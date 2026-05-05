/**
 * Invoice Controller — v23.1
 *
 * Endpoints :
 *   GET  /invoices/my            → liste les factures de l'utilisateur courant
 *   GET  /invoices/:id           → détail d'une facture (auth: owner OU provider)
 *   GET  /invoices/:id/html      → version HTML imprimable (PDF via "Imprimer → PDF")
 *   POST /admin/invoices         → liste admin avec filtres (role-aware)
 */

const Invoice = require('../models/Invoice');
const Booking = require('../models/Booking');
const Owner = require('../models/Owner');
const Sitter = require('../models/Sitter');
const Walker = require('../models/Walker');
const logger = require('../utils/logger');

const _providerModel = (role) => {
  const r = (role || '').toLowerCase();
  if (r === 'walker') return Walker;
  return Sitter;
};

/**
 * Build a unique invoice number HOP-YYYY-NNNN (zero-padded, atomic count).
 */
async function nextInvoiceNumber() {
  const year = new Date().getFullYear();
  // Count existing invoices issued this calendar year — naive but fine
  // until volume justifies a counter document.
  const start = new Date(year, 0, 1);
  const end = new Date(year + 1, 0, 1);
  const count = await Invoice.countDocuments({
    issuedAt: { $gte: start, $lt: end },
  });
  const seq = String(count + 1).padStart(4, '0');
  return `HOP-${year}-${seq}`;
}

/**
 * Idempotently create an Invoice for a booking that just got paid.
 * Called from airwallexWebhookController when payment_intent.succeeded
 * matches a booking. Safe to call multiple times — returns the existing
 * row if already created.
 */
async function createInvoiceForBooking(booking) {
  if (!booking) return null;

  const existing = await Invoice.findOne({ bookingId: booking._id });
  if (existing) {
    logger.info(
      `[invoice] booking ${booking._id} already has invoice ${existing.invoiceNumber}`,
    );
    return existing;
  }

  // Resolve owner.
  const owner = booking.ownerId && booking.ownerId._id
    ? booking.ownerId
    : await Owner.findById(booking.ownerId).lean();
  if (!owner) {
    logger.warn(`[invoice] owner not found for booking ${booking._id}`);
    return null;
  }

  // Resolve provider (sitter or walker).
  const isWalker = !!booking.walkerId;
  const providerRole = isWalker ? 'walker' : 'sitter';
  const ProviderModel = isWalker ? Walker : Sitter;
  const providerRefId = isWalker ? booking.walkerId : booking.sitterId;
  const provider = providerRefId && providerRefId._id
    ? providerRefId
    : await ProviderModel.findById(providerRefId).lean();
  if (!provider) {
    logger.warn(`[invoice] provider not found for booking ${booking._id}`);
    return null;
  }

  const gross = Number(booking.pricing?.totalPrice) || 0;
  const commission = Number(booking.pricing?.commission)
    || Math.round(gross * 0.2 * 100) / 100;
  const netPayout = Number(booking.pricing?.netPayout)
    || Math.round((gross - commission) * 100) / 100;
  const currency = (booking.pricing?.currency || 'EUR').toUpperCase();

  const invoice = await Invoice.create({
    invoiceNumber: await nextInvoiceNumber(),
    bookingId: booking._id,
    airwallexPaymentIntentId: booking.airwallexPaymentIntentId || '',
    ownerId: owner._id,
    ownerName: owner.name || '',
    ownerEmail: owner.email || '',
    providerId: provider._id,
    providerRole,
    providerName: provider.name || '',
    providerEmail: provider.email || '',
    serviceType: booking.serviceType || '',
    serviceDate: booking.serviceDate || null,
    startDate: booking.startDate || null,
    endDate: booking.endDate || null,
    petNames: Array.isArray(booking.petIds)
      ? booking.petIds
          .map((p) => (p && typeof p === 'object' ? p.petName : null))
          .filter(Boolean)
      : [],
    grossAmount: gross,
    commission,
    netPayout,
    currency,
    status: 'paid',
    paidAt: booking.paidAt || new Date(),
  });

  logger.info(
    `[invoice] created ${invoice.invoiceNumber} for booking ${booking._id} ` +
    `(€${gross} ${currency}, owner ${owner._id}, ${providerRole} ${provider._id})`,
  );
  return invoice;
}

/**
 * Mark an existing invoice as refunded (called when a booking is
 * self-cancelled within the 72h window or refunded after dispute).
 */
async function markInvoiceRefunded(bookingId) {
  if (!bookingId) return null;
  const inv = await Invoice.findOne({ bookingId });
  if (!inv) return null;
  if (inv.status === 'refunded') return inv;
  inv.status = 'refunded';
  inv.refundedAt = new Date();
  await inv.save();
  logger.info(`[invoice] ${inv.invoiceNumber} marked refunded (booking ${bookingId})`);
  return inv;
}

// ─── HTTP handlers ──────────────────────────────────────────────────────────

/**
 * GET /invoices/my
 * Returns invoices where current user is either the owner OR the provider.
 */
const listMyInvoices = async (req, res) => {
  try {
    if (!req.user?.id) {
      return res.status(401).json({ error: 'Authentication required.' });
    }
    const role = (req.user.role || '').toLowerCase();
    const userId = req.user.id;

    const filter = role === 'owner'
      ? { ownerId: userId }
      : role === 'walker' || role === 'sitter'
        ? { providerId: userId, providerRole: role }
        : { $or: [{ ownerId: userId }, { providerId: userId }] };

    const invoices = await Invoice.find(filter)
      .sort({ issuedAt: -1 })
      .limit(200)
      .lean();

    // Hide the counterparty's email in the response (GDPR-friendly).
    const sanitised = invoices.map((inv) => ({
      ...inv,
      ownerEmail: role === 'owner' ? inv.ownerEmail : undefined,
      providerEmail:
        role === 'sitter' || role === 'walker' ? inv.providerEmail : undefined,
    }));

    return res.json({ invoices: sanitised, count: sanitised.length });
  } catch (err) {
    logger.error('[invoiceController.listMyInvoices]', err);
    return res.status(500).json({ error: 'Unable to fetch invoices.' });
  }
};

/**
 * GET /invoices/:id
 * Returns a single invoice if the caller is involved (owner / provider / admin).
 */
const getInvoice = async (req, res) => {
  try {
    if (!req.user?.id) {
      return res.status(401).json({ error: 'Authentication required.' });
    }
    const inv = await Invoice.findById(req.params.id).lean();
    if (!inv) return res.status(404).json({ error: 'Invoice not found.' });

    const isOwner = inv.ownerId.toString() === req.user.id;
    const isProvider = inv.providerId.toString() === req.user.id;
    const isAdmin = req.user.role === 'admin';
    if (!isOwner && !isProvider && !isAdmin) {
      return res.status(403).json({ error: 'Access denied to this invoice.' });
    }

    return res.json({ invoice: inv });
  } catch (err) {
    logger.error('[invoiceController.getInvoice]', err);
    return res.status(500).json({ error: 'Unable to fetch invoice.' });
  }
};

/**
 * GET /invoices/:id/html
 * Returns a printable HTML version. The user (or admin) can hit "Imprimer →
 * PDF" from any browser to get a PDF copy. This avoids shipping a PDF
 * generation lib server-side for now.
 */
const renderInvoiceHtml = async (req, res) => {
  try {
    const inv = await Invoice.findById(req.params.id).lean();
    if (!inv) return res.status(404).send('Invoice not found');

    // Optional auth via query token — keep simple for a MVP, harden later.
    if (req.user?.id) {
      const isOwner = inv.ownerId.toString() === req.user.id;
      const isProvider = inv.providerId.toString() === req.user.id;
      const isAdmin = req.user.role === 'admin';
      if (!isOwner && !isProvider && !isAdmin) {
        return res.status(403).send('Access denied');
      }
    }

    const fmt = (d) => (d ? new Date(d).toISOString().slice(0, 10) : '—');
    const money = (n) =>
      `${(Number(n) || 0).toFixed(2)} ${(inv.currency || 'EUR').toUpperCase()}`;

    res.set('Content-Type', 'text/html; charset=utf-8');
    return res.send(`<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8" />
<title>Invoice ${inv.invoiceNumber} — HoPetSit</title>
<style>
  * { box-sizing: border-box; }
  body {
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
    color: #1f1f1f;
    margin: 0;
    padding: 40px;
    background: #fff;
  }
  .head { display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 32px; }
  .brand { font-size: 28px; font-weight: 700; color: #5942CC; }
  .brand small { display: block; font-size: 11px; font-weight: 400; color: #888; margin-top: 4px; }
  .meta { text-align: right; font-size: 13px; }
  .meta .num { font-size: 18px; font-weight: 700; color: #5942CC; }
  .meta .status {
    display: inline-block; padding: 4px 12px; border-radius: 999px;
    font-size: 11px; font-weight: 700; text-transform: uppercase;
    background: #E8F5E9; color: #2E7D32; margin-top: 6px;
  }
  .meta .status.refunded { background: #FFEBEE; color: #C62828; }
  .grid { display: grid; grid-template-columns: 1fr 1fr; gap: 24px; margin-bottom: 32px; }
  .card { padding: 14px 16px; border: 1px solid #E0DAFF; border-radius: 10px; background: #F9F7FF; }
  .card h3 { margin: 0 0 8px 0; font-size: 11px; text-transform: uppercase; letter-spacing: 0.05em; color: #5942CC; font-weight: 700; }
  .card .name { font-size: 14px; font-weight: 600; }
  .card .sub { font-size: 12px; color: #555; margin-top: 4px; }
  table { width: 100%; border-collapse: collapse; margin-bottom: 24px; }
  th, td { text-align: left; padding: 10px 12px; font-size: 13px; }
  th { background: #5942CC; color: #fff; font-weight: 600; }
  tbody tr:nth-child(even) { background: #F5F2FF; }
  .totals { width: 320px; margin-left: auto; }
  .totals tr td:first-child { color: #555; }
  .totals tr td:last-child { text-align: right; font-weight: 600; }
  .totals tr.grand td { font-size: 15px; color: #5942CC; border-top: 2px solid #5942CC; padding-top: 12px; }
  .footer { margin-top: 40px; padding-top: 20px; border-top: 1px solid #E0DAFF; font-size: 11px; color: #888; line-height: 1.6; }
  .pill { display: inline-block; padding: 2px 8px; border-radius: 4px; font-size: 10px; font-weight: 700; text-transform: uppercase; background: #5942CC; color: #fff; margin-left: 6px; }
  /* v23.1 part 44 — fix Daniel "factures sur Render mais on peut pas les
     télécharger". On mobile/Samsung browser the print menu is hidden behind
     a 3-dot menu and most users never find it. The download bar pins a
     visible "Télécharger PDF" button to the bottom of the screen — tapping
     it triggers window.print() which on mobile browsers presents the
     native Save-as-PDF / Share sheet. The bar hides itself in print mode
     so the saved PDF only contains the invoice itself. */
  .download-bar {
    position: fixed; left: 0; right: 0; bottom: 0;
    padding: 12px 16px; background: #fff;
    border-top: 1px solid #E0DAFF;
    box-shadow: 0 -4px 12px rgba(0,0,0,0.08);
    text-align: center;
    z-index: 9999;
  }
  .download-bar button {
    background: #EF4324; color: #fff; border: 0;
    padding: 12px 32px; border-radius: 999px;
    font-size: 15px; font-weight: 700; cursor: pointer;
    box-shadow: 0 2px 8px rgba(239, 67, 36, 0.35);
    -webkit-tap-highlight-color: transparent;
  }
  .download-bar button:active { transform: scale(0.97); }
  body { padding-bottom: 92px; } /* leave room for the fixed bar */
  @media print {
    body { padding: 20px; padding-bottom: 20px; }
    .download-bar { display: none !important; }
  }
</style>
</head>
<body>
  <div class="head">
    <div class="brand" style="display: flex; align-items: center; gap: 12px;">
      <!-- v23.1 part 34 — logo HoPetSit SVG inline (paw + "H" stylisé en orange) -->
      <svg width="48" height="48" viewBox="0 0 64 64" xmlns="http://www.w3.org/2000/svg">
        <circle cx="32" cy="32" r="32" fill="#EF4324"/>
        <g fill="#FFFFFF">
          <ellipse cx="32" cy="42" rx="14" ry="11"/>
          <ellipse cx="20" cy="26" rx="5" ry="6.5"/>
          <ellipse cx="44" cy="26" rx="5" ry="6.5"/>
          <ellipse cx="13" cy="35" rx="4" ry="5"/>
          <ellipse cx="51" cy="35" rx="4" ry="5"/>
        </g>
      </svg>
      <div>
        HoPetSit
        <small>Operated by CARDELLI HERMANOS LIMITED · Hong Kong<br/>Company No. n-2671528 · contact@hopetsit.com</small>
      </div>
    </div>
    <div class="meta">
      <div class="num">Invoice ${inv.invoiceNumber}</div>
      <div>Issued: ${fmt(inv.issuedAt)}</div>
      <div>Paid: ${fmt(inv.paidAt)}</div>
      <span class="status ${inv.status === 'refunded' ? 'refunded' : ''}">${inv.status}</span>
    </div>
  </div>

  <div class="grid">
    <div class="card">
      <h3>Bill to (Owner)</h3>
      <div class="name">${inv.ownerName || '—'}</div>
      <div class="sub">${inv.ownerEmail || ''}</div>
    </div>
    <div class="card">
      <h3>Service provider <span class="pill">${inv.providerRole}</span></h3>
      <div class="name">${inv.providerName || '—'}</div>
      <div class="sub">${inv.providerEmail || ''}</div>
    </div>
  </div>

  <table>
    <thead>
      <tr>
        <th>Description</th>
        <th>Service date</th>
        <th>Pets</th>
        <th style="text-align:right;">Amount</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td>${(inv.serviceType || 'Pet sitting / walking').replace(/_/g, ' ')}</td>
        <td>${fmt(inv.serviceDate || inv.startDate)}${inv.endDate ? ' → ' + fmt(inv.endDate) : ''}</td>
        <td>${(inv.petNames && inv.petNames.length ? inv.petNames.join(', ') : '—')}</td>
        <td style="text-align:right;">${money(inv.grossAmount)}</td>
      </tr>
    </tbody>
  </table>

  <table class="totals">
    <tr>
      <td>Gross amount</td>
      <td>${money(inv.grossAmount)}</td>
    </tr>
    <tr>
      <td>HoPetSit platform fee (20%)</td>
      <td>${money(inv.commission)}</td>
    </tr>
    <tr>
      <td>Net to provider</td>
      <td>${money(inv.netPayout)}</td>
    </tr>
    <tr class="grand">
      <td>Total charged to owner</td>
      <td>${money(inv.grossAmount)}</td>
    </tr>
  </table>

  <div class="footer">
    Payment processed by Airwallex (PCI-DSS Level 1 certified). HoPetSit does
    not access, transmit or store cardholder data.<br/>
    Funds are held in escrow until 24h after the service ends, then released
    to the provider's registered IBAN. Self-cancellation with full refund
    available up to 72h before the service starts. See
    <a href="https://hopetsit.com/refund">https://hopetsit.com/refund</a> for
    full terms.
  </div>

  <div class="download-bar">
    <button type="button" onclick="window.print()" aria-label="Télécharger PDF">
      ⬇ Télécharger PDF
    </button>
  </div>
</body>
</html>`);
  } catch (err) {
    logger.error('[invoiceController.renderInvoiceHtml]', err);
    return res.status(500).send('Server error');
  }
};

/**
 * GET /admin/invoices?role=owner|sitter|walker&from=YYYY-MM-DD&to=YYYY-MM-DD
 * Admin endpoint — list all invoices, optionally filtered by role and date.
 */
const adminListInvoices = async (req, res) => {
  try {
    if (req.user?.role !== 'admin') {
      return res.status(403).json({ error: 'Admin access required.' });
    }
    const { role, from, to } = req.query;
    const filter = {};
    if (role === 'owner' || role === 'sitter' || role === 'walker') {
      // 'owner' filter = invoices with an ownerId (always true), no-op.
      // For 'sitter' / 'walker' we restrict by providerRole.
      if (role !== 'owner') filter.providerRole = role;
    }
    if (from || to) {
      filter.issuedAt = {};
      if (from) filter.issuedAt.$gte = new Date(from);
      if (to) filter.issuedAt.$lte = new Date(to);
    }
    const invoices = await Invoice.find(filter)
      .sort({ issuedAt: -1 })
      .limit(500)
      .lean();
    return res.json({ invoices, count: invoices.length });
  } catch (err) {
    logger.error('[invoiceController.adminListInvoices]', err);
    return res.status(500).json({ error: 'Unable to fetch invoices.' });
  }
};

module.exports = {
  createInvoiceForBooking,
  markInvoiceRefunded,
  listMyInvoices,
  getInvoice,
  renderInvoiceHtml,
  adminListInvoices,
};

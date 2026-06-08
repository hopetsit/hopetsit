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

    // v23.1.162 — Daniel : "Facture HoPetSit" + "Télécharger PDF" affichés
    // en FR sur UI espagnole. La page HTML de la facture est servie par
    // le backend → on lit le `lang` query param (ou Accept-Language) et
    // on choisit la locale appropriee. Le frontend Flutter passe deja
    // ?lang=es/de/it/pt/en/fr quand il ouvre la WebView.
    const rawLang = (req.query.lang ||
      (req.headers['accept-language'] || 'en').split(',')[0].split('-')[0] ||
      'en')
      .toString()
      .toLowerCase()
      .slice(0, 2);
    const supported = ['en', 'fr', 'es', 'de', 'it', 'pt'];
    const lang = supported.includes(rawLang) ? rawLang : 'en';

    // v23.1.164 — Daniel : "dans la fcture ya tjr ecris invoice fais que tt
    // soit bien traduit". Ajout du label `invoiceLabel` qui sert pour le
    // <title> de la page ET pour le numero affiche en haut a droite.
    // v23.1.175 — Daniel : "sur le descriptif de la facture mal traduit
    // a verifier tte les langue". On ajoute serviceWalk / serviceDaycare /
    // serviceBoarding / serviceSitting / serviceGeneric à chaque langue,
    // et on traduit la cellule "Description" du tableau en fonction de
    // inv.serviceType (au lieu de juste replace _ par espace).
    const T = {
      en: {
        invoiceTitle: 'HoPetSit Invoice', invoiceLabel: 'Invoice', downloadBtn: '⬇ Download PDF',
        billTo: 'Bill to (Owner)', serviceProvider: 'Service provider',
        description: 'Description', serviceDate: 'Service date', pets: 'Pets',
        amount: 'Amount', issued: 'Issued', paid: 'Paid',
        grossAmount: 'Gross amount', commission: 'HoPetSit platform fee (20%)',
        netProvider: 'Net to provider', totalCharged: 'Total charged to owner',
        footer: 'Payment processed by Airwallex (PCI-DSS Level 1 certified). HoPetSit does not access, transmit or store cardholder data.',
        cancelTerms: 'Self-cancellation with full refund available up to 72h before the service starts. See',
        escrowText: "Funds are held in escrow until 24h after the service ends, then released to the provider's registered IBAN.",
        serviceWalk: 'Dog walk', serviceDaycare: 'Day care',
        serviceBoarding: 'Overnight boarding', serviceSitting: 'Pet-sitting',
        serviceGeneric: 'Service',
      },
      fr: {
        invoiceTitle: 'Facture HoPetSit', invoiceLabel: 'Facture', downloadBtn: '⬇ Télécharger PDF',
        billTo: 'Facturé à (Propriétaire)', serviceProvider: 'Prestataire',
        description: 'Description', serviceDate: 'Date du service', pets: 'Animaux',
        amount: 'Montant', issued: 'Émise', paid: 'Payée',
        grossAmount: 'Montant brut', commission: 'Commission HoPetSit (20%)',
        netProvider: 'Net pour le prestataire', totalCharged: 'Total facturé au propriétaire',
        footer: 'Paiement traité par Airwallex (certifié PCI-DSS Niveau 1). HoPetSit n\'accède pas, ne transmet pas et ne stocke pas les données de carte bancaire.',
        cancelTerms: 'Annulation gratuite avec remboursement intégral disponible jusqu\'à 72h avant le début du service. Voir',
        escrowText: "Les fonds sont conservés en séquestre jusqu'à 24h après la fin du service, puis libérés vers l'IBAN enregistré du prestataire.",
        serviceWalk: 'Promenade chien', serviceDaycare: 'Garderie',
        serviceBoarding: 'Garde nuit', serviceSitting: 'Pet-sitting',
        serviceGeneric: 'Service',
      },
      es: {
        invoiceTitle: 'Factura HoPetSit', invoiceLabel: 'Factura', downloadBtn: '⬇ Descargar PDF',
        billTo: 'Facturado a (Propietario)', serviceProvider: 'Prestador del servicio',
        description: 'Descripción', serviceDate: 'Fecha del servicio', pets: 'Mascotas',
        amount: 'Importe', issued: 'Emitida', paid: 'Pagada',
        grossAmount: 'Importe bruto', commission: 'Comisión HoPetSit (20%)',
        netProvider: 'Neto para el prestador', totalCharged: 'Total facturado al propietario',
        footer: 'Pago procesado por Airwallex (certificado PCI-DSS Nivel 1). HoPetSit no accede, transmite ni almacena datos de tarjetas.',
        cancelTerms: 'Cancelación gratuita con reembolso íntegro disponible hasta 72h antes del inicio del servicio. Ver',
        escrowText: 'Los fondos se mantienen en depósito hasta 24h después del final del servicio, luego se liberan al IBAN registrado del prestador.',
        serviceWalk: 'Paseo de perros', serviceDaycare: 'Guardería',
        serviceBoarding: 'Hospedaje nocturno', serviceSitting: 'Pet-sitting',
        serviceGeneric: 'Servicio',
      },
      de: {
        invoiceTitle: 'HoPetSit Rechnung', invoiceLabel: 'Rechnung', downloadBtn: '⬇ PDF herunterladen',
        billTo: 'Rechnung an (Besitzer)', serviceProvider: 'Dienstleister',
        description: 'Beschreibung', serviceDate: 'Servicedatum', pets: 'Tiere',
        amount: 'Betrag', issued: 'Ausgestellt', paid: 'Bezahlt',
        grossAmount: 'Bruttobetrag', commission: 'HoPetSit Plattformgebühr (20%)',
        netProvider: 'Netto an Anbieter', totalCharged: 'Gesamtbetrag an Besitzer berechnet',
        footer: 'Zahlung verarbeitet durch Airwallex (PCI-DSS Stufe 1 zertifiziert). HoPetSit greift nicht auf Kartendaten zu, überträgt oder speichert sie nicht.',
        cancelTerms: 'Kostenlose Stornierung mit voller Rückerstattung bis 72 Std. vor Servicebeginn möglich. Siehe',
        escrowText: 'Die Gelder werden bis 24 Std. nach Serviceende treuhänderisch verwahrt und dann auf das hinterlegte IBAN des Anbieters freigegeben.',
        serviceWalk: 'Gassi gehen', serviceDaycare: 'Tagesbetreuung',
        serviceBoarding: 'Übernachtungspflege', serviceSitting: 'Pet-Sitting',
        serviceGeneric: 'Service',
      },
      it: {
        invoiceTitle: 'Fattura HoPetSit', invoiceLabel: 'Fattura', downloadBtn: '⬇ Scarica PDF',
        billTo: 'Fatturato a (Proprietario)', serviceProvider: 'Prestatore del servizio',
        description: 'Descrizione', serviceDate: 'Data del servizio', pets: 'Animali',
        amount: 'Importo', issued: 'Emessa', paid: 'Pagata',
        grossAmount: 'Importo lordo', commission: 'Commissione HoPetSit (20%)',
        netProvider: 'Netto al prestatore', totalCharged: 'Totale addebitato al proprietario',
        footer: 'Pagamento elaborato da Airwallex (certificato PCI-DSS Livello 1). HoPetSit non accede, trasmette o memorizza i dati delle carte.',
        cancelTerms: 'Annullamento gratuito con rimborso integrale disponibile fino a 72h prima dell\'inizio del servizio. Vedi',
        escrowText: 'I fondi sono conservati in deposito fino a 24h dopo la fine del servizio, poi rilasciati sull\'IBAN registrato del prestatore.',
        serviceWalk: 'Passeggiata cane', serviceDaycare: 'Asilo',
        serviceBoarding: 'Pensione notturna', serviceSitting: 'Pet-sitting',
        serviceGeneric: 'Servizio',
      },
      pt: {
        invoiceTitle: 'Fatura HoPetSit', invoiceLabel: 'Fatura', downloadBtn: '⬇ Descarregar PDF',
        billTo: 'Faturado a (Proprietário)', serviceProvider: 'Prestador do serviço',
        description: 'Descrição', serviceDate: 'Data do serviço', pets: 'Animais',
        amount: 'Valor', issued: 'Emitida', paid: 'Paga',
        grossAmount: 'Valor bruto', commission: 'Comissão HoPetSit (20%)',
        netProvider: 'Líquido para o prestador', totalCharged: 'Total cobrado ao proprietário',
        footer: 'Pagamento processado pela Airwallex (certificado PCI-DSS Nível 1). A HoPetSit não acede, transmite nem armazena dados de cartões.',
        cancelTerms: 'Cancelamento gratuito com reembolso integral disponível até 72h antes do início do serviço. Ver',
        escrowText: 'Os fundos são mantidos em garantia até 24h após o fim do serviço, depois libertados para o IBAN registado do prestador.',
        serviceWalk: 'Passeio de cão', serviceDaycare: 'Creche',
        serviceBoarding: 'Hospedagem noturna', serviceSitting: 'Pet-sitting',
        serviceGeneric: 'Serviço',
      },
    }[lang];

    // v23.1.175 — helper qui traduit le serviceType brut (ex: 'dog_walk',
    // 'overnight_boarding') en label de la langue courante. Mirror exact
    // du _serviceLabel(raw) côté Flutter PDF (invoice_pdf_generator.dart).
    const serviceLabelHtml = (raw) => {
      const s = String(raw || '').toLowerCase();
      if (s.includes('walk')) return T.serviceWalk;
      if (s.includes('day_care') || s.includes('garderie')) return T.serviceDaycare;
      if (s.includes('boarding') || s.includes('overnight')) return T.serviceBoarding;
      if (s.includes('sitting')) return T.serviceSitting;
      return raw ? raw.replace(/_/g, ' ') : T.serviceGeneric;
    };

    res.set('Content-Type', 'text/html; charset=utf-8');
    return res.send(`<!DOCTYPE html>
<html lang="${lang}">
<head>
<meta charset="utf-8" />
<title>${T.invoiceLabel} ${inv.invoiceNumber} — HoPetSit</title>
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
  /* v23.1 part 44/45 — fix Daniel "factures sur Render mais on peut pas
     les télécharger". On mobile the print menu is hidden behind a 3-dot
     menu and most users never find it. We show TWO clear "Télécharger
     PDF" entry points : a banner CTA at the top (so users see it before
     scrolling) and a sticky bottom bar (so it stays in reach while
     reading). Both call window.print() which on mobile browsers presents
     the native Save-as-PDF / Share sheet. Bars hide themselves in print
     mode so the saved PDF only contains the invoice itself. */
  .download-cta-top {
    background: linear-gradient(135deg, #EF4324, #FF6B4A);
    color: #fff; border-radius: 14px;
    padding: 14px 16px; margin-bottom: 24px;
    display: flex; align-items: center; justify-content: space-between;
    box-shadow: 0 4px 12px rgba(239, 67, 36, 0.25);
  }
  .download-cta-top .label { font-weight: 700; font-size: 14px; }
  .download-cta-top button {
    background: #fff; color: #EF4324; border: 0;
    padding: 10px 20px; border-radius: 999px;
    font-size: 14px; font-weight: 800; cursor: pointer;
    -webkit-tap-highlight-color: transparent;
  }
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
    padding: 14px 32px; border-radius: 999px;
    font-size: 16px; font-weight: 800; cursor: pointer;
    box-shadow: 0 2px 8px rgba(239, 67, 36, 0.35);
    -webkit-tap-highlight-color: transparent;
    width: 100%;
    max-width: 360px;
  }
  .download-bar button:active { transform: scale(0.97); }
  body { padding-bottom: 92px; } /* leave room for the fixed bar */
  @media print {
    body { padding: 20px; padding-bottom: 20px; }
    .download-bar, .download-cta-top { display: none !important; }
  }
</style>
</head>
<body>
  <div class="download-cta-top">
    <span class="label">📄 ${T.invoiceTitle}</span>
    <button type="button" onclick="downloadInvoice()">${T.downloadBtn}</button>
  </div>
  <div class="head">
    <div class="brand" style="display: flex; align-items: center; gap: 12px;">
      <!-- v23.1 part 67 — official HoPetSit logo (orange rounded square +
           white paw with red/blue/green dots), copy of frontend
           assets/brand/web/logo-orange.svg. Daniel : "Mettre notre logo
           sur la facture". -->
      <svg width="56" height="56" viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg">
        <rect width="1024" height="1024" rx="200" fill="#EF4324"/>
        <g transform="translate(512, 471)">
          <path d="M0,-427 C-427,-427 -427,-171 -427,55 C-427,300 -215,478 0,539 C215,478 427,300 427,55 C427,-171 427,-427 0,-427 Z" fill="white"/>
          <ellipse cx="-195" cy="-154" rx="58" ry="65" fill="#EF4324"/>
          <ellipse cx="-68" cy="-235" rx="58" ry="65" fill="#1A73E8"/>
          <ellipse cx="68"  cy="-235" rx="58" ry="65" fill="#008000"/>
          <ellipse cx="195" cy="-154" rx="58" ry="65" fill="#EF4324"/>
          <path d="M-290,120 C-290,-34 -181,-119 0,-119 C181,-119 290,-34 290,120 C290,239 181,314 0,314 C-181,314 -290,239 -290,120 Z" fill="#1A1A1A"/>
          <ellipse cx="0" cy="120" rx="205" ry="102" fill="#0D0D0D"/>
          <circle cx="0" cy="120" r="99" fill="#EF4324"/>
          <circle cx="0" cy="120" r="55" fill="#0D0D0D"/>
          <circle cx="24" cy="92" r="26" fill="white"/>
          <circle cx="-20" cy="137" r="14" fill="white" opacity="0.5"/>
          <path d="M-205,120 C-116,55 116,55 205,120" fill="none" stroke="#0D0D0D" stroke-width="8.9" stroke-linecap="round"/>
          <path d="M-205,120 C-116,184 116,184 205,120" fill="none" stroke="#0D0D0D" stroke-width="8.9" stroke-linecap="round"/>
        </g>
      </svg>
      <div>
        HoPetSit
        <small>Operated by CARDELLI HERMANOS LIMITED · Hong Kong<br/>Company No. n-2671528 · contact@hopetsit.com</small>
      </div>
    </div>
    <div class="meta">
      <div class="num">${T.invoiceLabel} ${inv.invoiceNumber}</div>
      <div>${T.issued}: ${fmt(inv.issuedAt)}</div>
      <div>${T.paid}: ${fmt(inv.paidAt)}</div>
      <span class="status ${inv.status === 'refunded' ? 'refunded' : ''}">${inv.status}</span>
    </div>
  </div>

  <div class="grid">
    <div class="card">
      <h3>${T.billTo}</h3>
      <div class="name">${inv.ownerName || '—'}</div>
      <div class="sub">${inv.ownerEmail || ''}</div>
    </div>
    <div class="card">
      <h3>${T.serviceProvider} <span class="pill">${inv.providerRole}</span></h3>
      <div class="name">${inv.providerName || '—'}</div>
      <div class="sub">${inv.providerEmail || ''}</div>
    </div>
  </div>

  <table>
    <thead>
      <tr>
        <th>${T.description}</th>
        <th>${T.serviceDate}</th>
        <th>${T.pets}</th>
        <th style="text-align:right;">${T.amount}</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td>${serviceLabelHtml(inv.serviceType)}</td>
        <td>${fmt(inv.serviceDate || inv.startDate)}${inv.endDate ? ' → ' + fmt(inv.endDate) : ''}</td>
        <td>${(inv.petNames && inv.petNames.length ? inv.petNames.join(', ') : '—')}</td>
        <td style="text-align:right;">${money(inv.grossAmount)}</td>
      </tr>
    </tbody>
  </table>

  <table class="totals">
    <tr>
      <td>${T.grossAmount}</td>
      <td>${money(inv.grossAmount)}</td>
    </tr>
    <tr>
      <td>${T.commission}</td>
      <td>${money(inv.commission)}</td>
    </tr>
    <tr>
      <td>${T.netProvider}</td>
      <td>${money(inv.netPayout)}</td>
    </tr>
    <tr class="grand">
      <td>${T.totalCharged}</td>
      <td>${money(inv.grossAmount)}</td>
    </tr>
  </table>

  <div class="footer">
    ${T.footer}<br/>
    ${T.escrowText} ${T.cancelTerms}
    <a href="https://hopetsit.com/refund">https://hopetsit.com/refund</a>.
  </div>

  <div class="download-bar">
    <button type="button" onclick="downloadInvoice()" aria-label="${T.downloadBtn}">
      ${T.downloadBtn}
    </button>
  </div>

  <!-- v23.1 part 65 — Bug 7 : downloadInvoice() prefers the HoPetSit JS
       channel (registered by Flutter InvoiceViewerScreen) which pops out
       to the system browser where Save-as-PDF / Share work reliably.
       Falls back to window.print() when the page is opened in a regular
       browser (no HoPetSit channel registered). -->
  <script>
    function downloadInvoice() {
      try {
        if (typeof HoPetSit !== 'undefined' && HoPetSit && typeof HoPetSit.postMessage === 'function') {
          HoPetSit.postMessage('download');
          return;
        }
      } catch (_) { /* fall through */ }
      try { window.print(); } catch (_) { /* last-ditch silent */ }
    }
  </script>
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

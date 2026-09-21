/**
 * Invoice Controller — v23.1
 *
 * Endpoints :
 *   GET  /invoices/my            → liste les factures de l'utilisateur courant
 *   GET  /invoices/:id           → détail d'une facture (auth: owner OU provider)
 *   GET  /invoices/:id/html      → version HTML imprimable (PDF via "Imprimer → PDF")
 *   POST /admin/invoices         → liste admin avec filtres (role-aware)
 */

const fs = require('fs');
const path = require('path');
const Invoice = require('../models/Invoice');
const Booking = require('../models/Booking');
const Owner = require('../models/Owner');
const Sitter = require('../models/Sitter');
const Walker = require('../models/Walker');
const logger = require('../utils/logger');
const {
  resolveBillingInfoAcrossRoles,
  toBillingSnapshot,
  snapshotForApi,
  isSnapshotFrozen,
} = require('../utils/billingInfo');

// ─── v576 — identité de l'entité qui facture ────────────────────────────────
// CARDELLI HERMANOS LIMITED exploite HoPetSit : la marque affichée au client
// reste HoPetSit (il a réservé là), mais la facture est ÉMISE par la société.
// Ces valeurs reprennent exactement celles déjà présentes dans le pied de page
// de l'ancien gabarit — rien n'est inventé (pas d'adresse de rue, elle n'a
// jamais figuré ici).
const ISSUER_COMPANY = {
  name: 'CARDELLI HERMANOS LIMITED',
  place: 'Hong Kong',
  companyNumber: 'n-2671528',
  email: 'contact@hopetsit.com',
};

// ─── v576 — logos EMBARQUÉS (data URI) ──────────────────────────────────────
// Un PDF imprimé depuis la page doit rester complet hors ligne : aucune URL
// distante, donc les images sont encodées en base64 dans le HTML. Les fichiers
// sont lus UNE fois au chargement du module et gardés en mémoire.
//   · hopetsit_logo_192.png = logo OFFICIEL actuel de l'app (fourni par
//     Daniel en 320 px dans hopetsit_logo.png), redimensionné à 192 px =
//     4× sa taille d'affichage (48 px) : net à l'impression A4, et 3× plus
//     léger (54 ko au lieu de 124 ko). Le master 320 px reste dans assets.
//     L'ancien dessin SVG en dur (carré orange de la v23.1) ne correspondait
//     plus à la marque refaite au build 570.
//   · cardelli_hermanos_logo.png (320 px) = logo de la société qui facture.
const embeddedPng = (name, label) => {
  try {
    const file = path.join(__dirname, '..', 'assets', name);
    return `data:image/png;base64,${fs.readFileSync(file).toString('base64')}`;
  } catch (e) {
    logger.warn(`[invoice] logo ${label} illisible (${e.message}) — facture rendue sans ce logo`);
    return '';
  }
};
const CARDELLI_LOGO_DATA_URI = embeddedPng('cardelli_hermanos_logo.png', 'Cardelli Hermanos');
const HOPETSIT_LOGO_DATA_URI = embeddedPng('hopetsit_logo_192.png', 'HoPetSit')
  || embeddedPng('hopetsit_logo.png', 'HoPetSit (master)');

// ─── v576 — libellés de la facture : locales/<lang>/invoice.json ────────────
// Même mécanisme que notifications.json / lifecycle.json (lecture + cache).
// L'anglais sert de socle : une clé absente d'une langue ne peut pas faire
// apparaître une chaîne vide dans la facture.
const INVOICE_LOCALES = ['en', 'fr', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl'];
const _invoiceCatalogs = {};
const loadInvoiceCatalog = (locale) => {
  if (_invoiceCatalogs[locale]) return _invoiceCatalogs[locale];
  try {
    const file = path.join(__dirname, '..', 'locales', locale, 'invoice.json');
    _invoiceCatalogs[locale] = JSON.parse(fs.readFileSync(file, 'utf8') || '{}');
  } catch (e) {
    logger.warn(`[invoice] catalogue ${locale} illisible: ${e.message}`);
    _invoiceCatalogs[locale] = {};
  }
  return _invoiceCatalogs[locale];
};
const invoiceTexts = (lang) => ({ ...loadInvoiceCatalog('en'), ...loadInvoiceCatalog(lang) });

// ─── v576 — langue et page d'erreur (facture consultée en WebView) ──────────
// Avant : un 401 / 403 / 404 renvoyait une phrase ANGLAISE en texte brut, que
// la WebView de l'app affichait telle quelle (« Invoice not found »). On rend
// désormais une page lisible, traduite, qui dit quoi faire.
const twoLetters = (v) => String(v || '').toLowerCase().slice(0, 2);
const langFromRequest = (req) => [
  twoLetters(req && req.query ? req.query.lang : ''),
  twoLetters(((req && req.headers && req.headers['accept-language']) || '').split(',')[0].split('-')[0]),
].find((l) => INVOICE_LOCALES.includes(l)) || 'en';

const escapeHtml = (v) => String(v == null ? '' : v)
  .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
  .replace(/"/g, '&quot;').replace(/'/g, '&#39;');

/** Page d'erreur de la facture : status HTTP + message traduit. */
function sendInvoiceError(req, res, status, key) {
  const lang = langFromRequest(req);
  const T = invoiceTexts(lang);
  const message = T[key] || T.errorServer;
  res.status(status).set('Content-Type', 'text/html; charset=utf-8');
  return res.send(`<!DOCTYPE html>
<html lang="${lang}">
<head><meta charset="utf-8" /><meta name="viewport" content="width=device-width, initial-scale=1" />
<title>${escapeHtml(T.errorTitle)}</title>
<style>
  body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
    margin: 0; min-height: 100vh; display: flex; align-items: center; justify-content: center;
    padding: 32px 20px; background: #fff; color: #17141F; text-align: center; }
  .box { max-width: 420px; }
  h1 { font-size: 18px; font-weight: 800; margin: 0 0 8px; }
  p { font-size: 14px; line-height: 1.6; color: #5B5B66; margin: 0; }
  .mark { width: 44px; height: 44px; border-radius: 12px; background: #C92A12; margin: 0 auto 16px; }
</style>
</head>
<body><div class="box"><div class="mark"></div>
<h1>${escapeHtml(T.errorTitle)}</h1><p>${escapeHtml(message)}</p></div></body>
</html>`);
}

// ─── v566 — instantanés de facturation ──────────────────────────────────────
// `issuerBilling` (prestataire) et `customerBilling` (propriétaire) sont copiés
// à la création. Une fois figé (`snapshotAt`), un instantané ne change plus :
// modifier son NIF plus tard ne réécrit pas les factures déjà émises.
// Factures antérieures à la v566 (ou partie qui n'avait encore rien saisi) :
// remplissage UNE fois, à la première lecture où la personne a des données,
// puis figé. L'écriture est conditionnelle (`snapshotAt: null`) → deux lectures
// simultanées ne peuvent pas figer deux versions différentes.
const _billingSides = (inv) => [
  { field: 'issuerBilling', partyId: inv.providerId, model: inv.providerRole === 'walker' ? 'Walker' : 'Sitter' },
  { field: 'customerBilling', partyId: inv.ownerId, model: 'Owner' },
];

async function ensureBillingSnapshots(invoices) {
  const list = (Array.isArray(invoices) ? invoices : [invoices]).filter(Boolean);
  const memo = new Map(); // une résolution par personne et par requête
  const resolve = (id, model) => {
    const key = `${model}:${id}`;
    if (!memo.has(key)) memo.set(key, resolveBillingInfoAcrossRoles(id, model));
    return memo.get(key);
  };
  for (const inv of list) {
    for (const side of _billingSides(inv)) {
      if (isSnapshotFrozen(inv[side.field]) || !side.partyId) continue;
      try {
        // eslint-disable-next-line no-await-in-loop
        const snap = toBillingSnapshot(await resolve(String(side.partyId), side.model), new Date());
        if (!snap) continue; // rien à figer pour l'instant
        // eslint-disable-next-line no-await-in-loop
        const r = await Invoice.updateOne(
          { _id: inv._id, [`${side.field}.snapshotAt`]: null },
          { $set: { [side.field]: snap } },
        );
        if (r && r.modifiedCount === 0) {
          // Figé entre-temps par une autre lecture : on relit la version retenue.
          // eslint-disable-next-line no-await-in-loop
          const fresh = await Invoice.findById(inv._id).select(side.field).lean();
          inv[side.field] = (fresh && fresh[side.field]) || inv[side.field];
        } else {
          inv[side.field] = snap;
        }
      } catch (e) {
        logger.warn(`[invoice] billing snapshot failed for ${inv._id} (${side.field}): ${e.message}`);
      }
    }
  }
  return invoices;
}

const _withBillingForApi = (inv) => ({
  ...inv,
  issuerBilling: snapshotForApi(inv.issuerBilling),
  customerBilling: snapshotForApi(inv.customerBilling),
});

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
  // v532 — le repli calculait la commission comme 20 % du TOTAL PAYÉ. Or notre
  // modèle est « commission EN PLUS » : total = base × 1,20, donc la commission
  // vaut base × 0,20 = total / 6 (≈ 16,67 % du total), pas 20 % du total. Sur
  // une garde à 120 €, l'ancienne formule facturait 24 € de commission au lieu
  // de 20 € et sous-estimait d'autant le net du prestataire — une facture
  // fausse pour les deux parties. On privilégie maintenant le net réellement
  // versé (source de vérité du virement) et on ne retombe sur un calcul que si
  // la réservation n'a aucune donnée de prix.
  const storedCommission = Number(booking.pricing?.commission);
  const storedNet = Number(booking.pricing?.netPayout);
  let commission;
  let netPayout;
  if (Number.isFinite(storedCommission) && storedCommission > 0) {
    commission = storedCommission;
    netPayout = Number.isFinite(storedNet) && storedNet > 0
      ? storedNet
      : Math.round((gross - commission) * 100) / 100;
  } else if (Number.isFinite(storedNet) && storedNet > 0) {
    netPayout = storedNet;
    commission = Math.round((gross - netPayout) * 100) / 100;
  } else {
    // Aucune donnée : on inverse la formule du modèle (base = total / 1,20).
    netPayout = Math.round((gross / 1.2) * 100) / 100;
    commission = Math.round((gross - netPayout) * 100) / 100;
  }
  const currency = (booking.pricing?.currency || 'EUR').toUpperCase();

  // v566 — instantanés de facturation pris MAINTENANT (la facture ne change
  // plus ensuite). Un échec de lecture ne doit jamais bloquer la facture.
  const snapshotAt = new Date();
  const [issuerInfo, customerInfo] = await Promise.all([
    resolveBillingInfoAcrossRoles(provider._id, isWalker ? 'Walker' : 'Sitter').catch(() => null),
    resolveBillingInfoAcrossRoles(owner._id, 'Owner').catch(() => null),
  ]);
  const issuerBilling = toBillingSnapshot(issuerInfo, snapshotAt);
  const customerBilling = toBillingSnapshot(customerInfo, snapshotAt);

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
    ...(issuerBilling ? { issuerBilling } : {}),
    ...(customerBilling ? { customerBilling } : {}),
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
    await ensureBillingSnapshots(invoices);

    // Hide the counterparty's email in the response (GDPR-friendly).
    // v498 — Daniel : « Server error » au téléchargement PDF côté web. CAUSE :
    // les docs `.lean()` exposent `_id` (pas `id`) → le site lisait `inv.id`
    // === undefined → URL `/invoices/undefined/html` → findById('undefined')
    // = CastError → 500. On expose `id` explicitement (en plus de `_id`).
    const sanitised = invoices.map((inv) => ({
      ..._withBillingForApi(inv),
      id: inv._id ? inv._id.toString() : undefined,
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

    await ensureBillingSnapshots([inv]);
    return res.json({ invoice: _withBillingForApi(inv) });
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
    // v498 — id invalide (ex. 'undefined') → 404 propre au lieu d'un CastError
    // qui finissait en 500 « Server error ».
    if (!/^[0-9a-fA-F]{24}$/.test(String(req.params.id || ''))) {
      return sendInvoiceError(req, res, 404, 'errorNotFound');
    }
    const inv = await Invoice.findById(req.params.id).lean();
    if (!inv) return sendInvoiceError(req, res, 404, 'errorNotFound');

    // Optional auth via query token. v498 — Daniel : « le bouton télécharger
    // PDF ne marche pas ». Une facture d'ABONNEMENT/PROMO n'a pas de providerId
    // → `inv.providerId.toString()` levait un TypeError → 500 « Server error »
    // (page blanche/erreur). On compare via String(... || '') (null-safe).
    if (req.user?.id) {
      const uid = String(req.user.id);
      const isOwner = inv.ownerId ? String(inv.ownerId) === uid : false;
      const isProvider = inv.providerId ? String(inv.providerId) === uid : false;
      const isAdmin = req.user.role === 'admin';
      if (!isOwner && !isProvider && !isAdmin) {
        return sendInvoiceError(req, res, 403, 'errorDenied');
      }
    }

    // v566 — instantanés de facturation (remplissage unique si absents).
    await ensureBillingSnapshots([inv]);

    // v566 — tout texte saisi par un utilisateur est échappé (la page est
    // servie depuis le domaine de l'API, avec le jeton en paramètre).
    const esc = (v) => String(v == null ? '' : v)
      .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;').replace(/'/g, '&#39;');

    const fmt = (d) => (d ? new Date(d).toISOString().slice(0, 10) : '—');
    const money = (n) =>
      `${(Number(n) || 0).toFixed(2)} ${(inv.currency || 'EUR').toUpperCase()}`;

    // v23.1.162 — Daniel : "Facture HoPetSit" + "Télécharger PDF" affichés
    // en FR sur UI espagnole. La page HTML de la facture est servie par
    // le backend → on lit le `lang` query param (ou Accept-Language) et
    // on choisit la locale appropriee. Le frontend Flutter passe deja
    // ?lang=es/de/it/pt/en/fr quand il ouvre la WebView.
    // v566 — 9 langues (ko / ja / pl ajoutés) ; sans `?lang`, on prend la
    // langue du COMPTE (appLocale) avant l'Accept-Language du navigateur.
    const supported = INVOICE_LOCALES;
    const two = (v) => String(v || '').toLowerCase().slice(0, 2);
    let accountLang = '';
    if (!supported.includes(two(req.query.lang)) && req.user?.id && req.user.role !== 'admin') {
      try {
        const docs = await Promise.all(
          [Owner, Sitter, Walker].map((M) => M.findById(req.user.id).select('appLocale').lean().catch(() => null)),
        );
        accountLang = two((docs.find((d) => d && d.appLocale) || {}).appLocale);
      } catch (_) { /* langue du navigateur en repli */ }
    }
    const rawLang = [
      two(req.query.lang),
      accountLang,
      two((req.headers['accept-language'] || '').split(',')[0].split('-')[0]),
    ].find((l) => supported.includes(l));
    const lang = rawLang || 'en';

    // v576 — les libellés viennent de locales/<lang>/invoice.json (même
    // mécanisme que les notifications et les e-mails de cycle de vie) :
    // plus aucune table de traduction en dur dans ce contrôleur, et aucun mot
    // anglais résiduel (le statut « paid » était affiché brut avant la v576).
    const T = invoiceTexts(lang);

    // Libellé du type d'identifiant du client / du prestataire. Les sigles
    // nationaux (NIF, NIE, CIF, SIRET, EIN) ne se traduisent pas ; TVA,
    // passeport et numéro d'entreprise, si.
    const idTypeLabel = (t) => ({
      nif: 'NIF', nie: 'NIE', cif: 'CIF', siret: 'SIRET', ein: 'EIN',
      vat: T.vat, passport: T.passport, company_number: T.companyNumber, other: T.idOther,
    }[t] || T.idOther);

    // Lignes d'un bloc de facturation : raison sociale (+ « Professionnel »),
    // « NIF : X… », n° de TVA, adresse complète. Un champ vide ne produit
    // JAMAIS de ligne, et aucun libellé n'est affiché sans sa valeur.
    const billingLines = (b, accountName) => {
      if (!b) return '';
      const lines = [];
      // Nom légal identique au nom du compte (particulier) : pas de doublon.
      const sameName = String(b.legalName || '').trim().toLowerCase() === String(accountName || '').trim().toLowerCase();
      if (b.legalName && !(sameName && b.type !== 'business')) lines.push(`<div class="line"><strong>${esc(b.legalName)}</strong>${b.type === 'business' ? ` · ${esc(T.business)}` : ''}</div>`);
      if (b.idNumber) lines.push(`<div class="line">${esc(idTypeLabel(b.idType))}${esc(T.labelSep)}${esc(b.idNumber)}</div>`);
      if (b.vatNumber && !(b.idType === 'vat' && b.vatNumber === b.idNumber)) lines.push(`<div class="line">${esc(T.vat)}${esc(T.labelSep)}${esc(b.vatNumber)}</div>`);
      const cityLine = [b.postalCode, b.city].filter(Boolean).join(' ');
      const addr = [b.address, cityLine, b.country].filter(Boolean).map(esc).join(', ');
      if (addr) lines.push(`<div class="line">${addr}</div>`);
      return lines.join('\n        ');
    };
    const issuerB = snapshotForApi(inv.issuerBilling);
    const customerB = snapshotForApi(inv.customerBilling);

    // v23.1.175 — helper qui traduit le serviceType brut (ex: 'dog_walk',
    // 'overnight_boarding') en label de la langue courante. Mirror exact
    // du _serviceLabel(raw) côté Flutter PDF (invoice_pdf_generator.dart).
    const serviceLabelHtml = (raw) => {
      const s = String(raw || '').toLowerCase();
      if (s.includes('walk')) return T.serviceWalk;
      if (s.includes('day_care') || s.includes('garderie')) return T.serviceDaycare;
      if (s.includes('boarding') || s.includes('overnight')) return T.serviceBoarding;
      if (s.includes('sitting')) return T.serviceSitting;
      return raw ? esc(raw.replace(/_/g, ' ')) : T.serviceGeneric;
    };

    // Rôle du prestataire : traduit, jamais la valeur brute anglaise.
    const roleLabel = inv.providerRole === 'walker'
      ? T.roleWalker
      : inv.providerRole === 'sitter' ? T.roleSitter : inv.providerRole;

    const refunded = inv.status === 'refunded';
    const statusLabel = refunded ? T.statusRefunded : T.statusPaid;
    // Logo de la société, embarqué en base64 : aucun appel réseau à
    // l'impression. Absent (fichier illisible) → monogramme de repli.
    const issuerLogo = CARDELLI_LOGO_DATA_URI
      ? `<img class="issuer-logo" src="${CARDELLI_LOGO_DATA_URI}" alt="${esc(ISSUER_COMPANY.name)}" width="54" height="54" />`
      : '<div class="issuer-logo issuer-logo--fallback">CH</div>';
    // Logo de la marque (en-tête) : absent → seul le mot-symbole « HoPetSit »
    // reste, jamais d'image cassée.
    const brandLogo = HOPETSIT_LOGO_DATA_URI
      ? `<img class="brand-logo" src="${HOPETSIT_LOGO_DATA_URI}" alt="HoPetSit" width="48" height="48" />`
      : '';

    res.set('Content-Type', 'text/html; charset=utf-8');
    return res.send(`<!DOCTYPE html>
<html lang="${lang}">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>${esc(T.invoiceLabel)} ${esc(inv.invoiceNumber)} — HoPetSit</title>
<style>
  /* v576 — gabarit sobre, lisible en couleur comme en noir et blanc.
     Aucune dépendance externe : polices système, tout le CSS est inline.
     Rouge HoPetSit #C92A12 (la marque de l'app), noir/doré #C9A227
     (CARDELLI HERMANOS LIMITED, l'entité qui facture) — en touches. */
  :root {
    --brand: #C92A12;
    --gold: #C9A227;
    --ink: #17141F;
    --muted: #5B5B66;
    --rule: #DEDEE5;
    --soft: #F6F6F8;
  }
  * { box-sizing: border-box; }
  body {
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
    color: var(--ink);
    margin: 0;
    padding: 28px 20px 104px;
    background: #F2F2F5;
    -webkit-font-smoothing: antialiased;
  }
  .sheet {
    max-width: 780px; margin: 0 auto; background: #fff;
    border: 1px solid var(--rule); border-radius: 16px;
    padding: 34px 34px 26px;
  }
  /* En-tête : marque HoPetSit à gauche, identité du document à droite. */
  .head { display: flex; justify-content: space-between; align-items: flex-start; gap: 20px; }
  .brand { display: flex; align-items: center; gap: 12px; }
  .brand-logo { width: 48px; height: 48px; display: block; flex: 0 0 auto; border-radius: 11px; }
  .brand-name { font-size: 22px; font-weight: 800; letter-spacing: -0.01em; }
  .brand-sub { font-size: 10.5px; color: var(--muted); margin-top: 3px; line-height: 1.45; }
  .doc { text-align: right; }
  .doc-kind { font-size: 11px; font-weight: 700; letter-spacing: 0.14em; text-transform: uppercase; color: var(--brand); }
  .doc-num { font-size: 19px; font-weight: 800; margin-top: 2px; }
  .doc-row { font-size: 12px; color: var(--muted); margin-top: 3px; }
  .doc-row b { color: var(--ink); font-weight: 600; }
  .status {
    display: inline-block; margin-top: 8px; padding: 4px 12px; border-radius: 999px;
    font-size: 11px; font-weight: 800; text-transform: uppercase; letter-spacing: 0.05em;
    background: #ECF6EE; color: #1E6B33; border: 1px solid #1E6B33;
  }
  .status.refunded { background: #FDEDED; color: #A3261A; border-color: #A3261A; }
  .rule { height: 3px; background: var(--brand); border-radius: 2px; margin: 18px 0 22px; }
  /* Blocs Émetteur / Client / Prestataire. */
  .parties { display: grid; grid-template-columns: 1fr 1fr; gap: 16px; }
  .card { border: 1px solid var(--rule); border-radius: 12px; padding: 14px 16px; background: #fff; break-inside: avoid; }
  .card.issuer { background: var(--soft); border-left: 3px solid var(--gold); }
  .card.provider { grid-column: 1 / -1; }
  .card h3 {
    margin: 0 0 9px; font-size: 10px; font-weight: 800; letter-spacing: 0.12em;
    text-transform: uppercase; color: var(--muted);
  }
  .card .name { font-size: 14px; font-weight: 700; line-height: 1.35; }
  .card .line { font-size: 12px; color: var(--muted); margin-top: 3px; line-height: 1.45; }
  .card .line strong { color: var(--ink); font-weight: 600; }
  .issuer-head { display: flex; align-items: center; gap: 12px; }
  .issuer-logo { width: 54px; height: 54px; border-radius: 50%; display: block; flex: 0 0 auto; }
  .issuer-logo--fallback {
    background: #000; color: var(--gold); font-weight: 800; font-size: 19px;
    display: flex; align-items: center; justify-content: center; border: 2px solid var(--gold);
  }
  .pill {
    display: inline-block; padding: 2px 8px; border-radius: 999px; font-size: 9.5px;
    font-weight: 800; text-transform: uppercase; letter-spacing: 0.06em;
    border: 1px solid var(--rule); color: var(--muted); margin-left: 6px; vertical-align: 2px;
  }
  /* Tableau des lignes. */
  .section-title {
    margin: 26px 0 8px; font-size: 10px; font-weight: 800; letter-spacing: 0.12em;
    text-transform: uppercase; color: var(--muted);
  }
  table.items { width: 100%; border-collapse: collapse; break-inside: avoid; }
  table.items th {
    text-align: left; font-size: 10px; font-weight: 800; letter-spacing: 0.08em;
    text-transform: uppercase; color: var(--muted);
    padding: 0 10px 8px; border-bottom: 1px solid var(--ink);
  }
  table.items td { padding: 12px 10px; font-size: 13px; border-bottom: 1px solid var(--rule); vertical-align: top; }
  table.items th:first-child, table.items td:first-child { padding-left: 0; }
  table.items th:last-child, table.items td:last-child { padding-right: 0; text-align: right; white-space: nowrap; }
  /* Totaux. */
  .totals { width: 320px; margin: 18px 0 0 auto; border-collapse: collapse; break-inside: avoid; }
  .totals td { padding: 7px 0; font-size: 13px; }
  .totals td:first-child { color: var(--muted); }
  .totals td:last-child { text-align: right; font-weight: 600; white-space: nowrap; }
  .totals tr.grand td { font-size: 16px; font-weight: 800; border-top: 2px solid var(--ink); padding-top: 12px; }
  .totals tr.grand td:first-child { color: var(--ink); }
  /* Pied de page légal. */
  .legal { margin-top: 28px; padding-top: 14px; border-top: 1px solid var(--rule); break-inside: avoid; }
  .legal h4 {
    margin: 0 0 6px; font-size: 10px; font-weight: 800; letter-spacing: 0.12em;
    text-transform: uppercase; color: var(--muted);
  }
  .legal p { margin: 0 0 5px; font-size: 10.5px; color: var(--muted); line-height: 1.6; }
  .legal a { color: var(--brand); }
  /* Deux entrées « Télécharger PDF » : bandeau en haut (vu avant de faire
     défiler) et barre fixe en bas (à portée pendant la lecture). Les deux
     disparaissent à l'impression. */
  .cta {
    max-width: 780px; margin: 0 auto 16px; background: var(--brand); color: #fff;
    border-radius: 14px; padding: 12px 16px;
    display: flex; align-items: center; justify-content: space-between; gap: 12px;
  }
  .cta .label { font-weight: 700; font-size: 14px; }
  .cta button {
    background: #fff; color: var(--brand); border: 0; padding: 9px 18px; border-radius: 999px;
    font-size: 13px; font-weight: 800; cursor: pointer; -webkit-tap-highlight-color: transparent;
  }
  .download-bar {
    position: fixed; left: 0; right: 0; bottom: 0; padding: 12px 16px; background: #fff;
    border-top: 1px solid var(--rule); box-shadow: 0 -4px 12px rgba(0,0,0,0.08);
    text-align: center; z-index: 9999;
  }
  .download-bar button {
    background: var(--brand); color: #fff; border: 0; padding: 14px 32px; border-radius: 999px;
    font-size: 16px; font-weight: 800; cursor: pointer; width: 100%; max-width: 360px;
    -webkit-tap-highlight-color: transparent;
  }
  .download-bar button:active { transform: scale(0.97); }
  @media (max-width: 560px) {
    body { padding: 16px 12px 104px; }
    .sheet { padding: 20px 18px; border-radius: 12px; }
    .head { flex-direction: column; }
    .doc { text-align: left; }
    .parties { grid-template-columns: 1fr; }
    .totals { width: 100%; }
  }
  @media print {
    @page { size: A4; margin: 14mm; }
    body { background: #fff; padding: 0; }
    .sheet { max-width: none; border: 0; border-radius: 0; padding: 0; }
    .cta, .download-bar { display: none !important; }
    .card, table.items, .totals, .legal, .parties { break-inside: avoid; page-break-inside: avoid; }
    table.items thead { display: table-header-group; }
    .card.issuer { background: #fff; }
    a { color: var(--ink); text-decoration: none; }
  }
</style>
</head>
<body>
  <div class="cta">
    <span class="label">${esc(T.invoiceTitle)}</span>
    <button type="button" onclick="downloadInvoice()">${esc(T.downloadBtn)}</button>
  </div>

  <div class="sheet">
    <div class="head">
      <div class="brand">
        ${brandLogo}
        <div>
          <div class="brand-name">HoPetSit</div>
          <div class="brand-sub">${esc(T.operatedBy)} ${esc(ISSUER_COMPANY.name)}<br/>${esc(ISSUER_COMPANY.place)} · ${esc(T.companyNumber)}${esc(T.labelSep)}${esc(ISSUER_COMPANY.companyNumber)}</div>
        </div>
      </div>
      <div class="doc">
        <div class="doc-kind">${esc(T.invoiceLabel)}</div>
        <div class="doc-num">${esc(inv.invoiceNumber)}</div>
        <div class="doc-row">${esc(T.issued)}${esc(T.labelSep)}<b>${fmt(inv.issuedAt)}</b></div>
        <div class="doc-row">${esc(T.paid)}${esc(T.labelSep)}<b>${fmt(inv.paidAt)}</b></div>
        <span class="status${refunded ? ' refunded' : ''}">${esc(statusLabel)}</span>
      </div>
    </div>

    <div class="rule"></div>

    <div class="parties">
      <div class="card issuer">
        <h3>${esc(T.issuer)}</h3>
        <div class="issuer-head">
          ${issuerLogo}
          <div>
            <div class="name">${esc(ISSUER_COMPANY.name)}</div>
            <div class="line">${esc(ISSUER_COMPANY.place)}</div>
          </div>
        </div>
        <div class="line">${esc(T.companyNumber)}${esc(T.labelSep)}${esc(ISSUER_COMPANY.companyNumber)}</div>
        <div class="line">${esc(ISSUER_COMPANY.email)}</div>
      </div>
      <div class="card">
        <h3>${esc(T.customer)} · ${esc(T.billTo)}</h3>
        <div class="name">${esc(inv.ownerName || '—')}</div>
        ${inv.ownerEmail ? `<div class="line">${esc(inv.ownerEmail)}</div>` : ''}
        ${billingLines(customerB, inv.ownerName)}
      </div>
      <div class="card provider">
        <h3>${esc(T.serviceProvider)}${inv.providerRole ? `<span class="pill">${esc(roleLabel)}</span>` : ''}</h3>
        <div class="name">${esc(inv.providerName || '—')}</div>
        ${inv.providerEmail ? `<div class="line">${esc(inv.providerEmail)}</div>` : ''}
        ${billingLines(issuerB, inv.providerName)}
      </div>
    </div>

    <div class="section-title">${esc(T.summary)}</div>
    <table class="items">
      <thead>
        <tr>
          <th>${esc(T.description)}</th>
          <th>${esc(T.serviceDate)}</th>
          <th>${esc(T.pets)}</th>
          <th>${esc(T.amount)}</th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <td>${serviceLabelHtml(inv.serviceType)}</td>
          <td>${fmt(inv.serviceDate || inv.startDate)}${inv.endDate ? ' → ' + fmt(inv.endDate) : ''}</td>
          <td>${(inv.petNames && inv.petNames.length ? esc(inv.petNames.join(', ')) : '—')}</td>
          <td>${money(inv.grossAmount)}</td>
        </tr>
      </tbody>
    </table>

    <table class="totals">
      <tr>
        <td>${esc(T.grossAmount)}</td>
        <td>${money(inv.grossAmount)}</td>
      </tr>
      <tr>
        <td>${esc(T.commission)}</td>
        <td>${money(inv.commission)}</td>
      </tr>
      <tr>
        <td>${esc(T.netProvider)}</td>
        <td>${money(inv.netPayout)}</td>
      </tr>
      <tr class="grand">
        <td>${esc(T.totalCharged)}</td>
        <td>${money(inv.grossAmount)}</td>
      </tr>
    </table>

    <div class="legal">
      <h4>${esc(T.legalMentions)}</h4>
      <p>${esc(T.operatedBy)} ${esc(ISSUER_COMPANY.name)} · ${esc(ISSUER_COMPANY.place)} · ${esc(T.companyNumber)}${esc(T.labelSep)}${esc(ISSUER_COMPANY.companyNumber)} · ${esc(ISSUER_COMPANY.email)}</p>
      <p>${esc(T.footer)}</p>
      <p>${esc(T.escrowText)} ${esc(T.cancelTerms)} <a href="https://hopetsit.com/refund">https://hopetsit.com/refund</a>.</p>
    </div>
  </div>

  <div class="download-bar">
    <button type="button" onclick="downloadInvoice()" aria-label="${esc(T.downloadBtn)}">
      ${esc(T.downloadBtn)}
    </button>
  </div>

  <!-- v23.1 part 65 — Bug 7 : downloadInvoice() prefers the HoPetSit JS
       channel (registered by Flutter InvoiceViewerScreen) which pops out
       to the system browser where Save-as-PDF / Share work reliably.
       Falls back to window.print() when the page is opened in a regular
       browser (no HoPetSit channel registered). -->
  <script>
    // v576 — BUG : la page appelait « HoPetSit.postMessage », or le canal
    // enregistré par l'app s'appelle « Hopetsit » (invoice_viewer_screen.dart).
    // Les identifiants JS sont sensibles à la casse : le message n'arrivait
    // JAMAIS, on retombait sur window.print(), silencieux sur WebView Android
    // → « le bouton Télécharger ne marche pas ». On essaie les deux noms, donc
    // les apps DÉJÀ INSTALLÉES sont réparées sans rebuild.
    function invoiceChannel() {
      try { if (typeof Hopetsit !== 'undefined' && Hopetsit) return Hopetsit; } catch (_) { /* absent */ }
      try { if (typeof HoPetSit !== 'undefined' && HoPetSit) return HoPetSit; } catch (_) { /* absent */ }
      return null;
    }
    function downloadInvoice() {
      var ch = invoiceChannel();
      try {
        if (ch && typeof ch.postMessage === 'function') {
          ch.postMessage('download');
          return;
        }
      } catch (_) { /* on retombe sur l'impression du navigateur */ }
      try { window.print(); } catch (_) { /* dernier recours silencieux */ }
    }
  </script>
</body>
</html>`);
  } catch (err) {
    logger.error('[invoiceController.renderInvoiceHtml]', err);
    return sendInvoiceError(req, res, 500, 'errorServer');
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
    await ensureBillingSnapshots(invoices);
    return res.json({ invoices: invoices.map(_withBillingForApi), count: invoices.length });
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
  ensureBillingSnapshots,
  // v576 — exposés pour les tests (catalogue des libellés, logo embarqué).
  INVOICE_LOCALES,
  invoiceTexts,
  sendInvoiceError,
  CARDELLI_LOGO_DATA_URI,
  HOPETSIT_LOGO_DATA_URI,
  ISSUER_COMPANY,
};

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
const {
  resolveBillingInfoAcrossRoles,
  toBillingSnapshot,
  snapshotForApi,
  isSnapshotFrozen,
} = require('../utils/billingInfo');

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
      return res.status(404).send('Invoice not found');
    }
    const inv = await Invoice.findById(req.params.id).lean();
    if (!inv) return res.status(404).send('Invoice not found');

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
        return res.status(403).send('Access denied');
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
    const supported = ['en', 'fr', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl'];
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
      ko: {
        invoiceTitle: 'HoPetSit 청구서', invoiceLabel: '청구서', downloadBtn: '⬇ PDF 다운로드',
        billTo: '청구 대상 (보호자)', serviceProvider: '서비스 제공자',
        description: '내용', serviceDate: '서비스 날짜', pets: '반려동물',
        amount: '금액', issued: '발행일', paid: '결제일',
        grossAmount: '총액', commission: 'HoPetSit 플랫폼 수수료 (20%)',
        netProvider: '제공자 정산액', totalCharged: '보호자 결제 총액',
        footer: '결제는 Airwallex(PCI-DSS 레벨 1 인증)에서 처리됩니다. HoPetSit은 카드 정보에 접근하거나 전송·저장하지 않습니다.',
        cancelTerms: '서비스 시작 72시간 전까지 직접 취소 시 전액 환불됩니다. 자세히 보기:',
        escrowText: '결제 금액은 서비스 종료 후 24시간까지 에스크로로 보관된 뒤 제공자의 등록된 IBAN으로 지급됩니다.',
        serviceWalk: '반려견 산책', serviceDaycare: '데이케어',
        serviceBoarding: '숙박 돌봄', serviceSitting: '펫시팅',
        serviceGeneric: '서비스',
      },
      ja: {
        invoiceTitle: 'HoPetSit 請求書', invoiceLabel: '請求書', downloadBtn: '⬇ PDFをダウンロード',
        billTo: '請求先（飼い主）', serviceProvider: 'サービス提供者',
        description: '内容', serviceDate: 'サービス日', pets: 'ペット',
        amount: '金額', issued: '発行日', paid: '支払日',
        grossAmount: '総額', commission: 'HoPetSit プラットフォーム手数料 (20%)',
        netProvider: '提供者への支払額', totalCharged: '飼い主への請求総額',
        footer: '決済は Airwallex（PCI-DSS レベル1認定）が処理します。HoPetSit はカード情報へのアクセス・送信・保存を行いません。',
        cancelTerms: 'サービス開始の72時間前までのキャンセルは全額返金されます。詳細：',
        escrowText: '代金はサービス終了後24時間までエスクローで保管され、その後提供者の登録済み IBAN に支払われます。',
        serviceWalk: '犬の散歩', serviceDaycare: 'デイケア',
        serviceBoarding: 'お泊まり預かり', serviceSitting: 'ペットシッティング',
        serviceGeneric: 'サービス',
      },
      pl: {
        invoiceTitle: 'Faktura HoPetSit', invoiceLabel: 'Faktura', downloadBtn: '⬇ Pobierz PDF',
        billTo: 'Nabywca (właściciel)', serviceProvider: 'Usługodawca',
        description: 'Opis', serviceDate: 'Data usługi', pets: 'Zwierzęta',
        amount: 'Kwota', issued: 'Wystawiono', paid: 'Opłacono',
        grossAmount: 'Kwota brutto', commission: 'Prowizja platformy HoPetSit (20%)',
        netProvider: 'Kwota netto dla usługodawcy', totalCharged: 'Łączna kwota pobrana od właściciela',
        footer: 'Płatność obsługuje Airwallex (certyfikat PCI-DSS poziom 1). HoPetSit nie ma dostępu do danych karty, nie przesyła ich ani nie przechowuje.',
        cancelTerms: 'Samodzielne anulowanie z pełnym zwrotem jest możliwe do 72 godzin przed rozpoczęciem usługi. Zobacz',
        escrowText: 'Środki są przechowywane w depozycie do 24 godzin po zakończeniu usługi, a następnie wypłacane na zarejestrowany IBAN usługodawcy.',
        serviceWalk: 'Spacer z psem', serviceDaycare: 'Opieka dzienna',
        serviceBoarding: 'Opieka z noclegiem', serviceSitting: 'Pet-sitting',
        serviceGeneric: 'Usługa',
      },
    }[lang];

    // v566 — blocs « Émetteur » / « Client » (informations de facturation).
    const BT = {
      en: { issuer: 'Issuer', customer: 'Customer', vat: 'VAT No.', passport: 'Passport', companyNumber: 'Company No.', idOther: 'ID', business: 'Business', individual: 'Individual' },
      fr: { issuer: 'Émetteur', customer: 'Client', vat: 'N° TVA', passport: 'Passeport', companyNumber: "N° d'entreprise", idOther: 'Identifiant', business: 'Professionnel', individual: 'Particulier' },
      es: { issuer: 'Emisor', customer: 'Cliente', vat: 'N.º IVA', passport: 'Pasaporte', companyNumber: 'N.º de empresa', idOther: 'Identificador', business: 'Profesional', individual: 'Particular' },
      de: { issuer: 'Aussteller', customer: 'Kunde', vat: 'USt-IdNr.', passport: 'Reisepass', companyNumber: 'Handelsregisternr.', idOther: 'Kennnummer', business: 'Gewerblich', individual: 'Privatperson' },
      it: { issuer: 'Emittente', customer: 'Cliente', vat: 'P. IVA', passport: 'Passaporto', companyNumber: 'N. impresa', idOther: 'Identificativo', business: 'Professionista', individual: 'Privato' },
      pt: { issuer: 'Emitente', customer: 'Cliente', vat: 'N.º IVA', passport: 'Passaporte', companyNumber: 'N.º de empresa', idOther: 'Identificador', business: 'Profissional', individual: 'Particular' },
      ko: { issuer: '발행자', customer: '고객', vat: '부가세 번호', passport: '여권', companyNumber: '사업자 번호', idOther: '식별 번호', business: '사업자', individual: '개인' },
      ja: { issuer: '発行者', customer: '顧客', vat: 'VAT番号', passport: 'パスポート', companyNumber: '法人番号', idOther: '識別番号', business: '事業者', individual: '個人' },
      pl: { issuer: 'Wystawca', customer: 'Klient', vat: 'Nr VAT', passport: 'Paszport', companyNumber: 'Nr firmy', idOther: 'Identyfikator', business: 'Firma', individual: 'Osoba prywatna' },
    }[lang];
    const idTypeLabel = (t) => ({
      nif: 'NIF', nie: 'NIE', cif: 'CIF', siret: 'SIRET', ein: 'EIN',
      vat: BT.vat, passport: BT.passport, company_number: BT.companyNumber, other: BT.idOther,
    }[t] || BT.idOther);
    // Lignes d'un bloc : nom légal, « NIF : X… », n° TVA, adresse. Vide → ''.
    const billingLines = (b, accountName) => {
      if (!b) return '';
      const lines = [];
      // Nom légal identique au nom du compte (particulier) : pas de doublon.
      const sameName = String(b.legalName || '').trim().toLowerCase() === String(accountName || '').trim().toLowerCase();
      if (b.legalName && !(sameName && b.type !== 'business')) lines.push(`<div class="sub"><strong>${esc(b.legalName)}</strong>${b.type === 'business' ? ` · ${BT.business}` : ''}</div>`);
      if (b.idNumber) lines.push(`<div class="sub">${esc(idTypeLabel(b.idType))} : ${esc(b.idNumber)}</div>`);
      if (b.vatNumber && !(b.idType === 'vat' && b.vatNumber === b.idNumber)) lines.push(`<div class="sub">${BT.vat} : ${esc(b.vatNumber)}</div>`);
      const cityLine = [b.postalCode, b.city].filter(Boolean).join(' ');
      const addr = [b.address, cityLine, b.country].filter(Boolean).map(esc).join(', ');
      if (addr) lines.push(`<div class="sub">${addr}</div>`);
      return lines.join('\n      ');
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
      <h3>${BT.issuer} · ${T.serviceProvider} <span class="pill">${esc(inv.providerRole)}</span></h3>
      <div class="name">${esc(inv.providerName || '—')}</div>
      <div class="sub">${esc(inv.providerEmail || '')}</div>
      ${billingLines(issuerB, inv.providerName)}
    </div>
    <div class="card">
      <h3>${BT.customer} · ${T.billTo}</h3>
      <div class="name">${esc(inv.ownerName || '—')}</div>
      <div class="sub">${esc(inv.ownerEmail || '')}</div>
      ${billingLines(customerB, inv.ownerName)}
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
};

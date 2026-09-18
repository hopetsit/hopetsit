/**
 * v566 — Informations de facturation (Daniel, 18/09 : « CIF, NIE, NIF, SIRET,
 * n° de TVA, EIN, passeport, numéro d'entreprise… pour déclarer les factures »).
 *
 * Contrat (figé) :
 *   billingInfo = { type: 'individual'|'business', legalName,
 *     idType: 'nif'|'nie'|'cif'|'siret'|'vat'|'ein'|'passport'|'company_number'|'other',
 *     idNumber, vatNumber, address, postalCode, city, country (ISO-2), updatedAt }
 *   Tout est facultatif, chaînes bornées à 120 caractères, idNumber / vatNumber
 *   en majuscules sans espaces superflus. Stocké sur Owner / Sitter / Walker et
 *   synchronisé sur les 3 docs de la même personne (utils/identityGroup).
 *
 * Ce module ne dépend d'aucun contrôleur : il sert aux routes « moi-même »
 * (billingInfoController), aux factures (invoiceController) et à l'admin.
 */
const logger = require('./logger');

const BILLING_TYPES = ['individual', 'business'];
const BILLING_ID_TYPES = [
  'nif', 'nie', 'cif', 'siret', 'vat', 'ein', 'passport', 'company_number', 'other',
];
const BILLING_TEXT_FIELDS = ['legalName', 'idNumber', 'vatNumber', 'address', 'postalCode', 'city'];
const BILLING_FIELDS = ['type', 'legalName', 'idType', 'idNumber', 'vatNumber', 'address', 'postalCode', 'city', 'country'];
const BILLING_MAX_LEN = 120;

/** Champs Mongoose du sous-objet `billingInfo` (Owner / Sitter / Walker). */
const billingInfoSchemaFields = () => ({
  // ⚠️ un champ nommé `type` se déclare `type: { type: String }` en Mongoose.
  type: { type: String, default: 'individual' },
  legalName: { type: String, default: '', maxlength: BILLING_MAX_LEN },
  idType: { type: String, default: '' },
  idNumber: { type: String, default: '', maxlength: BILLING_MAX_LEN },
  vatNumber: { type: String, default: '', maxlength: BILLING_MAX_LEN },
  address: { type: String, default: '', maxlength: BILLING_MAX_LEN },
  postalCode: { type: String, default: '', maxlength: BILLING_MAX_LEN },
  city: { type: String, default: '', maxlength: BILLING_MAX_LEN },
  country: { type: String, default: '' },
  updatedAt: { type: Date, default: null },
});

/** Champs Mongoose d'un instantané de facture (Invoice.issuerBilling / customerBilling). */
const billingSnapshotSchemaFields = () => ({
  ...billingInfoSchemaFields(),
  // Date à laquelle l'instantané a été figé. null = pas encore figé (le
  // payeur / prestataire n'avait aucune donnée de facturation).
  snapshotAt: { type: Date, default: null },
});

// Texte libre : pas de caractères de contrôle, espaces repliés, 120 car. max.
const cleanText = (v) =>
  String(v == null ? '' : v)
    // eslint-disable-next-line no-control-regex
    .replace(/[\u0000-\u001F\u007F]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
    .slice(0, BILLING_MAX_LEN);

// Identifiants (NIF, SIRET, TVA…) : MAJUSCULES, espaces superflus retirés
// (un seul espace conservé entre deux blocs : « FR 12 345678901 » reste lisible).
const cleanIdNumber = (v) => cleanText(v).toUpperCase();

const cleanCountry = (v) => {
  const s = String(v == null ? '' : v).trim().toUpperCase();
  return /^[A-Z]{2}$/.test(s) ? s : '';
};

/** Objet COMPLET (champs vides si absents) à partir de n'importe quelle entrée. */
function normalizeBillingInfo(raw) {
  const r = raw && typeof raw === 'object' ? raw : {};
  const type = BILLING_TYPES.includes(String(r.type || '').toLowerCase())
    ? String(r.type).toLowerCase()
    : 'individual';
  const idType = BILLING_ID_TYPES.includes(String(r.idType || '').toLowerCase())
    ? String(r.idType).toLowerCase()
    : '';
  let updatedAt = null;
  if (r.updatedAt) {
    const d = new Date(r.updatedAt);
    if (!Number.isNaN(d.getTime())) updatedAt = d;
  }
  return {
    type,
    legalName: cleanText(r.legalName),
    idType,
    idNumber: cleanIdNumber(r.idNumber),
    vatNumber: cleanIdNumber(r.vatNumber),
    address: cleanText(r.address),
    postalCode: cleanText(r.postalCode),
    city: cleanText(r.city),
    country: cleanCountry(r.country),
    updatedAt,
  };
}

/** true si au moins un champ utile est renseigné (le `type` seul ne compte pas). */
function hasBillingData(b) {
  if (!b || typeof b !== 'object') return false;
  return ['legalName', 'idNumber', 'vatNumber', 'address', 'postalCode', 'city', 'country']
    .some((k) => String(b[k] || '').trim().length > 0);
}

/**
 * Corps PARTIEL → { value } (objet complet fusionné) ou { error }.
 * Seules les clés présentes dans `patch` sont modifiées ; '' ou null vide un champ.
 */
function mergeBillingInfo(current, patch) {
  const cur = normalizeBillingInfo(current);
  const p = patch && typeof patch === 'object' && !Array.isArray(patch) ? patch : null;
  if (!p) return { error: 'Body must be an object.' };

  for (const k of Object.keys(p)) {
    // Clés inconnues (ou `updatedAt`, posé par le serveur) : IGNORÉES, jamais
    // de 400 — un client plus récent ne doit pas voir son PATCH partiel refusé.
    if (!BILLING_FIELDS.includes(k)) continue;
    const v = p[k];
    if (v !== null && v !== undefined && typeof v !== 'string' && typeof v !== 'number') {
      return { error: `${k} must be a string.` };
    }
  }

  const next = { ...cur };
  if (p.type !== undefined) {
    const t = String(p.type == null ? '' : p.type).toLowerCase().trim();
    if (t === '') next.type = 'individual';
    else if (!BILLING_TYPES.includes(t)) return { error: `type must be one of: ${BILLING_TYPES.join(', ')}.` };
    else next.type = t;
  }
  if (p.idType !== undefined) {
    const t = String(p.idType == null ? '' : p.idType).toLowerCase().trim();
    if (t !== '' && !BILLING_ID_TYPES.includes(t)) {
      return { error: `idType must be one of: ${BILLING_ID_TYPES.join(', ')}.` };
    }
    next.idType = t;
  }
  if (p.country !== undefined) {
    const raw = String(p.country == null ? '' : p.country).trim();
    if (raw !== '' && !cleanCountry(raw)) return { error: 'country must be an ISO 3166-1 alpha-2 code (e.g. "FR").' };
    next.country = cleanCountry(raw);
  }
  for (const k of BILLING_TEXT_FIELDS) {
    if (p[k] === undefined) continue;
    if (String(p[k] == null ? '' : p[k]).length > 400) return { error: `${k} is too long.` };
    next[k] = k === 'idNumber' || k === 'vatNumber' ? cleanIdNumber(p[k]) : cleanText(p[k]);
  }
  next.updatedAt = new Date();
  return { value: next };
}

const _models = () => ({
  Owner: require('../models/Owner'),
  Sitter: require('../models/Sitter'),
  Walker: require('../models/Walker'),
});

/**
 * Données de facturation d'une PERSONNE, quel que soit le profil interrogé.
 * 1) le doc demandé ; 2) sinon un profil frère (même e-mail / oldId) — cas d'un
 * profil créé APRÈS la saisie (switchRole). On retient la saisie la plus récente.
 * Retourne toujours un objet complet (champs vides si rien).
 */
async function resolveBillingInfoAcrossRoles(userId, preferredModel) {
  const M = _models();
  const id = String(userId || '');
  if (!id) return normalizeBillingInfo(null);
  try {
    const order = ['Owner', 'Sitter', 'Walker'];
    if (preferredModel && order.includes(preferredModel)) {
      order.splice(order.indexOf(preferredModel), 1);
      order.unshift(preferredModel);
    }
    let me = null;
    for (const name of order) {
      // eslint-disable-next-line no-await-in-loop
      me = await M[name].findById(id).select('email oldId billingInfo').lean().catch(() => null);
      if (me) break;
    }
    if (!me) return normalizeBillingInfo(null);
    if (hasBillingData(me.billingInfo)) return normalizeBillingInfo(me.billingInfo);

    const or = [];
    if (me.email) or.push({ email: me.email });
    if (me.oldId != null) or.push({ oldId: me.oldId });
    if (!or.length) return normalizeBillingInfo(me.billingInfo);
    const lists = await Promise.all(
      ['Owner', 'Sitter', 'Walker'].map((n) => M[n].find({ $or: or }).select('billingInfo').lean().catch(() => [])),
    );
    const candidates = [].concat(...lists)
      .map((d) => d && d.billingInfo)
      .filter(hasBillingData)
      .map(normalizeBillingInfo)
      .sort((a, b) => (b.updatedAt ? b.updatedAt.getTime() : 0) - (a.updatedAt ? a.updatedAt.getTime() : 0));
    return candidates[0] || normalizeBillingInfo(me.billingInfo);
  } catch (e) {
    logger.warn(`[billingInfo] resolve failed for ${id}: ${e.message}`);
    return normalizeBillingInfo(null);
  }
}

/** Écrit l'objet sur les 3 docs de la même personne. Retourne le nombre de docs touchés. */
async function writeBillingInfoAcrossRoles(userId, value) {
  const { identityGroup } = require('./identityGroup');
  const M = _models();
  const g = await identityGroup(userId);
  const results = await Promise.all(
    g.docs.map((d) => (M[d.model] ? M[d.model].updateOne({ _id: d.id }, { $set: { billingInfo: value } }) : null)),
  );
  return results.filter(Boolean).length;
}

/** Instantané figé pour une facture (null si la personne n'a aucune donnée). */
function toBillingSnapshot(billing, at) {
  if (!hasBillingData(billing)) return null;
  return { ...normalizeBillingInfo(billing), snapshotAt: at || new Date() };
}

/** Forme API d'un instantané (champs vides si absent) — jamais `undefined`. */
function snapshotForApi(snap) {
  const n = normalizeBillingInfo(snap);
  return { ...n, snapshotAt: snap && snap.snapshotAt ? snap.snapshotAt : null };
}

const isSnapshotFrozen = (snap) => !!(snap && snap.snapshotAt);

module.exports = {
  BILLING_TYPES,
  BILLING_ID_TYPES,
  BILLING_FIELDS,
  BILLING_MAX_LEN,
  billingInfoSchemaFields,
  billingSnapshotSchemaFields,
  normalizeBillingInfo,
  mergeBillingInfo,
  hasBillingData,
  resolveBillingInfoAcrossRoles,
  writeBillingInfoAcrossRoles,
  toBillingSnapshot,
  snapshotForApi,
  isSnapshotFrozen,
};

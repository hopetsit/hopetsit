'use strict';

/**
 * 607 (NEO, 02/10/2026) — CE QUE MONTRE LA PAGE PUBLIQUE /s/<slug>.
 *
 * Liste BLANCHE : uniquement ce que la fiche publique /p/<rôle>/<id> montre
 * déjà à tout le monde. Le nom passe par la projection de ZOE
 * (publicListEntry607b → « Prénom I. »). AUCUNE position (ni exacte ni
 * floutée : la ville suffit), aucun e-mail, téléphone, date de naissance,
 * adresse, préférence, code de parrainage, jeton ou donnée de paiement.
 * Contrat écrit pour LEO : ~/hopetsit-social/CONTRAT_607_lien_perso.md.
 */
const { toPublicListEntry } = require('./publicListEntry607b');

const SITE = 'https://www.hopetsit.com';
const MAX_REVIEWS = 5;

const num = (v) => (Number.isFinite(Number(v)) ? Number(v) : 0);

function cityOfDoc(d) {
  const raw = (d.homeLocation && d.homeLocation.city) || d.city
    || (d.location && d.location.city) || d.coverageCity || '';
  return require('./publicCity607').publicCity(raw);
}

function ratesOf(d, role) {
  const cur = d.currency || 'EUR';
  if (role === 'walker') {
    return (Array.isArray(d.walkRates) ? d.walkRates : [])
      .filter((r) => r && r.enabled !== false && num(r.basePrice) > 0)
      .sort((a, b) => num(a.durationMinutes) - num(b.durationMinutes))
      .map((r) => ({
        unit: 'walk',
        durationMinutes: num(r.durationMinutes),
        amount: num(r.basePrice),
        currency: r.currency || cur,
      }));
  }
  const out = [];
  for (const [unit, field] of [['hour', 'hourlyRate'], ['day', 'dailyRate'], ['week', 'weeklyRate'], ['month', 'monthlyRate']]) {
    if (num(d[field]) > 0) out.push({ unit, amount: num(d[field]), currency: cur });
  }
  return out;
}

/**
 * @param {object} doc     Sitter ou Walker (lean ou mongoose)
 * @param {'sitter'|'walker'} role
 * @param {object} extra   { reviews: [Review lean, reviewer peuplé], isPioneer, indexable }
 */
function toPublicProvider(doc, role, extra = {}) {
  const d = doc && typeof doc.toObject === 'function' ? doc.toObject() : (doc || {});
  const id = String(d._id || '');
  const named = toPublicListEntry(d, {
    id, name: d.name || '', firstName: d.firstName || '', lastName: d.lastName || '',
  });
  const reviews = (extra.reviews || []).slice(0, MAX_REVIEWS).map((r) => {
    const who = r.reviewerId && typeof r.reviewerId === 'object' ? r.reviewerId : {};
    const n = toPublicListEntry(null, {
      name: who.name || '', firstName: who.firstName || '', lastName: who.lastName || '',
    });
    return {
      rating: num(r.rating),
      comment: String(r.comment || ''),
      reviewerName: (n && n.name) || '',
      createdAt: r.createdAt || null,
    };
  });
  const rating = num(d.averageRating || d.rating);
  const slug = d.publicSlug || '';
  return {
    slug,
    url: slug ? `${SITE}/s/${slug}` : '',
    role,
    id,
    profilePath: `/p/${role}/${id}`,
    name: named.name,
    firstName: named.firstName,
    photo: (d.avatar && d.avatar.url) || '',
    city: cityOfDoc(d),
    bio: String(d.bio || ''),
    services: Array.isArray(d.service) ? d.service.filter(Boolean) : (d.service ? [d.service] : []),
    acceptedPetTypes: Array.isArray(d.acceptedPetTypes) ? d.acceptedPetTypes : [],
    rates: ratesOf(d, role),
    rating: Math.round(rating * 10) / 10,
    reviewsCount: Math.max(num(d.reviewsCount), reviews.length),
    reviews,
    // 02/10 (FLO) — le badge du site s'appelle « Identité vérifiée »
    // (trust_id_title) mais lisait `verified`, qui est le drapeau « E-MAIL
    // vérifié » : 38 prestataires (22 gardiens, 16 promeneurs) l'auraient
    // affiché sans aucune vérification d'identité. Même règle que l'app.
    verified: d.kycStatus === 'verified'
      || !!(d.identityVerification && d.identityVerification.status === 'verified'),
    isPioneer: extra.isPioneer === true,
    // 611 (PAM, demande LEO) — rang Chiot → Légende ; champ absent = Chiot.
    rank: require('../services/ranks611').rankFor(d.pawPoints),
    indexable: extra.indexable !== false,
  };
}

/** Toutes les clés que la réponse publique a le droit de porter. */
const PUBLIC_PROVIDER_KEYS = [
  'slug', 'url', 'role', 'id', 'profilePath', 'name', 'firstName', 'photo', 'city',
  'bio', 'services', 'acceptedPetTypes', 'rates', 'rating', 'reviewsCount',
  'reviews', 'verified', 'isPioneer', 'indexable', 'rank', // 611 — rang (Chiot → Légende)
];

module.exports = { toPublicProvider, ratesOf, cityOfDoc, PUBLIC_PROVIDER_KEYS, SITE };

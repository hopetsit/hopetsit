/**
 * 612 §8 (ZOE, 05/10/2026) — UNE DEMANDE SANS ANIMAL ENREGISTRÉ NE POUVAIT RECEVOIR
 * AUCUNE CANDIDATURE.
 *
 * MESURÉ (scripts/mesure_circuit_612.js --sans-animal) : depuis l'app 600 et depuis le
 * SITE (formulaire sans compte), un propriétaire publie avec `petIds: []` +
 * `animalTypes` / `animalCount`. Les prestataires étaient bien prévenus… puis
 * `POST /applications` répondait 400 « petIds (or petId) is required » ; dans l'app
 * (accueil, fiche, PawMap) le bouton restait gris ou affichait « Cette demande n'a pas
 * d'animal rattaché ». Le circuit de l'argent s'arrêtait là, pour TOUTES les versions.
 *
 * Correctif côté serveur, valable pour les apps déjà installées : une demande a
 * toujours un animal. Si le propriétaire n'en a aucun, on crée une fiche minimale à
 * partir de l'espèce déclarée (« Chien », « Chat »…), marquée `autoCreated` — il la
 * complète ou la supprime quand il veut. S'il a déjà des animaux, rien n'est créé
 * (l'annonce montre déjà ses animaux : repli historique de resolvePostPets).
 */
const logger = require('./logger');

const SPECIES = ['dog', 'cat', 'nac', 'bird', 'reptile', 'other'];
const NAMES = {
  dog: { fr: 'Chien', en: 'Dog', es: 'Perro', de: 'Hund', it: 'Cane', pt: 'Cão', ko: '강아지', ja: '犬', pl: 'Pies' },
  cat: { fr: 'Chat', en: 'Cat', es: 'Gato', de: 'Katze', it: 'Gatto', pt: 'Gato', ko: '고양이', ja: '猫', pl: 'Kot' },
  nac: { fr: 'NAC', en: 'Small pet', es: 'Mascota pequeña', de: 'Kleintier', it: 'Piccolo animale', pt: 'Animal pequeno', ko: '소동물', ja: '小動物', pl: 'Małe zwierzę' },
  bird: { fr: 'Oiseau', en: 'Bird', es: 'Pájaro', de: 'Vogel', it: 'Uccello', pt: 'Pássaro', ko: '새', ja: '鳥', pl: 'Ptak' },
  reptile: { fr: 'Reptile', en: 'Reptile', es: 'Reptil', de: 'Reptil', it: 'Rettile', pt: 'Réptil', ko: '파충류', ja: '爬虫類', pl: 'Gad' },
  other: { fr: 'Mon animal', en: 'My pet', es: 'Mi mascota', de: 'Mein Tier', it: 'Il mio animale', pt: 'O meu animal', ko: '내 반려동물', ja: 'うちの子', pl: 'Mój zwierzak' },
};
const LOCALES = ['fr', 'en', 'es', 'de', 'it', 'pt', 'ko', 'ja', 'pl'];

const firstSpecies = (animalTypes) => {
  let list = animalTypes;
  if (typeof list === 'string') {
    try { const p = JSON.parse(list); list = Array.isArray(p) ? p : [list]; } catch (_) { list = list.split(','); }
  }
  for (const raw of (Array.isArray(list) ? list : [])) {
    const s = String(raw || '').trim().toLowerCase();
    if (SPECIES.includes(s)) return s;
  }
  return 'other';
};
const localeOf = (owner) => {
  const l = String((owner && (owner.appLocale || owner.language)) || '').toLowerCase().slice(0, 2);
  return LOCALES.includes(l) ? l : 'fr';
};
const placeholderName = (species, locale) => (NAMES[species] || NAMES.other)[LOCALES.includes(locale) ? locale : 'fr'];

/**
 * Animal à rattacher à une demande publiée sans animal. Renvoie l'id (String) ou
 * null. Ne lève jamais. `dryRun` : dit ce qui serait fait, n'écrit rien.
 */
const ensureOwnerPet = async ({ ownerId, owner = null, animalTypes = [], dryRun = false }) => {
  try {
    if (!ownerId) return null;
    const Pet = require('../models/Pet');
    const existing = await Pet.find({ ownerId }).select('_id category autoCreated').sort({ createdAt: -1 }).lean();
    const species = firstSpecies(animalTypes);
    if (existing.length) {
      // Il a déjà des animaux : on rattache celui de la bonne espèce, sinon le plus récent.
      const same = existing.find((p) => String(p.category || '').toLowerCase() === species);
      return { id: String((same || existing[0])._id), created: false };
    }
    if (dryRun) return { id: null, created: true, species };
    let ownerDoc = owner;
    if (!ownerDoc) {
      try { ownerDoc = await require('../models/Owner').findById(ownerId).select('appLocale language').lean(); } catch (_) { ownerDoc = null; }
    }
    const pet = await Pet.create({
      ownerId,
      petName: placeholderName(species, localeOf(ownerDoc)),
      category: species,
      autoCreated: true,
    });
    logger.info(`[postPet612] fiche animal minimale créée pour le propriétaire ${ownerId} (${species})`);
    return { id: String(pet._id), created: true, species };
  } catch (e) {
    logger.warn(`[postPet612] animal non rattaché : ${e && e.message ? e.message : e}`);
    return null;
  }
};

/** Complète `postPayload` (avant Post.create) quand la demande n'a aucun animal. */
const attachPetToPayload = async (postPayload, { owner, animalTypes }) => {
  if (!postPayload || postPayload.postType !== 'request') return false;
  const has = (Array.isArray(postPayload.petIds) && postPayload.petIds.length > 0) || !!postPayload.petId;
  if (has) return false;
  const r = await ensureOwnerPet({ ownerId: postPayload.ownerId, owner, animalTypes: animalTypes || postPayload.animalTypes });
  if (!r || !r.id) return false;
  postPayload.petIds = [r.id];
  postPayload.petId = r.id;
  return true;
};

/** Répare une demande DÉJÀ publiée sans animal (candidature, rattrapage admin). */
const attachPetToExistingPost = async (post, { dryRun = false } = {}) => {
  if (!post || (post.postType && post.postType !== 'request')) return null;
  const has = (Array.isArray(post.petIds) && post.petIds.length > 0) || !!post.petId;
  if (has) return null;
  const r = await ensureOwnerPet({ ownerId: post.ownerId && (post.ownerId._id || post.ownerId), animalTypes: post.animalTypes, dryRun });
  if (!r) return null;
  if (!dryRun && r.id) {
    await require('../models/Post').updateOne({ _id: post._id }, { $set: { petIds: [r.id], petId: r.id } });
  }
  return r;
};

module.exports = { SPECIES, NAMES, firstSpecies, placeholderName, ensureOwnerPet, attachPetToPayload, attachPetToExistingPost };

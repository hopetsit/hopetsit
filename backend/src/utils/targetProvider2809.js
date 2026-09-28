/**
 * 28/09/2026 (NEO, mission BOB validée par Daniel) — « Demander à Sasha ».
 *
 * Le bouton « Demander à <prénom> » du site (carte publique, fiche /p/…)
 * ouvrait la demande de NEO, mais le serveur ne savait pas À QUI elle
 * s'adressait : elle partait à tous les prestataires de la ville, et une
 * phrase le disait sous le bouton. Désormais une demande peut porter un
 * prestataire ciblé, facultatif :
 *
 *   targetProvider: { role: 'sitter' | 'walker', id: '<ObjectId>' }
 *
 * accepté en JSON (POST /posts) ou en chaîne JSON (multipart, /posts/with-media).
 * Règle : rôle connu ET id existant, sinon le ciblage est IGNORÉ sans rien
 * casser (la demande part quand même à la ville). Le prestataire ciblé reçoit
 * une notification distincte et prioritaire (« <Prénom> vous a choisi »), en
 * plus de la diffusion ville habituelle, et jamais deux fois.
 */
const mongoose = require('mongoose');

const TARGET_ROLES = new Set(['sitter', 'walker']);

/**
 * Lecture pure du champ (objet ou chaîne JSON). Renvoie { role, id } ou null.
 * Ne touche pas à la base : l'existence se vérifie dans resolveTargetProvider.
 */
const parseTargetProvider = (raw) => {
  let v = raw;
  if (v == null || v === '') return null;
  if (typeof v === 'string') {
    try { v = JSON.parse(v); } catch (_) { return null; }
  }
  if (!v || typeof v !== 'object' || Array.isArray(v)) return null;
  const role = String(v.role || '').trim().toLowerCase();
  const id = String(v.id || v._id || '').trim();
  if (!TARGET_ROLES.has(role)) return null;
  if (!mongoose.Types.ObjectId.isValid(id) || !/^[a-f0-9]{24}$/i.test(id)) return null;
  return { role, id };
};

/**
 * Vérifie que le prestataire existe. Renvoie { role, id } ou null.
 * Un échec de base est traité comme « inconnu » : jamais d'erreur remontée,
 * la publication de la demande ne dépend pas du ciblage.
 */
const resolveTargetProvider = async (raw) => {
  const parsed = parseTargetProvider(raw);
  if (!parsed) return null;
  try {
    const Model = parsed.role === 'walker'
      ? require('../models/Walker')
      : require('../models/Sitter');
    const found = await Model.findById(parsed.id).select('_id').lean();
    return found ? parsed : null;
  } catch (_) {
    return null;
  }
};

/** Forme renvoyée par sanitizePost : { role, id } ou null. */
const publicTargetProvider = (doc) => {
  const tp = doc && doc.targetProvider;
  if (!tp || !tp.id || !TARGET_ROLES.has(String(tp.role || ''))) return null;
  return { role: String(tp.role), id: String(tp.id) };
};

module.exports = { parseTargetProvider, resolveTargetProvider, publicTargetProvider, TARGET_ROLES };

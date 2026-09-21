/**
 * v576 — « Aucun e-mail ajouté » alors que le compte A un e-mail (Daniel,
 * 21/09/2026).
 *
 * CAUSE RACINE. L'écran « Modifier le profil » du GARDIEN se charge par
 * `GET /sitters/:id`, qui est la fiche PUBLIQUE. Depuis la v535 (fuite de
 * données corrigée), cette fiche renvoie volontairement
 * `email: '', mobile: '', countryCode: '', address: ''` — à n'importe qui,
 * y compris au gardien lui-même. L'app affichait donc « Aucun e-mail
 * ajouté », puis renvoyait `email: ''` à l'enregistrement, et le serveur
 * refusait tout ("Email must be a non-empty string").
 *
 * Le propriétaire (`GET /users/me/profile`) et le promeneur
 * (`GET /walkers/me`) passent déjà par `sanitizeUser({ includeEmail: true })`
 * : eux voyaient bien leur e-mail. Seul le gardien était aveugle.
 *
 * Ici : les champs privés ne sortent que lorsque le lecteur EST la personne
 * (son propre id, ou l'un des ids de son groupe d'identité owner/sitter/
 * walker). Fonction PURE, donc testable sans base ni réseau.
 */

/** Champs privés servis à la personne elle-même seulement. */
const SITTER_PRIVATE_FIELDS = [
  'email',
  'mobile',
  'countryCode',
  'address',
  'country',
  'postalCode',
];

const str = (v) => (v === null || v === undefined ? '' : String(v));

/**
 * Bloc de champs privés à fusionner dans la fiche gardien.
 *
 * @param {object} sitter  document Sitter (mongoose doc ou objet lean)
 * @param {boolean} isSelf le lecteur est-il cette personne ?
 * @returns {object} toujours les mêmes clés — vides quand `isSelf` est faux,
 *                   pour que la forme de la réponse publique ne change pas.
 */
function sitterSelfPrivateFields(sitter, isSelf) {
  const out = {};
  for (const field of SITTER_PRIVATE_FIELDS) {
    out[field] = isSelf && sitter ? str(sitter[field]).trim() : '';
  }
  return out;
}

/**
 * Le lecteur est-il la personne dont on lit la fiche ?
 *
 * @param {Set<string>|null} selfIds ids du groupe d'identité du lecteur
 * @param {string} targetId id de la fiche lue
 */
function isSelfProfile(selfIds, targetId) {
  if (!selfIds || typeof selfIds.has !== 'function') return false;
  if (!targetId) return false;
  return selfIds.has(String(targetId));
}

module.exports = {
  SITTER_PRIVATE_FIELDS,
  sitterSelfPrivateFields,
  isSelfProfile,
};

/**
 * 28/09/2026 — Daniel : « oui fais-le ». Sur la fiche PUBLIQUE d'un gardien ou
 * d'un promeneur, le nom de famille complet sortait (champ `lastName` et nom
 * affiché `name`). Pour tout autre lecteur que la personne elle-même : prénom
 * + initiale du nom (« Sasha B. »). La personne elle-même garde son nom
 * complet (écran « Modifier le profil »).
 */
const initialOf = (s) => {
  const t = String(s || '').trim();
  return t ? `${Array.from(t)[0].toUpperCase()}.` : '';
};

const publicNameFields = ({ name, firstName, lastName }) => {
  let first = String(firstName || '').trim();
  let last = String(lastName || '').trim();
  if (!first) {
    // Anciens comptes : seul `name` existe (« Prénom Nom … »).
    const parts = String(name || '').trim().split(/\s+/).filter(Boolean);
    first = parts[0] || '';
    if (!last) last = parts.slice(1).join(' ');
  }
  const initial = initialOf(last);
  return {
    name: [first, initial].filter(Boolean).join(' '),
    firstName: first,
    lastName: initial,
  };
};

/** Applique la règle sur un objet réponse (modifié sur place). */
const applyPublicName = (payload) => {
  if (!payload) return payload;
  Object.assign(payload, publicNameFields(payload));
  return payload;
};

module.exports = { publicNameFields, applyPublicName };

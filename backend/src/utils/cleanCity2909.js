/**
 * 29/09/2026 (NEO, mission BOB) — GARDE-FOU « VILLE = ADRESSE E-MAIL ».
 *
 * Relevé du 29/09 dans l'admin : un propriétaire inscrit par Google (Android,
 * build 598) a pour ville « quelquechose@gmail.com » — le champ ville a reçu
 * une adresse e-mail (saisie ou remplissage automatique du téléphone) et le
 * serveur l'a enregistrée telle quelle. Conséquences : aucun gardien prévenu
 * pour cette « ville », une adresse e-mail exposée là où la ville s'affiche
 * (PawMap, fiche), et un compte qui passe le contrôle « ville obligatoire »
 * sans en avoir une.
 *
 * Règle : une ville qui contient « @ » n'est PAS une ville → chaîne vide, et
 * le contrôle CITY_REQUIRED des apps ≥ 565 redemande la ville. Aucune donnée
 * retirée : une vraie ville passe inchangée (accents, tirets, apostrophes,
 * « Paris 11e », « Saint-Germain-en-Laye »…).
 */
const cleanCity = (value) => {
  const v = (value == null ? '' : String(value)).trim();
  if (!v) return '';
  if (v.includes('@')) return '';
  return v;
};

module.exports = { cleanCity };

/**
 * v591 — audit du 26/09 : en multipart (annonce avec photo) l'app envoie
 * `petIds` en TEXTE JSON (« ["a","b"] ») ; le serveur n'acceptait qu'un
 * tableau et ne gardait que le premier animal. Renvoie toujours un tableau.
 */
function parsePetIds(v) {
  if (Array.isArray(v)) return v.map(String).filter(Boolean);
  if (typeof v !== 'string' || !v.trim()) return [];
  try {
    const parsed = JSON.parse(v);
    return (Array.isArray(parsed) ? parsed : [parsed]).map(String).filter(Boolean);
  } catch (_) {
    return v.split(',').map((x) => x.trim()).filter(Boolean);
  }
}

module.exports = { parsePetIds };

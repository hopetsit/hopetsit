// 1011 (BOB, 10/11/2026 — plan validé par Daniel « il faut que les gens concluent ») —
// précisions FACULTATIVES d'une demande, nées du cas réel d'une propriétaire qui avait
// besoin d'une garde EN JOURNÉE (10 h – 18 h 30), sans voiture, et ne pouvait le dire nulle part :
//   · timeFrom / timeTo : heures « HH:MM » (24 h) ;
//   · ownerNoCar        : le propriétaire n'a pas de voiture (le gardien vient chercher l'animal).
//
// RÉTROCOMPATIBLE : champ absent → rien à écrire ; heure invalide → ignorée, jamais un 400.
const HHMM = /^([01]\d|2[0-3]):[0-5]\d$/;

/** « 9:30 » → « 09:30 » ; valeur illisible → null ; vide → ''. */
function cleanTime(v) {
  const s = String(v == null ? '' : v).trim();
  if (!s) return '';
  const m = /^(\d{1,2})[:hH](\d{2})$/.exec(s);
  if (!m) return null;
  const out = `${m[1].padStart(2, '0')}:${m[2]}`;
  return HHMM.test(out) ? out : null;
}

/** true / 'true' / 1 / '1' → true ; false / 'false' / 0 / '0' → false ; autre → null. */
function toBool(v) {
  if (v === true || v === 'true' || v === 1 || v === '1') return true;
  if (v === false || v === 'false' || v === 0 || v === '0') return false;
  return null;
}

/**
 * Champs à écrire à partir du corps de requête (création ou modification).
 * Absent ou invalide → clé absente (rien ne change) ; heure vide → '' (effacée).
 */
function resolveExtras(body) {
  const b = body || {};
  const out = {};
  for (const k of ['timeFrom', 'timeTo']) {
    if (!Object.prototype.hasOwnProperty.call(b, k)) continue;
    const t = cleanTime(b[k]);
    if (t !== null) out[k] = t;
  }
  if (Object.prototype.hasOwnProperty.call(b, 'ownerNoCar')) {
    const v = toBool(b.ownerNoCar);
    if (v !== null) out.ownerNoCar = v;
  }
  return out;
}

/** Champs publics d'une demande (toujours présents, valeurs neutres par défaut). */
function publicExtras(post) {
  const p = post || {};
  return {
    timeFrom: HHMM.test(String(p.timeFrom || '')) ? p.timeFrom : '',
    timeTo: HHMM.test(String(p.timeTo || '')) ? p.timeTo : '',
    ownerNoCar: p.ownerNoCar === true,
  };
}

/** Phrase lisible par une ANCIENNE app (ajoutée au texte de la demande). '' si rien à dire. */
function extrasSentence({ timeFrom, timeTo, noCar } = {}, lang = 'fr') {
  const fr = lang === 'fr';
  const f = cleanTime(timeFrom) || '';
  const t = cleanTime(timeTo) || '';
  const h = (x) => (fr ? x.replace(':', ' h ').replace(/ h 00$/, ' h') : x);
  const parts = [];
  if (f && t) parts.push(fr ? `Horaires : de ${h(f)} à ${h(t)}.` : `Hours: ${f} to ${t}.`);
  else if (f) parts.push(fr ? `À partir de ${h(f)}.` : `From ${f}.`);
  else if (t) parts.push(fr ? `Jusqu'à ${h(t)}.` : `Until ${t}.`);
  if (noCar === true) parts.push(fr ? "Je n'ai pas de voiture." : "I don't have a car.");
  return parts.join(' ');
}

module.exports = { resolveExtras, publicExtras, extrasSentence, cleanTime, toBool, HHMM };

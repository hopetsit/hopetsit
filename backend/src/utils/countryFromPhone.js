/**
 * countryFromPhone — v23.1.365 (Daniel : "dans le classement Pays rien
 * n'apparaît, les pays ne sont pas configurés").
 *
 * Les comptes n'ont pas de champ pays dédié, mais TOUS ont `countryCode`
 * (indicatif téléphonique choisi à l'inscription, ex. "+34"). On en dérive
 * le pays (drapeau + nom) pour le classement PawSpot et l'admin.
 */

const MAP = Object.freeze({
  '33': { iso: 'FR', flag: '🇫🇷', name: 'France' },
  '34': { iso: 'ES', flag: '🇪🇸', name: 'España' },
  '39': { iso: 'IT', flag: '🇮🇹', name: 'Italia' },
  '49': { iso: 'DE', flag: '🇩🇪', name: 'Deutschland' },
  '351': { iso: 'PT', flag: '🇵🇹', name: 'Portugal' },
  '44': { iso: 'GB', flag: '🇬🇧', name: 'United Kingdom' },
  '41': { iso: 'CH', flag: '🇨🇭', name: 'Suisse' },
  '32': { iso: 'BE', flag: '🇧🇪', name: 'Belgique' },
  '31': { iso: 'NL', flag: '🇳🇱', name: 'Nederland' },
  '352': { iso: 'LU', flag: '🇱🇺', name: 'Luxembourg' },
  '43': { iso: 'AT', flag: '🇦🇹', name: 'Österreich' },
  '353': { iso: 'IE', flag: '🇮🇪', name: 'Ireland' },
  '30': { iso: 'GR', flag: '🇬🇷', name: 'Ελλάδα' },
  '48': { iso: 'PL', flag: '🇵🇱', name: 'Polska' },
  '420': { iso: 'CZ', flag: '🇨🇿', name: 'Česko' },
  '46': { iso: 'SE', flag: '🇸🇪', name: 'Sverige' },
  '47': { iso: 'NO', flag: '🇳🇴', name: 'Norge' },
  '45': { iso: 'DK', flag: '🇩🇰', name: 'Danmark' },
  '358': { iso: 'FI', flag: '🇫🇮', name: 'Suomi' },
  '36': { iso: 'HU', flag: '🇭🇺', name: 'Magyarország' },
  '40': { iso: 'RO', flag: '🇷🇴', name: 'România' },
  '359': { iso: 'BG', flag: '🇧🇬', name: 'България' },
  '385': { iso: 'HR', flag: '🇭🇷', name: 'Hrvatska' },
  '386': { iso: 'SI', flag: '🇸🇮', name: 'Slovenija' },
  '421': { iso: 'SK', flag: '🇸🇰', name: 'Slovensko' },
  '370': { iso: 'LT', flag: '🇱🇹', name: 'Lietuva' },
  '371': { iso: 'LV', flag: '🇱🇻', name: 'Latvija' },
  '372': { iso: 'EE', flag: '🇪🇪', name: 'Eesti' },
  '356': { iso: 'MT', flag: '🇲🇹', name: 'Malta' },
  '357': { iso: 'CY', flag: '🇨🇾', name: 'Κύπρος' },
  '377': { iso: 'MC', flag: '🇲🇨', name: 'Monaco' },
  '376': { iso: 'AD', flag: '🇦🇩', name: 'Andorra' },
  '1': { iso: 'US', flag: '🇺🇸', name: 'USA / Canada' },
});

/** "+34" / "34" / "+34 " → { iso, flag, name } ou null. */
function countryFromPhone(countryCode) {
  const digits = String(countryCode || '').replace(/[^0-9]/g, '');
  if (!digits) return null;
  // Essaie le préfixe le plus long d'abord (3 → 2 → 1 chiffres).
  for (const len of [3, 2, 1]) {
    const hit = MAP[digits.slice(0, len)];
    if (hit) return hit;
  }
  return null;
}

// 619 (BOB, 19/10) — Daniel : le classement prend le pays de l'ADRESSE du
// profil (champ ISO `country`), l'indicatif seulement en secours. Le frère de
// Daniel avait l'indicatif +1 (Canada) et sortait « USA ».
const BY_ISO = Object.freeze(Object.values(MAP).reduce((acc, c) => {
  if (!acc[c.iso]) acc[c.iso] = c;
  return acc;
}, { US: { iso: 'US', flag: '🇺🇸', name: 'USA' }, CA: { iso: 'CA', flag: '🇨🇦', name: 'Canada' } }));

/** "FR" → { iso, flag, name } ; drapeau calculé pour un pays hors liste. */
function countryFromIso(iso) {
  const c = String(iso || '').trim().toUpperCase();
  if (!/^[A-Z]{2}$/.test(c)) return null;
  if (BY_ISO[c]) return BY_ISO[c];
  const flag = String.fromCodePoint(...[...c].map((ch) => 0x1f1e6 + ch.charCodeAt(0) - 65));
  let name = c;
  try { name = new Intl.DisplayNames(['fr'], { type: 'region' }).of(c) || c; } catch (_) { /* nom = code */ }
  return { iso: c, flag, name };
}

/** Pays d'un profil : adresse (`country`) d'abord, sinon indicatif. */
function countryOfProfile(doc) {
  return countryFromIso(doc && doc.country) || countryFromPhone(doc && doc.countryCode);
}

/** Indicatifs dont le pays déduit est `iso` (ex. "ES" → ["34"]). */
function phoneDigitsForIso(iso) {
  const c = String(iso || '').toUpperCase();
  return Object.keys(MAP).filter((k) => MAP[k].iso === c);
}

/**
 * Filtre Mongo « même pays que moi » : profils dont l'adresse est dans `iso`,
 * plus ceux SANS pays d'adresse dont l'indicatif mène à `iso`.
 */
function countryFilter(iso) {
  const c = String(iso || '').toUpperCase();
  const digits = phoneDigitsForIso(c);
  const or = [{ country: c }];
  if (digits.length) {
    or.push({
      country: { $in: ['', null] },
      countryCode: new RegExp(`^\\s*\\+?\\s*(${digits.join('|')})\\s*$`),
    });
  }
  return { $or: or };
}

module.exports = { countryFromPhone, countryFromIso, countryOfProfile, countryFilter, phoneDigitsForIso };

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

module.exports = { countryFromPhone };

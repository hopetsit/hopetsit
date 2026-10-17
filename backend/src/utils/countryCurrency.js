const COUNTRY_CURRENCY = {
  FR: 'EUR', ES: 'EUR', PT: 'EUR', IT: 'EUR', DE: 'EUR',
  BE: 'EUR', LU: 'EUR', NL: 'EUR', IE: 'EUR', AT: 'EUR', FI: 'EUR',
  CH: 'CHF', GB: 'GBP', US: 'USD', KR: 'KRW', JP: 'JPY',
};

const countryToCurrency = (iso2) =>
  COUNTRY_CURRENCY[String(iso2 || '').toUpperCase()] || 'EUR';


// 17/10/2026 (SAM, ordre de Daniel : « il faut respecter la devise du pays ») —
// 101 comptes réels n'avaient AUCUN pays (inscription par le site, qui n'envoie
// ni pays ni devise) et tombaient en EUR : 20 comptes new-yorkais en euros, donc
// refusés par le contrôle « devise candidat ≠ devise propriétaire » du 16/10.
// Le pays se déduit, dans l'ordre : champ `country` (ISO-2), puis indicatif
// téléphonique `countryCode` (« +1 » → US). Sans pays connu : rien n'est inventé.
const DIAL_COUNTRY = {
  '1': 'US', '33': 'FR', '34': 'ES', '351': 'PT', '39': 'IT', '49': 'DE', '32': 'BE',
  '352': 'LU', '31': 'NL', '353': 'IE', '43': 'AT', '358': 'FI', '41': 'CH', '44': 'GB',
  '82': 'KR', '81': 'JP',
};
const countryFromDialCode = (code) => {
  const d = String(code || '').replace(/[^0-9]/g, '');
  if (!d) return '';
  for (const len of [3, 2, 1]) {
    const k = d.slice(0, len);
    if (DIAL_COUNTRY[k]) return DIAL_COUNTRY[k];
  }
  return '';
};
/** Pays ISO-2 d'un payload d'inscription (`country` sinon indicatif), '' si inconnu. */
const resolveSignupCountry = (user) => {
  const iso = String((user && user.country) || '').toUpperCase().trim();
  if (/^[A-Z]{2}$/.test(iso)) return iso;
  return countryFromDialCode(user && user.countryCode);
};

module.exports = { countryToCurrency, COUNTRY_CURRENCY, countryFromDialCode, resolveSignupCountry, DIAL_COUNTRY };

const COUNTRY_CURRENCY = {
  FR: 'EUR', ES: 'EUR', PT: 'EUR', IT: 'EUR', DE: 'EUR',
  BE: 'EUR', LU: 'EUR', NL: 'EUR', IE: 'EUR', AT: 'EUR', FI: 'EUR',
  CH: 'CHF', GB: 'GBP', US: 'USD',
};

const countryToCurrency = (iso2) =>
  COUNTRY_CURRENCY[String(iso2 || '').toUpperCase()] || 'EUR';

module.exports = { countryToCurrency, COUNTRY_CURRENCY };

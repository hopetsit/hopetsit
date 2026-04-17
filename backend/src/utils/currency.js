/**
 * Centralized currency utilities.
 *
 * Supported currencies:
 * - EUR
 * - USD
 *
 * NOTE:
 * - DEFAULT_CURRENCY is EUR to preserve existing behavior.
 * - Use normalizeCurrency when accepting user input.
 * - Use assertSupportedCurrency before creating payments or bookings.
 */

const SUPPORTED_CURRENCIES = ['EUR', 'USD', 'GBP', 'CHF'];

const DEFAULT_CURRENCY = 'EUR';

/**
 * Normalize a currency value to an uppercased, supported currency.
 *
 * @param {string|undefined|null} value
 * @param {Object} options
 * @param {boolean} [options.required=false] - If true, throws when value is missing/invalid.
 * @returns {string} Uppercased currency code (e.g. 'EUR', 'USD')
 */
const normalizeCurrency = (value, { required = false } = {}) => {
  const upper = String(value || '').trim().toUpperCase();

  if (SUPPORTED_CURRENCIES.includes(upper)) {
    return upper;
  }

  if (required) {
    throw new Error(`currency must be one of: ${SUPPORTED_CURRENCIES.join(', ')}.`);
  }

  // Fallback to default (backwards compatibility) when not required
  return DEFAULT_CURRENCY;
};

/**
 * Ensure a currency is one of the supported values.
 * Returns the uppercased currency or throws an Error.
 *
 * @param {string|undefined|null} currency
 * @param {string} [contextMessage] - Optional context to append to the error message.
 * @returns {string} Uppercased currency code
 */
const assertSupportedCurrency = (currency, contextMessage) => {
  const upper = String(currency || '').trim().toUpperCase();

  if (!SUPPORTED_CURRENCIES.includes(upper)) {
    const baseMsg = `Unsupported currency "${currency}". Supported currencies are: ${SUPPORTED_CURRENCIES.join(', ')}.`;
    if (contextMessage) {
      throw new Error(`${baseMsg} ${contextMessage}`);
    }
    throw new Error(baseMsg);
  }

  return upper;
};

module.exports = {
  SUPPORTED_CURRENCIES,
  DEFAULT_CURRENCY,
  normalizeCurrency,
  assertSupportedCurrency,
};


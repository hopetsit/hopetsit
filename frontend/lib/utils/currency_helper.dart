/// Supported currencies across the platform.
///
/// Current set: EUR (default), USD, GBP, CHF.
/// Keep this in sync with `backend/src/utils/currency.js` (SUPPORTED_CURRENCIES).
class CurrencyHelper {
  CurrencyHelper._();

  static const String usd = 'USD';
  static const String eur = 'EUR';
  static const String gbp = 'GBP';
  static const String chf = 'CHF';

  static const List<String> supportedCurrencies = [eur, usd, gbp, chf];

  static const String defaultCurrency = eur;

  /// Display label for dropdown (e.g. "EUR (Euro)").
  static String label(String code) {
    switch (code.toUpperCase()) {
      case eur:
        return 'EUR (Euro)';
      case usd:
        return 'USD (Dollar)';
      case gbp:
        return 'GBP (Livre sterling)';
      case chf:
        return 'CHF (Franc suisse)';
      default:
        return code;
    }
  }

  /// Symbol for display (e.g. "€", "\$", "£", "CHF").
  static String symbol(String code) {
    switch (code.toUpperCase()) {
      case eur:
        return '€';
      case usd:
        return '\$';
      case gbp:
        return '£';
      case chf:
        return 'CHF ';
      default:
        return code;
    }
  }

  /// Formats an amount with its currency symbol.
  ///
  /// EUR/USD/GBP put the symbol before the number ("€3.90"), while CHF
  /// conventionally appears with a space separator ("CHF 3.90").
  static String format(String code, double amount, {int decimals = 2}) {
    final normalized = code.toUpperCase();
    final sym = symbol(normalized);
    final str = amount.toStringAsFixed(decimals);
    if (normalized == chf) return '$sym$str'; // symbol already has a trailing space
    return '$sym$str';
  }

  /// Resolve a default currency from a user's country code (ISO-2).
  /// Keeps the same mapping as backend/src/utils/countryCurrency.js.
  static String fromCountry(String? iso2) {
    final code = (iso2 ?? '').trim().toUpperCase();
    switch (code) {
      case 'CH':
        return chf;
      case 'GB':
      case 'UK':
        return gbp;
      case 'US':
        return usd;
      case 'FR':
      case 'ES':
      case 'PT':
      case 'IT':
      case 'DE':
      case 'BE':
      case 'LU':
      case 'NL':
      case 'IE':
      case 'AT':
      case 'FI':
        return eur;
      default:
        return defaultCurrency;
    }
  }
}

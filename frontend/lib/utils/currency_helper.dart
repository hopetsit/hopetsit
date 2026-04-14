/// Supported currencies for hourly fees (initial phase: USD, EUR).
class CurrencyHelper {
  CurrencyHelper._();

  static const String usd = 'USD';
  static const String eur = 'EUR';

  static const List<String> supportedCurrencies = [usd, eur];

  /// Display label for dropdown (e.g. "USD (Dollar)").
  static String label(String code) {
    switch (code.toUpperCase()) {
      case usd:
        return 'USD (Dollar)';
      case eur:
        return 'EUR (Euro)';
      default:
        return code;
    }
  }

  /// Symbol for display (e.g. "$", "€").
  static String symbol(String code) {
    switch (code.toUpperCase()) {
      case usd:
        return '\$';
      case eur:
        return '€';
      default:
        return code;
    }
  }

  /// Format amount with currency symbol (e.g. "$20.00", "€15.50").
  static String format(String code, double amount, {int decimals = 2}) {
    final sym = symbol(code);
    final str = amount.toStringAsFixed(decimals);
    return '$sym$str';
  }
}

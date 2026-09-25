import 'package:get/get.dart';
import 'package:intl/intl.dart';

/// Supported currencies across the platform.
///
/// Current set: EUR (default), USD, GBP, CHF, KRW, JPY.
/// Keep this in sync with `backend/src/utils/currency.js` (SUPPORTED_CURRENCIES).
///
/// Lot D (25/09/2026) — UN SEUL format monétaire dans toute l'app (demande de
/// Daniel : « même devise et même format partout, symbole au bon endroit selon
/// la langue »). Avant : `format` écrivait toujours « €12.00 » (symbole devant,
/// point décimal) quelle que soit la langue, la PawMap écrivait « 12 € », les
/// cartes « €12 », la carte promeneur « 12€ » en dur, et six fichiers avaient
/// leur propre table de symboles. Désormais :
///   · [format]        → montant complet, 2 décimales (totaux, portefeuille,
///                       factures) : « 48,00 € » en fr/es/de/it/pt/pl,
///                       « €48.00 » / « $48.00 » en anglais, « ₩48,000 » ;
///   · [formatCompact] → montant court (tarifs, épingles, boutons, estimations) :
///                       « 12 € », « $12 », « 12,50 € » seulement s'il y a des
///                       centimes.
/// Placement, séparateurs et regroupement viennent d'`intl` (`NumberFormat`)
/// pour la langue de l'app ; won et yen n'ont jamais de décimales.
class CurrencyHelper {
  CurrencyHelper._();

  static const String usd = 'USD';
  static const String eur = 'EUR';
  static const String gbp = 'GBP';
  static const String chf = 'CHF';
  static const String krw = 'KRW';
  static const String jpy = 'JPY';

  static const List<String> supportedCurrencies = [eur, usd, gbp, chf, krw, jpy];

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
      case krw:
        return 'KRW (Won)';
      case jpy:
        return 'JPY (Yen)';
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
      case krw:
        return '₩';
      case jpy:
        return '¥';
      default:
        return code;
    }
  }

  /// Devises sans subdivision affichée.
  static bool _noDecimals(String code) => code == krw || code == jpy;

  /// Langue de l'app (celle des traductions), repli français.
  static String _lang([String? locale]) {
    final l = (locale ?? Get.locale?.languageCode ?? 'fr').toLowerCase();
    if (l.isEmpty) return 'fr';
    // L'app parle le portugais du Portugal (« 12 € »), pas le brésilien
    // (« € 12 ») qu'`intl` prend par défaut pour `pt`.
    if (l == 'pt') return 'pt_PT';
    return l;
  }

  static String _render(String code, double amount, int decimals, String? locale) {
    final normalized = code.toUpperCase();
    final d = _noDecimals(normalized) ? 0 : decimals;
    final sym = symbol(normalized).trim();
    // Symbole séparé du nombre par une espace insécable quand il n'est pas
    // collé (« 12 € », « CHF 12 ») ; `intl` pose l'espace selon la langue.
    final symWithSpace = (normalized == chf || sym.length > 1) ? '$sym\u00A0' : sym;
    final lang = _lang(locale);
    try {
      final f = NumberFormat.currency(locale: lang, symbol: symWithSpace, decimalDigits: d);
      // « 12 € » : `intl` place l'espace insécable ; on retire seulement une
      // espace de fin (CHF placé après le nombre).
      return f.format(amount).replaceAll('\u00A0\u00A0', '\u00A0').trim();
    } catch (_) {
      final str = amount.toStringAsFixed(d);
      return lang == 'en' || lang == 'ko' || lang == 'ja' ? '$sym$str' : '$str\u00A0$sym';
    }
  }

  /// Montant COMPLET (2 décimales) dans la langue de l'app : « 48,00 € »,
  /// « €48.00 », « $48.00 », « 48,00 CHF », « ₩48,000 ».
  static String format(String code, double amount, {int decimals = 2, String? locale}) =>
      _render(code, amount, decimals, locale);

  /// Montant COURT pour les tarifs, épingles, boutons et estimations : pas de
  /// décimales quand le montant est rond (« 12 € », « $12 »), deux sinon
  /// (« 12,50 € »).
  static String formatCompact(String code, double amount, {String? locale}) {
    final rounded = amount.roundToDouble();
    final isRound = (amount - rounded).abs() < 0.005;
    return _render(code, isRound ? rounded : amount, isRound ? 0 : 2, locale);
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
      case 'KR':
        return krw;
      case 'JP':
        return jpy;
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

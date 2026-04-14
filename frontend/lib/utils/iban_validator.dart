class IbanValidationResult {
  final bool valid;
  final String? country;
  final String? reason;

  const IbanValidationResult({required this.valid, this.country, this.reason});
}

class IbanValidator {
  static const Map<String, int> _lengths = {
    'FR': 27, 'ES': 24, 'PT': 25, 'IT': 27, 'DE': 22,
    'BE': 16, 'LU': 20, 'CH': 21, 'GB': 22,
    'NL': 18, 'IE': 22, 'AT': 20, 'FI': 18, 'DK': 18,
    'SE': 24, 'NO': 15, 'PL': 28,
  };

  static String clean(String input) =>
      input.replaceAll(RegExp(r'\s+'), '').toUpperCase();

  static int _mod97(String numeric) {
    int remainder = 0;
    for (int i = 0; i < numeric.length; i += 7) {
      final end = (i + 7) > numeric.length ? numeric.length : i + 7;
      final chunk = remainder.toString() + numeric.substring(i, end);
      remainder = int.parse(chunk) % 97;
    }
    return remainder;
  }

  static IbanValidationResult validate(String input) {
    final s = clean(input);
    if (!RegExp(r'^[A-Z]{2}\d{2}[A-Z0-9]+$').hasMatch(s)) {
      return const IbanValidationResult(valid: false, reason: 'format');
    }
    final country = s.substring(0, 2);
    final expected = _lengths[country];
    if (expected != null && s.length != expected) {
      return IbanValidationResult(
        valid: false,
        country: country,
        reason: 'length_${country}_$expected',
      );
    }
    if (s.length < 15 || s.length > 34) {
      return IbanValidationResult(
        valid: false,
        country: country,
        reason: 'length_bounds',
      );
    }
    final rearranged = s.substring(4) + s.substring(0, 4);
    final buf = StringBuffer();
    for (final c in rearranged.split('')) {
      final code = c.codeUnitAt(0);
      if (code >= 65 && code <= 90) {
        buf.write(code - 55);
      } else {
        buf.write(c);
      }
    }
    if (_mod97(buf.toString()) != 1) {
      return IbanValidationResult(
        valid: false,
        country: country,
        reason: 'checksum',
      );
    }
    return IbanValidationResult(valid: true, country: country);
  }
}

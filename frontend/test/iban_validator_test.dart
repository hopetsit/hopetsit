import 'package:flutter_test/flutter_test.dart';
import 'package:hopetsit/utils/iban_validator.dart';

void main() {
  group('IbanValidator (mirror of backend)', () {
    test('accepts a valid French IBAN', () {
      final r = IbanValidator.validate('FR1420041010050500013M02606');
      expect(r.valid, isTrue);
      expect(r.country, 'FR');
    });

    test('accepts a valid GB IBAN with spaces', () {
      final r = IbanValidator.validate('GB82 WEST 1234 5698 7654 32');
      expect(r.valid, isTrue);
      expect(r.country, 'GB');
    });

    test('rejects invalid format', () {
      expect(IbanValidator.validate('not an iban').valid, isFalse);
    });

    test('rejects wrong checksum', () {
      final r = IbanValidator.validate('FR1420041010050500013M02607');
      expect(r.valid, isFalse);
      expect(r.reason, 'checksum');
    });

    test('rejects wrong country-specific length', () {
      expect(IbanValidator.validate('ES12345').valid, isFalse);
    });

    test('clean normalizes whitespace and case', () {
      expect(IbanValidator.clean('  gb82 west 1234  '), 'GB82WEST1234');
    });
  });
}

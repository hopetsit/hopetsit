import 'package:flutter_test/flutter_test.dart';
import 'package:hopetsit/models/sitter_model.dart';

void main() {
  group('SitterModel.fromJson', () {
    test('parses minimal payload with defaults', () {
      final sitter = SitterModel.fromJson(<String, dynamic>{
        'id': 'abc',
        'name': 'Alice',
        'mobile': '0600000000',
        'hourlyRate': 15,
      });
      expect(sitter.id, 'abc');
      expect(sitter.name, 'Alice');
      expect(sitter.hourlyRate, 15.0);
      expect(sitter.defaultRateType, 'hour');
      expect(sitter.identityVerified, isFalse);
      expect(sitter.isTopSitter, isFalse);
    });

    test('parses sprint 7 loyalty flags', () {
      final sitter = SitterModel.fromJson(<String, dynamic>{
        'id': 'x',
        'name': 'Bob',
        'hourlyRate': 20,
        'isTopSitter': true,
        'completedServicesCount': 25,
        'averageRating': 4.8,
        'identityVerified': true,
      });
      expect(sitter.isTopSitter, isTrue);
      expect(sitter.completedServicesCount, 25);
      expect(sitter.averageRating, 4.8);
      expect(sitter.identityVerified, isTrue);
    });

    test('hasConfiguredRates checks any positive rate', () {
      SitterModel s(Map<String, dynamic> overrides) =>
          SitterModel.fromJson({'id': 'x', 'name': 'n', 'hourlyRate': 0, ...overrides});
      expect(s({}).hasConfiguredRates, isFalse);
      expect(s({'hourlyRate': 10}).hasConfiguredRates, isTrue);
      expect(s({'dailyRate': 50}).hasConfiguredRates, isTrue);
      expect(s({'weeklyRate': 200}).hasConfiguredRates, isTrue);
      expect(s({'monthlyRate': 800}).hasConfiguredRates, isTrue);
    });
  });
}

// v613 — CGU de l'app : la règle de paiement doit être celle du serveur et
// des CGU du site (prestataire 100 % de son tarif, propriétaire tarif + 20 %,
// 15 % badge Top, libération à la confirmation ou 48 h après la fin).
import 'package:flutter_test/flutter_test.dart';
import 'package:hopetsit/data/static/terms_of_service.dart';

void main() {
  const hours48 = {
    'en': '48 hours',
    'fr': '48 heures',
    'es': '48 horas',
    'de': '48 Stunden',
    'it': '48 ore',
    'pt': '48 horas',
  };

  test('termsVersion passe à 2.1', () {
    expect(termsVersion, '2.1');
  });

  for (final entry in hours48.entries) {
    test('${entry.key} : 100 %, 20 % / 15 % Top, 48 h — plus de 80 % ni 24 h', () {
      final t = termsOfServiceForLocale(entry.key);
      expect(t, contains(entry.value));
      expect(RegExp(r'100\s?%').hasMatch(t), isTrue);
      expect(RegExp(r'20\s?%').hasMatch(t), isTrue);
      expect(RegExp(r'15\s?%').hasMatch(t), isTrue);
      expect(RegExp(r'80\s?%').hasMatch(t), isFalse);
      expect(RegExp(r'24 (hours|heures|horas|Stunden|ore)').hasMatch(t), isFalse);
      expect(t, contains('21,60'.replaceAll(',', entry.key == 'en' ? '.' : ',')));
    });
  }

  test('le français garde « wallet » (décision du 30/09)', () {
    final fr = termsOfServiceForLocale('fr');
    expect(fr, contains('wallet du Petsitter'));
    expect(fr, isNot(contains('portefeuille')));
  });

  test('ko / ja / pl retombent sur l\'anglais corrigé', () {
    for (final l in ['ko', 'ja', 'pl']) {
      expect(termsOfServiceForLocale(l), termsOfServiceForLocale('en'));
    }
  });
}

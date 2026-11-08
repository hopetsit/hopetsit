import 'package:flutter_test/flutter_test.dart';
import 'package:hopetsit/services/meta_events_636.dart';

/// 636 — règles pures du point d'entrée Meta (sans appareil).
void main() {
  group('purchaseAmount636', () {
    test('arrondit au centime et garde les montants positifs', () {
      expect(purchaseAmount636(49.999), 50.0);
      expect(purchaseAmount636(12), 12.0);
      expect(purchaseAmount636(0.005), 0.01);
    });
    test('refuse null, 0, négatif, NaN, infini', () {
      expect(purchaseAmount636(null), isNull);
      expect(purchaseAmount636(0), isNull);
      expect(purchaseAmount636(-5), isNull);
      expect(purchaseAmount636(double.nan), isNull);
      expect(purchaseAmount636(double.infinity), isNull);
    });
  });

  group('currencyCode636', () {
    test('normalise en 3 lettres majuscules', () {
      expect(currencyCode636('eur'), 'EUR');
      expect(currencyCode636(' usd '), 'USD');
    });
    test('refuse les devises inexploitables', () {
      expect(currencyCode636(null), isNull);
      expect(currencyCode636(''), isNull);
      expect(currencyCode636('€'), isNull);
      expect(currencyCode636('EURO'), isNull);
    });
  });

  group('demandeParams636', () {
    test('ne garde que les valeurs utiles, sans donnée personnelle', () {
      final p = demandeParams636(
        requestId: 'abc123',
        serviceType: 'dog_walking',
        city: ' Paris ',
        country: 'FR',
        currency: 'eur',
        notified: 3,
      );
      expect(p, {
        'fb_content_id': 'abc123',
        'fb_content_type': 'request',
        'service_type': 'dog_walking',
        'city': 'Paris',
        'country': 'FR',
        'fb_currency': 'EUR',
        'notified': 3,
      });
    });
    test('valeurs vides ou absentes retirées', () {
      final p = demandeParams636(
        requestId: '',
        serviceType: null,
        city: '  ',
        currency: 'x',
        notified: -1,
      );
      expect(p, {'fb_content_type': 'request'});
    });
  });

  test('noms des événements', () {
    expect(MetaEvents636.eventDemandePubliee, 'demande_publiee');
    expect(MetaEvents636.eventActivateApp, 'fb_mobile_activate_app');
  });
}

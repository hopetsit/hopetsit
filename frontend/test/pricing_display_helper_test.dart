import 'package:flutter_test/flutter_test.dart';
import 'package:hopetsit/utils/pricing_display_helper.dart';

void main() {
  group('PricingDisplayHelper.rateTypeLabelKey', () {
    test('maps all recognised rate types', () {
      expect(PricingDisplayHelper.rateTypeLabelKey('hour'), 'price_per_hour');
      expect(PricingDisplayHelper.rateTypeLabelKey('day'), 'price_per_day');
      expect(PricingDisplayHelper.rateTypeLabelKey('week'), 'price_per_week');
      expect(PricingDisplayHelper.rateTypeLabelKey('month'), 'price_per_month');
    });

    test('accepts pricingTier aliases (hourly/weekly/monthly/daily)', () {
      expect(PricingDisplayHelper.rateTypeLabelKey('hourly'), 'price_per_hour');
      expect(PricingDisplayHelper.rateTypeLabelKey('daily'), 'price_per_day');
      expect(PricingDisplayHelper.rateTypeLabelKey('weekly'), 'price_per_week');
      expect(PricingDisplayHelper.rateTypeLabelKey('monthly'), 'price_per_month');
    });

    test('falls back to hour for unknown or null', () {
      expect(PricingDisplayHelper.rateTypeLabelKey(null), 'price_per_hour');
      expect(PricingDisplayHelper.rateTypeLabelKey('unknown'), 'price_per_hour');
    });
  });
}

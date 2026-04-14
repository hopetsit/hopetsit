import 'package:hopetsit/models/booking_model.dart';
import 'package:hopetsit/utils/currency_helper.dart';

/// Display helpers for backend four-tier pricing (hourly / daily / weekly / monthly).
class PricingDisplayHelper {
  PricingDisplayHelper._();

  /// Localized label for a rate type. Keys must exist in app_translations.dart.
  /// rateType: 'hour' | 'day' | 'week' | 'month' (or the pricingTier form
  /// 'hourly' | 'daily' | 'weekly' | 'monthly').
  static String rateTypeLabelKey(String? rateType) {
    switch (rateType) {
      case 'day':
      case 'daily':
        return 'price_per_day';
      case 'week':
      case 'weekly':
        return 'price_per_week';
      case 'month':
      case 'monthly':
        return 'price_per_month';
      case 'hour':
      case 'hourly':
      default:
        return 'price_per_hour';
    }
  }

  /// Shown next to currency symbol on service provider cards (e.g. `15.0` or `420/wk`).
  static String serviceProviderCardPriceTail({
    BookingPricing? pricing,
    required double hourlyRate,
  }) {
    if (pricing == null ||
        pricing.pricingTier == null ||
        pricing.pricingTier!.isEmpty) {
      return hourlyRate.toStringAsFixed(1);
    }
    final rate = pricing.appliedRate ??
        pricing.basePrice ??
        pricing.resolvedBaseAmount ??
        hourlyRate;
    switch (pricing.pricingTier) {
      case 'weekly':
        return '${rate.toStringAsFixed(0)}/wk';
      case 'monthly':
        return '${rate.toStringAsFixed(0)}/mo';
      case 'hourly':
      default:
        return rate.toStringAsFixed(1);
    }
  }

  /// Full rate line for sitter booking list (includes currency and unit).
  static String sitterBookingRateLine(BookingModel booking) {
    final p = booking.pricing;
    final cur = booking.sitter.currency;
    if (p != null && p.pricingTier != null && p.pricingTier!.isNotEmpty) {
      final amt =
          p.resolvedBaseAmount ?? p.appliedRate ?? booking.sitter.hourlyRate;
      if (amt <= 0) {
        return '${CurrencyHelper.format(cur, booking.sitter.hourlyRate)}/hr';
      }
      switch (p.pricingTier) {
        case 'weekly':
          return '${CurrencyHelper.format(cur, amt)}/wk';
        case 'monthly':
          return '${CurrencyHelper.format(cur, amt)}/mo';
        case 'hourly':
        default:
          return '${CurrencyHelper.format(cur, amt)}/hr';
      }
    }
    return '${CurrencyHelper.format(cur, booking.sitter.hourlyRate)}/hr';
  }
}

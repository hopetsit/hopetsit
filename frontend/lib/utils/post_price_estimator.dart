import 'dart:math' as math;
import 'package:hopetsit/models/post_model.dart';

/// Estimated earning for a walker/sitter looking at an owner's post.
///
/// [brut]        Total the owner would pay (before platform commission).
/// [net]         What the walker/sitter actually receives after commission.
/// [commission]  Amount kept by the platform.
/// [currency]    ISO currency code (e.g. 'EUR', 'USD').
/// [breakdown]   Human readable breakdown (e.g. "2h × €15" or "3 jours × €30").
/// [unit]        'hour' | 'day' | 'week' | 'month' — which rate was used.
class PostPriceEstimate {
  final double brut;
  final double net;
  final double commission;
  final String currency;
  final String breakdown;
  final String unit;

  const PostPriceEstimate({
    required this.brut,
    required this.net,
    required this.commission,
    required this.currency,
    required this.breakdown,
    required this.unit,
  });

  bool get isZero => brut <= 0.0;
}

/// Build a [PostPriceEstimate] for [post] given the current walker/sitter
/// rates from their profile. Returns `null` if the post has no usable
/// start/end dates or the role/rates are missing.
///
///   * Walker (`dog_walking`)  → hourlyRate × hours. Minimum 0.5h billed.
///   * Sitter (`pet_sitting`, `house_sitting`, `day_care`) →
///       - >= 30 days and monthlyRate > 0  → monthlyRate × ceil(days/30)
///       - >= 7  days and weeklyRate  > 0  → weeklyRate  × ceil(days/7)
///       - else                             → dailyRate  × max(days, 1)
///
/// [commissionRate] defaults to 0.20 (20%). Pass 0.0 to disable.
PostPriceEstimate? estimatePostPrice({
  required PostModel post,
  required String userRole, // 'walker' | 'sitter'
  required double hourlyRate,
  required double dailyRate,
  required double weeklyRate,
  required double monthlyRate,
  required String currency,
  double commissionRate = 0.20,
}) {
  final start = post.startDate;
  final end = post.endDate;
  if (start == null || end == null) return null;
  if (end.isBefore(start)) return null;

  final role = userRole.toLowerCase();
  final services = post.serviceTypes.map((s) => s.toLowerCase()).toSet();
  final isWalkingPost = services.contains('dog_walking');

  // ----- WALKER ---------------------------------------------------------
  if (role == 'walker' || (role != 'sitter' && isWalkingPost)) {
    if (hourlyRate <= 0) return null;
    final duration = end.difference(start);
    // Minimum billable slot = 30 min, round up to nearest 30 min.
    double hours = duration.inMinutes / 60.0;
    if (hours < 0.5) hours = 0.5;
    // Round to 0.5 increments.
    hours = (hours * 2).ceilToDouble() / 2.0;
    final brut = hourlyRate * hours;
    final commission = brut * commissionRate;
    final net = brut - commission;
    final hoursLabel = hours == hours.roundToDouble()
        ? '${hours.toInt()}h'
        : '${hours.toStringAsFixed(1)}h';
    return PostPriceEstimate(
      brut: brut,
      net: net,
      commission: commission,
      currency: currency,
      breakdown: '$hoursLabel × ${_money(hourlyRate, currency)}',
      unit: 'hour',
    );
  }

  // ----- SITTER ---------------------------------------------------------
  // Use day count (inclusive). Minimum 1 day.
  final totalMinutes = end.difference(start).inMinutes;
  int days = math.max(1, (totalMinutes / (60 * 24)).ceil());

  // Session v17.1 — derive missing rate tiers from whichever one the
  // sitter has configured. Mirrors the backend logic in createBooking.js
  // (L.364-372): most sitters only fill ONE rate via the edit UI, but the
  // estimator used to require the specific tier matching the booking
  // duration, so multi-day bookings returned null → no blue block.
  //
  // Derivation rules (identical to the backend):
  //   hourlyRate × 8   → dailyRate fallback
  //   dailyRate × 7    → weeklyRate fallback
  //   weeklyRate × 4   → monthlyRate fallback
  //   monthlyRate / 30 → dailyRate fallback (cross-direction)
  //   monthlyRate / 4  → weeklyRate fallback
  double effectiveHourly = hourlyRate;
  double effectiveDaily = dailyRate;
  double effectiveWeekly = weeklyRate;
  double effectiveMonthly = monthlyRate;

  if (effectiveDaily <= 0) {
    if (effectiveHourly > 0) {
      effectiveDaily = effectiveHourly * 8;
    } else if (effectiveWeekly > 0) {
      effectiveDaily = effectiveWeekly / 7;
    } else if (effectiveMonthly > 0) {
      effectiveDaily = effectiveMonthly / 30;
    }
  }
  if (effectiveWeekly <= 0) {
    if (effectiveDaily > 0) {
      effectiveWeekly = effectiveDaily * 7;
    } else if (effectiveMonthly > 0) {
      effectiveWeekly = effectiveMonthly / 4;
    }
  }
  if (effectiveMonthly <= 0) {
    if (effectiveWeekly > 0) {
      effectiveMonthly = effectiveWeekly * 4;
    } else if (effectiveDaily > 0) {
      effectiveMonthly = effectiveDaily * 30;
    }
  }
  // v18.3 — also derive hourly (backend expects hourly for < 7 day bookings).
  // Convention: 1 day = 8 billable hours.
  if (effectiveHourly <= 0 && effectiveDaily > 0) {
    effectiveHourly = effectiveDaily / 8;
  }

  // Session v18.3 — align with backend tierPricing.calculateTierBasePrice:
  //   - ≥ 30 days AND monthlyRate > 0 → monthly (with partial days pro-rated)
  //   - ≥  7 days AND weeklyRate  > 0 → weekly  (with partial days pro-rated)
  //   - else                          → HOURLY × total hours (not days × daily)
  //
  // Why the change: a "Day Care" booking of 1h40 used to show "1 jour × €7.14"
  // on the sitter side (estimator rule) while the owner got charged 1.67h ×
  // €0.90 = €1.49 by the backend (hourly rule). Now both sides use the same
  // hourly math for sub-week durations.
  if (days >= 30 && effectiveMonthly > 0) {
    final fullMonths = (days ~/ 30);
    final remDays = days % 30;
    final dailyFromMonth = effectiveMonthly / 30;
    final brut = fullMonths * effectiveMonthly + remDays * dailyFromMonth;
    final commission = brut * commissionRate;
    final label = fullMonths + (remDays > 0 ? 1 : 0) == 1
        ? '1 mois'
        : '$days jours';
    return PostPriceEstimate(
      brut: brut,
      net: brut - commission,
      commission: commission,
      currency: currency,
      breakdown: '$label × ${_money(effectiveMonthly, currency)}',
      unit: 'month',
    );
  }
  if (days >= 7 && effectiveWeekly > 0) {
    final fullWeeks = (days ~/ 7);
    final remDays = days % 7;
    final dailyFromWeek = effectiveWeekly / 7;
    final brut = fullWeeks * effectiveWeekly + remDays * dailyFromWeek;
    final commission = brut * commissionRate;
    final label = fullWeeks + (remDays > 0 ? 1 : 0) == 1
        ? '1 semaine'
        : '$days jours';
    return PostPriceEstimate(
      brut: brut,
      net: brut - commission,
      commission: commission,
      currency: currency,
      breakdown: '$label × ${_money(effectiveWeekly, currency)}',
      unit: 'week',
    );
  }
  // Short bookings (< 7 days) — always hourly, matches backend.
  if (effectiveHourly > 0) {
    // Same floor as the backend: minimum 1 billed hour even if the booking
    // is shorter than that, to prevent absurd micro-bookings. Hours are kept
    // at 2 decimals for consistency with tierPricing.round2.
    final hoursRaw = math.max(totalMinutes / 60.0, 1.0);
    final hours = (hoursRaw * 100).round() / 100;
    final brut = effectiveHourly * hours;
    final commission = brut * commissionRate;
    final hoursLabel = hours == hours.roundToDouble()
        ? '${hours.toInt()}h'
        : '${hours.toStringAsFixed(2)}h';
    return PostPriceEstimate(
      brut: brut,
      net: brut - commission,
      commission: commission,
      currency: currency,
      breakdown: '$hoursLabel × ${_money(effectiveHourly, currency)}',
      unit: 'hour',
    );
  }

  // No usable rate at all — sitter has configured nothing. Hide the block.
  return null;
}

String _money(double amount, String currency) {
  final symbol = _currencySymbol(currency);
  final rounded = amount.toStringAsFixed(amount == amount.roundToDouble() ? 0 : 2);
  return '$symbol$rounded';
}

String _currencySymbol(String code) {
  switch (code.toUpperCase()) {
    case 'EUR':
      return '€';
    case 'USD':
    case 'CAD':
    case 'AUD':
      return '\$';
    case 'GBP':
      return '£';
    default:
      return '$code ';
  }
}

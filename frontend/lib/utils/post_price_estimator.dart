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

  // Prefer the rate tier that matches the duration if configured.
  if (days >= 30 && monthlyRate > 0) {
    final months = (days / 30).ceil();
    final brut = monthlyRate * months;
    final commission = brut * commissionRate;
    final label = months == 1 ? '1 mois' : '$months mois';
    return PostPriceEstimate(
      brut: brut,
      net: brut - commission,
      commission: commission,
      currency: currency,
      breakdown: '$label × ${_money(monthlyRate, currency)}',
      unit: 'month',
    );
  }
  if (days >= 7 && weeklyRate > 0) {
    final weeks = (days / 7).ceil();
    final brut = weeklyRate * weeks;
    final commission = brut * commissionRate;
    final label = weeks == 1 ? '1 semaine' : '$weeks semaines';
    return PostPriceEstimate(
      brut: brut,
      net: brut - commission,
      commission: commission,
      currency: currency,
      breakdown: '$label × ${_money(weeklyRate, currency)}',
      unit: 'week',
    );
  }
  if (dailyRate > 0) {
    final brut = dailyRate * days;
    final commission = brut * commissionRate;
    final label = days == 1 ? '1 jour' : '$days jours';
    return PostPriceEstimate(
      brut: brut,
      net: brut - commission,
      commission: commission,
      currency: currency,
      breakdown: '$label × ${_money(dailyRate, currency)}',
      unit: 'day',
    );
  }

  // No usable rate configured.
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

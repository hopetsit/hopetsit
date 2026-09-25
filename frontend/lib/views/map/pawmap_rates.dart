// v584 (révision PawMap du 25/09, point 8) — TARIFS d'un prestataire, dans SA
// devise, sous une forme pure et testable : sert la fiche courte de la carte,
// la réservation en 2 taps et la fiche complète (gardien / promeneur).
//   · gardien  : heure / jour / semaine / mois + animal supplémentaire ;
//   · promeneur : 30 min / 1 h / 2 h.
// Les lignes non renseignées (null ou ≤ 0) n'existent pas : jamais « 0 € ».
import 'package:get/get.dart';

import '../../utils/currency_helper.dart';
import 'widgets/pawmap_sheets.dart' show PawMapRateLine;

class PawProviderRates {
  const PawProviderRates({
    required this.currency,
    required this.role,
    this.hourly,
    this.daily,
    this.weekly,
    this.monthly,
    this.extraPet,
    this.halfHour,
    this.twoHours,
  });

  final String currency;
  final String role; // sitter | walker
  final double? hourly;
  final double? daily;
  final double? weekly;
  final double? monthly;
  final double? extraPet;
  final double? halfHour;
  final double? twoHours;

  bool get isEmpty => lines.isEmpty;

  /// « dès 35 €/j » (gardien) / « dès 10 €/30 min » (promeneur) — le prix
  /// d'entrée le plus parlant, formaté dans la devise du prestataire.
  String? get fromLabel {
    if (role == 'walker') {
      final v = halfHour ?? hourly ?? twoHours;
      if (v == null) return null;
      final unit = halfHour != null
          ? 'pawmap_rate_unit_30'.tr
          : (hourly != null ? 'pawmap_rate_unit_60'.tr : 'pawmap_rate_unit_120'.tr);
      return '${CurrencyHelper.formatCompact(currency, v)}/$unit';
    }
    final v = daily ?? hourly ?? weekly ?? monthly;
    if (v == null) return null;
    final unit = daily != null
        ? 'pawmap_rate_unit_day'.tr
        : (hourly != null
            ? 'pawmap_rate_unit_hour'.tr
            : (weekly != null ? 'pawmap_rate_unit_week'.tr : 'pawmap_rate_unit_month'.tr));
    return '${CurrencyHelper.formatCompact(currency, v)}/$unit';
  }

  /// Toutes les lignes renseignées, dans l'ordre d'affichage.
  List<PawMapRateLine> get lines {
    String f(double v) => CurrencyHelper.format(currency, v);
    final out = <PawMapRateLine>[];
    if (role == 'walker') {
      if ((halfHour ?? 0) > 0) out.add(PawMapRateLine(label: 'pawmap_rate_30'.tr, value: f(halfHour!)));
      if ((hourly ?? 0) > 0) out.add(PawMapRateLine(label: 'pawmap_rate_60'.tr, value: f(hourly!)));
      if ((twoHours ?? 0) > 0) out.add(PawMapRateLine(label: 'pawmap_rate_120'.tr, value: f(twoHours!)));
      return out;
    }
    if ((hourly ?? 0) > 0) out.add(PawMapRateLine(label: 'price_per_hour'.tr, value: f(hourly!)));
    if ((daily ?? 0) > 0) out.add(PawMapRateLine(label: 'price_per_day'.tr, value: f(daily!)));
    if ((weekly ?? 0) > 0) out.add(PawMapRateLine(label: 'price_per_week'.tr, value: f(weekly!)));
    if ((monthly ?? 0) > 0) out.add(PawMapRateLine(label: 'price_per_month'.tr, value: f(monthly!)));
    if ((extraPet ?? 0) > 0) out.add(PawMapRateLine(label: 'pawmap_rate_extra_pet'.tr, value: f(extraPet!)));
    return out;
  }
}

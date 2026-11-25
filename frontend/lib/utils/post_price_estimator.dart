import 'package:get/get.dart';
import 'dart:math' as math;
import 'package:hopetsit/models/post_model.dart';
import 'package:hopetsit/utils/currency_helper.dart';

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
  // v23.1 part 114 — Daniel : "jai changer de tarif et sa ne saffiche pas
  // le bon prix qd je vois la nouvelle publication". Le walker peut définir
  // un tarif EXACT pour 30min (différent de hourlyRate / 2). Si fourni, on
  // l'utilise tel quel pour les balades de 30 min (et 60min idem).
  double? walkRate30,
  double? walkRate60,
  // 646 (PAM, 25/11/2026) — tarif PAR VISITE du gardien (visite à domicile).
  double visitRate = 0,
}) {
  // v20.0.19 — soften the date requirement so the price block appears on
  // publications that don't carry a full end date. Most owners publish a
  // "Garderie du 24 avril" with only startDate, and the estimator used to
  // return null → Daniel voyait aucun montant estimé sur le feed sitter.
  // Rule:
  //   - start + end present : use the range as-is
  //   - start only, end null : assume 1 day service (garderie / petsitting)
  //     OR 1 hour for walker (handled below via hasExplicitDuration)
  //   - start null           : no estimate possible, return null
  final start = post.startDate;
  DateTime? end = post.endDate;
  if (start == null) return null;
  if (end != null && end.isBefore(start)) {
    end = null; // bad data → fall back to 1-day default
  }
  // 646 (ZOE) — fin RÉELLE de la demande (null = une seule date) : c'est elle
  // qui compte les jours, comme le serveur (une seule date = 1 jour). La fin
  // « par défaut » ci-dessous (+ 24 h) aurait compté 2 jours.
  final DateTime? realEnd = end;
  end ??= start.add(const Duration(hours: 24));

  final role = userRole.toLowerCase();
  final services = post.serviceTypes.map((s) => s.toLowerCase()).toSet();
  final isWalkingPost = services.contains('dog_walking');
  // 646 (PAM, 25/11/2026 — ordre de Daniel « plus jamais heure × 8 ») : le
  // service PRINCIPAL de la demande est le premier de la liste, comme sur le
  // serveur (`pricingEngine620.mainService`).
  final main = mainService646(post);

  // ----- WALKER ---------------------------------------------------------
  if (role == 'walker' || (role != 'sitter' && isWalkingPost)) {
    // 646 — un promeneur sur une GARDE : aucun gain affiché. Avant, la carte
    // multipliait son tarif horaire par toutes les heures de la période
    // (12 €/h × 48 h = « Vous recevez 576 € », mesuré par ZOE le 25/11).
    if (main.isNotEmpty && main != 'dog_walking') return null;
    final duration = end.difference(start);
    // 646 — balades sur PLUSIEURS jours : une balade par jour, comme le
    // serveur (`quantityFor` : unité 'walk', quantité = jours). Avant : tarif
    // horaire × toutes les heures entre le premier et le dernier jour.
    final walkDays = calendarDays628(start, realEnd);
    // 646 (ZOE, contrôle du 25/11) — EXACTEMENT la règle du serveur
    // (`priceApplication` : durée = celle de la demande ; tarif = celui de
    // cette durée ; quantité = une balade par jour). L'app ne connaît que les
    // tarifs 30 et 60 min : pour une autre durée, ou sans tarif pour la durée
    // demandée, le serveur prend un autre palier que l'app ne peut pas
    // deviner → AUCUN gain affiché plutôt qu'un chiffre faux (avant : tarif
    // horaire au prorata, ex. 24 € affichés pour 12 € versés).
    final int askedMinutes = post.walkDurationMinutes ?? 0;
    if (walkDays > 1 || askedMinutes > 0) {
      double perWalk = 0;
      if (askedMinutes == 30 && walkRate30 != null && walkRate30 > 0) {
        perWalk = _round2(walkRate30);
      } else if (askedMinutes == 60 && walkRate60 != null && walkRate60 > 0) {
        perWalk = _round2(walkRate60);
      }
      if (perWalk <= 0) return null;
      final double brut = _round2(perWalk * walkDays);
      final double commission = _round2(brut * commissionRate);
      return PostPriceEstimate(
        brut: _round2(brut + commission),
        net: brut,
        commission: commission,
        currency: currency,
        breakdown: walkDays == 1
            ? '$askedMinutes min × ${_money(perWalk, currency)}'
            : '${'price_days_n'.tr.replaceAll('{n}', '$walkDays')} × ${_money(perWalk, currency)}',
        unit: 'walk',
      );
    }
    // v23.1 part 114 — pour les balades EXACTEMENT 30 ou 60 min, on
    // privilégie le tarif explicite du walker (walkRate30 / walkRate60)
    // au lieu de multiplier hourlyRate × hours. Ça matche le comportement
    // du backend (bookingController.js:383-395 shim v18.9.3).
    final durationMinutes = duration.inMinutes;
    if (durationMinutes == 30 && walkRate30 != null && walkRate30 > 0) {
      final brut = walkRate30;
      final commission = brut * commissionRate;
      return PostPriceEstimate(
        brut: brut + commission,
        net: brut,
        commission: commission,
        currency: currency,
        breakdown: '30 min × ${_money(brut, currency)}',
        unit: 'hour',
      );
    }
    if (durationMinutes == 60 && walkRate60 != null && walkRate60 > 0) {
      final brut = walkRate60;
      final commission = brut * commissionRate;
      return PostPriceEstimate(
        brut: brut + commission,
        net: brut,
        commission: commission,
        currency: currency,
        breakdown: '1h × ${_money(brut, currency)}',
        unit: 'hour',
      );
    }
    // Pas de tarif exact → fallback sur hourlyRate × hours (comportement legacy).
    if (hourlyRate <= 0) return null;
    // Minimum billable slot = 30 min, round up to nearest 30 min.
    double hours = duration.inMinutes / 60.0;
    if (hours < 0.5) hours = 0.5;
    // Round to 0.5 increments.
    hours = (hours * 2).ceilToDouble() / 2.0;
    // v20.0.11 — commission is paid ON TOP by owner, NOT subtracted from
    // the walker's net. Walker gets his full rate × hours.
    final brut = hourlyRate * hours;
    final commission = brut * commissionRate;
    final net = brut; // provider keeps full rate
    final hoursLabel = hours == hours.roundToDouble()
        ? '${hours.toInt()}h'
        : '${hours.toStringAsFixed(1)}h';
    return PostPriceEstimate(
      brut: brut + commission, // what owner pays (gross with commission)
      net: net,
      commission: commission,
      currency: currency,
      breakdown: '$hoursLabel × ${_money(hourlyRate, currency)}',
      unit: 'hour',
    );
  }

  // ----- SITTER ---------------------------------------------------------
  // 628 (ZOE, 29/10/2026) — MÊME compte que le serveur (pricingEngine620
  // `dayCount`) : jours CALENDAIRES couverts, fin − début + 1 en UTC, ≥ 1.
  // Avant : ceil(minutes / 1440) → une garde du 12/11 9 h au 14/11 9 h
  // comptait 2 jours alors que le serveur en facture 3.
  final int days = calendarDays628(start, realEnd);

  // 646 — VISITE À DOMICILE : visites × tarif par visite, comme le serveur
  // (jours × visites par jour). Sans tarif par visite : aucun gain (la carte
  // invite à l'ajouter). Avant : calcul à la journée, donc un gain faux.
  if (main == 'home_visit') {
    if (visitRate <= 0) return null;
    final int perDay = const <int>[1, 2].contains(post.visitsPerDay) // 1 ou 2, comme le serveur
        ? post.visitsPerDay!
        : 1;
    final int visits = days * perDay;
    final double brut = _round2(_round2(visitRate) * visits);
    final double commission = _round2(brut * commissionRate);
    return PostPriceEstimate(
      brut: _round2(brut + commission),
      net: brut,
      commission: commission,
      currency: currency,
      breakdown: '$visits × ${_money(visitRate, currency)}',
      unit: 'visit',
    );
  }

  // 646 (ZOE, contrôle du 25/11/2026 — ordre de Daniel : « le gain affiché
  // doit être EXACTEMENT celui du serveur ») — MÊME règle que le serveur
  // (`pricingEngine620` : `rateFor` + `quantityFor` + `dailyTotalWithWeekly`),
  // pour TOUTES les prestations à la journée (garde, garderie, séjour) :
  //   · tarif d'une unité = tarif jour, sinon semaine ÷ 7, sinon mois ÷ 30,
  //     arrondi au centime ;
  //   · unités = jours calendaires (nuits = jours − 1 chez le gardien) ;
  //   · total = unités × tarif ; à partir de 7 unités, si le gardien a un
  //     tarif semaine d'au moins 3 × son tarif jour ET que c'est moins cher :
  //     semaines entières × tarif semaine + unités restantes × tarif jour.
  // Le tarif au MOIS ne sert jamais de palier (le serveur ne l'applique pas).
  // Avant : paliers « mois » et « semaine » propres à l'app → 30 jours à
  // 20 €/j, 120 €/sem, 400 €/mois affichaient 400 € quand le serveur verse
  // 520 € ; 7 jours à 50 €/j et 100 €/sem affichaient 100 € au lieu de 350 €.
  // Un gardien sur une demande dont le service principal est une BALADE :
  // aucun gain (le serveur n'a pas de tarif à lui appliquer).
  if (main == 'dog_walking') return null;
  final double unitRate = _round2(dailyRate > 0
      ? dailyRate
      : (weeklyRate > 0
          ? weeklyRate / 7
          : (monthlyRate > 0 ? monthlyRate / 30 : 0.0)));
  if (unitRate > 0) {
    final bool sittersHome = (main == 'house_sitting' || main == 'pet_sitting') &&
        (post.houseSittingVenue == 'sitters_home' ||
            post.serviceLocation == 'at_sitter');
    final int units = sittersHome ? math.max(1, days - 1) : days;
    double brut = _round2(unitRate * units);
    String breakdown = units == 1
        ? '${'price_days_one'.tr} × ${_money(unitRate, currency)}'
        : '${'price_days_n'.tr.replaceAll('{n}', '$units')} × ${_money(unitRate, currency)}';
    if (units >= 7 && weeklyRate > 0 && weeklyRate >= 3 * unitRate) {
      final int weeks = units ~/ 7;
      final int rest = units - weeks * 7;
      final double alt = _round2(weeks * weeklyRate + rest * unitRate);
      if (alt + 0.001 < brut) {
        brut = alt;
        breakdown =
            '${'price_days_n'.tr.replaceAll('{n}', '$units')} · ${_money(_round2(weeklyRate), currency)} / ${'price_week_one'.tr}';
      }
    }
    final double commission = _round2(brut * commissionRate);
    return PostPriceEstimate(
      brut: _round2(brut + commission),
      net: brut,
      commission: commission,
      currency: currency,
      breakdown: breakdown,
      unit: sittersHome ? 'night' : 'day',
    );
  }
  // 646 — aucun tarif à la journée (ni semaine, ni mois) : PAS de gain. Le
  // tarif à l'heure seul ne sert plus à inventer une journée (ni « × 8 », ni
  // « × toutes les heures de la période »). La carte affiche à la place une
  // invitation à ajouter son prix par jour (`gainHintKey646`).
  return null;
}

/// Lot D — même format monétaire que partout (langue de l'app).
String _money(double amount, String currency) =>
    CurrencyHelper.formatCompact(currency, amount);

/// 628 — jours calendaires couverts par [start]..[end] (UTC, inclusif), ≥ 1 :
/// même règle que `dayCount` de `pricingEngine620.js`. Pure.
int calendarDays628(DateTime start, DateTime? end) {
  final s = start.toUtc();
  final e = (end ?? start).toUtc();
  final sd = DateTime.utc(s.year, s.month, s.day);
  final ed = DateTime.utc(e.year, e.month, e.day);
  if (ed.isBefore(sd)) return 1;
  return ed.difference(sd).inDays + 1;
}

/// Arrondi au centime, comme `round2` du serveur.
double _round2(double v) => (v * 100).round() / 100;

/// 646 — service PRINCIPAL d'une demande = le premier de la liste (règle du
/// serveur). Normalisé : minuscules, `_`. '' quand la demande n'en a pas.
String mainService646(PostModel post) {
  for (final raw in post.serviceTypes) {
    final v = raw.trim().toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');
    if (v.isEmpty) continue;
    if (v == 'homevisit') return 'home_visit';
    if (v == 'walking' || v == 'promenade') return 'dog_walking';
    if (v == 'garderie' || v == 'daycare') return 'day_care';
    return v;
  }
  return '';
}

/// 646 — tarif qui MANQUE au prestataire pour chiffrer cette demande :
/// 'day' (prix par jour), 'visit' (prix par visite), 'walk' (prix de balade),
/// ou null quand il a ce qu'il faut (ou que la demande n'est pas pour lui).
/// Pure : sert à la carte (phrase à la place du gain) et aux tests.
String? missingRate646({
  required PostModel post,
  required String userRole,
  double dailyRate = 0,
  double weeklyRate = 0,
  double monthlyRate = 0,
  double visitRate = 0,
  bool hasWalkRate = false,
}) {
  final role = userRole.toLowerCase();
  final main = mainService646(post);
  if (role == 'walker') {
    if (main.isNotEmpty && main != 'dog_walking') return null;
    return hasWalkRate ? null : 'walk';
  }
  if (role != 'sitter') return null;
  if (main == 'dog_walking') return null;
  if (main == 'home_visit') return visitRate > 0 ? null : 'visit';
  return (dailyRate > 0 || weeklyRate > 0 || monthlyRate > 0) ? null : 'day';
}

/// 646 — clé i18n de la phrase affichée À LA PLACE du gain.
String gainHintKey646(String missing) {
  switch (missing) {
    case 'visit':
      return 'pam646_gain_add_visit';
    case 'walk':
      return 'pam646_gain_add_walk';
    default:
      return 'pam646_gain_add_day';
  }
}

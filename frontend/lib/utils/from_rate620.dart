// 621 (PAM, 24/10/2026 — serveur 620b de ZOE) — « à partir de » d'une demande
// OUVERTE (sans prestataire visé) : `POST /pricing/estimate` sans `rate` ni
// `providerId` renvoie `{ fromRate, unit, quantity, ownerTotalFrom, basedOn }`
// (minimum des prestataires du rayon d'alerte, dans la devise du
// propriétaire). L'app n'affiche que ce que le serveur renvoie :
//   « à partir de 12 €/visite · estimation ~86 € » (dates posées),
//   « à partir de 12 €/visite » (dates à prévoir),
//   rien quand `basedOn` vaut 0 (aucun prestataire par ici).
// Utilisé par « Mes annonces », le détail d'une demande et la bulle « Ma
// demande » de la PawMap (une seule requête par demande, cache 5 min — le
// serveur cache lui-même 5 min par zone).
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../data/network/api_client.dart';
import '../models/nearby_request_model.dart';
import '../models/post_model.dart';
import '../widgets/app_text.dart';
import 'app_colors.dart';
import 'currency_helper.dart';
import 'dates620.dart';
import 'services620.dart';

/// Unité « fil » (day | night | visit | walk) d'une réponse du moteur.
String fromRateUnitWire620(PricingEstimate620 e) {
  switch (e.unit) {
    case ServiceUnit620.visit:
      return 'visit';
    case ServiceUnit620.walk:
      return 'walk';
    case ServiceUnit620.day:
      return e.night ? 'night' : 'day';
  }
}

/// Texte « à partir de 12 €/visite · estimation ~86 € » ; « à partir de
/// 12 €/visite » sans total ; vide quand aucun prestataire (`basedOn 0`) ou
/// quand la réponse n'est pas une réponse de marché.
String fromRateText620(PricingEstimate620? e) {
  if (e == null || !e.hasFromRate) return '';
  final cur = e.currency.isNotEmpty ? e.currency : 'EUR';
  final price = CurrencyHelper.formatCompact(cur, e.fromRate!);
  final suffix = priceUnitSuffix620(fromRateUnitWire620(e));
  final base = (e.hasFromTotal ? 'dates620_from_rate_total' : 'dates620_from_rate').tr;
  var out = base
      .replaceAll('@price', price)
      .replaceAll('/@unit', suffix.isEmpty ? '' : suffix);
  if (e.hasFromTotal) {
    out = out.replaceAll('@total', CurrencyHelper.formatCompact(cur, e.ownerTotalFrom!));
  }
  return out;
}

/// Valeur SANS le préfixe « à partir de » pour une case dont l'étiquette le
/// porte déjà (grille de la carte d'annonce) : « 12 €/visite · estimation
/// ~43,20 € », ou « 12 €/visite » seul ; vide quand rien à montrer.
String fromRateValueText620(PricingEstimate620? e) {
  if (e == null || !e.hasFromRate) return '';
  final cur = e.currency.isNotEmpty ? e.currency : 'EUR';
  final price = CurrencyHelper.formatCompact(cur, e.fromRate!);
  final suffix = priceUnitSuffix620(fromRateUnitWire620(e));
  final unit = '$price${suffix.isEmpty ? '' : suffix}';
  if (!e.hasFromTotal) return unit;
  return 'dates620_from_rate_value_total'.tr
      .replaceAll('@price', price)
      .replaceAll('/@unit', suffix.isEmpty ? '' : suffix)
      .replaceAll('@total', CurrencyHelper.formatCompact(cur, e.ownerTotalFrom!));
}

/// Mode de dates d'une demande enregistrée (PostModel / bulle PawMap).
DateMode620 _modeOf(String raw, DateTime? start, DateTime? end) =>
    dateMode620Parse(raw, start: start, end: end);

/// Corps d'estimation d'une demande OUVERTE (jamais de `rate` ni de
/// `providerId` : le serveur cherche lui-même le minimum du rayon).
Map<String, dynamic> fromRateBody620({
  required String serviceType,
  required String dateMode,
  DateTime? startDate,
  DateTime? endDate,
  int? visitsPerDay,
  int? walkDurationMinutes,
  String? houseSittingVenue,
  double? lat,
  double? lng,
  String? city,
}) {
  final mode = _modeOf(dateMode, startDate, endDate);
  return estimateBody620(
    serviceType: serviceType,
    dateMode: mode,
    startDate: startDate,
    endDate: endDate,
    visitsPerDay: visitsPerDay,
    walkDurationMinutes: walkDurationMinutes,
    houseSittingVenue: houseSittingVenue,
    lat: lat,
    lng: lng,
    city: city,
  );
}

/// Corps pour une demande du propriétaire (« Mes annonces », détail).
/// Null si la demande n'est pas ouverte (réservée) ou n'a aucun service.
Map<String, dynamic>? fromRateBodyForPost620(PostModel post) {
  if (post.isReserved) return null;
  if (post.serviceTypes.isEmpty) return null;
  final loc = post.location;
  return fromRateBody620(
    serviceType: post.serviceTypes.first,
    dateMode: post.dateMode,
    startDate: post.startDate,
    endDate: post.endDate,
    visitsPerDay: post.visitsPerDay,
    walkDurationMinutes: post.walkDurationMinutes,
    houseSittingVenue: post.houseSittingVenue,
    lat: loc?.lat,
    lng: loc?.lng,
    city: loc?.city,
  );
}

/// Corps pour une bulle « Ma demande » de la PawMap.
Map<String, dynamic>? fromRateBodyForNearby620(NearbyRequestPost r) {
  if (r.serviceTypes.isEmpty) return null;
  return fromRateBody620(
    serviceType: r.serviceTypes.first,
    dateMode: r.dateMode,
    startDate: r.startDate,
    endDate: r.endDate,
    visitsPerDay: r.visitsPerDay,
    lat: r.lat,
    lng: r.lng,
    city: r.city,
  );
}

/// Empreinte d'un corps (service, dates, visites, position) : une demande
/// modifiée (dates posées) est ré-estimée tout de suite.
String fromRateKey620(String id, Map<String, dynamic> body) {
  final post = body['post'] is Map ? body['post'] as Map : const <String, dynamic>{};
  final loc = post['location'] is Map ? post['location'] as Map : const <String, dynamic>{};
  return [
    id,
    body['serviceType'],
    post['dateMode'],
    post['startDate'],
    post['endDate'],
    post['visitsPerDay'],
    loc['lat'],
    loc['lng'],
  ].join('|');
}

/// Cache mémoire (5 min) des « à partir de » par demande.
class FromRateCache620 {
  FromRateCache620._();

  static const Duration ttl = Duration(minutes: 5);
  static final Map<String, PricingEstimate620?> _values = <String, PricingEstimate620?>{};
  static final Map<String, DateTime> _at = <String, DateTime>{};
  static final Map<String, Future<PricingEstimate620?>> _inFlight =
      <String, Future<PricingEstimate620?>>{};

  static void reset() {
    _values.clear();
    _at.clear();
    _inFlight.clear();
  }

  /// Valeur déjà connue (sans requête), null si absente ou périmée.
  static PricingEstimate620? peek(String key) {
    final at = _at[key];
    if (at == null || DateTime.now().difference(at) > ttl) return null;
    return _values[key];
  }

  static Future<PricingEstimate620?> fetch(String key, Map<String, dynamic> body) {
    final at = _at[key];
    if (at != null && DateTime.now().difference(at) <= ttl) {
      return Future<PricingEstimate620?>.value(_values[key]);
    }
    final running = _inFlight[key];
    if (running != null) return running;
    if (!Get.isRegistered<ApiClient>()) return Future<PricingEstimate620?>.value(null);
    final f = fetchEstimate620(Get.find<ApiClient>(), body).then((e) {
      // Ancien serveur (sans `fromRate`) : on ne garde rien d'exploitable.
      final v = (e != null && e.market) ? e : null;
      _values[key] = v;
      _at[key] = DateTime.now();
      _inFlight.remove(key);
      return v;
    });
    _inFlight[key] = f;
    return f;
  }

  static Future<PricingEstimate620?> forPost(PostModel post) {
    final body = fromRateBodyForPost620(post);
    if (body == null) return Future<PricingEstimate620?>.value(null);
    return fetch(fromRateKey620(post.id, body), body);
  }

  static Future<PricingEstimate620?> forNearby(NearbyRequestPost r) {
    final body = fromRateBodyForNearby620(r);
    if (body == null) return Future<PricingEstimate620?>.value(null);
    return fetch(fromRateKey620(r.id, body), body);
  }
}

/// Fournit le texte « à partir de … » d'une demande à un constructeur
/// (vide tant qu'il n'est pas connu ou quand il n'y a rien à montrer).
class FromRate620Builder extends StatelessWidget {
  const FromRate620Builder({
    super.key,
    required this.future,
    required this.builder,
    this.valueOnly = true,
  });
  final Future<PricingEstimate620?> future;
  final Widget Function(BuildContext context, String label) builder;
  /// Vrai (défaut) : sans le préfixe « à partir de » (case étiquetée).
  final bool valueOnly;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PricingEstimate620?>(
      future: future,
      builder: (ctx, snap) => builder(
          ctx, valueOnly ? fromRateValueText620(snap.data) : fromRateText620(snap.data)),
    );
  }
}

/// Ligne « à partir de 12 €/visite · estimation ~86 € » (étiquette prix
/// dessinée à la couleur du rôle) ; rien tant que le serveur n'a pas répondu
/// ou s'il n'y a aucun prestataire par ici.
class FromRateLine620 extends StatelessWidget {
  const FromRateLine620({
    super.key,
    required this.future,
    this.tone,
    this.compact = false,
  });
  final Future<PricingEstimate620?> future;
  final Color? tone;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final Color t = tone ?? AppColors.primaryColor;
    final Color on = AppColors.accentOn(context, t);
    return FutureBuilder<PricingEstimate620?>(
      future: future,
      builder: (ctx, snap) {
        final text = fromRateText620(snap.data);
        if (text.isEmpty) return const SizedBox.shrink();
        return Container(
          key: const Key('dates620_from_rate_line'),
          margin: EdgeInsets.only(top: compact ? 6.h : 8.h),
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: compact ? 5.h : 7.h),
          decoration: BoxDecoration(
            color: t.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: t.withValues(alpha: 0.30)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.sell_rounded, size: compact ? 14.sp : 16.sp, color: on),
              SizedBox(width: 6.w),
              Flexible(
                child: InterText(
                  text: text,
                  fontSize: compact ? 12.sp : 13.sp,
                  fontWeight: FontWeight.w700,
                  color: on,
                  maxLines: 2,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

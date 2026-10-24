// 620 (PAM, 24/10/2026 — contrat CONTRAT_620_dates_visites.md §C.1/§C.4) —
// CATALOGUE DES SERVICES, une seule source pour l'app :
//   · lu sur `GET /app-config/services` (public, cache 60 s côté serveur) :
//     4 services avec leur UNITÉ — garde (`house_sitting`, jour / nuit),
//     visite à domicile (`home_visit`, par visite, 30 | 60 min, 1 | 2 visites
//     par jour), garderie (`day_care`, jour), promenade (`dog_walking`, balade) ;
//   · REPLI quand le serveur ne répond pas ou ne connaît pas encore le
//     catalogue (ancien serveur, panne, hors ligne) : les 3 services
//     d'aujourd'hui, inchangés. Jamais de « visite à domicile » proposée à un
//     serveur qui ne saurait pas la recevoir.
//
// Clés : l'app publie ses gardes multi-jours sous `pet_sitting` depuis 2026
// (`house_sitting` y a été fondu) ; le catalogue serveur et le site disent
// `house_sitting`. La correspondance se fait ICI (`appValueFor` /
// `catalogKeyFor`) pour que les annonces, les cartes et le moteur de prix
// continuent de se comprendre. Pure et testable (aucun widget).
import 'dart:async';

import 'package:get/get.dart';

import '../data/network/api_client.dart';
import '../data/network/api_exception.dart';

/// Unité de facturation d'un service (contrat §A.2).
enum ServiceUnit620 { day, visit, walk }

ServiceUnit620 serviceUnit620Parse(String? raw) {
  switch ((raw ?? '').trim().toLowerCase()) {
    case 'visit':
    case 'visits':
      return ServiceUnit620.visit;
    case 'walk':
    case 'walks':
      return ServiceUnit620.walk;
    default:
      return ServiceUnit620.day;
  }
}

String serviceUnit620Wire(ServiceUnit620 u) {
  switch (u) {
    case ServiceUnit620.day:
      return 'day';
    case ServiceUnit620.visit:
      return 'visit';
    case ServiceUnit620.walk:
      return 'walk';
  }
}

/// Un service du catalogue.
class ServiceDef620 {
  const ServiceDef620({
    required this.key,
    required this.unit,
    this.labels = const <String, String>{},
    this.descriptions = const <String, String>{},
    this.durations = const <int>[],
    this.visitsPerDay = const <int>[],
  });

  /// Clé du catalogue serveur (`house_sitting`, `home_visit`, `day_care`,
  /// `dog_walking`).
  final String key;
  final ServiceUnit620 unit;
  /// Libellés par langue (fr en es de it pt ko ja pl), tels que renvoyés par
  /// le serveur ; vides en repli (l'app utilise alors ses propres clés).
  final Map<String, String> labels;
  final Map<String, String> descriptions;
  /// Durées proposées (visite : 30 | 60 min).
  final List<int> durations;
  /// Visites par jour proposées (visite : 1 | 2).
  final List<int> visitsPerDay;

  /// Valeur envoyée par l'APP dans `serviceTypes` (garde = `pet_sitting`).
  String get appValue => ServiceCatalog620.appValueFor(key);

  static ServiceDef620? tryParse(dynamic raw) {
    if (raw is! Map) return null;
    final key = (raw['key'] ?? raw['id'] ?? raw['type'] ?? raw['serviceType'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    if (key.isEmpty) return null;
    Map<String, String> strMap(dynamic v) {
      if (v is! Map) return const <String, String>{};
      final out = <String, String>{};
      v.forEach((k, val) {
        final s = (val ?? '').toString().trim();
        if (s.isNotEmpty) out[k.toString().toLowerCase()] = s;
      });
      return out;
    }

    List<int> ints(dynamic v) {
      if (v is! List) return const <int>[];
      return v
          .map((e) => e is num ? e.toInt() : int.tryParse(e.toString()))
          .whereType<int>()
          .where((n) => n > 0)
          .toList();
    }

    return ServiceDef620(
      key: key,
      unit: serviceUnit620Parse((raw['unit'] ?? raw['priceUnit'])?.toString()),
      // Serveur 620 : `label` / `desc` par langue (liste `all`) ; `labels` /
      // `descriptions` acceptés aussi.
      labels: strMap(raw['labels'] ?? raw['label'] ?? raw['names']),
      descriptions: strMap(raw['descriptions'] ?? raw['desc'] ?? raw['description']),
      durations: ints(raw['durations'] ?? raw['durationMinutes'] ?? raw['visitDurations']),
      visitsPerDay: ints(raw['visitsPerDay'] ?? raw['visitsPerDayOptions']),
    );
  }
}

/// Les 3 services d'aujourd'hui (repli), dans l'ordre de l'écran « Publier ma
/// demande » : promenade, garderie, garde multi-jours.
const List<ServiceDef620> kFallbackServices620 = <ServiceDef620>[
  ServiceDef620(key: 'dog_walking', unit: ServiceUnit620.walk),
  ServiceDef620(key: 'day_care', unit: ServiceUnit620.day),
  ServiceDef620(key: 'house_sitting', unit: ServiceUnit620.day),
];

/// Les 4 services du contrat, si le serveur les confirme (ordre d'affichage).
const List<String> kCatalogOrder620 = <String>[
  'dog_walking',
  'day_care',
  'house_sitting',
  'home_visit',
];

class ServiceCatalog620 {
  ServiceCatalog620._();

  static const String endpoint = '/app-config/services';
  static const Duration cacheTtl = Duration(seconds: 60);

  /// Services connus (repli tant que le serveur n'a pas répondu).
  static final RxList<ServiceDef620> services =
      <ServiceDef620>[...kFallbackServices620].obs;

  /// Vrai quand la liste vient du serveur (pas du repli).
  static final RxBool fromServer = false.obs;

  static DateTime? _loadedAt;
  static Future<void>? _inFlight;

  /// Remise à zéro (tests).
  static void reset() {
    services.assignAll(kFallbackServices620);
    fromServer.value = false;
    _loadedAt = null;
    _inFlight = null;
  }

  static bool get hasHomeVisit => services.any((s) => s.key == 'home_visit');

  static ServiceDef620? byKey(String? key) {
    final k = catalogKeyFor(key);
    for (final s in services) {
      if (s.key == k) return s;
    }
    return null;
  }

  /// `house_sitting` (catalogue) → `pet_sitting` (valeur de l'app) ; le reste
  /// inchangé.
  static String appValueFor(String? catalogKey) {
    final k = (catalogKey ?? '').trim().toLowerCase();
    return k == 'house_sitting' ? 'pet_sitting' : k;
  }

  /// `pet_sitting` (app) → `house_sitting` (catalogue, site, moteur de prix).
  static String catalogKeyFor(String? appValue) {
    final k = (appValue ?? '').trim().toLowerCase();
    if (k == 'pet_sitting' || k == 'boarding') return 'house_sitting';
    return k;
  }

  /// Unité d'un service (par sa clé catalogue OU sa valeur app). Sans
  /// catalogue : promenade = balade, visite = visite, le reste = jour.
  static ServiceUnit620 unitFor(String? service) {
    final def = byKey(service);
    if (def != null) return def.unit;
    final k = catalogKeyFor(service);
    if (k == 'dog_walking') return ServiceUnit620.walk;
    if (k == 'home_visit' ||
        k == 'drop_in' ||
        k == 'drop_in_visit' ||
        k == 'pet_visit' ||
        k == 'visit' ||
        k == 'visits') {
      return ServiceUnit620.visit;
    }
    return ServiceUnit620.day;
  }

  /// Libellé d'un service dans la langue de l'app : celui du serveur s'il
  /// existe, sinon la clé de traduction de l'app.
  static String label(String? service, {String? lang}) {
    final def = byKey(service);
    final l = (lang ?? Get.locale?.languageCode ?? 'en').toLowerCase();
    if (def != null && def.labels.isNotEmpty) {
      final v = def.labels[l] ?? def.labels['en'] ?? def.labels.values.first;
      if (v.trim().isNotEmpty) return v;
    }
    final k = catalogKeyFor(service);
    switch (k) {
      case 'dog_walking':
        return 'publish_request_service_walking'.tr;
      case 'day_care':
        return 'publish_request_service_daycare'.tr;
      case 'house_sitting':
        return 'publish_request_service_pet_sitting'.tr;
      case 'home_visit':
        return 'dates620_service_home_visit'.tr;
      default:
        return k;
    }
  }

  /// Description courte (carte de service).
  static String description(String? service, {String? lang}) {
    final def = byKey(service);
    final l = (lang ?? Get.locale?.languageCode ?? 'en').toLowerCase();
    if (def != null && def.descriptions.isNotEmpty) {
      final v = def.descriptions[l] ?? def.descriptions['en'] ?? '';
      if (v.trim().isNotEmpty) return v;
    }
    switch (catalogKeyFor(service)) {
      case 'dog_walking':
        return 'publish_request_service_walking_desc'.tr;
      case 'day_care':
        return 'publish_request_service_daycare_desc'.tr;
      case 'house_sitting':
        return 'publish_request_service_pet_sitting_desc'.tr;
      case 'home_visit':
        return 'dates620_service_home_visit_desc'.tr;
      default:
        return '';
    }
  }

  /// Lit la réponse du serveur (`{services:[…]}`, `[…]`, ou `{data:{…}}`).
  /// Renvoie la liste ORDONNÉE (ordre du contrat) ou null si rien d'exploitable.
  static List<ServiceDef620>? parse(dynamic response) {
    dynamic list = response;
    if (list is Map) {
      // Serveur 620 : `services` (clé + unité) et `all` (même liste avec
      // libellés 9 langues, descriptions, `active`). On prend la plus riche.
      final all = list['all'];
      if (all is List && all.isNotEmpty) {
        list = all.where((e) => e is Map && e['active'] != false).toList();
      } else {
        list = list['services'] ?? list['catalog'] ?? list['items'] ?? list['data'];
      }
      if (list is Map) list = list['services'] ?? list.values.toList();
    }
    if (list is! List) return null;
    final parsed = list.map(ServiceDef620.tryParse).whereType<ServiceDef620>().toList();
    if (parsed.isEmpty) return null;
    final byKey = <String, ServiceDef620>{for (final s in parsed) s.key: s};
    final out = <ServiceDef620>[
      for (final k in kCatalogOrder620)
        if (byKey.containsKey(k)) byKey[k]!,
    ];
    // Un service inconnu du contrat n'est pas proposé (l'app ne saurait pas
    // le dessiner ni le tarifer).
    return out.isEmpty ? null : out;
  }

  /// Applique une liste lue (tests ou réponse serveur).
  static void apply(List<ServiceDef620> list) {
    services.assignAll(list);
    fromServer.value = true;
    _loadedAt = DateTime.now();
  }

  /// Charge le catalogue (une fois par minute au plus). Ne lève jamais : en
  /// cas d'échec, le repli (3 services) reste en place.
  static Future<void> load({ApiClient? client, bool force = false}) {
    final now = DateTime.now();
    if (!force &&
        _loadedAt != null &&
        now.difference(_loadedAt!) < cacheTtl) {
      return Future<void>.value();
    }
    final running = _inFlight;
    if (running != null) return running;
    final f = _load(client).whenComplete(() => _inFlight = null);
    _inFlight = f;
    return f;
  }

  static Future<void> _load(ApiClient? client) async {
    try {
      final api = client ?? (Get.isRegistered<ApiClient>() ? Get.find<ApiClient>() : null);
      if (api == null) return;
      final res = await api.get(endpoint).timeout(const Duration(seconds: 8));
      final list = parse(res);
      if (list != null) apply(list);
    } on ApiException catch (_) {
      // 404 (ancien serveur) ou autre : repli silencieux.
    } on TimeoutException catch (_) {
      // Hors ligne : repli.
    } catch (_) {
      // Jamais fatal.
    }
  }
}

/// « 12 €/visite », « 18 €/jour », « 10 €/balade », « 20 €/nuit » — l'unité
/// traduite après le montant déjà formaté.
String priceWithUnit620(String formattedAmount, ServiceUnit620 unit,
    {bool night = false}) {
  return '$formattedAmount/${unitLabel620(unit, night: night)}';
}

String unitLabel620(ServiceUnit620 unit, {bool night = false}) {
  switch (unit) {
    case ServiceUnit620.day:
      return (night ? 'dates620_unit_night' : 'dates620_unit_day').tr;
    case ServiceUnit620.visit:
      return 'dates620_unit_visit'.tr;
    case ServiceUnit620.walk:
      return 'dates620_unit_walk'.tr;
  }
}

/// Unité renvoyée par le serveur (`priceUnit` : day | night | visit | walk |
/// hour | week | month) → suffixe traduit « /jour », « /visite »… Vide si
/// inconnue.
String priceUnitSuffix620(String? unit) {
  switch ((unit ?? '').trim().toLowerCase()) {
    case 'day':
    case 'daily':
      return '/${'dates620_unit_day'.tr}';
    case 'night':
      return '/${'dates620_unit_night'.tr}';
    case 'visit':
      return '/${'dates620_unit_visit'.tr}';
    case 'walk':
      return '/${'dates620_unit_walk'.tr}';
    case 'hour':
    case 'hourly':
      return '/${'pawmap_rate_unit_hour'.tr}';
    case 'week':
    case 'weekly':
      return 'pm605_per_week'.tr;
    case 'month':
    case 'monthly':
      return 'pm605_per_month'.tr;
    default:
      return '';
  }
}

/// « 1 visite » / « 5 visites », « 1 jour » / « 3 jours », « 2 nuits »,
/// « 1 balade »… (quantité renvoyée par le moteur de prix).
String quantityLabel620(int n, ServiceUnit620 unit, {bool night = false}) {
  final String one;
  final String many;
  switch (unit) {
    case ServiceUnit620.day:
      one = night ? 'dates620_qty_night' : 'dates620_qty_day';
      many = night ? 'dates620_qty_nights' : 'dates620_qty_days';
      break;
    case ServiceUnit620.visit:
      one = 'dates620_qty_visit';
      many = 'dates620_qty_visits';
      break;
    case ServiceUnit620.walk:
      one = 'dates620_qty_walk';
      many = 'dates620_qty_walks';
      break;
  }
  return n == 1 ? one.tr : many.tr.replaceAll('@n', '$n');
}

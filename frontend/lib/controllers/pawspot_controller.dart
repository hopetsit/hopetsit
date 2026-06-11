import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/views/boost/coin_shop_screen.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';

/// v23.1.353 — refonte PawSpot (Daniel). PawSpot = spots pet-friendly
/// COMMUNAUTAIRES sur la PawMap (remplace les anciens halos "map boost").
/// Backend : backend/src/routes/pawSpotRoutes.js (monté sur /pawspots).
///
/// Gratuit : voir les spots + créer jusqu'à 3 spots. Abonnés PawSpot
/// (4,99 €/mois · 39,99 €/an · essai 7 j) : tag illimité, meilleurs spots,
/// récompenses à points. Le flag `pawspotActive` vient de
/// GET /users/me/benefits.
class PawSpotModel {
  const PawSpotModel({
    required this.id,
    required this.type,
    required this.name,
    this.description = '',
    this.photoUrl = '',
    required this.lat,
    required this.lng,
    this.creatorId = '',
    this.creatorName = '',
    this.likesCount = 0,
    this.validationsCount = 0,
    this.visitsCount = 0,
    this.commentsCount = 0,
    this.communityValidated = false,
    this.isGolden = false,
    this.featured = false,
    this.quality = 3.0,
  });

  final String id;
  final String type;
  final String name;
  final String description;
  final String photoUrl;
  final double lat;
  final double lng;
  final String creatorId;
  final String creatorName;
  final int likesCount;
  final int validationsCount;
  final int visitsCount;
  final int commentsCount;
  final bool communityValidated;

  /// Empreinte DORÉE 🐾 : validé communauté OU 50+ likes OU créateur Gold.
  final bool isGolden;
  final bool featured;

  /// ⭐ qualité (système de confiance) : 3.0 base, +0.5/validation, cap 5.
  final double quality;

  factory PawSpotModel.fromJson(Map<String, dynamic> j) {
    return PawSpotModel(
      id: (j['id'] ?? j['_id'] ?? '').toString(),
      type: (j['type'] as String?) ?? 'other',
      name: (j['name'] as String?) ?? '',
      description: (j['description'] as String?) ?? '',
      photoUrl: (j['photoUrl'] as String?) ?? '',
      lat: ((j['lat'] as num?) ?? 0).toDouble(),
      lng: ((j['lng'] as num?) ?? 0).toDouble(),
      creatorId: (j['creatorId'] ?? '').toString(),
      creatorName: (j['creatorName'] as String?) ?? '',
      likesCount: ((j['likesCount'] as num?) ?? 0).toInt(),
      validationsCount: ((j['validationsCount'] as num?) ?? 0).toInt(),
      visitsCount: ((j['visitsCount'] as num?) ?? 0).toInt(),
      commentsCount: ((j['commentsCount'] as num?) ?? 0).toInt(),
      communityValidated: j['communityValidated'] == true,
      isGolden: j['isGolden'] == true,
      featured: j['featured'] == true,
      quality: ((j['quality'] as num?) ?? 3).toDouble(),
    );
  }
}

/// Mapping type de spot → (emoji, couleur) — parité avec le doc PawSpot.
class PawSpotTypes {
  PawSpotTypes._();

  static const List<String> all = [
    'path_walk',
    'chill',
    'playground',
    'swimming',
    'food_cafe',
    'other',
  ];

  static String emoji(String t) {
    switch (t) {
      case 'path_walk':
        return '🚶';
      case 'chill':
        return '🧘';
      case 'playground':
        return '🛝';
      case 'swimming':
        return '🏊';
      case 'food_cafe':
        return '☕';
      default:
        return '📍';
    }
  }

  // v23.1.356 — couleurs alignées sur la légende de la maquette Daniel
  // (« exemple de spots tagués ») : vert / bleu / rouge / teal / doré / rose.
  static Color color(String t) {
    switch (t) {
      case 'path_walk':
        return const Color(0xFF16A34A);
      case 'chill':
        return const Color(0xFF2563EB);
      case 'playground':
        return const Color(0xFFEF4444);
      case 'swimming':
        return const Color(0xFF14B8A6);
      case 'food_cafe':
        return const Color(0xFFE8A00A);
      default:
        return const Color(0xFFEC4899);
    }
  }

  /// Label localisé — les clés `pawspot_type_<type>` existent en 6 langues.
  static String label(String t) =>
      all.contains(t) ? 'pawspot_type_$t'.tr : 'pawspot_type_other'.tr;
}

/// Résultat de GET /pawspots/directions (itinéraire "Y aller").
class PawSpotDirections {
  const PawSpotDirections({
    required this.points,
    this.distanceMeters,
    this.durationSeconds,
  });

  final List<LatLng> points;
  final int? distanceMeters;
  final int? durationSeconds;
}

class PawSpotController extends GetxController {
  /// Spots autour du centre de carte courant (couche PawSpot 🐾).
  final RxList<PawSpotModel> spots = <PawSpotModel>[].obs;
  final RxBool isLoading = false.obs;

  /// Lu via GET /users/me/benefits → champ `pawspotActive` (abo payé,
  /// essai 7 j en cours ou staff).
  final RxBool pawspotActive = false.obs;

  /// v23.1.356 — abo suivi actif (PawFollow OU PawFamily) : pilote l'état
  /// violet + couronne 👑 du chip PawFollow de la PawMap.
  final RxBool followActive = false.obs;

  ApiClient? get _api =>
      Get.isRegistered<ApiClient>() ? Get.find<ApiClient>() : null;

  /// Extrait le `code` métier d'une ApiException (PAWSPOT_REQUIRED,
  /// PAWFOLLOW_REQUIRED, INSUFFICIENT_POINTS...). Null si absent.
  static String? errorCode(Object e) {
    if (e is ApiException && e.details is Map) {
      final code = (e.details as Map)['code'];
      if (code is String && code.isNotEmpty) return code;
    }
    return null;
  }

  static int? statusCode(Object e) => e is ApiException ? e.statusCode : null;

  /// Refetch le flag pawspotActive depuis /users/me/benefits. Retourne la
  /// valeur fraîche (false si l'appel échoue ET qu'on n'avait rien en cache).
  Future<bool> refreshBenefits() async {
    try {
      final r = await _api?.get('/users/me/benefits', requiresAuth: true);
      if (r is Map) {
        pawspotActive.value = r['pawspotActive'] == true;
        followActive.value =
            r['pawFollowActive'] == true || r['familyActive'] == true;
      }
    } catch (e) {
      debugPrint('[PawSpot] refreshBenefits error: $e');
    }
    return pawspotActive.value;
  }

  /// GET /pawspots/nearby — spots publics autour d'un point (25 km).
  Future<void> loadNearby(LatLng center) async {
    final api = _api;
    if (api == null) return;
    isLoading.value = true;
    try {
      final r = await api.get(
        '/pawspots/nearby',
        queryParameters: {
          'lat': center.latitude.toString(),
          'lng': center.longitude.toString(),
          'radius': '25000',
        },
        requiresAuth: true,
      );
      final list = (r is Map ? r['spots'] as List? : null) ?? const [];
      spots.assignAll(
        list
            .whereType<Map>()
            .map((j) => PawSpotModel.fromJson(Map<String, dynamic>.from(j)))
            .where((s) => !(s.lat == 0 && s.lng == 0)),
      );
    } catch (e) {
      debugPrint('[PawSpot] loadNearby error: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// POST /pawspots — crée un spot. Retourne les points gagnés (+10, +5 si
  /// photo). LAISSE REMONTER l'ApiException (402 PAWSPOT_REQUIRED = limite
  /// gratuite de 3 spots atteinte) pour que l'UI ouvre la boutique.
  Future<int> create({
    required String type,
    required String name,
    String description = '',
    String photoUrl = '',
    required double lat,
    required double lng,
    String city = '',
  }) async {
    final api = Get.find<ApiClient>();
    final r = await api.post(
      '/pawspots',
      body: {
        'type': type,
        'name': name,
        'description': description,
        'photoUrl': photoUrl,
        'lat': lat,
        'lng': lng,
        'city': city,
      },
      requiresAuth: true,
    );
    return (r is Map ? (r['pointsEarned'] as num?) : null)?.toInt() ?? 0;
  }

  /// POST /pawspots/:id/like — toggle ❤️. Retourne {liked, likesCount} ou
  /// null en cas d'échec.
  Future<Map<String, dynamic>?> like(String id) async {
    try {
      final r = await _api?.post('/pawspots/$id/like', requiresAuth: true);
      return r is Map ? Map<String, dynamic>.from(r) : null;
    } catch (e) {
      debugPrint('[PawSpot] like error: $e');
      return null;
    }
  }

  /// POST /pawspots/:id/validate — 🏆 valider (3 validations = badge doré).
  /// Retourne {validated, validationsCount, already?} ou null.
  Future<Map<String, dynamic>?> validate(String id) async {
    try {
      final r = await _api?.post('/pawspots/$id/validate', requiresAuth: true);
      return r is Map ? Map<String, dynamic>.from(r) : null;
    } catch (e) {
      debugPrint('[PawSpot] validate error: $e');
      return null;
    }
  }

  /// POST /pawspots/:id/visit — 👣 marque une visite (best-effort, 1x/user).
  Future<void> visit(String id) async {
    try {
      await _api?.post('/pawspots/$id/visit', requiresAuth: true);
    } catch (e) {
      debugPrint('[PawSpot] visit error: $e');
    }
  }

  /// POST /pawspots/:id/comment — 💬 ajoute un commentaire (+2 pts, modéré).
  Future<bool> comment(String id, String text) async {
    try {
      await _api?.post(
        '/pawspots/$id/comment',
        body: {'text': text},
        requiresAuth: true,
      );
      return true;
    } catch (e) {
      debugPrint('[PawSpot] comment error: $e');
      return false;
    }
  }

  /// GET /pawspots/:id/comments — liste {id, authorName, text, createdAt}.
  Future<List<Map<String, dynamic>>> comments(String id) async {
    try {
      final r = await _api?.get('/pawspots/$id/comments', requiresAuth: true);
      final list = (r is Map ? r['comments'] as List? : null) ?? const [];
      return list
          .whereType<Map>()
          .map((c) => Map<String, dynamic>.from(c))
          .toList();
    } catch (e) {
      debugPrint('[PawSpot] comments error: $e');
      return const [];
    }
  }

  /// DELETE /pawspots/:id — créateur uniquement.
  Future<bool> deleteSpot(String id) async {
    try {
      await _api?.delete('/pawspots/$id', requiresAuth: true);
      spots.removeWhere((s) => s.id == id);
      return true;
    } catch (e) {
      debugPrint('[PawSpot] delete error: $e');
      return false;
    }
  }

  /// GET /pawspots/directions — itinéraire piéton "Y aller" (OSRM côté
  /// backend, fallback ligne droite). LAISSE REMONTER l'ApiException 402
  /// PAWFOLLOW_REQUIRED (inclus dans PawFollow / PawFamily).
  Future<PawSpotDirections> fetchDirections({
    required LatLng from,
    required LatLng to,
  }) async {
    final api = Get.find<ApiClient>();
    final r = await api.get(
      '/pawspots/directions',
      queryParameters: {
        'fromLat': from.latitude.toString(),
        'fromLng': from.longitude.toString(),
        'toLat': to.latitude.toString(),
        'toLng': to.longitude.toString(),
      },
      requiresAuth: true,
    );
    final raw = (r is Map ? r['points'] as List? : null) ?? const [];
    final points = <LatLng>[];
    for (final p in raw) {
      if (p is Map) {
        final lat = (p['lat'] as num?)?.toDouble();
        final lng = (p['lng'] as num?)?.toDouble();
        if (lat != null && lng != null) points.add(LatLng(lat, lng));
      }
    }
    return PawSpotDirections(
      points: points,
      distanceMeters:
          (r is Map ? (r['distanceMeters'] as num?) : null)?.toInt(),
      durationSeconds:
          (r is Map ? (r['durationSeconds'] as num?) : null)?.toInt(),
    );
  }

  /// GET /pawspots/me/points — points, badge, compteur spots, statut abo.
  Future<Map<String, dynamic>?> myPoints() async {
    try {
      final r = await _api?.get('/pawspots/me/points', requiresAuth: true);
      return r is Map ? Map<String, dynamic>.from(r) : null;
    } catch (e) {
      debugPrint('[PawSpot] myPoints error: $e');
      return null;
    }
  }

  /// POST /pawspots/rewards/redeem — dépense de PawPoints (abonnés).
  /// LAISSE REMONTER l'ApiException (402 INSUFFICIENT_POINTS /
  /// PAWSPOT_REQUIRED) pour que l'UI réagisse.
  Future<void> redeemReward(String reward, {String? spotId}) async {
    final api = Get.find<ApiClient>();
    await api.post(
      '/pawspots/rewards/redeem',
      body: {
        'reward': reward,
        if (spotId != null) 'spotId': spotId,
      },
      requiresAuth: true,
    );
  }

  /// Essai gratuit 7 j (1 seule fois) — sinon redirige vers la boutique
  /// PawSpot (CoinShop onglet 2).
  Future<void> startTrialOrShop() async {
    try {
      await Get.find<ApiClient>().post('/pawspots/trial', requiresAuth: true);
      pawspotActive.value = true;
      CustomSnackbar.showSuccess(
        title: 'PawSpot',
        message: 'pawspot_trial_started'.tr,
      );
    } catch (e) {
      // Essai déjà utilisé (409 TRIAL_USED) ou erreur → boutique.
      Get.to(() => const CoinShopScreen(initialTab: 2));
    }
  }

  /// Upload photo via POST /uploads/form-data (multipart Cloudinary,
  /// champ 'file' → {url, publicId}). Retourne l'URL ou null.
  Future<String?> uploadPhoto(File file) async {
    try {
      final api = Get.find<ApiClient>();
      final r = await api.postMultipart(
        '/uploads/form-data',
        file: file,
        fileFieldName: 'file',
        fields: const {'folder': 'petsinsta/pawspots', 'resourceType': 'image'},
        requiresAuth: true,
      );
      final url = (r is Map ? r['url'] : null)?.toString() ?? '';
      return url.isEmpty ? null : url;
    } catch (e) {
      debugPrint('[PawSpot] uploadPhoto error: $e');
      return null;
    }
  }
}

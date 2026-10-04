import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/models/map_report_model.dart';

/// 610 (ZOE) — état du quota « confort » (GET /map-reports/quota).
class ComfortQuota {
  const ComfortQuota({
    required this.unlimited,
    this.limit = 1,
    this.used = 0,
    this.remaining = 1,
    this.nextAvailableAt,
  });

  final bool unlimited;
  final int limit;
  final int used;
  final int remaining;
  final DateTime? nextAvailableAt;

  bool get exhausted => !unlimited && remaining <= 0;

  factory ComfortQuota.fromJson(Map<String, dynamic> j) {
    return ComfortQuota(
      unlimited: j['unlimited'] == true,
      limit: (j['limit'] as num?)?.toInt() ?? 1,
      used: (j['used'] as num?)?.toInt() ?? 0,
      remaining: (j['remaining'] as num?)?.toInt() ?? 1,
      nextAvailableAt:
          DateTime.tryParse(j['nextAvailableAt']?.toString() ?? '')?.toLocal(),
    );
  }
}

/// Controller for Couche 2 — ephemeral 48h reports.
///
/// 610 (ZOE, règle B) : tout le monde voit tout ; danger = gratuit et
/// illimité ; confort = 1 par semaine sans abonnement (429
/// COMFORT_WEEKLY_LIMIT → `comfortLimitReached`) ; animal perdu / trouvé =
/// abonnés (402 → `premiumRequired`).
class MapReportController extends GetxController {
  final RxBool isLoading = false.obs;
  final RxBool isSubmitting = false.obs;
  final RxBool premiumRequired = false.obs;

  /// 610 — quota confort ; null = inconnu (le serveur tranche).
  final Rxn<ComfortQuota> comfortQuota = Rxn<ComfortQuota>();

  /// 610 — vrai si le dernier envoi a été refusé par la limite hebdomadaire.
  final RxBool comfortLimitReached = false.obs;

  /// 610 — lit le compteur « 1 par semaine ». Ne lève jamais.
  Future<void> loadQuota() async {
    try {
      final api = Get.find<ApiClient>();
      final data = await api.get('/map-reports/quota', requiresAuth: true);
      final c = (data is Map ? data['comfort'] : null);
      if (c is Map) {
        comfortQuota.value =
            ComfortQuota.fromJson(Map<String, dynamic>.from(c));
      }
    } catch (e) {
      debugPrint('[MapReports] loadQuota error: $e');
    }
  }
  final RxList<MapReport> reports = <MapReport>[].obs;

  /// Radius in meters for nearby queries (defaults to 3 km for reports).
  int maxDistanceMeters = 3000;

  Future<void> loadNearby(LatLng center, {String? type}) async {
    isLoading.value = true;
    premiumRequired.value = false;
    try {
      final api = Get.find<ApiClient>();
      final data = await api.get(
        '/map-reports/nearby',
        queryParameters: {
          'lat': center.latitude,
          'lng': center.longitude,
          'maxDistance': maxDistanceMeters,
          if (type != null) 'type': type,
        },
        requiresAuth: true,
      );

      final list = (data['reports'] as List?) ?? const [];
      reports.value = list
          .map((r) => MapReport.fromJson(r as Map<String, dynamic>))
          .toList();
    } on ApiException catch (e) {
      // 402 — premium required
      if (e.statusCode == 402) {
        premiumRequired.value = true;
        reports.clear();
      } else {
        debugPrint('[MapReports] loadNearby API error: ${e.message}');
      }
    } catch (e) {
      debugPrint('[MapReports] loadNearby error: $e');
      // 607 (PAM) — erreur réseau : les signalements affichés restent.
    } finally {
      isLoading.value = false;
    }
  }

  /// Submit a new report at [point]. Returns the created MapReport or null on failure.
  Future<MapReport?> createReport({
    required String type,
    required LatLng point,
    String? note,
    String? photoUrl,
    String? city,
  }) async {
    isSubmitting.value = true;
    premiumRequired.value = false;
    comfortLimitReached.value = false;
    try {
      final api = Get.find<ApiClient>();
      final data = await api.post(
        '/map-reports',
        body: {
          'type': type,
          'lat': point.latitude,
          'lng': point.longitude,
          if (note != null) 'note': note,
          if (photoUrl != null) 'photoUrl': photoUrl,
          if (city != null) 'city': city,
        },
        requiresAuth: true,
      );

      final reportJson = (data['report'] as Map?)?.cast<String, dynamic>();
      if (reportJson == null) return null;
      final report = MapReport.fromJson(reportJson);
      reports.add(report);
      if (ReportTypes.isComfort(type)) {
        // 610 — le compteur suit tout de suite (puis la vérité serveur).
        final q = comfortQuota.value;
        if (q != null && !q.unlimited) {
          comfortQuota.value = ComfortQuota(
            unlimited: false,
            limit: q.limit,
            used: q.used + 1,
            remaining: q.remaining > 0 ? q.remaining - 1 : 0,
            nextAvailableAt: q.nextAvailableAt ??
                DateTime.now().add(const Duration(days: 7)),
          );
        }
        loadQuota();
      }
      return report;
    } on ApiException catch (e) {
      if (e.statusCode == 402) premiumRequired.value = true;
      if (e.statusCode == 429) {
        comfortLimitReached.value = true;
        final next = _nextAvailableFrom(e);
        final q = comfortQuota.value;
        comfortQuota.value = ComfortQuota(
          unlimited: false,
          limit: q?.limit ?? 1,
          used: q?.limit ?? 1,
          remaining: 0,
          nextAvailableAt: next ?? q?.nextAvailableAt,
        );
      }
      debugPrint('[MapReports] createReport API error: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('[MapReports] createReport error: $e');
      return null;
    } finally {
      isSubmitting.value = false;
    }
  }

  DateTime? _nextAvailableFrom(ApiException e) {
    final d = e.details;
    if (d is Map && d['nextAvailableAt'] != null) {
      return DateTime.tryParse(d['nextAvailableAt'].toString())?.toLocal();
    }
    return null;
  }

  /// Confirm a report — extends its life by 12h (max 96h total).
  /// Updates the local `reports` list in place.
  Future<bool> confirm(String reportId) async {
    try {
      final api = Get.find<ApiClient>();
      final data = await api.post(
        '/map-reports/$reportId/confirm',
        requiresAuth: true,
      );
      final newExpiry = DateTime.tryParse(data['expiresAt']?.toString() ?? '');
      final newCount = (data['confirmationsCount'] as num?)?.toInt() ?? 0;
      if (newExpiry != null) {
        final idx = reports.indexWhere((r) => r.id == reportId);
        if (idx != -1) {
          final old = reports[idx];
          reports[idx] = MapReport(
            id: old.id,
            type: old.type,
            note: old.note,
            photoUrl: old.photoUrl,
            latitude: old.latitude,
            longitude: old.longitude,
            city: old.city,
            reporterId: old.reporterId,
            reporterModel: old.reporterModel,
            expiresAt: newExpiry,
            createdAt: old.createdAt,
            hoursRemaining: newExpiry.difference(DateTime.now()).inMinutes / 60.0,
            confirmationsCount: newCount,
          );
          reports.refresh();
        }
      }
      return true;
    } catch (e) {
      debugPrint('[MapReports] confirm error: $e');
      return false;
    }
  }

  /// Flag a report for moderation (3 flags → auto-hidden).
  Future<bool> flag(String reportId, {String? reason}) async {
    try {
      final api = Get.find<ApiClient>();
      final data = await api.post(
        '/map-reports/$reportId/flag',
        body: {if (reason != null) 'reason': reason},
        requiresAuth: true,
      );
      final isHidden = data['hidden'] == true;
      if (isHidden) {
        reports.removeWhere((r) => r.id == reportId);
      }
      return true;
    } catch (e) {
      debugPrint('[MapReports] flag error: $e');
      return false;
    }
  }

  /// Delete a report the current user owns.
  Future<bool> delete(String reportId) async {
    try {
      final api = Get.find<ApiClient>();
      await api.delete('/map-reports/$reportId', requiresAuth: true);
      reports.removeWhere((r) => r.id == reportId);
      return true;
    } catch (e) {
      debugPrint('[MapReports] delete error: $e');
      return false;
    }
  }

  /// Filters report list by a set of types (empty = all).
  List<MapReport> filterByTypes(Set<String> types) {
    if (types.isEmpty) return reports.toList();
    return reports.where((r) => types.contains(r.type)).toList();
  }
}

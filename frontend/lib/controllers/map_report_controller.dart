import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/models/map_report_model.dart';

/// Controller for Couche 2 — ephemeral 48h reports. Premium-only.
///
/// API returns 402 ("PREMIUM_REQUIRED") when a free user tries to load or
/// create reports — the controller surfaces that via `premiumRequired`.
class MapReportController extends GetxController {
  final RxBool isLoading = false.obs;
  final RxBool isSubmitting = false.obs;
  final RxBool premiumRequired = false.obs;
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
      reports.clear();
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
      return report;
    } on ApiException catch (e) {
      if (e.statusCode == 402) premiumRequired.value = true;
      debugPrint('[MapReports] createReport API error: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('[MapReports] createReport error: $e');
      return null;
    } finally {
      isSubmitting.value = false;
    }
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

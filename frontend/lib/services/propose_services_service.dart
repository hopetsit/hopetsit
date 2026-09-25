// v586 (point 9) — « Proposer mes services » en UN appui depuis la fiche d'un
// propriétaire. Même contrat que le bouton de l'accueil gardien / promeneur et
// que la bulle de demande de la PawMap : `SitterRepository.createApplication`
// (animal de l'annonce, service, date, créneau, mon tarif de base, `postId`).
// Règles serveur inchangées : 403 `OWN_POST` sur sa propre annonce, doublon
// d'une candidature en attente → `duplicatePrevented`.
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/models/owner_active_request.dart';
import 'package:hopetsit/repositories/sitter_repository.dart';
import 'package:hopetsit/repositories/walker_repository.dart';
import 'package:hopetsit/utils/logger.dart';
import 'package:hopetsit/utils/storage_keys.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';

/// États du bouton de candidature.
enum OwnerRequestApplyState { idle, busy, sent, already, accepted, rejected }

OwnerRequestApplyState applyStateFromServer(String? status) {
  switch ((status ?? '').toLowerCase()) {
    case 'pending':
      return OwnerRequestApplyState.already;
    case 'accepted':
      return OwnerRequestApplyState.accepted;
    case 'rejected':
      return OwnerRequestApplyState.rejected;
    default:
      return OwnerRequestApplyState.idle;
  }
}

/// Mon tarif de base (même règle que l'accueil et la carte : promeneur =
/// grille de promenades ramenée à l'heure ; gardien = horaire, sinon jour…).
Future<double> myBasePrice(SitterRepository repo, String role) async {
  try {
    final profile = GetStorage().read<Map<String, dynamic>>(StorageKeys.userProfile);
    final myId = (profile?['id'] ?? '').toString();
    if (myId.isEmpty) return 0;
    if (role == 'walker' && Get.isRegistered<WalkerRepository>()) {
      final w = await Get.find<WalkerRepository>().getWalkerProfile(myId);
      double? rate(int min) {
        for (final r in w.walkRates) {
          if (r.durationMinutes == min && r.enabled && r.basePrice > 0) return r.basePrice;
        }
        return null;
      }

      return rate(60) ??
          (rate(30) != null ? rate(30)! * 2 : null) ??
          (rate(90) != null ? rate(90)! * (60 / 90) : null) ??
          (rate(120) != null ? rate(120)! / 2 : null) ??
          0;
    }
    final p = await repo.getSitterProfile(myId);
    final data = (p['sitter'] as Map<String, dynamic>?) ?? (p['profile'] as Map<String, dynamic>?) ?? p;
    for (final k in const ['hourlyRate', 'dailyRate', 'weeklyRate', 'monthlyRate']) {
      final v = (data[k] as num?)?.toDouble();
      if (v != null && v > 0) return v;
    }
    final s = double.tryParse((data['rate'] ?? '').toString());
    if (s != null && s > 0) return s;
  } catch (e) {
    AppLogger.logError('[propose] tarif de base', error: e);
  }
  return 0;
}

/// Envoie la candidature ; renvoie l'état final du bouton.
Future<OwnerRequestApplyState> proposeMyServices(OwnerActiveRequest r, {required String role}) async {
  if (!Get.isRegistered<SitterRepository>()) return OwnerRequestApplyState.idle;
  if (r.petIds.isEmpty) {
    CustomSnackbar.showError(title: 'common_error'.tr, message: 'pawmap_request_no_pets'.tr);
    return OwnerRequestApplyState.idle;
  }
  try {
    final repo = Get.find<SitterRepository>();
    final basePrice = await myBasePrice(repo, role);
    if (basePrice <= 0) {
      CustomSnackbar.showError(title: 'common_error'.tr, message: 'pawmap_request_pricing_missing'.tr);
      return OwnerRequestApplyState.idle;
    }
    final serviceType = r.serviceTypes.isNotEmpty
        ? r.serviceTypes.first
        : (role == 'walker' ? 'dog_walking' : 'pet_sitting');
    final start = r.startDate ?? r.endDate ?? DateTime.now();
    final serviceDate =
        start.toUtc().copyWith(hour: 0, minute: 0, second: 0, millisecond: 0).toIso8601String();
    String timeSlot = 'All Day';
    final ls = r.startDate?.toLocal();
    if (ls != null) {
      final h12 = ls.hour % 12 == 0 ? 12 : ls.hour % 12;
      timeSlot = '$h12:${ls.minute.toString().padLeft(2, '0')} ${ls.hour < 12 ? 'AM' : 'PM'}';
    }
    final res = await repo.createApplication(
      ownerId: r.ownerId,
      petIds: [r.petIds.first],
      serviceType: serviceType,
      serviceDate: serviceDate,
      startDate: r.startDate?.toUtc().toIso8601String(),
      endDate: r.endDate?.toUtc().toIso8601String(),
      timeSlot: timeSlot,
      basePrice: basePrice,
      postId: r.id,
    );
    final dup = res['duplicatePrevented'] == true;
    CustomSnackbar.showSuccess(
      title: 'common_success'.tr,
      message: dup ? 'pawmap_request_already'.tr : 'request_send_success'.tr,
    );
    return dup ? OwnerRequestApplyState.already : OwnerRequestApplyState.sent;
  } on ApiException catch (e) {
    final String msg = e.message;
    final bool dup = msg.contains('ALREADY') || msg.toLowerCase().contains('already') || msg.contains('duplicate');
    CustomSnackbar.showError(
      title: 'common_error'.tr,
      message: dup ? 'pawmap_request_already'.tr : (msg.isNotEmpty ? msg : 'request_send_failed'.tr),
    );
    return dup ? OwnerRequestApplyState.already : OwnerRequestApplyState.idle;
  } catch (e) {
    AppLogger.logError('[propose] candidature', error: e);
    CustomSnackbar.showError(title: 'common_error'.tr, message: 'request_send_failed'.tr);
    return OwnerRequestApplyState.idle;
  }
}

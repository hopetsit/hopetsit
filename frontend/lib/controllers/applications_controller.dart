import 'package:get/get.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/models/application_model.dart';
import 'package:hopetsit/repositories/owner_repository.dart';
import 'package:hopetsit/services/socket_service.dart';
import 'package:hopetsit/utils/logger.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';

/// 627 (PAM) — 409 `RATE_PENDING` du serveur (eee4b792, ZOE 28/10) : le
/// candidat n'a pas encore de tarif pour ce service (ex. aucun tarif par
/// visite). Renvoie la phrase claire à montrer — celle du serveur, déjà dans
/// la langue du propriétaire — ou, à défaut, l'explication locale « Tarif à
/// venir ». `null` si l'erreur n'est pas un RATE_PENDING. Jamais le code brut.
String? ratePendingMessage627(ApiException error) {
  final d = error.details;
  final bool isRatePending = (d is Map && d['code']?.toString() == 'RATE_PENDING') ||
      error.message.contains('RATE_PENDING');
  if (!isRatePending) return null;
  final String server = (d is Map ? (d['error'] ?? d['message'] ?? '') : '').toString().trim();
  if (server.isNotEmpty && !server.contains('RATE_PENDING') && !server.startsWith('Request failed')) {
    return server;
  }
  return 'dates620_stale_explain'.tr;
}

/// 638 (contrôle ZOE) — 409 `ALREADY_PAID` (lot 1011 : la demande a déjà un
/// gardien payé, on ne choisit plus personne d'autre). Le serveur n'envoie
/// qu'une phrase en anglais : on affiche la nôtre, traduite. `null` sinon.
String? alreadyPaidMessage1011(ApiException error) {
  final d = error.details;
  final bool isAlreadyPaid = (d is Map && d['code']?.toString() == 'ALREADY_PAID') ||
      error.message.contains('ALREADY_PAID') ||
      (error.statusCode == 409 && error.message.trim() == 'This request is already paid.');
  return isAlreadyPaid ? 'c1011_already_paid'.tr : null;
}

/// 644 — code métier d'un refus du serveur (`OFFER_TOO_LOW`, `PAY_LATER_TOO_LATE`…),
/// '' si absent. Lu dans le corps de la réponse, jamais deviné.
String apiErrorCode644(ApiException error) {
  final d = error.details;
  if (d is Map && d['code'] != null) return d['code'].toString().trim();
  final m = RegExp(r'\b(OFFER_[A-Z_]+|PAY_LATER_[A-Z_]+)\b').firstMatch(error.message);
  return m?.group(1) ?? '';
}

/// 644 — résultat d'un appel « proposer mon prix » / « réserver, payer plus
/// tard » : `ok`, sinon le code du serveur ('' = panne sans code) et, pour un
/// refus déjà connu de l'app (tarif à venir, déjà payé, dates), sa phrase.
class Result644 {
  const Result644.ok()
      : ok = true,
        code = '',
        message = null;
  const Result644.fail(this.code, {this.message}) : ok = false;
  final bool ok;
  final String code;
  final String? message;
}

class ApplicationsController extends GetxController {
  ApplicationsController({OwnerRepository? ownerRepository})
    : _ownerRepository = ownerRepository ?? Get.find<OwnerRepository>();

  final OwnerRepository _ownerRepository;

  final RxList<ApplicationModel> applications = <ApplicationModel>[].obs;
  final RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadApplications();
    // v23.1 — listen for real-time application:new events so the owner's
    // multi-candidates banner appears immediately when a new sitter/walker
    // applies (instead of waiting for the next periodic refresh). Bug B12.
    _attachSocketListeners();
    // 612 (ZOE) — la prise n'existe pas toujours à ce moment (connexion après
    // le démarrage, reconnexion) : l'écoute posée sur une prise absente était
    // perdue pour toujours. On la repose à CHAQUE connexion de la prise.
    try {
      if (Get.isRegistered<SocketService>()) {
        Get.find<SocketService>().addOnConnectedHook(_attachSocketListeners);
      }
    } catch (_) {/* best-effort */}
  }

  void _attachSocketListeners() {
    try {
      if (!Get.isRegistered<SocketService>()) return;
      final s = Get.find<SocketService>();
      s.socket?.off('application:new');
      s.socket?.on('application:new', (_) {
        loadApplications();
      });
      s.socket?.off('application:updated');
      s.socket?.on('application:updated', (_) {
        loadApplications();
      });
    } catch (e) {
      AppLogger.logError('ApplicationsController socket bind failed', error: e);
    }
  }

  Future<void> loadApplications() async {
    isLoading.value = true;

    try {
      final applicationsList = await _ownerRepository.getMyApplications();
      applications.assignAll(applicationsList);
    } on ApiException catch (error) {
      AppLogger.logError('Failed to load applications', error: error.message);
      applications.clear();
    } catch (error) {
      AppLogger.logError('Failed to load applications', error: error);
      applications.clear();
    } finally {
      isLoading.value = false;
    }
  }

  /// 644 — met à jour UNE candidature en place (état renvoyé par le serveur).
  void patch644(String applicationId, ApplicationModel Function(ApplicationModel a) change) {
    final i = applications.indexWhere((a) => a.id == applicationId);
    if (i >= 0) applications[i] = change(applications[i]);
  }

  /// 644 — « Proposer mon prix » : le serveur vérifie les bornes, prévient le
  /// gardien et renvoie l'état à afficher. Le prix de la carte ne change
  /// qu'après l'accord du gardien (nouveau `pricing` au rechargement).
  Future<Result644> proposePrice644({
    required String applicationId,
    required double amount,
    required String currency,
  }) async {
    try {
      final res = await _ownerRepository.proposeApplicationPrice(
        applicationId: applicationId,
        amount: amount,
      );
      final view = PriceOffer2211View.tryParse(res['priceOffer2211View']) ??
          PriceOffer2211View(status: 'pending', amount: amount, currency: currency);
      patch644(applicationId, (a) => a.copyWith644(priceOffer: view));
      return const Result644.ok();
    } on ApiException catch (error) {
      final code = apiErrorCode644(error);
      // Limite atteinte ou fonction coupée côté serveur : le lien disparaît.
      if (code == 'OFFER_LIMIT' || code == 'OFFER_DISABLED') {
        patch644(applicationId,
            (a) => a.copyWith644(priceOffer: (a.priceOffer ?? const PriceOffer2211View()).closed()));
      }
      return Result644.fail(code);
    } catch (error) {
      AppLogger.logError('proposePrice644', error: error);
      return const Result644.fail('');
    }
  }

  /// 644 — « Réserver (prénom), payer plus tard » : acceptation SANS intention
  /// de paiement (`payLater: true`). La liste est rechargée : la candidature
  /// revient « acceptée » avec son échéance (`payLater2211View`).
  Future<Result644> reserveLater644(String applicationId) async {
    try {
      await _ownerRepository.respondToApplication(
        applicationId: applicationId,
        action: 'accept',
        payLater: true,
      );
      await loadApplications();
      return const Result644.ok();
    } on ApiException catch (error) {
      final code = apiErrorCode644(error);
      if (code.startsWith('PAY_LATER_')) {
        // Refusé (éteint, service trop proche, déjà libérée une fois) : il ne
        // reste que « Choisir et payer ».
        patch644(applicationId,
            (a) => a.copyWith644(payLater: (a.payLater ?? const PayLater2211View()).closed()));
        return Result644.fail(code);
      }
      final String? known = ratePendingMessage627(error) ??
          alreadyPaidMessage1011(error) ??
          (code == 'DATES_REQUIRED' ? 'dates620_dates_required_error'.tr : null);
      return Result644.fail(code, message: known);
    } catch (error) {
      AppLogger.logError('reserveLater644', error: error);
      return const Result644.fail('');
    }
  }

  Future<bool> respondToApplication({
    required String applicationId,
    required String action, // 'accept' or 'reject'
  }) async {
    final result = await respondToApplicationFull(
      applicationId: applicationId,
      action: action,
    );
    return result != null;
  }

  /// Richer variant used by the one-tap accept-and-pay flow.
  /// Returns the raw backend response on success (so the caller can inspect the
  /// `booking` + `payment` fields to open Stripe PaymentSheet directly) or
  /// null on failure.
  Future<Map<String, dynamic>?> respondToApplicationFull({
    required String applicationId,
    required String action, // 'accept' or 'reject'
  }) async {
    try {
      final response = await _ownerRepository.respondToApplication(
        applicationId: applicationId,
        action: action,
      );

      CustomSnackbar.showSuccess(
        title: 'common_success'.tr,
        message: action == 'accept'
            ? 'application_accept_success'.tr
            : 'application_reject_success'.tr,
      );

      // Refresh the applications list
      await loadApplications();
      return response;
    } on ApiException catch (error) {
      // 620 — 409 DATES_REQUIRED (demande « dates à prévoir ») : message
      // clair, jamais le code brut.
      if (error.statusCode == 409 &&
          (error.message.contains('DATES_REQUIRED') ||
              error.details.toString().contains('DATES_REQUIRED'))) {
        CustomSnackbar.showWarning(
          title: 'dates620_set_dates_banner'.tr,
          message: 'dates620_dates_required_error'.tr,
        );
        return null;
      }
      // 627 — 409 RATE_PENDING (candidature « Tarif à venir ») : la phrase du
      // serveur, en avertissement, puis la liste rechargée (le candidat
      // s'affiche « Tarif à venir », Choisir verrouillé).
      final String? ratePending = ratePendingMessage627(error);
      if (ratePending != null) {
        CustomSnackbar.showWarning(
          title: 'dates620_stale_label'.tr,
          message: ratePending,
        );
        try {
          await loadApplications();
        } catch (_) {}
        return null;
      }
      // 638 — 409 ALREADY_PAID : phrase traduite (le serveur ne parle
      // qu'anglais ici), puis la liste rechargée.
      final String? alreadyPaid = alreadyPaidMessage1011(error);
      if (alreadyPaid != null) {
        CustomSnackbar.showWarning(
          title: 'c1011_already_paid_title'.tr,
          message: alreadyPaid,
        );
        try {
          await loadApplications();
        } catch (_) {}
        return null;
      }
      CustomSnackbar.showError(title: 'common_error'.tr, message: error.message);
      return null;
    } catch (error) {
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'application_action_failed'.tr,
      );
      return null;
    }
  }
}

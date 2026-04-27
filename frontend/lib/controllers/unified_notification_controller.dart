import 'package:get/get.dart';
import 'package:hopetsit/controllers/auth_controller.dart';
import 'package:hopetsit/controllers/bookings_controller.dart';
import 'package:hopetsit/controllers/notifications_controller.dart';
import 'package:hopetsit/controllers/sitter_bookings_controller.dart';
import 'package:hopetsit/controllers/walker_bookings_controller.dart';
import 'package:hopetsit/models/app_notification_model.dart';
import 'package:hopetsit/models/booking_model.dart';

/// v22.5 — PART 1 (Option A) : facade non-breaking au-dessus des controllers
/// existants pour exposer un état notif unifié à TOUTE l'UI.
///
/// PROBLÈME RÉSOLU
/// Avant, 3 endroits de l'UI (cloche AppBar, bandeau home, badge bottom-bar)
/// lisaient leur compteur depuis des sources séparées :
///   * cloche / bottom badge → NotificationsController.unreadCount
///   * bandeau home owner → BookingsController.bookings filtré
///   * bandeau home sitter → SitterBookingsController.bookings filtré
///   * bandeau home walker → WalkerBookingsController.bookings filtré
/// Conséquence : refresh asynchrones, valeurs incohérentes pendant 30s,
/// chaque rôle avec sa propre logique copy-paste.
///
/// CE FACADE
/// Expose 3 streams réactifs unifiés :
///   * [unreadCount]       — compteur de notifs non-lues (cloche + bottom)
///   * [pendingActions]    — actions urgentes pour le rôle actif (bandeau)
///   * [allNotifications]  — liste pour la page Notifications
///
/// AVANTAGE
/// L'UI n'a plus à savoir quel controller observer ni à dupliquer la logique
/// de filtrage par rôle. Migration progressive : les widgets existants
/// continuent de marcher tant qu'ils observent leur controller historique,
/// et on bascule vers ce facade écran par écran.
///
/// Le controller s'auto-rafraîchit :
///   * binding initial à `onInit` (lit l'état courant)
///   * worker `ever` sur les listes sources → recalcule pendingActions
///   * pas besoin de polling : NotificationsController et BookingsController*
///     ont déjà leurs propres mécanismes (socket, periodic, FCM).
class UnifiedNotificationController extends GetxController {
  // ─── État exposé à l'UI ─────────────────────────────────────────────────

  /// Compteur global de notifs non-lues. Source : NotificationsController.
  /// Utilisé par : cloche AppBar, badge bottom-nav.
  final RxInt unreadCount = 0.obs;

  /// Liste d'actions urgentes pour le rôle actif. Recalculée chaque fois
  /// que les bookings changent.
  /// Utilisé par : bandeau HomeQuickActionBar.
  final RxList<PendingAction> pendingActions = <PendingAction>[].obs;

  /// Liste complète de notifications. Source : NotificationsController.
  /// Utilisé par : page Notifications.
  final RxList<AppNotificationModel> allNotifications =
      <AppNotificationModel>[].obs;

  // ─── Workers (cleanup en onClose) ───────────────────────────────────────
  Worker? _unreadWorker;
  Worker? _notifsWorker;
  Worker? _ownerBookingsWorker;
  Worker? _sitterBookingsWorker;
  Worker? _walkerBookingsWorker;
  Worker? _roleWorker;

  @override
  void onInit() {
    super.onInit();
    _bindAll();
  }

  @override
  void onClose() {
    _unreadWorker?.dispose();
    _notifsWorker?.dispose();
    _ownerBookingsWorker?.dispose();
    _sitterBookingsWorker?.dispose();
    _walkerBookingsWorker?.dispose();
    _roleWorker?.dispose();
    super.onClose();
  }

  /// Refresh public si l'UI veut forcer une recalcul (ex: pull-to-refresh).
  /// Ne déclenche PAS de fetch backend — pour ça, on délègue aux controllers
  /// sous-jacents (NotificationsController.refreshAll, BookingsController.
  /// loadBookings, etc.).
  void refresh() {
    _syncUnreadCount();
    _syncAllNotifications();
    _recalcPendingActions();
  }

  // ─── Wiring : bind aux controllers existants ───────────────────────────
  void _bindAll() {
    _bindNotifications();
    _bindBookings();
    _bindRoleChange();
    // Initial sync au cas où les controllers sont déjà peuplés.
    refresh();
  }

  void _bindNotifications() {
    if (!Get.isRegistered<NotificationsController>()) return;
    final ctrl = Get.find<NotificationsController>();
    _unreadWorker = ever<int>(ctrl.unreadCount, (v) {
      unreadCount.value = v;
    });
    _notifsWorker = ever<List<AppNotificationModel>>(ctrl.notifications, (
      list,
    ) {
      allNotifications.assignAll(list);
    });
  }

  void _bindBookings() {
    if (Get.isRegistered<BookingsController>()) {
      final ctrl = Get.find<BookingsController>();
      _ownerBookingsWorker = ever<List<BookingModel>>(ctrl.bookings, (_) {
        _recalcPendingActions();
      });
    }
    if (Get.isRegistered<SitterBookingsController>()) {
      final ctrl = Get.find<SitterBookingsController>();
      _sitterBookingsWorker = ever<List<BookingModel>>(ctrl.bookings, (_) {
        _recalcPendingActions();
      });
    }
    if (Get.isRegistered<WalkerBookingsController>()) {
      final ctrl = Get.find<WalkerBookingsController>();
      _walkerBookingsWorker = ever<List<BookingModel>>(ctrl.bookings, (_) {
        _recalcPendingActions();
      });
    }
  }

  void _bindRoleChange() {
    if (!Get.isRegistered<AuthController>()) return;
    final auth = Get.find<AuthController>();
    _roleWorker = ever<String?>(auth.userRole, (_) {
      _recalcPendingActions();
    });
  }

  // ─── Sync helpers ───────────────────────────────────────────────────────
  void _syncUnreadCount() {
    if (!Get.isRegistered<NotificationsController>()) return;
    unreadCount.value = Get.find<NotificationsController>().unreadCount.value;
  }

  void _syncAllNotifications() {
    if (!Get.isRegistered<NotificationsController>()) return;
    allNotifications.assignAll(
      Get.find<NotificationsController>().notifications,
    );
  }

  void _recalcPendingActions() {
    final role = Get.isRegistered<AuthController>()
        ? Get.find<AuthController>().userRole.value
        : null;
    final List<BookingModel> bookings = _bookingsForRole(role);
    final List<PendingAction> next = [];
    if (role == 'owner') {
      for (final b in bookings) {
        final status = (b.status ?? '').toLowerCase();
        final pay = (b.paymentStatus ?? '').toLowerCase();
        if (pay == 'paid') continue;
        if (status == 'accepted' ||
            status == 'agreed' ||
            status == 'mutually_accepted') {
          next.add(
            PendingAction(
              kind: PendingActionKind.ownerPay,
              booking: b,
              label: 'Payer',
            ),
          );
        }
      }
    } else if (role == 'sitter' || role == 'walker') {
      for (final b in bookings) {
        final status = (b.status ?? '').toLowerCase();
        if (status == 'pending' || status == 'requested') {
          next.add(
            PendingAction(
              kind: PendingActionKind.providerAccept,
              booking: b,
              label: 'Accepter',
            ),
          );
        }
      }
    }
    pendingActions.assignAll(next);
  }

  List<BookingModel> _bookingsForRole(String? role) {
    switch (role) {
      case 'walker':
        return Get.isRegistered<WalkerBookingsController>()
            ? Get.find<WalkerBookingsController>().bookings.toList()
            : <BookingModel>[];
      case 'sitter':
        return Get.isRegistered<SitterBookingsController>()
            ? Get.find<SitterBookingsController>().bookings.toList()
            : <BookingModel>[];
      case 'owner':
      default:
        return Get.isRegistered<BookingsController>()
            ? Get.find<BookingsController>().bookings.toList()
            : <BookingModel>[];
    }
  }
}

/// Dérive l'action urgente côté UI à partir d'un BookingModel.
class PendingAction {
  final PendingActionKind kind;
  final BookingModel booking;
  final String label;
  const PendingAction({
    required this.kind,
    required this.booking,
    required this.label,
  });
}

enum PendingActionKind { ownerPay, providerAccept, providerPaid }

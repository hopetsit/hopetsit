// v21 — Home Quick Action Bar.
//
// A self-contained, reactive notification bar that sits below the AppBar on
// the 3 home screens (owner / sitter / walker). It is INVISIBLE by default
// and only renders when the user has an urgent action to take :
//
//   OWNER  →  ① a sitter/walker just accepted their request → "Pay €X"
//             ② a payment is pending past its deadline → "Pay now" (orange)
//
//   SITTER →  ① a new booking request is waiting → "Accept ✓ / Refuse ✗"
//             ② a payment was just received → "Voir détails"
//
//   WALKER →  same as sitter, with green accent.
//
// The widget reuses the existing `BookingsController` / `SitterBookingsController`
// / `WalkerBookingsController` — it does NOT make its own API calls, just
// observes the existing RxList<BookingModel>. If the controller isn't
// registered yet (rare race), it renders nothing and waits for the next frame.
//
// USAGE (single line) :
//   HomeQuickActionBar(role: 'owner')
//
// Insert directly under the AppBar in each home screen's body, before the
// existing scrollable content. NOTHING else needs to change.

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/applications_controller.dart';
import 'package:hopetsit/controllers/bookings_controller.dart';
import 'package:hopetsit/controllers/friend_controller.dart';
import 'package:hopetsit/controllers/notifications_controller.dart';
import 'package:hopetsit/controllers/sitter_bookings_controller.dart';
import 'package:hopetsit/controllers/walker_bookings_controller.dart';
import 'package:hopetsit/localization/app_translations.dart';
import 'package:hopetsit/models/application_model.dart';
import 'package:hopetsit/models/booking_model.dart';
import 'package:hopetsit/models/friendship_model.dart';
import 'package:hopetsit/repositories/owner_repository.dart';
import 'package:hopetsit/repositories/sitter_repository.dart';
import 'package:hopetsit/repositories/walker_repository.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart' as snack;
import 'package:hopetsit/utils/currency_helper.dart';
import 'package:hopetsit/utils/logger.dart';
import 'package:hopetsit/views/booking/bookings_history_screen.dart';
import 'package:hopetsit/views/friends/friends_screen.dart';
import 'package:hopetsit/views/invoices/invoices_screen.dart';
// v23.1.327 — écrans de chat pour le bouton "Discuter" du sheet Paiement.
import 'package:hopetsit/views/pet_owner/chat/chat_screen.dart';
import 'package:hopetsit/views/pet_owner/chat/individual_chat_screen.dart';
import 'package:hopetsit/views/pet_sitter/chat/sitter_chat_screen.dart';
import 'package:hopetsit/views/pet_sitter/chat/sitter_individual_chat_screen.dart';
import 'package:hopetsit/views/payment/airwallex_payment_screen.dart';
import 'package:hopetsit/views/pet_owner/posts/my_posts_screen.dart';
import 'package:hopetsit/views/wallet/wallet_screen.dart';
import 'package:hopetsit/views/pet_owner/posts/widgets/post_candidates_sheet.dart';
import 'package:hopetsit/views/service_provider/service_provider_detail_screen.dart';
import 'package:hopetsit/views/service_provider/walker_detail_screen.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/service_confirmation_card.dart';
import 'package:hopetsit/widgets/verified_badge.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/utils/storage_keys.dart';
import 'package:hopetsit/data/network/api_client.dart';

class HomeQuickActionBar extends StatefulWidget {
  final String role; // 'owner' | 'sitter' | 'walker'
  const HomeQuickActionBar({super.key, required this.role});

  @override
  State<HomeQuickActionBar> createState() => _HomeQuickActionBarState();
}

class _HomeQuickActionBarState extends State<HomeQuickActionBar>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _pulse;
  // v22.1 — Bug 14a : worker pour réagir aux nouvelles notifs.
  Worker? _notifWorker;
  Timer? _periodicRefresh;
  // v23.1 — bug fix : persisted dismiss list. The X button on the banner
  // adds the booking id here AND to GetStorage so the banner stays hidden
  // across app restarts. Cleared at logout to avoid leaking across accounts
  // (see auth_controller._forceDelete).
  final Set<String> _dismissedIds = <String>{};
  final GetStorage _bannerStorage = GetStorage();
  // v23.1 — debounce double-tap on ✓/✗. Without this, two quick taps
  // both fire respondToBooking → second call hits 'Booking already X'
  // / a 500 (race on save), and the user sees a confusing red toast.
  bool _isResponding = false;

  @override
  void initState() {
    super.initState();
    // v23.1 part 250 — perf : observer lifecycle pour couper le timer de
    // refresh quand l'app passe en background (cf. didChangeAppLifecycleState).
    WidgetsBinding.instance.addObserver(this);
    // v23.1 — hydrate the dismiss set from disk so dismissed banners stay
    // hidden after app restart.
    try {
      final raw = _bannerStorage.read(StorageKeys.dismissedBannerBookings);
      if (raw is List) {
        for (final id in raw) {
          if (id is String && id.isNotEmpty) _dismissedIds.add(id);
        }
      }
    } catch (_) {}

    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);

    // v22.1 — Bug 14a : refresh proactif de la liste de bookings.
    //   1. Force reload AU MOUNT (le user a peut-être manqué des updates
    //      pendant qu'il était sur un autre tab).
    //   2. Écoute le compteur de notifs : si une nouvelle notif arrive
    //      (typiquement "Réservation acceptée"), on relance loadBookings()
    //      → la barre passe de "Tout est à jour" à "Payer X€" en moins de 1s.
    //   3. Backup periodic refresh toutes les 30s pour les sessions très
    //      longues sans push.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // v23.1 part 20 — owner banner needs ApplicationsController. Register it
      // here if the owner just landed on the home screen and no other screen
      // had a chance to put() it yet — otherwise the banner can't show new
      // candidatures before the owner navigates somewhere else.
      if (widget.role == 'owner' &&
          !Get.isRegistered<ApplicationsController>()) {
        try {
          Get.put(ApplicationsController());
        } catch (_) { /* noop */ }
      }
      // v23.1.337 — Daniel : "je veux que la demande d'amis s'affiche dans
      // la bande et qu'on puisse voir le profil de celui qui me demande".
      // On enregistre FriendController ici (s'il ne l'est pas déjà) → son
      // onInit() charge incomingRequests ET attache les listeners socket
      // (friend_request:received) → la bande réagit en temps réel sur les
      // 3 home screens (owner/sitter/walker). Si déjà enregistré, on force
      // un loadRequests() pour rafraîchir au mount.
      try {
        if (!Get.isRegistered<FriendController>()) {
          Get.put(FriendController());
        } else {
          Get.find<FriendController>().loadRequests();
        }
      } catch (_) { /* noop */ }
      // v23.1.348 — Daniel : "la langue doit suivre le système dès
      // l'installation". La bande est montée sur les 3 home screens juste
      // après le login → on synchronise la langue UI (choisie ou héritée du
      // téléphone) vers le backend pour les notifications/emails. Best-effort,
      // 1 fois par session (garde interne).
      LocalizationService.syncToBackend();
      _refreshBookings();
      if (Get.isRegistered<NotificationsController>()) {
        final notifs = Get.find<NotificationsController>();
        _notifWorker = ever<int>(notifs.unreadCount, (_) {
          _refreshBookings();
          // v23.1.338 — une notif (demande d'ami OU invitation famille) arrive
          // → on rafraîchit aussi le social pour que la bande la surface en
          // temps réel. (le friend_request socket couvre déjà les demandes,
          // mais les invitations famille n'ont pas de listener dédié.)
          _refreshSocial();
        });
      }
      _startPeriodicRefresh();
    });
  }

  // v23.1 part 250 — perf : le timer de refresh 30s tournait meme quand
  // l'app etait en background (le widget reste monte dans l'IndexedStack
  // du nav bottom). 3 appels reseau toutes les 30s pour rien → reveils
  // CPU + radio + batterie sur low-end. On le coupe en background et on
  // le relance au resume (meme pattern que paw_map_screen v243 round 3).
  void _startPeriodicRefresh() {
    _periodicRefresh?.cancel();
    _periodicRefresh = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _refreshBookings();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (!mounted) return;
    if (state == AppLifecycleState.resumed) {
      // Refresh immediat au retour + relance le timer.
      _refreshBookings();
      _startPeriodicRefresh();
    } else {
      // paused / inactive / detached / hidden → coupe le timer.
      _periodicRefresh?.cancel();
      _periodicRefresh = null;
    }
  }

  void _refreshBookings() {
    try {
      switch (widget.role) {
        case 'walker':
          if (Get.isRegistered<WalkerBookingsController>()) {
            Get.find<WalkerBookingsController>().loadBookings();
          }
          break;
        case 'sitter':
          if (Get.isRegistered<SitterBookingsController>()) {
            Get.find<SitterBookingsController>().loadBookings();
          }
          break;
        case 'owner':
        default:
          if (Get.isRegistered<BookingsController>()) {
            Get.find<BookingsController>().loadBookings();
          }
          // v23.1 part 20 — owner banner reads candidates too. When a walker
          // (or sitter) submits an application, only the ApplicationsController
          // is updated by the backend ; the BookingsController stays empty
          // until the owner accepts. Without refreshing here the banner
          // stayed on "Tout est à jour" forever — bug Daniel reported.
          if (Get.isRegistered<ApplicationsController>()) {
            Get.find<ApplicationsController>().loadApplications();
          }
      }
    } catch (_) { /* noop */ }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulse.dispose();
    _notifWorker?.dispose();
    _periodicRefresh?.cancel();
    super.dispose();
  }

  // ─── Helpers ────────────────────────────────────────────────────────────

  /// Read the right Rx list of bookings depending on the user role.
  /// Returns null if the controller isn't registered yet (the bar simply
  /// hides until the controller boots).
  RxList<BookingModel>? _bookingsRxForRole() {
    switch (widget.role) {
      case 'walker':
        return Get.isRegistered<WalkerBookingsController>()
            ? Get.find<WalkerBookingsController>().bookings
            : null;
      case 'sitter':
        return Get.isRegistered<SitterBookingsController>()
            ? Get.find<SitterBookingsController>().bookings
            : null;
      case 'owner':
      default:
        return Get.isRegistered<BookingsController>()
            ? Get.find<BookingsController>().bookings
            : null;
    }
  }

  /// Pick the most-urgent action across the booking list, or null when
  /// nothing actionable shows up.
  _QuickAction? _pickAction(List<BookingModel> bookings) {
    if (bookings.isEmpty) return null;

    // Priority 1 — pending payment for OWNER.
    if (widget.role == 'owner') {
      // v22.2 — Bug 16c : aggregate les bookings à payer pour afficher leur
      // count quand y en a plus de 1.
      // v23.1 part 65 — Bug 1 : exclude bookings whose service date is
      // already past (>3 days). Without this guard, owner reconnecting
      // weeks later sees stale "X a accepté" banners for bookings the
      // service date already lapsed — Daniel reported "anciens paiements
      // ressortent à reconnexion". We give a small 3-day grace window so
      // a same-day booking that just lapsed still shows briefly.
      final nowDateMs = DateTime.now().millisecondsSinceEpoch;
      const grace3DaysMs = 3 * 24 * 60 * 60 * 1000;
      final acceptedToPay = bookings.where((b) {
        final status = b.status.toLowerCase();
        final pay    = (b.paymentStatus ?? '').toLowerCase();
        if (pay == 'paid') return false;
        if (_dismissedIds.contains(b.id)) return false;
        // Exclude cancelled / refunded / completed bookings.
        if (status == 'cancelled' || status == 'refunded' ||
            status == 'completed' || status == 'rejected' ||
            status == 'expired') {
          return false;
        }
        // Exclude stale bookings — service date already > 3 days past.
        final serviceMs = DateTime.tryParse(b.date)?.millisecondsSinceEpoch;
        if (serviceMs != null && (nowDateMs - serviceMs) > grace3DaysMs) {
          return false;
        }
        return status == 'accepted' || status == 'agreed' || status == 'mutually_accepted';
      }).toList();

      if (acceptedToPay.isNotEmpty) {
        // v22.2 — Bug 16b : fallback "Le prestataire" si sitter.name vide
        // (cas où l'API ne populate pas le champ sitter/walker correctement).
        final b = acceptedToPay.first;
        // v23.1.346 — audit traductions : ces labels étaient codés en dur en
        // FRANÇAIS (affichés tels quels en UI es/de/it/pt/en) → clés 6 langues.
        final providerName = b.sitter.name.trim().isNotEmpty
            ? b.sitter.name
            : 'band_provider_fallback'.tr;
        final isWalker = (b.serviceType ?? '').toLowerCase().contains('walking');
        final extraCount = acceptedToPay.length - 1;
        final title = extraCount > 0
            ? 'band_owner_pay_title_extra'.trParams({
                'name': providerName,
                'count': extraCount.toString(),
              })
            : 'band_owner_pay_title'.trParams({'name': providerName});
        // Total agrégé si plusieurs bookings.
        double totalToPay = 0;
        String? aggCurrency;
        for (final bk in acceptedToPay) {
          final amt = (bk.pricing?.totalPrice ?? bk.totalAmount ?? 0).toDouble();
          totalToPay += amt;
          aggCurrency ??= bk.pricing?.currency ?? bk.sitter.currency;
        }
        final ctaLabel = extraCount > 0
            ? 'band_cta_pay_all'.trParams({
                'amount': CurrencyHelper.format(aggCurrency ?? 'EUR', totalToPay),
              })
            : 'band_cta_pay'.trParams({
                'amount': CurrencyHelper.format(
                  b.pricing?.currency ?? b.sitter.currency,
                  (b.pricing?.totalPrice ?? b.totalAmount ?? 0).toDouble(),
                ),
              });
        return _QuickAction(
          kind: _Kind.ownerPay,
          color: isWalker ? const Color(0xFF16A34A) : const Color(0xFF2563EB),
          icon: Icons.celebration_rounded,
          title: title,
          subtitle: '${_serviceLabel(b.serviceType)} ${b.petName} — '
              '${_dateLabel(b)}',
          ctaLabel: ctaLabel,
          booking: b,
          pulse: false,
          allBookingIds: acceptedToPay.map((bk) => bk.id).toList(),
        );
      }
      // v23.1.341 — Daniel : "la fin du service passe par le bandeau, plus
      // simple". Le prestataire a marqué "J'ai rendu l'animal" → l'owner doit
      // confirmer (c'est CE clic qui libère le paiement). Priorité haute :
      // juste après le paiement dû, avant les bannières d'information.
      for (final b in bookings) {
        if ((b.paymentStatus ?? '').toLowerCase() != 'paid') continue;
        if (b.confirmationStatus != 'awaiting_confirmation') continue;
        // v448 — AUDIT : anti-zombie. (1) Une résa annulée/remboursée ne doit
        // jamais demander « Confirme la fin ». (2) Borne d'ancienneté : si la
        // date de service est passée de plus de 30 jours, on n'affiche plus la
        // bannière (vieux profil/test bloqué en awaiting_confirmation qui
        // ressortait à CHAQUE reconnexion, et non masquable).
        final st = b.status.toLowerCase();
        if (st == 'cancelled' ||
            st == 'refunded' ||
            st == 'rejected' ||
            st == 'expired') {
          continue;
        }
        final svcMs = DateTime.tryParse(b.date)?.millisecondsSinceEpoch;
        if (svcMs != null &&
            (DateTime.now().millisecondsSinceEpoch - svcMs) >
                30 * 24 * 60 * 60 * 1000) {
          continue;
        }
        final providerName = b.sitter.name.trim().isNotEmpty
            ? b.sitter.name
            : 'role_sitter'.tr;
        return _QuickAction(
          kind: _Kind.serviceAction,
          color: const Color(0xFFEF4324), // orange owner
          icon: Icons.task_alt_rounded,
          title: 'band_owner_confirm_title'.tr,
          subtitle:
              'band_owner_confirm_subtitle'.trParams({'name': providerName}),
          ctaLabel: 'band_cta_confirm'.tr,
          booking: b,
          pulse: true,
        );
      }
      // v23.1 part 49 — owner-side "Paiement effectué" banner.
      // v23.1 part 65 — Bug 2 : aggregate ALL recently-paid bookings into
      // allBookingIds so a single tap on X dismisses every paid banner at
      // once instead of needing 1 tap per booking (Daniel : "je dois
      // appuyer 4 fois sur fermer avant que le bandeau ce ferme"). Also
      // applies to the provider-side "Paiement reçu" branch below.
      final ownerNowMs = DateTime.now().millisecondsSinceEpoch;
      const ownerMaxAgeMs = 24 * 60 * 60 * 1000; // 24h
      final ownerPaidRecent = bookings.where((b) {
        final pay = (b.paymentStatus ?? '').toLowerCase();
        final st  = b.status.toLowerCase();
        if (_dismissedIds.contains(b.id)) return false;
        if (pay != 'paid' || st == 'completed') return false;
        final paidAtMs =
            DateTime.tryParse(b.paidAt ?? '')?.millisecondsSinceEpoch ??
            DateTime.tryParse(b.updatedAt)?.millisecondsSinceEpoch;
        if (paidAtMs == null) return false;
        return (ownerNowMs - paidAtMs) <= ownerMaxAgeMs;
      }).toList();

      if (ownerPaidRecent.isNotEmpty) {
        final b = ownerPaidRecent.first;
        // v23.1.346 — audit traductions : labels FR codés en dur → clés 6 langues
        // (réutilise payment_made_banner_title déjà existante pour le singulier).
        final providerName = b.sitter.name.trim().isNotEmpty
            ? b.sitter.name
            : 'band_provider_fallback'.tr;
        final extra = ownerPaidRecent.length - 1;
        final title = extra > 0
            ? 'band_payment_made_title_extra'.trParams({'count': extra.toString()})
            : 'payment_made_banner_title'.tr;
        return _QuickAction(
          kind: _Kind.providerPaid,
          color: const Color(0xFF16A34A), // green = success
          icon: Icons.verified_rounded,
          title: title,
          subtitle: '${CurrencyHelper.format(
                b.pricing?.currency ?? 'EUR',
                (b.pricing?.totalPrice ?? b.totalAmount ?? 0).toDouble(),
              )} → $providerName • ${_dateLabel(b)}',
          ctaLabel: 'view_details_cta'.tr,
          booking: b,
          pulse: false,
          allBookingIds: ownerPaidRecent.map((bk) => bk.id).toList(),
        );
      }
      // Lower priority — payment pending warning (orange).
      // (We don't model a deadline here, so just look for status=pending_payment.)
      for (final b in bookings) {
        final pay = (b.paymentStatus ?? '').toLowerCase();
        if (pay == 'pending_payment' || pay == 'requires_payment') {
          return _QuickAction(
            kind: _Kind.ownerPay,
            color: const Color(0xFFFF9800),
            icon: Icons.timer_rounded,
            // v23.1.346 — audit traductions : FR codé en dur → clés 6 langues.
            title: 'band_payment_pending_title'.tr,
            subtitle: 'band_payment_pending_subtitle'.tr,
            ctaLabel: 'band_cta_pay_now'.tr,
            booking: b,
            pulse: true,
          );
        }
      }
      return null;
    }

    // Priority 1 — a new booking request awaiting accept/refuse.
    for (final b in bookings) {
      final status = b.status.toLowerCase();
      if (status == 'pending' || status == 'requested') {
        final isWalker = widget.role == 'walker';
        final estimated = (b.pricing?.netAmount ?? b.pricing?.basePrice ?? 0).toDouble();
        final ownerName = b.owner.name.isNotEmpty ? b.owner.name : '—';
        return _QuickAction(
          kind: _Kind.providerAccept,
          color: isWalker ? const Color(0xFF16A34A) : const Color(0xFF2563EB),
          icon: Icons.notifications_active_rounded,
          // v23.1.346 — audit traductions : FR codé en dur → clés 6 langues.
          title: 'band_new_request_title'.tr,
          subtitle: 'band_new_request_subtitle'.trParams({
            'owner': ownerName,
            'pet': b.petName,
            'date': _dateLabel(b),
            'amount': CurrencyHelper.format(
              b.pricing?.currency ?? 'EUR',
              estimated,
            ),
          }),
          ctaLabel: '',
          booking: b,
          pulse: true,
        );
      }
    }

    // v23.1.341 — Daniel : "le début et la fin de service passent par le
    // bandeau, plus simple". Côté prestataire (sitter/walker) :
    //   a) C'EST L'HEURE : réservation payée, pas encore démarrée, heure de
    //      début atteinte → "Confirme le début du service" (🐾).
    //   b) SERVICE EN COURS : démarré → "Confirme la fin du service" (✅).
    // Tap → sheet avec la ServiceConfirmationCard (mêmes boutons que l'écran
    // Réservations). Priorité : après une nouvelle demande, avant les infos.
    {
      final svcNow = DateTime.now();
      const svcMaxAgeMs = 7 * 24 * 60 * 60 * 1000; // anti-stale 7 jours
      final isWalkerRole = widget.role == 'walker';
      final svcAccent =
          isWalkerRole ? const Color(0xFF16A34A) : const Color(0xFF2563EB);
      // a) début dû.
      for (final b in bookings) {
        if ((b.paymentStatus ?? '').toLowerCase() != 'paid') continue;
        if (b.confirmationStatus != 'awaiting_start') continue;
        final startAt = _serviceStartAt(b);
        if (startAt == null || startAt.isAfter(svcNow)) continue;
        if (svcNow.difference(startAt).inMilliseconds > svcMaxAgeMs) continue;
        return _QuickAction(
          kind: _Kind.serviceAction,
          color: svcAccent,
          icon: Icons.pets_rounded,
          title: 'band_service_start_title'.tr,
          subtitle: 'band_service_start_subtitle'
              .trParams({'pet': b.petName.isNotEmpty ? b.petName : '—'}),
          ctaLabel: 'band_cta_start'.tr,
          booking: b,
          pulse: true,
        );
      }
      // b) fin à confirmer (service démarré).
      // v23.1.354 — Daniel : "la 2e confirmation ne sort pas de suite après
      // la 1re mais 5 min avant la fin du service". On masque l'action tant
      // que la fin (heure de fin du timeSlot / duration) est à plus de 5 min.
      // Fin indéterminable (données legacy) → comportement d'avant (affichée).
      // Le backend envoie la notif push+mail 'service_end_soon' au même moment.
      for (final b in bookings) {
        if ((b.paymentStatus ?? '').toLowerCase() != 'paid') continue;
        if (b.confirmationStatus != 'in_progress') continue;
        final endAt = _serviceEndAt(b);
        // v23.1.357 — Daniel : 5 min avant la fin (et plus 30).
        if (endAt != null && endAt.difference(svcNow).inMinutes > 5) continue;
        // v448 — AUDIT : anti-zombie. La branche start a sa borne svcMaxAgeMs
        // (7 j) mais PAS celle-ci → un booking bloqué en in_progress (sans
        // heure de fin) affichait « Confirme la fin » indéfiniment. On borne
        // sur la fin (ou le début à défaut) : > 7 jours passé = on n'affiche plus.
        final endRef = endAt ?? _serviceStartAt(b);
        if (endRef != null &&
            svcNow.difference(endRef).inMilliseconds > svcMaxAgeMs) {
          continue;
        }
        return _QuickAction(
          kind: _Kind.serviceAction,
          color: svcAccent,
          icon: Icons.flag_circle_rounded,
          title: 'band_service_end_title'.tr,
          subtitle: 'band_service_end_subtitle'
              .trParams({'pet': b.petName.isNotEmpty ? b.petName : '—'}),
          ctaLabel: 'band_cta_end'.tr,
          booking: b,
          pulse: false,
        );
      }
    }

    // v23.1.349 — Daniel : "service fini → notification bandeau paiement reçu
    // pour sitter/walker". L'owner a confirmé la fin du service → l'argent
    // vient d'être DÉBLOQUÉ dans le wallet. Fenêtre 24h sur updatedAt (bump à
    // la confirmation), dismissible via X, tap → WalletScreen.
    {
      final relNowMs = DateTime.now().millisecondsSinceEpoch;
      const relMaxAgeMs = 24 * 60 * 60 * 1000;
      final released = bookings.where((b) {
        if (_dismissedIds.contains('rel_${b.id}')) return false;
        if ((b.paymentStatus ?? '').toLowerCase() != 'paid') return false;
        if (b.confirmationStatus != 'confirmed') return false;
        final updMs = DateTime.tryParse(b.updatedAt)?.millisecondsSinceEpoch;
        if (updMs == null) return false;
        return (relNowMs - updMs) <= relMaxAgeMs;
      }).toList();
      if (released.isNotEmpty) {
        final b = released.first;
        final isWalkerRole = widget.role == 'walker';
        double total = 0;
        String? cur;
        for (final bk in released) {
          total += (bk.pricing?.netAmount ??
                  bk.pricing?.totalPrice ??
                  bk.totalAmount ??
                  0)
              .toDouble();
          cur ??= bk.pricing?.currency ?? 'EUR';
        }
        return _QuickAction(
          kind: _Kind.providerReleased,
          color: isWalkerRole ? const Color(0xFF16A34A) : const Color(0xFF2563EB),
          icon: Icons.account_balance_wallet_rounded,
          title: 'band_payment_released_title'.tr,
          subtitle: 'band_payment_released_subtitle'.trParams({
            'amount': CurrencyHelper.format(cur ?? 'EUR', total),
          }),
          ctaLabel: 'band_cta_wallet'.tr,
          booking: b,
          pulse: true,
          allBookingIds: released.map((bk) => 'rel_${bk.id}').toList(),
        );
      }
    }

    // Priority 2 — payment received → confirmation banner.
    //
    // v23.1 part 44/49 — uses `paidAt` (canonical payment timestamp) NOT
    // `updatedAt` (which bumps on every booking mutation). 24h window so
    // the user has the whole day to see the confirmation if they were
    // away when the payment landed. Auto-dismissed after first display
    // via the X button, OR auto-hidden once status flips to 'completed'.
    // v23.1 part 65 — Bug 2/5 : aggregate all recently-paid bookings into
    // allBookingIds so a single X tap dismisses every paid banner at
    // once. Same pattern as the owner side.
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    const maxBannerAgeMs = 24 * 60 * 60 * 1000; // 24h
    final providerPaidRecent = bookings.where((b) {
      final pay = (b.paymentStatus ?? '').toLowerCase();
      final st  = b.status.toLowerCase();
      if (_dismissedIds.contains(b.id)) return false;
      if (pay != 'paid' || st == 'completed') return false;
      final paidAtMs =
          DateTime.tryParse(b.paidAt ?? '')?.millisecondsSinceEpoch ??
          DateTime.tryParse(b.updatedAt)?.millisecondsSinceEpoch;
      if (paidAtMs == null) return false;
      return (nowMs - paidAtMs) <= maxBannerAgeMs;
    }).toList();

    if (providerPaidRecent.isNotEmpty) {
      final b = providerPaidRecent.first;
      final isWalker = widget.role == 'walker';
      final ownerName = b.owner.name.isNotEmpty ? b.owner.name : '—';
      final extra = providerPaidRecent.length - 1;
      // v23.1.162 — Daniel : banner toast en FR sur UI espagnole.
      final title = extra > 0
          ? 'payment_received_banner_title_extra'
              .trParams({'count': extra.toString()})
          : 'payment_received_banner_title'.tr;
      return _QuickAction(
        kind: _Kind.providerPaid,
        color: isWalker ? const Color(0xFF16A34A) : const Color(0xFF2563EB),
        icon: Icons.check_circle_rounded,
        title: title,
        // v23.1.162 — subtitle hardcoded FR avant ('$ownerName a payé X').
        // Templated avec @name + @amount maintenant.
        subtitle: 'payment_received_subtitle'.trParams({
          'name': ownerName,
          'amount':
            '${CurrencyHelper.format(
              b.pricing?.currency ?? 'EUR',
              (b.pricing?.totalPrice ?? b.totalAmount ?? 0).toDouble(),
            )} • ${_dateLabel(b)}',
        }),
        ctaLabel: 'view_details_cta'.tr,
        booking: b,
        pulse: false,
        allBookingIds: providerPaidRecent.map((bk) => bk.id).toList(),
      );
    }
    return null;
  }

  String _serviceLabel(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    final s = raw.toLowerCase();
    if (s.contains('walking')) return 'Promenade';
    if (s.contains('day_care')) return 'Garderie';
    if (s.contains('boarding') || s.contains('overnight')) return 'Garde nuit';
    if (s.contains('sitting')) return 'Pet-sitting';
    return raw.replaceAll('_', ' ');
  }

  String _dateLabel(BookingModel b) {
    final d = b.date;
    if (d.isEmpty) return '';
    return d.split('T').first;
  }

  // ─── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final rx = _bookingsRxForRole();

    return Obx(() {
      // v23.1 part 20 — owner banner now also reacts to ApplicationsController.
      // The walker/sitter sends an Application (NOT a Booking) when they tap
      // "Demander" on a publication. The Booking only exists *after* the owner
      // accepts. So if we only watch BookingsController for owner, the banner
      // stays on "Tout est à jour" — bug Daniel reported.
      // v23.1.337 — rx peut être null si le BookingsController du rôle n'est
      // pas encore registered : dans ce cas on saute directement au fallback
      // demande d'ami / neutre (avant on retournait un _NeutralBar fixe, ce
      // qui empêchait la demande d'ami de s'afficher).
      _QuickAction? action = rx != null ? _pickAction(rx.toList()) : null;
      if (action == null && widget.role == 'owner') {
        action = _pickOwnerApplicationAction();
      }
      // v23.1.337 — Daniel : la demande d'amis doit apparaître dans LA BANDE
      // (pas seulement la cloche). On la surface dès qu'aucune action booking/
      // candidature plus urgente n'est en attente. Tap → sheet avec le profil
      // du demandeur (avatar/nom/rôle/ville) + Accepter / Refuser. Le widget
      // est partagé → couvre owner + sitter + walker, et tout rôle de demandeur.
      action ??= _pickFriendRequestAction();
      // v23.1.338 — Daniel : "et famille aussi". Invitation PawFollow Famille
      // dans la bande (violet), même logique que la demande d'ami : tap →
      // sheet profil du titulaire + Accepter / Refuser.
      action ??= _pickFamilyInvitationAction();
      // Neutral fallback : rien d'urgent → barre soft "tout est à jour".
      if (action == null) {
        return _NeutralBar(role: widget.role, onTap: _onNeutralTap);
      }
      return _ActionBanner(
        action: action,
        pulse: _pulse,
        onTap: () => _onActionTap(action!),
        onAccept: () => _onAccept(action!),
        onRefuse: () => _onRefuse(action!),
        // v23.1 — PART 2 : X dismiss callback. Owner-pay AND provider-paid
        // banners (sitter/walker side after payment received).
        onDismiss: (action.kind == _Kind.ownerPay ||
                action.kind == _Kind.providerPaid ||
                action.kind == _Kind.providerReleased)
            ? () => _dismissBannerMulti(
                  action!.allBookingIds.isNotEmpty
                      ? action.allBookingIds
                      : <String>[action.booking.id],
                )
            : null,
      );
    });
  }

  /// v23.1 part 20 — owner-only : read pending applications and surface a
  /// banner when at least one candidate is waiting for a response. Aggregates
  /// across multiple posts ("+N autres"). Returns null when none.
  _QuickAction? _pickOwnerApplicationAction() {
    if (!Get.isRegistered<ApplicationsController>()) return null;
    final list = Get.find<ApplicationsController>().applications.toList();
    if (list.isEmpty) return null;
    final pending = list
        .where((a) =>
            (a.status).toLowerCase() == 'pending' &&
            !_dismissedIds.contains(a.id))
        .toList();
    if (pending.isEmpty) return null;
    final first = pending.first;
    final extra = pending.length - 1;
    final providerName = first.sitter.name.trim().isNotEmpty
        ? first.sitter.name
        : (first.providerRole == 'walker'
            ? 'role_walker'.tr
            : 'role_sitter'.tr);
    final isWalker = first.providerRole == 'walker';
    final color = isWalker
        ? const Color(0xFF16A34A)
        : const Color(0xFF2563EB);
    final title = extra > 0
        ? '${'notif_title_new_application'.tr} (+$extra)'
        : '${'notif_title_new_application'.tr} — $providerName';
    final petLbl = first.petName.isNotEmpty ? first.petName : '';
    final dateLbl = (first.serviceDate ?? '').split('T').first;
    final subtitle = [petLbl, dateLbl, providerName]
        .where((s) => s.isNotEmpty)
        .join(' • ');
    return _QuickAction(
      kind: _Kind.ownerCandidate,
      color: color,
      icon: Icons.notifications_active_rounded,
      title: title,
      subtitle: subtitle,
      ctaLabel: 'bookings_action_view_details'.tr,
      // We reuse the booking field with a synthetic placeholder ; the tap
      // handler routes to MyPostsScreen and never reads booking-only fields.
      booking: _ownerCandidateStubBooking(first),
      pulse: true,
      candidateApplicationId: first.id,
      allCandidateApplicationIds:
          pending.map((a) => a.id).toList(growable: false),
    );
  }

  /// Build a minimal placeholder BookingModel from an Application so we can
  /// keep _QuickAction's required `booking` field non-null without breaking
  /// the existing render paths (which never run for ownerCandidate kind).
  BookingModel _ownerCandidateStubBooking(ApplicationModel a) {
    return BookingModel.fromJson(<String, dynamic>{
      'id': a.id,
      'status': a.status,
      'paymentStatus': '',
      'serviceType': '',
      'petName': a.petName,
      'date': a.serviceDate ?? '',
      'timeSlot': a.timeSlot,
      'totalAmount': 0,
      'owner': <String, dynamic>{},
      'sitter': <String, dynamic>{},
    });
  }

  /// v23.1.337 — Daniel : "la demande d'amis avec vue profil sur la bande ne
  /// fonctionne pas". On lit la 1re demande d'ami PENDING reçue (FriendController.
  /// incomingRequests, déjà rempli + temps réel via socket) et on en fait une
  /// action de bande. Couvre les 3 rôles de demandeur (owner/sitter/walker) et
  /// s'affiche sur les 3 home screens (le widget est partagé). Retourne null
  /// si FriendController absent ou aucune demande valide.
  _QuickAction? _pickFriendRequestAction() {
    if (!Get.isRegistered<FriendController>()) return null;
    final fc = Get.find<FriendController>();
    final reqs = fc.incomingRequests; // lecture réactive → Obx rebuild
    if (reqs.isEmpty) return null;
    Friendship? pick;
    for (final f in reqs) {
      if (f.status == 'pending' && (f.other?.id ?? '').isNotEmpty) {
        pick = f;
        break;
      }
    }
    if (pick == null) return null;
    final other = pick.other!;
    final role = other.roleLowercase; // 'owner' | 'sitter' | 'walker'
    final name = other.name.trim().isNotEmpty
        ? other.name
        : _friendRoleLabel(role);
    return _QuickAction(
      kind: _Kind.friendRequest,
      // Couleur par rôle du DEMANDEUR (owner orange · sitter bleu · walker
      // vert) — cohérent avec le code couleur de l'app.
      color: _friendRoleAccent(role),
      icon: Icons.person_add_alt_1_rounded,
      title: 'friend_request_banner_title'.tr,
      subtitle: 'friend_request_banner_subtitle'.trParams({'name': name}),
      ctaLabel: 'friend_request_view_profile'.tr,
      // booking obligatoire non-null : stub jamais lu pour ce kind.
      booking: _friendStubBooking(pick),
      pulse: true,
      friendship: pick,
    );
  }

  Color _friendRoleAccent(String role) {
    switch (role) {
      case 'walker':
        return const Color(0xFF16A34A);
      case 'sitter':
        return const Color(0xFF2563EB);
      case 'owner':
      default:
        return const Color(0xFFEF4324);
    }
  }

  String _friendRoleLabel(String role) {
    switch (role) {
      case 'walker':
        return 'role_walker'.tr;
      case 'sitter':
        return 'role_sitter'.tr;
      case 'owner':
      default:
        return 'role_pet_owner'.tr;
    }
  }

  /// Placeholder BookingModel pour garder _QuickAction.booking non-null sur le
  /// kind friendRequest (les chemins de rendu booking ne tournent jamais ici).
  BookingModel _friendStubBooking(Friendship f) {
    return BookingModel.fromJson(<String, dynamic>{
      'id': f.id,
      'status': 'pending',
      'paymentStatus': '',
      'serviceType': '',
      'petName': '',
      'date': '',
      'timeSlot': '',
      'totalAmount': 0,
      'owner': <String, dynamic>{},
      'sitter': <String, dynamic>{},
    });
  }

  /// v23.1.338 — Daniel : "et famille aussi". 1re invitation Famille PawFollow
  /// PENDING reçue (FriendController.incomingFamilyInvitations) → action de
  /// bande violette. Tap → sheet profil du titulaire + Accepter / Refuser.
  _QuickAction? _pickFamilyInvitationAction() {
    if (!Get.isRegistered<FriendController>()) return null;
    final fc = Get.find<FriendController>();
    final invs = fc.incomingFamilyInvitations; // lecture réactive → Obx rebuild
    if (invs.isEmpty) return null;
    Map<String, dynamic>? pick;
    for (final i in invs) {
      final id = (i['invitationId'] ?? i['id'] ?? '').toString();
      if (id.isNotEmpty) {
        pick = i;
        break;
      }
    }
    if (pick == null) return null;
    final role = (pick['familyOwnerRole'] ?? 'owner').toString().toLowerCase();
    final name = (pick['familyOwnerName'] ?? '').toString().trim();
    final displayName = name.isNotEmpty ? name : _friendRoleLabel(role);
    return _QuickAction(
      kind: _Kind.familyInvitation,
      color: const Color(0xFF8B5CF6), // violet Famille PawFollow
      icon: Icons.diversity_3_rounded,
      title: 'family_invitation_received_title'.tr,
      subtitle:
          'family_invitation_banner_subtitle'.trParams({'name': displayName}),
      ctaLabel: 'friend_request_view_profile'.tr,
      booking: _familyStubBooking(pick),
      pulse: true,
      familyInvitation: pick,
    );
  }

  BookingModel _familyStubBooking(Map<String, dynamic> i) {
    return BookingModel.fromJson(<String, dynamic>{
      'id': (i['invitationId'] ?? i['id'] ?? '').toString(),
      'status': 'pending',
      'paymentStatus': '',
      'serviceType': '',
      'petName': '',
      'date': '',
      'timeSlot': '',
      'totalAmount': 0,
      'owner': <String, dynamic>{},
      'sitter': <String, dynamic>{},
    });
  }

  /// v23.1.338 — rafraîchit les demandes d'amis + invitations famille (appelé
  /// quand une notif arrive → la bande surface l'item en temps réel).
  void _refreshSocial() {
    try {
      if (Get.isRegistered<FriendController>()) {
        final fc = Get.find<FriendController>();
        fc.loadRequests();
        fc.loadFamilyInvitations();
      }
    } catch (_) { /* noop */ }
  }

  void _onNeutralTap() {
    // En l'absence d'action urgente, on emmène vers l'historique des bookings
    // (l'écran le plus utile pour comprendre l'état général).
    Get.to(() => const BookingsHistoryScreen());
  }

  // ─── Tap handlers (graceful degradation if a route is missing) ─────────

  void _onActionTap(_QuickAction a) {
    // v22.5 — PART 3 : owner pay banner court-circuite la chaîne
    //   Banner → BookingsHistory → BookingDetail → BookingAgreement → Payment
    // pour aller DIRECT à AirwallexPaymentScreen.
    if (a.kind == _Kind.ownerPay) {
      _navigateOwnerPay(a);
      return;
    }
    // v23.1 — B1+B3 : when sitter/walker taps the "Nouvelle demande" banner,
    // open a rich bottom sheet with owner profile + animal + lieu + date +
    // heure + service type, plus inline accept/refuse buttons. Avoids the
    // detour through BookingsHistoryScreen which lacked these details.
    if (a.kind == _Kind.providerAccept) {
      _showProviderRequestSheet(a);
      return;
    }
    // v23.1 part 21 — owner candidature : sheet riche avec 3 actions
    // (Accept / Reject / Voir profil). Si plusieurs candidats sur le même
    // post, on bascule vers PostCandidatesSheet (vue multi-candidats).
    if (a.kind == _Kind.ownerCandidate) {
      _showOwnerCandidateSheet(a);
      return;
    }
    // v23.1 part 34 — fix Daniel : "Voir détails Payer" sur banner walker/sitter
    // après que owner a payé → renvoyait vers ANCIENNE page BookingsHistoryScreen.
    // Maintenant : sheet riche avec détails du paiement + nav vers Factures.
    if (a.kind == _Kind.providerPaid) {
      _showProviderPaidSheet(a);
      return;
    }
    // v23.1.337 — demande d'ami : sheet avec le profil du demandeur
    // (avatar / nom / rôle / ville) + Accepter / Refuser + (pour un
    // prestataire) bouton "Voir le profil complet".
    if (a.kind == _Kind.friendRequest) {
      _showFriendRequestSheet(a);
      return;
    }
    // v23.1.338 — invitation famille : sheet profil titulaire + Accepter/Refuser.
    if (a.kind == _Kind.familyInvitation) {
      _showFamilyInvitationSheet(a);
      return;
    }
    // v23.1.341 — début / fin de service via le bandeau : sheet avec la
    // ServiceConfirmationCard (mêmes boutons que l'écran Réservations).
    if (a.kind == _Kind.serviceAction) {
      _showServiceActionSheet(a);
      return;
    }
    // v23.1.349 — paiement débloqué (service confirmé) → ouvre le wallet.
    if (a.kind == _Kind.providerReleased) {
      Get.to(() => const WalletScreen());
      return;
    }
    Get.to(() => const BookingsHistoryScreen());
  }

  /// v23.1.341 — heure de début du service côté app (miroir de
  /// resolveBookingStartDate backend) : date + heure du timeSlot si la date
  /// ne porte pas déjà l'heure ; sinon début de journée.
  DateTime? _serviceStartAt(BookingModel b) {
    final raw = b.date;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return null;
    final hasTimePart = RegExp(r'T\d{2}:').hasMatch(raw);
    if (hasTimePart) return parsed;
    final m = RegExp(r'(\d{1,2})[:hH](\d{2})').firstMatch(b.timeSlot);
    if (m != null) {
      return DateTime(parsed.year, parsed.month, parsed.day,
          int.parse(m.group(1)!), int.parse(m.group(2)!));
    }
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  /// v23.1.354 — heure de FIN du service (miroir de resolveBookingEndDate
  /// backend) : 2e heure du timeSlot ("10:00 - 12:00" → 12:00, créneau de
  /// nuit → lendemain) → sinon duration (minutes) → sinon null (le bandeau
  /// affiche alors l'action sans gate, comme avant).
  DateTime? _serviceEndAt(BookingModel b) {
    final startAt = _serviceStartAt(b);
    if (startAt == null) return null;
    final matches =
        RegExp(r'(\d{1,2})[:hH](\d{2})').allMatches(b.timeSlot).toList();
    if (matches.length >= 2) {
      final last = matches.last;
      final h = int.parse(last.group(1)!);
      final min = int.parse(last.group(2)!);
      if (h <= 23 && min <= 59) {
        var end = DateTime(startAt.year, startAt.month, startAt.day, h, min);
        if (!end.isAfter(startAt)) end = end.add(const Duration(days: 1));
        return end;
      }
    }
    final dur = b.duration;
    if (dur != null && dur > 0) return startAt.add(Duration(minutes: dur));
    return null;
  }

  /// v23.1.341 — sheet "Début / fin de service" du bandeau. Embarque la
  /// ServiceConfirmationCard existante (déjà traduite 6 langues, role-aware) :
  ///   prestataire : 🐾 J'ai récupéré l'animal / ✅ J'ai rendu l'animal
  ///   owner       : Tout est ok ✅ (libère le paiement) / Signaler un problème
  void _showServiceActionSheet(_QuickAction a) {
    final b = a.booking;
    final accent = a.color;
    final isOwner = widget.role == 'owner';
    final cpName = isOwner
        ? (b.sitter.name.trim().isNotEmpty ? b.sitter.name : '—')
        : (b.owner.name.trim().isNotEmpty ? b.owner.name : '—');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(ctx).cardColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
        ),
        padding: EdgeInsets.fromLTRB(
          20.w, 12.h, 20.w, 24.h + MediaQuery.of(ctx).padding.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36.w,
                  height: 4.h,
                  margin: EdgeInsets.only(bottom: 12.h),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              Center(
                child: PoppinsText(
                  text: a.title,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w800,
                  color: accent,
                ),
              ),
              SizedBox(height: 12.h),
              if (b.petName.isNotEmpty) _sheetRow(Icons.pets, b.petName),
              _sheetRow(Icons.person_outline, cpName),
              if (_dateLabel(b).isNotEmpty)
                _sheetRow(Icons.event_outlined, _dateLabel(b)),
              SizedBox(height: 8.h),
              ServiceConfirmationCard(
                confirmationStatus: b.confirmationStatus,
                role: widget.role,
                isPaid: (b.paymentStatus ?? '').toLowerCase() == 'paid',
                busy: false,
                onStart: () async {
                  Navigator.pop(ctx);
                  await _svcStart(b);
                },
                onComplete: () async {
                  Navigator.pop(ctx);
                  await _svcComplete(b);
                },
                onConfirm: () async {
                  Navigator.pop(ctx);
                  await _svcConfirm(b);
                },
                onDispute: () async {
                  Navigator.pop(ctx);
                  await _svcDispute(b);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // v23.1.341 — actions service depuis le bandeau. Mêmes endpoints + mêmes
  // snackbars que les écrans Réservations, puis refresh → le bandeau passe
  // automatiquement à l'étape suivante.
  Future<void> _svcStart(BookingModel b) async {
    try {
      if (widget.role == 'walker') {
        final repo = Get.isRegistered<WalkerRepository>()
            ? Get.find<WalkerRepository>()
            : WalkerRepository(Get.find<ApiClient>());
        await repo.startService(bookingId: b.id);
      } else {
        final repo = Get.isRegistered<SitterRepository>()
            ? Get.find<SitterRepository>()
            : SitterRepository(Get.find<ApiClient>());
        await repo.startService(bookingId: b.id);
      }
      snack.CustomSnackbar.showSuccess(
        title: 'service_started_snack_title'.tr,
        message: 'service_started_snack_msg'.tr,
      );
    } catch (e) {
      snack.CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: e.toString().replaceAll('ApiException:', '').trim(),
      );
    }
    _refreshBookings();
  }

  Future<void> _svcComplete(BookingModel b) async {
    try {
      if (widget.role == 'walker') {
        final repo = Get.isRegistered<WalkerRepository>()
            ? Get.find<WalkerRepository>()
            : WalkerRepository(Get.find<ApiClient>());
        await repo.completeService(bookingId: b.id);
      } else {
        final repo = Get.isRegistered<SitterRepository>()
            ? Get.find<SitterRepository>()
            : SitterRepository(Get.find<ApiClient>());
        await repo.completeService(bookingId: b.id);
      }
      snack.CustomSnackbar.showSuccess(
        title: 'service_completed_snack_title'.tr,
        message: 'service_completed_snack_msg'.tr,
      );
    } catch (e) {
      snack.CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: e.toString().replaceAll('ApiException:', '').trim(),
      );
    }
    _refreshBookings();
  }

  Future<void> _svcConfirm(BookingModel b) async {
    try {
      final repo = Get.isRegistered<OwnerRepository>()
          ? Get.find<OwnerRepository>()
          : OwnerRepository(Get.find<ApiClient>());
      await repo.confirmService(bookingId: b.id);
      snack.CustomSnackbar.showSuccess(
        title: 'service_confirmed_snack_title'.tr,
        message: 'service_confirmed_snack_msg'.tr,
      );
    } catch (e) {
      snack.CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: e.toString().replaceAll('ApiException:', '').trim(),
      );
    }
    _refreshBookings();
  }

  Future<void> _svcDispute(BookingModel b) async {
    try {
      final repo = Get.isRegistered<OwnerRepository>()
          ? Get.find<OwnerRepository>()
          : OwnerRepository(Get.find<ApiClient>());
      await repo.disputeService(bookingId: b.id);
      snack.CustomSnackbar.showWarning(
        title: 'service_disputed_snack_title'.tr,
        message: 'service_disputed_snack_msg'.tr,
      );
    } catch (e) {
      snack.CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: e.toString().replaceAll('ApiException:', '').trim(),
      );
    }
    _refreshBookings();
  }

  /// v23.1.339 — Daniel : "le message auto sort après au lieu de de suite".
  /// Ouvre DIRECTEMENT la conversation de la réservation (où le message système
  /// "Paiement confirmé / Discutons du lieu et de l'heure" est déjà posté) au
  /// lieu de la liste des chats. Owner -> IndividualChatScreen ; prestataire ->
  /// SitterIndividualChatScreen. La conversation existe déjà (créée au paiement)
  /// et l'endpoint /conversations/start* est idempotent (renvoie l'existante).
  /// Fallback : la liste des chats si la résolution échoue.
  Future<void> _openBookingChat(BookingModel b, bool isOwnerView) async {
    try {
      final api = Get.find<ApiClient>();
      if (isOwnerView) {
        final providerId = b.sitter.id;
        if (providerId.isEmpty) {
          _openChatListFallback(true);
          return;
        }
        final isWalkerSvc =
            (b.serviceType ?? '').toLowerCase().contains('walking');
        final qp =
            isWalkerSvc ? 'walkerId=$providerId' : 'sitterId=$providerId';
        final res = await api.post(
          '/conversations/start?$qp',
          body: {'message': 'payment_chat_opener_message'.tr},
          requiresAuth: true,
        );
        final convId = _extractConversationId(res);
        if (convId.isEmpty) {
          _openChatListFallback(true);
          return;
        }
        Get.to(() => IndividualChatScreen(
              conversationId: convId,
              contactName: b.sitter.name,
              contactImage: b.sitter.avatar.url,
            ));
      } else {
        final ownerId = b.owner.id;
        if (ownerId.isEmpty) {
          _openChatListFallback(false);
          return;
        }
        final endpoint = widget.role == 'walker'
            ? '/conversations/start-by-walker'
            : '/conversations/start-by-sitter';
        final res = await api.post(
          '$endpoint?ownerId=$ownerId',
          body: const <String, dynamic>{},
          requiresAuth: true,
        );
        final convId = _extractConversationId(res);
        if (convId.isEmpty) {
          _openChatListFallback(false);
          return;
        }
        Get.to(() => SitterIndividualChatScreen(
              conversationId: convId,
              contactName: b.owner.name,
              contactImage: b.owner.avatar.url,
            ));
      }
    } catch (e) {
      AppLogger.logError('open booking chat failed', error: e);
      _openChatListFallback(isOwnerView);
    }
  }

  String _extractConversationId(dynamic res) {
    if (res is Map && res['conversation'] is Map) {
      final c = res['conversation'] as Map;
      return (c['id'] ?? c['_id'] ?? '').toString();
    }
    return '';
  }

  void _openChatListFallback(bool isOwnerView) {
    if (isOwnerView) {
      Get.to(() => const ChatScreen());
    } else {
      Get.to(() => const SitterChatScreen());
    }
  }

  /// v23.1 part 34 — bottom sheet pour le banner "Paiement reçu" côté provider.
  /// Affiche : owner avatar+nom, montant, service, date, + 2 actions :
  /// Voir factures / Voir le chat avec l'owner.
  void _showProviderPaidSheet(_QuickAction a) {
    final b = a.booking;
    final ownerName = b.owner.name.isNotEmpty ? b.owner.name : '—';
    final ownerAvatar = b.owner.avatar.url;
    final petLbl = b.petName;
    final dateLbl = _dateLabel(b);
    final amount = (b.pricing?.totalPrice ?? b.totalAmount ?? 0).toDouble();
    final currency = b.pricing?.currency ?? b.sitter.currency;
    final accent = a.color;
    // v23.1.327 — Daniel : ce sheet est partagé owner ↔ prestataire. On l'adapte
    // au PROFIL qui le regarde : le prestataire voit l'OWNER ("Paiement reçu"),
    // l'owner voit le PRESTATAIRE ("Paiement effectué"). Le bouton "Discuter"
    // pointe vers la bonne contrepartie + le bon écran de chat.
    final bool isOwnerView = widget.role == 'owner';
    final bool isWalkerSvc =
        (b.serviceType ?? '').toLowerCase().contains('walking');
    final String cpName = isOwnerView
        ? (b.sitter.name.trim().isNotEmpty ? b.sitter.name : '—')
        : ownerName;
    final String cpAvatar = isOwnerView ? b.sitter.avatar.url : ownerAvatar;
    final String cpRoleKey = isOwnerView
        ? (isWalkerSvc ? 'role_walker' : 'role_sitter')
        : 'role_pet_owner';
    final String titleKey = isOwnerView
        ? 'payment_made_banner_title'
        : 'payment_received_banner_title';
    final String chatBtnKey = isOwnerView
        ? (isWalkerSvc ? 'chat_with_walker_button' : 'chat_with_sitter_button')
        : 'chat_with_owner_button';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(ctx).cardColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
        ),
        padding: EdgeInsets.fromLTRB(
          20.w, 12.h, 20.w, 24.h + MediaQuery.of(ctx).padding.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // v23.1 part 66 — Bug 3 : Daniel wanted a small close X
              // next to the "Voir mes factures" button so he can dismiss
              // the sheet without swiping. We expose it at the top-right
              // (visually next to the drag handle), which is the
              // conventional location and lets us add the same to the
              // other action sheets without bloating the action row.
              Stack(
                // v23.1.327 — Daniel : "le X de fermeture est coupé". Le Stack
                // clippe par défaut (Clip.hardEdge) → l'icône positionnée
                // débordait et se faisait rogner. Clip.none la rend entière.
                clipBehavior: Clip.none,
                children: [
                  Center(
                    child: Container(
                      width: 36.w, height: 4.h,
                      margin: EdgeInsets.only(bottom: 12.h),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2.r),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    top: -2,
                    child: GestureDetector(
                      onTap: () => Navigator.of(ctx).pop(),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: EdgeInsets.all(6.w),
                        child: Icon(
                          Icons.close_rounded,
                          color: const Color(0xFF707070),
                          size: 22.sp,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Center(
                child: Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.check_circle_rounded,
                      color: accent, size: 36.sp),
                ),
              ),
              SizedBox(height: 12.h),
              Center(
                child: PoppinsText(
                  text: titleKey.tr,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w800,
                  color: accent,
                ),
              ),
              SizedBox(height: 4.h),
              Center(
                child: InterText(
                  text: CurrencyHelper.format(currency, amount),
                  fontSize: 24.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 20.h),
              Row(
                children: [
                  CircleAvatar(
                    radius: 22.r,
                    backgroundColor: accent.withValues(alpha: 0.15),
                    // v23.1 part 231 — perf : CachedNetworkImageProvider 150.
                    backgroundImage: cpAvatar.isNotEmpty
                        ? CachedNetworkImageProvider(cpAvatar, maxWidth: 150)
                        : null,
                    child: cpAvatar.isEmpty
                        ? Icon(Icons.person, color: accent, size: 22.sp)
                        : null,
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PoppinsText(
                          text: cpName,
                          fontSize: 14.sp, fontWeight: FontWeight.w700,
                        ),
                        SizedBox(height: 2.h),
                        InterText(
                          text: cpRoleKey.tr,
                          fontSize: 11.sp,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              if (petLbl.isNotEmpty) _sheetRow(Icons.pets, petLbl),
              if (dateLbl.isNotEmpty) _sheetRow(Icons.event_outlined, dateLbl),
              SizedBox(height: 16.h),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Get.to(() => const InvoicesScreen());
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                  ),
                  icon: Icon(Icons.receipt_long_rounded,
                      color: Colors.white, size: 20.sp),
                  label: Text(
                    'view_my_invoices_button'.tr,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.sp, fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 10.h),
              // v23.1.327 — Daniel : 2e action "Discuter avec [contrepartie]".
              // Ouvre le chat du bon profil (owner -> ChatScreen ;
              // sitter/walker -> SitterChatScreen). La conversation avec la
              // contrepartie y est en tête (chat débloqué au paiement).
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    // v23.1.339 — Daniel : "le message auto sort après au lieu
                    // de de suite". Avant, ce bouton ouvrait la LISTE des chats
                    // → il fallait encore taper la conversation pour voir le
                    // message auto (paiement confirmé). Maintenant on ouvre
                    // DIRECTEMENT la conversation de la réservation → le message
                    // auto est visible de suite.
                    _openBookingChat(b, isOwnerView);
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: accent, width: 1.5),
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                  ),
                  icon: Icon(Icons.chat_bubble_outline_rounded,
                      color: accent, size: 20.sp),
                  label: Text(
                    chatBtnKey.tr,
                    style: TextStyle(
                      color: accent,
                      fontSize: 14.sp, fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showProviderRequestSheet(_QuickAction a) {
    final b = a.booking;
    final ownerName = b.owner.name.isNotEmpty ? b.owner.name : '—';
    final ownerAvatar = b.owner.avatar.url;
    final petLabel = b.petName;
    final dateLbl = _dateLabel(b);
    final timeLbl = b.timeSlot.isNotEmpty ? b.timeSlot : '';
    final svcLbl = _serviceLabel(b.serviceType);
    // BookingModel has no locationType getter; we just use owner.address.
    final addressLbl = b.owner.address.isNotEmpty ? b.owner.address : '';
    final accent = a.color;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      // v23.1 — useSafeArea so the sheet respects system insets (gesture
      // nav bar / home indicator). Without this the bottom action buttons
      // were cropped by the OS handle on Android Q+ / iOS.
      useSafeArea: true,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(ctx).cardColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
        ),
        padding: EdgeInsets.fromLTRB(
          20.w,
          12.h,
          20.w,
          24.h + MediaQuery.of(ctx).padding.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36.w,
                  height: 4.h,
                  margin: EdgeInsets.only(bottom: 12.h),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              Row(
                children: [
                  CircleAvatar(
                    radius: 26.r,
                    backgroundColor: accent.withValues(alpha: 0.15),
                    // v23.1 part 231 — perf cache + maxWidth.
                    backgroundImage: ownerAvatar.isNotEmpty
                        ? CachedNetworkImageProvider(ownerAvatar, maxWidth: 150)
                        : null,
                    child: ownerAvatar.isEmpty
                        ? Icon(Icons.person, color: accent, size: 26.sp)
                        : null,
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PoppinsText(
                          text: ownerName,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                        ),
                        SizedBox(height: 2.h),
                        InterText(
                          text: 'role_pet_owner'.tr,
                          fontSize: 12.sp,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.h),
              _sheetRow(Icons.pets, petLabel),
              if (svcLbl.isNotEmpty) _sheetRow(Icons.work_outline, svcLbl),
              if (dateLbl.isNotEmpty) _sheetRow(Icons.event_outlined, dateLbl),
              if (timeLbl.isNotEmpty)
                _sheetRow(Icons.access_time, timeLbl),
              if (addressLbl.isNotEmpty)
                _sheetRow(Icons.location_on_outlined, addressLbl),
              SizedBox(height: 20.h),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _onAccept(a);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                      ),
                      child: Text(
                        'snackbar_text_request_accepted'.tr,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _onRefuse(a);
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: const Color(0xFFE53935)),
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                      ),
                      child: Text(
                        'snackbar_text_request_refused'.tr,
                        style: TextStyle(
                          color: const Color(0xFFE53935),
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetRow(IconData icon, String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Row(
        children: [
          Icon(icon, size: 18.sp, color: Colors.grey),
          SizedBox(width: 10.w),
          Expanded(
            child: InterText(
              text: text,
              fontSize: 13.sp,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// v23.1 part 21 — bottom sheet riche pour la candidature owner.
  /// Affiche : avatar + nom + role badge + rating + service/pet/date,
  /// puis 3 boutons : Accept / Refuse / Voir profil.
  /// Pour le multi-candidats (>1 candidat même post), bascule sur PostCandidatesSheet.
  void _showOwnerCandidateSheet(_QuickAction a) {
    if (!Get.isRegistered<ApplicationsController>()) {
      Get.to(() => const MyPostsScreen());
      return;
    }
    final ctrl = Get.find<ApplicationsController>();
    ApplicationModel? app;
    try {
      app = ctrl.applications.firstWhere(
        (x) => x.id == a.candidateApplicationId,
      );
    } catch (_) {
      app = null;
    }
    if (app == null) {
      Get.to(() => const MyPostsScreen());
      return;
    }

    // Si plusieurs candidats sur le même post → ouvre la sheet multi-candidats
    // qui présente la liste et permet le choix optimal.
    final samePostCount = ctrl.applications.where((x) {
      return x.postId == app!.postId &&
          x.status.toLowerCase() == 'pending';
    }).length;
    if (samePostCount > 1 && (app.postId ?? '').isNotEmpty) {
      PostCandidatesSheet.show(context: context, postId: app.postId!);
      return;
    }

    final isWalker = app.providerRole == 'walker';
    final accent = isWalker
        ? const Color(0xFF16A34A)
        : const Color(0xFF2563EB);
    final providerName = app.sitter.name.trim().isNotEmpty
        ? app.sitter.name
        : (isWalker ? 'role_walker'.tr : 'role_sitter'.tr);
    final providerAvatar = app.sitter.avatar.url;
    final petLabel = app.petName;
    final dateLbl = (app.serviceDate ?? '').split('T').first;
    final timeLbl = app.timeSlot;
    final addrLbl = app.sitter.city ?? app.sitter.address;
    final rating = app.sitter.rating;
    final priceLbl = (app.pricing != null && app.pricing!.totalPrice != null)
        ? CurrencyHelper.format(
            app.pricing!.currency ?? 'EUR',
            (app.pricing!.totalPrice ?? 0).toDouble(),
          )
        : '';

    final localApp = app;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(ctx).cardColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
        ),
        padding: EdgeInsets.fromLTRB(
          20.w,
          12.h,
          20.w,
          24.h + MediaQuery.of(ctx).padding.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36.w,
                  height: 4.h,
                  margin: EdgeInsets.only(bottom: 12.h),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              Row(
                children: [
                  CircleAvatar(
                    radius: 28.r,
                    backgroundColor: accent.withValues(alpha: 0.15),
                    // v23.1 part 231 — perf.
                    backgroundImage: providerAvatar.isNotEmpty
                        ? CachedNetworkImageProvider(providerAvatar, maxWidth: 200)
                        : null,
                    child: providerAvatar.isEmpty
                        ? Icon(Icons.person, color: accent, size: 28.sp)
                        : null,
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: PoppinsText(
                                text: providerName,
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            // v23.1 part 38 — VerifiedBadge dans le sheet candidature
                            if (localApp.sitter.verified) ...[
                              SizedBox(width: 6.w),
                              VerifiedBadge(isVerified: true),
                            ],
                            SizedBox(width: 6.w),
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 6.w, vertical: 2.h),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6.r),
                              ),
                              child: InterText(
                                text: isWalker
                                    ? 'role_walker'.tr
                                    : 'role_sitter'.tr,
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w700,
                                color: accent,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4.h),
                        Row(
                          children: [
                            Icon(Icons.star_rounded,
                                color: const Color(0xFFFFB400), size: 16.sp),
                            SizedBox(width: 4.w),
                            InterText(
                              text: rating > 0
                                  ? rating.toStringAsFixed(1)
                                  : '—',
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                            ),
                            if (priceLbl.isNotEmpty) ...[
                              SizedBox(width: 10.w),
                              Icon(Icons.payments_outlined,
                                  size: 14.sp, color: accent),
                              SizedBox(width: 3.w),
                              InterText(
                                text: priceLbl,
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                                color: accent,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.h),
              if (petLabel.isNotEmpty) _sheetRow(Icons.pets, petLabel),
              if (dateLbl.isNotEmpty)
                _sheetRow(Icons.event_outlined, dateLbl),
              if (timeLbl.isNotEmpty) _sheetRow(Icons.access_time, timeLbl),
              if (addrLbl.isNotEmpty)
                _sheetRow(Icons.location_on_outlined, addrLbl),
              SizedBox(height: 20.h),
              // 3 actions : Accept / Refuse / Voir profil
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _ownerAcceptCandidate(localApp);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                      ),
                      icon: Icon(Icons.check_rounded,
                          color: Colors.white, size: 18.sp),
                      label: Text(
                        'snackbar_text_request_accepted'.tr,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _ownerRejectCandidate(localApp);
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFE53935)),
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                      ),
                      icon: Icon(Icons.close_rounded,
                          color: const Color(0xFFE53935), size: 18.sp),
                      label: Text(
                        'snackbar_text_request_refused'.tr,
                        style: TextStyle(
                          color: const Color(0xFFE53935),
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    // v23.1 part 37 — fix Daniel : navigue vers la screen
                    // complète (sitter ou walker) au lieu d'un dialog minimal.
                    if (isWalker) {
                      Get.to(() => WalkerDetailScreen(
                            walkerId: localApp.sitter.id,
                          ));
                    } else {
                      Get.to(() => ServiceProviderDetailScreen(
                            sitterId: localApp.sitter.id,
                            status: 'pending',
                          ));
                    }
                  },
                  icon: Icon(Icons.person_outline,
                      color: accent, size: 18.sp),
                  label: Text(
                    isWalker
                        ? 'view_walker_profile'.tr
                        : 'view_sitter_profile'.tr,
                    style: TextStyle(
                      color: accent,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// v23.1.337 — Daniel : "je veux que la demande d'amis s'affiche dans la
  /// bande et qu'on puisse voir le profil de celui qui me demande, corrige
  /// sur les 3 profils owner/sitter/walker avec traduction". Sheet riche :
  /// avatar + nom + badge rôle + ville du DEMANDEUR (= voir son profil), avec
  /// Accepter / Refuser. Pour un demandeur prestataire (sitter/walker) on
  /// ajoute "Voir le profil complet" → écran détail public dédié. Pour un
  /// demandeur owner (pas d'écran public) la carte fait office de profil.
  void _showFriendRequestSheet(_QuickAction a) {
    final f = a.friendship;
    if (f == null || f.other == null) return;
    final other = f.other!;
    final role = other.roleLowercase; // owner | sitter | walker
    final accent = a.color;
    final name = other.name.trim().isNotEmpty
        ? other.name
        : _friendRoleLabel(role);
    final avatar = other.avatar;
    final city = other.city;
    final roleLabel = _friendRoleLabel(role);
    final isWalker = role == 'walker';
    final isSitter = role == 'sitter';
    final isProvider = isWalker || isSitter;
    final otherId = other.id;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(ctx).cardColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
        ),
        padding: EdgeInsets.fromLTRB(
          20.w,
          12.h,
          20.w,
          24.h + MediaQuery.of(ctx).padding.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36.w,
                  height: 4.h,
                  margin: EdgeInsets.only(bottom: 12.h),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              // En-tête : "Nouvelle demande d'ami".
              Center(
                child: PoppinsText(
                  text: 'friend_request_banner_title'.tr,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w800,
                  color: accent,
                ),
              ),
              SizedBox(height: 16.h),
              // Carte profil du demandeur.
              Row(
                children: [
                  CircleAvatar(
                    radius: 28.r,
                    backgroundColor: accent.withValues(alpha: 0.15),
                    backgroundImage: avatar.isNotEmpty
                        ? CachedNetworkImageProvider(avatar, maxWidth: 200)
                        : null,
                    child: avatar.isEmpty
                        ? Icon(Icons.person, color: accent, size: 28.sp)
                        : null,
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PoppinsText(
                          text: name,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                        ),
                        SizedBox(height: 6.h),
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 8.w, vertical: 3.h),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6.r),
                          ),
                          child: InterText(
                            text: roleLabel,
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w700,
                            color: accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              if (city.trim().isNotEmpty)
                _sheetRow(Icons.location_on_outlined, city),
              SizedBox(height: 16.h),
              // Accepter / Refuser.
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _acceptFriendRequest(a);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                      ),
                      icon: Icon(Icons.check_rounded,
                          color: Colors.white, size: 18.sp),
                      label: Text(
                        'pawfollow_accept'.tr,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _declineFriendRequest(a);
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFE53935)),
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                      ),
                      icon: Icon(Icons.close_rounded,
                          color: const Color(0xFFE53935), size: 18.sp),
                      label: Text(
                        'pawfollow_refuse'.tr,
                        style: TextStyle(
                          color: const Color(0xFFE53935),
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              // Pour un prestataire : "Voir le profil complet" → écran détail.
              if (isProvider && otherId.isNotEmpty) ...[
                SizedBox(height: 8.h),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      if (isWalker) {
                        Get.to(() => WalkerDetailScreen(walkerId: otherId));
                      } else {
                        Get.to(() => ServiceProviderDetailScreen(
                              sitterId: otherId,
                              status: 'pending',
                            ));
                      }
                    },
                    icon: Icon(Icons.person_outline,
                        color: accent, size: 18.sp),
                    label: Text(
                      isWalker
                          ? 'view_walker_profile'.tr
                          : 'view_sitter_profile'.tr,
                      style: TextStyle(
                        color: accent,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// v23.1.338 — Daniel : "et famille aussi". Sheet d'invitation Famille
  /// PawFollow (violet) : profil du TITULAIRE qui invite (avatar / nom / badge
  /// rôle) + Accepter / Refuser. Pour un titulaire prestataire on ajoute
  /// "Voir le profil complet". Couvre les 3 rôles d'inviteur.
  void _showFamilyInvitationSheet(_QuickAction a) {
    final inv = a.familyInvitation;
    if (inv == null) return;
    final accent = a.color; // violet 0xFF8B5CF6
    final role = (inv['familyOwnerRole'] ?? 'owner').toString().toLowerCase();
    final rawName = (inv['familyOwnerName'] ?? '').toString().trim();
    final name = rawName.isNotEmpty ? rawName : _friendRoleLabel(role);
    final avatar = (inv['familyOwnerAvatar'] ?? '').toString();
    final roleLabel = _friendRoleLabel(role);
    final isWalker = role == 'walker';
    final isSitter = role == 'sitter';
    final isProvider = isWalker || isSitter;
    final ownerId = (inv['familyOwnerId'] ?? '').toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(ctx).cardColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
        ),
        padding: EdgeInsets.fromLTRB(
          20.w,
          12.h,
          20.w,
          24.h + MediaQuery.of(ctx).padding.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36.w,
                  height: 4.h,
                  margin: EdgeInsets.only(bottom: 12.h),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              Center(
                child: PoppinsText(
                  text: 'family_invitation_received_title'.tr,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w800,
                  color: accent,
                ),
              ),
              SizedBox(height: 6.h),
              Center(
                child: InterText(
                  text: 'family_invitation_banner_subtitle'
                      .trParams({'name': name}),
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(height: 16.h),
              Row(
                children: [
                  CircleAvatar(
                    radius: 28.r,
                    backgroundColor: accent.withValues(alpha: 0.15),
                    backgroundImage: avatar.isNotEmpty
                        ? CachedNetworkImageProvider(avatar, maxWidth: 200)
                        : null,
                    child: avatar.isEmpty
                        ? Icon(Icons.person, color: accent, size: 28.sp)
                        : null,
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PoppinsText(
                          text: name,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                        ),
                        SizedBox(height: 6.h),
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 8.w, vertical: 3.h),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6.r),
                          ),
                          child: InterText(
                            text: roleLabel,
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w700,
                            color: accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.h),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _acceptFamilyInvitation(a);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                      ),
                      icon: Icon(Icons.check_rounded,
                          color: Colors.white, size: 18.sp),
                      label: Text(
                        'pawfollow_accept'.tr,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _refuseFamilyInvitation(a);
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFE53935)),
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                      ),
                      icon: Icon(Icons.close_rounded,
                          color: const Color(0xFFE53935), size: 18.sp),
                      label: Text(
                        'pawfollow_refuse'.tr,
                        style: TextStyle(
                          color: const Color(0xFFE53935),
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (isProvider && ownerId.isNotEmpty) ...[
                SizedBox(height: 8.h),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      if (isWalker) {
                        Get.to(() => WalkerDetailScreen(walkerId: ownerId));
                      } else {
                        Get.to(() => ServiceProviderDetailScreen(
                              sitterId: ownerId,
                              status: 'pending',
                            ));
                      }
                    },
                    icon: Icon(Icons.person_outline,
                        color: accent, size: 18.sp),
                    label: Text(
                      isWalker
                          ? 'view_walker_profile'.tr
                          : 'view_sitter_profile'.tr,
                      style: TextStyle(
                        color: accent,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _ownerAcceptCandidate(ApplicationModel app) async {
    if (!Get.isRegistered<ApplicationsController>()) return;
    final ctrl = Get.find<ApplicationsController>();
    await ctrl.respondToApplication(applicationId: app.id, action: 'accept');
  }

  Future<void> _ownerRejectCandidate(ApplicationModel app) async {
    if (!Get.isRegistered<ApplicationsController>()) return;
    final ctrl = Get.find<ApplicationsController>();
    await ctrl.respondToApplication(applicationId: app.id, action: 'reject');
  }

  /// v22.5 — PART 3 : pre-warm createPaymentIntent puis push AirwallexPaymentScreen.
  Future<void> _navigateOwnerPay(_QuickAction a) async {
    final booking = a.booking;
    try {
      try {
        if (Get.isRegistered<OwnerRepository>()) {
          await Get.find<OwnerRepository>().createPaymentIntent(bookingId: booking.id);
        }
      } catch (e) {
        AppLogger.logDebug('owner banner pre-warm failed: $e');
      }
      final pricing = booking.pricing;
      final base = (pricing?.totalPrice
              ?? pricing?.resolvedBaseAmount
              ?? booking.totalAmount
              ?? booking.basePrice) ??
          0.0;
      final serviceLower = (booking.serviceType ?? '').toLowerCase();
      final providerType = (serviceLower.contains('walking') ||
              serviceLower.contains('dog_walking'))
          ? 'walker'
          : 'sitter';
      await Get.to(
        () => AirwallexPaymentScreen(
          booking: booking,
          totalAmount: base,
          currency: pricing?.currency ?? booking.sitter.currency,
          providerType: providerType,
        ),
      );
    } catch (e) {
      AppLogger.logError('owner banner navigation failed', error: e);
      Get.to(() => const BookingsHistoryScreen());
    }
  }

  Future<void> _onAccept(_QuickAction a) async {
    // v23.1.337 — demande d'ami (au cas où un bouton inline appellerait ce
    // handler) → on accepte la friendship, pas un booking.
    if (a.kind == _Kind.friendRequest) {
      await _acceptFriendRequest(a);
      return;
    }
    if (a.kind == _Kind.familyInvitation) {
      await _acceptFamilyInvitation(a);
      return;
    }
    // v23.1 — bug #3 fix : really call POST /bookings/:id/respond instead of
    // navigating to the details screen. Same endpoint works for sitter AND
    // walker (no role middleware on the route).
    await _respondToBooking(a, 'accept');
  }

  Future<void> _onRefuse(_QuickAction a) async {
    if (a.kind == _Kind.friendRequest) {
      await _declineFriendRequest(a);
      return;
    }
    if (a.kind == _Kind.familyInvitation) {
      await _refuseFamilyInvitation(a);
      return;
    }
    // v23.1 — bug #2 fix : really call POST /bookings/:id/respond reject.
    await _respondToBooking(a, 'reject');
  }

  // v23.1.338 — onglets de FriendsScreen : 0=Amis · 1=Demandes · 2=Ajouter ·
  // 3=Famille. Daniel : "quand on accepte ou on refuse ça nous envoie dans
  // l'onglet amis ou famille".
  static const int _friendsTabFriends = 0;
  static const int _friendsTabFamily = 3;

  void _openFriendsTab(int index) {
    Get.to(() => FriendsScreen(initialIndex: index));
  }

  /// v23.1.337 — accepte la demande d'ami depuis la bande/sheet, puis refresh
  /// (FriendController.accept appelle déjà refresh() → la bande se met à jour)
  /// et redirige vers l'onglet Amis (v23.1.338).
  Future<void> _acceptFriendRequest(_QuickAction a) async {
    final f = a.friendship;
    if (f == null || f.id.isEmpty) return;
    if (!Get.isRegistered<FriendController>()) return;
    final ok = await Get.find<FriendController>().accept(f.id);
    if (ok) {
      snack.CustomSnackbar.showSuccess(
        title: 'snackbar_text_request_accepted'.tr,
        message: 'friend_request_accepted_msg'.tr,
      );
      _openFriendsTab(_friendsTabFriends);
    } else {
      snack.CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'friends_invite_err_title'.tr,
      );
    }
  }

  Future<void> _declineFriendRequest(_QuickAction a) async {
    final f = a.friendship;
    if (f == null || f.id.isEmpty) return;
    if (!Get.isRegistered<FriendController>()) return;
    final ok = await Get.find<FriendController>().decline(f.id);
    if (ok) {
      snack.CustomSnackbar.showSuccess(
        title: 'snackbar_text_request_refused'.tr,
        message: 'friend_request_declined_msg'.tr,
      );
      _openFriendsTab(_friendsTabFriends);
    }
  }

  /// v23.1.338 — accepte l'invitation Famille puis redirige vers l'onglet
  /// Famille (FriendController.acceptFamilyInvitation recharge déjà loadFamily
  /// + loadFamilyInvitations → la bande se met à jour).
  Future<void> _acceptFamilyInvitation(_QuickAction a) async {
    final inv = a.familyInvitation;
    final id = (inv?['invitationId'] ?? inv?['id'] ?? '').toString();
    if (id.isEmpty) return;
    if (!Get.isRegistered<FriendController>()) return;
    final ok = await Get.find<FriendController>().acceptFamilyInvitation(id);
    if (ok) {
      snack.CustomSnackbar.showSuccess(
        title: 'snackbar_text_request_accepted'.tr,
        message: 'family_invitation_accepted_msg'.tr,
      );
      _openFriendsTab(_friendsTabFamily);
    } else {
      snack.CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'friends_invite_err_title'.tr,
      );
    }
  }

  Future<void> _refuseFamilyInvitation(_QuickAction a) async {
    final inv = a.familyInvitation;
    final id = (inv?['invitationId'] ?? inv?['id'] ?? '').toString();
    if (id.isEmpty) return;
    if (!Get.isRegistered<FriendController>()) return;
    final ok = await Get.find<FriendController>().refuseFamilyInvitation(id);
    if (ok) {
      snack.CustomSnackbar.showSuccess(
        title: 'snackbar_text_request_refused'.tr,
        message: 'family_invitation_declined_msg'.tr,
      );
      _openFriendsTab(_friendsTabFamily);
    }
  }

  Future<void> _respondToBooking(_QuickAction a, String action) async {
    if (_isResponding) return; // v23.1 — debounce double-tap
    _isResponding = true;
    final isAccept = action == 'accept';
    try {
      // v23.1 — SitterRepository requires an ApiClient. The DI registers it
      // at startup, so the fallback path is just defensive in case the repo
      // wasn't put yet (e.g. a hot-reload race).
      final repo = Get.isRegistered<SitterRepository>()
          ? Get.find<SitterRepository>()
          : SitterRepository(Get.find<ApiClient>());
      await repo.respondToBooking(bookingId: a.booking.id, action: action);

      // Refresh the relevant bookings list so the banner updates immediately.
      try {
        if (widget.role == 'sitter' &&
            Get.isRegistered<SitterBookingsController>()) {
          await Get.find<SitterBookingsController>().loadBookings();
        } else if (widget.role == 'walker' &&
            Get.isRegistered<WalkerBookingsController>()) {
          await Get.find<WalkerBookingsController>().loadBookings();
        }
      } catch (e) {
        AppLogger.logError('respondBooking refresh failed', error: e);
      }

      snack.CustomSnackbar.showSuccess(
        title: isAccept ? 'snackbar_text_request_accepted'.tr : 'snackbar_text_request_refused'.tr,
        message: isAccept
            ? 'snackbar_text_request_accepted_message'.tr
            : 'snackbar_text_request_refused_message'.tr,
      );
    } catch (e) {
      AppLogger.logError('respondToBooking failed', error: e);
      snack.CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: e.toString(),
      );
    } finally {
      // v448 — AUDIT : sans ce reset, _isResponding restait à true après le
      // 1er tap → accepter/refuser depuis la bande ne marchait qu'UNE fois
      // par session (le debounce double-tap bloquait tous les taps suivants).
      _isResponding = false;
    }
  }

  void _dismissBannerMulti(List<String> bookingIds) {
    if (bookingIds.isEmpty) return;
    setState(() => _dismissedIds.addAll(bookingIds));
    try {
      _bannerStorage.write(
        StorageKeys.dismissedBannerBookings,
        _dismissedIds.toList(),
      );
    } catch (_) {}
  }
}

// ─── Banner widget ──────────────────────────────────────────────────────────

class _ActionBanner extends StatelessWidget {
  final _QuickAction action;
  final AnimationController pulse;
  final VoidCallback onTap;
  final VoidCallback onAccept;
  final VoidCallback onRefuse;
  // v23.1 — PART 2 : optional X dismiss button (owner-pay only).
  final VoidCallback? onDismiss;

  const _ActionBanner({
    required this.action,
    required this.pulse,
    required this.onTap,
    required this.onAccept,
    required this.onRefuse,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 4.h),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedBuilder(
          animation: pulse,
          builder: (context, _) {
            final scale = action.pulse ? 1.0 + 0.012 * pulse.value : 1.0;
            return Transform.scale(
              scale: scale,
              child: Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: action.color,
                  borderRadius: BorderRadius.circular(12.r),
                  boxShadow: [
                    BoxShadow(
                      color: action.color.withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 36.w,
                      height: 36.w,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      child: Icon(action.icon, color: Colors.white, size: 20.sp),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          PoppinsText(
                            text: action.title,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                          if (action.subtitle.isNotEmpty) ...[
                            SizedBox(height: 2.h),
                            InterText(
                              text: action.subtitle,
                              fontSize: 11.5.sp,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.95),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    SizedBox(width: 8.w),
                    if (action.kind == _Kind.providerAccept) ...[
                      _BannerSmallButton(
                        label: '✓',
                        bg: Colors.white,
                        fg: action.color,
                        onTap: onAccept,
                      ),
                      SizedBox(width: 6.w),
                      _BannerSmallButton(
                        label: '✗',
                        bg: const Color(0xFFE53935),
                        fg: Colors.white,
                        onTap: onRefuse,
                      ),
                    ] else if (action.ctaLabel.isNotEmpty)
                      _BannerCtaButton(
                        label: action.ctaLabel,
                        bg: Colors.white,
                        fg: action.color,
                        onTap: onTap,
                      ),
                    // v23.1 — PART 2 : X dismiss button (owner-pay only).
                    if (onDismiss != null) ...[
                      SizedBox(width: 6.w),
                      GestureDetector(
                        onTap: onDismiss,
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: EdgeInsets.all(4.w),
                          child: Icon(
                            Icons.close_rounded,
                            color: Colors.white.withValues(alpha: 0.85),
                            size: 18.sp,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BannerCtaButton extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  final VoidCallback onTap;
  const _BannerCtaButton({
    required this.label,
    required this.bg,
    required this.fg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: PoppinsText(
          text: label,
          fontSize: 12.sp,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

class _BannerSmallButton extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  final VoidCallback onTap;
  const _BannerSmallButton({
    required this.label,
    required this.bg,
    required this.fg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32.w,
        height: 32.w,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10.r),
        ),
        alignment: Alignment.center,
        child: PoppinsText(
          text: label,
          fontSize: 16.sp,
          fontWeight: FontWeight.w800,
          color: fg,
        ),
      ),
    );
  }
}

// ─── Neutral fallback banner (no urgent action) ─────────────────────────────
//
// v21.1.1 — barre toujours visible même quand rien d'urgent. Couleur role-
// based mais en alpha bas (subtile, n'écrase pas la home page). Cliquable
// pour ouvrir l'historique des bookings.
class _NeutralBar extends StatelessWidget {
  final String role; // 'owner' | 'sitter' | 'walker'
  final VoidCallback onTap;
  const _NeutralBar({required this.role, required this.onTap});

  Color _accent() {
    switch (role) {
      case 'walker':
        return const Color(0xFF16A34A);
      case 'sitter':
        return const Color(0xFF2563EB);
      case 'owner':
      default:
        return const Color(0xFFEF4324);
    }
  }

  String _title() {
    switch (role) {
      case 'walker':
      case 'sitter':
        return 'quick_action_title_provider'.tr;
      case 'owner':
      default:
        return 'quick_action_title_owner'.tr;
    }
  }

  String _subtitle() {
    switch (role) {
      case 'walker':
        return 'quick_action_subtitle_walker'.tr;
      case 'sitter':
        return 'quick_action_subtitle_sitter'.tr;
      case 'owner':
      default:
        return 'quick_action_subtitle_owner'.tr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accent();
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 4.h),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: accent.withValues(alpha: 0.20),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36.w,
                height: 36.w,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(
                  Icons.check_circle_outline_rounded,
                  color: accent,
                  size: 20.sp,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PoppinsText(
                      text: _title(),
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                    SizedBox(height: 2.h),
                    InterText(
                      text: _subtitle(),
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w500,
                      color: accent.withValues(alpha: 0.85),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              Icon(
                Icons.chevron_right_rounded,
                color: accent.withValues(alpha: 0.6),
                size: 20.sp,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Internal action descriptor ─────────────────────────────────────────────

enum _Kind {
  ownerPay,
  providerAccept,
  providerPaid,
  ownerCandidate,
  friendRequest,
  familyInvitation,
  // v23.1.341 — Daniel : "les notifications de début et fin de service
  // passent par le bandeau, plus simple". Action de service (début / fin /
  // confirmation owner) : tap → sheet avec ServiceConfirmationCard.
  serviceAction,
  // v23.1.349 — Daniel : "lorsque le service est fini, je veux la notification
  // bandeau pour sitter et walker : paiement reçu". L'owner a confirmé la fin
  // → l'argent vient d'être DÉBLOQUÉ dans le wallet. Tap → WalletScreen.
  providerReleased,
}

class _QuickAction {
  final _Kind kind;
  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final String ctaLabel;
  final BookingModel booking;
  final bool pulse;
  // v23.1 — when an owner-pay banner aggregates multiple bookings ('+2 autres'),
  // we keep the full list here so a single X tap dismisses *all* of them at
  // once — otherwise the banner reappeared on next refresh with the next
  // unpaid booking and Daniel could never get rid of it.
  final List<String> allBookingIds;
  // v23.1 part 20 — owner-candidate variant : carry the application ids so
  // the X dismiss button can hide them and the tap handler routes to the
  // multi-candidates UI in MyPostsScreen.
  final String? candidateApplicationId;
  final List<String> allCandidateApplicationIds;
  // v23.1.337 — friendRequest variant : on porte la Friendship pending pour
  // que le tap ouvre la sheet profil du demandeur + Accepter/Refuser.
  final Friendship? friendship;
  // v23.1.338 — familyInvitation variant : on porte l'invitation famille
  // pending (Map renvoyée par /friends/family/invitations) pour la sheet +
  // accept/refuse.
  final Map<String, dynamic>? familyInvitation;
  const _QuickAction({
    required this.kind,
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.ctaLabel,
    required this.booking,
    required this.pulse,
    this.allBookingIds = const <String>[],
    this.candidateApplicationId,
    this.allCandidateApplicationIds = const <String>[],
    this.friendship,
    this.familyInvitation,
  });
}

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

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/applications_controller.dart';
import 'package:hopetsit/controllers/bookings_controller.dart';
import 'package:hopetsit/controllers/notifications_controller.dart';
import 'package:hopetsit/controllers/sitter_bookings_controller.dart';
import 'package:hopetsit/controllers/walker_bookings_controller.dart';
import 'package:hopetsit/models/application_model.dart';
import 'package:hopetsit/models/booking_model.dart';
import 'package:hopetsit/repositories/owner_repository.dart';
import 'package:hopetsit/repositories/sitter_repository.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart' as snack;
import 'package:hopetsit/utils/currency_helper.dart';
import 'package:hopetsit/utils/logger.dart';
import 'package:hopetsit/views/booking/bookings_history_screen.dart';
import 'package:hopetsit/views/invoices/invoices_screen.dart';
import 'package:hopetsit/views/payment/stripe_payment_screen.dart';
import 'package:hopetsit/views/pet_owner/posts/my_posts_screen.dart';
import 'package:hopetsit/views/pet_owner/posts/widgets/post_candidates_sheet.dart';
import 'package:hopetsit/views/service_provider/service_provider_detail_screen.dart';
import 'package:hopetsit/views/service_provider/walker_detail_screen.dart';
import 'package:hopetsit/widgets/app_text.dart';
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
    with SingleTickerProviderStateMixin {
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
      _refreshBookings();
      if (Get.isRegistered<NotificationsController>()) {
        final notifs = Get.find<NotificationsController>();
        _notifWorker = ever<int>(notifs.unreadCount, (_) => _refreshBookings());
      }
      _periodicRefresh = Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted) _refreshBookings();
      });
    });
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
      final acceptedToPay = bookings.where((b) {
        final status = (b.status ?? '').toLowerCase();
        final pay    = (b.paymentStatus ?? '').toLowerCase();
        if (pay == 'paid') return false;
        // v23.1 — PART 2 : skip bookings the user dismissed via the X button.
        if (_dismissedIds.contains(b.id)) return false;
        return status == 'accepted' || status == 'agreed' || status == 'mutually_accepted';
      }).toList();

      if (acceptedToPay.isNotEmpty) {
        // v22.2 — Bug 16b : fallback "Le prestataire" si sitter.name vide
        // (cas où l'API ne populate pas le champ sitter/walker correctement).
        final b = acceptedToPay.first;
        final providerName = b.sitter.name.trim().isNotEmpty
            ? b.sitter.name
            : 'Le prestataire';
        final isWalker = (b.serviceType ?? '').toLowerCase().contains('walking');
        final extraCount = acceptedToPay.length - 1;
        final title = extraCount > 0
            ? '$providerName a accepté ! (+$extraCount autre${extraCount > 1 ? 's' : ''})'
            : '$providerName a accepté !';
        // Total agrégé si plusieurs bookings.
        double totalToPay = 0;
        String? aggCurrency;
        for (final bk in acceptedToPay) {
          final amt = (bk.pricing?.totalPrice ?? bk.totalAmount ?? 0).toDouble();
          totalToPay += amt;
          aggCurrency ??= bk.pricing?.currency ?? bk.sitter.currency;
        }
        final ctaLabel = extraCount > 0
            ? 'Tout payer ${CurrencyHelper.format(aggCurrency ?? 'EUR', totalToPay)}'
            : 'Payer ${CurrencyHelper.format(b.pricing?.currency ?? b.sitter.currency, (b.pricing?.totalPrice ?? b.totalAmount ?? 0).toDouble())}';
        return _QuickAction(
          kind: _Kind.ownerPay,
          color: isWalker ? const Color(0xFF4CAF50) : const Color(0xFF2196F3),
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
      // Lower priority — payment pending warning (orange).
      // (We don't model a deadline here, so just look for status=pending_payment.)
      for (final b in bookings) {
        final pay = (b.paymentStatus ?? '').toLowerCase();
        if (pay == 'pending_payment' || pay == 'requires_payment') {
          return _QuickAction(
            kind: _Kind.ownerPay,
            color: const Color(0xFFFF9800),
            icon: Icons.timer_rounded,
            title: 'Paiement en attente !',
            subtitle: 'Confirme ton paiement avant l\'expiration.',
            ctaLabel: 'Payer maintenant',
            booking: b,
            pulse: true,
          );
        }
      }
      return null;
    }

    // Priority 1 — a new booking request awaiting accept/refuse.
    for (final b in bookings) {
      final status = (b.status ?? '').toLowerCase();
      if (status == 'pending' || status == 'requested') {
        final isWalker = widget.role == 'walker';
        final estimated = (b.pricing?.netAmount ?? b.pricing?.basePrice ?? 0).toDouble();
        final ownerName = b.owner.name.isNotEmpty ? b.owner.name : '—';
        return _QuickAction(
          kind: _Kind.providerAccept,
          color: isWalker ? const Color(0xFF4CAF50) : const Color(0xFF2196F3),
          icon: Icons.notifications_active_rounded,
          title: 'Nouvelle demande !',
          subtitle: '$ownerName • ${b.petName} • ${_dateLabel(b)} → '
              '${CurrencyHelper.format(
                b.pricing?.currency ?? 'EUR',
                estimated,
              )} estimé',
          ctaLabel: '',
          booking: b,
          pulse: true,
        );
      }
    }

    // Priority 2 — payment received → confirmation banner.
    //
    // v23.1 part 44 — fix Daniel "walker reçoit Paiement reçu alors que
    // owner n'a pas payé". Root cause : the window was 24h on
    // `updatedAt`. `updatedAt` bumps on every mutation (status change,
    // agreement update, …) so a booking paid yesterday kept re-flashing
    // the banner today every time it was touched. The user could still
    // dismiss with the X but it kept reappearing.
    //
    // Fix : key off `paidAt` (the actual payment timestamp, set once at
    // confirmBookingPayment time and never moved) AND a tighter 1h
    // window. Bookings paid more than 1h ago no longer surface this
    // banner — the user can still find them under Mes Réservations.
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    const maxBannerAgeMs = 60 * 60 * 1000; // 1h
    for (final b in bookings) {
      final pay = (b.paymentStatus ?? '').toLowerCase();
      final st  = (b.status ?? '').toLowerCase();
      if (_dismissedIds.contains(b.id)) continue;
      if (pay != 'paid' || st == 'completed') continue;
      // Require a recent paidAt. If paidAt is missing (legacy bookings
      // from before part 44) we deliberately skip the banner rather
      // than fall back to updatedAt — the false-positive risk is too
      // high for a banner that says "Paiement reçu €X".
      final paidAtMs = DateTime.tryParse(b.paidAt ?? '')?.millisecondsSinceEpoch;
      if (paidAtMs == null) continue;
      if ((nowMs - paidAtMs) > maxBannerAgeMs) continue;

      final isWalker = widget.role == 'walker';
      final ownerName = b.owner.name.isNotEmpty ? b.owner.name : '—';
      return _QuickAction(
        kind: _Kind.providerPaid,
        color: isWalker ? const Color(0xFF4CAF50) : const Color(0xFF2196F3),
        icon: Icons.check_circle_rounded,
        title: 'Paiement reçu !',
        subtitle: '$ownerName a payé '
            '${CurrencyHelper.format(
              b.pricing?.currency ?? 'EUR',
              (b.pricing?.totalPrice ?? b.totalAmount ?? 0).toDouble(),
            )} • ${_dateLabel(b)}',
        ctaLabel: 'Voir détails',
        booking: b,
        pulse: false,
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
    // v21.1.1 — même si le controller n'est pas registered, on affiche le
    // neutral state (au lieu d'un SizedBox invisible). Daniel veut TOUJOURS
    // voir la barre sur les 3 home screens.
    if (rx == null) {
      return _NeutralBar(role: widget.role, onTap: _onNeutralTap);
    }

    return Obx(() {
      // v23.1 part 20 — owner banner now also reacts to ApplicationsController.
      // The walker/sitter sends an Application (NOT a Booking) when they tap
      // "Demander" on a publication. The Booking only exists *after* the owner
      // accepts. So if we only watch BookingsController for owner, the banner
      // stays on "Tout est à jour" — bug Daniel reported.
      _QuickAction? action = _pickAction(rx.toList());
      if (action == null && widget.role == 'owner') {
        action = _pickOwnerApplicationAction();
      }
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
                action.kind == _Kind.providerPaid)
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

  void _onNeutralTap() {
    // En l'absence d'action urgente, on emmène vers l'historique des bookings
    // (l'écran le plus utile pour comprendre l'état général).
    Get.to(() => const BookingsHistoryScreen());
  }

  // ─── Tap handlers (graceful degradation if a route is missing) ─────────

  void _onActionTap(_QuickAction a) {
    // v22.5 — PART 3 : owner pay banner court-circuite la chaîne
    //   Banner → BookingsHistory → BookingDetail → BookingAgreement → Payment
    // pour aller DIRECT à StripePaymentScreen.
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
    Get.to(() => const BookingsHistoryScreen());
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
                  width: 36.w, height: 4.h, margin: EdgeInsets.only(bottom: 12.h),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
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
                  text: 'Paiement reçu !',
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
                    backgroundImage: ownerAvatar.isNotEmpty
                        ? NetworkImage(ownerAvatar) : null,
                    child: ownerAvatar.isEmpty
                        ? Icon(Icons.person, color: accent, size: 22.sp)
                        : null,
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PoppinsText(
                          text: ownerName,
                          fontSize: 14.sp, fontWeight: FontWeight.w700,
                        ),
                        SizedBox(height: 2.h),
                        InterText(
                          text: 'role_pet_owner'.tr,
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
                    'Voir mes factures',
                    style: TextStyle(
                      color: Colors.white,
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
                    backgroundImage:
                        ownerAvatar.isNotEmpty ? NetworkImage(ownerAvatar) : null,
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
                    backgroundImage: providerAvatar.isNotEmpty
                        ? NetworkImage(providerAvatar)
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

  /// v23.1 part 22 — popup riche pour le profil walker (en attendant un
  /// WalkerDetailScreen public dédié qui appelle /walkers/:id).
  void _showWalkerInfoDialog(ApplicationModel app) {
    final accent = const Color(0xFF16A34A);
    final w = app.sitter; // ApplicationSitter contient les data walker quand providerRole='walker'
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        contentPadding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 12.h),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 28.r,
                    backgroundColor: accent.withValues(alpha: 0.15),
                    backgroundImage: w.avatar.url.isNotEmpty
                        ? NetworkImage(w.avatar.url)
                        : null,
                    child: w.avatar.url.isEmpty
                        ? Icon(Icons.person, color: accent, size: 28.sp)
                        : null,
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PoppinsText(
                          text: w.name.isNotEmpty ? w.name : 'role_walker'.tr,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                        ),
                        SizedBox(height: 4.h),
                        Row(
                          children: [
                            Icon(Icons.star_rounded,
                                color: const Color(0xFFFFB400), size: 16.sp),
                            SizedBox(width: 4.w),
                            InterText(
                              text: w.rating > 0
                                  ? '${w.rating.toStringAsFixed(1)} (${w.reviewsCount})'
                                  : '—',
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.h),
              if ((w.bio ?? '').isNotEmpty) ...[
                _sheetRow(Icons.info_outline, w.bio!),
              ],
              if (w.skills.isNotEmpty) _sheetRow(Icons.workspace_premium, w.skills),
              if ((w.city ?? '').isNotEmpty) _sheetRow(Icons.location_on_outlined, w.city!),
              if (w.address.isNotEmpty && w.address != w.city) _sheetRow(Icons.home_outlined, w.address),
              if (w.language.isNotEmpty) _sheetRow(Icons.language, w.language),
              if (w.hourlyRate > 0)
                _sheetRow(
                  Icons.payments_outlined,
                  '${CurrencyHelper.format(w.currency, w.hourlyRate)} / h',
                ),
              if (w.verified)
                _sheetRow(Icons.verified_outlined, 'verified'.tr.isNotEmpty
                    ? 'verified'.tr
                    : 'Vérifié'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'common_close'.tr.isNotEmpty ? 'common_close'.tr : 'Fermer',
              style: TextStyle(color: accent, fontWeight: FontWeight.w700),
            ),
          ),
        ],
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

  /// v22.5 — PART 3 : pre-warm createPaymentIntent puis push StripePaymentScreen.
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
        () => StripePaymentScreen(
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
    // v23.1 — bug #3 fix : really call POST /bookings/:id/respond instead of
    // navigating to the details screen. Same endpoint works for sitter AND
    // walker (no role middleware on the route).
    await _respondToBooking(a, 'accept');
  }

  Future<void> _onRefuse(_QuickAction a) async {
    // v23.1 — bug #2 fix : really call POST /bookings/:id/respond reject.
    await _respondToBooking(a, 'reject');
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
    }
  }

  void _dismissBanner(String bookingId) {
    _dismissBannerMulti(<String>[bookingId]);
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

enum _Kind { ownerPay, providerAccept, providerPaid, ownerCandidate }

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
  });
}

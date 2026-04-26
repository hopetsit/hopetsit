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
import 'package:hopetsit/controllers/bookings_controller.dart';
import 'package:hopetsit/controllers/notifications_controller.dart';
import 'package:hopetsit/controllers/sitter_bookings_controller.dart';
import 'package:hopetsit/controllers/walker_bookings_controller.dart';
import 'package:hopetsit/models/booking_model.dart';
import 'package:hopetsit/utils/currency_helper.dart';
import 'package:hopetsit/views/booking/bookings_history_screen.dart';
import 'package:hopetsit/widgets/app_text.dart';

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

  @override
  void initState() {
    super.initState();
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
    // Heuristic : show whenever paymentStatus = paid AND status is still
    // 'agreed' or 'paid' (we have no per-user "seen" flag, so the bar
    // disappears as soon as the booking moves to 'completed').
    for (final b in bookings) {
      final pay = (b.paymentStatus ?? '').toLowerCase();
      final st  = (b.status ?? '').toLowerCase();
      if (pay == 'paid' && st != 'completed') {
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
      final action = _pickAction(rx.toList());
      // Neutral fallback : rien d'urgent → barre soft "tout est à jour".
      if (action == null) {
        return _NeutralBar(role: widget.role, onTap: _onNeutralTap);
      }
      return _ActionBanner(
        action: action,
        pulse: _pulse,
        onTap: () => _onActionTap(action),
        onAccept: () => _onAccept(action),
        onRefuse: () => _onRefuse(action),
      );
    });
  }

  void _onNeutralTap() {
    // En l'absence d'action urgente, on emmène vers l'historique des bookings
    // (l'écran le plus utile pour comprendre l'état général).
    Get.to(() => const BookingsHistoryScreen());
  }

  // ─── Tap handlers (graceful degradation if a route is missing) ─────────

  void _onActionTap(_QuickAction a) {
    // Open the bookings history screen — the user picks the right booking
    // from there and proceeds (Pay / Accept / Refuse / View details). This
    // keeps the quick-action bar decoupled from the existing payment flow.
    Get.to(() => const BookingsHistoryScreen());
  }

  void _onAccept(_QuickAction a) {
    // Provider side accept — defer to the existing booking detail screen
    // which already exposes Accept/Refuse logic. This keeps the widget
    // free of API coupling.
    _onActionTap(a);
  }

  void _onRefuse(_QuickAction a) {
    _onActionTap(a);
  }
}

// ─── Banner widget ──────────────────────────────────────────────────────────

class _ActionBanner extends StatelessWidget {
  final _QuickAction action;
  final AnimationController pulse;
  final VoidCallback onTap;
  final VoidCallback onAccept;
  final VoidCallback onRefuse;

  const _ActionBanner({
    required this.action,
    required this.pulse,
    required this.onTap,
    required this.onAccept,
    required this.onRefuse,
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
        return 'Pas de demande en attente';
      case 'sitter':
        return 'Pas de demande en attente';
      case 'owner':
      default:
        return 'Tout est à jour';
    }
  }

  String _subtitle() {
    switch (role) {
      case 'walker':
        return 'Reste connecté pour les nouvelles demandes de balade';
      case 'sitter':
        return 'Reste connecté pour les nouvelles demandes de garde';
      case 'owner':
      default:
        return 'Aucune action en attente · découvre la PawMap';
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

enum _Kind { ownerPay, providerAccept, providerPaid }

class _QuickAction {
  final _Kind kind;
  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final String ctaLabel;
  final BookingModel booking;
  final bool pulse;
  const _QuickAction({
    required this.kind,
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.ctaLabel,
    required this.booking,
    required this.pulse,
  });
}


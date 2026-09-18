import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/auth_controller.dart';
import 'package:hopetsit/controllers/sitter_bookings_controller.dart';
import 'package:hopetsit/controllers/walker_bookings_controller.dart';
import 'package:hopetsit/models/booking_model.dart';
import 'package:hopetsit/utils/currency_helper.dart';
import 'package:hopetsit/utils/service_type_translator.dart';
import 'package:hopetsit/views/booking/widgets/booking_ui_kit.dart';
import 'package:hopetsit/views/pet_owner/payments/saved_cards_screen.dart';
import 'package:hopetsit/views/profile/widgets/profile_ui_kit.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:intl/intl.dart';

/// v18.8 — Historique des versements reçus par le provider (sitter ou walker).
/// Montre les bookings dont le payment est confirmé, avec date, owner, montant
/// net (80% du total) et statut de versement (held / paid). Peut être ouvert
/// depuis PaymentManagementScreen (sitter et walker).
///
/// v565 (point 28) — kit Profil / Réservations : total net en tête, états
/// chargement / vide / erreur avec « Réessayer », pastille de statut.
class ProviderPayoutHistoryScreen extends StatefulWidget {
  const ProviderPayoutHistoryScreen({super.key});

  @override
  State<ProviderPayoutHistoryScreen> createState() =>
      _ProviderPayoutHistoryScreenState();
}

class _ProviderPayoutHistoryScreenState
    extends State<ProviderPayoutHistoryScreen> {
  bool _loading = true;
  // v565 — état d'erreur explicite (avant : catch silencieux → « vide »).
  String? _error;
  List<BookingModel> _bookings = const [];

  Color get _accent => currentRoleAccent();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final role = Get.isRegistered<AuthController>()
          ? (Get.find<AuthController>().userRole.value ?? 'sitter').toLowerCase()
          : 'sitter';
      List<BookingModel> bookings;
      if (role == 'walker') {
        final ctrl = Get.isRegistered<WalkerBookingsController>()
            ? Get.find<WalkerBookingsController>()
            : Get.put(WalkerBookingsController());
        await ctrl.loadBookings();
        bookings = ctrl.bookings.toList();
      } else {
        final ctrl = Get.isRegistered<SitterBookingsController>()
            ? Get.find<SitterBookingsController>()
            : Get.put(SitterBookingsController());
        await ctrl.loadBookings();
        bookings = ctrl.bookings.toList();
      }
      if (!mounted) return;
      setState(() {
        _bookings = bookings.where((b) {
          final paid = (b.paymentStatus ?? '').toLowerCase() == 'paid' ||
              b.status.toLowerCase() == 'paid';
          return paid;
        }).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = paymentErrorMessage(e);
      });
    }
  }

  double get _totalNet => _bookings.fold<double>(0, (s, b) => s + _net(b));

  double _net(BookingModel booking) =>
      booking.pricing?.netAmount ??
      ((booking.totalAmount ?? booking.basePrice ?? 0) * 0.8);

  @override
  Widget build(BuildContext context) {
    final accent = _accent;
    return ProfileSubPageScaffold(
      title: 'payment_history_title'.tr,
      accent: accent,
      scroll: false,
      padding: EdgeInsets.zero,
      body: RefreshIndicator(
        color: accent,
        onRefresh: _load,
        child: _loading
            ? BookingLoadingList(accent: accent)
            : _error != null
                ? BookingErrorState(message: _error!, onRetry: _load)
                : _bookings.isEmpty
                    ? BookingEmptyState(
                        icon: Icons.receipt_long_rounded,
                        title: 'payment_history_empty'.tr,
                        subtitle: 'v565_pay_payout_hint'.tr,
                        accent: accent,
                      )
                    : ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 28.h),
                        children: [
                          _summaryCard(accent),
                          SizedBox(height: 14.h),
                          ProfileGroupCard(
                            children: _bookings.map(_buildTile).toList(),
                          ),
                        ],
                      ),
      ),
    );
  }

  Widget _summaryCard(Color accent) {
    final currency = _bookings.isNotEmpty
        ? (_bookings.first.pricing?.currency ?? _bookings.first.sitter.currency)
        : 'EUR';
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 18.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accent, accent.withValues(alpha: 0.78)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22.r),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InterText(
            text: '${'v565_pay_net_label'.tr} · ${'v565_pay_payments_count'.trParams({'count': _bookings.length.toString()})}',
            fontSize: 12.5.sp,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.92),
          ),
          SizedBox(height: 6.h),
          PoppinsText(
            text: CurrencyHelper.format(currency, _totalNet),
            fontSize: 30.sp,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _buildTile(BookingModel booking) {
    final currency =
        booking.pricing?.currency ?? booking.sitter.currency;
    final net = _net(booking);
    String createdDate = '';
    try {
      createdDate =
          DateFormat.yMMMd(Get.locale?.languageCode ?? 'fr')
              .format(DateTime.parse(booking.createdAt));
    } catch (_) {
      createdDate = booking.createdAt;
    }
    final service = translateServiceType(booking.serviceType);
    final subtitle = [
      if (service.isNotEmpty) service,
      if (createdDate.isNotEmpty) createdDate,
    ].join(' · ');

    return ProfileRow(
      icon: Icons.check_circle_rounded,
      color: const Color(0xFF16A34A),
      title: booking.owner.name.isNotEmpty
          ? booking.owner.name
          : booking.petName,
      subtitle: subtitle,
      showChevron: false,
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          PoppinsText(
            text: '+${CurrencyHelper.format(currency, net)}',
            fontSize: 14.sp,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF16A34A),
          ),
          BookingStatusChip(
            status: booking.status,
            paymentStatus: booking.paymentStatus,
            accent: _accent,
          ),
        ],
      ),
    );
  }
}

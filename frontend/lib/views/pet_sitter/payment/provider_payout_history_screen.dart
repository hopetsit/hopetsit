import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/auth_controller.dart';
import 'package:hopetsit/controllers/sitter_bookings_controller.dart';
import 'package:hopetsit/controllers/walker_bookings_controller.dart';
import 'package:hopetsit/models/booking_model.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/currency_helper.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:intl/intl.dart';

/// v18.8 — Historique des versements reçus par le provider (sitter ou walker).
/// Montre les bookings dont le payment est confirmé, avec date, owner, montant
/// net (80% du total) et statut de versement (held / paid). Peut être ouvert
/// depuis PaymentManagementScreen (sitter et walker).
class ProviderPayoutHistoryScreen extends StatefulWidget {
  const ProviderPayoutHistoryScreen({super.key});

  @override
  State<ProviderPayoutHistoryScreen> createState() =>
      _ProviderPayoutHistoryScreenState();
}

class _ProviderPayoutHistoryScreenState
    extends State<ProviderPayoutHistoryScreen> {
  bool _loading = true;
  List<BookingModel> _bookings = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
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
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      appBar: AppBar(
        backgroundColor: AppColors.appBar(context),
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: AppColors.primaryColor),
        leading: const BackButton(),
        title: PoppinsText(
          text: 'payment_history_title'.tr,
          fontSize: 18.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _bookings.isEmpty
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.w),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long_rounded,
                            size: 48.sp, color: AppColors.greyColor),
                        SizedBox(height: 12.h),
                        InterText(
                          text: 'payment_history_empty'.tr,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textSecondary(context),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: EdgeInsets.all(16.w),
                    itemCount: _bookings.length,
                    itemBuilder: (context, i) => _buildTile(_bookings[i]),
                  ),
                ),
    );
  }

  Widget _buildTile(BookingModel booking) {
    final currency =
        booking.pricing?.currency ?? booking.sitter.currency;
    final net = booking.pricing?.netAmount ??
        ((booking.totalAmount ?? booking.basePrice ?? 0) * 0.8);
    String createdDate = '';
    try {
      createdDate =
          DateFormat.yMMMd(Get.locale?.languageCode ?? 'fr')
              .format(DateTime.parse(booking.createdAt));
    } catch (_) {
      createdDate = booking.createdAt;
    }

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: AppColors.cardShadow(context),
      ),
      child: Row(
        children: [
          Container(
            width: 42.w,
            height: 42.w,
            decoration: BoxDecoration(
              color: Colors.teal.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(Icons.check_circle_rounded,
                size: 22.sp, color: Colors.teal),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PoppinsText(
                  text: booking.owner.name.isNotEmpty
                      ? booking.owner.name
                      : booking.petName,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2.h),
                InterText(
                  text: createdDate,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary(context),
                ),
              ],
            ),
          ),
          PoppinsText(
            text: CurrencyHelper.format(currency, net),
            fontSize: 14.sp,
            fontWeight: FontWeight.w700,
            color: Colors.teal,
          ),
        ],
      ),
    );
  }
}

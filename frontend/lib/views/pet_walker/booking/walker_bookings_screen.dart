import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/views/shared/handover_proof_sheet.dart';
import 'package:hopetsit/controllers/walker_bookings_controller.dart';
import 'package:hopetsit/models/booking_model.dart';
import 'package:hopetsit/repositories/walker_repository.dart';
import 'package:hopetsit/widgets/service_confirmation_card.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/booking_date_format.dart';
import 'package:hopetsit/widgets/app_text.dart';
// v23.1 — onglet Factures.
import 'package:hopetsit/views/invoices/invoices_screen.dart';

/// Walker bookings history screen.
///
/// Session v17 — created so walkers see the bookings the owners have
/// confirmed with them. Mirrors the visual structure of
/// `SitterBookingsScreen` but uses [WalkerBookingsController] which hits the
/// /bookings/my endpoint with the walker's auth token. Walker payment cards
/// use the walker accent green (#16A34A) — same colour as the post price
/// block in v16.3h and the PaymentPage in v17d.
class WalkerBookingsScreen extends StatefulWidget {
  const WalkerBookingsScreen({super.key});

  @override
  State<WalkerBookingsScreen> createState() => _WalkerBookingsScreenState();
}

class _WalkerBookingsScreenState extends State<WalkerBookingsScreen> {
  // Same colour as walker price-block in PetPostCard / PaymentPage v17d.
  static const Color _walkerAccent = Color(0xFF16A34A);
  // v23.1.265 — refresh auto silencieux toutes les 30s.
  Timer? _autoRefresh;

  // v23.1.260 — confirmation de service (côté walker).
  String? _busySvcId;

  Future<void> _onServiceStart(BookingModel booking) async {
    // v532 — preuve de remise : photo de l'animal + code a 4 chiffres
    // dicte par le proprietaire. Annuler la feuille annule l'action.
    final proof = await HandoverProofSheet.show(isPickup: true);
    if (proof == null) return;
    setState(() => _busySvcId = booking.id);
    try {
      await Get.find<WalkerRepository>().startService(
        bookingId: booking.id,
        photo: proof.photo,
        code: proof.code,
      );
      CustomSnackbar.showSuccess(
        title: 'service_started_snack_title'.tr,
        message: 'service_started_snack_msg'.tr,
      );
      await _bookingsController.loadBookings();
    } catch (e) {
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: e.toString().replaceAll('ApiException:', '').trim(),
      );
    } finally {
      if (mounted) setState(() => _busySvcId = null);
    }
  }

  Future<void> _onServiceComplete(BookingModel booking) async {
    // v532 — preuve de restitution : photo de l'animal rendu.
    final proof = await HandoverProofSheet.show(isPickup: false);
    if (proof == null) return;
    setState(() => _busySvcId = booking.id);
    try {
      await Get.find<WalkerRepository>().completeService(
        bookingId: booking.id,
        photo: proof.photo,
      );
      CustomSnackbar.showSuccess(
        title: 'service_completed_snack_title'.tr,
        message: 'service_completed_snack_msg'.tr,
      );
      await _bookingsController.loadBookings();
    } catch (e) {
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: e.toString().replaceAll('ApiException:', '').trim(),
      );
    } finally {
      if (mounted) setState(() => _busySvcId = null);
    }
  }

  late WalkerBookingsController _bookingsController;
  String _selectedStatus = 'all';

  // v23.1 — Tout / Remboursée / Payée + chip Factures (3 profils).
  final List<String> _statuses = const [
    'all',
    'refunded',
    'paid',
    'factures',
  ];

  @override
  void initState() {
    super.initState();
    _bookingsController = Get.put(WalkerBookingsController());
    // v23.1.265 — refresh auto toutes les 30s tant que l'écran est visible.
    _autoRefresh = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _bookingsController.loadBookings(silent: true);
    });
  }

  @override
  void dispose() {
    _autoRefresh?.cancel();
    super.dispose();
  }

  List<BookingModel> get _filteredBookings {
    if (_selectedStatus == 'all') {
      return _bookingsController.bookings;
    }
    // v23.1 part 28 — fix : 'paid' / 'refunded' sur paymentStatus.
    return _bookingsController.bookings.where((b) {
      final s = (b.status).toLowerCase();
      final p = (b.paymentStatus ?? '').toLowerCase();
      if (_selectedStatus == 'paid') return p == 'paid';
      if (_selectedStatus == 'refunded') return p == 'refunded' || s == 'refunded';
      return s == _selectedStatus;
    }).toList();
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
        iconTheme: const IconThemeData(color: _walkerAccent),
        title: PoppinsText(
          // Same key as sitter screen — title is generic.
          text: 'sitter_bookings_title'.tr,
          fontSize: 18.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary(context),
        ),
        // v23.1 — Factures déplacé en chip dans la barre de filtres.
      ),
      body: Column(
        children: [
          _buildStatusFilter(),
          Expanded(
            child: Obx(() {
              if (_bookingsController.isLoading.value) {
                return const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(_walkerAccent),
                  ),
                );
              }

              final list = _filteredBookings;
              if (list.isEmpty) {
                return Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.w),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_busy,
                            size: 64.sp, color: AppColors.greyColor),
                        SizedBox(height: 16.h),
                        InterText(
                          text: _selectedStatus == 'all'
                              ? 'sitter_bookings_empty_all'.tr
                              : 'sitter_bookings_empty_filtered'.trParams({
                                  'status': _label(_selectedStatus),
                                }),
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w400,
                          color: AppColors.greyColor,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }

              return RefreshIndicator(
                color: _walkerAccent,
                onRefresh: () => _bookingsController.loadBookings(
                  status: _selectedStatus == 'all' ? null : _selectedStatus,
                ),
                child: ListView.builder(
                  // v468 — dégage le bas au-dessus du menu pleine largeur
                  padding: EdgeInsets.fromLTRB(
                      20.w, 16.h, 20.w, 110.h + MediaQuery.of(context).viewPadding.bottom),
                  itemCount: list.length,
                  itemBuilder: (context, index) => _buildBookingCard(list[index]),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilter() {
    return Container(
      height: 50.h,
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        itemCount: _statuses.length,
        itemBuilder: (context, index) {
          final status = _statuses[index];
          final isSelected = _selectedStatus == status;
          return GestureDetector(
            onTap: () {
              // v23.1 — chip "Factures" navigue vers InvoicesScreen.
              if (status == 'factures') {
                Get.to(() => const InvoicesScreen());
                return;
              }
              setState(() => _selectedStatus = status);
              _bookingsController.loadBookings(
                status: status == 'all' ? null : status,
              );
            },
            child: Container(
              margin: EdgeInsets.only(right: 12.w),
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: isSelected ? _walkerAccent : AppColors.whiteColor,
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(
                  color: isSelected ? _walkerAccent : AppColors.grey300Color,
                ),
              ),
              child: Center(
                child: InterText(
                  text: _label(status),
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  color: isSelected
                      ? AppColors.whiteColor
                      : AppColors.grey700Color,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _label(String status) {
    switch (status) {
      case 'all':
        return 'status_all_label'.tr;
      case 'pending':
        return 'status_pending_label'.tr;
      case 'agreed':
        return 'status_agreed_label'.tr;
      case 'paid':
        return 'status_paid_label'.tr;
      case 'failed':
        return 'status_failed_label'.tr;
      case 'cancelled':
        return 'status_cancelled_label'.tr;
      case 'refunded':
        return 'status_refunded_label'.tr;
      case 'factures':
        return 'invoices_chip'.tr;
      default:
        return status.tr;
    }
  }

  Widget _buildBookingCard(BookingModel booking) {
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.all(16.w),
      // v465 — refonte : carte surélevée (ombre), coins 18, liseré vert rôle.
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: _walkerAccent.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _statusBadge(booking.status),
              const Spacer(),
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipOval(
                      child: booking.owner.avatar.url.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: booking.owner.avatar.url,
                              width: 32.w,
                              height: 32.h,
                              memCacheWidth: 96, // v234.
                              fit: BoxFit.cover,
                              placeholder: (_, __) => _avatarPlaceholder(),
                              errorWidget: (_, __, ___) => _avatarPlaceholder(),
                            )
                          : _avatarPlaceholder(),
                    ),
                    SizedBox(width: 8.w),
                    Flexible(
                      child: InterText(
                        text: booking.owner.name,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          _row(Icons.pets, 'sitter_bookings_pet_label'.tr, booking.petName),
          SizedBox(height: 12.h),
          // v18.9 — date + heure formatées selon la locale (plus d'ISO brut
          // "2026-04-24T00:00:00.000Z" ni "11:24 PM" en FR).
          _row(Icons.calendar_today,
              'sitter_bookings_date_label'.tr,
              BookingDateFormat.localizedDate(booking.date)),
          SizedBox(height: 12.h),
          _row(Icons.access_time,
              'sitter_bookings_time_label'.tr,
              BookingDateFormat.localizedTime(booking.timeSlot)),
          if (booking.duration != null && booking.duration! > 0) ...[
            SizedBox(height: 12.h),
            _row(Icons.timer, 'duration_label'.tr, '${booking.duration} min'),
          ],
          if (booking.totalAmount != null) ...[
            SizedBox(height: 12.h),
            // v18.9.2 — walker voit son montant NET perçu (80% après commission
            // plateforme) sur les réservations payées, pas le montant brut
            // que l'owner a payé.
            Builder(builder: (context) {
              final paid = (booking.paymentStatus ?? '').toLowerCase() == 'paid';
              final total = booking.totalAmount!;
              // v20.0.11 — commission is paid ON TOP by owner. Walker gets
              // the full basePrice. Fallback: basePrice, then total/1.20.
              final net = booking.pricing?.netAmount ??
                  booking.pricing?.basePrice ??
                  (total > 0 ? total / 1.20 : 0.0);
              final currency =
                  booking.pricing?.currency ?? booking.sitter.currency;
              return Row(
                children: [
                  Icon(Icons.attach_money, size: 16.sp, color: _walkerAccent),
                  SizedBox(width: 8.w),
                  InterText(
                    text: paid
                        ? 'bookings_card_you_receive'.trParams({
                            'amount':
                                '${net.toStringAsFixed(2)} $currency',
                          })
                        : '${total.toStringAsFixed(2)} $currency',
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: _walkerAccent,
                  ),
                ],
              );
            }),
          ],
          // v23.1.161 — Daniel : "dans reservation il manque le bouton
          // annuler apres 72h le client ou sitter ne peux annuler dc
          // verifier les 3 profile". Walker n'avait AUCUN bouton annuler
          // — ajout du bouton self-cancel pour bookings payes >72h avant
          // le service. Calls selfCancelBooking endpoint qui refund
          // l'owner integralement et bloque le payout futur du walker.
          // v23.1.256 — bouton visible pour TOUTE résa payée (aligné détail) ;
          // le dialogue gère gratuit (>72h) vs fenêtre fermée. Avant : gaté
          // >72h → caché pour résas proches → "pas revenu sur aucun profil".
          if (booking.paymentStatus?.toLowerCase() == 'paid' &&
              booking.status.toLowerCase() != 'cancelled' &&
              booking.status.toLowerCase() != 'completed' &&
              booking.status.toLowerCase() != 'refunded') ...[
            SizedBox(height: 12.h),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _confirmSelfCancel(booking),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 10.h),
                  side: const BorderSide(color: Color(0xFFDC2626), width: 1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                child: InterText(
                  text: 'cancel_72h_button'.tr,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFFDC2626),
                ),
              ),
            ),
          ],
          // v23.1.260 — carte de confirmation de service dans la liste walker.
          if ((booking.paymentStatus?.toLowerCase() == 'paid') &&
              booking.status.toLowerCase() != 'cancelled' &&
              booking.status.toLowerCase() != 'refunded')
            ServiceConfirmationCard(
              confirmationStatus: booking.confirmationStatus,
              role: 'walker',
              isPaid: true,
              busy: _busySvcId == booking.id,
              onStart: () => _onServiceStart(booking),
              onComplete: () => _onServiceComplete(booking),
            ),
        ],
      ),
    );
  }

  /// v23.1.161 — true si le booking est a plus de 72h du service (fenetre
  /// self-cancel avec refund integral).
  bool _isWithinSelfCancelWindow(BookingModel booking) {
    // v462 — délègue au getter autoritaire du modèle (backend canSelfCancel +
    // filet local). Plus de divergence frontend/backend.
    return booking.isSelfCancelEligible;
  }

  Future<void> _confirmSelfCancel(BookingModel booking) async {
    // v23.1.256 — annulation gratuite seulement si >72h (règle backend) ;
    // sinon message "fenêtre fermée" sans bouton confirmer.
    final canFree = _isWithinSelfCancelWindow(booking);
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: Text('cancel_72h_dialog_title'.tr),
        content: Text(
          canFree
              ? 'cancel_72h_dialog_message'.tr
              : 'cancel_72h_closed_message'.tr,
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text(canFree ? 'common_cancel'.tr : 'common_ok'.tr),
          ),
          if (canFree)
            ElevatedButton(
              onPressed: () => Get.back(result: true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
              ),
              child: Text('cancel_72h_dialog_confirm'.tr),
            ),
        ],
      ),
    );
    if (confirmed == true && canFree) {
      await Get.find<WalkerBookingsController>()
          .selfCancelBooking(bookingId: booking.id);
    }
  }

  Widget _statusBadge(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'paid':
        color = _walkerAccent;
        break;
      case 'pending':
        color = const Color(0xFFF59E0B);
        break;
      case 'agreed':
      case 'accepted':
        color = const Color(0xFF3B82F6);
        break;
      case 'cancelled':
      case 'rejected':
      case 'refunded':
      case 'payment_failed':
        color = const Color(0xFFEF4444);
        break;
      default:
        color = AppColors.greyColor;
    }
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: InterText(
        text: _label(status),
        fontSize: 11.sp,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16.sp, color: AppColors.grey700Color),
        SizedBox(width: 8.w),
        InterText(
          text: label,
          fontSize: 12.sp,
          fontWeight: FontWeight.w400,
          color: AppColors.grey700Color,
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: InterText(
            text: value,
            fontSize: 12.sp,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary(context),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _avatarPlaceholder() {
    return Container(
      width: 32.w,
      height: 32.h,
      color: AppColors.lightGrey,
      child: Icon(Icons.person, size: 20.sp, color: _walkerAccent),
    );
  }
}

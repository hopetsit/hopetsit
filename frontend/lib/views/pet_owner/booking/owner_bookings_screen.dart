import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:hopetsit/controllers/bookings_controller.dart';
import 'package:hopetsit/models/booking_model.dart';
import 'package:hopetsit/views/reviews/reviews_screen.dart';
import 'package:hopetsit/repositories/owner_repository.dart';
import 'package:hopetsit/widgets/service_confirmation_card.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/booking_date_format.dart';
import 'package:hopetsit/utils/currency_helper.dart';
import 'package:hopetsit/views/booking/booking_agreement_screen.dart';
import 'package:hopetsit/views/payment/airwallex_payment_screen.dart';
// v23.1 — onglet Factures auto-générées.
import 'package:hopetsit/views/invoices/invoices_screen.dart';
import 'package:hopetsit/widgets/app_text.dart';

/// v18.9 — "Mes réservations" côté Owner, clone du design walker/sitter
/// (cartes compactes + filter chips) avec l'accent ORANGE du rôle owner.
/// Daniel : "ce design de reservation je le veux pareil pour le profil
/// owner et petsitter en respectant role et couleur".
class OwnerBookingsScreen extends StatefulWidget {
  const OwnerBookingsScreen({super.key});

  @override
  State<OwnerBookingsScreen> createState() => _OwnerBookingsScreenState();
}

class _OwnerBookingsScreenState extends State<OwnerBookingsScreen> {
  static const Color _ownerAccent = Color(0xFFEF4324);

  late BookingsController _bookingsController;
  String _selectedStatus = 'all';
  // v23.1.260 — id du booking dont l'action confirmation est en cours.
  String? _busySvcId;
  // v23.1.265 — Daniel : "les pages réservation se mettent à jour toutes les
  // 30s". Rafraîchissement de fond silencieux (pas de spinner).
  Timer? _autoRefresh;

  Future<void> _onServiceConfirm(BookingModel booking) async {
    setState(() => _busySvcId = booking.id);
    try {
      await Get.find<OwnerRepository>().confirmService(bookingId: booking.id);
      CustomSnackbar.showSuccess(
        title: 'service_confirmed_snack_title'.tr,
        message: 'service_confirmed_snack_msg'.tr,
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

  Future<void> _onServiceDispute(BookingModel booking) async {
    setState(() => _busySvcId = booking.id);
    try {
      await Get.find<OwnerRepository>().disputeService(bookingId: booking.id);
      CustomSnackbar.showWarning(
        title: 'service_disputed_snack_title'.tr,
        message: 'service_disputed_snack_msg'.tr,
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

  // v23.1 — simplifié par Daniel : Tout / Remboursée / Payée + chip Factures
  // qui navigue vers InvoicesScreen (au lieu d'une icône à part dans l'AppBar).
  final List<String> _statuses = const [
    'all',
    'refunded',
    'paid',
    'factures',
  ];

  @override
  void initState() {
    super.initState();
    _bookingsController = Get.isRegistered<BookingsController>()
        ? Get.find<BookingsController>()
        : Get.put(BookingsController());
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
    // v23.1 part 28 — fix : 'refunded' et 'paid' sont sur paymentStatus,
    // PAS status. Sans cette correction, les chips ne filtrer que les
    // bookings dont le workflow status matche, ce qui rate les bookings
    // payées (status='agreed' + paymentStatus='paid') et remboursées.
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
      // v23.1 part 27 — was AppColors.scaffold (#F7F7F8 grey) → blanc.
      // Le grey transparaissait derrière la pill nav bar floating et créait
      // l'illusion d'un "rectangle gris" en bas.
      backgroundColor: AppColors.appBar(context),
      appBar: AppBar(
        backgroundColor: AppColors.appBar(context),
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: _ownerAccent),
        title: PoppinsText(
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
                    valueColor:
                        AlwaysStoppedAnimation<Color>(_ownerAccent),
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
                color: _ownerAccent,
                onRefresh: () => _bookingsController.loadBookings(),
                child: ListView.builder(
                  padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 20.h),
                  itemCount: list.length,
                  itemBuilder: (context, index) =>
                      _buildBookingCard(list[index]),
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
            },
            child: Container(
              margin: EdgeInsets.only(right: 12.w),
              padding:
                  EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: isSelected ? _ownerAccent : AppColors.whiteColor,
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(
                  color: isSelected
                      ? _ownerAccent
                      : AppColors.grey300Color,
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
    final totalAmount = booking.totalAmount ??
        booking.pricing?.totalPrice ??
        booking.basePrice;
    return GestureDetector(
      onTap: () {
        Get.to(() => BookingAgreementScreen(booking: booking));
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 16.h),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: AppColors.grey300Color),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _statusBadge(booking.status, booking.paymentStatus),
                const Spacer(),
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipOval(
                        child: booking.sitter.avatar.url.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: booking.sitter.avatar.url,
                                width: 32.w,
                                height: 32.h,
                                memCacheWidth: 96, // v234.
                                fit: BoxFit.cover,
                                placeholder: (_, __) => _avatarPlaceholder(),
                                errorWidget: (_, __, ___) =>
                                    _avatarPlaceholder(),
                              )
                            : _avatarPlaceholder(),
                      ),
                      SizedBox(width: 8.w),
                      Flexible(
                        child: InterText(
                          text: booking.sitter.name,
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
            _row(Icons.pets, 'sitter_bookings_pet_label'.tr,
                booking.petName),
            SizedBox(height: 12.h),
            _row(Icons.calendar_today, 'sitter_bookings_date_label'.tr,
                BookingDateFormat.localizedDate(booking.date)),
            SizedBox(height: 12.h),
            _row(Icons.access_time, 'sitter_bookings_time_label'.tr,
                BookingDateFormat.localizedTime(booking.timeSlot)),
            if (booking.duration != null && booking.duration! > 0) ...[
              SizedBox(height: 12.h),
              _row(Icons.timer, 'duration_label'.tr,
                  '${booking.duration} min'),
            ],
            if (totalAmount != null) ...[
              SizedBox(height: 12.h),
              // v18.9.2 — owner sur booking payé voit "Tu as payé €X".
              Builder(builder: (_) {
                final paid =
                    (booking.paymentStatus ?? '').toLowerCase() == 'paid';
                final formatted = CurrencyHelper.format(
                  booking.pricing?.currency ?? booking.sitter.currency,
                  totalAmount,
                );
                return Row(
                  children: [
                    Icon(Icons.attach_money, size: 16.sp, color: _ownerAccent),
                    SizedBox(width: 8.w),
                    InterText(
                      text: paid
                          ? 'bookings_card_you_paid'.trParams({
                              'amount': formatted,
                            })
                          : formatted,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: _ownerAccent,
                    ),
                  ],
                );
              }),
            ],
            SizedBox(height: 16.h),
            _buildActionButtons(booking),
            // v23.1.260 — carte de confirmation de service directement dans
            // la liste (avant elle n'était que sur l'écran détail → "elle
            // n'apparaît pas"). Visible pour les résas payées.
            if ((booking.paymentStatus?.toLowerCase() == 'paid') &&
                booking.status.toLowerCase() != 'cancelled' &&
                booking.status.toLowerCase() != 'refunded')
              ServiceConfirmationCard(
                confirmationStatus: booking.confirmationStatus,
                role: 'owner',
                isPaid: true,
                busy: _busySvcId == booking.id,
                onConfirm: () => _onServiceConfirm(booking),
                onDispute: () => _onServiceDispute(booking),
              ),
            // v23.1.291 — Daniel : note inline directement sur la carte une
            // fois le service confirmé/terminé (maquette owner). Taper une
            // étoile ou le lien ouvre l'écran d'avis (note pré-sélectionnée).
            if (booking.confirmationStatus == 'confirmed' ||
                booking.status.toLowerCase() == 'completed')
              _buildReviewPrompt(booking),
          ],
        ),
      ),
    );
  }

  // v23.1.291 — carte de note inline (maquette owner) : « Comment s'est passé
  // le service ? » + 5 étoiles tappables + lien « Noter le prestataire ». Taper
  // ouvre l'écran d'avis (qui gère création OU édition si déjà noté), avec la
  // note pré-sélectionnée selon l'étoile touchée.
  Widget _buildReviewPrompt(BookingModel booking) {
    final serviceLower = (booking.serviceType ?? '').toLowerCase();
    final resolvedRole = (serviceLower.contains('walking') ||
            serviceLower.contains('dog_walking'))
        ? 'walker'
        : 'sitter';
    void openReview(int rating) {
      Get.to(
        () => ReviewsScreen(
          serviceProviderName: booking.sitter.name,
          phoneNumber: booking.sitter.mobile,
          email: booking.sitter.email,
          profileImagePath: booking.sitter.avatar.url.isNotEmpty
              ? booking.sitter.avatar.url
              : null,
          serviceProviderId: booking.sitter.id,
          bookingId: booking.id,
          revieweeRole: resolvedRole,
          initialRating: rating,
        ),
      );
    }

    return Container(
      margin: EdgeInsets.only(top: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4EF),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: const Color(0xFFFFD9CC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PoppinsText(
            text: 'review_prompt_title'.tr,
            fontSize: 14.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary(context),
          ),
          SizedBox(height: 10.h),
          Row(
            children: List.generate(5, (i) {
              return GestureDetector(
                onTap: () => openReview(i + 1),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: EdgeInsets.only(right: 8.w),
                  child: Icon(
                    Icons.star_rounded,
                    size: 34.sp,
                    color: AppColors.grey300Color,
                  ),
                ),
              );
            }),
          ),
          SizedBox(height: 10.h),
          GestureDetector(
            onTap: () => openReview(0),
            behavior: HitTestBehavior.opaque,
            child: InterText(
              text: 'review_prompt_cta'.tr,
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  /// v23.1.161 — Daniel : "dans reservation il manque le bouton annuler
  /// apres 72h le client ou sitter ne peux annuler". Helper qui retourne
  /// true si le booking est dans la fenetre 72h+ (donc annulable avec
  /// refund integral).
  bool _isWithinSelfCancelWindow(BookingModel booking) {
    final dateStr = booking.date.trim();
    if (dateStr.isEmpty) return false;
    try {
      // booking.date est typiquement "yyyy-MM-dd" ou "dd/MM/yyyy".
      final parsed = DateTime.tryParse(dateStr) ??
          DateFormat('dd/MM/yyyy').tryParse(dateStr);
      if (parsed == null) return false;
      final hoursUntilStart = parsed.difference(DateTime.now()).inHours;
      return hoursUntilStart > 72;
    } catch (_) {
      return false;
    }
  }

  Future<void> _confirmSelfCancel(BookingModel booking) async {
    // v23.1.256 — dialogue adaptatif : annulation gratuite uniquement si
    // >72h avant le service (règle backend selfCancelWithRefund). Si on est
    // dans les 72h, on affiche le message "fenêtre fermée" SANS bouton
    // confirmer (le backend rejetterait de toute façon un self-cancel <72h).
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
      await _bookingsController.selfCancelBooking(bookingId: booking.id);
    }
  }

  Widget _buildActionButtons(BookingModel booking) {
    final statusLower = booking.status.toLowerCase();
    final paymentStatusLower = booking.paymentStatus?.toLowerCase();
    final isEligibleForPayment = (statusLower == 'agreed' ||
            statusLower == 'accepted' ||
            statusLower == 'confirmed') &&
        (paymentStatusLower == null ||
            paymentStatusLower.isEmpty ||
            paymentStatusLower != 'paid');

    // v23.1.256 — Daniel : "le bouton annulation 72h n'est revenu sur AUCUN
    // profil". Cause racine : la liste gâtait le bouton sur
    // _isWithinSelfCancelWindow (>72h) ET sur le parsing de booking.date —
    // donc pour une résa proche (<72h) OU si la date ne se parse pas, le
    // bouton disparaissait TOTALEMENT. On aligne sur l'écran DÉTAIL qui le
    // montre pour toute résa payée : ici le bouton s'affiche dès que la résa
    // est payée et non annulée/terminée/remboursée ; le dialogue
    // (_confirmSelfCancel) adapte ensuite (gratuit si >72h, sinon message
    // "fenêtre d'annulation gratuite fermée").
    final isCancellable = paymentStatusLower == 'paid' &&
        statusLower != 'cancelled' &&
        statusLower != 'completed' &&
        statusLower != 'refunded';

    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              Get.to(() => BookingAgreementScreen(booking: booking));
            },
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 10.h),
              side: const BorderSide(color: _ownerAccent, width: 1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
            ),
            child: InterText(
              text: 'bookings_action_view_details'.tr,
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              color: _ownerAccent,
            ),
          ),
        ),
        if (isEligibleForPayment) ...[
          SizedBox(width: 12.w),
          Expanded(
            child: ElevatedButton(
              onPressed: () async {
                final pricing = booking.pricing;
                final base = (pricing?.totalPrice ??
                        pricing?.resolvedBaseAmount ??
                        booking.totalAmount ??
                        booking.basePrice) ??
                    0.0;
                final serviceLower =
                    (booking.serviceType ?? '').toLowerCase();
                final providerType = serviceLower.contains('walking') ||
                        serviceLower.contains('dog_walking')
                    ? 'walker'
                    : 'sitter';
                await Get.to(
                  () => AirwallexPaymentScreen(
                    booking: booking,
                    totalAmount: base,
                    currency:
                        pricing?.currency ?? booking.sitter.currency,
                    providerType: providerType,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _ownerAccent,
                padding: EdgeInsets.symmetric(vertical: 10.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
              child: InterText(
                text: 'service_card_pay_now'.tr,
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
                color: AppColors.whiteColor,
              ),
            ),
          ),
        ],
        // v23.1.161 — Bouton "Annuler" pour reservations payees a >72h.
        if (isCancellable) ...[
          SizedBox(width: 12.w),
          Expanded(
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
      ],
    );
  }

  Widget _statusBadge(String status, String? paymentStatus) {
    final statusLower = status.toLowerCase();
    final paymentLower = paymentStatus?.toLowerCase();
    String primary;
    if (paymentLower == 'paid') {
      primary = 'paid';
    } else if (paymentLower == 'failed') {
      primary = 'failed';
    } else {
      primary = statusLower;
    }

    Color color;
    switch (primary) {
      case 'paid':
        color = const Color(0xFF16A34A);
        break;
      case 'pending':
        color = const Color(0xFFF59E0B);
        break;
      case 'agreed':
      case 'accepted':
        color = _ownerAccent;
        break;
      case 'cancelled':
      case 'rejected':
      case 'refunded':
      case 'failed':
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
        text: _label(primary),
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
            text: value.isNotEmpty ? value : '—',
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
      child: Icon(Icons.person, size: 20.sp, color: _ownerAccent),
    );
  }
}

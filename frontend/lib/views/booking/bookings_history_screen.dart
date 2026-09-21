import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/bookings_controller.dart';
import 'package:hopetsit/models/booking_model.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/booking_date_format.dart';
import 'package:hopetsit/utils/currency_helper.dart';
import 'package:hopetsit/utils/service_type_translator.dart';
import 'package:hopetsit/widgets/action_banner_kit.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/paw_pattern_background.dart';
import 'package:hopetsit/views/booking/widgets/booking_ui_kit.dart';
import 'package:hopetsit/widgets/custom_confirmation_dialog.dart';
// v575 — audit P0-2 : feuille commune d'annulation < 72 h avec remboursement.
import 'package:hopetsit/widgets/cancel_72h_sheet.dart';
import 'package:hopetsit/views/booking/booking_agreement_screen.dart';
import 'package:hopetsit/views/reviews/reviews_screen.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/utils/storage_keys.dart';
import 'package:hopetsit/utils/bottom_inset.dart';

// v573 — les dates/heures passent par `BookingDateFormat`, le formateur
// partagé par les pages Réservations des 3 rôles (avant : deux helpers
// locaux qui rendaient « lun. 28 avr. 2026 » au lieu de « lun., 28 avr.
// 2026 » — même information, mise en forme différente d'un écran à l'autre).

class BookingsHistoryScreen extends StatefulWidget {
  const BookingsHistoryScreen({super.key});

  @override
  State<BookingsHistoryScreen> createState() => _BookingsHistoryScreenState();
}

class _BookingsHistoryScreenState extends State<BookingsHistoryScreen> {
  late BookingsController _bookingsController;
  String? _selectedStatus;

  // All available statuses
  final List<String> _statuses = [
    'all',
    'pending',
    'agreed',
    'paid',
    'failed',
    'cancelled',
    'refunded',
  ];

  @override
  void initState() {
    super.initState();
    _bookingsController = Get.put(BookingsController());
    _selectedStatus = 'all';
  }

  List<BookingModel> get _filteredBookings {
    if (_selectedStatus == 'all') {
      return _bookingsController.bookings;
    }
    return _bookingsController.bookings.where((booking) {
      final s = booking.status.toLowerCase();
      final p = (booking.paymentStatus ?? '').toLowerCase();
      switch (_selectedStatus) {
        case 'pending':
          return s == 'pending' || s == 'requested';
        case 'agreed':
          // 'Acceptée' label covers accepted / agreed / mutually_accepted
          // / confirmed (any provider-accepted state) but NOT yet paid.
          return (s == 'accepted' ||
                  s == 'agreed' ||
                  s == 'mutually_accepted' ||
                  s == 'confirmed') &&
              p != 'paid';
        case 'paid':
          // 'Payée' tab keys off paymentStatus, not booking status.
          return p == 'paid';
        case 'failed':
          return p == 'failed' || p == 'payment_failed' || s == 'payment_failed';
        case 'cancelled':
          return s == 'cancelled' || p == 'cancelled' || s == 'rejected';
        case 'refunded':
          return p == 'refunded';
        default:
          return s == _selectedStatus;
      }
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
        iconTheme: IconThemeData(color: AppColors.primaryColor),
        leading: BackButton(),
        title: PoppinsText(
          text: 'bookings_history_title'.tr,
          fontSize: 18.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary(context),
        ),
      ),
      // v573 — même fond à petites pattes que les pages Réservations des
      // 3 rôles (Daniel : « le fond est tout blanc, sans patte »).
      body: PawPatternBackground(
        color: AppColors.primaryColor,
        child: Column(
        children: [
          // Status Filter Chips
          _buildStatusFilter(),

          // Bookings List
          Expanded(
            child: Obx(() {
              if (_bookingsController.isLoading.value &&
                  _bookingsController.bookings.isEmpty) {
                return BookingLoadingList(accent: AppColors.primaryColor);
              }
              // v565 — état d'erreur lisible (liste vide + erreur réseau).
              if (_bookingsController.lastError.value.isNotEmpty &&
                  _bookingsController.bookings.isEmpty) {
                return BookingErrorState(
                  message: _bookingsController.lastError.value,
                  onRetry: () => _bookingsController.loadBookings(),
                );
              }

              final filteredBookings = _filteredBookings;

              if (filteredBookings.isEmpty) {
                return RefreshIndicator(
                  color: AppColors.primaryColor,
                  onRefresh: () => _bookingsController.loadBookings(),
                  child: BookingEmptyState(
                    icon: Icons.event_note_rounded,
                    accent: AppColors.primaryColor,
                    title: _selectedStatus == 'all'
                        ? 'bookings_history_empty_all'.tr
                        : 'bookings_history_empty_filtered'.trParams({
                            'status': _getStatusLabel(_selectedStatus!),
                          }),
                    subtitle: 'v565_bk_empty_hint'.tr,
                  ),
                );
              }

              return RefreshIndicator(
                color: AppColors.primaryColor,
                onRefresh: () => _bookingsController.loadBookings(),
                child: ListView.builder(
                  // v569 — dernière réservation au-dessus de la barre.
                  padding: EdgeInsets.fromLTRB(
                      20.w, 16.h, 20.w, 20.h + appBottomInset(context)),
                  itemCount: filteredBookings.length,
                  itemBuilder: (context, index) {
                    final booking = filteredBookings[index];
                    return _buildBookingCard(booking);
                  },
                ),
              );
            }),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildStatusFilter() {
    // v565 — filtres en pilules (kit Réservations).
    return BookingFilterBar(
      values: _statuses,
      selected: _selectedStatus ?? 'all',
      label: _getStatusLabel,
      accent: AppColors.primaryColor,
      onSelected: (status) {
        setState(() {
          _selectedStatus = status;
        });
      },
    );
  }

  String _getStatusLabel(String status) {
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
      default:
        return status.tr;
    }
  }

  /// v18.6 — couleur d'accent du rôle (vert promeneur / bleu gardien / rouge
  /// propriétaire). Règle INCHANGÉE : elle est seulement remontée au niveau de
  /// la carte pour que l'avatar, les pastilles et les boutons s'accordent.
  Color _roleAccent(BookingModel booking) {
    final serviceLower = (booking.serviceType ?? '').toLowerCase();
    if (serviceLower.contains('dog_walking') ||
        serviceLower.contains('walking')) {
      return const Color(0xFF16A34A);
    }
    if (serviceLower.contains('sitting') ||
        serviceLower.contains('day_care') ||
        serviceLower.contains('boarding')) {
      return const Color(0xFF2563EB);
    }
    return AppColors.primaryColor;
  }

  Widget _buildBookingCard(BookingModel booking) {
    // v573 — la carte est reconstruite avec les widgets PUBLICS du kit
    // Réservations (`booking_ui_kit.dart`) : elle est désormais identique à
    // celles des pages Réservations des 3 rôles (coins 20, fond
    // `AppColors.card`, liseré et ombre du thème, méta-données en pastilles,
    // prix lisible). Avant : coins 12, `grey300Color` en dur, aucune ombre et
    // trois `AppColors.lightGrey` illisibles en mode sombre.
    // Aucune donnée, aucune condition et aucune navigation ne changent.
    final Color accent = _roleAccent(booking);
    final String service = translateServiceType(booking.serviceType);
    final bool paid = (booking.paymentStatus ?? '').toLowerCase() == 'paid';
    final String amount = CurrencyHelper.format(
      booking.pricing?.currency ?? booking.sitter.currency,
      booking.pricing?.totalPrice ??
          booking.totalAmount ??
          booking.pricing?.basePrice ??
          booking.sitter.hourlyRate,
    );

    return BookingCard(
      accent: accent,
      margin: EdgeInsets.only(bottom: 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BookingPartyHeader(
            name: booking.sitter.name,
            avatarUrl: booking.sitter.avatar.url,
            subtitle: service.isNotEmpty ? service : null,
            accent: accent,
            trailing: BookingStatusChip(
              status: booking.status,
              paymentStatus: booking.paymentStatus,
              accent: accent,
            ),
          ),
          SizedBox(height: 14.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: [
              BookingMetaChip(
                icon: Icons.pets_rounded,
                value: booking.petName,
                semanticsLabel: 'bookings_detail_pet_label'.tr,
                tint: accent,
              ),
              BookingMetaChip(
                icon: Icons.calendar_today_rounded,
                value: BookingDateFormat.localizedDate(booking.date),
                semanticsLabel: 'bookings_detail_date_label'.tr,
              ),
              BookingMetaChip(
                icon: Icons.access_time_rounded,
                value: BookingDateFormat.localizedTime(booking.timeSlot),
                semanticsLabel: 'bookings_detail_time_label'.tr,
              ),
            ],
          ),
          const BookingCardDivider(),
          BookingPriceRow(
            accent: accent,
            icon: paid ? Icons.verified_rounded : Icons.credit_card_rounded,
            caption: 'bookings_detail_total_amount_label'.tr,
            amount: amount,
          ),
          // v18.8 — design unifié sur les 3 rôles (walker/sitter/owner).
          // On supprime les lignes téléphone / localisation / notation dans
          // la card liste : elles polluaient le rendu avec "****1982" et
          // "Aucun lieu disponible" pour les bookings walker. Ces infos
          // restent accessibles dans BookingAgreementScreen (détail).

          if (booking.description.isNotEmpty) ...[
            SizedBox(height: 12.h),
            _buildDescription(accent, booking.description),
          ],

          SizedBox(height: 16.h),

          // Action Buttons
          _buildActionButtons(booking, accent),
        ],
      ),
    );
  }

  Widget _buildDescription(Color accent, String description) {
    // v573 — encart teinté à la couleur du rôle (avant : même fond que la
    // carte, donc invisible).
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.divider(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InterText(
            text: 'bookings_detail_description_label'.tr,
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary(context),
          ),
          SizedBox(height: 4.h),
          InterText(
            text: description,
            fontSize: 12.5.sp,
            fontWeight: FontWeight.w400,
            color: AppColors.textPrimary(context),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BookingModel booking, Color roleAccent) {
    final statusLower = booking.status.toLowerCase();
    final paymentStatusLower = booking.paymentStatus?.toLowerCase();

    // v573 — mêmes conditions, mêmes appels, mêmes navigations : seul
    // l'habillage change (`ActionPillButton` du kit). « Payer » reste
    // l'action principale, « Voir détails » passe en contour, et les actions
    // secondaires descendent sur leur propre ligne — trois boutons côte à
    // côte tronquaient les libellés allemands et polonais.
    // v23.1 — le bouton « Payer » ne doit apparaître QUE pour le rôle
    // propriétaire (sinon 403 au tap côté gardien/promeneur).
    // v22.4 — Bug B1 : il s'affiche dès que la réservation est
    // acceptée/confirmée et non encore payée.
    final bool showPay = ((GetStorage().read<String>(StorageKeys.userRole) ??
                    '')
                .toLowerCase() ==
            'owner') &&
        (statusLower == 'accepted' ||
            statusLower == 'agreed' ||
            statusLower == 'mutually_accepted' ||
            statusLower == 'confirmed') &&
        paymentStatusLower != 'paid';
    // v575 — audit P0-2 : une réservation PAYÉE s'annule uniquement par le
    // parcours « annulation < 72 h avec remboursement » (celui des pages
    // Réservations). L'annulation simple ne remboursait RIEN.
    final bool isPaidBooking = paymentStatusLower == 'paid';
    final bool isCancellablePaid = isPaidBooking &&
        statusLower != 'cancelled' &&
        statusLower != 'completed' &&
        statusLower != 'refunded';
    final bool showCancel = isCancellablePaid ||
        statusLower == 'pending' ||
        statusLower == 'agreed';
    // v18.5 — #22 / v23.1.290 : « Laisser un avis » sur les réservations
    // terminées OU confirmées (le flux v259 laisse status == 'paid').
    final bool showReview = statusLower == 'completed' ||
        booking.confirmationStatus == 'confirmed';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: ActionPillButton(
                label: 'bookings_action_view_details'.tr,
                icon: Icons.receipt_long_outlined,
                tone: roleAccent,
                kind: ActionPillKind.outlined,
                expand: true,
                onPressed: () {
                  Get.to(() => BookingAgreementScreen(booking: booking));
                },
              ),
            ),
            if (showPay) ...[
              SizedBox(width: 10.w),
              Expanded(
                child: ActionPillButton(
                  label: 'service_card_pay_now'.tr,
                  icon: Icons.credit_card_rounded,
                  tone: roleAccent,
                  expand: true,
                  onPressed: () {
                    Get.to(() => BookingAgreementScreen(booking: booking));
                  },
                ),
              ),
            ],
          ],
        ),
        if (showReview) ...[
          SizedBox(height: 8.h),
          ActionPillButton(
            label: 'booking_leave_review'.tr,
            icon: Icons.star_rounded,
            tone: ActionTone.pending,
            expand: true,
            onPressed: () {
              final serviceLower = (booking.serviceType ?? '').toLowerCase();
              final resolvedRole = (serviceLower.contains('walking') ||
                      serviceLower.contains('dog_walking'))
                  ? 'walker'
                  : 'sitter';
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
                ),
              );
            },
          ),
        ],
        if (showCancel) ...[
          SizedBox(height: 8.h),
          ActionPillButton(
            label: 'service_card_cancel'.tr,
            icon: Icons.event_busy_rounded,
            tone: ActionTone.danger,
            kind: ActionPillKind.danger,
            expand: true,
            onPressed: () {
              if (isCancellablePaid) {
                _confirmSelfCancel(booking);
              } else {
                _showCancelBookingDialog(context, booking);
              }
            },
          ),
        ],
      ],
    );
  }
  /// v575 — audit P0-2 : même parcours que les pages Réservations des 3 rôles
  /// (`showCancel72hSheet` → `self-cancel` avec remboursement). L'annulation
  /// simple laissait l'argent chez nous et le versement au prestataire
  /// programmé. La feuille s'adapte : confirmation possible seulement à plus
  /// de 72 h du début, sinon message « fenêtre fermée » sans bouton.
  Future<void> _confirmSelfCancel(BookingModel booking) async {
    final canFree = booking.isSelfCancelEligible;
    final confirmed = await showCancel72hSheet(canFree: canFree);
    if (confirmed == true && canFree) {
      await _bookingsController.selfCancelBooking(bookingId: booking.id);
    }
  }

  void _showCancelBookingDialog(BuildContext context, BookingModel booking) {
    CustomConfirmationDialog.show(
      context: context,
      message: 'booking_cancel_dialog_message'.tr,
      yesText: 'common_yes'.tr,
      cancelText: 'common_no'.tr,
      onYes: () {
        _bookingsController.cancelBooking(
          bookingId: booking.id,
          sitterId: booking.sitter.id,
        );
      },
    );
  }
}

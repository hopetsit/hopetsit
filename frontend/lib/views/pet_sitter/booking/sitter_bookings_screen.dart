import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hopetsit/widgets/cancel_72h_sheet.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/services/service_tracking_helper.dart';
import 'package:hopetsit/views/booking/handover/handover_action_sheet.dart';
import 'package:hopetsit/controllers/sitter_bookings_controller.dart';
import 'package:hopetsit/models/booking_model.dart';
import 'package:hopetsit/repositories/sitter_repository.dart';
import 'package:hopetsit/widgets/action_banner_kit.dart';
import 'package:hopetsit/widgets/service_confirmation_card.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/booking_date_format.dart';
import 'package:hopetsit/utils/pricing_display_helper.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/views/booking/widgets/booking_ui_kit.dart';
import 'package:hopetsit/widgets/custom_confirmation_dialog.dart';
// v23.1 — onglet Factures.
import 'package:hopetsit/views/invoices/invoices_screen.dart';
import 'package:hopetsit/utils/bottom_inset.dart';
// v571 — fond à motif de pattes + service traduit dans la tête de carte.
import 'package:hopetsit/utils/service_type_translator.dart';
import 'package:hopetsit/widgets/paw_pattern_background.dart';

class SitterBookingsScreen extends StatefulWidget {
  const SitterBookingsScreen({super.key});

  @override
  State<SitterBookingsScreen> createState() => _SitterBookingsScreenState();
}

class _SitterBookingsScreenState extends State<SitterBookingsScreen> {
  late SitterBookingsController _bookingsController;
  // v23.1.260 — id du booking dont l'action service est en cours.
  String? _busySvcId;
  // v23.1.265 — refresh auto silencieux toutes les 30s.
  Timer? _autoRefresh;

  Future<void> _onServiceStart(BookingModel booking) async {
    // v532 — preuve de remise : photo de l'animal + code a 4 chiffres
    // dicte par le proprietaire. Annuler la feuille annule l'action.
    // v565 — photo facultative + position GPS (lat/lng) envoyée avec la preuve.
    final proof = await HandoverActionSheet.show(
        isPickup: true, accent: _sitterAccent);
    if (proof == null) return;
    setState(() => _busySvcId = booking.id);
    try {
      await Get.find<SitterRepository>().startService(
        bookingId: booking.id,
        photo: proof.photo,
        code: proof.code,
        lat: proof.lat,
        lng: proof.lng,
      );
      // v534 — le suivi en direct demarre AVEC la prestation. Sans ca, le
      // proprietaire ne voyait qu un point fige : il fallait que le
      // prestataire pense a activer l interrupteur de la PawMap.
      await ServiceTrackingHelper.startForService();
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
    final proof = await HandoverActionSheet.show(
        isPickup: false, accent: _sitterAccent);
    if (proof == null) return;
    setState(() => _busySvcId = booking.id);
    try {
      await Get.find<SitterRepository>().completeService(
        bookingId: booking.id,
        photo: proof.photo,
        lat: proof.lat,
        lng: proof.lng,
      );
      // v534 — fin de prestation : on coupe la diffusion de position.
      await ServiceTrackingHelper.stopForService();
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
  String? _selectedStatus;
  // v18.7 — couleur d'accent sitter (bleu) pour cohérence avec le reste
  // de l'app. Les 3 écrans Réservations (owner/sitter/walker) utilisent
  // désormais chacun leur couleur de rôle.
  static const Color _sitterAccent = Color(0xFF2563EB);

  // v23.1 — Tout / Remboursée / Payée + chip Factures (3 profils).
  final List<String> _statuses = [
    'all',
    'refunded',
    'paid',
    'factures',
  ];

  @override
  void initState() {
    super.initState();
    _bookingsController = Get.put(SitterBookingsController());
    _selectedStatus = 'all';
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
        backgroundColor: AppColors.scaffold(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: _sitterAccent),
        leading: BackButton(),
        title: Obx(() => BookingAppBarTitle(
              title: 'sitter_bookings_title'.tr,
              subtitle: _headerSubtitle(_bookingsController.bookings.length),
            )),
        // v23.1 — Factures déplacé en chip dans la barre de filtres.
      ),
      body: PawPatternBackground(
        color: _sitterAccent,
        child: Column(
          children: [
            // Status Filter Chips
            _buildStatusFilter(),

            // Bookings List
            Expanded(
              child: Obx(() {
                if (_bookingsController.isLoading.value &&
                    _bookingsController.bookings.isEmpty) {
                  return BookingLoadingList(accent: _sitterAccent);
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
                    color: _sitterAccent,
                    onRefresh: () => _bookingsController.loadBookings(),
                    child: BookingEmptyState(
                      icon: Icons.event_note_rounded,
                      accent: _sitterAccent,
                      title: _selectedStatus == 'all'
                          ? 'sitter_bookings_empty_all'.tr
                          : 'sitter_bookings_empty_filtered'.trParams({
                              'status': _getStatusLabel(_selectedStatus!),
                            }),
                      subtitle: 'v565_bk_empty_hint'.tr,
                    ),
                  );
                }

                return RefreshIndicator(
                  color: _sitterAccent,
                  onRefresh: () => _bookingsController.loadBookings(),
                  child: ListView.builder(
                    // v468 — dégage le bas au-dessus du menu pleine largeur
                    padding: EdgeInsets.fromLTRB(
                        20.w, 16.h, 20.w, 110.h + appBottomInset(context)),
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

  /// v571 — sous-titre de l'en-tête : compteur de réservations chargées.
  String _headerSubtitle(int n) {
    if (n <= 0) return 'bookings571_count_none'.tr;
    if (n == 1) return 'bookings571_count_one'.tr;
    return 'bookings571_count_many'.tr.replaceAll('{n}', '$n');
  }

  Widget _buildStatusFilter() {
    // v571 — sélecteur segmenté (kit Réservations).
    return BookingSegmentedTabs(
      values: _statuses,
      selected: _selectedStatus ?? 'all',
      label: _getStatusLabel,
      icon: bookingTabIcon,
      accent: _sitterAccent,
      linkValues: const {'factures'},
      onSelected: (status) {
        // v23.1 — chip "Factures" navigue vers InvoicesScreen.
        if (status == 'factures') {
          Get.to(() => const InvoicesScreen());
          return;
        }
        setState(() {
          _selectedStatus = status;
        });
        _bookingsController.loadBookings(
          status: status == 'all' ? null : status,
        );
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
      case 'factures':
        return 'invoices_chip'.tr;
      default:
        return status.tr;
    }
  }

  Widget _buildBookingCard(BookingModel booking) {
    // v571 — mêmes données, mêmes conditions : hiérarchie claire (propriétaire
    // + statut, méta-données en pastilles, montant bien lisible, actions).
    final bool paid = (booking.paymentStatus ?? '').toLowerCase() == 'paid';
    final String service = translateServiceType(booking.serviceType);
    // v18.9.2 — sitter voit son montant NET perçu sur les bookings payés.
    // v20.0.11 — commission is paid ON TOP by owner, so sitter receives
    // basePrice intact. Fallback to basePrice, then to total/1.20 (back-out
    // commission), never to total*0.8.
    final double total =
        booking.totalAmount ?? booking.pricing?.totalPrice ?? 0.0;
    final double net = booking.pricing?.netAmount ??
        booking.pricing?.basePrice ??
        (total > 0 ? total / 1.20 : 0.0);
    final String currency =
        booking.pricing?.currency ?? booking.sitter.currency;
    return BookingCard(
      accent: _sitterAccent,
      margin: EdgeInsets.only(bottom: 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête : propriétaire (avatar + nom + service) et statut.
          BookingPartyHeader(
            name: booking.owner.name,
            avatarUrl: booking.owner.avatar.url,
            subtitle: service.isNotEmpty ? service : null,
            accent: _sitterAccent,
            trailing: _buildStatusBadge(booking.status),
          ),

          SizedBox(height: 14.h),

          // Booking Details
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: [
              BookingMetaChip(
                icon: Icons.pets_rounded,
                value: booking.petName,
                semanticsLabel: 'sitter_bookings_pet_label'.tr,
                tint: _sitterAccent,
              ),
              // v18.9 — date + heure localisées (plus d'ISO brut / AM/PM en FR).
              BookingMetaChip(
                icon: Icons.calendar_today_rounded,
                value: BookingDateFormat.localizedDate(booking.date),
                semanticsLabel: 'sitter_bookings_date_label'.tr,
              ),
              BookingMetaChip(
                icon: Icons.access_time_rounded,
                value: BookingDateFormat.localizedTime(booking.timeSlot),
                semanticsLabel: 'sitter_bookings_time_label'.tr,
              ),
              if (booking.duration != null && booking.duration! > 0)
                BookingMetaChip(
                  icon: Icons.timer_rounded,
                  value: '${booking.duration} min',
                  semanticsLabel: 'duration_label'.tr,
                ),
            ],
          ),

          const BookingCardDivider(),

          // Montant net perçu si payé, sinon tarif de référence.
          BookingPriceRow(
            accent: _sitterAccent,
            icon: paid ? Icons.account_balance_wallet_rounded
                : Icons.sell_rounded,
            caption: paid ? null : 'sitter_bookings_rate_label'.tr,
            amount: paid
                ? 'bookings_card_you_receive'.trParams({
                    'amount': '${net.toStringAsFixed(2)} $currency',
                  })
                : PricingDisplayHelper.sitterBookingRateLine(booking),
          ),

          if (booking.description.isNotEmpty) ...[
            SizedBox(height: 12.h),
            _buildDescription(booking.description),
          ],

          SizedBox(height: 16.h),

          // Action Buttons
          _buildActionButtons(booking),
          // v23.1.260 — carte de confirmation de service dans la liste.
          if ((booking.paymentStatus?.toLowerCase() == 'paid') &&
              booking.status.toLowerCase() != 'cancelled' &&
              booking.status.toLowerCase() != 'refunded')
            ServiceConfirmationCard(
              confirmationStatus: booking.confirmationStatus,
              role: 'sitter',
              isPaid: true,
              busy: _busySvcId == booking.id,
              booking: booking,
              accent: _sitterAccent,
              onStart: () => _onServiceStart(booking),
              onComplete: () => _onServiceComplete(booking),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    // v565 — pastille de statut du kit Réservations.
    return BookingStatusChip(status: status, accent: _sitterAccent);
  }

  Widget _buildDescription(String description) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.w),
      // v571 — le fond valait `card` DANS une carte `card` : bloc invisible.
      decoration: BoxDecoration(
        color: AppColors.textSecondary(context).withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InterText(
            text: 'sitter_bookings_description_label'.tr,
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary(context),
          ),
          SizedBox(height: 4.h),
          InterText(
            text: description,
            fontSize: 12.sp,
            fontWeight: FontWeight.w400,
            color: AppColors.textPrimary(context),
          ),
        ],
      ),
    );
  }

  /// v23.1.161 — true si on est encore dans la fenetre 72h+ avant le service.
  /// v462 — délègue au getter autoritaire du modèle (backend canSelfCancel +
  /// filet local robuste). Plus de divergence frontend/backend.
  bool _isWithinSelfCancelWindow(BookingModel booking) {
    return booking.isSelfCancelEligible;
  }

  Future<void> _confirmSelfCancel(BookingModel booking) async {
    // v23.1.256 — annulation gratuite seulement si >72h (règle backend) ;
    // sinon message "fenêtre fermée" sans bouton confirmer.
    final canFree = _isWithinSelfCancelWindow(booking);
    // v569 — feuille moderne commune (widgets/cancel_72h_sheet.dart).
    final confirmed = await showCancel72hSheet(canFree: canFree);
    if (confirmed == true && canFree) {
      await _bookingsController.selfCancelBooking(bookingId: booking.id);
    }
  }

  Widget _buildActionButtons(BookingModel booking) {
    final statusLower = booking.status.toLowerCase();
    final paymentStatusLower = booking.paymentStatus?.toLowerCase();
    // v23.1.256 — bouton annulation visible pour TOUTE résa payée (aligné sur
    // l'écran détail) ; le dialogue gère gratuit (>72h) vs fenêtre fermée.
    // Avant : gaté sur >72h → caché pour les résas proches ou si date non
    // parsable → "le bouton 72h n'est revenu sur aucun profil".
    final isCancellable = paymentStatusLower == 'paid' &&
        statusLower != 'cancelled' &&
        statusLower != 'completed' &&
        statusLower != 'refunded';

    // v569 — mêmes conditions, même appel : seul l'habillage change (kit
    // commun ActionPillButton, destructive = rouge texte, coins 14, ≥ 44 px).
    return Row(
      children: [
        // Cancel Button (for pending and agreed statuses) — calls requestCancellation
        if (statusLower == 'pending' || statusLower == 'agreed') ...[
          Expanded(
            child: ActionPillButton(
              label: 'sitter_bookings_cancel_button'.tr,
              icon: Icons.close_rounded,
              tone: ActionTone.danger,
              kind: ActionPillKind.danger,
              expand: true,
              onPressed: () {
                _showCancelBookingDialog(context, booking);
              },
            ),
          ),
        ],
        // v23.1.161 — self-cancel for PAID bookings >72h (different from
        // requestCancellation which is for pending/agreed). Refund integral.
        if (isCancellable) ...[
          if (statusLower == 'pending' || statusLower == 'agreed')
            SizedBox(width: 10.w),
          Expanded(
            child: ActionPillButton(
              label: 'cancel_72h_button'.tr,
              icon: Icons.event_busy_rounded,
              tone: ActionTone.danger,
              kind: ActionPillKind.danger,
              expand: true,
              onPressed: () => _confirmSelfCancel(booking),
            ),
          ),
        ],
      ],
    );
  }

  void _showCancelBookingDialog(BuildContext context, BookingModel booking) {
    CustomConfirmationDialog.show(
      context: context,
      message: 'sitter_bookings_cancel_dialog_message'.tr,
      yesText: 'sitter_bookings_cancel_dialog_yes'.tr,
      cancelText: 'common_no'.tr,
      onYes: () {
        _bookingsController.requestCancellation(bookingId: booking.id);
      },
    );
  }
}

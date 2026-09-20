import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hopetsit/widgets/cancel_72h_sheet.dart';
// v532 — copie du code de remise en pression longue.
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/bookings_controller.dart';
import 'package:hopetsit/models/booking_model.dart';
import 'package:hopetsit/views/reviews/reviews_screen.dart';
import 'package:hopetsit/repositories/owner_repository.dart';
import 'package:hopetsit/widgets/action_banner_kit.dart';
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
import 'package:hopetsit/views/booking/widgets/booking_ui_kit.dart';
import 'package:hopetsit/utils/bottom_inset.dart';
// v571 — fond à motif de pattes + service traduit dans la tête de carte.
import 'package:hopetsit/utils/service_type_translator.dart';
import 'package:hopetsit/widgets/paw_pattern_background.dart';

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
  static const Color _ownerAccent = Color(0xFFC92A12);

  late BookingsController _bookingsController;
  String _selectedStatus = 'all';
  // v23.1.260 — id du booking dont l'action confirmation est en cours.
  String? _busySvcId;
  // v23.1.265 — Daniel : "les pages réservation se mettent à jour toutes les
  // 30s". Rafraîchissement de fond silencieux (pas de spinner).
  Timer? _autoRefresh;

  // v565 (point 24) — le propriétaire confirme la récupération déclarée par
  // le prestataire (POST /bookings/:id/handover/confirm-pickup).
  Future<void> _onConfirmPickup(BookingModel booking) async {
    setState(() => _busySvcId = booking.id);
    try {
      await Get.find<OwnerRepository>().confirmPickup(bookingId: booking.id);
      CustomSnackbar.showSuccess(
        title: 'v565_ho_pickup_confirmed_title'.tr,
        message: 'v565_ho_pickup_confirmed_msg'.tr,
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

  Future<void> _onServiceConfirm(BookingModel booking) async {
    setState(() => _busySvcId = booking.id);
    try {
      // v565 — « Confirmer le rendu » = /handover/confirm-return (repli
      // /service/confirm si le backend n'est pas encore déployé).
      await Get.find<OwnerRepository>().confirmReturn(bookingId: booking.id);
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
    return _bookingsController.bookings
        .where((b) => _matchesStatus(b, _selectedStatus))
        .toList();
  }

  /// v565 — même règle de filtre, réutilisée pour les compteurs des pilules.
  static bool _matchesStatus(BookingModel b, String status) {
    final s = (b.status).toLowerCase();
    final p = (b.paymentStatus ?? '').toLowerCase();
    if (status == 'paid') return p == 'paid';
    if (status == 'refunded') return p == 'refunded' || s == 'refunded';
    return s == status;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // v571 — fond de page du thème (teinté rôle en clair, #121212 en
      // sombre), le motif de pattes se posant par-dessus.
      backgroundColor: AppColors.scaffold(context),
      appBar: AppBar(
        backgroundColor: AppColors.scaffold(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: _ownerAccent),
        title: Obx(() => BookingAppBarTitle(
              title: 'sitter_bookings_title'.tr,
              subtitle: _headerSubtitle(_bookingsController.bookings.length),
            )),
        // v23.1 — Factures déplacé en chip dans la barre de filtres.
      ),
      body: PawPatternBackground(
        color: _ownerAccent,
        child: Column(
          children: [
            _buildStatusFilter(),
            Expanded(
              child: Obx(() {
                if (_bookingsController.isLoading.value &&
                    _bookingsController.bookings.isEmpty) {
                  return BookingLoadingList(accent: _ownerAccent);
                }
                // v565 — état d'erreur lisible (liste vide + erreur réseau).
                if (_bookingsController.lastError.value.isNotEmpty &&
                    _bookingsController.bookings.isEmpty) {
                  return BookingErrorState(
                    message: _bookingsController.lastError.value,
                    onRetry: () => _bookingsController.loadBookings(),
                  );
                }

                final list = _filteredBookings;
                if (list.isEmpty) {
                  return RefreshIndicator(
                    color: _ownerAccent,
                    onRefresh: () => _bookingsController.loadBookings(),
                    child: BookingEmptyState(
                      icon: Icons.event_note_rounded,
                      accent: _ownerAccent,
                      title: _selectedStatus == 'all'
                          ? 'sitter_bookings_empty_all'.tr
                          : 'sitter_bookings_empty_filtered'.trParams({
                              'status': _label(_selectedStatus),
                            }),
                      subtitle: 'v565_bk_empty_hint'.tr,
                    ),
                  );
                }

                return RefreshIndicator(
                  color: _ownerAccent,
                  onRefresh: () => _bookingsController.loadBookings(),
                  child: ListView.builder(
                    // v468 — dégager le bas pour passer AU-DESSUS de la barre de
                    // menu pleine largeur (~80) + l'inset Samsung.
                    padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w,
                        110.h + appBottomInset(context)),
                    itemCount: list.length,
                    itemBuilder: (context, index) =>
                        _buildBookingCard(list[index]),
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
    // v571 — sélecteur segmenté (kit Réservations) + compteurs par statut.
    return Obx(() {
      final all = _bookingsController.bookings;
      final counts = <String, int>{
        for (final st in _statuses)
          if (st != 'all' && st != 'factures')
            st: all.where((b) => _matchesStatus(b, st)).length,
      };
      return BookingSegmentedTabs(
        values: _statuses,
        selected: _selectedStatus,
        label: _label,
        icon: bookingTabIcon,
        accent: _ownerAccent,
        linkValues: const {'factures'},
        counts: counts,
        onSelected: (status) {
          // v23.1 — chip "Factures" navigue vers InvoicesScreen.
          if (status == 'factures') {
            Get.to(() => const InvoicesScreen());
            return;
          }
          setState(() => _selectedStatus = status);
        },
      );
    });
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
    // v571 — même navigation qu'avant (tap = accord de réservation) : seul
    // l'habillage change. Hiérarchie : prestataire + statut, méta-données en
    // pastilles, prix bien lisible, puis les actions.
    final bool paid = (booking.paymentStatus ?? '').toLowerCase() == 'paid';
    final String service = translateServiceType(booking.serviceType);
    return BookingCard(
      accent: _ownerAccent,
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.zero,
      onTap: () {
        Get.to(() => BookingAgreementScreen(booking: booking));
      },
      child: Padding(
              padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 16.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
            BookingPartyHeader(
              name: booking.sitter.name,
              avatarUrl: booking.sitter.avatar.url,
              subtitle: service.isNotEmpty ? service : null,
              accent: _ownerAccent,
              trailing: BookingStatusChip(
                status: booking.status,
                paymentStatus: booking.paymentStatus,
                accent: _ownerAccent,
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
                  semanticsLabel: 'sitter_bookings_pet_label'.tr,
                  tint: _ownerAccent,
                ),
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
            if (totalAmount != null) ...[
              const BookingCardDivider(),
              // v18.9.2 — owner sur booking payé voit "Tu as payé €X".
              BookingPriceRow(
                accent: _ownerAccent,
                icon: paid
                    ? Icons.verified_rounded
                    : Icons.credit_card_rounded,
                amount: paid
                    ? 'bookings_card_you_paid'.trParams({
                        'amount': CurrencyHelper.format(
                          booking.pricing?.currency ?? booking.sitter.currency,
                          totalAmount,
                        ),
                      })
                    : CurrencyHelper.format(
                        booking.pricing?.currency ?? booking.sitter.currency,
                        totalAmount,
                      ),
              ),
            ],
            SizedBox(height: 16.h),
            _buildActionButtons(booking),
            // v23.1.260 — carte de confirmation de service directement dans
            // la liste (avant elle n'était que sur l'écran détail → "elle
            // n'apparaît pas"). Visible pour les résas payées.
            // v532 — CODE DE REMISE. Le propriétaire le lit ici et le dicte
            // au prestataire au moment de lui confier l'animal : c'est ce qui
            // atteste la rencontre physique. On ne l'affiche que tant que la
            // garde n'a pas démarré (après, il ne sert plus à rien).
            if ((booking.handoverCode ?? '').isNotEmpty &&
                (booking.paymentStatus?.toLowerCase() == 'paid') &&
                (booking.confirmationStatus == 'none' ||
                    booking.confirmationStatus == 'awaiting_start') &&
                booking.status.toLowerCase() != 'cancelled' &&
                booking.status.toLowerCase() != 'refunded')
              _HandoverCodeTile(code: booking.handoverCode!),
            if ((booking.paymentStatus?.toLowerCase() == 'paid') &&
                booking.status.toLowerCase() != 'cancelled' &&
                booking.status.toLowerCase() != 'refunded')
              ServiceConfirmationCard(
                confirmationStatus: booking.confirmationStatus,
                role: 'owner',
                isPaid: true,
                busy: _busySvcId == booking.id,
                booking: booking,
                accent: _ownerAccent,
                onConfirmPickup: () => _onConfirmPickup(booking),
                onConfirm: () => _onServiceConfirm(booking),
                onDispute: () => _onServiceDispute(booking),
              ),
            // v23.1.291 — Daniel : note inline directement sur la carte une
            // fois le service confirmé/terminé (maquette owner). Taper une
            // étoile ou le lien ouvre l'écran d'avis (note pré-sélectionnée).
            if (booking.confirmationStatus == 'confirmed' ||
                booking.status.toLowerCase() == 'completed')
              _ReviewPromptTile(booking: booking),
                ],
              ),
            ),
    );
  }

  /// v23.1.161 — Daniel : "dans reservation il manque le bouton annuler
  /// apres 72h le client ou sitter ne peux annuler". Helper qui retourne
  /// true si le booking est dans la fenetre 72h+ (donc annulable avec
  /// refund integral).
  bool _isWithinSelfCancelWindow(BookingModel booking) {
    // v462 — délègue au getter du modèle qui PRÉFÈRE la valeur backend
    // (canSelfCancel) et retombe sur un recalcul local robuste sinon. Évite
    // toute divergence frontend/backend (cause racine du « bouton ne marche
    // pas + pop up anglais »).
    return booking.isSelfCancelEligible;
  }

  Future<void> _confirmSelfCancel(BookingModel booking) async {
    // v23.1.256 — dialogue adaptatif : annulation gratuite uniquement si
    // >72h avant le service (règle backend selfCancelWithRefund). Si on est
    // dans les 72h, on affiche le message "fenêtre fermée" SANS bouton
    // confirmer (le backend rejetterait de toute façon un self-cancel <72h).
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

    // v569 — mêmes conditions, mêmes appels, mêmes navigations : seul
    // l'habillage change. « Payer » devient l'action PRINCIPALE (pilule
    // pleine), « Voir détails » passe en contour, « Annuler » en rouge texte
    // et sur sa propre ligne — trois boutons côte à côte tronquaient les
    // libellés allemands et polonais.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: ActionPillButton(
                label: 'bookings_action_view_details'.tr,
                icon: Icons.receipt_long_outlined,
                tone: _ownerAccent,
                kind: ActionPillKind.outlined,
                expand: true,
                onPressed: () {
                  Get.to(() => BookingAgreementScreen(booking: booking));
                },
              ),
            ),
            if (isEligibleForPayment) ...[
              SizedBox(width: 10.w),
              Expanded(
                child: ActionPillButton(
                  label: 'service_card_pay_now'.tr,
                  icon: Icons.credit_card_rounded,
                  tone: _ownerAccent,
                  expand: true,
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
                ),
              ),
            ],
          ],
        ),
        // v23.1.161 — Bouton "Annuler" pour reservations payees a >72h.
        if (isCancellable) ...[
          SizedBox(height: 8.h),
          ActionPillButton(
            label: 'cancel_72h_button'.tr,
            icon: Icons.event_busy_rounded,
            tone: ActionTone.danger,
            kind: ActionPillKind.danger,
            expand: true,
            onPressed: () => _confirmSelfCancel(booking),
          ),
        ],
      ],
    );
  }

}

/// v23.1.292 — carte de note inline (maquette owner). Au montage, vérifie si
/// l'owner a déjà noté ce booking (getMyReview) :
///   • pas encore noté → « Comment s'est passé le service ? » + 5 étoiles + lien.
///   • déjà noté → « ✓ Déjà noté · Modifier » (taper ouvre l'écran en mode
///     édition/suppression).
/// Tout tap est absorbé (HitTestBehavior.opaque) pour ne JAMAIS remonter à la
/// carte de réservation qui ouvre la page paiement.
class _ReviewPromptTile extends StatefulWidget {
  final BookingModel booking;
  const _ReviewPromptTile({required this.booking});

  @override
  State<_ReviewPromptTile> createState() => _ReviewPromptTileState();
}

class _ReviewPromptTileState extends State<_ReviewPromptTile> {
  Map<String, dynamic>? _existing;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Get.find<OwnerRepository>()
          .getMyReview(bookingId: widget.booking.id);
      if (mounted) {
        setState(() {
          _existing = r;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String get _resolvedRole {
    final s = (widget.booking.serviceType ?? '').toLowerCase();
    return (s.contains('walking') || s.contains('dog_walking'))
        ? 'walker'
        : 'sitter';
  }

  void _openReview(int rating) {
    final b = widget.booking;
    Get.to(
      () => ReviewsScreen(
        serviceProviderName: b.sitter.name,
        phoneNumber: b.sitter.mobile,
        email: b.sitter.email,
        profileImagePath:
            b.sitter.avatar.url.isNotEmpty ? b.sitter.avatar.url : null,
        serviceProviderId: b.sitter.id,
        bookingId: b.id,
        revieweeRole: _resolvedRole,
        initialRating: rating,
      ),
    )?.then((_) => _load()); // rafraîchit l'état au retour (noté / modifié / supprimé)
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    return _existing != null ? _alreadyRated() : _starPrompt();
  }

  // État « déjà noté » : étoiles pleines + « Modifier ».
  Widget _alreadyRated() {
    final rating = ((_existing!['rating'] as num?) ?? 0).round();
    // v571 — plus de vert/pêche en dur : le fond et le liseré se déduisent du
    // thème, sinon la tuile restait blanc verdâtre en mode sombre.
    const Color green = Color(0xFF16A34A);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openReview(0),
      child: Container(
        margin: EdgeInsets.only(top: 12.h),
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: bookingToneSurface(context, green),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: green.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle_rounded,
                color: bookingToneForeground(context, green), size: 20.sp),
            SizedBox(width: 8.w),
            ...List.generate(
              5,
              (i) => Icon(
                i < rating ? Icons.star_rounded : Icons.star_border_rounded,
                color: const Color(0xFFF5B301),
                size: 18.sp,
              ),
            ),
            const Spacer(),
            InterText(
              text: 'review_already_rated'.tr,
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
              color: bookingToneForeground(context, AppColors.primaryColor),
            ),
          ],
        ),
      ),
    );
  }

  // État « pas encore noté » : invitation + étoiles tappables + lien.
  Widget _starPrompt() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openReview(0),
      child: Container(
        margin: EdgeInsets.only(top: 12.h),
        padding: EdgeInsets.all(16.w),
        // v571 — pêche en dur remplacé par la teinte du rôle sur la surface
        // du thème (lisible en clair comme en sombre).
        decoration: BoxDecoration(
          color: bookingToneSurface(context, AppColors.primaryColor),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
              color: AppColors.primaryColor.withValues(alpha: 0.28)),
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
                  onTap: () => _openReview(i + 1),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: EdgeInsets.only(right: 8.w),
                    child: Icon(
                      Icons.star_rounded,
                      size: 34.sp,
                      // v571 — gris fixe illisible en sombre.
                      color: AppColors.divider(context),
                    ),
                  ),
                );
              }),
            ),
            SizedBox(height: 10.h),
            GestureDetector(
              onTap: () => _openReview(0),
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
      ),
    );
  }
}

/// v532 — CODE DE REMISE affiché au propriétaire.
///
/// Daniel : « améliore le système de vérification quand je laisse mon chien et
/// quand je le récupère ». Le prestataire ne peut plus déclarer « j'ai
/// récupéré l'animal » depuis chez lui : il doit saisir ce code, que seul le
/// propriétaire voit, et que celui-ci lui donne de vive voix au moment de la
/// remise. Une pression longue copie le code.
class _HandoverCodeTile extends StatelessWidget {
  final String code;
  const _HandoverCodeTile({required this.code});

  @override
  Widget build(BuildContext context) {
    // v571 — mêmes textes, mêmes gestes : seules les couleurs deviennent
    // dépendantes du thème (titre et description étaient illisibles en sombre).
    final Color fg = bookingToneForeground(context, AppColors.primaryColor);
    return Container(
      margin: EdgeInsets.only(top: 12.h),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: bookingToneSurface(context, AppColors.primaryColor),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: AppColors.primaryColor.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.vpn_key_rounded, color: fg, size: 22.sp),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PoppinsText(
                  text: 'handover_owner_code_title'.tr,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary(context),
                ),
                SizedBox(height: 2.h),
                InterText(
                  text: 'handover_owner_code_desc'.tr,
                  fontSize: 11.sp,
                  color: AppColors.textSecondary(context),
                ),
              ],
            ),
          ),
          SizedBox(width: 10.w),
          GestureDetector(
            onLongPress: () {
              Clipboard.setData(ClipboardData(text: code));
              CustomSnackbar.showSuccess(
                title: 'handover_owner_code_copied'.tr,
                message: '',
              );
            },
            child: Text(
              code,
              style: TextStyle(
                fontSize: 22.sp,
                fontWeight: FontWeight.w800,
                letterSpacing: 4,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

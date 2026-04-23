
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/models/booking_model.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/currency_helper.dart';
import 'package:hopetsit/utils/app_images.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/views/service_provider/service_provider_detail_screen.dart';
import 'package:hopetsit/views/pet_owner/booking-application/owner_booking_detail_screen.dart';

enum ServiceProviderCardType { home, application, booking }

class ServiceProviderCard extends StatefulWidget {
  final String name;
  final String phoneNumber;
  final String email;
  final double rating;
  final int? reviewsCount;
  final String location;
  final String status;
  final String pricePerHour;
  final String? pricePerDay;
  final String? pricePerWeek;
  final String? pricePerMonth;
  final String? profileImagePath;
  final bool? isBlurred;
  final bool? showStatusChip;
  final String? sitterId;
  final VoidCallback? onSendRequest;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final VoidCallback? onCancel;
  final VoidCallback? onBlock;
  final VoidCallback? onPay; // Payment callback
  final VoidCallback? onStartChat; // Start chat callback for paid bookings
  final ServiceProviderCardType cardType;
  final BookingModel? booking; // Booking model for payment status
  /// Currency code for hourly rate display (e.g. USD, EUR). Defaults to EUR.
  final String currencyCode;
  /// Sprint 5 UI step 4 — show a blue verified badge next to the name.
  final bool identityVerified;
  /// Sprint 7 step 2 — show 🏆 Top badge next to the name.
  final bool isTopSitter;
  /// Coin boost — show 🔥 Boosted badge.
  final bool isBoosted;
  /// Estimated total cost for the owner's active post (optional).
  final double? estimatedCost;
  /// Number of days for the estimation.
  final int? estimatedDays;

  const ServiceProviderCard({
    super.key,
    required this.name,
    required this.phoneNumber,
    required this.email,
    required this.rating,
    this.showStatusChip = true,
    this.reviewsCount,
    this.isBlurred = false,
    required this.location,
    required this.status,
    required this.pricePerHour,
    this.pricePerDay,
    this.pricePerWeek,
    this.pricePerMonth,
    this.profileImagePath,
    this.sitterId,
    this.onSendRequest,
    this.onAccept,
    this.onReject,
    this.onCancel,
    this.onBlock,
    this.onPay,
    this.onStartChat,
    this.cardType = ServiceProviderCardType.home,
    this.booking,
    this.currencyCode = CurrencyHelper.eur,
    this.identityVerified = false,
    this.isTopSitter = false,
    this.isBoosted = false,
    this.estimatedCost,
    this.estimatedDays,
  });

  @override
  State<ServiceProviderCard> createState() => _ServiceProviderCardState();
}

class _ServiceProviderCardState extends State<ServiceProviderCard> {
  late bool isPhoneLocked;
  late bool isEmailLocked;
  bool _isAccepting = false;
  bool _isRejecting = false;

  @override
  void initState() {
    super.initState();
    // v18.8 — coherence paiement : dès que la réservation est payée,
    // on déverrouille automatiquement téléphone + email, même si le
    // parent a passé isBlurred=true. Avant, les cadenas + ****1982
    // restaient visibles sur une réservation payée, ce qui est un bug.
    final paid =
        (widget.booking?.paymentStatus?.toLowerCase() ?? '') == 'paid';
    final shouldBlur = (widget.isBlurred ?? false) && !paid;
    isPhoneLocked = shouldBlur;
    isEmailLocked = shouldBlur;
  }

  String getMaskedPhoneNumber(String phone) {
    if (phone.isEmpty) return '';
    return '****${phone.replaceRange(0, phone.length - 4, '')}';
  }

  String getMaskedEmail(String email) {
    if (email.isEmpty) return '';
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final name = parts[0];
    return '${name[0]}${'*' * (name.length - 1)}@${parts[1]}';
  }

  @override
  Widget build(BuildContext context) {
    // v18.8 — Option B : en mode booking, on affiche une carte COMPACTE
    // alignée sur le design des écrans Réservations sitter/walker
    // (avatar 32×32, lignes icône pet/date/heure/prix, bouton unique en
    // couleur rôle). Les modes home / application conservent la fiche
    // complète (gros avatar 100×100 + contacts + note + bouton
    // Accept/Reject) car leur UX est différente.
    if (widget.cardType == ServiceProviderCardType.booking &&
        widget.booking != null) {
      return _buildCompactBookingCard();
    }
    // v18.8 — Option B (suite) : carte candidature également en version
    // compacte, alignée sur le design booking. Owner voit désormais une
    // ligne cohérente avec l'onglet Réservations : badge statut + avatar
    // + note + prix + boutons Accepter/Rejeter en couleur rôle.
    if (widget.cardType == ServiceProviderCardType.application) {
      return _buildCompactApplicationCard();
    }

    return GestureDetector(
      onTap: () {
        // Navigate to booking detail screen if it's a booking card
        if (widget.cardType == ServiceProviderCardType.booking &&
            widget.booking != null) {
          Get.to(
            () => OwnerBookingDetailScreen(
              booking: widget.booking!,
              onPay: widget.onPay,
              onStartChat: widget.onStartChat,
              onCancel: widget.onCancel,
            ),
          );
        } else if (widget.sitterId != null && widget.sitterId!.isNotEmpty) {
          // Navigate to service provider detail screen for other card types
          Get.to(
            () => ServiceProviderDetailScreen(
              sitterId: widget.sitterId!,
              status: widget.status,
              booking: widget.booking,
            ),
          );
        }
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 16.h),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(11.r),
          boxShadow: AppColors.cardShadow(context),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Picture and Info
                Row(
                  children: [
                    widget.profileImagePath != null &&
                            (widget.profileImagePath!.startsWith('http://') ||
                                widget.profileImagePath!.startsWith('https://'))
                        ? ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: widget.profileImagePath!,
                              width: 100.w,
                              height: 100.h,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                width: 100.w,
                                height: 100.h,
                                color: AppColors.lightGrey,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.primaryColor,
                                    ),
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) =>
                                  CircleAvatar(
                                    radius: 50.r,
                                    backgroundImage: AssetImage(
                                      AppImages.placeholderImage,
                                    ),
                                  ),
                            ),
                          )
                        : CircleAvatar(
                            radius: 50.r,
                            backgroundImage: AssetImage(
                              widget.profileImagePath ??
                                  AppImages.placeholderImage,
                            ),
                          ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right:
                              widget.cardType ==
                                  ServiceProviderCardType.application
                              ? 80.w
                              : 0,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Name + verified badge (sprint 5 UI step 4)
                            Row(
                              children: [
                                Flexible(
                                  child: PoppinsText(
                                    text: widget.name,
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary(context),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (widget.identityVerified) ...[
                                  SizedBox(width: 4.w),
                                  Tooltip(
                                    message: 'profile_identity_verified'.tr,
                                    child: Icon(
                                      Icons.verified,
                                      color: Colors.blue,
                                      size: 16.sp,
                                    ),
                                  ),
                                ],
                                // Sprint 7 step 2 — Top Sitter badge.
                                if (widget.isTopSitter) ...[
                                  SizedBox(width: 4.w),
                                  Tooltip(
                                    message: 'top_sitter_badge'.tr,
                                    child: Text('🏆', style: TextStyle(fontSize: 14.sp)),
                                  ),
                                ],
                                // Coin Boost badge.
                                if (widget.isBoosted) ...[
                                  SizedBox(width: 4.w),
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [Colors.orange, Colors.red.shade400],
                                      ),
                                      borderRadius: BorderRadius.circular(8.r),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text('🔥', style: TextStyle(fontSize: 10.sp)),
                                        SizedBox(width: 2.w),
                                        InterText(
                                          text: 'boost_badge'.tr,
                                          fontSize: 9.sp,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            SizedBox(height: 8.h),
                            // Contact Information
                            GestureDetector(
                              // onTap: () => setState(
                              //   () => isPhoneLocked = !isPhoneLocked,
                              // ),
                              child: _buildContactInfo(
                                AppImages.callIcon,
                                widget.phoneNumber.isNotEmpty
                                    ? widget.phoneNumber
                                    : 'service_card_no_phone'.tr,
                                isPhoneLocked,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            GestureDetector(
                              // onTap: () => setState(
                              //   () => isEmailLocked = !isEmailLocked,
                              // ),
                              child: _buildContactInfo(
                                AppImages.mailIcon,
                                widget.email,
                                isEmailLocked,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 16.h),

                // Rating — v18.8 : on cache "Aucune note pour le moment" sur les
                // cartes réservation (peu utile après paiement).
                if ((widget.rating > 0 && (widget.reviewsCount ?? 0) > 0) ||
                    widget.cardType != ServiceProviderCardType.booking)
                  Row(
                    children: [
                      if (widget.rating > 0 &&
                          (widget.reviewsCount ?? 0) > 0) ...[
                        Row(
                          children: List.generate(5, (starIndex) {
                            return Icon(
                              starIndex < widget.rating.floor()
                                  ? Icons.star
                                  : Icons.star_border,
                              size: 16.sp,
                              color: starIndex < widget.rating.floor()
                                  ? Colors.amber
                                  : AppColors.greyText,
                            );
                          }),
                        ),
                        SizedBox(width: 8.w),
                        InterText(
                          text: widget.rating.toStringAsFixed(1),
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textSecondary(context),
                        ),
                      ] else ...[
                        InterText(
                          text: 'sitter_detail_no_rating'.tr,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textSecondary(context),
                        ),
                      ],
                      SizedBox(width: 16.w),
                    ],
                  ),
                // Location — v18.8 : on cache complètement la ligne quand
                // la ville est absente ET qu'on est sur une carte réservation.
                // Avant, on affichait "Aucun lieu disponible" même sur une
                // réservation payée, ce qui polluait l'UI.
                if (widget.location.isNotEmpty ||
                    widget.cardType != ServiceProviderCardType.booking)
                  Row(
                    children: [
                      Image.asset(
                        AppImages.pinIcon,
                        width: 24.w,
                        height: 24.h,
                        color: _roleAccent,
                      ),
                      SizedBox(width: 4.w),
                      Expanded(
                        child: InterText(
                          text: widget.location.isNotEmpty
                              ? widget.location
                              : 'service_card_no_location'.tr,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                    ],
                  ),

                // Status Chip
                if (widget.showStatusChip == true) ...[
                  SizedBox(height: 5.h),
                  _buildStatusChip(),
                ],

                // Action Buttons
                if (widget.cardType == ServiceProviderCardType.home ||
                    (widget.cardType == ServiceProviderCardType.application &&
                        widget.status == 'pending') ||
                    widget.cardType == ServiceProviderCardType.booking) ...[
                  SizedBox(height: 16.h),
                  _buildActionButtons(),
                ],
              ],
            ),
            // More Options Icon or Price - Top Right
            if (widget.cardType != ServiceProviderCardType.booking)
              Positioned(
                top: 0,
                right: 0,
                child: widget.cardType == ServiceProviderCardType.application
                    ? Padding(
                        padding: EdgeInsets.all(8.w),
                        child: PoppinsText(
                          text:
                              '${CurrencyHelper.symbol(widget.currencyCode)}${widget.pricePerHour}',
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary(context),
                        ),
                      )
                    : PopupMenuButton<String>(
                        icon: Container(
                          padding: EdgeInsets.all(8.w),
                          decoration: BoxDecoration(
                            color: AppColors.card(context),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.more_vert,
                            color: AppColors.grey500Color,
                            size: 20.sp,
                          ),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                        elevation: 8,
                        color: AppColors.card(context),
                        itemBuilder: (BuildContext context) => [
                          PopupMenuItem<String>(
                            value: 'block',
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8.w,
                                vertical: 8.h,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(5.r),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(6.w),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryColor.withValues(alpha: 
                                        0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(6.r),
                                    ),
                                    child: Icon(
                                      Icons.block,
                                      size: 18.sp,
                                      color: AppColors.primaryColor,
                                    ),
                                  ),
                                  SizedBox(width: 12.w),
                                  Expanded(
                                    child: PoppinsText(
                                      text: 'service_card_block'.tr,
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        onSelected: (String value) {
                          if (value == 'block') {
                            widget.onBlock?.call();
                          }
                        },
                      ),
              ),
          ],
        ),
      ),
    );
  }

  /// v18.8 — Design compact pour ServiceProviderCardType.booking.
  /// Aligné sur walker_bookings_screen.dart et sitter_bookings_screen.dart :
  /// badge statut à gauche, avatar 32×32 + nom à droite, lignes icône
  /// pet/date/heure/prix, bouton action unique en couleur rôle.
  Widget _buildCompactBookingCard() {
    final booking = widget.booking!;
    final accent = _roleAccent;
    final duration = booking.duration;
    final totalAmount = booking.totalAmount ??
        booking.pricing?.totalPrice ??
        booking.basePrice;

    return GestureDetector(
      onTap: () {
        Get.to(
          () => OwnerBookingDetailScreen(
            booking: booking,
            onPay: widget.onPay,
            onStartChat: widget.onStartChat,
            onCancel: widget.onCancel,
          ),
        );
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
            // Header : badge statut + avatar/nom
            Row(
              children: [
                _buildStatusChip(),
                const Spacer(),
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipOval(
                        child: widget.profileImagePath != null &&
                                widget.profileImagePath!.isNotEmpty &&
                                (widget.profileImagePath!.startsWith('http://') ||
                                    widget.profileImagePath!.startsWith('https://'))
                            ? CachedNetworkImage(
                                imageUrl: widget.profileImagePath!,
                                width: 32.w,
                                height: 32.h,
                                fit: BoxFit.cover,
                                placeholder: (_, __) =>
                                    _compactAvatarPlaceholder(accent),
                                errorWidget: (_, __, ___) =>
                                    _compactAvatarPlaceholder(accent),
                              )
                            : _compactAvatarPlaceholder(accent),
                      ),
                      SizedBox(width: 8.w),
                      Flexible(
                        child: InterText(
                          text: widget.name,
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
            _compactRow(
              Icons.pets,
              'sitter_bookings_pet_label'.tr,
              booking.petName,
            ),
            SizedBox(height: 12.h),
            _compactRow(
              Icons.calendar_today,
              'sitter_bookings_date_label'.tr,
              booking.date,
            ),
            SizedBox(height: 12.h),
            _compactRow(
              Icons.access_time,
              'sitter_bookings_time_label'.tr,
              booking.timeSlot,
            ),
            if (duration != null && duration > 0) ...[
              SizedBox(height: 12.h),
              _compactRow(
                Icons.timer,
                'duration_label'.tr.isNotEmpty
                    ? 'duration_label'.tr
                    : 'Duration',
                '$duration min',
              ),
            ],
            if (totalAmount != null) ...[
              SizedBox(height: 12.h),
              Row(
                children: [
                  Icon(Icons.attach_money, size: 16.sp, color: accent),
                  SizedBox(width: 8.w),
                  InterText(
                    text: CurrencyHelper.format(widget.currencyCode, totalAmount),
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ],
              ),
            ],
            if (booking.description.isNotEmpty) ...[
              SizedBox(height: 12.h),
              InterText(
                text: booking.description,
                fontSize: 12.sp,
                fontWeight: FontWeight.w400,
                color: AppColors.textSecondary(context),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            SizedBox(height: 16.h),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  /// v18.8 — Carte candidature compacte côté owner. Miroite le design
  /// booking : badge statut + avatar 32 + nom + note/prix + boutons rôle.
  Widget _buildCompactApplicationCard() {
    final accent = _roleAccent;
    final hasRating =
        widget.rating > 0 && (widget.reviewsCount ?? 0) > 0;
    final hasLocation = widget.location.trim().isNotEmpty;
    final currencySym = CurrencyHelper.symbol(widget.currencyCode);
    final price = widget.pricePerHour.trim();
    final showPrice = price.isNotEmpty && price != '0';

    return GestureDetector(
      onTap: () {
        if (widget.sitterId != null && widget.sitterId!.isNotEmpty) {
          Get.to(
            () => ServiceProviderDetailScreen(
              sitterId: widget.sitterId!,
              status: widget.status,
              booking: widget.booking,
            ),
          );
        }
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
            // Row 1 — badge statut + avatar/nom
            Row(
              children: [
                _buildStatusChip(),
                const Spacer(),
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipOval(
                        child: widget.profileImagePath != null &&
                                widget.profileImagePath!.isNotEmpty &&
                                (widget.profileImagePath!.startsWith('http://') ||
                                    widget.profileImagePath!.startsWith('https://'))
                            ? CachedNetworkImage(
                                imageUrl: widget.profileImagePath!,
                                width: 32.w,
                                height: 32.h,
                                fit: BoxFit.cover,
                                placeholder: (_, __) =>
                                    _compactAvatarPlaceholder(accent),
                                errorWidget: (_, __, ___) =>
                                    _compactAvatarPlaceholder(accent),
                              )
                            : _compactAvatarPlaceholder(accent),
                      ),
                      SizedBox(width: 8.w),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: PoppinsText(
                                    text: widget.name,
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary(context),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (widget.identityVerified) ...[
                                  SizedBox(width: 4.w),
                                  Icon(Icons.verified,
                                      color: Colors.blue, size: 14.sp),
                                ],
                                if (widget.isTopSitter) ...[
                                  SizedBox(width: 4.w),
                                  Text('🏆',
                                      style: TextStyle(fontSize: 12.sp)),
                                ],
                                if (widget.isBoosted) ...[
                                  SizedBox(width: 4.w),
                                  Text('🔥',
                                      style: TextStyle(fontSize: 12.sp)),
                                ],
                              ],
                            ),
                            if (hasRating) ...[
                              SizedBox(height: 2.h),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.star,
                                      size: 12.sp, color: Colors.amber),
                                  SizedBox(width: 2.w),
                                  InterText(
                                    text:
                                        '${widget.rating.toStringAsFixed(1)} (${widget.reviewsCount})',
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w400,
                                    color: AppColors.textSecondary(context),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Row 2 — info secondaire : location + prix
            if (hasLocation || showPrice) ...[
              SizedBox(height: 12.h),
              Row(
                children: [
                  if (hasLocation) ...[
                    Icon(Icons.place_outlined,
                        size: 14.sp, color: AppColors.grey700Color),
                    SizedBox(width: 4.w),
                    Flexible(
                      child: InterText(
                        text: widget.location,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textSecondary(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (showPrice)
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 10.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                      child: PoppinsText(
                        text: '$currencySym$price/${'price_per_hour_short'.tr}',
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                ],
              ),
            ],
            // Row 3 — action buttons Accept/Reject (role-colored) for
            // pending applications only. Pour les statuts autres (accepted
            // etc.), pas de boutons : la candidature a déjà transité.
            if (widget.status.toLowerCase() == 'pending' &&
                (widget.onAccept != null || widget.onReject != null)) ...[
              SizedBox(height: 16.h),
              Row(
                children: [
                  if (widget.onAccept != null)
                    Expanded(
                      child: GestureDetector(
                        onTap: (_isAccepting || _isRejecting)
                            ? null
                            : () async {
                                setState(() => _isAccepting = true);
                                try {
                                  await Future.sync(() => widget.onAccept!.call());
                                } finally {
                                  if (mounted) {
                                    setState(() => _isAccepting = false);
                                  }
                                }
                              },
                        child: Container(
                          height: 44.h,
                          decoration: BoxDecoration(
                            color: _isAccepting
                                ? accent.withValues(alpha: 0.7)
                                : accent,
                            borderRadius: BorderRadius.circular(22.r),
                          ),
                          child: Center(
                            child: _isAccepting
                                ? SizedBox(
                                    width: 18.w,
                                    height: 18.h,
                                    child: const CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          AppColors.whiteColor),
                                    ),
                                  )
                                : InterText(
                                    text: 'service_card_accept'.tr,
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.whiteColor,
                                  ),
                          ),
                        ),
                      ),
                    ),
                  if (widget.onAccept != null && widget.onReject != null)
                    SizedBox(width: 10.w),
                  if (widget.onReject != null)
                    Expanded(
                      child: GestureDetector(
                        onTap: (_isAccepting || _isRejecting)
                            ? null
                            : () async {
                                setState(() => _isRejecting = true);
                                try {
                                  await Future.sync(() => widget.onReject!.call());
                                } finally {
                                  if (mounted) {
                                    setState(() => _isRejecting = false);
                                  }
                                }
                              },
                        child: Container(
                          height: 44.h,
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: AppColors.errorColor, width: 1),
                            borderRadius: BorderRadius.circular(22.r),
                          ),
                          child: Center(
                            child: _isRejecting
                                ? SizedBox(
                                    width: 18.w,
                                    height: 18.h,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          AppColors.errorColor),
                                    ),
                                  )
                                : InterText(
                                    text: 'service_card_reject'.tr,
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.errorColor,
                                  ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _compactAvatarPlaceholder(Color accent) {
    return Container(
      width: 32.w,
      height: 32.h,
      color: AppColors.lightGrey,
      child: Icon(Icons.person, size: 20.sp, color: accent),
    );
  }

  Widget _compactRow(IconData icon, String label, String value) {
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

  String _localizedStatusLabel(String status) {
    final statusLower = status.toLowerCase();
    switch (statusLower) {
      case 'available':
      case 'online':
        return 'status_available_label'.tr;
      case 'cancelled':
        return 'status_cancelled_label'.tr;
      case 'rejected':
        return 'status_rejected_label'.tr;
      case 'pending':
        return 'status_pending_label'.tr;
      case 'agreed':
        return 'status_agreed_label'.tr;
      case 'paid':
        return 'status_paid_label'.tr;
      case 'accepted':
        return 'status_accepted_label'.tr;
      default:
        if (status.isEmpty) return status;
        return status[0].toUpperCase() + status.substring(1);
    }
  }

  Widget _buildStatusChip() {
    final statusLower = widget.status.toLowerCase();
    Color backgroundColor;
    Color textColor;
    IconData icon;
    final displayText = _localizedStatusLabel(widget.status);

    switch (statusLower) {
      case 'available':
      case 'online':
        backgroundColor = AppColors.greenColor.withValues(alpha: 0.1);
        textColor = AppColors.greenColor;
        icon = Icons.check_circle;
        break;
      case 'cancelled':
        backgroundColor = AppColors.errorColor.withValues(alpha: 0.1);
        textColor = AppColors.errorColor;
        icon = Icons.cancel;
        break;
      case 'rejected':
        backgroundColor = AppColors.errorColor.withValues(alpha: 0.1);
        textColor = AppColors.errorColor;
        icon = Icons.close_rounded;
        break;
      case 'pending':
        backgroundColor = Colors.orange.withValues(alpha: 0.1);
        textColor = Colors.orange;
        icon = Icons.timer;
        break;
      case 'agreed':
      case 'paid':
      case 'accepted':
        backgroundColor = AppColors.greenColor.withValues(alpha: 0.1);
        textColor = AppColors.greenColor;
        icon = Icons.check_circle;
        break;
      default:
        backgroundColor = AppColors.greyColor.withValues(alpha: 0.1);
        textColor = AppColors.greyColor;
        icon = Icons.info;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14.sp, color: textColor),
          SizedBox(width: 6.w),
          InterText(
            text: displayText,
            fontSize: 11.sp,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ],
      ),
    );
  }

  Widget _buildContactInfo(String iconPath, String text, bool isLocked) {
    final displayText = isLocked
        ? (iconPath == AppImages.callIcon
              ? getMaskedPhoneNumber(text)
              : getMaskedEmail(text))
        : text;

    return Row(
      children: [
        Icon(
          isLocked ? Icons.lock : Icons.lock_open,
          size: 20.sp,
          color: AppColors.grey500Color,
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: InterText(
            text: displayText,
            fontSize: 14.sp,
            fontWeight: FontWeight.w400,
            color: AppColors.textSecondary(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // SizedBox(width: 8.w),
        // Icon(
        //   isLocked ? Icons.lock : Icons.lock_open,
        //   size: 16.sp,
        //   color: AppColors.primaryColor,
        // ),
      ],
    );
  }

  /// v18.8 — dérive la couleur d'accent du rôle à partir du booking.
  /// Walker → vert ; Sitter → bleu ; fallback → orange primary.
  Color get _roleAccent {
    final serviceLower = (widget.booking?.serviceType ?? '').toLowerCase();
    if (serviceLower.contains('walking') ||
        serviceLower.contains('dog_walking')) {
      return const Color(0xFF16A34A);
    }
    if (serviceLower.contains('sitting') ||
        serviceLower.contains('day_care') ||
        serviceLower.contains('boarding')) {
      return const Color(0xFF2563EB);
    }
    return AppColors.primaryColor;
  }

  Widget _buildActionButtons() {
    switch (widget.cardType) {
      case ServiceProviderCardType.home:
        final sym = CurrencyHelper.symbol(widget.currencyCode);
        final rates = <String>[
          if (widget.pricePerHour.isNotEmpty && widget.pricePerHour != '0')
            '$sym${widget.pricePerHour}/${'price_per_hour_short'.tr}',
          if (widget.pricePerDay != null && widget.pricePerDay!.isNotEmpty && widget.pricePerDay != '0')
            '$sym${widget.pricePerDay}/${'price_per_day_short'.tr}',
          if (widget.pricePerWeek != null && widget.pricePerWeek!.isNotEmpty && widget.pricePerWeek != '0')
            '$sym${widget.pricePerWeek}/${'price_per_week_short'.tr}',
          if (widget.pricePerMonth != null && widget.pricePerMonth!.isNotEmpty && widget.pricePerMonth != '0')
            '$sym${widget.pricePerMonth}/${'price_per_month_short'.tr}',
        ];
        final priceLabel = rates.isNotEmpty ? rates.join(' · ') : '$sym${widget.pricePerHour}/${'price_per_hour_short'.tr}';
        return Column(
          children: [
            // Price row
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 12.w),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primaryColor),
                borderRadius: BorderRadius.circular(48.r),
              ),
              child: Center(
                child: InterText(
                  text: priceLabel,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryColor,
                ),
              ),
            ),
            // Estimated cost for owner's active post
            if (widget.estimatedCost != null && widget.estimatedDays != null && widget.estimatedDays! > 0) ...[
              SizedBox(height: 8.h),
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 12.w),
                decoration: BoxDecoration(
                  color: AppColors.primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.calculate_outlined, size: 16.sp, color: AppColors.primaryColor),
                    SizedBox(width: 6.w),
                    InterText(
                      text: '${'estimated_cost_label'.tr}: ${CurrencyHelper.symbol(widget.currencyCode)}${widget.estimatedCost!.toStringAsFixed(0)}',
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryColor,
                    ),
                    SizedBox(width: 4.w),
                    InterText(
                      text: '(${'for_x_days'.trParams({'days': widget.estimatedDays.toString()})})',
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textSecondary(context),
                    ),
                  ],
                ),
              ),
            ],
            SizedBox(height: 10.h),
            // Send request button
            GestureDetector(
              onTap:
                  widget.onSendRequest ??
                  () {
                    // Default navigation to send request screen
                  },
              child: Container(
                width: double.infinity,
                height: 48.h,
                padding: EdgeInsets.symmetric(vertical: 12.h),
                decoration: BoxDecoration(
                  color: AppColors.primaryColor,
                  borderRadius: BorderRadius.circular(48.r),
                ),
                child: Center(
                  child: InterText(
                    text: 'service_card_send_request'.tr,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                    color: AppColors.whiteColor,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ],
        );

      case ServiceProviderCardType.application:
        return Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: (_isAccepting || _isRejecting || widget.onAccept == null)
                    ? null
                    : () async {
                        setState(() => _isAccepting = true);
                        try {
                          await Future.sync(() => widget.onAccept!.call());
                        } finally {
                          if (mounted) setState(() => _isAccepting = false);
                        }
                      },
                child: Container(
                  height: 48.h,
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  decoration: BoxDecoration(
                    color: _isAccepting
                        ? AppColors.primaryColor.withValues(alpha: 0.7)
                        : AppColors.primaryColor,
                    borderRadius: BorderRadius.circular(48.r),
                  ),
                  child: Center(
                    child: _isAccepting
                        ? SizedBox(
                            width: 20.w,
                            height: 20.h,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.whiteColor,
                              ),
                            ),
                          )
                        : InterText(
                            text: 'service_card_accept'.tr,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                            color: AppColors.whiteColor,
                          ),
                  ),
                ),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: GestureDetector(
                onTap: (_isAccepting || _isRejecting || widget.onReject == null)
                    ? null
                    : () async {
                        setState(() => _isRejecting = true);
                        try {
                          await Future.sync(() => widget.onReject!.call());
                        } finally {
                          if (mounted) setState(() => _isRejecting = false);
                        }
                      },
                child: Container(
                  height: 48.h,
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.primaryColor),
                    borderRadius: BorderRadius.circular(48.r),
                  ),
                  child: Center(
                    child: _isRejecting
                        ? SizedBox(
                            width: 20.w,
                            height: 20.h,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.primaryColor,
                              ),
                            ),
                          )
                        : InterText(
                            text: 'service_card_reject'.tr,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                            color: AppColors.greyText,
                          ),
                  ),
                ),
              ),
            ),
          ],
        );

      case ServiceProviderCardType.booking:
        if (widget.booking == null) {
          // No booking data, show cancel button
          return Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: widget.onCancel,
                  child: Container(
                    height: 48.h,
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.primaryColor),
                      borderRadius: BorderRadius.circular(48.r),
                    ),
                    child: Center(
                      child: InterText(
                        text: 'service_card_cancel'.tr,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                        color: AppColors.greyText,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        // Check if booking is cancelled
        final status = widget.booking!.status.toLowerCase().trim();
        if (status == 'cancelled' || widget.booking!.cancelledAt != null) {
          // Show no action buttons for cancelled bookings
          return SizedBox.shrink();
        }

        final paymentStatus = widget.booking!.paymentStatus
            ?.toLowerCase()
            .trim();

        // Booking is eligible for payment if:
        // 1. Status is 'agreed', 'accepted', or 'confirmed'
        // 2. Payment status is null, 'pending', 'failed', or anything other than 'paid'
        final isEligibleForPayment =
            (status == 'agreed' ||
                status == 'accepted' ||
                status == 'confirmed') &&
            (paymentStatus == null ||
                paymentStatus.isEmpty ||
                paymentStatus != 'paid');

        final isPaid = paymentStatus == 'paid';

        // Show Pay button if eligible for payment and onPay callback is provided
        if (isEligibleForPayment && widget.onPay != null) {
          return Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: widget.onPay,
                  child: Container(
                    height: 48.h,
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    decoration: BoxDecoration(
                      color: _roleAccent,
                      borderRadius: BorderRadius.circular(48.r),
                    ),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.payment,
                            color: AppColors.whiteColor,
                            size: 18.sp,
                          ),
                          SizedBox(width: 8.w),
                          InterText(
                            text: widget.booking!.totalAmount != null
                                ? 'service_card_pay_with_amount'.trParams({
                                    'amount': CurrencyHelper.format(
                                      widget.currencyCode,
                                      widget.booking!.totalAmount!,
                                    ),
                                  })
                                : 'service_card_pay_now'.tr,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                            color: AppColors.whiteColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        // Show Cancel button for other booking statuses (but not for paid bookings)
        if (!isPaid) {
          return Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: widget.onCancel,
                  child: Container(
                    height: 48.h,
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.primaryColor),
                      borderRadius: BorderRadius.circular(48.r),
                    ),
                    child: Center(
                      child: InterText(
                        text: 'service_card_cancel'.tr,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                        color: AppColors.greyText,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        // For paid bookings, show a chat button
        return Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap:
                    widget.onStartChat ??
                    () {
                      // Default: navigate to detail screen where chat can be started
                      if (widget.sitterId != null &&
                          widget.sitterId!.isNotEmpty) {
                        Get.to(
                          () => ServiceProviderDetailScreen(
                            sitterId: widget.sitterId!,
                            status: widget.status,
                            booking: widget.booking,
                          ),
                        );
                      }
                    },
                child: Container(
                  height: 48.h,
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  decoration: BoxDecoration(
                    color: _roleAccent,
                    borderRadius: BorderRadius.circular(48.r),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          color: AppColors.whiteColor,
                          size: 18.sp,
                        ),
                        SizedBox(width: 8.w),
                        InterText(
                          text: 'service_card_chat'.tr,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                          color: AppColors.whiteColor,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
    }
  }
}

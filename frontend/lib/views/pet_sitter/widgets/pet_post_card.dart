import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/app_images.dart';
import 'package:hopetsit/utils/post_price_estimator.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:hopetsit/widgets/report_dialog.dart';

class PetPostCard extends StatelessWidget {
  final String userName;
  final String userEmail;
  final String? userAvatar;
  final List<String> petImages; // Changed to list
  final String? postBody;
  final String? petName;
  final String? serviceTypes;
  final String? dateRange;
  final String? location;
  final bool isNetworkImage;
  final int likeCount;
  final int commentCount;
  final bool isLiked;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final VoidCallback? onDelete;
  /// v18.6 — callback "Modifier l'annonce". Si null, l'icône stylo n'est
  /// pas affichée. Désactivée UI-side quand isReserved=true pour éviter
  /// de modifier une annonce déjà prise.
  final VoidCallback? onEdit;
  final VoidCallback? onViewPetDetails;
  final VoidCallback? onSendRequest;
  final bool isRequestLoading;
  final String? requestButtonText;
  final bool isCancelRequest;
  final VoidCallback? onBlockUser;
  final VoidCallback? onReportPost;

  /// v16.3g — estimated earning for the current walker/sitter viewing
  /// this post. When provided, a price block (brut + net + breakdown) is
  /// displayed right above the action buttons.
  final PostPriceEstimate? priceEstimate;

  /// v16.3h — role of the viewer ('walker' | 'sitter' | null). Controls the
  /// accent color of the price block (green for walker, blue for sitter).
  final String? viewerRole;

  /// Session v17.1 — when the post has an active reservation (owner already
  /// accepted a sitter/walker application), the card shows a "Reserved"
  /// badge in the header so other providers know the slot is taken.
  /// [reservedProviderRole] ('walker' | 'sitter' | null) colours the badge.
  final bool isReserved;
  /// v18.6 — #24 : true quand l'owner consulte SA propre publication.
  /// Force la couleur du badge "Réservé" en orange HoPetSit pour un état
  /// immédiatement lisible côté owner. Sur le feed sitter/walker, garde
  /// la couleur du provider qui a réservé.
  final bool ownerViewOfOwnPost;
  final String? reservedProviderRole;

  const PetPostCard({
    super.key,
    required this.userName,
    required this.userEmail,
    this.userAvatar,
    required this.petImages, // Changed to list
    this.postBody,
    this.petName,
    this.serviceTypes,
    this.dateRange,
    this.location,
    this.isNetworkImage = false,
    required this.likeCount,
    required this.commentCount,
    this.isLiked = false,
    this.onLike,
    this.onComment,
    this.onShare,
    this.onDelete,
    this.onEdit,
    this.onViewPetDetails,
    this.onSendRequest,
    this.isRequestLoading = false,
    this.requestButtonText,
    this.isCancelRequest = false,
    this.onBlockUser,
    this.onReportPost,
    this.priceEstimate,
    this.viewerRole,
    this.isReserved = false,
    this.ownerViewOfOwnPost = false,
    this.reservedProviderRole,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(19.r),
        border: Border.all(
          color: AppColors.divider(context).withValues(alpha: 0.35),
          width: 1.w,
        ),
        boxShadow: AppColors.cardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with profile info
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: AppColors.inputFill(context),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(19.r),
                topRight: Radius.circular(19.r),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 25.r,
                  backgroundColor: AppColors.primaryColor,
                  child: CircleAvatar(
                    radius: 22.r,
                    backgroundImage:
                        userAvatar != null && userAvatar!.isNotEmpty
                        ? NetworkImage(userAvatar!)
                        : AssetImage(AppImages.placeholderImage)
                              as ImageProvider,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: InterText(
                              text: userName,
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary(context),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isReserved) ...[
                            SizedBox(width: 8.w),
                            _buildReservedBadge(),
                          ],
                        ],
                      ),
                      SizedBox(height: 3.h),
                      InterText(
                        text: 'role_pet_owner'.tr,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary(context),
                      ),
                    ],
                  ),
                ),
                // v18.6 — stylo Modifier (désactivé si isReserved) + poubelle
                // relookée (rond rouge pastel, icône blanche). Les 2 sont
                // côte à côte dans un wrapper animé.
                if (onEdit != null)
                  Container(
                    margin: EdgeInsets.only(right: 4.w),
                    decoration: BoxDecoration(
                      color: isReserved
                          ? AppColors.grey300Color.withValues(alpha: 0.4)
                          : const Color(0xFF2563EB).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: isReserved ? null : onEdit,
                      icon: Icon(
                        Icons.edit_outlined,
                        color: isReserved
                            ? AppColors.grey500Color
                            : const Color(0xFF2563EB),
                        size: 20.sp,
                      ),
                      tooltip: 'post_action_edit'.tr,
                    ),
                  ),
                if (onDelete != null)
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.errorColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: onDelete,
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        color: AppColors.errorColor,
                        size: 20.sp,
                      ),
                      tooltip: 'post_action_delete'.tr,
                    ),
                  ),
                if (onBlockUser != null || onReportPost != null)
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, size: 20.sp, color: AppColors.textSecondary(context)),
                    tooltip: 'post_more_options'.tr,
                    onSelected: (value) {
                      if (value == 'block' && onBlockUser != null) {
                        onBlockUser!();
                      } else if (value == 'report' && onReportPost != null) {
                        onReportPost!();
                      }
                    },
                    itemBuilder: (context) => [
                      if (onBlockUser != null)
                        PopupMenuItem<String>(
                          value: 'block',
                          child: Row(
                            children: [
                              Icon(Icons.block, color: AppColors.errorColor, size: 18.sp),
                              SizedBox(width: 8.w),
                              Text('post_action_block_user'.tr),
                            ],
                          ),
                        ),
                      if (onReportPost != null)
                        PopupMenuItem<String>(
                          value: 'report',
                          child: Row(
                            children: [
                              Icon(Icons.flag_outlined, color: AppColors.textSecondary(context), size: 18.sp),
                              SizedBox(width: 8.w),
                              Text('post_action_report'.tr),
                            ],
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),

          // Show media only when the post actually has media images.
          if (petImages.isNotEmpty)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: _buildImagesGrid(context),
            )
          else
            SizedBox(height: 4.h),

          if ((postBody ?? '').trim().isNotEmpty ||
              (petName ?? '').trim().isNotEmpty ||
              (serviceTypes ?? '').trim().isNotEmpty ||
              (dateRange ?? '').trim().isNotEmpty ||
              (location ?? '').trim().isNotEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 8.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if ((postBody ?? '').trim().isNotEmpty) ...[
                    InterText(
                      text: _localizePostBody(postBody!.trim()),
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textSecondary(context),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 10.h),
                  ],
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 12.h),
                    decoration: BoxDecoration(
                      color: AppColors.inputFill(context),
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(
                        color: AppColors.divider(context).withValues(alpha: 0.4),
                        width: 1.w,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Section header — "Demande de réservation"
                        Row(
                          children: [
                            Container(
                              width: 4.w,
                              height: 14.h,
                              decoration: BoxDecoration(
                                color: AppColors.primaryColor,
                                borderRadius: BorderRadius.circular(2.r),
                              ),
                            ),
                            SizedBox(width: 8.w),
                            InterText(
                              text: 'post_card_reservation_request'.tr,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary(context),
                            ),
                          ],
                        ),
                        SizedBox(height: 10.h),
                        if ((petName ?? '').trim().isNotEmpty)
                          _buildDetailRow(Icons.pets_outlined, petName!.trim()),
                        if ((serviceTypes ?? '').trim().isNotEmpty)
                          _buildDetailRow(
                            Icons.volunteer_activism_outlined,
                            _localizedServices(serviceTypes!.trim()),
                          ),
                        if ((dateRange ?? '').trim().isNotEmpty)
                          _buildDetailRow(
                            Icons.calendar_today_outlined,
                            dateRange!.trim(),
                          ),
                        if ((location ?? '').trim().isNotEmpty)
                          _buildDetailRow(
                            Icons.location_on_outlined,
                            location!.trim(),
                            isLast: true,
                          ),
                      ],
                    ),
                  ),
                  if (priceEstimate != null && !priceEstimate!.isZero) ...[
                    SizedBox(height: 10.h),
                    _buildPriceBlock(context, priceEstimate!),
                  ],
                  if (onViewPetDetails != null || onSendRequest != null) ...[
                    SizedBox(height: 10.h),
                    Row(
                      children: [
                        if (onViewPetDetails != null)
                          Expanded(
                            child: _buildSoftButton(
                              icon: Icons.visibility_outlined,
                              text: 'sitter_post_pet_details'.tr,
                              onTap: onViewPetDetails,
                            ),
                          ),
                        if (onViewPetDetails != null && onSendRequest != null)
                          SizedBox(width: 8.w),
                        if (onSendRequest != null)
                          Expanded(
                            // v18.5 — #18 : quand le post est réservé
                            // (badge "Réservé"), on désactive le bouton
                            // "Envoyer la demande" et on le remplace par
                            // un label "Déjà réservé" grisé. Empêche
                            // d'envoyer une candidature sur une annonce
                            // déjà prise.
                            child: _buildPrimaryButton(
                              onTap: (isRequestLoading || isReserved)
                                  ? null
                                  : onSendRequest,
                              isLoading: isRequestLoading,
                              isCancelRequest: isCancelRequest,
                              buttonText: isReserved
                                  ? 'post_already_reserved_cta'.tr
                                  : (requestButtonText ??
                                      (isCancelRequest
                                          ? 'service_card_cancel'.tr
                                          : 'send_request_button'.tr)),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

          // Like count (comment counts hidden — same as comment action below)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            child: Row(
              children: [
                Image.asset(AppImages.totalLikeIcon, width: 16.w, height: 16.h),
                SizedBox(width: 4.w),
                InterText(
                  text: likeCount.toString(),
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary(context),
                ),
                // GestureDetector(
                //   onTap: onComment,
                //   child: InterText(
                //     text: commentCount == 1
                //         ? 'post_comments_count_singular'.trParams({
                //             'count': commentCount.toString(),
                //           })
                //         : 'post_comments_count_plural'.trParams({
                //             'count': commentCount.toString(),
                //           }),
                //     fontSize: 12.sp,
                //     fontWeight: FontWeight.w400,
                //     color: AppColors.greyText,
                //   ),
                // ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Divider(color: AppColors.divider(context).withValues(alpha: 0.2)),
          ),

          // Action buttons (comment hidden — keep like + share balanced)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: Center(
                    child: _buildActionButton(
                      context: context,
                      icon: AppImages.likeIcon,
                      label: 'post_action_like'.tr,
                      isActive: isLiked,
                      onTap: onLike,
                    ),
                  ),
                ),
                // Expanded(
                //   child: Center(
                //     child: _buildActionButton(
                //       icon: AppImages.commentLikeIcon,
                //       label: 'post_action_comment'.tr,
                //       onTap: onComment,
                //     ),
                //   ),
                // ),
                Expanded(
                  child: Center(
                    child: _buildActionButton(
                      context: context,
                      icon: AppImages.sendIcon,
                      label: 'post_action_share'.tr,
                      onTap: onShare,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required String icon,
    required String label,
    bool isActive = false,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Image.asset(
            icon,
            width: 20.w,
            height: 20.h,
            color: isActive ? AppColors.primaryColor : AppColors.textSecondary(context),
          ),
          SizedBox(height: 4.h),
          InterText(
            text: label,
            fontSize: 12.sp,
            fontWeight: FontWeight.w400,
            color: isActive ? AppColors.primaryColor : AppColors.textSecondary(context),
          ),
        ],
      ),
    );
  }

  // Maps known English post body strings from backend to localized versions.
  String _localizePostBody(String body) {
    switch (body.toLowerCase()) {
      case 'reservation request':
        return 'post_card_reservation_request'.tr;
      default:
        return body;
    }
  }

  // Maps raw backend service strings (e.g. "house sitting", "dog walking")
  // to localized labels. Preserves unknown values verbatim.
  String _localizedServices(String raw) {
    final items = raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty);
    String map(String s) {
      switch (s.toLowerCase()) {
        case 'house sitting':
        case 'house_sitting':
          return 'post_card_service_house_sitting'.tr;
        case 'dog walking':
        case 'dog_walking':
          return 'post_card_service_dog_walking'.tr;
        case 'pet sitting':
        case 'pet_sitting':
          return 'post_card_service_pet_sitting'.tr;
        case 'pet grooming':
        case 'pet_grooming':
          return 'post_card_service_pet_grooming'.tr;
        case 'pet training':
        case 'pet_training':
          return 'post_card_service_pet_training'.tr;
        case 'overnight care':
        case 'overnight_care':
          return 'post_card_service_overnight_care'.tr;
        case 'pet boarding':
        case 'pet_boarding':
          return 'post_card_service_pet_boarding'.tr;
        default:
          return s;
      }
    }
    return items.map(map).join(', ');
  }

  Widget _buildDetailRow(IconData icon, String text, {bool isLast = false}) {
    return Builder(
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: isLast ? 0 : 8.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 26.w,
              height: 26.w,
              decoration: BoxDecoration(
                color: AppColors.primaryColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8.r),
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                size: 14.sp,
                color: AppColors.primaryColor,
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: InterText(
                text: text,
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary(context),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Session v17.1 — tiny "Reserved" pill rendered in the card header when
  /// the post has an active reservation. Colour matches the provider role
  /// that reserved it (green walker / blue sitter). Uses the `reserved_badge`
  /// translation key; falls back to "Réservé" when the key is missing.
  Widget _buildReservedBadge() {
    final role = (reservedProviderRole ?? '').toLowerCase();
    // v18.6 — #24 : quand l'owner visualise SES propres publications
    // (ownerViewOfOwnPost=true, passé depuis "Mes publications"), on force
    // la couleur orange HoPetSit pour que le badge soit immédiatement
    // reconnaissable comme état du post. Pour les autres rôles (sitter/
    // walker qui voient le post d'un owner), on garde la couleur du
    // provider qui a réservé (vert walker / bleu sitter).
    final Color accent = ownerViewOfOwnPost
        ? AppColors.primaryColor
        : (role == 'walker'
            ? const Color(0xFF16A34A)
            : role == 'sitter'
                ? const Color(0xFF2563EB)
                : const Color(0xFF6B7280));
    final String label = 'reserved_badge'.tr == 'reserved_badge'
        ? 'Réservé'
        : 'reserved_badge'.tr;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_rounded, size: 11.sp, color: accent),
          SizedBox(width: 4.w),
          InterText(
            text: label,
            fontSize: 10.sp,
            fontWeight: FontWeight.w700,
            color: accent,
          ),
        ],
      ),
    );
  }

  /// v16.3g — earning estimate block for the walker/sitter viewing this
  /// post. v16.3h: accent color depends on viewer role (green for walker,
  /// blue for sitter, fallback to primary color).
  Widget _buildPriceBlock(BuildContext context, PostPriceEstimate est) {
    final role = (viewerRole ?? '').toLowerCase();
    Color accent;
    if (role == 'walker') {
      accent = const Color(0xFF16A34A); // green-600
    } else if (role == 'sitter') {
      accent = const Color(0xFF2563EB); // blue-600
    } else {
      accent = AppColors.primaryColor;
    }
    final brutLabel = _formatMoneyShort(est.brut, est.currency);
    final netLabel = _formatMoneyShort(est.net, est.currency);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.10),
            accent.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: accent.withValues(alpha: 0.25),
          width: 1.w,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.payments_outlined, size: 16.sp, color: accent),
              SizedBox(width: 6.w),
              InterText(
                text: 'post_price_estimate_title'.tr,
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
                color: accent,
              ),
            ],
          ),
          SizedBox(height: 8.h),
          // Brut + net side-by-side.
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InterText(
                      text: 'post_price_brut_label'.tr,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary(context),
                    ),
                    SizedBox(height: 2.h),
                    InterText(
                      text: brutLabel,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary(context),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1.w,
                height: 28.h,
                color: accent.withValues(alpha: 0.25),
                margin: EdgeInsets.symmetric(horizontal: 10.w),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InterText(
                      text: 'post_price_net_label'.tr,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w500,
                      color: accent,
                    ),
                    SizedBox(height: 2.h),
                    InterText(
                      text: netLabel,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          InterText(
            text: est.breakdown,
            fontSize: 10.sp,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary(context),
          ),
        ],
      ),
    );
  }

  String _formatMoneyShort(double amount, String currency) {
    final symbol = _symbolFor(currency);
    final isInt = amount == amount.roundToDouble();
    final formatted = isInt
        ? amount.toInt().toString()
        : amount.toStringAsFixed(2);
    return '$symbol$formatted';
  }

  String _symbolFor(String code) {
    switch (code.toUpperCase()) {
      case 'EUR':
        return '€';
      case 'USD':
      case 'CAD':
      case 'AUD':
        return '\$';
      case 'GBP':
        return '£';
      default:
        return '$code ';
    }
  }

  Widget _buildSoftButton({
    required IconData icon,
    required String text,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 9.h),
        decoration: BoxDecoration(
          color: AppColors.primaryColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(
            color: AppColors.primaryColor.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16.sp, color: AppColors.primaryColor),
            SizedBox(width: 6.w),
            Flexible(
              child: InterText(
                text: text,
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
                color: AppColors.primaryColor,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrimaryButton({
    required VoidCallback? onTap,
    required bool isLoading,
    required bool isCancelRequest,
    required String buttonText,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18.r),
      child: Builder(
        builder: (context) => Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 9.h),
          decoration: BoxDecoration(
            color: isCancelRequest
                ? AppColors.card(context)
                : AppColors.primaryColor,
            borderRadius: BorderRadius.circular(18.r),
            border: Border.all(
              color: isCancelRequest
                  ? AppColors.errorColor
                  : AppColors.primaryColor,
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading) ...[
                SizedBox(
                  width: 14.w,
                  height: 14.h,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isCancelRequest ? AppColors.errorColor : Colors.white,
                    ),
                  ),
                ),
                SizedBox(width: 6.w),
              ] else ...[
                Icon(
                  isCancelRequest ? Icons.cancel_outlined : Icons.send_outlined,
                  size: 16.sp,
                  color: isCancelRequest ? AppColors.errorColor : Colors.white,
                ),
                SizedBox(width: 6.w),
              ],
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: InterText(
                    text: isLoading
                        ? (isCancelRequest
                              ? 'request_cancel_button_cancelling'.tr
                              : 'send_request_button_sending'.tr)
                        : buttonText,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: isCancelRequest ? AppColors.errorColor : Colors.white,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagesGrid(BuildContext context) {
    final imageCount = petImages.length;
    final spacing = 4.w; // Consistent spacing

    if (imageCount == 1) {
      // Single image - full width
      return _buildImageItem(context, petImages[0], 0, 1);
    } else if (imageCount == 2) {
      // Two images - side by side
      return Row(
        children: [
          Expanded(child: _buildImageItem(context, petImages[0], 0, 2)),
          SizedBox(width: spacing),
          Expanded(child: _buildImageItem(context, petImages[1], 1, 2)),
        ],
      );
    } else if (imageCount == 3) {
      // Three images - one large, two small
      return Row(
        children: [
          Expanded(
            flex: 2,
            child: _buildImageItem(context, petImages[0], 0, 3),
          ),
          SizedBox(width: spacing),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildImageItem(context, petImages[1], 1, 3),
                SizedBox(height: spacing),
                _buildImageItem(context, petImages[2], 2, 3),
              ],
            ),
          ),
        ],
      );
    } else if (imageCount == 4) {
      // Four images - 2x2 grid
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildImageItem(context, petImages[0], 0, 4)),
              SizedBox(width: spacing),
              Expanded(child: _buildImageItem(context, petImages[1], 1, 4)),
            ],
          ),
          SizedBox(height: spacing),
          Row(
            children: [
              Expanded(child: _buildImageItem(context, petImages[2], 2, 4)),
              SizedBox(width: spacing),
              Expanded(child: _buildImageItem(context, petImages[3], 3, 4)),
            ],
          ),
        ],
      );
    } else {
      // More than 4 images - show first 4 in 2x2 grid with overlay
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildImageItem(context, petImages[0], 0, imageCount),
              ),
              SizedBox(width: spacing),
              Expanded(
                child: _buildImageItem(context, petImages[1], 1, imageCount),
              ),
            ],
          ),
          SizedBox(height: spacing),
          Row(
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildImageItem(context, petImages[2], 2, imageCount),
                    if (imageCount > 4)
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12.r),
                          color: Colors.black.withValues(alpha: 0.6),
                        ),
                        child: Center(
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 16.w,
                              vertical: 8.h,
                            ),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black.withValues(alpha: 0.3),
                            ),
                            child: InterText(
                              text: '+${imageCount - 4}',
                              fontSize: 24.sp,
                              fontWeight: FontWeight.bold,
                              color: AppColors.whiteColor,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(width: spacing),
              Expanded(
                child: _buildImageItem(context, petImages[3], 3, imageCount),
              ),
            ],
          ),
        ],
      );
    }
  }

  Widget _buildImageItem(
    BuildContext context,
    String imageUrl,
    int index,
    int total,
  ) {
    final height = _getImageHeight(total, index);
    final borderRadius = 12.r; // Consistent border radius

    return GestureDetector(
      onTap: () => _openPhotoViewer(context, index),
      onLongPress: () => ReportDialog.show(
        context: context,
        targetType: 'photo',
        targetId: '',
        photoUrl: imageUrl,
      ),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          color: AppColors.lightGrey,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: Stack(
            fit: StackFit.expand,
            children: [
              isNetworkImage
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
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
                      errorWidget: (context, url, error) => Container(
                        color: AppColors.lightGrey,
                        child: _buildImageLoadError(
                          context,
                          imageUrl: url,
                          isNetwork: true,
                        ),
                      ),
                    )
                  : Image.asset(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: AppColors.lightGrey,
                          child: _buildImageLoadError(context),
                        );
                      },
                    ),
              // Subtle overlay on hover/tap for better UX
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _openPhotoViewer(context, index),
                  borderRadius: BorderRadius.circular(borderRadius),
                  child: Container(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _getImageHeight(int total, int index) {
    // More consistent heights
    if (total == 1) {
      return 280.h; // Single image - slightly reduced for consistency
    } else if (total == 2) {
      return 220.h; // Two images - taller for better visibility
    } else if (total == 3) {
      if (index == 0) {
        return 220.h; // Large image
      } else {
        return 108.h; // Small images - calculated to fit perfectly
      }
    } else {
      // 4 or more images - consistent square-ish aspect ratio
      return 160.h;
    }
  }

  Widget _buildImageLoadError(
    BuildContext context, {
    String? imageUrl,
    bool isNetwork = false,
  }) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.broken_image_outlined,
            size: 26.sp,
            color: AppColors.textSecondary(context),
          ),
          SizedBox(height: 8.h),
          TextButton.icon(
            onPressed: () async {
              if (isNetwork && imageUrl != null && imageUrl.isNotEmpty) {
                await CachedNetworkImage.evictFromCache(imageUrl);
              }
              (context as Element).markNeedsBuild();
            },
            icon: Icon(
              Icons.refresh,
              size: 16.sp,
              color: AppColors.primaryColor,
            ),
            label: InterText(
              text: 'common_refresh'.tr,
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              color: AppColors.primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  void _openPhotoViewer(BuildContext context, int initialIndex) {
    Get.to(
      () => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          iconTheme: const IconThemeData(color: Colors.white),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Get.back(),
          ),
        ),
        body: PhotoViewGallery.builder(
          scrollPhysics: const BouncingScrollPhysics(),
          builder: (BuildContext context, int index) {
            return PhotoViewGalleryPageOptions(
              imageProvider: isNetworkImage
                  ? NetworkImage(petImages[index])
                  : AssetImage(petImages[index]) as ImageProvider,
              initialScale: PhotoViewComputedScale.contained,
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 2,
            );
          },
          itemCount: petImages.length,
          loadingBuilder: (context, event) => Center(
            child: CircularProgressIndicator(
              value: event == null
                  ? 0
                  : event.cumulativeBytesLoaded / event.expectedTotalBytes!,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
            ),
          ),
          backgroundDecoration: const BoxDecoration(color: Colors.black),
          pageController: PageController(initialPage: initialIndex),
          onPageChanged: (index) {
            // Optional: track page changes
          },
        ),
      ),
    );
  }
}

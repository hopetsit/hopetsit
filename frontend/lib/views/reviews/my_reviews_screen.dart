import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/views/profile/widgets/profile_ui_kit.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/repositories/owner_repository.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';

/// v23.1.292 — Daniel : "je puisse cliquer sur Avis et lire tous mes
/// commentaires". Écran qui liste les avis reçus par un prestataire
/// (sitter/walker), avec sa note moyenne et le nombre d'avis. Les données
/// viennent du profil public (champ `reviews`).
class MyReviewsScreen extends StatelessWidget {
  final List<dynamic> reviews;
  final double rating;
  final int reviewsCount;
  final Color accent;

  const MyReviewsScreen({
    super.key,
    required this.reviews,
    this.rating = 0.0,
    this.reviewsCount = 0,
    this.accent = const Color(0xFFC92A12),
  });

  String _asStr(dynamic v) => v == null ? '' : v.toString();

  // v23.1.294 — signaler un avis (insulte/abus) → POST /reviews/:id/report.
  // Le backend alerte l'admin par mail + l'affiche dans l'onglet Signalés.
  Future<void> _report(BuildContext context, String reviewId) async {
    final ok = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: AppColors.card(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        title: PoppinsText(
          text: 'review_report'.tr,
          fontSize: 16.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary(context),
        ),
        content: InterText(
          text: 'review_report_confirm'.tr,
          fontSize: 14.sp,
          color: AppColors.textPrimary(context),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: InterText(
              text: 'common_cancel'.tr,
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              // v571 — mode sombre : #717680 disparaît sur le fond de carte.
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.textSecondaryDark
                  : AppColors.grey500Color,
            ),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: InterText(
              text: 'review_report'.tr,
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: Colors.red,
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Get.find<OwnerRepository>().reportReview(reviewId: reviewId);
      CustomSnackbar.showSuccess(
        title: 'common_success'.tr,
        message: 'review_reported'.tr,
      );
    } catch (_) {
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'review_report_failed'.tr,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = reviewsCount > 0 ? reviewsCount : reviews.length;
    // v565 — point 39 : kit Profil (carte de note moyenne avec étoiles,
    // cartes d'avis sans bordure, état vide illustré).
    return ProfileSubPageScaffold(
      title: 'reviews_title'.tr,
      accent: accent,
      scroll: false,
      padding: EdgeInsets.zero,
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 4.h),
            child: _summaryCard(context, count),
          ),
          Expanded(
            child: reviews.isEmpty
                ? ProfileEmptyState(
                    icon: Icons.star_outline_rounded,
                    title: 'reviews_empty_title'.tr,
                    message: 'reviews_empty_body'.tr,
                    accent: accent,
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 28.h),
                    itemCount: reviews.length,
                    separatorBuilder: (_, __) => SizedBox(height: 10.h),
                    itemBuilder: (context, i) => _reviewItem(context, reviews[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _stars(double value, {double size = 14}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        IconData icon;
        if (value >= i + 1) {
          icon = Icons.star_rounded;
        } else if (value > i && value < i + 1) {
          icon = Icons.star_half_rounded;
        } else {
          icon = Icons.star_outline_rounded;
        }
        return Icon(icon, color: const Color(0xFFF4B400), size: size.sp);
      }),
    );
  }

  Widget _summaryCard(BuildContext context, int count) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 18.w),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: AppColors.cardShadow(context),
      ),
      child: Row(
        children: [
          Container(
            width: 56.w,
            height: 56.w,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Icon(Icons.star_rounded, color: const Color(0xFFF4B400), size: 30.sp),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    PoppinsText(
                      text: rating.toStringAsFixed(1),
                      fontSize: 26.sp,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary(context),
                    ),
                    SizedBox(width: 4.w),
                    Padding(
                      padding: EdgeInsets.only(bottom: 5.h),
                      child: InterText(
                        text: '/5',
                        fontSize: 13.sp,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Padding(
                      padding: EdgeInsets.only(bottom: 7.h),
                      child: _stars(rating, size: 15),
                    ),
                  ],
                ),
                SizedBox(height: 2.h),
                InterText(
                  text: '${'reviews_average'.tr} · $count ${'stat_reviews'.tr}',
                  fontSize: 12.5.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _reviewItem(BuildContext context, dynamic review) {
    final Map r = review is Map ? review : const {};
    final Map reviewer = r['reviewer'] is Map ? r['reviewer'] as Map : const {};
    final name = _asStr(r['reviewerName']).isNotEmpty
        ? _asStr(r['reviewerName'])
        : _asStr(reviewer['name']);
    // v23.1.296 — l'avatar peut être une string OU un objet {url}.
    final rawAvatar = reviewer['avatar'];
    final image = _asStr(r['reviewerImage']).isNotEmpty
        ? _asStr(r['reviewerImage'])
        : (rawAvatar is Map ? _asStr(rawAvatar['url']) : _asStr(rawAvatar));
    final ratingVal = (r['rating'] as num?)?.toDouble() ?? 0.0;
    final comment = _asStr(r['comment']);
    final id = _asStr(r['id']).isNotEmpty ? _asStr(r['id']) : _asStr(r['_id']);
    final displayName = name.trim().isNotEmpty
        ? name.trim()
        : 'sitter_detail_anonymous_reviewer'.tr;
    final createdAt = _asStr(r['createdAt']);
    final dateStr = createdAt.length >= 10 ? createdAt.substring(0, 10) : '';

    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(18.r),
        boxShadow: AppColors.cardShadow(context),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          image.startsWith('http')
              ? ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: image,
                    width: 44.w,
                    height: 44.w,
                    memCacheWidth: 138,
                    fit: BoxFit.cover,
                    errorWidget: (c, u, e) => _avatarFallback(),
                  ),
                )
              : _avatarFallback(),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: PoppinsText(
                        text: displayName,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: 6.w),
                    // v23.1.294 — signaler un avis insultant/abusif.
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: id.isEmpty ? null : () => _report(context, id),
                      child: Padding(
                        padding: EdgeInsets.all(2.w),
                        child: Icon(Icons.flag_outlined,
                            size: 17.sp, color: AppColors.textSecondary(context)),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 3.h),
                Row(
                  children: [
                    _stars(ratingVal, size: 13),
                    if (dateStr.isNotEmpty) ...[
                      SizedBox(width: 8.w),
                      Flexible(
                        child: InterText(
                          text: dateStr,
                          fontSize: 11.sp,
                          color: AppColors.textSecondary(context),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
                if (comment.isNotEmpty) ...[
                  SizedBox(height: 6.h),
                  InterText(
                    text: comment,
                    fontSize: 13.sp,
                    color: AppColors.textPrimary(context),
                    height: 1.4,
                    maxLines: 12,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarFallback() => Container(
        width: 44.w,
        height: 44.w,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.person_rounded, size: 24.sp, color: accent),
      );
}

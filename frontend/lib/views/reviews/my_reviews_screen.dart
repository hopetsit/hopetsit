import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/utils/app_colors.dart';
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
    this.accent = const Color(0xFFEF4324),
  });

  String _asStr(dynamic v) => v == null ? '' : v.toString();

  // v23.1.294 — signaler un avis (insulte/abus) → POST /reviews/:id/report.
  // Le backend alerte l'admin par mail + l'affiche dans l'onglet Signalés.
  Future<void> _report(BuildContext context, String reviewId) async {
    final ok = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: AppColors.card(context),
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
              color: AppColors.grey500Color,
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
    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      appBar: AppBar(
        backgroundColor: AppColors.appBar(context),
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: accent),
        leading: const BackButton(),
        title: PoppinsText(
          text: 'reviews_title'.tr,
          fontSize: 18.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // En-tête : note moyenne + nombre d'avis.
            Container(
              width: double.infinity,
              margin: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 4.h),
              padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 18.w),
              decoration: BoxDecoration(
                color: AppColors.card(context),
                borderRadius: BorderRadius.circular(16.r),
                boxShadow: AppColors.cardShadow(context),
              ),
              child: Row(
                children: [
                  Icon(Icons.star_rounded, color: Colors.amber, size: 34.sp),
                  SizedBox(width: 10.w),
                  PoppinsText(
                    text: rating.toStringAsFixed(1),
                    fontSize: 26.sp,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary(context),
                  ),
                  SizedBox(width: 4.w),
                  Padding(
                    padding: EdgeInsets.only(top: 8.h),
                    child: InterText(
                      text: '/5',
                      fontSize: 14.sp,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                  const Spacer(),
                  InterText(
                    text: '$count ${'stat_reviews'.tr}',
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: reviews.isEmpty
                  ? Center(
                      child: InterText(
                        text: 'sitter_detail_no_reviews'.tr,
                        fontSize: 14.sp,
                        color: AppColors.greyColor,
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.all(16.w),
                      itemCount: reviews.length,
                      separatorBuilder: (_, __) => SizedBox(height: 12.h),
                      itemBuilder: (context, i) => _reviewItem(context, reviews[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reviewItem(BuildContext context, dynamic review) {
    final Map r = review is Map ? review : const {};
    final Map reviewer = r['reviewer'] is Map ? r['reviewer'] as Map : const {};
    final name = _asStr(r['reviewerName']).isNotEmpty
        ? _asStr(r['reviewerName'])
        : _asStr(reviewer['name']);
    final image = _asStr(r['reviewerImage']).isNotEmpty
        ? _asStr(r['reviewerImage'])
        : _asStr(reviewer['avatar']);
    final ratingVal = (r['rating'] as num?)?.toDouble() ?? 0.0;
    final comment = _asStr(r['comment']);
    final id = _asStr(r['id']).isNotEmpty ? _asStr(r['id']) : _asStr(r['_id']);
    final displayName = name.trim().isNotEmpty
        ? name.trim()
        : 'sitter_detail_anonymous_reviewer'.tr;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: AppColors.cardShadow(context),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          image.startsWith('http')
              ? ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: image,
                    width: 46.w,
                    height: 46.w,
                    memCacheWidth: 138,
                    fit: BoxFit.cover,
                    errorWidget: (c, u, e) => CircleAvatar(
                      radius: 23.r,
                      backgroundColor: AppColors.grey300Color,
                      child: Icon(Icons.person,
                          size: 24.sp, color: AppColors.greyColor),
                    ),
                  ),
                )
              : CircleAvatar(
                  radius: 23.r,
                  backgroundColor: AppColors.grey300Color,
                  child: Icon(Icons.person,
                      size: 24.sp, color: AppColors.greyColor),
                ),
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
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    ...List.generate(5, (i) {
                      return Icon(
                        i < ratingVal.round() ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 14.sp,
                      );
                    }),
                    SizedBox(width: 6.w),
                    // v23.1.294 — signaler un avis insultant/abusif.
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: id.isEmpty ? null : () => _report(context, id),
                      child: Icon(Icons.flag_outlined,
                          size: 16.sp, color: AppColors.greyColor),
                    ),
                  ],
                ),
                if (comment.isNotEmpty) ...[
                  SizedBox(height: 6.h),
                  InterText(
                    text: comment,
                    fontSize: 13.sp,
                    color: AppColors.textSecondary(context),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

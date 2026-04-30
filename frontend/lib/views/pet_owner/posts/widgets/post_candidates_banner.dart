import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:hopetsit/controllers/applications_controller.dart';
import 'package:hopetsit/models/application_model.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/views/pet_owner/posts/widgets/post_candidates_sheet.dart';
import 'package:hopetsit/widgets/app_text.dart';

/// v23.1 — B3 : compact banner shown above an owner's post card when more
/// than one provider has applied. Tapping opens the candidates bottom sheet
/// where the owner can pick the right one.
class PostCandidatesBanner extends StatelessWidget {
  const PostCandidatesBanner({
    super.key,
    required this.postId,
  });

  final String postId;

  List<ApplicationModel> _pendingForPost(ApplicationsController c) {
    return c.applications
        .where((a) =>
            a.postId == postId && a.status.toLowerCase().trim() == 'pending')
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final c = Get.isRegistered<ApplicationsController>()
        ? Get.find<ApplicationsController>()
        : Get.put(ApplicationsController());

    return Obx(() {
      final pending = _pendingForPost(c);
      if (pending.length < 2) return const SizedBox.shrink();
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => PostCandidatesSheet.show(
          context: context,
          postId: postId,
        ),
        child: Container(
          margin: EdgeInsets.only(bottom: 10.h),
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primaryColor.withValues(alpha: 0.15),
                AppColors.primaryColor.withValues(alpha: 0.05),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: AppColors.primaryColor.withValues(alpha: 0.4),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32.w,
                height: 32.w,
                decoration: BoxDecoration(
                  color: AppColors.primaryColor,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: PoppinsText(
                  text: '${pending.length}',
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PoppinsText(
                      text: 'candidates_banner_title'
                          .trParams({'count': pending.length.toString()}),
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary(context),
                    ),
                    SizedBox(height: 2.h),
                    InterText(
                      text: 'candidates_banner_subtitle'.tr,
                      fontSize: 12.sp,
                      color: AppColors.textSecondary(context),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14.sp,
                color: AppColors.primaryColor,
              ),
            ],
          ),
        ),
      );
    });
  }
}

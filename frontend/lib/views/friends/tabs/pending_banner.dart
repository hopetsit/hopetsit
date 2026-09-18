// v566 — bandeau « demandes en attente », visible sur TOUS les onglets sauf
// « Demandes ». v23.1.195 — il existe parce qu'un push peut se perdre : une
// demande reçue doit toujours sauter aux yeux. Avant, il recopiait toutes les
// lignes (accepter / refuser / annuler) au-dessus de chaque onglet ; ces
// actions vivent maintenant dans l'onglet « Demandes » (une touche), le
// bandeau ne fait plus qu'y conduire.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/friend_controller.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/views/friends/tabs/friends_ui.dart';
import 'package:hopetsit/widgets/app_text.dart';

class PendingRequestsBanner extends StatelessWidget {
  const PendingRequestsBanner({
    super.key,
    required this.controller,
    required this.accent,
    required this.tabController,
    required this.requestsTabIndex,
  });

  final FriendController controller;
  final Color accent;
  final TabController tabController;
  final int requestsTabIndex;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: tabController,
      builder: (context, _) {
        final onRequestsTab = tabController.index == requestsTabIndex;
        return Obx(() {
          final n = controller.incomingRequests.length +
              controller.incomingFamilyInvitations.length;
          final visible = n > 0 && !onRequestsTab;
          return AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: !visible
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 2.h),
                    child: Material(
                      color: accent.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(16.r),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => tabController.animateTo(requestsTabIndex),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: 12.w, vertical: 10.h),
                          child: Row(
                            children: [
                              Icon(Icons.mark_email_unread_rounded,
                                  color: accent, size: 18.sp),
                              SizedBox(width: 10.w),
                              Expanded(
                                child: InterText(
                                  text: 'friends_pending_banner_title'.tr,
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary(context),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(width: 8.w),
                              FriendsCountDot(count: n, color: accent),
                              SizedBox(width: 4.w),
                              Icon(Icons.chevron_right_rounded,
                                  color: accent, size: 20.sp),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
          );
        });
      },
    );
  }
}

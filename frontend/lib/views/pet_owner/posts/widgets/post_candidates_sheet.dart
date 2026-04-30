import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:hopetsit/controllers/applications_controller.dart';
import 'package:hopetsit/models/application_model.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/currency_helper.dart';
import 'package:hopetsit/widgets/app_text.dart';

/// v23.1 — B5 : bottom sheet listing every pending candidate for one of the
/// owner's posts. The owner can choose one (auto-rejects the others on the
/// backend) or reject any individually.
class PostCandidatesSheet {
  PostCandidatesSheet._();

  static Future<void> show({
    required BuildContext context,
    required String postId,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CandidatesSheetBody(postId: postId),
    );
  }
}

class _CandidatesSheetBody extends StatefulWidget {
  const _CandidatesSheetBody({required this.postId});

  final String postId;

  @override
  State<_CandidatesSheetBody> createState() => _CandidatesSheetBodyState();
}

enum _SortMode { newest, priceAsc, ratingDesc }

class _CandidatesSheetBodyState extends State<_CandidatesSheetBody> {
  _SortMode _sortMode = _SortMode.newest;
  final RxBool _busy = false.obs;

  ApplicationsController get _controller => Get.isRegistered<ApplicationsController>()
      ? Get.find<ApplicationsController>()
      : Get.put(ApplicationsController());

  List<ApplicationModel> _candidates() {
    final list = _controller.applications
        .where((a) =>
            a.postId == widget.postId &&
            a.status.toLowerCase().trim() == 'pending')
        .toList();
    switch (_sortMode) {
      case _SortMode.priceAsc:
        list.sort((a, b) {
          final pa = a.pricing?.totalPrice ?? double.infinity;
          final pb = b.pricing?.totalPrice ?? double.infinity;
          return pa.compareTo(pb);
        });
        break;
      case _SortMode.ratingDesc:
        list.sort((a, b) => b.sitter.rating.compareTo(a.sitter.rating));
        break;
      case _SortMode.newest:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
    }
    return list;
  }

  Future<void> _accept(ApplicationModel app) async {
    if (_busy.value) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text('candidates_choose_dialog_title'.tr),
        content: Text(
          'candidates_choose_dialog_message'
              .trParams({'name': app.sitter.name}),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text('common_cancel'.tr),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text(
              'candidates_choose_confirm'.tr,
              style: TextStyle(
                color: AppColors.primaryColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    _busy.value = true;
    try {
      await _controller.respondToApplication(
        applicationId: app.id,
        action: 'accept',
      );
      if (mounted) Navigator.of(context).pop();
    } finally {
      _busy.value = false;
    }
  }

  Future<void> _reject(ApplicationModel app) async {
    if (_busy.value) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text('candidates_reject_dialog_title'.tr),
        content: Text(
          'candidates_reject_dialog_message'
              .trParams({'name': app.sitter.name}),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text('common_cancel'.tr),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text(
              'common_reject'.tr,
              style: const TextStyle(color: Color(0xFFE53935)),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    _busy.value = true;
    try {
      await _controller.respondToApplication(
        applicationId: app.id,
        action: 'reject',
      );
    } finally {
      _busy.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Container(
      constraints: BoxConstraints(
        maxHeight: mq.size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: AppColors.scaffold(context),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      padding: EdgeInsets.fromLTRB(
        16.w,
        12.h,
        16.w,
        20.h + mq.padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle.
          Container(
            width: 44.w,
            height: 4.h,
            margin: EdgeInsets.only(bottom: 12.h),
            decoration: BoxDecoration(
              color: AppColors.divider(context),
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          _header(context),
          SizedBox(height: 12.h),
          _sortBar(context),
          SizedBox(height: 8.h),
          Flexible(
            child: Obx(() {
              // Touching .applications/.isLoading inside Obx so reactive.
              final loading = _controller.isLoading.value;
              final list = _candidates();
              if (loading && list.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              if (list.isEmpty) {
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 24.h),
                  child: Center(
                    child: InterText(
                      text: 'candidates_empty'.tr,
                      fontSize: 13.sp,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                );
              }
              return ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: list.length,
                separatorBuilder: (_, __) => SizedBox(height: 10.h),
                itemBuilder: (_, i) => _CandidateCard(
                  app: list[i],
                  busy: _busy,
                  onAccept: () => _accept(list[i]),
                  onReject: () => _reject(list[i]),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.groups_2_rounded,
            size: 22.sp, color: AppColors.primaryColor),
        SizedBox(width: 8.w),
        Expanded(
          child: PoppinsText(
            text: 'candidates_sheet_title'.tr,
            fontSize: 17.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary(context),
          ),
        ),
        IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _sortBar(BuildContext context) {
    Widget chip(String labelKey, _SortMode mode, IconData icon) {
      final selected = _sortMode == mode;
      return Padding(
        padding: EdgeInsets.only(right: 8.w),
        child: ChoiceChip(
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14.sp,
                  color: selected ? Colors.white : AppColors.primaryColor),
              SizedBox(width: 4.w),
              Text(labelKey.tr, style: TextStyle(fontSize: 12.sp)),
            ],
          ),
          selected: selected,
          onSelected: (_) => setState(() => _sortMode = mode),
          selectedColor: AppColors.primaryColor,
          labelStyle: TextStyle(
            color: selected ? Colors.white : AppColors.textPrimary(context),
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      );
    }

    return SizedBox(
      height: 36.h,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          chip('candidates_sort_newest', _SortMode.newest,
              Icons.schedule_rounded),
          chip('candidates_sort_price', _SortMode.priceAsc,
              Icons.euro_rounded),
          chip('candidates_sort_rating', _SortMode.ratingDesc,
              Icons.star_rounded),
        ],
      ),
    );
  }
}

class _CandidateCard extends StatelessWidget {
  const _CandidateCard({
    required this.app,
    required this.busy,
    required this.onAccept,
    required this.onReject,
  });

  final ApplicationModel app;
  final RxBool busy;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  String _priceLabel() {
    final price = app.pricing?.totalPrice;
    if (price == null) return '';
    final currency = app.pricing?.currency ?? 'EUR';
    final symbol = CurrencyHelper.symbol(currency);
    return '$symbol${price.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = app.sitter.avatar.url;
    final isWalker = app.providerRole == 'walker';
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(14.r),
        boxShadow: AppColors.cardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22.r,
                backgroundColor:
                    AppColors.primaryColor.withValues(alpha: 0.1),
                backgroundImage:
                    avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                child: avatarUrl.isEmpty
                    ? Icon(Icons.person, size: 22.sp,
                        color: AppColors.primaryColor)
                    : null,
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: PoppinsText(
                            text: app.sitter.name.isNotEmpty
                                ? app.sitter.name
                                : 'provider_unknown'.tr,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 6.w),
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 6.w, vertical: 2.h),
                          decoration: BoxDecoration(
                            color: (isWalker
                                    ? const Color(0xFF1976D2)
                                    : AppColors.primaryColor)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6.r),
                          ),
                          child: InterText(
                            text: (isWalker ? 'role_walker' : 'role_sitter').tr,
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w600,
                            color: isWalker
                                ? const Color(0xFF1976D2)
                                : AppColors.primaryColor,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 2.h),
                    Row(
                      children: [
                        Icon(Icons.star_rounded,
                            size: 14.sp, color: const Color(0xFFFFB400)),
                        SizedBox(width: 2.w),
                        InterText(
                          text: app.sitter.rating > 0
                              ? '${app.sitter.rating.toStringAsFixed(1)} '
                                  '(${app.sitter.reviewsCount})'
                              : 'candidates_no_reviews'.tr,
                          fontSize: 11.sp,
                          color: AppColors.textSecondary(context),
                        ),
                        if ((app.sitter.city ?? '').isNotEmpty) ...[
                          SizedBox(width: 8.w),
                          Icon(Icons.place_outlined,
                              size: 12.sp,
                              color: AppColors.textSecondary(context)),
                          SizedBox(width: 2.w),
                          Flexible(
                            child: InterText(
                              text: app.sitter.city ?? '',
                              fontSize: 11.sp,
                              color: AppColors.textSecondary(context),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (_priceLabel().isNotEmpty)
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: PoppinsText(
                    text: _priceLabel(),
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryColor,
                  ),
                ),
            ],
          ),
          if (app.description.isNotEmpty) ...[
            SizedBox(height: 8.h),
            InterText(
              text: app.description,
              fontSize: 12.sp,
              color: AppColors.textPrimary(context),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          SizedBox(height: 12.h),
          Obx(
            () => Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy.value ? null : onReject,
                    icon: const Icon(Icons.close_rounded,
                        color: Color(0xFFE53935), size: 18),
                    label: Text(
                      'common_reject'.tr,
                      style: const TextStyle(color: Color(0xFFE53935)),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFE53935)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 10.h),
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: busy.value ? null : onAccept,
                    icon: const Icon(Icons.check_circle_rounded, size: 18),
                    label: Text('candidates_choose_button'.tr),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 10.h),
                      textStyle:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 13.sp),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:hopetsit/widgets/role_chip.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:hopetsit/controllers/applications_controller.dart';
import 'package:hopetsit/models/application_model.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/currency_helper.dart';
import 'package:hopetsit/widgets/action_banner_kit.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/utils/bottom_inset.dart';

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

/// v573 — dialogue de confirmation au patron moderne (accepter / refuser un
/// gardien : le moment décisif de l'annonce). Même grammaire que
/// `CustomConfirmationDialog` — carte `AppColors.card`, coins 22, disque
/// teinté, `PoppinsText` + `InterText`, boutons du kit — mais avec un TITRE
/// propre à chaque action, que le dialogue commun (titre générique
/// « misc569_confirm_title ») ne sait pas porter.
///
/// Renvoie `true` seulement si l'utilisateur confirme. Aucun texte nouveau :
/// les clés i18n sont celles des anciens `AlertDialog`.
Future<bool?> _showModernConfirm({
  required BuildContext context,
  required IconData icon,
  required Color tone,
  required String title,
  required String message,
  required String confirmLabel,
  required bool destructive,
}) {
  final bool dark = Theme.of(context).brightness == Brightness.dark;
  return showDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: dark ? 0.62 : 0.38),
    builder: (dialogCtx) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.symmetric(horizontal: 28.w, vertical: 24.h),
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 360.w),
          child: Container(
            padding: EdgeInsets.fromLTRB(20.w, 24.h, 20.w, 18.h),
            decoration: BoxDecoration(
              color: AppColors.card(dialogCtx),
              borderRadius: BorderRadius.circular(22.r),
              border: Border.all(color: AppColors.divider(dialogCtx)),
              boxShadow: AppColors.cardShadow(dialogCtx),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56.w,
                  height: 56.w,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tone.withValues(alpha: dark ? 0.22 : 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon,
                      size: 28.sp, color: AppColors.accentOn(dialogCtx, tone)),
                ),
                SizedBox(height: 14.h),
                PoppinsText(
                  text: title,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary(dialogCtx),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8.h),
                InterText(
                  text: message,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w400,
                  height: 1.45,
                  color: AppColors.textSecondary(dialogCtx),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 22.h),
                ActionPillButton(
                  label: confirmLabel,
                  icon: icon,
                  tone: tone,
                  kind: destructive
                      ? ActionPillKind.danger
                      : ActionPillKind.filled,
                  expand: true,
                  haptic: destructive,
                  onPressed: () => Navigator.of(dialogCtx).pop(true),
                ),
                SizedBox(height: 10.h),
                ActionPillButton(
                  label: 'common_cancel'.tr,
                  tone: AppColors.textSecondary(dialogCtx),
                  kind: ActionPillKind.ghost,
                  expand: true,
                  onPressed: () => Navigator.of(dialogCtx).pop(false),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
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
    final confirmed = await _showModernConfirm(
      context: context,
      icon: Icons.verified_rounded,
      tone: AppColors.primaryColor,
      title: 'candidates_choose_dialog_title'.tr,
      message:
          'candidates_choose_dialog_message'.trParams({'name': app.sitter.name}),
      confirmLabel: 'candidates_choose_confirm'.tr,
      destructive: false,
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
    final confirmed = await _showModernConfirm(
      context: context,
      icon: Icons.warning_amber_rounded,
      tone: ActionTone.danger,
      title: 'candidates_reject_dialog_title'.tr,
      message:
          'candidates_reject_dialog_message'.trParams({'name': app.sitter.name}),
      confirmLabel: 'common_reject'.tr,
      destructive: true,
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
        // v569 — `padding.bottom` = 0 sur le Samsung de Daniel.
        20.h + appBottomInset(context),
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
                // v573 — squelettes de cartes plutôt qu'un spinner nu : la
                // feuille garde sa forme pendant le chargement.
                return const _CandidatesSkeleton();
              }
              if (list.isEmpty) {
                // v573 — état vide illustré (disque teinté + icône) au lieu
                // d'une ligne de texte perdue au milieu de la feuille.
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 28.h),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 64.w,
                        height: 64.w,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.primaryColor.withValues(alpha: 0.10),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.groups_2_rounded,
                          size: 30.sp,
                          color: AppColors.accentOn(
                              context, AppColors.primaryColor),
                        ),
                      ),
                      SizedBox(height: 12.h),
                      InterText(
                        text: 'candidates_empty'.tr,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w500,
                        textAlign: TextAlign.center,
                        color: AppColors.textSecondary(context),
                      ),
                    ],
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
    // v573 — 3 pilules FIXES à parts égales (même grammaire que
    // `BookingSegmentedTabs`) : plus de rangée qui glisse, plus de
    // `ChoiceChip` Material au milieu d'un écran au nouveau design. Le tri et
    // ses 3 modes sont inchangés.
    Widget pill(String labelKey, _SortMode mode, IconData icon) {
      final bool selected = _sortMode == mode;
      final Color fg =
          selected ? AppColors.whiteColor : AppColors.textSecondary(context);
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _sortMode = mode),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: selected ? AppColors.primaryColor : Colors.transparent,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 15.sp, color: fg),
                SizedBox(width: 5.w),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: InterText(
                      text: labelKey.tr,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                      color: fg,
                      maxLines: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(5.w),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.divider(context)),
        boxShadow: AppColors.cardShadow(context),
      ),
      child: Row(
        children: [
          pill('candidates_sort_newest', _SortMode.newest,
              Icons.schedule_rounded),
          SizedBox(width: 4.w),
          pill('candidates_sort_price', _SortMode.priceAsc,
              Icons.payments_rounded),
          SizedBox(width: 4.w),
          pill('candidates_sort_rating', _SortMode.ratingDesc,
              Icons.star_rounded),
        ],
      ),
    );
  }
}

/// v573 — squelette de chargement de la feuille des candidatures : 3 cartes
/// grises qui respirent, à la place du `CircularProgressIndicator` nu.
class _CandidatesSkeleton extends StatefulWidget {
  const _CandidatesSkeleton();

  @override
  State<_CandidatesSkeleton> createState() => _CandidatesSkeletonState();
}

class _CandidatesSkeletonState extends State<_CandidatesSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  Widget _bar(BuildContext context, double w, double h) => Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: AppColors.mediaPlaceholder(context),
          borderRadius: BorderRadius.circular(6.r),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctl,
      builder: (context, _) => Opacity(
        opacity: 0.45 + (_ctl.value * 0.35),
        child: ListView.separated(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 3,
          separatorBuilder: (_, __) => SizedBox(height: 10.h),
          itemBuilder: (_, __) => Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: AppColors.card(context),
              borderRadius: BorderRadius.circular(18.r),
              border: Border.all(color: AppColors.divider(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44.w,
                      height: 44.w,
                      decoration: BoxDecoration(
                        color: AppColors.mediaPlaceholder(context),
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _bar(context, 130.w, 12.h),
                          SizedBox(height: 7.h),
                          _bar(context, 88.w, 10.h),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 14.h),
                _bar(context, double.infinity, 40.h),
              ],
            ),
          ),
        ),
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
    // v573 — couleur du rôle éclaircie en mode sombre (`accentOn`) : le bleu
    // gardien #1976D2 et le rouge propriétaire étaient illisibles sur fond
    // sombre.
    final Color roleTone = AppColors.accentOn(
      context,
      isWalker ? const Color(0xFF1976D2) : AppColors.primaryColor,
    );
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: AppColors.divider(context)),
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
                // v23.1 part 250 — perf : CachedNetworkImageProvider + maxWidth
                // (avatar 44px, repete dans la liste de candidats). NetworkImage
                // brut re-telechargeait l'image entiere a chaque scroll.
                backgroundImage: avatarUrl.isNotEmpty
                    ? CachedNetworkImageProvider(avatarUrl, maxWidth: 130)
                    : null,
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
                            color: AppColors.textPrimary(context),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 6.w),
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 7.w, vertical: 2.h),
                          decoration: BoxDecoration(
                            color: roleTone.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: InterText(
                            // v576 — libellé unifié (plus de « Petsitter »).
                            text: roleLabelKey(
                                isWalker ? 'walker' : 'sitter').tr,
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w600,
                            color: roleTone,
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
                    color: AppColors.primaryColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: PoppinsText(
                    text: _priceLabel(),
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color:
                        AppColors.accentOn(context, AppColors.primaryColor),
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
          // v569 — même langage visuel que les feuilles d'action du bandeau :
          // choisir = pilule pleine, refuser = rouge texte, indicateur « en
          // cours » (busy) qui neutralise le double tap. Mêmes callbacks.
          Obx(
            () => Row(
              children: [
                Expanded(
                  child: ActionPillButton(
                    label: 'common_reject'.tr,
                    icon: Icons.close_rounded,
                    tone: ActionTone.danger,
                    kind: ActionPillKind.danger,
                    expand: true,
                    haptic: true,
                    busy: busy.value,
                    onPressed: onReject,
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  flex: 2,
                  child: ActionPillButton(
                    label: 'candidates_choose_button'.tr,
                    icon: Icons.check_circle_rounded,
                    tone: AppColors.primaryColor,
                    expand: true,
                    haptic: true,
                    busy: busy.value,
                    onPressed: onAccept,
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

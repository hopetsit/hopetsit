import 'package:hopetsit/widgets/role_chip.dart';
import 'package:hopetsit/widgets/net_image620.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:hopetsit/controllers/applications_controller.dart';
import 'package:hopetsit/models/application_model.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/action_banner_kit.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/utils/bottom_inset.dart';
import 'package:hopetsit/utils/service_location587.dart';
import 'package:hopetsit/views/pet_owner/posts/widgets/dates620_candidates.dart';
import 'package:hopetsit/views/pet_owner/posts/widgets/post_dates_sheet2610.dart';
import 'package:hopetsit/views/pet_owner/chat/individual_chat_screen.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/models/post_model.dart';
import 'package:hopetsit/repositories/owner_repository.dart';
import 'package:hopetsit/repositories/post_repository.dart';
import 'package:hopetsit/utils/currency_helper.dart';
import 'package:hopetsit/utils/services620.dart';
import 'package:hopetsit/widgets/chat_access_upsell_helper.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'dart:async';
import 'dart:math' as math;

/// v23.1 — B5 : bottom sheet listing every pending candidate for one of the
/// owner's posts. The owner can choose one (auto-rejects the others on the
/// backend) or reject any individually.
class PostCandidatesSheet {
  PostCandidatesSheet._();

  /// 624 — [highlightApplicationId] : le candidat de la notification, posé
  /// en premier et entouré. [source] : `push` | `notification` | `direct`
  /// (repère « a ouvert ses candidats » d'ADA).
  static Future<void> show({
    required BuildContext context,
    required String postId,
    String? highlightApplicationId,
    String source = 'direct',
  }) {
    markCandidatesViewed2610(postId, source);
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CandidatesSheetBody(
          postId: postId, highlightId: highlightApplicationId),
    );
  }
}

/// 624 (ADA) — repère « le propriétaire a ouvert ses candidats » : envoyé
/// sans attendre, toutes les erreurs ignorées (le serveur répond 204).
void markCandidatesViewed2610(String postId, String source) {
  if (postId.isEmpty || !Get.isRegistered<ApiClient>()) return;
  final src = const {'push', 'notification', 'direct'}.contains(source) ? source : 'direct';
  unawaited(() async {
    try {
      await Get.find<ApiClient>().post('/owner-signals/candidates-view',
          body: {'postId': postId, 'source': src}, requiresAuth: true);
    } catch (_) {/* repère facultatif */}
  }());
}

/// 624 — total à afficher (frais compris, tel que renvoyé par le serveur),
/// au format de la langue (« 86,40 € »). Vide si absent, nul ou inférieur
/// au tarif unitaire (règle de ZOE : jamais un total incohérent). Pure.
String candidateTotal2610(ApplicationModel app) {
  final p = app.pricing;
  if (p == null || p.stale || applicationIsIndicative620(app)) return '';
  final t = p.totalPrice;
  if (t == null || !(t > 0)) return '';
  final rate = p.appliedRate;
  if (rate != null && rate > 0 && t + 0.001 < rate) return '';
  final cur = (p.currency ?? '').isNotEmpty ? p.currency! : 'EUR';
  return CurrencyHelper.format(cur, t);
}

/// 624 — distance arrondie au km (≥ 1), jamais l'adresse. Pure.
int? candidateKm2610(double? lat1, double? lng1, double? lat2, double? lng2) {
  if (lat1 == null || lng1 == null || lat2 == null || lng2 == null) return null;
  const r = 6371.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1), dLng = rad(lng2 - lng1);
  final h = math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.pow(math.sin(dLng / 2), 2);
  final km = 2 * r * math.asin(math.min(1.0, math.sqrt(h.toDouble())));
  return math.max(1, km.round());
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
  const _CandidatesSheetBody({required this.postId, this.highlightId});

  final String postId;
  final String? highlightId;

  @override
  State<_CandidatesSheetBody> createState() => _CandidatesSheetBodyState();
}

class _CandidatesSheetBodyState extends State<_CandidatesSheetBody> {
  final RxBool _busy = false.obs;
  final RxString _writing = ''.obs;
  PostModel? _post;

  ApplicationsController get _controller => Get.isRegistered<ApplicationsController>()
      ? Get.find<ApplicationsController>()
      : Get.put(ApplicationsController());

  @override
  void initState() {
    super.initState();
    unawaited(_loadPost());
  }

  Future<void> _loadPost() async {
    if (!Get.isRegistered<PostRepository>()) return;
    try {
      final p = await Get.find<PostRepository>().getPostById(widget.postId);
      if (mounted && p != null) setState(() => _post = p);
    } catch (_) {/* la page reste utilisable sans la demande */}
  }

  /// Candidats en attente ; celui de la notification d'abord, puis les plus
  /// récents.
  List<ApplicationModel> _candidates() {
    final list = _controller.applications
        .where((a) =>
            a.postId == widget.postId &&
            a.status.toLowerCase().trim() == 'pending')
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final h = widget.highlightId;
    if (h != null && h.isNotEmpty) {
      final i = list.indexWhere((a) => a.id == h);
      if (i > 0) list.insert(0, list.removeAt(i));
    }
    return list;
  }

  bool _postIsTbd(List<ApplicationModel> list) {
    final p = _post;
    if (p != null) return p.dateMode == 'tbd';
    return list.any(applicationNeedsDates620);
  }

  Future<void> _openDates() async {
    var p = _post;
    if (p == null) {
      await _loadPost();
      p = _post;
    }
    if (p == null || !mounted) {
      CustomSnackbar.showError(
          title: 'common_error'.tr, message: 'cand2610_editor_error'.tr);
      return;
    }
    final saved = await PostDatesSheet2610.show(context, p);
    if (saved) await _loadPost();
  }

  Future<void> _write(ApplicationModel app) async {
    if (_writing.value.isNotEmpty) return;
    _writing.value = app.id;
    final isWalker = app.providerRole == 'walker';
    try {
      final res = await Get.find<OwnerRepository>().startConversation(
        sitterId: isWalker ? null : app.sitter.id,
        walkerId: isWalker ? app.sitter.id : null,
      );
      final conv = res['conversation'];
      final id = conv is Map ? (conv['id'] ?? conv['_id'] ?? '').toString() : '';
      if (id.isEmpty) {
        CustomSnackbar.showError(title: 'common_error'.tr, message: 'cand2610_write_fail'.tr);
        return;
      }
      await Get.to(() => IndividualChatScreen(
            conversationId: id,
            contactName: app.sitter.name,
            contactImage: app.sitter.avatar.url,
          ));
    } on ApiException catch (e) {
      if (mounted && ChatAccessUpsellHelper.maybeShowChatUpsell(context, e)) return;
      CustomSnackbar.showError(title: 'common_error'.tr, message: 'cand2610_write_fail'.tr);
    } catch (_) {
      CustomSnackbar.showError(title: 'common_error'.tr, message: 'cand2610_write_fail'.tr);
    } finally {
      _writing.value = '';
    }
  }

  Future<void> _accept(ApplicationModel app) async {
    if (_busy.value) return;
    // 620 — candidature indicative (demande sans dates) : on ne choisit pas,
    // on pose d'abord les dates.
    if (applicationIsStale620(app)) {
      warnStale620(); // 621 — tarif à venir : rien à choisir encore
      return;
    }
    if (applicationIsIndicative620(app)) {
      warnDatesRequired620();
      return;
    }
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
      key: const Key('cand2610_sheet'),
      constraints: BoxConstraints(
        maxHeight: mq.size.height * 0.92,
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
      child: Obx(() {
        // Touching .applications/.isLoading inside Obx so reactive.
        final loading = _controller.isLoading.value;
        final list = _candidates();
        final bool tbd = list.isNotEmpty && _postIsTbd(list);
        final int stale620 = list.where(applicationIsStale620).length;
        final String place = list
            .map((a) => serviceLocationDisplay(a.serviceLocation,
                meetingPoint: a.meetingPoint))
            .firstWhere((t) => t.isNotEmpty, orElse: () => '');
        final header = <Widget>[
          if (tbd) _TbdBanner2610(onTap: _openDates),
          if (stale620 > 0) StaleBanner620(count: stale620),
          if (place.isNotEmpty)
            Row(
              key: const Key('candidates_service_location'),
              children: [
                Icon(Icons.place_rounded,
                    size: 16.sp,
                    color: AppColors.accentOn(context, AppColors.primaryColor)),
                SizedBox(width: 6.w),
                Expanded(
                  child: InterText(
                    text: place,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary(context),
                  ),
                ),
              ],
            ),
        ];
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44.w,
                height: 4.h,
                margin: EdgeInsets.only(bottom: 10.h),
                decoration: BoxDecoration(
                  color: AppColors.divider(context),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
            _header(context, list.length),
            SizedBox(height: 10.h),
            Flexible(
              child: Builder(builder: (context) {
                if (loading && list.isEmpty) return const _CandidatesSkeleton();
                if (list.isEmpty) return _empty(context);
                return ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: header.length + list.length,
                  separatorBuilder: (_, __) => SizedBox(height: 10.h),
                  itemBuilder: (_, i) {
                    if (i < header.length) return header[i];
                    final app = list[i - header.length];
                    final p = _post?.location;
                    return _CandidateCard(
                      app: app,
                      busy: _busy,
                      writing: _writing,
                      tbd: tbd,
                      highlighted: app.id == widget.highlightId,
                      km: candidateKm2610(p?.lat, p?.lng, app.sitter.lat, app.sitter.lng),
                      onWrite: () => _write(app),
                      onAccept: () => _accept(app),
                      onReject: () => _reject(app),
                    );
                  },
                );
              }),
            ),
          ],
        );
      }),
    );
  }

  Widget _empty(BuildContext context) {
    // v573 — état vide illustré (disque teinté + icône).
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
            child: Icon(Icons.groups_2_rounded,
                size: 30.sp,
                color: AppColors.accentOn(context, AppColors.primaryColor)),
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

  /// 624 — « Tes candidats (N) » + la phrase du site (écrire d'abord,
  /// choisir ensuite, payer après).
  Widget _header(BuildContext context, int n) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PoppinsText(
                key: const Key('cand2610_title'),
                text: n > 0 ? '${'cand2610_title'.tr} ($n)' : 'cand2610_title'.tr,
                fontSize: 18.sp,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary(context),
              ),
              SizedBox(height: 3.h),
              InterText(
                text: 'cand2610_sub'.tr,
                fontSize: 12.sp,
                height: 1.35,
                color: AppColors.textSecondary(context),
                maxLines: 3,
              ),
            ],
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
}

/// 624 — encart « Indique tes dates pour voir le prix total et choisir » +
/// « Choisir mes dates » qui ouvre DIRECTEMENT le choix des dates.
class _TbdBanner2610 extends StatelessWidget {
  const _TbdBanner2610({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tone = AppColors.primaryColor;
    final on = AppColors.accentOn(context, tone);
    return Container(
      key: const Key('dates620_set_dates_banner'),
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 10.h),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: tone, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event_note_rounded, size: 18.sp, color: on),
              SizedBox(width: 8.w),
              Expanded(
                child: PoppinsText(
                  text: 'cand2610_tbd_title'.tr,
                  fontSize: 13.5.sp,
                  fontWeight: FontWeight.w700,
                  color: on,
                  maxLines: 2,
                ),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          InterText(
            text: 'cand2610_tbd_sub'.tr,
            fontSize: 11.5.sp,
            color: AppColors.textSecondary(context),
            maxLines: 3,
          ),
          SizedBox(height: 8.h),
          ActionPillButton(
            key: const Key('dates620_set_dates_button'),
            label: 'cand2610_tbd_cta'.tr,
            icon: Icons.edit_calendar_rounded,
            tone: tone,
            compact: true,
            onPressed: onTap,
          ),
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
    required this.writing,
    required this.tbd,
    required this.highlighted,
    required this.km,
    required this.onWrite,
    required this.onAccept,
    required this.onReject,
  });

  final ApplicationModel app;
  final RxBool busy;
  final RxString writing;
  final bool tbd;
  final bool highlighted;
  final int? km;
  final VoidCallback onWrite;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  bool get _indicative => applicationIsIndicative620(app);
  bool get _stale => applicationIsStale620(app);

  /// « TARIF 12 €/balade » (demande sans dates) au format de la langue.
  String _rateLabel() {
    final p = app.pricing;
    // 624 (ZOE) — tarif FRAIS COMPRIS pour le propriétaire, sinon l'ancien.
    final r = (p?.ownerUnitRate != null && p!.ownerUnitRate! > 0)
        ? p.ownerUnitRate
        : p?.unitRate;
    if (p == null || r == null || !(r > 0) || _stale) return '';
    final cur = (p.currency ?? '').isNotEmpty ? p.currency! : app.sitter.currency;
    final unit = p.unit.isNotEmpty ? p.unit : (app.providerRole == 'walker' ? 'walk' : 'day');
    return '${CurrencyHelper.formatCompact(cur.isNotEmpty ? cur : 'EUR', r)}${priceUnitSuffix620(unit)}';
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = app.sitter.avatar.url;
    final isWalker = app.providerRole == 'walker';
    final Color role = isWalker ? const Color(0xFF16A34A) : const Color(0xFF2563EB);
    final Color roleOn = AppColors.accentOn(context, role);
    final String name = app.sitter.name.isNotEmpty ? app.sitter.name : 'provider_unknown'.tr;
    final String first = name.split(' ').first;
    final String total = candidateTotal2610(app);
    final String rate = _indicative ? _rateLabel() : '';
    final String meta = [
      app.sitter.rating > 0
          ? '★ ${app.sitter.rating.toStringAsFixed(1)}'
              '${app.sitter.reviewsCount > 0 ? ' (${app.sitter.reviewsCount})' : ''}'
          : 'cand2610_no_reviews'.tr,
      if ((app.sitter.city ?? '').isNotEmpty) app.sitter.city!,
      if (km != null) 'cand2610_c1610_km_about'.tr.replaceAll('{km}', '$km'),
    ].join(' · ');
    final Color owner = AppColors.primaryColor;
    final bool chooseLocked = _stale || _indicative || tbd;
    return Container(
      key: Key('cand2610_card_${app.id}'),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(
            color: highlighted ? owner : AppColors.divider(context),
            width: highlighted ? 2 : 1),
        boxShadow: AppColors.cardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photo 56, sinon l'initiale sur la couleur du rôle.
              CircleAvatar(
                onBackgroundImageError: avatarUrl.isNotEmpty ? netImageOnError620 : null,
                radius: 28.r,
                backgroundColor: role,
                backgroundImage: avatarUrl.isNotEmpty
                    ? CachedNetworkImageProvider(avatarUrl, maxWidth: 170)
                    : null,
                child: avatarUrl.isEmpty
                    ? PoppinsText(
                        text: first.isNotEmpty ? first.characters.first.toUpperCase() : '?',
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      )
                    : null,
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PoppinsText(
                      text: first,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 3.h),
                    Wrap(
                      spacing: 5.w,
                      runSpacing: 4.h,
                      children: [
                        _chip(context, roleLabelKey(isWalker ? 'walker' : 'sitter').tr,
                            isWalker ? Icons.directions_walk_rounded : Icons.home_rounded,
                            role.withValues(alpha: 0.12), roleOn),
                        if (app.sitter.identityVerified)
                          _chip(context, 'identity_badge_verified'.tr, Icons.verified_user_rounded,
                              const Color(0xFF16A34A).withValues(alpha: 0.14),
                              AppColors.accentOn(context, const Color(0xFF15803D))),
                        if (highlighted)
                          _chip(context, 'cand2610_c1610_new'.tr, null, owner, Colors.white),
                      ],
                    ),
                    SizedBox(height: 4.h),
                    InterText(
                      text: meta,
                      fontSize: 12.sp,
                      color: AppColors.textSecondary(context),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          // Encadré prix : total frais compris, sinon tarif, sinon tarif à venir.
          Container(
            key: Key('cand2610_price_${app.id}'),
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 9.h),
            decoration: BoxDecoration(
              color: owner.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: _stale
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InterText(
                        text: 'cand2610_stale_short'.tr,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w800,
                        color: AppColors.accentOn(context, owner),
                      ),
                      SizedBox(height: 2.h),
                      InterText(
                        text: 'cand2610_cand_stale_hint'.tr,
                        fontSize: 11.5.sp,
                        color: AppColors.textSecondary(context),
                        maxLines: 3,
                      ),
                    ],
                  )
                : Row(
                    children: [
                      InterText(
                        text: (total.isNotEmpty ? 'cand2610_total' : 'cand2610_rate').tr.toUpperCase(),
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textSecondary(context),
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: PoppinsText(
                          text: total.isNotEmpty ? total : (rate.isNotEmpty ? rate : '—'),
                          fontSize: 17.sp,
                          fontWeight: FontWeight.w800,
                          color: AppColors.accentOn(context, owner),
                          maxLines: 1,
                        ),
                      ),
                      if (total.isNotEmpty && app.pricing?.weeklyApplied == true)
                        InterText(
                          key: Key('cand2610_weekly_${app.id}'),
                          text: 'cand2610_weekly'.tr,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accentOn(context, const Color(0xFF15803D)),
                        ),
                    ],
                  ),
          ),
          if (app.description.trim().isNotEmpty) ...[
            SizedBox(height: 8.h),
            InterText(
              text: '« ${app.description.trim()} »',
              fontSize: 12.5.sp,
              height: 1.35,
              color: AppColors.textPrimary(context),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          SizedBox(height: 12.h),
          // Boutons : Écrire (principal, couleur du rôle) · Choisir (contour
          // orange) · Refuser (lien). Paiement inchangé (après Choisir).
          Obx(() => ActionPillButton(
                key: Key('cand2610_write_${app.id}'),
                label: 'cand2610_write'.tr.replaceAll('{name}', first),
                icon: Icons.chat_bubble_rounded,
                tone: role,
                expand: true,
                busy: writing.value == app.id,
                onPressed: onWrite,
              )),
          SizedBox(height: 8.h),
          Obx(() => Opacity(
                opacity: chooseLocked ? 0.55 : 1,
                child: ActionPillButton(
                  key: Key('dates620_choose_${app.id}'),
                  label: _stale
                      ? 'dates620_stale_label'.tr
                      : (chooseLocked
                          ? 'dates620_choose_locked'.tr
                          : (total.isNotEmpty
                              ? '${'candidates_choose_button'.tr} · $total'
                              : 'candidates_choose_button'.tr)),
                  icon: _stale
                      ? Icons.hourglass_top_rounded
                      : (chooseLocked ? Icons.lock_clock_rounded : Icons.check_circle_rounded),
                  tone: owner,
                  kind: ActionPillKind.outlined,
                  expand: true,
                  haptic: true,
                  busy: busy.value,
                  onPressed: onAccept,
                ),
              )),
          if (chooseLocked && !_stale) ...[
            SizedBox(height: 4.h),
            Center(
              child: InterText(
                text: 'cand2610_cand_choose_blocked'.tr,
                fontSize: 11.sp,
                color: AppColors.textSecondary(context),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          SizedBox(height: 4.h),
          // « Refuser » en lien texte (rouge, sans aplat — kit).
          Center(
            child: ActionPillButton(
              key: Key('cand2610_reject_${app.id}'),
              label: 'common_reject'.tr,
              tone: ActionTone.danger,
              kind: ActionPillKind.danger,
              compact: true,
              onPressed: onReject,
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String text, IconData? icon, Color bg, Color fg) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11.sp, color: fg),
            SizedBox(width: 3.w),
          ],
          InterText(text: text, fontSize: 11.sp, fontWeight: FontWeight.w700, color: fg),
        ],
      ),
    );
  }
}

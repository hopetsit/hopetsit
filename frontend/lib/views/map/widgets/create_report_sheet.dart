import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hopetsit/controllers/map_report_controller.dart';
import 'package:hopetsit/models/map_report_model.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/bottom_inset.dart';
import 'package:hopetsit/utils/report_premium_helper.dart';
import 'package:hopetsit/views/boost/coin_shop_screen.dart';
import 'package:hopetsit/widgets/app_dialog_kit.dart';
import 'package:intl/intl.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';

/// Bottom sheet used by PawMap "Signaler" FAB — Premium users pick a report
/// type, add an optional note, and drop the report at [initialPoint] (the
/// current map center). The sheet is stateful so the pick+note can update
/// without rebuilding the whole map.
class CreateReportSheet extends StatefulWidget {
  const CreateReportSheet({
    super.key,
    required this.initialPoint,
    this.city,
    this.preselectedType,
  });

  final LatLng initialPoint;
  final String? city;

  /// Optional type pre-selected when the sheet opens — used by the "Quick
  /// signal" chips on the PawMap (Perdu / Trouvé / Point d'eau) so the user
  /// lands directly on the right category without having to tap again.
  final String? preselectedType;

  /// Convenience: opens the sheet and returns true if a report was created.
  static Future<bool> show(
    BuildContext context, {
    required LatLng initialPoint,
    String? city,
    String? preselectedType,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateReportSheet(
        initialPoint: initialPoint,
        city: city,
        preselectedType: preselectedType,
      ),
    );
    return result ?? false;
  }

  @override
  State<CreateReportSheet> createState() => _CreateReportSheetState();
}

class _CreateReportSheetState extends State<CreateReportSheet> {
  final _noteController = TextEditingController();
  String? _selectedType;

  late final MapReportController _ctrl;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.preselectedType;
    _ctrl = Get.isRegistered<MapReportController>()
        ? Get.find<MapReportController>()
        : Get.put(MapReportController());
    // 610 — compteur « 1 par semaine » des signalements de confort.
    if (!_isPremium) _ctrl.loadQuota();
  }

  /// 610 — confort bloqué : sans abonnement ET quota de la semaine utilisé.
  bool get _comfortExhausted =>
      !_isPremium && (_ctrl.comfortQuota.value?.exhausted ?? false);

  String _fmtDate(DateTime d) {
    final lang = Get.locale?.languageCode ?? 'fr';
    try {
      return '${DateFormat.MMMEd(lang).format(d)} ${DateFormat.Hm(lang).format(d)}';
    } catch (_) {
      return DateFormat('dd/MM HH:mm').format(d);
    }
  }

  /// 610 — message clair + accès aux abonnements quand le quota est atteint.
  Future<void> _showComfortQuotaDialog() async {
    final next = _ctrl.comfortQuota.value?.nextAvailableAt;
    final msg = next != null
        ? 'alerts610_quota_msg'.trParams({'date': _fmtDate(next)})
        : 'alerts610_quota_msg_nodate'.tr;
    final go = await showAppConfirmDialog(
      context,
      title: 'alerts610_quota_title'.tr,
      message: msg,
      confirmLabel: 'alerts610_see_plans'.tr,
      cancelLabel: 'alerts610_close'.tr,
      icon: Icons.hourglass_bottom_rounded,
    );
    if (go == true) Get.to(() => const CoinShopScreen(initialTab: 3));
  }

  /// 610 — animal perdu / trouvé : règle inchangée (abonnés), SOS gratuit.
  Future<void> _showLostLockedDialog() async {
    final go = await showAppConfirmDialog(
      context,
      title: 'alerts610_lost_locked_title'.tr,
      message: 'alerts610_lost_locked_msg'.tr,
      confirmLabel: 'alerts610_see_plans'.tr,
      cancelLabel: 'alerts610_close'.tr,
      icon: Icons.lock_rounded,
    );
    if (go == true) Get.to(() => const CoinShopScreen(initialTab: 3));
  }

  /// Premium gate for the report flow. Source unique : [ReportPremiumHelper]
  /// → débloqué si N'IMPORTE QUEL abo actif (SubscriptionController.isPremium
  /// OU PawSpotController.premiumActive). Avant on ne lisait que
  /// SubscriptionController, donc un utilisateur Paw Premium était bloqué.
  bool get _isPremium => ReportPremiumHelper.isUnlocked;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _showPremiumLockedSnack() {
    CustomSnackbar.showError(
      title: 'pawmap_snack_premium_required'.tr,
      message: 'pawmap_snack_premium_only_msg'.tr,
    );
  }

  Future<void> _submit() async {
    if (_selectedType == null) {
      CustomSnackbar.showError(
        title: 'pawmap_snack_type_required_title'.tr,
        message: 'pawmap_snack_type_required_msg'.tr,
      );
      return;
    }
    // 610 — garde côté app (le serveur tranche aussi : 402 / 429).
    if (ReportTypes.isPremiumCreate(_selectedType!) && !_isPremium) {
      await _showLostLockedDialog();
      return;
    }
    if (ReportTypes.isComfort(_selectedType!) && _comfortExhausted) {
      await _showComfortQuotaDialog();
      return;
    }
    final controller = _ctrl;

    final report = await controller.createReport(
      type: _selectedType!,
      point: widget.initialPoint,
      note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      city: widget.city,
    );

    if (!mounted) return;
    if (report != null) {
      CustomSnackbar.showSuccess(
        title: 'pawmap_snack_sent_title'.tr,
        message: 'pawmap_snack_sent_msg'.tr,
      );
      Navigator.of(context).pop(true);
    } else if (controller.comfortLimitReached.value) {
      // 610 — la limite hebdomadaire vue par le serveur : message + abonnements.
      await _showComfortQuotaDialog();
    } else if (controller.premiumRequired.value) {
      await _showLostLockedDialog();
    } else {
      CustomSnackbar.showError(
        title: 'pawmap_snack_send_failed_title'.tr,
        message: 'pawmap_snack_send_failed_msg'.tr,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    // `viewPadding.bottom` is the system navigation bar / gesture area —
    // add it to our bottom padding so the Publier button is never hidden
    // underneath Android's 3-button nav bar.
    // v556 — sur le Samsung de Daniel `viewPadding.bottom` vaut 0 (app
    // edge-to-edge) → le bouton passait sous la barre système. Même règle que
    // la carte : marge réelle, ou 48 si le système annonce 0.
    // v569 — utilitaire unique de l'app (iOS = inset réel, Android = 48 mini).
    final safeBottom = appBottomInset(context);
    // Session v15-4 — refonte compacte pour tenir sur 1 écran :
    //   • section "Gratuits" en tête avec les 4 types libres
    //   • section "Premium" en grille 3 colonnes pour les 15 Premium
    //   • description corrigée (4 types gratuits, pas 3)
    //   • paddings réduits + note sur 2 lignes
    // 610 — règle B : dangers et infos utiles gratuits sans limite, confort
    // 1 par semaine sans abonnement, animal perdu / trouvé pour les abonnés.

    // v447 — Daniel : "le bouton Publier oblige à scroller". Refonte de la
    // structure : l'EN-TÊTE (titre/sous-titre) et le PIED (note + position +
    // bouton Publier) sont FIXES ; seule la liste des types (Gratuits +
    // Premium) défile dans un espace borné au milieu. Le bouton « Publier le
    // signalement » est donc TOUJOURS visible sans scroll. La sheet est bornée
    // à 82 % de la hauteur écran pour laisser voir la carte derrière.
    final maxSheetHeight = MediaQuery.of(context).size.height * 0.82;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: Container(
        constraints: BoxConstraints(maxHeight: maxSheetHeight),
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 12.h + safeBottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── En-tête FIXE ────────────────────────────────────────────
            // Grabber
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: AppColors.divider(context),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
            SizedBox(height: 10.h),

            // Title + subtitle compact
            Row(
              children: [
                Text('📣', style: TextStyle(fontSize: 20.sp)),
                SizedBox(width: 8.w),
                Expanded(
                  child: PoppinsText(
                    text: 'pawmap_signal_title'.tr,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                // v23.1.170-fix — Daniel : "sur la page signalement en
                // haut a droite met une croix pour fermer la page" —
                // c'est ce bottom sheet (Signaler autour de moi), pas
                // le bug_report_screen comme on l'avait cru en premier.
                IconButton(
                  icon: Icon(Icons.close_rounded,
                      size: 22.sp,
                      color: AppColors.textSecondary(context)),
                  tooltip: 'common_close'.tr,
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(
                    minWidth: 32.w,
                    minHeight: 32.h,
                  ),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ],
            ),
            SizedBox(height: 2.h),
            InterText(
              text: 'alerts610_subtitle'.tr,
              fontSize: 11.sp,
              color: AppColors.textSecondary(context),
            ),
            SizedBox(height: 12.h),

            // ── Zone DÉFILANTE (types Gratuits + Premium uniquement) ──────
            // Seule la liste des types défile : l'en-tête et le pied (note +
            // bouton Publier) restent visibles en permanence.
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 610 — Section 1 : Dangers (gratuit pour tous, sans limite)
                    _buildFreeSection(
                      context,
                      ReportTypes.dangerTypes,
                      key: const ValueKey('alerts610_danger_section'),
                      title: 'alerts610_section_danger'.tr,
                      subtitle: 'alerts610_section_danger_sub'.tr,
                    ),
                    SizedBox(height: 10.h),
                    // Section 2 : Infos utiles (gratuit, sans limite)
                    _buildFreeSection(
                      context,
                      ReportTypes.usefulFreeTypes,
                      key: const ValueKey('alerts610_useful_section'),
                      title: 'alerts610_section_useful'.tr,
                      subtitle: 'alerts610_section_useful_sub'.tr,
                    ),
                    SizedBox(height: 10.h),
                    // Section 3 : Confort (1 par semaine sans abonnement)
                    _buildComfortSection(context),
                    SizedBox(height: 10.h),
                    // Section 4 : Animal perdu / trouvé (abonnés, inchangé)
                    _buildPremiumSection(context, ReportTypes.premiumCreateTypes),
                  ],
                ),
              ),
            ),

            // ── Pied FIXE (hint + note + position + Publier) ──────────────
            // Hint sous la sélection — compact, disparaît par défaut.
            if (_selectedType != null) ...[
              SizedBox(height: 8.h),
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: 10.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color:
                      AppColors.primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 14.sp,
                        color: AppColors.primaryColor),
                    SizedBox(width: 6.w),
                    Expanded(
                      child: InterText(
                        // 610 — sur un danger : rappel du geste du bon Samaritain.
                        text: ReportTypes.isDanger(_selectedType!)
                            ? '${ReportTypes.hintFr(_selectedType!)}\n${'alerts610_samaritan_hint'.tr}'
                            : ReportTypes.hintFr(_selectedType!),
                        fontSize: 11.sp,
                        color: AppColors.textSecondary(context),
                        maxLines: 4,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            SizedBox(height: 8.h),

            // Note field — 2 lignes par défaut, maxLength retiré du
            // bas visuel pour gagner de la place.
            InterText(
              text: 'pawmap_note_label'.tr,
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary(context),
            ),
            SizedBox(height: 4.h),
            TextField(
              controller: _noteController,
              maxLines: 2,
              maxLength: 500,
              style: TextStyle(fontSize: 13.sp),
              decoration: InputDecoration(
                hintText: 'pawmap_note_hint'.tr,
                hintStyle: TextStyle(fontSize: 12.sp),
                filled: true,
                fillColor: AppColors.scaffold(context),
                counterText: '',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                    horizontal: 10.w, vertical: 10.h),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.r),
                  borderSide: BorderSide(
                      color: AppColors.divider(context)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.r),
                  borderSide: BorderSide(
                      color: AppColors.primaryColor, width: 1.5),
                ),
              ),
            ),

            SizedBox(height: 6.h),

            // Location indicator compact
            Row(
              children: [
                Icon(Icons.place,
                    size: 13.sp, color: AppColors.primaryColor),
                SizedBox(width: 4.w),
                Expanded(
                  child: InterText(
                    text:
                        '${widget.initialPoint.latitude.toStringAsFixed(5)}, ${widget.initialPoint.longitude.toStringAsFixed(5)}',
                    fontSize: 10.sp,
                    color: AppColors.textSecondary(context),
                  ),
                ),
              ],
            ),

            SizedBox(height: 10.h),

            // Submit button — TOUJOURS visible (pied fixe), pas de scroll.
            Obx(() {
              final submitting = _ctrl.isSubmitting.value;
              return SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                  ),
                  icon: submitting
                      ? SizedBox(
                          width: 14.w,
                          height: 14.w,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(Icons.send_rounded,
                          size: 16.sp, color: Colors.white),
                  label: InterText(
                    text: submitting ? 'pawmap_btn_submit_sending'.tr : 'pawmap_btn_submit'.tr,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  /// Section "Gratuits" — petit header + Wrap des types free.
  /// Fond vert pâle pour signaler visuellement que le groupe entier est
  /// accessible sans Premium (plus besoin du badge "GRATUIT" par chip).
  Widget _buildFreeSection(
    BuildContext context,
    List<String> types, {
    Key? key,
    required String title,
    required String subtitle,
  }) {
    // v571 — lisibilité sombre : le vert #008000 sur la feuille anthracite est
    // quasi illisible ; en sombre on prend un vert clair (le clair ne bouge pas).
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color green =
        isDark ? const Color(0xFF4ADE80) : AppColors.greenColor;
    return Container(
      key: key,
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: green.withValues(alpha: isDark ? 0.12 : 0.06),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: green.withValues(alpha: 0.25), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_rounded, size: 14.sp, color: green),
              SizedBox(width: 4.w),
              InterText(
                text: title,
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: green,
              ),
              SizedBox(width: 6.w),
              Flexible(
                child: InterText(
                  text: subtitle,
                  fontSize: 10.sp,
                  color: AppColors.textSecondary(context),
                  maxLines: 2,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Wrap(
            spacing: 6.w,
            runSpacing: 6.h,
            children: types.map((t) => _buildTypeChip(
                  context,
                  type: t,
                  locked: false,
                  isFreeBadge: false, // le container entier sert de badge
                )).toList(),
          ),
        ],
      ),
    );
  }

  /// 610 — Section « Confort » : 1 par semaine sans abonnement, illimité avec.
  /// Le compteur se lit dans le contrôleur (GET /map-reports/quota).
  Widget _buildComfortSection(BuildContext context) {
    return Obx(() {
      final q = _ctrl.comfortQuota.value;
      final exhausted = !_isPremium && (q?.exhausted ?? false);
      final String counter;
      if (_isPremium || (q?.unlimited ?? false)) {
        counter = 'alerts610_comfort_unlimited'.tr;
      } else if (exhausted) {
        counter = q?.nextAvailableAt != null
            ? 'alerts610_comfort_used'
                .trParams({'date': _fmtDate(q!.nextAvailableAt!)})
            : 'alerts610_quota_title'.tr;
      } else {
        counter = 'alerts610_comfort_available'.tr;
      }
      return Column(
        key: const ValueKey('alerts610_comfort_section'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                exhausted
                    ? Icons.hourglass_bottom_rounded
                    : Icons.event_repeat_rounded,
                size: 14.sp,
                color: AppColors.primaryColor,
              ),
              SizedBox(width: 4.w),
              InterText(
                text: 'alerts610_section_comfort'.tr,
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary(context),
              ),
              SizedBox(width: 6.w),
              Flexible(
                child: InterText(
                  key: const ValueKey('alerts610_comfort_counter'),
                  text: counter,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w600,
                  color: exhausted
                      ? AppColors.primaryColor
                      : AppColors.textSecondary(context),
                  maxLines: 2,
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 6.h,
            crossAxisSpacing: 6.w,
            childAspectRatio: 2.4,
            children: ReportTypes.comfortTypes
                .map((t) => _buildTypeChip(
                      context,
                      type: t,
                      locked: exhausted,
                      isFreeBadge: false,
                      compact: true,
                      lockIcon: Icons.hourglass_bottom_rounded,
                      onLockedTap: _showComfortQuotaDialog,
                    ))
                .toList(),
          ),
        ],
      );
    });
  }

  /// 610 — Section « Animal perdu ou trouvé » : règle inchangée, réservée
  /// aux abonnés (le SOS de la PawMap reste gratuit).
  Widget _buildPremiumSection(
      BuildContext context, List<String> types) {
    return Column(
      key: const ValueKey('alerts610_lost_section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              _isPremium ? Icons.star_rounded : Icons.lock_rounded,
              size: 14.sp,
              color: _isPremium
                  ? const Color(0xFFFF9500)
                  : AppColors.textSecondary(context),
            ),
            SizedBox(width: 4.w),
            InterText(
              text: 'alerts610_section_lost'.tr,
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary(context),
            ),
            SizedBox(width: 6.w),
            Flexible(
              child: InterText(
                text: _isPremium
                    ? 'alerts610_section_lost_unlocked'.tr
                    : 'alerts610_section_lost_locked'.tr,
                fontSize: 10.sp,
                color: AppColors.textSecondary(context),
                maxLines: 2,
              ),
            ),
          ],
        ),
        SizedBox(height: 6.h),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 6.h,
          crossAxisSpacing: 6.w,
          childAspectRatio: 2.4,
          children: types
              .map((t) => _buildTypeChip(
                    context,
                    type: t,
                    locked: !_isPremium,
                    isFreeBadge: false,
                    compact: true,
                    onLockedTap: _showLostLockedDialog,
                  ))
              .toList(),
        ),
      ],
    );
  }

  /// Chip unifié utilisé par les deux sections. [compact] resserre le
  /// padding et masque le label au-delà de 1 ligne (cellules de grille).
  Widget _buildTypeChip(
    BuildContext context, {
    required String type,
    required bool locked,
    required bool isFreeBadge,
    bool compact = false,
    IconData lockIcon = Icons.lock_rounded,
    VoidCallback? onLockedTap,
  }) {
    final selected = _selectedType == type;
    final bg = selected
        ? AppColors.primaryColor
        : (locked
            ? AppColors.scaffold(context)
            : AppColors.card(context));
    final borderColor = selected
        ? AppColors.primaryColor
        : (locked
            ? AppColors.divider(context).withValues(alpha: 0.6)
            : AppColors.divider(context));
    final textColor = selected
        ? Colors.white
        : (locked
            ? AppColors.textSecondary(context)
            : AppColors.textPrimary(context));

    return GestureDetector(
      key: ValueKey('alerts610_chip_$type'),
      onTap: () {
        if (locked) {
          (onLockedTap ?? _showPremiumLockedSnack)();
          return;
        }
        setState(() => _selectedType = type);
      },
      child: Opacity(
        opacity: locked ? 0.72 : 1.0,
        child: Container(
          padding: EdgeInsets.symmetric(
              horizontal: compact ? 6.w : 10.w,
              vertical: compact ? 6.h : 8.h),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                ReportTypes.emoji(type),
                style: TextStyle(fontSize: compact ? 13.sp : 15.sp),
              ),
              SizedBox(width: 4.w),
              Flexible(
                child: InterText(
                  text: ReportTypes.labelFr(type),
                  fontSize: compact ? 10.sp : 11.sp,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                  maxLines: 1,
                ),
              ),
              if (locked) ...[
                SizedBox(width: 3.w),
                Icon(
                  lockIcon,
                  size: 10.sp,
                  color: AppColors.textSecondary(context),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// v565 — Feuille « J'ai un code » (saisie d'un code promo depuis le paiement,
// la boutique ou le profil) + pop-up promo discret (une seule fois).
// Rempli par le lot app-profile ; l'API ci-dessous est FIGÉE (voir
// docs/v565_contracts.md §9), le lot app-home-bookings l'appelle.
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:hopetsit/utils/bottom_inset.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:get_storage/get_storage.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';

import 'package:hopetsit/controllers/promo_controller.dart';
import 'package:hopetsit/data/network/secure_token_store.dart';
import 'package:hopetsit/repositories/promo_repository.dart';
import 'package:hopetsit/services/apple_iap_service.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/storage_keys.dart';
import 'package:hopetsit/views/profile/widgets/profile_ui_kit.dart';
import 'package:hopetsit/widgets/app_text.dart';

/// Libellé lisible d'un forfait offert (aligné sur l'admin / PromoCodeScreen).
String promoPlanLabel(String plan) {
  switch (plan) {
    case 'premium_monthly':
    case 'premium_yearly':
    case 'premium':
      return 'promo_plan_premium'.tr;
    case 'monthly':
    case 'yearly':
      return 'promo_plan_pawfollow'.tr;
    case 'family':
    case 'famille':
    case 'family_yearly':
      return 'promo_plan_pawfamily'.tr;
    case 'pawspot':
      return 'promo_plan_pawspot'.tr;
    case 'pawboost':
      return 'promo_plan_pawboost'.tr;
    default:
      return plan.isEmpty ? 'promo_plan_generic'.tr : plan;
  }
}

/// Message de succès lisible pour un [PromoResult].
String promoSuccessMessage(PromoResult? res) {
  if (res == null) return 'promo_success_generic'.tr;
  if (res.isPercentDiscount) {
    return 'promo_success_discount'.trParams({'percent': '${res.discountPercent}'});
  }
  return 'promo_success_subscription'.trParams({'plan': promoPlanLabel(res.plan)});
}

/// Ouvre la feuille de saisie d'un code promo. Renvoie true si un code a été
/// appliqué avec succès.
///
/// Sur iOS (refus Apple 3.1.1), la feuille propose aussi la feuille de code
/// OFFICIELLE App Store (offer codes) ; le formulaire serveur reste disponible
/// pour les codes maison (Android / réductions boutique).
/// v565 — Daniel : « pré-remplir le code, il a juste à appuyer sur Appliquer ».
/// [initialCode] pré-remplit le champ ; [autoApply] lance l'application dès
/// l'ouverture (un seul geste depuis le pop-up).
Future<bool> showPromoCodeSheet(
  BuildContext context, {
  required Color accent,
  String? initialCode,
  bool autoApply = false,
}) async {
  final result = await showProfileSheet<bool>(
    context,
    builder: (ctx) => _PromoCodeSheetBody(
      accent: accent,
      initialCode: initialCode,
      autoApply: autoApply,
    ),
  );
  return result == true;
}

class _PromoCodeSheetBody extends StatefulWidget {
  const _PromoCodeSheetBody({
    required this.accent,
    this.initialCode,
    this.autoApply = false,
  });
  final Color accent;
  final String? initialCode;
  final bool autoApply;

  @override
  State<_PromoCodeSheetBody> createState() => _PromoCodeSheetBodyState();
}

class _PromoCodeSheetBodyState extends State<_PromoCodeSheetBody> {
  late final PromoController _controller;
  final TextEditingController _text = TextEditingController();
  static const String _tag = 'promo_sheet';
  bool _iosBusy = false;
  bool _previewed = false;

  @override
  void initState() {
    super.initState();
    _controller = Get.isRegistered<PromoController>(tag: _tag)
        ? Get.find<PromoController>(tag: _tag)
        : Get.put(PromoController(), tag: _tag);
    _controller.reset();
    if (Platform.isIOS) {
      try {
        AppleIapService.init();
      } catch (_) {/* best-effort */}
    }
    final initial = (widget.initialCode ?? '').trim().toUpperCase();
    if (initial.isNotEmpty) {
      _text.text = initial;
      if (widget.autoApply) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _apply();
        });
      }
    }
  }

  @override
  void dispose() {
    _text.dispose();
    try {
      Get.delete<PromoController>(tag: _tag);
    } catch (_) {/* déjà libéré */}
    super.dispose();
  }

  Future<void> _preview() async {
    FocusScope.of(context).unfocus();
    final ok = await _controller.check(_text.text);
    if (!mounted) return;
    setState(() => _previewed = ok);
  }

  Future<void> _apply() async {
    FocusScope.of(context).unfocus();
    final ok = await _controller.redeem(_text.text);
    if (!mounted) return;
    if (ok) {
      HapticFeedback.mediumImpact();
      setState(() {});
    }
  }

  Future<void> _openAppleCodeSheet() async {
    if (_iosBusy) return;
    setState(() => _iosBusy = true);
    try {
      final addition = InAppPurchase.instance
          .getPlatformAddition<InAppPurchaseStoreKitPlatformAddition>();
      await addition.presentCodeRedemptionSheet();
    } catch (e) {
      Get.snackbar('common_error'.tr, e.toString(),
          snackPosition: SnackPosition.BOTTOM, margin: EdgeInsets.all(12.w));
    } finally {
      if (mounted) setState(() => _iosBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 20.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ProfileSheetHandle(),
          Row(
            children: [
              Container(
                width: 44.w,
                height: 44.w,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: Icon(Icons.confirmation_number_rounded, color: accent, size: 22.sp),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PoppinsText(
                      text: 'promo_sheet_title'.tr,
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    InterText(
                      text: 'promo_sheet_subtitle'.tr,
                      fontSize: 12.sp,
                      color: AppColors.textSecondary(context),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(false),
                icon: Icon(Icons.close_rounded, color: AppColors.textSecondary(context)),
              ),
            ],
          ),
          SizedBox(height: 18.h),
          Obx(() {
            final status = _controller.status.value;
            final res = _controller.result.value;
            if (status == PromoStatus.success) {
              return _SuccessCard(
                accent: accent,
                message: promoSuccessMessage(res),
                hint: (res?.isPercentDiscount ?? false)
                    ? 'promo_success_discount_hint'.tr
                    : 'promo_sheet_success_hint'.tr,
                onDone: () => Navigator.of(context).pop(true),
              );
            }
            final hasError = status == PromoStatus.error;
            final busy = _controller.isBusy;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _text,
                  enabled: !busy,
                  autofocus: true,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [_UpperCaseFormatter()],
                  onChanged: (_) {
                    if (_previewed) setState(() => _previewed = false);
                    if (status == PromoStatus.error) _controller.reset();
                  },
                  onSubmitted: (_) => _apply(),
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.6,
                    color: AppColors.textPrimary(context),
                  ),
                  decoration: InputDecoration(
                    hintText: 'promo_field_hint'.tr,
                    hintStyle: TextStyle(
                      color: AppColors.textSecondary(context),
                      letterSpacing: 0.5,
                      fontWeight: FontWeight.w500,
                    ),
                    filled: true,
                    fillColor: AppColors.card(context),
                    prefixIcon: Icon(Icons.sell_rounded, color: accent, size: 20.sp),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16.r),
                      borderSide: BorderSide(
                        color: hasError ? AppColors.errorColor : AppColors.divider(context),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16.r),
                      borderSide: BorderSide(color: hasError ? AppColors.errorColor : accent, width: 1.6),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16.r)),
                  ),
                ),
                if (hasError && _controller.errorMessage.value.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: 8.h, left: 4.w),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline_rounded, size: 16.sp, color: AppColors.errorColor),
                        SizedBox(width: 6.w),
                        Expanded(
                          child: InterText(
                            text: _controller.errorMessage.value,
                            fontSize: 12.sp,
                            color: AppColors.errorColor,
                            maxLines: 3,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_previewed && res != null && res.valid && !hasError)
                  Padding(
                    padding: EdgeInsets.only(top: 10.h),
                    child: ProfileInfoBanner(
                      icon: Icons.auto_awesome_rounded,
                      accent: accent,
                      text: 'promo_sheet_preview'.trParams({'reward': promoSuccessMessage(res)}),
                    ),
                  ),
                SizedBox(height: 16.h),
                ProfilePrimaryButton(
                  label: 'promo_apply_button'.tr,
                  accent: accent,
                  loading: status == PromoStatus.redeeming,
                  onTap: busy ? null : _apply,
                  icon: Icons.check_rounded,
                ),
                SizedBox(height: 8.h),
                TextButton(
                  onPressed: busy ? null : _preview,
                  child: InterText(
                    text: status == PromoStatus.checking
                        ? 'promo_sheet_checking'.tr
                        : 'promo_sheet_preview_button'.tr,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: accent,
                  ),
                ),
                if (Platform.isIOS) ...[
                  Divider(height: 24.h, color: AppColors.divider(context)),
                  InterText(
                    text: 'promo_ios_info'.tr,
                    fontSize: 12.sp,
                    color: AppColors.textSecondary(context),
                    maxLines: 4,
                    height: 1.35,
                  ),
                  SizedBox(height: 10.h),
                  ProfileSecondaryButton(
                    label: 'promo_ios_button'.tr,
                    accent: accent,
                    icon: Icons.apple,
                    onTap: _iosBusy ? null : _openAppleCodeSheet,
                  ),
                ],
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _SuccessCard extends StatelessWidget {
  const _SuccessCard({
    required this.accent,
    required this.message,
    required this.hint,
    required this.onDone,
  });
  final Color accent;
  final String message;
  final String hint;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: EdgeInsets.all(18.w),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(18.r),
            border: Border.all(color: accent.withValues(alpha: 0.35)),
          ),
          child: Column(
            children: [
              Container(
                width: 56.w,
                height: 56.w,
                decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                child: Icon(Icons.celebration_rounded, color: Colors.white, size: 28.sp),
              ),
              SizedBox(height: 12.h),
              PoppinsText(
                text: 'promo_success_title'.tr,
                fontSize: 17.sp,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary(context),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 6.h),
              InterText(
                text: message,
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary(context),
                textAlign: TextAlign.center,
                maxLines: 3,
              ),
              SizedBox(height: 4.h),
              InterText(
                text: hint,
                fontSize: 12.sp,
                color: AppColors.textSecondary(context),
                textAlign: TextAlign.center,
                maxLines: 3,
                height: 1.35,
              ),
            ],
          ),
        ),
        SizedBox(height: 14.h),
        ProfilePrimaryButton(
          label: 'common_done'.tr,
          accent: accent,
          onTap: onDone,
        ),
      ],
    );
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(text: newValue.text.toUpperCase(), selection: newValue.selection);
  }
}

/// Pop-up promo discret : à monter une fois dans le wrapper de navigation.
///
/// Règles (docs/v565_contracts.md §9) :
///   • compteur `app_open_count` incrémenté à CHAQUE montage du wrapper ;
///   • affiché UNE seule fois (`promo_popup_shown_v565`), jamais à la 1re
///     ouverture (compteur ≥ 2), seulement pour une session connectée ;
///   • fermable (croix / « Plus tard »), bouton « J'ai un code » → feuille.
/// Rendu : petite carte flottante en bas de l'écran, au-dessus du menu,
/// qui glisse depuis le bas après un court délai.
class PromoPopup extends StatefulWidget {
  const PromoPopup({super.key});

  @override
  State<PromoPopup> createState() => _PromoPopupState();
}

class _PromoPopupState extends State<PromoPopup> with SingleTickerProviderStateMixin {
  bool _visible = false;
  // v565 — « code du moment » réglé dans l'admin (GET /app-config/public-promo),
  // pré-rempli et appliqué en UN geste. HOPDALIOS = code valable iOS/Android/web.
  static const String _fallbackCode = 'HOPDALIOS';
  String _code = _fallbackCode;
  String _message = '';
  // v565 — Daniel : « précise 1 mois de PawPremium gratuit » : la récompense
  // réelle du code (lue via /promo/check, sans le consommer) est affichée.
  String _reward = '';
  // Lot D (25/09/2026) — BUG vu sur l'app réelle (test du menu du bas) :
  // ces deux champs étaient `late final` INITIALISÉS PARESSEUSEMENT. Quand le
  // pop-up décidait de ne pas s'afficher puis était retiré (changement
  // d'écran), `dispose()` touchait `_anim` pour la première fois → le
  // contrôleur se créait sur un widget déjà désactivé (« Looking up a
  // deactivated widget's ancestor is unsafe »). Création dans `initState`.
  late final AnimationController _anim;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _slide = Tween<Offset>(begin: const Offset(0, 1.2), end: Offset.zero)
        .animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));
    _decide();
  }

  void _decide() {
    int count = 0;
    bool shown = false;
    try {
      final box = GetStorage();
      count = (box.read<int>(StorageKeys.appOpenCount) ?? 0) + 1;
      box.write(StorageKeys.appOpenCount, count);
      shown = box.read<bool>(StorageKeys.promoPopupShown) ?? false;
    } catch (_) {
      return;
    }
    if (shown || count < 2) return;
    final token = SecureTokenStore.currentToken();
    if (token == null || token.isEmpty) return;
    _loadPublicPromo();
  }

  Future<void> _loadPublicPromo() async {
    bool enabled = true;
    try {
      final api = Get.isRegistered<ApiClient>() ? Get.find<ApiClient>() : ApiClient();
      final res = await api.get('/app-config/public-promo', requiresAuth: true);
      if (res is Map) {
        enabled = res['enabled'] != false;
        final c = (res['code'] ?? '').toString().trim().toUpperCase();
        if (c.isNotEmpty) _code = c;
        _message = (res['message'] ?? '').toString().trim();
      }
    } catch (_) {
      // Serveur injoignable ou route pas encore déployée : code par défaut.
    }
    if (!enabled || !mounted) return;
    try {
      final api = Get.isRegistered<ApiClient>() ? Get.find<ApiClient>() : ApiClient();
      final res = await api.post('/promo/check', body: {'code': _code}, requiresAuth: true);
      _reward = _rewardLabel(PromoResult.fromCheck(res));
    } catch (_) {
      _reward = '';
    }
    if (!mounted) return;
    Future.delayed(const Duration(seconds: 6), () {
      if (!mounted) return;
      setState(() => _visible = true);
      _anim.forward();
    });
  }

  /// « 1 mois de Paw Premium offert », « -10 % en boutique »… ('' si inconnu).
  static String _rewardLabel(PromoResult r) {
    if (!r.valid) return '';
    if (r.isPercentDiscount && r.discountPercent > 0) {
      return 'promo_popup_reward_pct'.trParams({'pct': '${r.discountPercent}'});
    }
    if (r.isFreeSubscription) {
      final months = r.intervalDays >= 28 ? (r.intervalDays / 30).round().clamp(1, 24) : 0;
      final duration = months >= 12
          ? 'promo_popup_years'.trParams({'n': '${(months / 12).round()}'})
          : months >= 1
              ? 'promo_popup_months'.trParams({'n': '$months'})
              : 'promo_popup_days'.trParams({'n': '${r.intervalDays}'});
      return 'promo_popup_reward_sub'.trParams({'duration': duration, 'plan': _planLabel(r.plan)});
    }
    return '';
  }

  static String _planLabel(String plan) {
    switch (plan) {
      case 'premium_monthly':
      case 'premium_yearly':
      case 'premium':
        return 'promo_plan_premium'.tr;
      case 'monthly':
      case 'yearly':
        return 'promo_plan_pawfollow'.tr;
      case 'family':
      case 'famille':
      case 'family_yearly':
        return 'promo_plan_pawfamily'.tr;
      case 'pawspot':
        return 'promo_plan_pawspot'.tr;
      case 'pawboost':
        return 'promo_plan_pawboost'.tr;
      default:
        return plan;
    }
  }

  void _markShown() {
    try {
      GetStorage().write(StorageKeys.promoPopupShown, true);
    } catch (_) {/* best-effort */}
  }

  Future<void> _dismiss() async {
    _markShown();
    await _anim.reverse();
    if (mounted) setState(() => _visible = false);
  }

  Future<void> _openSheet() async {
    _markShown();
    await _anim.reverse();
    if (!mounted) return;
    setState(() => _visible = false);
    final role = GetStorage().read<String>(StorageKeys.userRole);
    await showPromoCodeSheet(
      context,
      accent: profileAccentFor(role),
      initialCode: _code,
      autoApply: true,
    );
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    final role = GetStorage().read<String>(StorageKeys.userRole);
    final accent = profileAccentFor(role);
    // v566 — Daniel : « le pop-up sur Android est trop bas, derrière le menu ».
    // Le Scaffold du wrapper est en `extendBody: true` : dans le corps,
    // `MediaQuery.padding.bottom` vaut EXACTEMENT la hauteur réelle du menu
    // flottant + l'inset système (Android 3 boutons, gestes, iPhone). On se
    // pose donc 12 px au-dessus, au lieu d'une marge fixe (86) qui passait
    // sous le menu sur Android et le frôlait sur iPhone. Plancher de sécurité
    // si le menu est masqué (carte agrandie).
    final mq = MediaQuery.of(context);
    // v585 (lot D) — hors onglets : `appBottomInset` (Android ≥ 48) + 96.
    final double clearance =
        mq.padding.bottom > mq.viewPadding.bottom ? mq.padding.bottom : appBottomInset(context) + 96;
    return Positioned(
      left: 14.w,
      right: 14.w,
      bottom: clearance + 12,
      child: SlideTransition(
        position: _slide,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: EdgeInsets.fromLTRB(14.w, 12.h, 8.w, 12.h),
            decoration: BoxDecoration(
              color: AppColors.card(context),
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(color: accent.withValues(alpha: 0.25)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1E1513).withValues(alpha: 0.16),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 42.w,
                  height: 42.w,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(13.r),
                  ),
                  child: Icon(Icons.local_offer_rounded, color: accent, size: 22.sp),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PoppinsText(
                        text: 'promo_popup_gift_title'.tr,
                        fontSize: 13.5.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 2.h),
                      InterText(
                        text: _message.isNotEmpty
                            ? _message
                            : _reward.isNotEmpty
                                ? 'promo_popup_code_body_reward'
                                    .trParams({'code': _code, 'reward': _reward})
                                : 'promo_popup_code_body'.trParams({'code': _code}),
                        fontSize: 11.5.sp,
                        color: AppColors.textSecondary(context),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        height: 1.3,
                      ),
                      SizedBox(height: 8.h),
                      Row(
                        children: [
                          Flexible(
                            child: GestureDetector(
                              onTap: _openSheet,
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 7.h),
                                decoration: BoxDecoration(
                                  color: accent,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: InterText(
                                  text: 'promo_popup_apply'.trParams({'code': _code}),
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 10.w),
                          Flexible(
                            child: GestureDetector(
                              onTap: _dismiss,
                              behavior: HitTestBehavior.opaque,
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 6.h),
                                child: InterText(
                                  text: 'common_later'.tr,
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary(context),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _dismiss,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.close_rounded, size: 20.sp, color: AppColors.textSecondary(context)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

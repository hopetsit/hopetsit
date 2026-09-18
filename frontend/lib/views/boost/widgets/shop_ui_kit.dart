// v566 — kit visuel de la boutique (audit « vérifie que tout est bon », Daniel
// 18/09). Style Apple minimaliste + « Paw Buttons » : cartes 20-24, pilule
// « Meilleur prix », économie en %, bouton d'achat collant, feuille de
// confirmation, mentions légales d'abonnement, gestion / annulation.
//
// Aucun texte en dur : toutes les chaînes viennent de l'appelant (déjà
// traduites) ou des clés `v566_shop_*` (paquet localization/v565/home_i18n).
// Anti-débordement (allemand, portugais) : chaque libellé est borné par
// maxLines + ellipsis ou FittedBox(scaleDown).

import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:url_launcher/url_launcher.dart';

/// Liens légaux (mêmes cibles que le pied de boutique iOS — `www` direct pour
/// éviter la redirection 308 du domaine nu).
const String kShopTermsUrl = 'https://www.hopetsit.com/cgu';
const String kShopPrivacyUrl = 'https://www.hopetsit.com/privacy';

/// Réglages d'abonnement de l'App Store (lien officiel Apple).
const String kAppleManageSubscriptionsUrl =
    'https://apps.apple.com/account/subscriptions';

/// Économie (en %) d'un forfait annuel par rapport à 12 mensualités.
/// Renvoie 0 si les prix ne permettent pas de calculer (évite « -0 % »).
int shopYearlySavingsPct({required double monthly, required double yearly}) {
  if (monthly <= 0 || yearly <= 0) return 0;
  final full = monthly * 12;
  if (yearly >= full) return 0;
  return ((1 - yearly / full) * 100).round();
}

/// Libellé de durée traduit pour un nombre de jours (30 → 1 mois, 365 → 1 an).
String shopPeriodLabel(int days) {
  if (days >= 360) return 'v566_shop_period_year'.tr;
  if (days >= 28 && days <= 31) return 'v566_shop_period_month'.tr;
  return 'v566_shop_period_days'.tr.replaceAll('{n}', '$days');
}

/// Date courte JJ/MM/AAAA (neutre, lisible dans les 9 langues).
String shopShortDate(DateTime d) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year}';
}

/// Pilule « MEILLEUR PRIX » / « −40 % ».
class ShopPill extends StatelessWidget {
  const ShopPill({
    super.key,
    required this.label,
    required this.background,
    this.foreground = Colors.white,
    this.gradient,
  });

  final String label;
  final Color background;
  final Color foreground;
  final List<Color>? gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: 150.w),
      padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 3.5.h),
      decoration: BoxDecoration(
        color: gradient == null ? background : null,
        gradient: gradient == null ? null : LinearGradient(colors: gradient!),
        borderRadius: BorderRadius.circular(999),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          label,
          maxLines: 1,
          style: TextStyle(
            fontSize: 9.5.sp,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
            color: foreground,
            height: 1.1,
          ),
        ),
      ),
    );
  }
}

/// Pastille de sélection (rond vide / coche pleine) des cartes d'offre.
class ShopSelectDot extends StatelessWidget {
  const ShopSelectDot({
    super.key,
    required this.selected,
    required this.color,
    this.idleColor,
    this.checkColor = Colors.white,
  });

  final bool selected;
  final Color color;
  final Color? idleColor;
  final Color checkColor;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? color : Colors.transparent,
        border: Border.all(
          color: selected ? color : (idleColor ?? AppColors.divider(context)),
          width: 2,
        ),
      ),
      child: selected
          ? Icon(Icons.check_rounded, size: 15, color: checkColor)
          : null,
    );
  }
}

/// Bouton d'achat COLLANT en bas d'un onglet de la boutique.
class ShopStickyBar extends StatelessWidget {
  const ShopStickyBar({
    super.key,
    required this.title,
    required this.priceLabel,
    required this.buttonLabel,
    required this.colors,
    required this.onPressed,
    this.subLabel,
    this.loading = false,
    this.dark = false,
    this.buttonTextColor = Colors.white,
  });

  /// Nom de l'offre sélectionnée (« PawFollow · Annuel »).
  final String title;

  /// Prix affiché (« 49,99 € »), déjà formaté.
  final String priceLabel;

  /// Ligne discrète sous le prix (« soit 4,17 €/mois », « 7 jours »…).
  final String? subLabel;
  final String buttonLabel;

  /// Dégradé du bouton (couleur du produit).
  final List<Color> colors;
  final VoidCallback? onPressed;
  final bool loading;

  /// Barre sombre (onglet Paw Premium noir/or).
  final bool dark;
  final Color buttonTextColor;

  @override
  Widget build(BuildContext context) {
    final bg = dark ? const Color(0xFF15120D) : AppColors.card(context);
    final titleColor =
        dark ? Colors.white.withValues(alpha: 0.75) : AppColors.greyText;
    final priceColor = dark ? const Color(0xFFFFD34D) : AppColors.textPrimary(context);
    final enabled = onPressed != null && !loading;
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 22,
            spreadRadius: -6,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 12.h),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: titleColor,
                  ),
                ),
                SizedBox(height: 2.h),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    priceLabel,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 19.sp,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      color: priceColor,
                      height: 1.1,
                    ),
                  ),
                ),
                if (subLabel != null && subLabel!.isNotEmpty)
                  Text(
                    subLabel!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w500,
                      color: titleColor,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            flex: 6,
            child: Semantics(
              button: true,
              enabled: enabled,
              label: buttonLabel,
              child: GestureDetector(
                onTap: enabled ? onPressed : null,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 160),
                  opacity: enabled || loading ? 1 : 0.45,
                  child: Container(
                    height: 50.h,
                    alignment: Alignment.center,
                    padding: EdgeInsets.symmetric(horizontal: 12.w),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: colors,
                        begin: const Alignment(-0.6, -1),
                        end: const Alignment(0.6, 1),
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colors.last.withValues(alpha: 0.45),
                          blurRadius: 18,
                          spreadRadius: -8,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: loading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: buttonTextColor,
                            ),
                          )
                        : FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              buttonLabel,
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                                color: buttonTextColor,
                              ),
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mentions obligatoires d'un achat boutique + liens CGU / confidentialité.
///
/// iOS (règle Apple 3.1.2) : durée, prix, renouvellement automatique, gestion
/// dans les réglages App Store. Android / autres : paiement par carte UNIQUE,
/// sans renouvellement automatique (c'est le fonctionnement réel du serveur).
class ShopLegalNote extends StatelessWidget {
  const ShopLegalNote({
    super.key,
    this.oneTime = false,
    this.onDark = false,
  });

  /// true = achat ponctuel (PawBoost) : jamais de renouvellement.
  final bool oneTime;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final color = onDark
        ? Colors.white.withValues(alpha: 0.62)
        : AppColors.greyText;
    final String body;
    if (oneTime) {
      body = 'v566_shop_legal_onetime'.tr;
    } else if (Platform.isIOS) {
      body = 'v566_shop_legal_ios'.tr;
    } else {
      body = 'v566_shop_legal_other'.tr;
    }
    Widget link(String label, String url) => InkWell(
          onTap: () =>
              launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 4.h, horizontal: 2.w),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5.sp,
                fontWeight: FontWeight.w600,
                color: color,
                decoration: TextDecoration.underline,
                decorationColor: color,
              ),
            ),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          body,
          style: TextStyle(fontSize: 10.5.sp, height: 1.35, color: color),
        ),
        SizedBox(height: 4.h),
        Wrap(
          spacing: 12.w,
          children: [
            link('iap_terms_link'.tr, kShopTermsUrl),
            link('iap_privacy_link'.tr, kShopPrivacyUrl),
          ],
        ),
      ],
    );
  }
}

/// Ligne « Gérer mon abonnement » : iOS → réglages d'abonnement App Store ;
/// ailleurs → feuille qui explique qu'il n'y a rien à annuler (paiement unique).
class ShopManageRow extends StatelessWidget {
  const ShopManageRow({
    super.key,
    required this.accent,
    this.activeUntil,
    this.onDark = false,
  });

  final Color accent;
  final DateTime? activeUntil;
  final bool onDark;

  Future<void> _open(BuildContext context) async {
    if (Platform.isIOS) {
      final ok = await launchUrl(
        Uri.parse(kAppleManageSubscriptionsUrl),
        mode: LaunchMode.externalApplication,
      );
      if (ok) return;
    }
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: AppColors.card(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 20.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider(ctx),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            SizedBox(height: 16.h),
            InterText(
              text: Platform.isIOS
                  ? 'v566_shop_manage'.tr
                  : 'v566_shop_manage_other_title'.tr,
              fontSize: 17.sp,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary(ctx),
              maxLines: 2,
            ),
            SizedBox(height: 8.h),
            Text(
              Platform.isIOS
                  ? 'v566_shop_manage_ios_hint'.tr
                  : 'v566_shop_manage_other_body'.tr,
              style: TextStyle(
                fontSize: 13.sp,
                height: 1.4,
                color: AppColors.textSecondary(ctx),
              ),
            ),
            if (activeUntil != null) ...[
              SizedBox(height: 10.h),
              Text(
                'v566_shop_active_until'
                    .tr
                    .replaceAll('{date}', shopShortDate(activeUntil!)),
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ],
            SizedBox(height: 16.h),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: TextButton.styleFrom(
                  backgroundColor: accent.withValues(alpha: 0.10),
                  foregroundColor: accent,
                  padding: EdgeInsets.symmetric(vertical: 13.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'common_ok'.tr,
                  style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fg = onDark ? Colors.white.withValues(alpha: 0.9) : accent;
    return InkWell(
      onTap: () => _open(context),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: (onDark ? Colors.white : accent).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(Icons.manage_accounts_outlined, size: 18.sp, color: fg),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                'v566_shop_manage'.tr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 20.sp, color: fg),
          ],
        ),
      ),
    );
  }
}

/// Bandeau ambre « Expire dans N j ».
class ShopExpiryNotice extends StatelessWidget {
  const ShopExpiryNotice({super.key, required this.days});

  final int days;

  /// Seuil « expiration proche ».
  static const int threshold = 5;

  static bool shouldShow(int days) => days > 0 && days <= threshold;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E0),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF5C26B)),
      ),
      child: Row(
        children: [
          Icon(Icons.schedule_rounded,
              size: 18.sp, color: const Color(0xFFB45309)),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              (Platform.isIOS
                      ? 'v566_shop_expiring_soon_ios'
                      : 'v566_shop_expiring_soon')
                  .tr
                  .replaceAll('{days}', '$days'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF92400E),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// État d'erreur d'un onglet (réseau) avec bouton « Réessayer ».
class ShopErrorState extends StatelessWidget {
  const ShopErrorState({super.key, required this.onRetry, required this.accent});

  final VoidCallback onRetry;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(28.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 40.sp, color: AppColors.greyText),
            SizedBox(height: 12.h),
            Text(
              'v566_shop_load_error'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary(context),
              ),
            ),
            SizedBox(height: 14.h),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                backgroundColor: accent.withValues(alpha: 0.10),
                foregroundColor: accent,
                padding: EdgeInsets.symmetric(horizontal: 22.w, vertical: 11.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                'v566_shop_retry'.tr,
                style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Moyen de paiement annoncé dans la feuille de confirmation.
enum ShopPayMethod { appleIap, card, wallet }

/// Feuille de confirmation d'achat (remplace les AlertDialog hétérogènes).
///
/// Indispensable AVANT tout POST d'achat : le serveur active immédiatement les
/// comptes staff (gratuit) et les paiements wallet, sans écran de paiement.
/// Renvoie true si l'utilisateur confirme.
Future<bool> showShopConfirmSheet(
  BuildContext context, {
  required String productName,
  required String planLabel,
  required String priceLabel,
  required String durationLabel,
  required List<Color> colors,
  required Widget icon,
  required ShopPayMethod method,
  String? strikePriceLabel,
  String? noteLabel,
  bool oneTime = false,
  Color buttonTextColor = Colors.white,
}) async {
  final String methodLabel;
  final IconData methodIcon;
  switch (method) {
    case ShopPayMethod.appleIap:
      methodLabel = 'v566_shop_pay_apple'.tr;
      methodIcon = Icons.apple_rounded;
      break;
    case ShopPayMethod.wallet:
      methodLabel = 'v566_shop_pay_wallet'.tr;
      methodIcon = Icons.account_balance_wallet_outlined;
      break;
    case ShopPayMethod.card:
      methodLabel = 'v566_shop_pay_card'.tr;
      methodIcon = Icons.credit_card_rounded;
      break;
  }

  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.card(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      Widget line(IconData ic, String label, String value, {String? strike}) {
        return Padding(
          padding: EdgeInsets.symmetric(vertical: 9.h),
          child: Row(
            children: [
              Icon(ic, size: 18.sp, color: AppColors.greyText),
              SizedBox(width: 10.w),
              Expanded(
                flex: 4,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: AppColors.textSecondary(ctx),
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                flex: 6,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (strike != null) ...[
                      Flexible(
                        child: Text(
                          strike,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: AppColors.greyText,
                            decoration: TextDecoration.lineThrough,
                            decorationColor: AppColors.greyText,
                          ),
                        ),
                      ),
                      SizedBox(width: 6.w),
                    ],
                    Flexible(
                      child: Text(
                        value,
                        maxLines: 2,
                        textAlign: TextAlign.end,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary(ctx),
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

      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 18.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider(ctx),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            SizedBox(height: 16.h),
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: colors,
                      begin: const Alignment(-0.6, -1),
                      end: const Alignment(0.6, 1),
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.45)),
                  ),
                  child: Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: icon,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'v566_shop_confirm_title'.tr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.greyText,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        productName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          color: AppColors.textPrimary(ctx),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: AppColors.scaffold(ctx),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  line(Icons.sell_outlined, 'v566_shop_confirm_offer'.tr,
                      planLabel),
                  Divider(height: 1, color: AppColors.divider(ctx)),
                  line(Icons.event_available_outlined,
                      'v566_shop_confirm_duration'.tr, durationLabel),
                  Divider(height: 1, color: AppColors.divider(ctx)),
                  line(Icons.payments_outlined, 'v566_shop_confirm_price'.tr,
                      priceLabel,
                      strike: strikePriceLabel),
                  Divider(height: 1, color: AppColors.divider(ctx)),
                  line(methodIcon, 'v566_shop_confirm_payment'.tr, methodLabel),
                ],
              ),
            ),
            if (noteLabel != null && noteLabel.isNotEmpty) ...[
              SizedBox(height: 8.h),
              Text(
                noteLabel,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5.sp,
                  fontWeight: FontWeight.w700,
                  color: colors.last,
                ),
              ),
            ],
            SizedBox(height: 10.h),
            ShopLegalNote(oneTime: oneTime),
            SizedBox(height: 12.h),
            GestureDetector(
              onTap: () => Navigator.of(ctx).pop(true),
              child: Container(
                height: 52.h,
                width: double.infinity,
                alignment: Alignment.center,
                padding: EdgeInsets.symmetric(horizontal: 14.w),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: colors,
                    begin: const Alignment(-0.6, -1),
                    end: const Alignment(0.6, 1),
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: colors.last.withValues(alpha: 0.45),
                      blurRadius: 18,
                      spreadRadius: -8,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'v566_shop_confirm_pay'.tr.replaceAll('{price}', priceLabel),
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 15.5.sp,
                      fontWeight: FontWeight.w800,
                      color: buttonTextColor,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 4.h),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(
                  'common_cancel'.tr,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.greyText,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
  return result == true;
}

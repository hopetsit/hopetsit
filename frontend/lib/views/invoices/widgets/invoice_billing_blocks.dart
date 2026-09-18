// v566 — blocs « Émetteur » / « Client » des factures + bandeau « Ajoute tes
// informations de facturation » (demande Daniel 18/09). Partagé par la liste
// des factures et l'aperçu. Rien ne s'affiche quand les données sont vides.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:hopetsit/models/billing_info_model.dart';
import 'package:hopetsit/models/invoice_model.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/views/profile/billing_info_screen.dart';
import 'package:hopetsit/views/profile/widgets/profile_ui_kit.dart';
import 'package:hopetsit/widgets/app_text.dart';

/// Ouvre l'écran de saisie ; `onReturn` est appelé au retour.
Future<void> openBillingInfoScreen({required Color accent, VoidCallback? onReturn}) async {
  await Get.to(() => BillingInfoScreen(accent: accent));
  onReturn?.call();
}

/// Bandeau cliquable « Ajoute tes informations de facturation ».
class BillingMissingBanner extends StatelessWidget {
  final Color accent;
  final VoidCallback? onReturn;
  final EdgeInsetsGeometry? margin;
  const BillingMissingBanner({super.key, required this.accent, this.onReturn, this.margin});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: Material(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16.r),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => openBillingInfoScreen(accent: accent, onReturn: onReturn),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
            child: Row(
              children: [
                Icon(Icons.request_quote_rounded, color: accent, size: 20.sp),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InterText(
                        text: 'billing_missing_title'.tr,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary(context),
                        maxLines: 2,
                      ),
                      SizedBox(height: 2.h),
                      InterText(
                        text: 'billing_row_subtitle'.tr,
                        fontSize: 11.5.sp,
                        color: AppColors.textSecondary(context),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 6.w),
                Icon(Icons.chevron_right_rounded, size: 20.sp, color: accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Un bloc (Émetteur ou Client) : libellé, nom légal (sinon nom du profil),
/// « NIF : … », « TVA : … », adresse. Ne rend RIEN si tout est vide.
class InvoicePartyBlock extends StatelessWidget {
  final String label;
  final String fallbackName;
  final BillingInfo billing;
  final Color accent;
  final IconData icon;
  const InvoicePartyBlock({
    super.key,
    required this.label,
    required this.fallbackName,
    required this.billing,
    required this.accent,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final name = billing.legalName.isNotEmpty ? billing.legalName : fallbackName;
    final lines = billing.detailLines;
    if (name.isEmpty && lines.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(18.r),
        boxShadow: AppColors.cardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 14.sp, color: accent),
              SizedBox(width: 6.w),
              Expanded(
                child: PoppinsText(
                  text: label.toUpperCase(),
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: accent,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (name.isNotEmpty) ...[
            SizedBox(height: 6.h),
            PoppinsText(
              text: name,
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary(context),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          for (final l in lines) ...[
            SizedBox(height: 3.h),
            InterText(
              text: l,
              fontSize: 12.5.sp,
              color: AppColors.textSecondary(context),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

/// Feuille « Émetteur et client » d'une facture.
Future<void> showInvoicePartiesSheet(
  BuildContext context, {
  required InvoiceModel invoice,
  required Color accent,
}) {
  return showProfileSheet<void>(
    context,
    builder: (ctx) => SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const ProfileSheetHandle(),
          PoppinsText(
            text: 'billing_parties_title'.tr,
            fontSize: 17.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary(ctx),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 12.h),
          InvoicePartyBlock(
            label: 'billing_issuer'.tr,
            fallbackName: invoice.providerName,
            billing: invoice.issuerBilling,
            accent: accent,
            icon: Icons.storefront_rounded,
          ),
          InvoicePartyBlock(
            label: 'billing_customer'.tr,
            fallbackName: invoice.ownerName,
            billing: invoice.customerBilling,
            accent: accent,
            icon: Icons.person_rounded,
          ),
        ],
      ),
    ),
  );
}

/// Barre fine, au-dessus de l'aperçu : ouvre la feuille « Émetteur et client ».
/// Résumé à droite = identifiants présents (« NIF : … · CIF : … »).
class InvoicePartiesStrip extends StatelessWidget {
  final InvoiceModel invoice;
  final Color accent;
  const InvoicePartiesStrip({super.key, required this.invoice, required this.accent});

  @override
  Widget build(BuildContext context) {
    final summary = <String>[
      invoice.issuerBilling.summary,
      invoice.customerBilling.summary,
    ].where((e) => e.isNotEmpty).join('  ·  ');
    return Material(
      color: AppColors.card(context),
      child: InkWell(
        onTap: () => showInvoicePartiesSheet(context, invoice: invoice, accent: accent),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
          child: Row(
            children: [
              Icon(Icons.badge_rounded, size: 18.sp, color: accent),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InterText(
                      text: 'billing_parties_title'.tr,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (summary.isNotEmpty)
                      InterText(
                        text: summary,
                        fontSize: 11.sp,
                        color: AppColors.textSecondary(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 20.sp, color: AppColors.textSecondary(context)),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';

/// Modern in-app card payment screen.
///
/// Replaces Stripe's native PaymentSheet in places where the sheet's input
/// fields weren't receiving taps on some Android devices (reported by
/// Daniel on 2026-04-18). Uses the Stripe `CardFormField` widget so the
/// PCI-compliant card collection stays with Stripe, but everything else —
/// visuals, buttons, layout — is pure Flutter controlled by us.
///
/// Usage:
///   final ok = await Get.to(() => ModernCardPaymentScreen(
///     clientSecret: clientSecret,
///     amount: 3.90,
///     currency: 'EUR',
///     productLabel: 'Premium Mensuel',
///   ));
///   if (ok == true) { /* confirm server-side + refresh status */ }
class ModernCardPaymentScreen extends StatefulWidget {
  const ModernCardPaymentScreen({
    super.key,
    required this.clientSecret,
    required this.amount,
    required this.currency,
    required this.productLabel,
    this.productSubtitle,
    this.primaryColor,
    this.savedPaymentMethods = const [],
  });

  final String clientSecret;
  final double amount;
  final String currency; // 'EUR' | 'GBP' | 'CHF' | 'USD'
  final String productLabel;
  final String? productSubtitle;

  /// Optional primary color for the header/button. Defaults to app primary.
  final Color? primaryColor;

  /// v18.9 — liste des cartes déjà enregistrées. Si non vide, l'écran
  /// propose à l'user de payer avec une carte existante sans re-saisir.
  /// Chaque entrée doit avoir au minimum { id, brand, last4, expMonth, expYear }.
  final List<Map<String, dynamic>> savedPaymentMethods;

  @override
  State<ModernCardPaymentScreen> createState() =>
      _ModernCardPaymentScreenState();
}

class _ModernCardPaymentScreenState extends State<ModernCardPaymentScreen> {
  CardFieldInputDetails? _cardDetails;
  bool _processing = false;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  String _country = 'FR';

  /// v18.9 — payment method ID sélectionné parmi saved cards. null = nouvelle carte.
  String? _selectedSavedPmId;

  @override
  void initState() {
    super.initState();
    // Pré-sélectionne la 1re carte enregistrée si dispo.
    if (widget.savedPaymentMethods.isNotEmpty) {
      _selectedSavedPmId =
          widget.savedPaymentMethods.first['id']?.toString();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  String _currencySymbol(String c) {
    switch (c.toUpperCase()) {
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      case 'USD':
        return '\$';
      case 'CHF':
        return 'CHF ';
      default:
        return '';
    }
  }

  Future<void> _pay() async {
    // v18.9 — si une saved card est sélectionnée, on confirme avec son
    // PaymentMethodId et on skip la saisie carte. Sinon flow normal.
    if (_selectedSavedPmId != null && _selectedSavedPmId!.isNotEmpty) {
      setState(() => _processing = true);
      try {
        await Stripe.instance.confirmPayment(
          paymentIntentClientSecret: widget.clientSecret,
          data: PaymentMethodParams.cardFromMethodId(
            paymentMethodData: PaymentMethodDataCardFromMethod(
              paymentMethodId: _selectedSavedPmId!,
            ),
          ),
        );
        if (!mounted) return;
        Navigator.of(context).pop(true);
        return;
      } on StripeException catch (e) {
        if (!mounted) return;
        if (e.error.code != FailureCode.Canceled) {
          CustomSnackbar.showError(
            title: 'Paiement échoué',
            message: e.error.localizedMessage ??
                e.error.message ??
                'Erreur pendant la transaction.',
          );
        }
        return;
      } catch (e) {
        if (!mounted) return;
        CustomSnackbar.showError(
          title: 'Paiement échoué',
          message: e.toString(),
        );
        return;
      } finally {
        if (mounted) setState(() => _processing = false);
      }
    }

    if (_cardDetails == null || !(_cardDetails!.complete)) {
      CustomSnackbar.showError(
        title: 'Carte incomplète',
        message: 'Remplis tous les champs de la carte avant de payer.',
      );
      return;
    }
    if (_nameController.text.trim().isEmpty) {
      CustomSnackbar.showError(
        title: 'Nom requis',
        message: 'Ajoute le nom du titulaire de la carte.',
      );
      return;
    }

    setState(() => _processing = true);
    try {
      final billingDetails = BillingDetails(
        name: _nameController.text.trim(),
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        address: Address(
          country: _country,
          city: null,
          line1: null,
          line2: null,
          postalCode: null,
          state: null,
        ),
      );

      await Stripe.instance.confirmPayment(
        paymentIntentClientSecret: widget.clientSecret,
        data: PaymentMethodParams.card(
          paymentMethodData: PaymentMethodData(
            billingDetails: billingDetails,
          ),
        ),
      );

      if (!mounted) return;
      Navigator.of(context).pop(true); // success
    } on StripeException catch (e) {
      if (!mounted) return;
      if (e.error.code != FailureCode.Canceled) {
        CustomSnackbar.showError(
          title: 'Paiement échoué',
          message: e.error.localizedMessage ??
              e.error.message ??
              'Erreur pendant la transaction.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      String msg = e.toString();
      if (msg.contains('StripeConfigException')) {
        msg = 'Stripe non configuré. Ferme et relance l\'app.';
      }
      CustomSnackbar.showError(
        title: 'Paiement échoué',
        message: msg,
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = widget.primaryColor ?? AppColors.primaryColor;
    final sym = _currencySymbol(widget.currency);
    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      appBar: AppBar(
        backgroundColor: AppColors.appBar(context),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: AppColors.textPrimary(context)),
        title: PoppinsText(
          text: 'Paiement',
          fontSize: 18.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(20.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Order summary card.
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(18.w),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            primary,
                            primary.withValues(alpha: 0.75),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18.r),
                        boxShadow: [
                          BoxShadow(
                            color: primary.withValues(alpha: 0.28),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InterText(
                            text: 'Tu vas payer',
                            fontSize: 12.sp,
                            color: Colors.white.withValues(alpha: 0.85),
                            fontWeight: FontWeight.w500,
                          ),
                          SizedBox(height: 6.h),
                          PoppinsText(
                            text:
                                '$sym${widget.amount.toStringAsFixed(2)}',
                            fontSize: 32.sp,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                          SizedBox(height: 8.h),
                          InterText(
                            text: widget.productLabel,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                          if (widget.productSubtitle != null) ...[
                            SizedBox(height: 2.h),
                            InterText(
                              text: widget.productSubtitle!,
                              fontSize: 11.sp,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ],
                        ],
                      ),
                    ),
                    SizedBox(height: 22.h),

                    // Card details section.
                    _sectionTitle(context, 'Carte bancaire',
                        icon: Icons.credit_card_rounded, color: primary),
                    SizedBox(height: 10.h),
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 12.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: AppColors.card(context),
                        borderRadius: BorderRadius.circular(14.r),
                        border: Border.all(
                          color: AppColors.divider(context),
                        ),
                      ),
                      child: CardFormField(
                        style: CardFormStyle(
                          textColor: AppColors.textPrimary(context),
                          placeholderColor:
                              AppColors.textSecondary(context),
                          fontSize: 14,
                        ),
                        onCardChanged: (details) {
                          setState(() => _cardDetails = details);
                        },
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Row(
                      children: [
                        Icon(Icons.lock_outline,
                            size: 12.sp,
                            color: AppColors.textSecondary(context)),
                        SizedBox(width: 4.w),
                        Expanded(
                          child: InterText(
                            text:
                                'Paiement sécurisé par Stripe. On ne stocke jamais ton numéro de carte.',
                            fontSize: 10.sp,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 22.h),

                    // Billing details.
                    _sectionTitle(context, 'Informations du titulaire',
                        icon: Icons.person_outline_rounded, color: primary),
                    SizedBox(height: 10.h),
                    _inputField(
                      controller: _nameController,
                      hint: 'Nom sur la carte',
                      icon: Icons.person_outline,
                    ),
                    SizedBox(height: 12.h),
                    _inputField(
                      controller: _emailController,
                      hint: 'Email (facultatif, pour reçu)',
                      icon: Icons.mail_outline_rounded,
                      keyboard: TextInputType.emailAddress,
                    ),
                    SizedBox(height: 12.h),
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 14.w, vertical: 2.h),
                      decoration: BoxDecoration(
                        color: AppColors.card(context),
                        borderRadius: BorderRadius.circular(14.r),
                        border: Border.all(
                          color: AppColors.divider(context),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.flag_outlined,
                              size: 18.sp,
                              color: AppColors.textSecondary(context)),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: DropdownButton<String>(
                              value: _country,
                              isExpanded: true,
                              underline: const SizedBox.shrink(),
                              items: const [
                                DropdownMenuItem(
                                    value: 'FR', child: Text('🇫🇷 France')),
                                DropdownMenuItem(
                                    value: 'CH', child: Text('🇨🇭 Suisse')),
                                DropdownMenuItem(
                                    value: 'BE', child: Text('🇧🇪 Belgique')),
                                DropdownMenuItem(
                                    value: 'LU',
                                    child: Text('🇱🇺 Luxembourg')),
                                DropdownMenuItem(
                                    value: 'DE',
                                    child: Text('🇩🇪 Allemagne')),
                                DropdownMenuItem(
                                    value: 'ES', child: Text('🇪🇸 Espagne')),
                                DropdownMenuItem(
                                    value: 'IT', child: Text('🇮🇹 Italie')),
                                DropdownMenuItem(
                                    value: 'PT', child: Text('🇵🇹 Portugal')),
                                DropdownMenuItem(
                                    value: 'NL',
                                    child: Text('🇳🇱 Pays-Bas')),
                                DropdownMenuItem(
                                    value: 'GB',
                                    child: Text('🇬🇧 Royaume-Uni')),
                                DropdownMenuItem(
                                    value: 'US',
                                    child: Text('🇺🇸 États-Unis')),
                              ],
                              onChanged: (v) =>
                                  setState(() => _country = v ?? 'FR'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Pay button pinned to bottom with SafeArea.
            Padding(
              padding: EdgeInsets.fromLTRB(
                20.w,
                12.h,
                20.w,
                MediaQuery.of(context).viewPadding.bottom + 12.h,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 54.h,
                child: ElevatedButton.icon(
                  onPressed: _processing ? null : _pay,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: primary.withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    elevation: 4,
                    shadowColor: primary.withValues(alpha: 0.35),
                  ),
                  icon: _processing
                      ? SizedBox(
                          width: 18.w,
                          height: 18.w,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.lock_rounded),
                  label: InterText(
                    text: _processing
                        ? 'Traitement…'
                        : 'Payer $sym${widget.amount.toStringAsFixed(2)}',
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(
    BuildContext context,
    String title, {
    required IconData icon,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 28.w,
          height: 28.w,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Icon(icon, size: 16.sp, color: color),
        ),
        SizedBox(width: 10.w),
        PoppinsText(
          text: title,
          fontSize: 14.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary(context),
        ),
      ],
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboard,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboard ?? TextInputType.text,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: AppColors.card(context),
        prefixIcon:
            Icon(icon, size: 18.sp, color: AppColors.textSecondary(context)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.r),
          borderSide: BorderSide(color: AppColors.divider(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.r),
          borderSide: BorderSide(color: AppColors.divider(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14.r),
          borderSide: BorderSide(
            color: widget.primaryColor ?? AppColors.primaryColor,
            width: 1.5,
          ),
        ),
        contentPadding:
            EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
      ),
    );
  }
}

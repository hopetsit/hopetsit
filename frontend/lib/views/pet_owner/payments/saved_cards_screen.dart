import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/repositories/owner_repository.dart';
import 'package:hopetsit/services/airwallex_payment_service.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';

/// v23.1 — Mes cartes (saved Airwallex payment_consents).
/// Owner can see all cards saved on Airwallex side and detach any of them.
class SavedCardsScreen extends StatefulWidget {
  const SavedCardsScreen({super.key});

  @override
  State<SavedCardsScreen> createState() => _SavedCardsScreenState();
}

class _SavedCardsScreenState extends State<SavedCardsScreen> {
  late final OwnerRepository _repo;
  final RxList<Map<String, dynamic>> cards = <Map<String, dynamic>>[].obs;
  final RxBool isLoading = false.obs;
  final RxnString errorMessage = RxnString();

  @override
  void initState() {
    super.initState();
    _repo = Get.isRegistered<OwnerRepository>()
        ? Get.find<OwnerRepository>()
        : OwnerRepository(Get.find<ApiClient>());
    _load();
  }

  Future<void> _load() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final list = await _repo.getOwnerPaymentMethods();
      cards.assignAll(list);
    } on ApiException catch (e) {
      errorMessage.value = e.message;
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _confirmAndDelete(Map<String, dynamic> card) async {
    final id = card['id']?.toString() ?? '';
    if (id.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('saved_cards_delete_title'.tr),
        content: Text('saved_cards_delete_message'.tr),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('common_cancel'.tr),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'common_delete'.tr,
              style: const TextStyle(color: Color(0xFFE53935)),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repo.deleteOwnerPaymentMethod(id);
      cards.removeWhere((c) => c['id']?.toString() == id);
      CustomSnackbar.showSuccess(
        title: 'common_success'.tr,
        message: 'saved_cards_delete_success'.tr,
      );
    } catch (e) {
      String msg = e.toString();
      if (e is ApiException && e.details is Map) {
        final d = (e.details as Map)['details'];
        if (d is String && d.isNotEmpty) msg = d;
      }
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: msg,
      );
    }
  }

  // v23.1 — busy flag pour éviter double-tap pendant la vérification.
  final RxBool _verifying = false.obs;

  Future<void> _onAddCardTap() async {
    if (_verifying.value) return;

    // 1. Confirm dialog : explique la charge €0.50 + refund auto.
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('saved_cards_verify_title'.tr),
        content: Text('saved_cards_verify_message'.tr),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('common_cancel'.tr),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'saved_cards_verify_confirm'.tr,
              style: TextStyle(
                color: AppColors.primaryColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;

    _verifying.value = true;
    try {
      // 2. Backend creates the verification PI.
      final intent = await _repo.verifyCard();
      final piId = intent['paymentIntentId'] as String? ?? '';
      final secret = intent['clientSecret'] as String? ?? '';
      final amount = (intent['amount'] as num?)?.toDouble() ?? 0.50;
      final currency = (intent['currency'] as String?) ?? 'EUR';

      if (piId.isEmpty || secret.isEmpty) {
        CustomSnackbar.showError(
          title: 'common_error'.tr,
          message: 'saved_cards_verify_failed'.tr,
        );
        return;
      }

      // 3. Open the Airwallex WebView for the user to enter card details.
      final result = await AirwallexPaymentService.confirmPaymentIntent(
        intentId: piId,
        clientSecret: secret,
        amount: amount,
        currency: currency,
      );

      if (!result.isSuccess) {
        if (result.outcome != AirwallexPaymentOutcome.cancelled) {
          CustomSnackbar.showError(
            title: 'common_error'.tr,
            message: result.errorMessage ?? 'saved_cards_verify_failed'.tr,
          );
        }
        return;
      }

      // 4. Success — refund is triggered by the webhook server-side.
      CustomSnackbar.showSuccess(
        title: 'common_success'.tr,
        message: 'saved_cards_verify_success'.tr,
      );
      // Small delay so Airwallex has time to register the consent before reload.
      await Future.delayed(const Duration(seconds: 2));
      await _load();
    } on ApiException catch (e) {
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: e.message,
      );
    } catch (e) {
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: e.toString(),
      );
    } finally {
      _verifying.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // v23.1 — affichage : SafeArea sur le body + FAB endFloat pour ne pas
    // chevaucher la gesture bar Android (Daniel screenshot bug).
    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      appBar: AppBar(
        backgroundColor: AppColors.appBar(context),
        elevation: 0,
        title: PoppinsText(
          text: 'saved_cards_title'.tr,
          fontSize: 18.sp,
          fontWeight: FontWeight.w600,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Get.back(),
        ),
      ),
      // v23.1 — FAB en bas-droite, position fixe avec marge sécurisée pour
      // ne pas être derrière la barre de gestes Android.
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      // v23.1 — FAB "Ajouter une carte" : flux de vérification réel.
      // Charge €0.50 (auto-remboursé par webhook) pour enregistrer la carte
      // sans qu'il y ait besoin d'une vraie réservation.
      floatingActionButton: Obx(() => FloatingActionButton.extended(
            backgroundColor: _verifying.value
                ? AppColors.primaryColor.withValues(alpha: 0.5)
                : AppColors.primaryColor,
            foregroundColor: Colors.white,
            icon: _verifying.value
                ? SizedBox(
                    width: 16.w,
                    height: 16.w,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.add_card_rounded),
            label: Text(
              _verifying.value
                  ? 'saved_cards_verifying'.tr
                  : 'saved_cards_add_button'.tr,
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.sp),
            ),
            onPressed: _verifying.value ? null : _onAddCardTap,
          )),
      body: SafeArea(
        child: RefreshIndicator(
        onRefresh: _load,
        child: Obx(() {
          if (isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }
          if (errorMessage.value != null) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(20.w),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline,
                        color: const Color(0xFFE53935), size: 48.sp),
                    SizedBox(height: 12.h),
                    InterText(
                      text: errorMessage.value!,
                      fontSize: 14.sp,
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 16.h),
                    ElevatedButton(
                      onPressed: _load,
                      child: Text('common_retry'.tr),
                    ),
                  ],
                ),
              ),
            );
          }
          if (cards.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: 80.h),
                Icon(Icons.credit_card_off,
                    size: 56.sp, color: Colors.grey),
                SizedBox(height: 16.h),
                Center(
                  child: PoppinsText(
                    text: 'saved_cards_empty_title'.tr,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8.h),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.w),
                  child: InterText(
                    text: 'saved_cards_empty_message'.tr,
                    fontSize: 13.sp,
                    color: Colors.grey,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            );
          }
          return ListView.separated(
            padding: EdgeInsets.all(16.w),
            itemCount: cards.length,
            separatorBuilder: (_, __) => SizedBox(height: 10.h),
            itemBuilder: (_, i) {
              final c = cards[i];
              final brand = (c['brand']?.toString() ?? '').toUpperCase();
              final last4 = c['last4']?.toString() ?? '••••';
              final mm = c['expiryMonth']?.toString() ?? '••';
              final yy = c['expiryYear']?.toString() ?? '••';
              final holder = c['cardholder']?.toString() ?? '';
              return Container(
                padding: EdgeInsets.all(14.w),
                decoration: BoxDecoration(
                  color: AppColors.card(context),
                  borderRadius: BorderRadius.circular(14.r),
                  boxShadow: AppColors.cardShadow(context),
                ),
                child: Row(
                  children: [
                    Icon(Icons.credit_card,
                        size: 28.sp, color: AppColors.primaryColor),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          PoppinsText(
                            text: '$brand •••• $last4',
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                          ),
                          SizedBox(height: 4.h),
                          InterText(
                            text: holder.isNotEmpty
                                ? '$holder · $mm/$yy'
                                : '$mm/$yy',
                            fontSize: 12.sp,
                            color: Colors.grey,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: Color(0xFFE53935)),
                      tooltip: 'common_delete'.tr,
                      onPressed: () => _confirmAndDelete(c),
                    ),
                  ],
                ),
              );
            },
          );
        }),
      ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/repositories/owner_repository.dart';
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

  void _showAddCardInfo() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('saved_cards_add_title'.tr),
        content: Text('saved_cards_add_message'.tr),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('common_ok'.tr),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
      // v23.1 — FAB "Ajouter une carte" : pour le moment redirige vers le
      // flow paiement (cocher "Enregistrer ma carte"). Une vraie route setup
      // standalone (Airwallex SDK setup mode) sera ajoutée en suivant.
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_card_rounded),
        label: Text(
          'saved_cards_add_button'.tr,
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.sp),
        ),
        onPressed: _showAddCardInfo,
      ),
      body: RefreshIndicator(
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
    );
  }
}

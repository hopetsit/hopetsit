// v565 — Daniel (17/09) : « toutes les notifications Apple ne marchent pas ».
// Écran de contrôle, ouvert depuis Profil › Aide › « Tester mes notifications » :
//   1. état réel de l'appareil : autorisation système, jeton FCM présent et
//      enregistré côté serveur, bouton « Réenregistrer cet appareil » ;
//   2. envoi d'un test à SOI-MÊME pour CHAQUE type du catalogue serveur
//      (POST /notifications/test-fire { type }) → on doit voir la bannière
//      (app ouverte, en arrière-plan, fermée) puis, au tap, le bon écran.
// Sert de preuve type par type sur un vrai iPhone / Android.
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/services/push_notification_service.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';

class NotificationTestScreen extends StatefulWidget {
  const NotificationTestScreen({super.key});

  @override
  State<NotificationTestScreen> createState() => _NotificationTestScreenState();
}

class _NotificationTestScreenState extends State<NotificationTestScreen> {
  List<String> _types = const [];
  bool _loading = true;
  String? _busyType;
  AuthorizationStatus? _perm;
  String? _token;

  ApiClient get _api =>
      Get.isRegistered<ApiClient>() ? Get.find<ApiClient>() : ApiClient();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final settings = await FirebaseMessaging.instance.getNotificationSettings();
      _perm = settings.authorizationStatus;
    } catch (_) {
      _perm = null;
    }
    try {
      _token = Get.isRegistered<PushNotificationService>()
          ? Get.find<PushNotificationService>().fcmToken.value
          : await FirebaseMessaging.instance.getToken();
    } catch (_) {
      _token = null;
    }
    try {
      final res = await _api.get('/notifications/test-types', requiresAuth: true);
      final list = (res is Map ? res['types'] : null) as List? ?? const [];
      _types = list.map((e) => e.toString()).toList();
    } catch (_) {
      _types = const [];
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _reRegister() async {
    setState(() => _busyType = '__register__');
    try {
      if (Get.isRegistered<PushNotificationService>()) {
        await Get.find<PushNotificationService>().reRegisterAfterLogin();
      }
      await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);
      await _load();
      CustomSnackbar.showSuccess(
          title: 'notif_test_title'.tr, message: 'notif_test_reregistered'.tr);
    } catch (e) {
      CustomSnackbar.showError(title: 'common_error'.tr, message: e.toString());
    } finally {
      if (mounted) setState(() => _busyType = null);
    }
  }

  Future<void> _fire(String type) async {
    setState(() => _busyType = type);
    try {
      await _api.post('/notifications/test-fire',
          body: {'type': type}, requiresAuth: true);
      CustomSnackbar.showSuccess(
          title: _label(type), message: 'notif_test_fire_ok'.tr);
    } catch (e) {
      CustomSnackbar.showError(title: 'notif_test_fire_err'.tr, message: e.toString());
    } finally {
      if (mounted) setState(() => _busyType = null);
    }
  }

  /// Catégorie (même mappage que le serveur, docs/v565_contracts.md §2).
  String _category(String type) {
    final t = type.toLowerCase();
    if (t.contains('message') || t.contains('chat')) return 'messages';
    if (t.startsWith('payment') || t.startsWith('payout') || t.startsWith('withdrawal') ||
        t.contains('wallet') || t == 'kyc_payment_succeeded' || t == 'referral_credited') {
      return 'payments';
    }
    if (t.startsWith('friend') || t.startsWith('family')) return 'friends';
    if (t.contains('sighting') || t.contains('sos') || t.contains('boost')) return 'pawmap';
    if (t.startsWith('live_')) return 'live';
    if (t == 'new_review' || t.contains('achieved')) return 'reviews';
    if (t.startsWith('subscription') || t.startsWith('kyc_')) return 'subscriptions';
    return 'bookings';
  }

  String _label(String type) =>
      type.toLowerCase().replaceAll('_', ' ').trim();

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.activeRoleAccent();
    final grouped = <String, List<String>>{};
    for (final t in _types) {
      grouped.putIfAbsent(_category(t), () => []).add(t);
    }
    const order = ['messages', 'bookings', 'payments', 'friends', 'pawmap', 'live', 'reviews', 'subscriptions'];
    final permOk = _perm == AuthorizationStatus.authorized ||
        _perm == AuthorizationStatus.provisional;
    final tokenOk = (_token ?? '').isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      appBar: AppBar(
        backgroundColor: AppColors.appBar(context),
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.textPrimary(context)),
        title: PoppinsText(
            text: 'notif_test_title'.tr,
            fontSize: 17.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary(context)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 32.h),
              children: [
                Container(
                  padding: EdgeInsets.all(14.w),
                  decoration: BoxDecoration(
                    color: AppColors.card(context),
                    borderRadius: BorderRadius.circular(16.r),
                    boxShadow: AppColors.cardShadow(context),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PoppinsText(
                          text: 'notif_test_device'.tr,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary(context)),
                      SizedBox(height: 8.h),
                      _statusRow(context, permOk,
                          permOk ? 'notif_test_perm_granted'.tr : 'notif_test_perm_denied'.tr),
                      SizedBox(height: 6.h),
                      _statusRow(context, tokenOk,
                          tokenOk ? 'notif_test_token_ok'.tr : 'notif_test_token_missing'.tr),
                      SizedBox(height: 12.h),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _busyType == null ? _reRegister : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accent,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.r)),
                          ),
                          icon: const Icon(Icons.sync_rounded, size: 18),
                          label: Text('notif_test_reregister'.tr),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 14.h),
                PoppinsText(
                    text: 'notif_test_hint'.tr,
                    fontSize: 12.sp,
                    color: AppColors.textSecondary(context)),
                SizedBox(height: 8.h),
                for (final cat in order)
                  if (grouped[cat] != null && grouped[cat]!.isNotEmpty) ...[
                    Padding(
                      padding: EdgeInsets.only(top: 14.h, bottom: 6.h),
                      child: PoppinsText(
                          text: 'notif_cat_$cat'.tr.toUpperCase(),
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.greyText),
                    ),
                    for (final t in grouped[cat]!)
                      _typeTile(context, t, accent),
                  ],
                if (_types.isEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: 24.h),
                    child: Center(
                      child: PoppinsText(
                          text: 'notif_test_fire_err'.tr,
                          fontSize: 13.sp,
                          color: AppColors.textSecondary(context)),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _statusRow(BuildContext context, bool ok, String label) {
    return Row(children: [
      Icon(ok ? Icons.check_circle_rounded : Icons.error_rounded,
          size: 18, color: ok ? const Color(0xFF16A34A) : const Color(0xFFDC2626)),
      SizedBox(width: 8.w),
      Expanded(
        child: PoppinsText(
            text: label, fontSize: 12.sp, color: AppColors.textPrimary(context)),
      ),
    ]);
  }

  Widget _typeTile(BuildContext context, String type, Color accent) {
    final busy = _busyType == type;
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(14.r),
        boxShadow: AppColors.cardShadow(context),
      ),
      child: ListTile(
        dense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 2.h),
        title: PoppinsText(
            text: _label(type),
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary(context)),
        subtitle: PoppinsText(
            text: type, fontSize: 10.sp, color: AppColors.textSecondary(context)),
        trailing: busy
            ? SizedBox(
                width: 18.w,
                height: 18.w,
                child: const CircularProgressIndicator(strokeWidth: 2))
            : Icon(Icons.send_rounded, color: accent, size: 20),
        onTap: _busyType == null ? () => _fire(type) : null,
      ),
    );
  }
}

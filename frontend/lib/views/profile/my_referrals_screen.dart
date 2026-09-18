import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/views/profile/widgets/profile_ui_kit.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';

/// Sprint 7 step 3 — user-facing referral program screen.
class MyReferralsScreen extends StatefulWidget {
  const MyReferralsScreen({super.key});

  @override
  State<MyReferralsScreen> createState() => _MyReferralsScreenState();
}

class _MyReferralsScreenState extends State<MyReferralsScreen> {
  final ApiClient _api =
      Get.isRegistered<ApiClient>() ? Get.find<ApiClient>() : ApiClient();
  String _code = '';
  List<dynamic> _referrals = const [];
  // v23.1.332 — récompense = nombre de réductions -10% (PawFollow/PawFamily)
  // disponibles (au lieu d'un total en euros).
  int _availableDiscounts = 0;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await _api.get('/users/me/referrals', requiresAuth: true);
      debugPrint('[REFERRALS DEBUG] response: $r');
      if (r is Map) {
        setState(() {
          _code = (r['code'] ?? '').toString();
          _referrals = (r['referrals'] as List?) ?? const [];
          _availableDiscounts =
              ((r['availableDiscounts'] ?? 0) as num).toInt();
        });
      }
    } catch (e) {
      debugPrint('[REFERRALS DEBUG] ERROR: $e');
      // v565 — plus de texte en dur : état d'erreur illustré + réessayer.
      if (mounted) setState(() => _error = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _statusLabel(dynamic status) =>
      status == 'completed' ? 'referrals_status_completed'.tr : 'referrals_status_pending'.tr;

  @override
  Widget build(BuildContext context) {
    // v565 — sous-page modernisée (kit Profil) : accent du rôle, carte du
    // code (copier / partager), explication, liste avec états.
    final accent = currentRoleAccent();
    return ProfileSubPageScaffold(
      title: 'referrals_title'.tr,
      accent: accent,
      scroll: false,
      body: _loading
          ? Center(child: CircularProgressIndicator(color: accent))
          : _error
              ? ProfileEmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: 'referrals_unavailable'.tr,
                  accent: accent,
                  error: true,
                  actionLabel: 'common_retry'.tr,
                  onAction: () {
                    setState(() {
                      _loading = true;
                      _error = false;
                    });
                    _load();
                  },
                )
              : RefreshIndicator(
                  color: accent,
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 28.h),
                    children: [
                      Container(
                        padding: EdgeInsets.all(18.w),
                        decoration: BoxDecoration(
                          color: AppColors.card(context),
                          borderRadius: BorderRadius.circular(20.r),
                          boxShadow: AppColors.cardShadow(context),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InterText(
                              text: 'referrals_my_code'.tr,
                              fontSize: 12.5.sp,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary(context),
                            ),
                            SizedBox(height: 8.h),
                            Row(
                              children: [
                                Expanded(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: PoppinsText(
                                      text: _code.isEmpty ? '——' : _code,
                                      fontSize: 28.sp,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 3,
                                      color: accent,
                                      maxLines: 1,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'referrals_copy'.tr,
                                  icon: Icon(Icons.copy_rounded, color: accent),
                                  onPressed: _code.isEmpty
                                      ? null
                                      : () {
                                          Clipboard.setData(ClipboardData(text: _code));
                                          CustomSnackbar.showSuccess(
                                            title: 'common_success'.tr,
                                            message: 'referrals_copied'.tr,
                                          );
                                        },
                                ),
                              ],
                            ),
                            SizedBox(height: 12.h),
                            ProfilePrimaryButton(
                              label: 'referrals_share'.tr,
                              accent: accent,
                              icon: Icons.ios_share_rounded,
                              onTap: _code.isEmpty
                                  ? null
                                  : () {
                                      final msg = 'referrals_share_text'.trParams({'code': _code});
                                      SharePlus.instance.share(ShareParams(text: msg));
                                    },
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 12.h),
                      ProfileInfoBanner(
                        icon: Icons.local_offer_rounded,
                        accent: const Color(0xFFF59E0B),
                        text: 'referrals_how_it_works'.tr,
                      ),
                      if (_availableDiscounts > 0) ...[
                        SizedBox(height: 10.h),
                        ProfileInfoBanner(
                          icon: Icons.check_circle_rounded,
                          accent: const Color(0xFF16A34A),
                          text: 'referrals_discounts_available'
                              .trParams({'count': _availableDiscounts.toString()}),
                        ),
                      ],
                      ProfileSectionTitle('referrals_list_title'.tr, icon: Icons.group_rounded),
                      if (_referrals.isEmpty)
                        ProfileEmptyState(
                          icon: Icons.group_add_rounded,
                          title: 'referrals_list_empty'.tr,
                          accent: accent,
                        )
                      else
                        ProfileGroupCard(
                          children: [
                            for (final r in _referrals.whereType<Map>())
                              ProfileRow(
                                icon: r['status'] == 'completed'
                                    ? Icons.check_circle_rounded
                                    : Icons.hourglass_bottom_rounded,
                                color: r['status'] == 'completed'
                                    ? const Color(0xFF16A34A)
                                    : const Color(0xFFF59E0B),
                                title: '#${(r['referredUserId'] ?? '').toString().padRight(8).substring(0, 8)}',
                                subtitle: _statusLabel(r['status']),
                                showChevron: false,
                                trailing: r['completedAt'] != null
                                    ? InterText(
                                        text: DateTime.tryParse(r['completedAt'].toString())
                                                ?.toLocal()
                                                .toString()
                                                .substring(0, 10) ??
                                            '',
                                        fontSize: 12.sp,
                                        color: AppColors.textSecondary(context),
                                      )
                                    : null,
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
    );
  }
}

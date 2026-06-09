import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/utils/app_colors.dart';

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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Parrainage indisponible : $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      appBar: AppBar(
        title: Text('referrals_title'.tr),
        backgroundColor: AppColors.appBar(context),
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('referrals_my_code'.tr),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.card(context),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: AppColors.cardShadow(context),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _code,
                          style: const TextStyle(
                              fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: 3),
                        ),
                      ),
                      IconButton(
                        tooltip: 'referrals_copy'.tr,
                        icon: const Icon(Icons.copy),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _code));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('referrals_copy'.tr)),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.share),
                  label: Text('referrals_share'.tr),
                  onPressed: () {
                    final msg = 'referrals_share_text'.trParams({'code': _code});
                    SharePlus.instance.share(ShareParams(text: msg));
                  },
                ),
                const SizedBox(height: 16),
                // v23.1.332 — Daniel : nouvelle récompense = -10% sur un plan
                // PawFollow/PawFamily (au lieu de 5€). Explication + nombre de
                // réductions disponibles.
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.30)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.local_offer_rounded,
                          color: Color(0xFFF59E0B)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'referrals_how_it_works'.tr,
                          style: const TextStyle(fontSize: 13, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (_availableDiscounts > 0)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'referrals_discounts_available'
                          .trParams({'count': _availableDiscounts.toString()}),
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, color: Colors.green),
                    ),
                  ),
                const SizedBox(height: 12),
                if (_referrals.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text('referrals_list_empty'.tr),
                  )
                else
                  for (final r in _referrals.cast<Map<String, dynamic>>())
                    ListTile(
                      leading: Icon(
                        r['status'] == 'completed' ? Icons.check_circle : Icons.hourglass_bottom,
                        color: r['status'] == 'completed' ? Colors.green : Colors.orange,
                      ),
                      title: Text('#${r['referredUserId'].toString().substring(0, 8)}'),
                      subtitle: Text(r['status'] == 'completed'
                          ? 'referrals_status_completed'.tr
                          : 'referrals_status_pending'.tr),
                      trailing: r['completedAt'] != null
                          ? Text(DateTime.parse(r['completedAt']).toLocal().toString().substring(0, 10))
                          : null,
                    ),
              ],
            ),
    );
  }
}

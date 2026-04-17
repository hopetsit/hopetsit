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
  double _totalCredits = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await _api.get('/users/me/referrals', requiresAuth: true);
      if (r is Map) {
        setState(() {
          _code = (r['code'] ?? '').toString();
          _referrals = (r['referrals'] as List?) ?? const [];
          _totalCredits = ((r['totalCredits'] ?? 0) as num).toDouble();
        });
      }
    } catch (_) {
      // silent
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
                    Share.share(msg);
                  },
                ),
                const SizedBox(height: 24),
                if (_totalCredits > 0)
                  Text(
                    'referrals_total_earned'.trParams({
                      'amount': _totalCredits.toStringAsFixed(2),
                      'currency': 'EUR',
                    }),
                    style: const TextStyle(fontWeight: FontWeight.w600),
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

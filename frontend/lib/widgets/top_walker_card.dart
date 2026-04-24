import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/utils/storage_keys.dart';
import 'package:hopetsit/utils/app_colors.dart';

/// v20.0.7 — Top Walker status card for the walker's own profile.
/// Mirrors TopSitterCard but uses walker-specific endpoint + counters.
class TopWalkerCard extends StatefulWidget {
  const TopWalkerCard({super.key});

  @override
  State<TopWalkerCard> createState() => _TopWalkerCardState();
}

class _TopWalkerCardState extends State<TopWalkerCard> {
  final ApiClient _api =
      Get.isRegistered<ApiClient>() ? Get.find<ApiClient>() : ApiClient();
  bool _loading = true;
  bool _isTop = false;
  int _completed = 0;
  double _avg = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final profile =
          GetStorage().read<Map<String, dynamic>>(StorageKeys.userProfile);
      final walkerId = profile?['id']?.toString() ?? '';
      if (walkerId.isEmpty) return;
      final r = await _api.get('/walkers/$walkerId', requiresAuth: true);
      final walker = (r is Map && r['walker'] is Map)
          ? Map<String, dynamic>.from(r['walker'])
          : (r is Map ? Map<String, dynamic>.from(r) : null);
      if (walker != null) {
        setState(() {
          _isTop = walker['isTopWalker'] == true;
          _completed =
              (walker['completedWalksCount'] as num?)?.toInt() ??
                  (walker['completedServicesCount'] as num?)?.toInt() ??
                  0;
          _avg = (walker['averageRating'] as num?)?.toDouble() ?? 0.0;
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
    if (_loading) return const SizedBox.shrink();
    final walkerGreen = const Color(0xFF16A34A);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.cardShadow(context),
        border: Border.all(
          color: _isTop ? Colors.amber : walkerGreen.withValues(alpha: 0.25),
          width: _isTop ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _isTop ? Icons.emoji_events_rounded : Icons.trending_up_rounded,
                color: _isTop ? Colors.amber : walkerGreen,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _isTop
                      ? 'top_walker_achieved'.tr
                      : 'top_walker_badge'.tr,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('top_walker_progress'.trParams({
            'done': _completed.toString(),
            'goal': '20',
            'rating': _avg.toStringAsFixed(1),
          })),
          const SizedBox(height: 4),
          Text(
            _isTop
                ? 'top_walker_commission_15'.tr
                : 'top_walker_need_more'.trParams({
                    'walks': (20 - _completed).clamp(0, 20).toString(),
                    'rating': (4.5 - _avg > 0 ? (4.5 - _avg) : 0)
                        .toStringAsFixed(1),
                  }),
            style: TextStyle(
              color: _isTop ? Colors.green : Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

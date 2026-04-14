import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/utils/storage_keys.dart';

/// Sprint 7 step 2 — Top Sitter status card for the sitter's own profile.
class TopSitterCard extends StatefulWidget {
  const TopSitterCard({super.key});

  @override
  State<TopSitterCard> createState() => _TopSitterCardState();
}

class _TopSitterCardState extends State<TopSitterCard> {
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
      final profile = GetStorage().read<Map<String, dynamic>>(StorageKeys.userProfile);
      final sitterId = profile?['id']?.toString() ?? '';
      if (sitterId.isEmpty) return;
      final r = await _api.get('/sitters/$sitterId', requiresAuth: true);
      final sitter = (r is Map && r['sitter'] is Map)
          ? Map<String, dynamic>.from(r['sitter'])
          : (r is Map ? Map<String, dynamic>.from(r) : null);
      if (sitter != null) {
        setState(() {
          _isTop = sitter['isTopSitter'] == true;
          _completed = (sitter['completedServicesCount'] as num?)?.toInt() ?? 0;
          _avg = (sitter['averageRating'] as num?)?.toDouble() ?? 0.0;
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isTop ? Colors.amber : Colors.transparent,
          width: _isTop ? 2 : 0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isTop ? 'top_sitter_achieved'.tr : 'top_sitter_badge'.tr,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text('top_sitter_progress'.trParams({
            'done': _completed.toString(),
            'goal': '20',
            'rating': _avg.toStringAsFixed(1),
          })),
          const SizedBox(height: 4),
          Text(
            _isTop
                ? 'top_sitter_commission_15'.tr
                : 'top_sitter_need_more'.trParams({
                    'bookings': (20 - _completed).clamp(0, 20).toString(),
                    'rating': (4.5 - _avg > 0 ? (4.5 - _avg) : 0).toStringAsFixed(1),
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

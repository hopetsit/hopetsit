// Refonte PawSpot — classement communautaire PawPoints.
// 3 scopes (ville / pays / Europe) via GET /pawspots/leaderboard?scope=…,
// en-tête avec mes points + badge (GET /pawspots/me/points).
// Identité PawSpot : empreinte / trophée sur accent DORÉ (0xFFE8A00A).

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';

class PawspotLeaderboardScreen extends StatefulWidget {
  const PawspotLeaderboardScreen({super.key});

  @override
  State<PawspotLeaderboardScreen> createState() =>
      _PawspotLeaderboardScreenState();
}

class _PawspotLeaderboardScreenState extends State<PawspotLeaderboardScreen> {
  static const Color _gold = Color(0xFFE8A00A);
  static const Color _goldLight = Color(0xFFFFD700);

  Map<String, dynamic> _me = const {};

  @override
  void initState() {
    super.initState();
    _loadMyPoints();
  }

  Future<void> _loadMyPoints() async {
    try {
      final data = await Get.find<ApiClient>()
          .get('/pawspots/me/points', requiresAuth: true);
      if (!mounted) return;
      if (data is Map) {
        setState(() => _me = Map<String, dynamic>.from(data));
      }
    } catch (_) {
      // Best-effort : l'en-tête reste à 0 pts si l'appel échoue.
    }
  }

  /// Mapping key backend → libellé traduit (inclut déjà emoji + seuil).
  static String badgeLabel(String key) {
    switch (key) {
      case 'explorer':
        return 'pawspot_badge_explorer'.tr;
      case 'expert':
        return 'pawspot_badge_expert'.tr;
      case 'ambassador':
        return 'pawspot_badge_ambassador'.tr;
      case 'pawmaster':
        return 'pawspot_badge_pawmaster'.tr;
      default:
        return key;
    }
  }

  /// Mapping key backend → emoji seul (pour les rangées du classement).
  static String badgeEmoji(String badge) {
    switch (badge) {
      case 'explorer':
        return '🥉';
      case 'expert':
        return '🥈';
      case 'ambassador':
        return '🥇';
      case 'pawmaster':
        return '👑';
      default:
        // Le backend peut renvoyer directement un emoji.
        return badge;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.scaffold(context),
        appBar: AppBar(
          backgroundColor: AppColors.appBar(context),
          elevation: 0,
          scrolledUnderElevation: 0.5,
          surfaceTintColor: Colors.transparent,
          title: Row(
            children: [
              Icon(Icons.emoji_events_rounded, color: _gold, size: 22.sp),
              SizedBox(width: 8.w),
              InterText(
                text: 'pawspot_leaderboard_title'.tr,
                fontSize: 18.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary(context),
              ),
            ],
          ),
          bottom: TabBar(
            labelColor: _gold,
            unselectedLabelColor: AppColors.greyText,
            indicatorColor: _gold,
            labelStyle: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700),
            unselectedLabelStyle:
                TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w500),
            tabs: [
              Tab(text: 'pawspot_lb_city'.tr),
              Tab(text: 'pawspot_lb_country'.tr),
              Tab(text: 'pawspot_lb_europe'.tr),
            ],
          ),
        ),
        body: Column(
          children: [
            _buildMyPointsHeader(context),
            const Expanded(
              child: TabBarView(
                children: [
                  _LeaderboardList(scope: 'city'),
                  _LeaderboardList(scope: 'country'),
                  _LeaderboardList(scope: 'europe'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// En-tête doré : mes PawPoints + mon badge actuel.
  Widget _buildMyPointsHeader(BuildContext context) {
    final points = (_me['points'] as num?)?.toInt() ?? 0;
    final badge = _me['badge'] is Map
        ? Map<String, dynamic>.from(_me['badge'] as Map)
        : null;
    return Container(
      margin: EdgeInsets.all(16.w),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_gold, _goldLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: _gold.withValues(alpha: 0.30),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48.w,
            height: 48.w,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text('🐾', style: TextStyle(fontSize: 24.sp)),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InterText(
                  text: 'pawspot_points_title'.tr,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.95),
                ),
                SizedBox(height: 2.h),
                PoppinsText(
                  text: '$points pts',
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ],
            ),
          ),
          if (badge != null)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: InterText(
                text: badgeLabel((badge['key'] ?? '').toString()),
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
        ],
      ),
    );
  }
}

/// Une liste de classement pour un scope donné (city | country | europe).
class _LeaderboardList extends StatefulWidget {
  const _LeaderboardList({required this.scope});

  final String scope;

  @override
  State<_LeaderboardList> createState() => _LeaderboardListState();
}

class _LeaderboardListState extends State<_LeaderboardList>
    with AutomaticKeepAliveClientMixin {
  static const Color _gold = Color(0xFFE8A00A);

  bool _loading = true;
  List<Map<String, dynamic>> _rows = const [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await Get.find<ApiClient>().get(
        '/pawspots/leaderboard',
        queryParameters: {'scope': widget.scope},
        requiresAuth: true,
      );
      if (!mounted) return;
      final list = (data is Map ? data['leaderboard'] : null) as List? ?? [];
      setState(() => _rows = list
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList());
    } catch (_) {
      // Best-effort : liste vide en cas d'erreur.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Parse '#RRGGBB' → Color (null si invalide).
  Color? _hexColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    final cleaned = hex.replaceAll('#', '');
    if (cleaned.length != 6) return null;
    final value = int.tryParse(cleaned, radix: 16);
    return value == null ? null : Color(0xFF000000 | value);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_rows.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: 80.h),
            Icon(Icons.emoji_events_outlined,
                size: 44.sp, color: AppColors.greyText),
            SizedBox(height: 10.h),
            Center(
              child: PoppinsText(
                text: '—',
                fontSize: 18.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.greyText,
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 24.h),
        itemCount: _rows.length,
        itemBuilder: (context, index) => _buildRow(context, index, _rows[index]),
      ),
    );
  }

  Widget _buildRow(BuildContext context, int index, Map<String, dynamic> row) {
    final rank = index + 1;
    final name = (row['name'] ?? '').toString();
    final avatar = (row['avatar'] ?? '').toString();
    final points = (row['points'] as num?)?.toInt() ?? 0;
    final badge = (row['badge'] ?? '').toString();
    final goldFrame = row['goldFrame'] == true;
    final badgeColor = _hexColor((row['badgeColor'] as String?));

    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(14.r),
        boxShadow: AppColors.cardShadow(context),
        border: rank <= 3
            ? Border.all(color: _gold.withValues(alpha: 0.4), width: 1.2)
            : null,
      ),
      child: Row(
        children: [
          // Rang : médailles pour le podium, numéro sinon.
          SizedBox(
            width: 32.w,
            child: rank <= 3
                ? Text(
                    rank == 1
                        ? '🥇'
                        : rank == 2
                            ? '🥈'
                            : '🥉',
                    style: TextStyle(fontSize: 20.sp),
                  )
                : PoppinsText(
                    text: '$rank',
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.greyText,
                    textAlign: TextAlign.center,
                  ),
          ),
          SizedBox(width: 8.w),
          // Avatar — ANNEAU DORÉ si la récompense gold_frame est active.
          Container(
            padding: EdgeInsets.all(goldFrame ? 2.w : 0),
            decoration: goldFrame
                ? const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFFE8A00A), Color(0xFFFFD700)],
                    ),
                  )
                : null,
            child: ClipOval(
              child: avatar.startsWith('http')
                  ? CachedNetworkImage(
                      imageUrl: avatar,
                      width: 40.w,
                      height: 40.w,
                      memCacheWidth: 120,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _avatarFallback(),
                      placeholder: (_, __) => _avatarFallback(),
                    )
                  : _avatarFallback(),
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                InterText(
                  text: name,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                // v23.1.365 — Daniel : "dans Pays/Europe rien n'apparaît,
                // juste les points". Le pays (dérivé de l'indicatif tél. à
                // l'inscription) + la ville sous le nom : 🇪🇸 España · Madrid.
                Builder(builder: (context) {
                  final flag = (row['countryFlag'] as String?) ?? '';
                  final country = (row['countryName'] as String?) ?? '';
                  final city = (row['city'] as String?) ?? '';
                  final parts = <String>[
                    if (flag.isNotEmpty || country.isNotEmpty)
                      '$flag $country'.trim(),
                    if (city.isNotEmpty) city,
                  ];
                  if (parts.isEmpty) return const SizedBox.shrink();
                  return InterText(
                    text: parts.join(' · '),
                    fontSize: 11.sp,
                    color: AppColors.greyText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  );
                }),
              ],
            ),
          ),
          if (badge.isNotEmpty) ...[
            SizedBox(width: 6.w),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 3.h),
              decoration: BoxDecoration(
                color: (badgeColor ?? _gold).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Text(
                _PawspotLeaderboardScreenState.badgeEmoji(badge),
                style: TextStyle(fontSize: 14.sp),
              ),
            ),
          ],
          SizedBox(width: 8.w),
          PoppinsText(
            text: '$points',
            fontSize: 15.sp,
            fontWeight: FontWeight.w800,
            color: _gold,
          ),
          SizedBox(width: 3.w),
          InterText(
            text: 'pts',
            fontSize: 10.sp,
            color: AppColors.greyText,
          ),
        ],
      ),
    );
  }

  Widget _avatarFallback() {
    return Container(
      width: 40.w,
      height: 40.w,
      color: AppColors.greyText.withValues(alpha: 0.2),
      child: Icon(Icons.person, size: 22.sp, color: AppColors.greyText),
    );
  }
}

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

/// v435 — Daniel : la boutique PawSpot affichait d'anciennes récompenses
/// hardcodées (badge/cadre/bannière). Cette fonction ouvre le VRAI catalogue
/// PawPoints (lu depuis /pawpoints/catalog + /pawpoints/me, éditable par
/// l'admin sans rebuild) — la même feuille que le classement PawSpot.
/// [myPoints] = solde dépensable connu de l'appelant (sert d'affichage
/// initial avant que la feuille recharge /pawpoints/me).
/// [onChanged] est appelé après un échange réussi pour rafraîchir l'appelant.
Future<void> showPawPointsRewardsSheet(
  BuildContext context, {
  int myPoints = 0,
  Future<void> Function()? onChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _RewardsSheet(
      myPoints: myPoints,
      onChanged: onChanged ?? () async {},
    ),
  );
}

/// v440 — Daniel : "dans la boutique PawSpot, au lieu d'un onglet « voir les
/// récompenses » je veux la page complète écrite ouverte". Cet encart rend le
/// VRAI catalogue PawPoints (/pawpoints/catalog + /pawpoints/me, éditable par
/// l'admin sans rebuild) DIRECTEMENT inline dans une page qui scrolle déjà
/// (la boutique PawSpot) — pas derrière un bouton ni dans un bottom sheet.
/// L'échange de récompenses reste fonctionnel (même flux que le sheet).
/// [myPoints] = solde dépensable connu de l'appelant (affiché avant que la
/// liste recharge /pawpoints/me). [onChanged] est appelé après un échange
/// réussi pour rafraîchir l'appelant.
class PawPointsRewardsList extends StatelessWidget {
  const PawPointsRewardsList({
    super.key,
    this.myPoints = 0,
    this.onChanged,
  });

  final int myPoints;
  final Future<void> Function()? onChanged;

  @override
  Widget build(BuildContext context) {
    return _RewardsSheet(
      myPoints: myPoints,
      onChanged: onChanged ?? () async {},
      embedded: true,
    );
  }
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
      case 'contributor':
        return 'Contributeur';
      case 'expert':
        return 'pawspot_badge_expert'.tr;
      case 'ambassador':
        return 'pawspot_badge_ambassador'.tr;
      case 'pawmaster':
        return 'pawspot_badge_pawmaster'.tr;
      case 'legend':
        return 'Légendaire';
      case 'paw_legend':
        return 'Paw Legend';
      default:
        return key;
    }
  }

  /// Mapping key backend → emoji seul (pour les rangées du classement).
  /// v416 — aligné sur les 7 niveaux (cf pawPointsService.LEVELS).
  static String badgeEmoji(String badge) {
    switch (badge) {
      case 'explorer':
        return '🧭';
      case 'contributor':
        return '🐾';
      case 'expert':
        return '⭐';
      case 'ambassador':
        return '🦴';
      case 'pawmaster':
      case 'legend':
      case 'paw_legend':
        return '👑';
      default:
        // Le backend peut renvoyer directement un emoji.
        return badge;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
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
            isScrollable: true,
            tabAlignment: TabAlignment.center,
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
              // v420 — onglet Récompenses à droite de Europe (Daniel).
              Tab(text: '🎁 ${'pawpoints_rewards_title'.tr}'),
            ],
          ),
        ),
        body: Column(
          children: [
            _buildMyPointsHeader(context),
            Expanded(
              child: TabBarView(
                children: [
                  const _LeaderboardList(scope: 'city'),
                  const _LeaderboardList(scope: 'country'),
                  const _LeaderboardList(scope: 'europe'),
                  // v420 — 4e onglet : récompenses listées inline (pas un sheet).
                  _RewardsSheet(
                    inTab: true,
                    myPoints: (_me['points'] as num?)?.toInt() ?? 0,
                    onChanged: _loadMyPoints,
                  ),
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
      child: Column(
        children: [
          Row(
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
                  padding:
                      EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
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
          // v414 — Daniel : "améliore la liste de points et de récompenses".
          // CTA vers le catalogue de récompenses (lu depuis /pawpoints/catalog,
          // éditable par l'admin sans rebuild).
          SizedBox(height: 12.h),
          SizedBox(
            width: double.infinity,
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.r),
              child: InkWell(
                borderRadius: BorderRadius.circular(12.r),
                onTap: () => _openRewards(context, points),
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 11.h),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('🎁', style: TextStyle(fontSize: 16.sp)),
                      SizedBox(width: 8.w),
                      InterText(
                        text: 'pawpoints_rewards_cta'.tr,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w800,
                        color: _gold,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// v414 — Ouvre le catalogue de récompenses + barème (GET /pawpoints/catalog).
  Future<void> _openRewards(BuildContext context, int myPoints) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RewardsSheet(myPoints: myPoints, onChanged: _loadMyPoints),
    );
  }
}
/// v416 — Feuille « Mes PawPoints » (refonte design Daniel) : stats, barre de
/// niveau, réductions/mois gratuits sur abonnements (échange auto, 1×/user),
/// 7 niveaux exclusifs + objectif Paw Legend, et barème de gains.
class _RewardsSheet extends StatefulWidget {
  const _RewardsSheet({
    required this.myPoints,
    required this.onChanged,
    this.inTab = false,
    this.embedded = false,
  });

  final int myPoints;
  final Future<void> Function() onChanged;
  // v420 — true = rendu inline dans l'onglet « Récompenses » (pas un sheet).
  final bool inTab;
  // v440 — true = encart imbriqué dans une page qui scrolle déjà (boutique
  // PawSpot). On rend une Column non-scrollable (shrinkWrap) au lieu d'une
  // ListView pour éviter les conflits de scroll imbriqués.
  final bool embedded;

  @override
  State<_RewardsSheet> createState() => _RewardsSheetState();
}

class _RewardsSheetState extends State<_RewardsSheet> {
  static const Color _gold = Color(0xFFE8A00A);

  bool _loading = true;
  String? _busyId;

  // /me
  int _lifetime = 0;
  int _spendable = 0;
  int _contributions = 0;
  int _spotsLiked = 0;
  int _bonusPct = 0;
  Map<String, dynamic>? _level;
  Map<String, dynamic>? _nextLevel;
  List<Map<String, dynamic>> _levels = const [];
  List<Map<String, dynamic>> _earn = const [];
  Set<String> _claimed = {};
  // /catalog
  List<Map<String, dynamic>> _subRewards = const [];
  // v450 — Daniel : « vérifie que les récompenses fonctionnent ». Les
  // récompenses créées dans l'admin (PawReward) arrivent dans cat['rewards']
  // mais n'étaient jamais lues → invisibles dans l'app. On les charge ici.
  List<Map<String, dynamic>> _customRewards = const [];

  @override
  void initState() {
    super.initState();
    _spendable = widget.myPoints;
    _load();
  }

  List<Map<String, dynamic>> _list(dynamic v) => (v as List? ?? [])
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();

  Future<void> _load() async {
    try {
      final api = Get.find<ApiClient>();
      final cat = await api.get('/pawpoints/catalog');
      final me = await api.get('/pawpoints/me', requiresAuth: true);
      if (!mounted) return;
      setState(() {
        if (cat is Map) {
          _subRewards = _list(cat['subscriptionRewards']);
          _customRewards = _list(cat['rewards']);
        }
        if (me is Map) {
          _lifetime = (me['lifetime'] as num?)?.toInt() ?? 0;
          _spendable = (me['spendable'] as num?)?.toInt() ?? _spendable;
          _contributions = (me['contributions'] as num?)?.toInt() ?? 0;
          _spotsLiked = (me['spotsLiked'] as num?)?.toInt() ?? 0;
          _bonusPct = (me['bonusPct'] as num?)?.toInt() ?? 0;
          _level = me['level'] is Map ? Map<String, dynamic>.from(me['level']) : null;
          _nextLevel = me['nextLevel'] is Map ? Map<String, dynamic>.from(me['nextLevel']) : null;
          _levels = _list(me['levels']);
          _earn = _list(me['earnRules']);
          // claimedRewardKeys est une liste de strings (sub_*).
          final ck = me['claimedRewardKeys'];
          _claimed = ck is List ? ck.map((e) => e.toString()).toSet() : <String>{};
        }
      });
    } catch (_) {
      // best-effort
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  static Color _hex(String? h) {
    if (h == null || h.isEmpty) return _gold;
    final c = h.replaceAll('#', '');
    if (c.length != 6) return _gold;
    final v = int.tryParse(c, radix: 16);
    return v == null ? _gold : Color(0xFF000000 | v);
  }

  static const Map<int, String> _tierIcon = {
    1: '🥉', 2: '🥈', 3: '🥇', 4: '🟣', 5: '🟡', 6: '🌸',
  };

  String _perkLabel(String p) {
    switch (p) {
      case 'badge':
        return 'pawpoints_perk_badge'.tr;
      case 'chests_basic':
        return 'pawpoints_perk_chests'.tr;
      case 'map_visibility':
        return 'pawpoints_perk_map'.tr;
      case 'bonus_5':
        return 'pawpoints_perk_bonus5'.tr;
      case 'bonus_10':
        return 'pawpoints_perk_bonus10'.tr;
      case 'free_pawboost':
        return 'pawpoints_perk_boost'.tr;
      case 'legendary_frame':
        return 'pawpoints_perk_frame'.tr;
      case 'legendary_status':
        return 'pawpoints_perk_status'.tr;
      case 'pink_crown':
        return 'pawpoints_perk_crown'.tr;
      case 'ultimate':
        return 'pawpoints_perk_ultimate'.tr;
      default:
        return p;
    }
  }

  Future<void> _redeem(Map<String, dynamic> r) async {
    final id = (r['id'] ?? '').toString();
    final cost = (r['cost'] as num?)?.toInt() ?? 0;
    final kind = (r['kind'] ?? '').toString();
    if (id.isEmpty || _busyId != null) return;
    if (_claimed.contains(id)) {
      Get.snackbar('pawpoints_already_claimed'.tr, '',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    if (_spendable < cost) {
      Get.snackbar('pawpoints_not_enough'.tr, '',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    setState(() => _busyId = id);
    try {
      final res = await Get.find<ApiClient>()
          .post('/pawpoints/redeem/$id', body: const {}, requiresAuth: true);
      if (!mounted) return;
      final applied = (res is Map ? res['applied'] : '')?.toString();
      Get.snackbar(
        'pawpoints_redeemed'.tr,
        kind == 'free_month' || applied == 'fulfilled'
            ? 'pawpoints_applied_now'.tr
            : 'pawpoints_applied_next'.tr,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 4),
      );
      await widget.onChanged();
      await _load();
    } catch (e) {
      Get.snackbar('common_error'.tr, e.toString(),
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Widget _rewardsList(ScrollController? scroll) {
    if (_loading) {
      // v440 — encart imbriqué : pas de hauteur infinie (Center planterait
      // dans un parent non-borné). On garde un spinner compact.
      if (widget.embedded) {
        return Padding(
          padding: EdgeInsets.symmetric(vertical: 24.h),
          child: const Center(child: CircularProgressIndicator()),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }
    final children = <Widget>[
      _statsRow(context),
      SizedBox(height: 12.h),
      _levelBar(context),
      SizedBox(height: 22.h),
      _sectionTitle(context, 'pawpoints_sub_rewards_title'.tr,
          'pawpoints_sub_rewards_sub'.tr),
      SizedBox(height: 10.h),
      ..._subRewards.map((r) => _subRewardRow(context, r)),
      // v450 — récompenses créées dans l'admin (PawReward). Affichées + échangeables.
      if (_customRewards.isNotEmpty) ...[
        SizedBox(height: 22.h),
        _sectionTitle(context, 'pawpoints_rewards_title'.tr,
            'pawpoints_rewards_sub'.tr),
        SizedBox(height: 10.h),
        ..._customRewards.map((r) => _customRewardRow(context, r)),
      ],
      SizedBox(height: 22.h),
      _sectionTitle(context, 'pawpoints_levels_title'.tr,
          'pawpoints_levels_sub'.tr),
      SizedBox(height: 10.h),
      ..._levels.map((l) => _levelCard(context, l)),
      SizedBox(height: 16.h),
      _pawLegendCard(context),
      SizedBox(height: 22.h),
      if (_earn.isNotEmpty) ...[
        _sectionTitle(context, 'pawpoints_how_to_earn'.tr, ''),
        SizedBox(height: 10.h),
        ..._earn.map((e) => _earnRow(context, e)),
      ],
    ];
    // v440 — encart boutique PawSpot : Column non-scrollable (le parent
    // SingleChildScrollView gère le scroll).
    if (widget.embedded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      );
    }
    return ListView(
      controller: scroll,
      padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 28.h),
      children: children,
    );
  }

  @override
  Widget build(BuildContext context) {
    // v420 — Daniel : "à droite de Europe, un onglet Récompenses avec tout
    // listé". inTab=true → on rend la liste directement (pas de bottom sheet).
    // v440 — embedded=true → encart imbriqué dans la boutique PawSpot (Column).
    if (widget.inTab || widget.embedded) {
      return _rewardsList(null);
    }
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scroll) => Container(
        decoration: BoxDecoration(
          color: AppColors.scaffold(context),
          borderRadius: BorderRadius.vertical(top: Radius.circular(22.r)),
        ),
        child: Column(
          children: [
            SizedBox(height: 10.h),
            Container(
              width: 42.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: AppColors.greyText.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(4.r),
              ),
            ),
            SizedBox(height: 10.h),
            Expanded(child: _rewardsList(scroll)),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title, String sub) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PoppinsText(
          text: title,
          fontSize: 17.sp,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary(context),
        ),
        if (sub.isNotEmpty) ...[
          SizedBox(height: 2.h),
          InterText(text: sub, fontSize: 12.sp, color: AppColors.greyText),
        ],
      ],
    );
  }

  Widget _statsRow(BuildContext context) {
    Widget card(String emoji, String value, String label, {bool accent = false}) {
      return Expanded(
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 3.w),
          padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 6.w),
          decoration: BoxDecoration(
            color: AppColors.card(context),
            borderRadius: BorderRadius.circular(14.r),
            border: accent
                ? Border.all(color: _gold.withValues(alpha: 0.5), width: 1.2)
                : null,
            boxShadow: AppColors.cardShadow(context),
          ),
          child: Column(
            children: [
              Text(emoji, style: TextStyle(fontSize: 18.sp)),
              SizedBox(height: 4.h),
              PoppinsText(
                text: value,
                fontSize: 16.sp,
                fontWeight: FontWeight.w800,
                color: accent ? _gold : AppColors.textPrimary(context),
              ),
              SizedBox(height: 2.h),
              InterText(
                text: label,
                fontSize: 9.sp,
                color: AppColors.greyText,
                textAlign: TextAlign.center,
                maxLines: 2,
              ),
            ],
          ),
        ),
      );
    }

    final levelLabel = _level != null ? (_level!['label'] ?? '').toString() : '—';
    return Row(
      children: [
        card('🚩', '$_contributions', 'pawpoints_stat_contributions'.tr),
        card('❤️', '$_spotsLiked', 'pawpoints_stat_liked'.tr),
        card('🏅', levelLabel, 'pawpoints_stat_level'.tr, accent: true),
        card('🪙', '$_spendable', 'pawpoints_stat_points'.tr, accent: true),
      ],
    );
  }

  Widget _levelBar(BuildContext context) {
    final prevMin = _level != null ? ((_level!['min'] as num?)?.toInt() ?? 0) : 0;
    final nextMin =
        _nextLevel != null ? ((_nextLevel!['min'] as num?)?.toInt() ?? prevMin) : prevMin;
    final hasNext = _nextLevel != null;
    final span = (nextMin - prevMin);
    final frac = hasNext && span > 0
        ? ((_lifetime - prevMin) / span).clamp(0.0, 1.0)
        : 1.0;
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: AppColors.cardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: InterText(
                  text: hasNext
                      ? 'pawpoints_to_next'.trParams({
                          'pts': '${(nextMin - _lifetime).clamp(0, nextMin)}',
                          'level': (_nextLevel!['label'] ?? '').toString(),
                        })
                      : 'pawpoints_max_level'.tr,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary(context),
                ),
              ),
              InterText(
                text: hasNext ? '$_lifetime / $nextMin' : '$_lifetime',
                fontSize: 11.sp,
                color: AppColors.greyText,
              ),
            ],
          ),
          SizedBox(height: 8.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(6.r),
            child: LinearProgressIndicator(
              value: frac,
              minHeight: 10.h,
              backgroundColor: AppColors.greyText.withValues(alpha: 0.15),
              valueColor: const AlwaysStoppedAnimation(_gold),
            ),
          ),
          if (_bonusPct > 0) ...[
            SizedBox(height: 8.h),
            InterText(
              text: 'pawpoints_bonus_active'.trParams({'pct': '$_bonusPct'}),
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: _gold,
            ),
          ],
        ],
      ),
    );
  }

  Widget _subRewardRow(BuildContext context, Map<String, dynamic> r) {
    final id = (r['id'] ?? '').toString();
    final cost = (r['cost'] as num?)?.toInt() ?? 0;
    final tier = (r['tier'] as num?)?.toInt() ?? 1;
    final kind = (r['kind'] ?? '').toString();
    final percent = (r['percent'] as num?)?.toInt() ?? 0;
    final days = (r['days'] as num?)?.toInt() ?? 0;
    final target = (r['target'] ?? '').toString();
    final claimed = _claimed.contains(id);
    final affordable = _spendable >= cost;
    final busy = _busyId == id;
    final value = kind == 'discount'
        ? '-$percent%'
        : (days >= 90 ? 'pawpoints_3m_free'.tr : 'pawpoints_1m_free'.tr);
    final free = kind == 'free_month';

    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(14.r),
        boxShadow: AppColors.cardShadow(context),
      ),
      child: Row(
        children: [
          Container(
            width: 42.w,
            height: 42.w,
            decoration: BoxDecoration(
              color: _gold.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(_tierIcon[tier] ?? '🪙',
                  style: TextStyle(fontSize: 20.sp)),
            ),
          ),
          SizedBox(width: 8.w),
          // v443 — Daniel : « valable un mois » s'affichait À LA VERTICALE
          // (une lettre par ligne) dans la boutique PawSpot. CAUSE : encart
          // récompenses imbriqué dans une carte étroite (double padding 16+16)
          // → trop d'enfants à largeur fixe dans la Row ; le badge de valeur
          // (« 1 mois GRATUIT » / « 3 mois GRATUITS ») et la colonne libellé
          // se faisaient écraser à ~0px et se repliaient caractère par
          // caractère. FIX : la colonne points devient Flexible (plus de
          // largeur fixe 64), le badge passe en maxLines:1 + ellipsis et est
          // enveloppé dans Flexible pour qu'il cède de l'espace au lieu de
          // déborder/écraser. Le texte se lit désormais normalement sur une
          // ligne.
          Flexible(
            flex: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                PoppinsText(
                  text: '$cost',
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary(context),
                ),
                InterText(text: 'pts', fontSize: 9.sp, color: AppColors.greyText),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          Flexible(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: free ? const Color(0xFF7C3AED) : _gold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: InterText(
                text: value,
                fontSize: 11.sp,
                fontWeight: FontWeight.w800,
                color: free ? Colors.white : _gold,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InterText(
                  text: target,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                InterText(
                  text: 'pawpoints_once'.tr,
                  fontSize: 9.sp,
                  color: AppColors.greyText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          SizedBox(width: 6.w),
          SizedBox(
            height: 30.h,
            child: ElevatedButton(
              onPressed: (claimed || !affordable || busy) ? null : () => _redeem(r),
              style: ElevatedButton.styleFrom(
                backgroundColor: _gold,
                disabledBackgroundColor: AppColors.greyText.withValues(alpha: 0.3),
                padding: EdgeInsets.symmetric(horizontal: 10.w),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r)),
              ),
              child: busy
                  ? SizedBox(
                      width: 14.w,
                      height: 14.w,
                      child: const CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : InterText(
                      text: claimed
                          ? 'pawpoints_used'.tr
                          : affordable
                              ? 'pawpoints_redeem'.tr
                              : 'pawpoints_locked'.tr,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // v450 — ligne récompense admin custom (PawReward). Même style que les
  // récompenses abonnement ; échange via le même POST /pawpoints/redeem/:id
  // (id = ObjectId). soldOut → bouton désactivé.
  Widget _customRewardRow(BuildContext context, Map<String, dynamic> r) {
    final cost = (r['cost'] as num?)?.toInt() ?? 0;
    final icon = (r['icon'] ?? '🎁').toString();
    final title = (r['title'] ?? '').toString();
    final valueLabel = (r['valueLabel'] ?? '').toString();
    final soldOut = r['soldOut'] == true;
    final affordable = _spendable >= cost;
    final busy = _busyId == (r['id'] ?? '').toString();
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(14.r),
        boxShadow: AppColors.cardShadow(context),
      ),
      child: Row(
        children: [
          Container(
            width: 42.w,
            height: 42.w,
            decoration: BoxDecoration(
              color: _gold.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(child: Text(icon, style: TextStyle(fontSize: 20.sp))),
          ),
          SizedBox(width: 8.w),
          Flexible(
            flex: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                PoppinsText(
                  text: '$cost',
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary(context),
                ),
                InterText(text: 'pts', fontSize: 9.sp, color: AppColors.greyText),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InterText(
                  text: title,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (valueLabel.isNotEmpty)
                  InterText(
                    text: valueLabel,
                    fontSize: 9.sp,
                    color: AppColors.greyText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          SizedBox(width: 6.w),
          SizedBox(
            height: 30.h,
            child: ElevatedButton(
              onPressed: (soldOut || !affordable || busy) ? null : () => _redeem(r),
              style: ElevatedButton.styleFrom(
                backgroundColor: _gold,
                disabledBackgroundColor: AppColors.greyText.withValues(alpha: 0.3),
                padding: EdgeInsets.symmetric(horizontal: 10.w),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r)),
              ),
              child: busy
                  ? SizedBox(
                      width: 14.w,
                      height: 14.w,
                      child: const CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : InterText(
                      text: soldOut
                          ? 'pawpoints_sold_out'.tr
                          : affordable
                              ? 'pawpoints_redeem'.tr
                              : 'pawpoints_locked'.tr,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _levelCard(BuildContext context, Map<String, dynamic> l) {
    final color = _hex((l['color'] as String?));
    final reached = _lifetime >= ((l['min'] as num?)?.toInt() ?? 0);
    final perks = (l['perks'] as List? ?? []).map((e) => e.toString()).toList();
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(14.r),
        border: reached ? Border.all(color: color.withValues(alpha: 0.5), width: 1.2) : null,
        boxShadow: AppColors.cardShadow(context),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42.w,
            height: 42.w,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Center(
              child: Text((l['emoji'] ?? '🐾').toString(),
                  style: TextStyle(fontSize: 20.sp)),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: PoppinsText(
                        text: '${l['index']}. ${l['label']}',
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                    if (reached)
                      Icon(Icons.check_circle, color: color, size: 16.sp),
                  ],
                ),
                InterText(
                  text: '${l['min']} pts',
                  fontSize: 10.sp,
                  color: AppColors.greyText,
                ),
                SizedBox(height: 4.h),
                ...perks.map((p) => Padding(
                      padding: EdgeInsets.only(top: 2.h),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InterText(text: '✓ ', fontSize: 11.sp, color: color),
                          Expanded(
                            child: InterText(
                              text: _perkLabel(p),
                              fontSize: 11.sp,
                              color: AppColors.textPrimary(context),
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pawLegendCard(BuildContext context) {
    final pawLegendMin =
        _levels.isNotEmpty ? ((_levels.last['min'] as num?)?.toInt() ?? 1000000) : 1000000;
    final remaining = (pawLegendMin - _lifetime).clamp(0, pawLegendMin);
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFCE7F3), Color(0xFFFEF3C7)],
        ),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: const Color(0xFFF472B6), width: 1.4),
      ),
      child: Row(
        children: [
          Text('👑', style: TextStyle(fontSize: 30.sp)),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PoppinsText(
                  text: 'pawpoints_legend_title'
                      .trParams({'pts': '$pawLegendMin'}),
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFFDB2777),
                ),
                SizedBox(height: 2.h),
                InterText(
                  text: 'pawpoints_legend_sub'.tr,
                  fontSize: 11.sp,
                  color: AppColors.textPrimary(context),
                  maxLines: 3,
                ),
                SizedBox(height: 4.h),
                InterText(
                  text: 'pawpoints_legend_remaining'
                      .trParams({'pts': '$remaining'}),
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                  color: _gold,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _earnRow(BuildContext context, Map<String, dynamic> r) {
    final icon = (r['icon'] ?? '➕').toString();
    // v527 — retour Jose (R3-10) : le backend envoie le label en FRANÇAIS.
    // On traduit côté app via la `key` de la règle (pawpoints_earn_<key>),
    // avec fallback sur le label serveur si la clé i18n n'existe pas.
    final ruleKey = (r['key'] ?? '').toString();
    final i18nKey = 'pawpoints_earn_$ruleKey';
    final translated = i18nKey.tr;
    final label = (ruleKey.isNotEmpty && translated != i18nKey)
        ? translated
        : (r['label'] ?? '').toString();
    final pts = (r['points'] as num?)?.toInt() ?? 0;
    return Padding(
      padding: EdgeInsets.only(bottom: 6.h),
      child: Row(
        children: [
          Text(icon, style: TextStyle(fontSize: 16.sp)),
          SizedBox(width: 10.w),
          Expanded(
            child: InterText(
              text: label,
              fontSize: 13.sp,
              color: AppColors.textPrimary(context),
            ),
          ),
          PoppinsText(
            text: '+$pts',
            fontSize: 14.sp,
            fontWeight: FontWeight.w800,
            color: _gold,
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

// 611 (PAM, 04/10/2026) — RANGS façon Waze (idée de Cam, décision BOB) :
// Chiot → Jeune chien → Chien adulte → Chef de meute → Légende.
//
// Le serveur calcule le rang sur les PawPoints GAGNÉS depuis toujours (jamais
// sur le solde) et l'envoie partout sous la même forme :
//   rank: {key, level, pointsEarned, nextAt, nextKey}
// (profil, fiche publique, couches de la PawMap, /pawpoints/me, classement).
// Ici : le modèle, la pastille (profil, fiche sur la carte), la carte de
// progression (écran PawPoints) et le petit message au passage de rang (une
// fois par personne, noté côté serveur : POST /pawpoints/rank-seen).
// Le rang est honorifique : aucun avantage payant, aucune valeur en argent.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:hopetsit/widgets/paw_icons.dart';

/// Seuils (miroir de backend/src/services/ranks611.js — le serveur fait foi
/// pour le rang, l'app ne s'en sert que pour la barre de progression).
const List<int> kPawRankMins611 = <int>[0, 150, 800, 3000, 10000];
const List<String> kPawRankKeys611 = <String>[
  'puppy', 'young_dog', 'adult_dog', 'pack_leader', 'legend',
];

class PawRank611 {
  const PawRank611({
    required this.key,
    required this.level,
    required this.pointsEarned,
    this.nextAt,
    this.nextKey,
  });

  final String key;
  final int level; // 1..5
  final int pointsEarned;
  final int? nextAt;
  final String? nextKey;

  /// null si absent ou illisible (ancien serveur, projection partielle) :
  /// l'app n'affiche alors aucune pastille plutôt qu'un faux « Chiot ».
  static PawRank611? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final key = (raw['key'] ?? '').toString();
    final level = (raw['level'] as num?)?.toInt() ?? 0;
    if (!kPawRankKeys611.contains(key) || level < 1 || level > 5) return null;
    return PawRank611(
      key: key,
      level: level,
      pointsEarned: (raw['pointsEarned'] as num?)?.toInt() ?? 0,
      nextAt: (raw['nextAt'] as num?)?.toInt(),
      nextKey: raw['nextKey']?.toString(),
    );
  }

  bool get isTop => nextAt == null;
  int get pointsToNext =>
      nextAt == null ? 0 : (nextAt! - pointsEarned).clamp(0, 1 << 30);

  /// Progression 0..1 entre le seuil du rang et le suivant.
  double get progress {
    if (nextAt == null) return 1;
    final int from = kPawRankMins611[(level - 1).clamp(0, 4)];
    final int span = nextAt! - from;
    if (span <= 0) return 1;
    return ((pointsEarned - from) / span).clamp(0.0, 1.0);
  }

  String get label => 'rank611_$key'.tr;
  String get nextLabel => nextKey == null ? '' : 'rank611_$nextKey'.tr;
}

/// Teintes PLEINES et chaudes (zéro gris), lisibles en clair et en sombre.
class PawRankStyle611 {
  const PawRankStyle611(this.base, this.lightBg, this.lightInk, this.darkBg, this.darkInk);
  final Color base;
  final Color lightBg;
  final Color lightInk;
  final Color darkBg;
  final Color darkInk;

  static const List<PawRankStyle611> _all = <PawRankStyle611>[
    // Chiot — miel
    PawRankStyle611(Color(0xFFE0A045), Color(0xFFFCEBCB), Color(0xFF7A4A06), Color(0xFF4A2F0A), Color(0xFFFFD58C)),
    // Jeune chien — orange
    PawRankStyle611(Color(0xFFE07A2E), Color(0xFFFDE2CC), Color(0xFF8A3A06), Color(0xFF52260A), Color(0xFFFFBE8A)),
    // Chien adulte — brique
    PawRankStyle611(Color(0xFFC9442A), Color(0xFFFADAD2), Color(0xFF8A2410), Color(0xFF55190E), Color(0xFFFFAE9C)),
    // Chef de meute — violet royal
    PawRankStyle611(Color(0xFF7A3FB8), Color(0xFFEBDDFB), Color(0xFF4B1D85), Color(0xFF34175A), Color(0xFFD9BCFF)),
    // Légende — or
    PawRankStyle611(Color(0xFFC9961A), Color(0xFFFBEDC4), Color(0xFF6E4E00), Color(0xFF4A3604), Color(0xFFFFDC73)),
  ];

  static PawRankStyle611 of(int level) => _all[(level - 1).clamp(0, 4)];
}

/// Pastille de rang : icône maison + nom + 5 crans. [onDark] = posée sur un
/// dégradé de couleur (en-tête du profil) : verre blanc, texte blanc.
class PawRankPill611 extends StatelessWidget {
  const PawRankPill611({
    super.key,
    required this.rank,
    this.onDark = false,
    this.compact = false,
  });

  final PawRank611 rank;
  final bool onDark;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final st = PawRankStyle611.of(rank.level);
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color bg = onDark ? const Color(0x33FFFFFF) : (dark ? st.darkBg : st.lightBg);
    final Color ink = onDark ? Colors.white : (dark ? st.darkInk : st.lightInk);
    final Color pipOn = onDark ? Colors.white : (dark ? st.darkInk : st.base);
    final Color pipOff = onDark ? const Color(0x59FFFFFF) : (dark ? st.base.withValues(alpha: 0.45) : st.base.withValues(alpha: 0.30));
    final double fs = compact ? 10.5 : 11.5;
    return Semantics(
      label: 'rank611_semantic'.trParams({'rank': rank.label}),
      child: Container(
        key: const ValueKey<String>('paw_rank_pill'),
        padding: EdgeInsets.fromLTRB(5, 3, compact ? 7 : 9, 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: onDark ? const Color(0x66FFFFFF) : st.base.withValues(alpha: dark ? 0.75 : 0.55),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PawIconWidget(
              rank.level == 5 ? PawIcon.crown : PawIcon.paw,
              size: compact ? 13 : 14,
              color: pipOn,
              fill: pipOn,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                rank.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: fs,
                  fontWeight: FontWeight.w700,
                  color: ink,
                  height: 1.1,
                ),
              ),
            ),
            if (!compact) ...[
              const SizedBox(width: 5),
              for (var i = 1; i <= 5; i++)
                Container(
                  width: 4,
                  height: 4,
                  margin: const EdgeInsets.only(left: 1.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i <= rank.level ? pipOn : pipOff,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Écran PawPoints : mon rang + barre « encore N points pour Chien adulte ».
class PawRankProgress611 extends StatelessWidget {
  const PawRankProgress611({super.key, required this.rank});

  final PawRank611 rank;

  @override
  Widget build(BuildContext context) {
    final st = PawRankStyle611.of(rank.level);
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color card = dark ? st.darkBg : st.lightBg;
    final Color ink = dark ? st.darkInk : st.lightInk;
    final String line = rank.isTop
        ? 'rank611_top'.tr
        : 'rank611_to_next'.trParams({
            'n': '${rank.pointsToNext}',
            'rank': rank.nextLabel,
          });
    return Container(
      key: const ValueKey<String>('paw_rank_progress'),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: st.base.withValues(alpha: dark ? 0.8 : 0.5), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'rank611_my_rank'.tr.toUpperCase(),
                  style: GoogleFonts.inter(
                      fontSize: 10.sp, fontWeight: FontWeight.w800, color: ink, letterSpacing: 0.4),
                ),
              ),
              PawRankPill611(rank: rank),
            ],
          ),
          SizedBox(height: 10.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: SizedBox(
              height: 8,
              child: Stack(
                children: [
                  Positioned.fill(child: ColoredBox(color: st.base.withValues(alpha: dark ? 0.35 : 0.22))),
                  FractionallySizedBox(
                    key: const ValueKey<String>('paw_rank_bar'),
                    widthFactor: rank.progress,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [st.base, Color.lerp(st.base, const Color(0xFFFFC23D), 0.35)!]),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            line,
            key: const ValueKey<String>('paw_rank_line'),
            style: GoogleFonts.poppins(fontSize: 13.sp, fontWeight: FontWeight.w700, color: ink),
          ),
          SizedBox(height: 4.h),
          Text(
            'rank611_how'.tr,
            style: GoogleFonts.inter(fontSize: 11.5.sp, color: ink.withValues(alpha: 0.85), height: 1.35),
          ),
        ],
      ),
    );
  }
}

/// Mon rang (profil, PawPoints, carte) + le message de passage, une fois.
class PawRankService611 {
  PawRankService611._();
  static final PawRankService611 instance = PawRankService611._();

  final Rxn<PawRank611> mine = Rxn<PawRank611>();
  int seenLevel = 1;
  bool _celebrating = false;

  /// Lit une réponse de GET /pawpoints/me (déjà chargée par l'appelant).
  void ingestMe(dynamic me) {
    if (me is! Map) return;
    final r = PawRank611.fromJson(me['rank']);
    if (r != null) mine.value = r;
    final s = (me['rankSeenLevel'] as num?)?.toInt();
    if (s != null && s > seenLevel) seenLevel = s; // jamais en arrière
  }

  /// GET /pawpoints/me puis message éventuel. Ne lève jamais.
  Future<void> refresh({bool celebrate = true}) async {
    try {
      if (!Get.isRegistered<ApiClient>()) return;
      final me = await Get.find<ApiClient>().get('/pawpoints/me', requiresAuth: true);
      ingestMe(me);
      if (celebrate) await maybeCelebrate();
    } catch (_) {/* best-effort : pas de rang affiché */}
  }

  /// « Tu passes Jeune chien ! » une seule fois par rang et par personne.
  Future<bool> maybeCelebrate() async {
    final r = mine.value;
    if (r == null || r.level <= seenLevel || _celebrating) return false;
    _celebrating = true;
    try {
      seenLevel = r.level; // jamais deux fois, même si le réseau échoue
      CustomSnackbar.showSuccess(
        title: 'rank611_up_title'.trParams({'rank': r.label}),
        message: r.isTop
            ? 'rank611_top'.tr
            : 'rank611_to_next'.trParams({'n': '${r.pointsToNext}', 'rank': r.nextLabel}),
      );
      if (Get.isRegistered<ApiClient>()) {
        await Get.find<ApiClient>().post('/pawpoints/rank-seen',
            body: <String, dynamic>{'level': r.level}, requiresAuth: true);
      }
      return true;
    } catch (_) {
      return true;
    } finally {
      _celebrating = false;
    }
  }

  @visibleForTesting
  void resetForTests() {
    mine.value = null;
    seenLevel = 1;
    _celebrating = false;
  }
}

/// En-tête du profil : ma pastille (chargée au premier affichage).
class PawMyRankPill611 extends StatefulWidget {
  const PawMyRankPill611({super.key, this.onDark = true});
  final bool onDark;

  @override
  State<PawMyRankPill611> createState() => _PawMyRankPill611State();
}

class _PawMyRankPill611State extends State<PawMyRankPill611> {
  @override
  void initState() {
    super.initState();
    if (PawRankService611.instance.mine.value == null) {
      PawRankService611.instance.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final r = PawRankService611.instance.mine.value;
      if (r == null) return const SizedBox.shrink();
      return PawRankPill611(rank: r, onDark: widget.onDark);
    });
  }
}

/// Mon rang + barre (boutique, toute page qui n'a pas déjà /pawpoints/me).
class PawMyRankProgress611 extends StatefulWidget {
  const PawMyRankProgress611({super.key});

  @override
  State<PawMyRankProgress611> createState() => _PawMyRankProgress611State();
}

class _PawMyRankProgress611State extends State<PawMyRankProgress611> {
  @override
  void initState() {
    super.initState();
    if (PawRankService611.instance.mine.value == null) {
      PawRankService611.instance.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final r = PawRankService611.instance.mine.value;
      if (r == null) return const SizedBox.shrink();
      return PawRankProgress611(rank: r);
    });
  }
}

/// 611 (I) — Cam : « Je suis OÙ ? ». MA ligne épinglée en haut de chaque
/// onglet du classement, d'après `me` du serveur :
/// « Toi · 9e · 136 pts » + rang, ou la raison claire d'une absence.
class PawLeaderboardMeRow611 extends StatelessWidget {
  const PawLeaderboardMeRow611({super.key, required this.me});
  final Map<String, dynamic> me;

  @override
  Widget build(BuildContext context) {
    final rank = PawRank611.fromJson(me['rank']);
    final pts = (me['pointsEarned'] as num?)?.toInt() ?? 0;
    final pos = (me['position'] as num?)?.toInt();
    final reason = (me['excludedReason'] ?? '').toString();
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final st = PawRankStyle611.of(rank?.level ?? 1);
    final Color ink = dark ? st.darkInk : st.lightInk;
    final String line = reason.isNotEmpty
        ? 'lb611_$reason'.tr
        : (pos == null || pts <= 0)
            ? 'lb611_zero'.tr
            : '${'lb611_ordinal'.trParams({'n': '$pos'})} · $pts pts';
    return Container(
      key: const ValueKey<String>('lb611_me_row'),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
      decoration: BoxDecoration(
        color: dark ? st.darkBg : st.lightBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: st.base, width: 1.4),
      ),
      child: Row(
        children: [
          Text('lb611_you'.tr,
              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w800, color: ink)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              line,
              key: const ValueKey<String>('lb611_me_line'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: ink),
            ),
          ),
          if (rank != null) ...[
            const SizedBox(width: 6),
            PawRankPill611(rank: rank, compact: true),
          ],
        ],
      ),
    );
  }
}

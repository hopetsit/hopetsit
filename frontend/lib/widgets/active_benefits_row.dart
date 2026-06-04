// v23.1 part 109 — Daniel : "le boost marche pas".
// Petit row de badges ("Boost actif", "PawSpot actif", "Premium actif")
// affiché en haut du profil pour que le user voie immédiatement après
// achat que son achat a bien pris effet.
//
// v23.1 part 114 — appel direct à GET /users/me/benefits (route dédiée
// qui marche pour les 3 rôles owner/sitter/walker, contrairement à
// /users/me/profile qui était réservé aux owners). On rafraichit à
// chaque mount + sur demande externe via refreshAfterPurchase().

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/widgets/app_text.dart';

class ActiveBenefitsRow extends StatefulWidget {
  const ActiveBenefitsRow({super.key, this.compact = false});

  /// Quand `compact: true`, badges plus petits (utile dans le header).
  final bool compact;

  @override
  State<ActiveBenefitsRow> createState() => _ActiveBenefitsRowState();

  // v23.1 part 114 — clé statique pour forcer un refresh global (utilisé
  // par refreshAfterPurchase). Tous les widgets ActiveBenefitsRow
  // observent _refreshTick et re-fetchent.
  static final RxInt _refreshTick = 0.obs;
  static void notifyChanged() {
    _refreshTick.value += 1;
  }

  // v23.1 part 115 — exposé pour que KycStatusBanner (et autres widgets
  // dépendants de /users/me/benefits) puissent aussi se rafraichir
  // après un changement (achat, KYC submit, etc.).
  // ignore: prefer_const_declarations
  static RxInt get refreshTickAccessor => _refreshTick;

  // v23.1.149 — Daniel : "le boost sur owner ne saffiche pas". On expose
  // l'état boost actif comme un Rx<bool> partagé, observable par les
  // autres widgets (notamment le hero du profil owner qui affiche un
  // cadre doré quand le boost est actif). Mis à jour par _ActiveBenefitsRowState
  // à chaque /users/me/benefits.
  static final RxBool _boostActive = false.obs;
  static RxBool get boostActiveAccessor => _boostActive;

  /// v23.1.175 — Daniel : "le cadre boost napparait toujour pas sur le
  /// profile owner". Cause #1 (v175 initial) : _boostActive ne devenait true
  /// qu'après que le _ActiveBenefitsRowState s'exécute (montée du widget
  /// enfant). Cette méthode statique permet à n'importe quel écran (ex.
  /// ProfileScreen.build) de forcer un refetch immédiat de /benefits
  /// → met à jour _boostActive sans attendre le mount du widget.
  ///
  /// v23.1.175 fix #2 — Daniel : "reverifie egalement le cadre boost sur
  /// owner qui naparait pas car jai demande r5fois". Cause RACINE :
  /// l'API /users/me/benefits renvoie 2 champs distincts : `boostExpiry`
  /// (Boost annonce) ET `mapBoostExpiry` (PawSpot Gold etc.). On lisait
  /// SEULEMENT boostExpiry → si Daniel avait juste un PawSpot Gold actif,
  /// le cadre doré ne s'affichait jamais. Maintenant on prend l'OR :
  /// _boostActive = (boostExpiry > now) OU (mapBoostExpiry > now).
  static Future<void> refreshBoostState() async {
    try {
      if (!Get.isRegistered<ApiClient>()) return;
      final api = Get.find<ApiClient>();
      final r = await api.get('/users/me/benefits', requiresAuth: true);
      if (r is Map) {
        final benefits = Map<String, dynamic>.from(r);
        DateTime? parseExpiry(dynamic raw) {
          if (raw is String && raw.isNotEmpty) return DateTime.tryParse(raw);
          if (raw is num) {
            return DateTime.fromMillisecondsSinceEpoch(raw.toInt());
          }
          return null;
        }

        final boostExpiry = parseExpiry(benefits['boostExpiry']);
        final mapBoostExpiry = parseExpiry(benefits['mapBoostExpiry']);
        final now = DateTime.now();
        final boostActive =
            boostExpiry != null && boostExpiry.isAfter(now);
        final mapBoostActive =
            mapBoostExpiry != null && mapBoostExpiry.isAfter(now);
        // v23.1.182 — Daniel : "le cadre urgent boost naparait tjr pa"
        // (10e fois). VRAIE cause racine : Daniel a une sub Famille
        // (isPremium=true) mais ni Boost annonce ni PawSpot/MapBoost.
        // L'accessor _boostActive ignorait isPremium → frontend fallback
        // stayed false → ruban URGENT never appeared on his own posts.
        // Fix : tout abo Premium actif déclenche aussi le cadre URGENT
        // (= "compte premium, post mis en avant"). Aligné sur la logique
        // backend postController.js isSubscriptionActive.
        final isPremium = benefits['isPremium'] == true;
        _boostActive.value = boostActive || mapBoostActive || isPremium;
      }
    } catch (_) {/* defensive */}
  }
}

class _ActiveBenefitsRowState extends State<ActiveBenefitsRow> {
  Map<String, dynamic> _benefits = const {};
  bool _loaded = false;
  Worker? _tickWorker;

  @override
  void initState() {
    super.initState();
    _load();
    _tickWorker = ever<int>(ActiveBenefitsRow._refreshTick, (_) => _load());
  }

  @override
  void dispose() {
    _tickWorker?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      if (!Get.isRegistered<ApiClient>()) return;
      final api = Get.find<ApiClient>();
      final r = await api.get('/users/me/benefits', requiresAuth: true);
      if (!mounted) return;
      if (r is Map) {
        setState(() {
          _benefits = Map<String, dynamic>.from(r);
          _loaded = true;
        });
        // v23.1.149 — synchronise le Rx<bool> boostActive partagé.
        // v23.1.175 fix #2 — Daniel "cadre boost napparait toujours pas
        // sur profile owner". On regarde maintenant boostExpiry OU
        // mapBoostExpiry (PawSpot/MapBoost) pour activer le cadre doré.
        final expiry = _toDate(_benefits['boostExpiry']);
        final mapExpiry = _toDate(_benefits['mapBoostExpiry']);
        final now = DateTime.now();
        final boostActive = expiry != null && expiry.isAfter(now);
        final mapActive = mapExpiry != null && mapExpiry.isAfter(now);
        // v23.1.182 — inclut isPremium dans l'accessor (10e fix demandé).
        final isPremium = _benefits['isPremium'] == true;
        ActiveBenefitsRow._boostActive.value = boostActive || mapActive || isPremium;
      }
    } catch (_) {
      // best-effort, on cache simplement la row.
      if (mounted) setState(() => _loaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();
    final p = _benefits;
    final now = DateTime.now();
    final boostExpiry = _toDate(p['boostExpiry']);
    final mapBoostExpiry = _toDate(p['mapBoostExpiry']);
    final isPremium = p['isPremium'] == true;
    final boostActive = boostExpiry != null && boostExpiry.isAfter(now);
    final pawSpotActive = mapBoostExpiry != null && mapBoostExpiry.isAfter(now);

    // v23.1.276 — Daniel : "change premium à PawFollow avec les jours restant
    // et rajoute badge Family avec les jours, pour une vraie distinction".
    //   - Badge PawFollow (doré ⭐) : abo INDIVIDUEL actif (mensuel/annuel).
    //   - Badge Family (violet 👨‍👩‍👧) : plan FAMILLE actif (titulaire ou membre).
    // Un titulaire famille n'a QUE le badge Family (pas de PawFollow individuel).
    final familyActive = p['familyActive'] == true;
    final pawFollowExpiry = _toDate(p['pawFollowExpiry']);
    final familyExpiry = _toDate(p['familyExpiry']);
    // v23.1.279 — Daniel : "le badge jaune PawFollow n'y est tjr pas". On lit
    // le flag backend pawFollowActive (premium individuel/staff) — indépendant
    // de la famille → les 2 badges coexistent. FALLBACK robuste : si le backend
    // n'expose pas encore pawFollowActive (Render pas redéployé), on retombe
    // sur isPremium.
    // v23.1.280 — Daniel : "réorganise les badges que ça fasse propre" / "on
    // dirait que PawFollow et PawFamily se calculent ensemble". En mode
    // FALLBACK (backend sans pawFollowActive), un titulaire Famille a
    // isPremium=true → il affichait DEUX badges (PawFollow + Famille). On
    // soustrait familyActive du fallback pour ne montrer qu'UN badge propre.
    final hasIndividualPawFollow = p.containsKey('pawFollowActive')
        ? p['pawFollowActive'] == true
        : (isPremium && !familyActive);

    // v23.1.280 — suffixe jours localisé (« · 5 j » / « · 5 d » / « · 5 T. »…)
    // au lieu du « j » hardcodé FR, pour que les 3 profils soient propres dans
    // les 6 langues.
    String withDays(String base, int days) => days > 0
        ? '$base · ${'pawmap_time_days_short'.trParams({'n': '$days'})}'
        : base;

    final children = <Widget>[];
    if (hasIndividualPawFollow) {
      final days = pawFollowExpiry != null
          ? pawFollowExpiry.difference(now).inDays
          : 0;
      children.add(_badge(
          context, '⭐', withDays('PawFollow', days), const Color(0xFFF59E0B)));
    }
    if (familyActive) {
      final days =
          familyExpiry != null ? familyExpiry.difference(now).inDays : 0;
      children.add(_badge(context, '👨‍👩‍👧',
          withDays('friends_tab_family'.tr, days), const Color(0xFF8B5CF6)));
    }
    if (boostActive) {
      final days = boostExpiry.difference(now).inDays;
      children.add(_badge(
          context, '🚀', withDays('Boost', days), const Color(0xFFE8472A)));
    }
    if (pawSpotActive) {
      final days = mapBoostExpiry.difference(now).inDays;
      children.add(_badge(
          context, '📍', withDays('PawSpot', days), const Color(0xFF10B981)));
    }
    if (children.isEmpty) return const SizedBox.shrink();
    // v23.1.282 — Daniel : "plus aucun badge n'apparaît". RÉGRESSION v281 : la
    // grille Column→Row(Expanded, stretch) cassait la mise en page dans le
    // header (largeur lâche) → tout le sous-arbre des badges disparaissait.
    // On revient à un Wrap (robuste, jamais de contrainte non bornée) mais on
    // garde le « 2 par ligne » en fixant chaque cellule à ~la demi-largeur via
    // LayoutBuilder. Les pilules gardent leur taille naturelle (Align à gauche)
    // → grille propre 2 colonnes, sans risque de crash de layout.
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxW =
              constraints.maxWidth.isFinite ? constraints.maxWidth : 320.w;
          final cellW = ((maxW - 6.w) / 2).clamp(80.0, maxW);
          return Wrap(
            spacing: 6.w,
            runSpacing: 6.h,
            children: children
                .map((b) => SizedBox(
                      width: cellW,
                      child: Align(alignment: Alignment.centerLeft, child: b),
                    ))
                .toList(),
          );
        },
      ),
    );
  }

  Widget _badge(BuildContext context, String emoji, String label, Color color) {
    // v23.1 part 123 — Daniel : "owner le boost marche tjr pas" / "le badge
    // ne s'affiche pas sur le profil owner". Le bug : le badge orange Boost
    // (#E8472A à 15% d'opacité) sur un hero orange owner = invisible. En
    // mode compact (= utilisé dans les headers colorés), on inverse le
    // contraste : fond plein + texte blanc + bordure blanche translucide.
    if (widget.compact) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 4.h),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: Colors.white, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.35),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: TextStyle(fontSize: 11.sp)),
            SizedBox(width: 4.w),
            InterText(
              text: label,
              fontSize: 10.sp,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ],
        ),
      );
    }
    // Mode non-compact (anciens écrans) : tons clairs, pour fonds clairs.
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: TextStyle(fontSize: 13.sp)),
          SizedBox(width: 4.w),
          InterText(
            text: label,
            fontSize: 12.sp,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ],
      ),
    );
  }

  DateTime? _toDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }
}

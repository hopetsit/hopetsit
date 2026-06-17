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
    // v23.1.370 — Daniel : "le badge jours PawSpot ne correspond pas à
    // l'abonnement". Le badge lisait l'ANCIEN mapBoostExpiry (halos
    // map-boost morts) → jamais à jour. Il lit désormais le VRAI abo
    // communautaire (pawspotActive/pawspotExpiry du backend), fallback
    // legacy mapBoost si le backend n'expose pas encore ces champs.
    final pawspotExpiry = _toDate(p['pawspotExpiry']) ?? mapBoostExpiry;
    final pawSpotActive = p.containsKey('pawspotActive')
        ? p['pawspotActive'] == true
        : (mapBoostExpiry != null && mapBoostExpiry.isAfter(now));

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
    // v23.1.387 — Paw Premium (bundle) : badge 👑 noir/or EN PREMIER (le
    // plus prestigieux), jours au plafond comme PawSpot.
    final premiumActive = p['premiumActive'] == true;
    final premiumExpiry = _toDate(p['premiumExpiry']);

    final children = <Widget>[];
    if (premiumActive) {
      final days = premiumExpiry != null
          ? (premiumExpiry.difference(now).inHours / 24).ceil()
          : 0;
      // v444 — Daniel : badge discret = jours restants dans une pastille
      // pleine NOIRE (Premium = le plus prestigieux).
      children.add(_badge(context, '👑', days, const Color(0xFF111111)));
    }
    if (hasIndividualPawFollow) {
      final days = pawFollowExpiry != null
          ? pawFollowExpiry.difference(now).inDays
          : 0;
      // Violet PawFollow.
      children.add(_badge(context, '📍', days, const Color(0xFF7C3AED)));
    }
    if (familyActive) {
      final days =
          familyExpiry != null ? familyExpiry.difference(now).inDays : 0;
      // Violet Famille (légèrement plus clair que PawFollow).
      children.add(_badge(context, '👨‍👩‍👧', days, const Color(0xFF8B5CF6)));
    }
    if (boostActive) {
      final days = boostExpiry.difference(now).inDays;
      // Rouge PawBoost.
      children.add(_badge(context, '🚀', days, const Color(0xFFE8472A)));
    }
    if (pawSpotActive) {
      // Jours au PLAFOND (29,9 j → 30) pour coller à l'abonnement acheté.
      final days = pawspotExpiry != null
          ? (pawspotExpiry.difference(now).inHours / 24).ceil()
          : 0;
      // Jaune/doré PawSpot.
      children.add(_badge(context, '🐾', days, const Color(0xFFE8A00A)));
    }
    if (children.isEmpty) return const SizedBox.shrink();
    // v444 — Daniel : « les petits badges du cadre orange/vert/bleu, mets-les
    // HORIZONTAUX ». Avant : grille 2 colonnes (LayoutBuilder demi-largeur).
    // Maintenant : une seule LIGNE horizontale, défilable si trop de badges
    // pour la largeur du header (jamais de débordement ni de wrap en colonnes).
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < children.length; i++) ...[
              if (i > 0) SizedBox(width: 6.w),
              children[i],
            ],
          ],
        ),
      ),
    );
  }

  /// v444 — Daniel : badge DISCRET & CLASSE = uniquement les JOURS RESTANTS
  /// dans une pastille PLEINE à la couleur de l'ABONNEMENT (noir Premium /
  /// violet PawFollow-Famille / jaune PawSpot / rouge PawBoost). Plus de nom
  /// d'abonnement ni de cadre couleur-rôle : l'emoji + la couleur identifient.
  Widget _badge(BuildContext context, String emoji, int days, Color color) {
    final daysLabel =
        days > 0 ? 'pawmap_time_days_short'.trParams({'n': '$days'}) : '';
    // Texte SOMBRE sur le jaune PawSpot (contraste), BLANC sinon.
    final onColor = color == const Color(0xFFE8A00A)
        ? const Color(0xFF1A1A1A)
        : Colors.white;
    // v446 — Daniel : badges PLUS PETITS (ils étaient coupés sur la droite).
    final double fs = widget.compact ? 9.sp : 10.sp;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: TextStyle(fontSize: fs)),
          if (daysLabel.isNotEmpty) ...[
            SizedBox(width: 3.w),
            InterText(
              text: daysLabel,
              fontSize: fs,
              fontWeight: FontWeight.w800,
              color: onColor,
            ),
          ],
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

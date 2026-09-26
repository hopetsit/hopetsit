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
import 'package:hopetsit/widgets/paw_icons.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/utils/app_colors.dart';

import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/data/network/secure_token_store.dart';
import 'package:hopetsit/widgets/app_text.dart';

class ActiveBenefitsRow extends StatefulWidget {
  const ActiveBenefitsRow({super.key, this.compact = false, this.hero = false});

  /// Quand `compact: true`, badges plus petits (utile dans le header).
  final bool compact;

  /// v565 — mode « hero » (en-tête de profil partagé `ProfileHero`) : pilules
  /// en verre blanc translucide avec l'icône produit ET son nom court
  /// (« 👑 Premium · 60 j »), badge discret « Aucun abonnement » si vide.
  final bool hero;

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

  /// v585 (bug 11) — PawBoost SEUL (le `boostExpiry` de /users/me/benefits,
  /// désormais le plus lointain des 3 profils) : c'est lui qui fait briller
  /// mon rond « Moi » en turquoise sur la PawMap. `_boostActive` mélange
  /// PawSpot et Premium (cadre du profil) et ne convient pas ici.
  static final RxBool _profileBoost = false.obs;
  static RxBool get profileBoostAccessor => _profileBoost;

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
  static Future<void> refreshBoostState() => _fetch();

  // v592 — Daniel (26/09) : « quand je me connecte, ça clignote, ça tremble
  // sur mon profil le temps que ça s'installe ». Cause mesurée : cette rangée
  // ne rendait RIEN tant que /users/me/benefits n'avait pas répondu, puis une
  // pilule (+28 px) ou une rangée de badges avec marge (+40 px) → tout
  // l'en-tête du profil grandissait d'un coup et la page sautait. Et chaque
  // montage (changement d'onglet, de rôle) refaisait l'aller-retour.
  // Désormais : UNE seule réponse partagée (mémoire, liée à la session), une
  // seule requête à la fois, et en mode hero une hauteur identique dans tous
  // les états (attente, aucun abonnement, badges).
  static final Rxn<Map<String, dynamic>> _shared = Rxn<Map<String, dynamic>>();
  static String? _sharedSession;
  static Future<void>? _inflight;

  static String? _sessionNow() {
    try {
      return SecureTokenStore.currentToken();
    } catch (_) {
      return null;
    }
  }

  /// Dernière réponse connue pour la session EN COURS (jamais celle d'un
  /// autre compte après une déconnexion).
  static Map<String, dynamic>? _cachedForSession() {
    final data = _shared.value;
    if (data == null) return null;
    return _sharedSession == _sessionNow() ? data : null;
  }

  /// Dernier échec de /users/me/benefits sans aucune donnée pour la session.
  static final RxBool _lastFailed = false.obs;

  /// v592 — réponse /users/me/benefits de la session en cours (partagée avec
  /// KycStatusBanner : une seule requête, un seul affichage).
  static Map<String, dynamic>? get sessionBenefits => _cachedForSession();

  /// v592 — vrai quand la réponse est connue (ou a échoué) : les pages Profil
  /// attendent ce moment pour afficher leur contenu d'un seul coup. À lire
  /// dans un Obx (lit deux Rx).
  static bool get settledForSession {
    final failed = _lastFailed.value;
    _shared.value;
    return _cachedForSession() != null || failed;
  }

  @visibleForTesting
  static void debugResetCache() {
    _shared.value = null;
    _sharedSession = null;
    _inflight = null;
    _lastFailed.value = false;
  }

  static Future<void> _fetch() {
    return _inflight ??= _doFetch();
  }

  static Future<void> _doFetch() async {
    try {
      if (!Get.isRegistered<ApiClient>()) return;
      final api = Get.find<ApiClient>();
      final r = await api.get('/users/me/benefits', requiresAuth: true);
      if (r is Map) {
        final benefits = Map<String, dynamic>.from(r);
        _sharedSession = _sessionNow();
        _shared.value = benefits;
        _lastFailed.value = false;
        _applyFlags(benefits);
      } else if (_cachedForSession() == null) {
        _lastFailed.value = true;
      }
    } catch (_) {
      if (_cachedForSession() == null) _lastFailed.value = true;
    } finally {
      _inflight = null;
    }
  }

  static void _applyFlags(Map<String, dynamic> benefits) {
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
    final boostActive = boostExpiry != null && boostExpiry.isAfter(now);
    final mapBoostActive =
        mapBoostExpiry != null && mapBoostExpiry.isAfter(now);
    // v23.1.182 — tout abo Premium actif déclenche aussi le cadre URGENT
    // (aligné sur le backend postController.js isSubscriptionActive).
    // v23.1.175 fix #2 — boostExpiry OU mapBoostExpiry (PawSpot/MapBoost).
    final isPremium = benefits['isPremium'] == true;
    _boostActive.value = boostActive || mapBoostActive || isPremium;
    _profileBoost.value = boostActive;
  }
}

class _ActiveBenefitsRowState extends State<ActiveBenefitsRow> {
  /// Réponse en échec sans aucune donnée connue : on montre l'état « vide »
  /// (comme avant) plutôt qu'une attente sans fin.
  bool _failed = false;
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
    await ActiveBenefitsRow._fetch();
    if (!mounted) return;
    if (ActiveBenefitsRow._cachedForSession() == null && !_failed) {
      setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // Lecture de l'Rx DANS la closure (règle d'or GetX).
      ActiveBenefitsRow._shared.value;
      final data = ActiveBenefitsRow._cachedForSession();
      if (data == null && !_failed) {
        // Attente : en mode hero, la place exacte d'une pilule est RÉSERVÉE
        // (invisible) → l'en-tête ne change jamais de hauteur.
        if (!widget.hero) return const SizedBox.shrink();
        return _heroSlot(
          key: const ValueKey<String>('benefits_wait'),
          child: Visibility(
            visible: false,
            maintainSize: true,
            maintainAnimation: true,
            maintainState: true,
            child: _heroPill(
              leading: Icon(Icons.workspace_premium_outlined, size: 13.sp),
              text: 'hero_no_subscription'.tr,
              muted: true,
            ),
          ),
        );
      }
      return _content(context, data ?? const <String, dynamic>{});
    });
  }

  /// Mode hero : la rangée occupe toujours la hauteur d'UNE pilule, et le
  /// passage de l'attente au contenu est un simple fondu (jamais un saut).
  Widget _heroSlot({required Key key, required Widget child}) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.centerLeft,
        children: <Widget>[...previous, if (current != null) current],
      ),
      child: KeyedSubtree(
        key: key,
        child: Align(alignment: Alignment.centerLeft, child: child),
      ),
    );
  }

  Widget _content(BuildContext context, Map<String, dynamic> p) {
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
      children.add(_badge(context, PawIcon.crown, days, const Color(0xFF150F0D),
          name: 'hero_benefit_premium'.tr));
    }
    if (hasIndividualPawFollow) {
      final days = pawFollowExpiry != null
          ? pawFollowExpiry.difference(now).inDays
          : 0;
      // Violet PawFollow.
      children.add(_badge(context, PawIcon.route, days, const Color(0xFF7C3AED),
          name: 'hero_benefit_follow'.tr));
    }
    if (familyActive) {
      final days =
          familyExpiry != null ? familyExpiry.difference(now).inDays : 0;
      // Violet Famille (légèrement plus clair que PawFollow).
      children.add(_badge(context, PawIcon.friends, days, const Color(0xFF8B5CF6),
          name: 'hero_benefit_family'.tr));
    }
    if (boostActive) {
      final days = boostExpiry.difference(now).inDays;
      // Rouge PawBoost.
      children.add(_badge(context, PawIcon.rocket, days, const Color(0xFFE8472A),
          name: 'hero_benefit_boost'.tr));
    }
    if (pawSpotActive) {
      // Jours au PLAFOND (29,9 j → 30) pour coller à l'abonnement acheté.
      final days = pawspotExpiry != null
          ? (pawspotExpiry.difference(now).inHours / 24).ceil()
          : 0;
      // Jaune/doré PawSpot.
      children.add(_badge(context, PawIcon.coin, days, const Color(0xFFE8A00A),
          name: 'hero_benefit_spot'.tr));
    }
    if (children.isEmpty) {
      // v565 — en mode hero, un badge discret « Aucun abonnement » (les
      // autres modes restent invisibles quand il n'y a rien à montrer).
      if (!widget.hero) return const SizedBox.shrink();
      return _heroSlot(
        key: const ValueKey<String>('benefits_none'),
        child: _heroPill(
          leading: Icon(Icons.workspace_premium_outlined,
              size: 13.sp, color: Colors.white.withValues(alpha: 0.85)),
          text: 'hero_no_subscription'.tr,
          muted: true,
        ),
      );
    }
    final row = SingleChildScrollView(
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
    );
    // v592 — en mode hero, PAS de marge verticale en plus : la rangée de
    // badges a exactement la hauteur de la pilule « Aucun abonnement » et de
    // la place réservée pendant l'attente.
    if (widget.hero) {
      return _heroSlot(key: const ValueKey<String>('benefits_badges'), child: row);
    }
    // v444 — Daniel : « les petits badges du cadre orange/vert/bleu, mets-les
    // HORIZONTAUX ». Avant : grille 2 colonnes (LayoutBuilder demi-largeur).
    // Maintenant : une seule LIGNE horizontale, défilable si trop de badges
    // pour la largeur du header (jamais de débordement ni de wrap en colonnes).
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: row,
    );
  }

  /// v444 — Daniel : badge DISCRET & CLASSE = uniquement les JOURS RESTANTS
  /// dans une pastille PLEINE à la couleur de l'ABONNEMENT (noir Premium /
  /// violet PawFollow-Famille / jaune PawSpot / rouge PawBoost). Plus de nom
  /// d'abonnement ni de cadre couleur-rôle : l'emoji + la couleur identifient.
  Widget _badge(BuildContext context, PawIcon emoji, int days, Color color,
      {String name = ''}) {
    // v565 — un abonnement « à vie » (expiration très lointaine) affichait
    // « 26766 j » : au-delà de 10 ans on montre ∞.
    final daysLabel = days > 3650
        ? '∞'
        : (days > 0 ? 'pawmap_time_days_short'.trParams({'n': '$days'}) : '');
    if (widget.hero) {
      // v565 — pilule de verre blanc translucide : icône + nom court + jours.
      final text = daysLabel.isEmpty ? name : '$name · $daysLabel';
      return _heroPill(
        leading: PawIconWidget(emoji, size: 13.sp, color: Colors.white, fill: Colors.white.withValues(alpha: 0.3)),
        text: text,
      );
    }
    // Texte SOMBRE sur le jaune PawSpot (contraste), BLANC sinon.
    final onColor = color == const Color(0xFFE8A00A)
        ? const Color(0xFF201614)
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
            color: AppColors.shadow(0.18),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PawIconWidget(emoji, size: fs + 3, color: onColor, fill: onColor.withValues(alpha: 0.3)),
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

  /// v565 — pilule « verre » du mode hero (blanc translucide, bord blanc,
  /// texte blanc) ; `muted` = version discrète pour « Aucun abonnement ».
  Widget _heroPill({
    required Widget leading,
    required String text,
    bool muted = false,
  }) {
    return Container(
      padding: EdgeInsets.fromLTRB(9.w, 5.h, 11.w, 5.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: muted ? 0.10 : 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: muted ? 0.18 : 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          leading,
          SizedBox(width: 5.w),
          InterText(
            text: text,
            fontSize: 11.sp,
            fontWeight: FontWeight.w800,
            color: Colors.white.withValues(alpha: muted ? 0.85 : 1),
            maxLines: 1,
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

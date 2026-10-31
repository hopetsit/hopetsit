// 631 (PAM-C, 31/10/2026) — PRÉFÉRENCES « L'app s'ouvre sur » + « Balade rapide ».
//
// Daniel (31/10) : dans Profil › Préférences, choisir sur quel écran l'app
// s'ouvre (Accueil par défaut / PawMap / Chat / Réservations / Dernière page
// visitée), et régler le bouton « Balade rapide » de la carte (affiché ou non,
// à droite ou à gauche pour les gauchers).
//
// Où c'est enregistré : SUR LE TÉLÉPHONE (GetStorage), pas sur le compte.
// Les deux routes de préférences du serveur filtrent strictement leurs clés
// (`userController.js` : seules les clés booléennes connues de `preferences` ;
// `mapPrefsController.js` : `normalizeMapPrefs` jette toute clé inconnue) —
// une synchro entre appareils demanderait 3 lignes côté serveur (632), jamais
// une nouvelle route. Tant que ce n'est pas fait, chaque téléphone a son
// réglage.
//
// Quand la page d'ouverture s'applique (RÈGLE) :
//   · au lancement à froid (premier menu monté dans le processus) ;
//   · au retour depuis l'arrière-plan après PLUS DE 30 MIN (pas à chaque
//     retour) ;
//   · JAMAIS au-dessus d'un lien profond ou d'une notification : si un écran
//     est déjà poussé par-dessus le menu, si la carte a été demandée par un
//     autre chemin, ou si un lien attend d'être rejoué, le lien gagne.
// La décision est une fonction PURE (`openOnDecide3110`) testée seule.
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

/// Écran d'ouverture choisi. Les valeurs enregistrées sont les `code`.
enum OpenOnChoice3110 {
  home('home', 0),
  pawmap('pawmap', 2),
  chat('chat', 1),
  bookings('bookings', 3),
  last('last', -1);

  const OpenOnChoice3110(this.code, this.tabIndex);

  /// Valeur enregistrée.
  final String code;

  /// Onglet du menu du bas (0 Accueil · 1 Chat · 2 PawMap · 3 Réservations) ;
  /// -1 = « dernière page visitée » (lue à part).
  final int tabIndex;

  static OpenOnChoice3110 fromCode(Object? v) {
    final s = (v ?? '').toString();
    for (final c in OpenOnChoice3110.values) {
      if (c.code == s) return c;
    }
    return OpenOnChoice3110.home;
  }
}

/// Côté du bouton « Balade rapide » sur la carte.
enum QuickWalkSide3110 {
  right('right'),
  left('left');

  const QuickWalkSide3110(this.code);
  final String code;

  static QuickWalkSide3110 fromCode(Object? v) =>
      (v ?? '').toString() == 'left' ? QuickWalkSide3110.left : QuickWalkSide3110.right;
}

/// Décide quel onglet ouvrir, ou `null` pour ne rien changer. Pure.
///
/// [choice] le réglage ; [lastTab] le dernier onglet visité (pour « dernière
/// page ») ; [deepLinkPending] un lien / une notification attend d'être
/// rejoué ; [routeOnTop] un écran est déjà poussé par-dessus le menu (lien
/// profond, notification, conversation…) ; [mapRequested] la carte a été
/// demandée par un autre chemin (ami, itinéraire, lien) ; [currentTab]
/// l'onglet affiché (rien à faire s'il est déjà le bon) ; [tabCount] pour ne
/// jamais viser un onglet qui n'existe pas.
int? openOnDecide3110({
  required OpenOnChoice3110 choice,
  required int? lastTab,
  required bool deepLinkPending,
  required bool routeOnTop,
  required bool mapRequested,
  int currentTab = 0,
  int tabCount = 5,
}) {
  if (deepLinkPending || routeOnTop || mapRequested) return null;
  final int target = choice == OpenOnChoice3110.last ? (lastTab ?? 0) : choice.tabIndex;
  if (target < 0 || target >= tabCount) return null;
  // L'onglet Profil (4) n'est pas une page d'ouverture : jamais proposé, et
  // « dernière page » s'arrête à Réservations.
  if (target == 4) return null;
  if (target == currentTab) return null;
  return target;
}

/// Le retour depuis l'arrière-plan compte-t-il comme une « ouverture » ?
/// Pure : vrai seulement après plus de [threshold] (30 min) hors de l'app.
bool openOnResumeCounts3110(DateTime? pausedAt, DateTime now,
    {Duration threshold = const Duration(minutes: 30)}) {
  if (pausedAt == null) return false;
  return now.difference(pausedAt) > threshold;
}

/// Lecture / écriture des 3 réglages (téléphone seulement) + état réactif
/// pour que la carte et le bouton suivent le changement tout de suite.
class OpenOnPrefs3110 {
  OpenOnPrefs3110._();

  static const String kOpenOn = 'open_on_3110';
  static const String kLastTab = 'open_on_last_tab_3110';
  static const String kQuickWalkVisible = 'quick_walk_visible_3110';
  static const String kQuickWalkSide = 'quick_walk_side_3110';
  static const String kPausedAt = 'open_on_paused_at_3110';

  /// Seuil « retour depuis l'arrière-plan » (Daniel : 30 min).
  static const Duration resumeThreshold = Duration(minutes: 30);

  static GetStorage get _box => GetStorage();

  /// État réactif (la carte, le bouton et l'onglet des préférences lisent ici).
  static final Rx<OpenOnChoice3110> openOn = OpenOnChoice3110.home.obs;
  static final RxBool quickWalkVisible = true.obs;
  static final Rx<QuickWalkSide3110> quickWalkSide = QuickWalkSide3110.right.obs;

  static bool _loaded = false;

  /// Relit le téléphone (sans effet si déjà fait, sauf [force]).
  static void load({bool force = false}) {
    if (_loaded && !force) return;
    _loaded = true;
    try {
      final b = _box;
      openOn.value = OpenOnChoice3110.fromCode(b.read(kOpenOn));
      final v = b.read(kQuickWalkVisible);
      quickWalkVisible.value = v is bool ? v : true;
      quickWalkSide.value = QuickWalkSide3110.fromCode(b.read(kQuickWalkSide));
    } catch (e) {
      debugPrint('[OpenOn3110] lecture impossible : $e');
    }
  }

  static Future<void> setOpenOn(OpenOnChoice3110 c) async {
    openOn.value = c;
    await _write(kOpenOn, c.code);
  }

  static Future<void> setQuickWalkVisible(bool v) async {
    quickWalkVisible.value = v;
    await _write(kQuickWalkVisible, v);
  }

  static Future<void> setQuickWalkSide(QuickWalkSide3110 s) async {
    quickWalkSide.value = s;
    await _write(kQuickWalkSide, s.code);
  }

  /// Dernier onglet visité (0-3 ; le Profil n'est pas mémorisé).
  static int? lastTab() {
    try {
      final v = _box.read(kLastTab);
      return v is int ? v : null;
    } catch (_) {
      return null;
    }
  }

  static void rememberTab(int index) {
    if (index < 0 || index > 3) return;
    // ignore: discarded_futures
    _write(kLastTab, index);
  }

  /// Heure du passage en arrière-plan (pour le seuil de 30 min).
  static void markPaused([DateTime? now]) =>
      // ignore: discarded_futures
      _write(kPausedAt, (now ?? DateTime.now()).millisecondsSinceEpoch);

  static DateTime? pausedAt() {
    try {
      final v = _box.read(kPausedAt);
      return v is int ? DateTime.fromMillisecondsSinceEpoch(v) : null;
    } catch (_) {
      return null;
    }
  }

  static void clearPaused() {
    try {
      _box.remove(kPausedAt);
    } catch (_) {/* rien */}
  }

  static Future<void> _write(String k, Object v) async {
    try {
      await _box.write(k, v);
    } catch (e) {
      debugPrint('[OpenOn3110] écriture impossible : $e');
    }
  }

  /// Tests seulement.
  @visibleForTesting
  static void resetForTest() {
    _loaded = false;
    openOn.value = OpenOnChoice3110.home;
    quickWalkVisible.value = true;
    quickWalkSide.value = QuickWalkSide3110.right;
  }
}

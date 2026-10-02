// 607 (02/10/2026, PAM) — MINI-PELUCHES de la PawMap (idée 2 de Daniel).
//
// · Visibles SEULEMENT pendant MA Balade (le serveur renvoie une liste vide
//   sinon : il est la seule vérité, voir CONTRAT_607_peluches.md).
// · Capture AUTOMATIQUE à moins de 30 m : l'app propose, le serveur juge
//   (distance, vitesse, 1 par jour, 1 par peluche) et crédite +20 PawPoints.
// · Confirmation discrète par la pastille PawSignal existante.
// · Collection = section de la page PawPoints ([PawPlushCollectionSection]).
// · Réglage « Mini-peluches » dans Calques, retenu sur le compte
//   (`pawMap.layers.plush`, absent = affichées).
//
// Rien ici ne touche à l'argent : récompense en PawPoints seulement.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:typed_data';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../data/network/api_client.dart';
import '../../../data/network/api_exception.dart';
import '../../../utils/app_colors.dart';

/// Clé du calque dans `pawMap.layers` (même nom côté serveur et site).
const String kPawPlushLayerKey = 'plush';

/// Les 5 peluches, dans l'ordre de la collection.
const List<String> kPawPlushTypes = <String>['teddy', 'bunny', 'kitty', 'puppy', 'fox'];

/// Rayon de capture (m) — le serveur refuse au-delà.
const double kPawPlushCatchM = 30;

/// Visuel PNG d'une peluche (64 px logiques, variantes 2.0x / 3.0x).
/// [golden] : peluche dorée (anneau or, étoiles) — 1 par ville et par semaine.
String pawPlushAsset(String type, {bool golden = false}) =>
    'assets/images/plush607_${kPawPlushTypes.contains(type) ? type : 'teddy'}${golden ? '_gold' : ''}.png';

/// Lecture tolérante du réglage : absent = affichées.
bool pawPlushFromLayers(Map<String, bool> layers) => layers[kPawPlushLayerKey] ?? true;

class PawPlush {
  const PawPlush({
    required this.id,
    required this.type,
    required this.lat,
    required this.lng,
    this.golden = false,
  });

  final String id;
  final String type;
  final bool golden;
  final double lat;
  final double lng;

  LatLng get position => LatLng(lat, lng);

  static PawPlush? fromJson(dynamic j) {
    if (j is! Map) return null;
    final id = (j['id'] ?? '').toString();
    final lat = (j['lat'] as num?)?.toDouble();
    final lng = (j['lng'] as num?)?.toDouble();
    if (id.isEmpty || lat == null || lng == null) return null;
    return PawPlush(
        id: id,
        type: (j['type'] ?? 'teddy').toString(),
        lat: lat,
        lng: lng,
        golden: j['golden'] == true);
  }
}

double pawPlushMeters(double aLat, double aLng, double bLat, double bLng) {
  const r = 6371000.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(bLat - aLat);
  final dLng = rad(bLng - aLng);
  final x = math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(aLat)) * math.cos(rad(bLat)) * math.pow(math.sin(dLng / 2), 2);
  return 2 * r * math.asin(math.min(1.0, math.sqrt(x)));
}

/// Peluche la plus proche à portée de capture, sinon null.
PawPlush? pawPlushInReach(LatLng me, List<PawPlush> list, {double radiusM = kPawPlushCatchM}) {
  PawPlush? best;
  double bestD = double.infinity;
  for (final p in list) {
    final d = pawPlushMeters(me.latitude, me.longitude, p.lat, p.lng);
    if (d <= radiusM && d < bestD) {
      best = p;
      bestD = d;
    }
  }
  return best;
}

/// Résultat d'une tentative de capture.
enum PawPlushCatch { caught, dailyDone, taken, refused, none }

/// Détail d'une capture réussie (pour la pastille de confirmation).
class PawPlushWin {
  const PawPlushWin({this.points = 20, this.golden = false, this.collector = false, this.streak = 0});
  final int points;
  final bool golden;
  final bool collector;
  final int streak;
}

typedef PawPlushGet = Future<dynamic> Function(String path, Map<String, String> query);
typedef PawPlushPost = Future<dynamic> Function(String path, Map<String, dynamic> body);

/// La couche « peluches » de la carte : liste, rafraîchissement, capture.
/// Les appels réseau sont injectables (tests).
class PawPlushLayer {
  PawPlushLayer({PawPlushGet? get, PawPlushPost? post})
      : _get = get ?? _apiGet,
        _post = post ?? _apiPost;

  final PawPlushGet _get;
  final PawPlushPost _post;

  /// Peluches visibles (vide hors Balade).
  final RxList<PawPlush> items = <PawPlush>[].obs;

  /// Réglage « Mini-peluches » (Calques).
  final RxBool shown = true.obs;

  /// Déjà une capture aujourd'hui : on n'essaie plus d'en attraper.
  bool caughtToday = false;

  /// 607 (BOB/Daniel 02/10) — peluches libres à 5 km, connues même HORS
  /// Balade (le serveur ne donne alors que le nombre, jamais les positions).
  /// Nourrit le rappel « N peluches près de toi ».
  final RxInt nearbyCount = 0.obs;

  /// 607 (bouton PawPoints de la barre de gauche) — peluches attrapées
  /// AUJOURD'HUI (pastille verte ; rien si 0). Lu dans /plush/collection.
  final RxInt caughtTodayCount = 0.obs;

  Future<void> refreshTodayCount({DateTime? now}) async {
    try {
      final res = await _get('/plush/collection', const <String, String>{});
      if (res is! Map) return;
      final today = pawPlushDayKey(now ?? DateTime.now());
      final items = (res['items'] as List?) ?? const [];
      caughtTodayCount.value =
          items.where((it) => it is Map && it['day'] == today).length;
    } catch (_) {
      // Réseau : on garde la dernière valeur.
    }
  }
  LatLng? _hintAt;
  DateTime? _hintTime;
  bool _hintFetching = false;

  /// Hors Balade : redemande le NOMBRE au plus toutes les 5 min, ou après
  /// 1 km de déplacement (ou si [force]).
  Future<void> refreshHint(LatLng me, {bool force = false, DateTime? now}) async {
    if (_hintFetching) return;
    final t = now ?? DateTime.now();
    if (!force &&
        _hintAt != null &&
        _hintTime != null &&
        t.difference(_hintTime!) < const Duration(minutes: 5) &&
        pawPlushMeters(_hintAt!.latitude, _hintAt!.longitude, me.latitude, me.longitude) < 1000) {
      return;
    }
    _hintFetching = true;
    try {
      final res = await _get('/plush/active', <String, String>{
        'lat': me.latitude.toStringAsFixed(6),
        'lng': me.longitude.toStringAsFixed(6),
      });
      if (res is Map) {
        nearbyCount.value = (res['nearbyCount'] as num?)?.toInt() ?? 0;
        _hintAt = me;
        _hintTime = t;
      }
    } catch (_) {
      // Réseau : on garde la dernière valeur (le rappel est facultatif).
    } finally {
      _hintFetching = false;
    }
  }

  /// Dernière réponse du serveur (diagnostic) : Balade vue côté serveur ?
  bool? lastWalkActive;
  String lastError = '';

  LatLng? _lastFetchAt;
  DateTime? _lastFetchTime;
  bool _fetching = false;
  bool _catching = false;
  final Map<String, DateTime> _tried = <String, DateTime>{};

  static Future<dynamic> _apiGet(String path, Map<String, String> q) =>
      Get.find<ApiClient>().get(path, queryParameters: q, requiresAuth: true);
  static Future<dynamic> _apiPost(String path, Map<String, dynamic> b) =>
      Get.find<ApiClient>().post(path, body: b, requiresAuth: true);

  /// Ma Balade s'arrête : plus rien à l'écran.
  void clear() {
    if (items.isNotEmpty) items.clear();
    _lastFetchAt = null;
    _lastFetchTime = null;
  }

  /// Recharge si l'on a bougé de 300 m ou après 60 s (ou si [force]).
  Future<void> refresh(LatLng me, {bool force = false, DateTime? now}) async {
    if (_fetching) return;
    final t = now ?? DateTime.now();
    final last = _lastFetchAt;
    if (!force &&
        last != null &&
        _lastFetchTime != null &&
        t.difference(_lastFetchTime!) < const Duration(seconds: 60) &&
        pawPlushMeters(last.latitude, last.longitude, me.latitude, me.longitude) < 300) {
      return;
    }
    _fetching = true;
    try {
      final res = await _get('/plush/active', <String, String>{
        'lat': me.latitude.toStringAsFixed(6),
        'lng': me.longitude.toStringAsFixed(6),
      });
      if (res is Map) {
        lastWalkActive = res['walkActive'] == true;
        caughtToday = res['caughtToday'] == true;
        if (res['nearbyCount'] is num) {
          nearbyCount.value = (res['nearbyCount'] as num).toInt();
        }
        final list = ((res['plushies'] as List?) ?? const [])
            .map(PawPlush.fromJson)
            .whereType<PawPlush>()
            .toList();
        items.assignAll(list);
        _lastFetchAt = me;
        _lastFetchTime = t;
      }
    } catch (e) {
      // Réseau : on garde la liste affichée (jamais de carte qui se vide).
      lastError = e.toString();
    } finally {
      _fetching = false;
    }
  }

  /// Nouvelle position GPS pendant la Balade : tente la capture d'une
  /// peluche à portée. Renvoie le résultat et les points crédités.
  /// Dernière capture réussie (points, dorée, collection complète…).
  PawPlushWin? lastWin;

  /// 607 — dernier refus du serveur (TOO_FAST, TOO_FAR, WALK_REQUIRED…).
  String lastRefusal = '';
  int? lastRefusalMeters;

  /// 607 — la peluche la plus proche de [me] et sa distance (m), ou null.
  (PawPlush, double)? nearest(LatLng me) {
    (PawPlush, double)? best;
    for (final p in items) {
      final d = pawPlushMeters(me.latitude, me.longitude, p.lat, p.lng);
      if (best == null || d < best.$2) best = (p, d);
    }
    return best;
  }

  Future<(PawPlushCatch, int)> onPosition(LatLng me, {DateTime? now}) async {
    if (_catching || caughtToday || !shown.value) return (PawPlushCatch.none, 0);
    final p = pawPlushInReach(me, items);
    if (p == null) return (PawPlushCatch.none, 0);
    final t = now ?? DateTime.now();
    final prev = _tried[p.id];
    if (prev != null && t.difference(prev) < const Duration(seconds: 20)) {
      return (PawPlushCatch.none, 0);
    }
    _tried[p.id] = t;
    _catching = true;
    try {
      final res = await _post('/plush/${p.id}/catch', <String, dynamic>{
        'lat': me.latitude,
        'lng': me.longitude,
      });
      items.removeWhere((x) => x.id == p.id);
      caughtToday = true;
      caughtTodayCount.value += 1; // pastille du bouton PawPoints
      final pts = res is Map ? ((res['points'] as num?)?.toInt() ?? 20) : 20;
      final bonuses = res is Map && res['bonuses'] is List ? res['bonuses'] as List : const [];
      lastWin = PawPlushWin(
        points: pts,
        golden: p.golden,
        collector: bonuses.any((b) => b is Map && b['kind'] == 'collector'),
        streak: res is Map ? ((res['streak'] as num?)?.toInt() ?? 0) : 0,
      );
      return (PawPlushCatch.caught, pts);
    } on ApiException catch (e) {
      final code = e.details is Map ? (e.details['code'] ?? '').toString() : '';
      if (code == 'DAILY_LIMIT') {
        caughtToday = true;
        return (PawPlushCatch.dailyDone, 0);
      }
      if (code == 'ALREADY_CAUGHT' || code == 'EXPIRED' || code == 'NOT_FOUND') {
        items.removeWhere((x) => x.id == p.id);
        return (PawPlushCatch.taken, 0);
      }
      lastRefusal = code; // 607 — l'écran l'explique (plus d'échec muet)
      lastRefusalMeters = e.details is Map ? (e.details['distanceM'] as num?)?.toInt() : null;
      return (PawPlushCatch.refused, 0); // trop loin / trop vite / pas en Balade
    } catch (_) {
      return (PawPlushCatch.refused, 0);
    } finally {
      _catching = false;
    }
  }

  // ── épingles ────────────────────────────────────────────────────────────
  static final Map<String, BitmapDescriptor> _icons = <String, BitmapDescriptor>{};
  static bool _loading = false;

  /// Charge les 10 visuels une fois (5 + 5 dorés, variante selon la densité).
  static Future<void> preloadIcons(BuildContext context) async {
    if (iconsReady || _loading) return;
    _loading = true;
    try {
      // 607 (mesuré au simulateur, 02/10) — avec BitmapDescriptor.asset, les
      // 3 peluches étaient remises à la carte (journal) mais JAMAIS
      // dessinées sur iOS. On passe par des octets PNG (comme toutes les
      // autres épingles de la carte, qui s'affichent) : la version 3× du
      // dessin, affichée à 44 dp (50 pour la dorée).
      for (final t in kPawPlushTypes) {
        _icons[t] = BitmapDescriptor.bytes(await _png(t, false), width: 44);
        _icons['${t}_gold'] =
            BitmapDescriptor.bytes(await _png(t, true), width: 50);
      }
    } catch (e) {
      // Visuel indisponible : la peluche n'est pas posée (jamais d'épingle Google).
      debugPrint('[plush607] visuels non chargés : $e');
    } finally {
      _loading = false;
      // 607 — la carte se redessine quand les visuels sont prêts (avant : un
      // booléen statique, lu par personne → peluches jamais posées tant que
      // rien d'autre ne reconstruisait la carte).
      iconsReadyRx.value = iconsReady;
    }
  }

  static Future<Uint8List> _png(String type, bool golden) async {
    final name = pawPlushAsset(type, golden: golden).split('/').last;
    final data = await rootBundle.load('assets/images/3.0x/$name');
    return data.buffer.asUint8List();
  }

  static final RxBool iconsReadyRx = false.obs;
  static bool get iconsReady => _icons.length == kPawPlushTypes.length * 2;

  /// Marqueurs à poser (aucun si le réglage est éteint ou les visuels absents).
  Set<Marker> markers({required String Function(String key) tr}) {
    if (!shown.value || items.isEmpty || !iconsReady) return const <Marker>{};
    return <Marker>{
      for (final p in items)
        Marker(
          markerId: MarkerId('plush_${p.id}'),
          position: p.position,
          icon: _icons[p.golden ? '${p.type}_gold' : p.type] ?? _icons['teddy']!,
          anchor: const Offset(0.5, 0.5),
          zIndexInt: 40,
          infoWindow: InfoWindow(title: tr('plush607_marker_title'), snippet: tr('plush607_marker_hint')),
        ),
    };
  }
}

/// Section « Ma collection de peluches » de la page PawPoints (3 rôles).
// ─── 607 (BOB/Daniel 02/10) — rappel « N peluches près de toi » ──────────

/// Clé GetStorage : jour local (AAAA-MM-JJ) où le rappel a été refermé.
const String kPawPlushHintClosedKey = 'plush607_hint_closed_day';

String pawPlushDayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Refermé aujourd'hui ? (ne revient pas avant le lendemain).
bool pawPlushHintClosedToday({GetStorage? box, DateTime? now}) {
  try {
    final v = (box ?? GetStorage()).read(kPawPlushHintClosedKey);
    return v is String && v == pawPlushDayKey(now ?? DateTime.now());
  } catch (_) {
    return false;
  }
}

void pawPlushHintClose({GetStorage? box, DateTime? now}) {
  try {
    (box ?? GetStorage()).write(kPawPlushHintClosedKey, pawPlushDayKey(now ?? DateTime.now()));
  } catch (_) {/* stockage indisponible : rappel refermé pour la session */}
}

/// Le rappel s'affiche-t-il ? Rien en Balade, rien si N = 0, rien si la
/// couche est éteinte, rien si refermé aujourd'hui.
bool pawPlushHintVisible({
  required bool loggedIn,
  required bool walking,
  required bool layerShown,
  required int count,
  required bool closedToday,
}) =>
    loggedIn && !walking && layerShown && count > 0 && !closedToday;

/// Petit rappel discret posé à côté du bouton Balade : peluche, une phrase,
/// une croix. Un appui = la feuille Balade ; la croix = plus rien jusqu'à
/// demain. Couleurs : blanc nacré (sombre : prune), liseré et ombre de la
/// couleur du rôle.
class PawPlushHint extends StatelessWidget {
  const PawPlushHint({
    super.key,
    required this.count,
    required this.accent,
    required this.onTap,
    required this.onClose,
    this.dark = false,
    this.maxWidth = 214,
  });

  final int count;
  final Color accent;
  final VoidCallback onTap;
  final VoidCallback onClose;
  final bool dark;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final text = count == 1
        ? 'plush607_hint_one'.tr
        : 'plush607_hint'.trParams(<String, String>{'count': '$count'});
    final bg = dark ? const Color(0xFF2E1F3D) : const Color(0xFFFFFCF8);
    final ink = dark ? const Color(0xFFF6F1EE) : const Color(0xFF1C1430);
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Material(
        key: const ValueKey<String>('pawmap_plush_hint'),
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: bg.withValues(alpha: 0.97),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accent.withValues(alpha: 0.55), width: 1.2),
            boxShadow: [
              BoxShadow(color: accent.withValues(alpha: 0.22), blurRadius: 14, offset: const Offset(0, 5)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: InkWell(
                  key: const ValueKey<String>('pawmap_plush_hint_open'),
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 7, 2, 7),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(pawPlushAsset('teddy'), width: 28, height: 28),
                        const SizedBox(width: 7),
                        Flexible(
                          child: Text(
                            text,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              height: 1.25,
                              fontWeight: FontWeight.w600,
                              color: ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Semantics(
                button: true,
                label: 'plush607_hint_close'.tr,
                child: InkWell(
                  key: const ValueKey<String>('pawmap_plush_hint_close'),
                  customBorder: const CircleBorder(),
                  onTap: onClose,
                  child: SizedBox(
                    width: 30,
                    height: 34,
                    child: Center(
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accent.withValues(alpha: dark ? 0.35 : 0.14),
                        ),
                        child: Icon(Icons.close_rounded, size: 12, color: dark ? Colors.white : accent),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 607 — « Peluche la plus proche · 350 m » (pendant la Balade).
class PawNearestPlushPill extends StatelessWidget {
  const PawNearestPlushPill({
    super.key,
    required this.type,
    required this.golden,
    required this.label,
    required this.onTap,
    this.semantics,
  });
  final String type;
  final bool golden;
  final String label;
  final String? semantics;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      button: true,
      label: semantics ?? label,
      child: Material(
      color: Colors.transparent,
      child: InkWell(
        key: const ValueKey<String>('pawmap_nearest_plush'),
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(4, 3, 10, 3),
          decoration: BoxDecoration(
            color: (dark ? const Color(0xFF2E1F3D) : const Color(0xFFFFFCF8)).withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFDB2777).withValues(alpha: 0.55), width: 1.2),
            boxShadow: [
              BoxShadow(color: const Color(0xFFDB2777).withValues(alpha: 0.22), blurRadius: 10, offset: const Offset(0, 3)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(pawPlushAsset(type, golden: golden), width: 26, height: 26),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: dark ? const Color(0xFFF6F1EE) : const Color(0xFF1C1430),
                ),
              ),
              const SizedBox(width: 2),
              const Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFFDB2777)),
            ],
          ),
        ),
      ),
    ),
    );
  }
}

/// 607 — pastille verte du bouton PawPoints : peluches attrapées aujourd'hui
/// (même dessin que le site : vert promeneur, liseré blanc).
class PawPlushTodayBadge extends StatelessWidget {
  const PawPlushTodayBadge({super.key, required this.count});
  final int count;

  @override
  Widget build(BuildContext context) => Container(
        key: const ValueKey<String>('pawpoints_today_badge'),
        constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF16A34A),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: Colors.white, width: 2),
        ),
        alignment: Alignment.center,
        child: Text(
          '$count',
          style: GoogleFonts.poppins(
            fontSize: 10.5,
            height: 1.1,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      );
}

class PawPlushCollectionSection extends StatefulWidget {
  const PawPlushCollectionSection({super.key, this.load});

  /// Lecture de /plush/collection (injectable pour les tests).
  final Future<dynamic> Function()? load;

  @override
  State<PawPlushCollectionSection> createState() => _PawPlushCollectionSectionState();
}

class _PawPlushCollectionSectionState extends State<PawPlushCollectionSection> {
  Map<String, int> _counts = const {};
  int _total = 0;
  int _golden = 0;
  int _streak = 0;
  bool _collector = false;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    unawaited(_read());
  }

  Future<void> _read() async {
    try {
      final res = await (widget.load ??
          () => Get.find<ApiClient>().get('/plush/collection', requiresAuth: true))();
      if (!mounted) return;
      if (res is Map) {
        final c = res['counts'];
        setState(() {
          _counts = c is Map
              ? {for (final e in c.entries) e.key.toString(): (e.value as num?)?.toInt() ?? 0}
              : const {};
          _total = (res['total'] as num?)?.toInt() ?? 0;
          _golden = (res['golden'] as num?)?.toInt() ?? 0;
          _streak = (res['streak'] as num?)?.toInt() ?? 0;
          _collector = res['badges'] is List && (res['badges'] as List).contains('collector');
          _ready = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _ready = true);
    }
  }

  static const Color _rose = Color(0xFFDB2777);

  @override
  Widget build(BuildContext context) {
    final ink = AppColors.textPrimary(context);
    final sub = AppColors.textSecondary(context);
    return Container(
      key: const ValueKey<String>('plush607_collection'),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: _rose.withValues(alpha: 0.55), width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text('plush607_collection_title'.tr,
                  style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800, color: ink)),
            ),
            if (_ready)
              Text('plush607_total'.trParams({'count': '$_total'}),
                  style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700, color: _rose)),
          ]),
          SizedBox(height: 3.h),
          Text(_ready && _total == 0 ? 'plush607_collection_empty'.tr : 'plush607_collection_sub'.tr,
              style: TextStyle(fontSize: 12.sp, color: sub)),
          if (_collector || _golden > 0 || _streak > 1) ...[
            SizedBox(height: 8.h),
            Wrap(spacing: 6.w, runSpacing: 6.h, children: [
              if (_collector)
                _chip('🏆 ${'plush607_collector_badge'.tr}', const Color(0xFFB7791F),
                    key: const ValueKey<String>('plush607_badge_collector')),
              if (_golden > 0)
                _chip('✨ ${'plush607_golden_count'.trParams({'count': '$_golden'})}', const Color(0xFFB7791F)),
              if (_streak > 1)
                _chip('🔥 ${'plush607_streak'.trParams({'days': '$_streak'})}', _rose),
            ]),
          ],
          SizedBox(height: 12.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final t in kPawPlushTypes)
                Expanded(
                  child: Column(children: [
                    Opacity(
                      opacity: (_counts[t] ?? 0) > 0 ? 1 : 0.45,
                      child: Image.asset(pawPlushAsset(t), width: 44.w, height: 44.w),
                    ),
                    SizedBox(height: 4.h),
                    Text('×${_counts[t] ?? 0}',
                        key: ValueKey<String>('plush607_count_$t'),
                        style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w800, color: ink)),
                    Text('plush607_type_$t'.tr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10.sp, color: sub)),
                  ]),
                ),
            ],
          ),
          SizedBox(height: 10.h),
          Text('plush607_rules'.tr, style: TextStyle(fontSize: 10.5.sp, color: sub, height: 1.3)),
        ],
      ),
    );
  }

  Widget _chip(String text, Color c, {Key? key}) => Container(
        key: key,
        padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 4.h),
        decoration: BoxDecoration(
          color: c,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(text,
            style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w800, color: Colors.white)),
      );
}

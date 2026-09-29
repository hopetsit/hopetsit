// v601 (PAM, 29/09) — CARTE AFFICHÉE INSTANTANÉMENT.
//
// Daniel : « cette mini-seconde d'attente m'énerve ». Quand la PawMap est
// stable (caméra à l'arrêt, au plus une fois par 10 s, et au passage en
// arrière-plan), on prend une PHOTO de la carte (`takeSnapshot`) et on
// l'enregistre sur le disque avec la position et le zoom. Au lancement
// suivant, la photo est posée tout de suite SOUS la vue Google, à la place
// du fond « Carte en préparation… » (qui reste le repli sans photo), et la
// caméra initiale est calée sur la même position/zoom : les vraies tuiles
// recouvrent la photo sans couture. La photo est retirée au premier
// « caméra à l'arrêt » ou au premier geste. Jamais de voile par-dessus,
// jamais de minuterie qui bloque.
//
// La photo n'est PAS utilisée si : elle a plus de 7 jours ; l'endroit à
// ouvrir est à plus de ~20 km de la photo ; le mode nuit, le type de carte
// (satellite), le compte ou les proportions de l'écran ont changé ; le
// fichier a disparu.
//
// Règles PURES dans [PawMapSnapshotRules] (testées) ; la lecture (synchrone,
// GetStorage + `File.existsSync`) et l'écriture (asynchrone, fichier
// temporaire puis renommage) dans [PawMapSnapshotStore].

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:path_provider/path_provider.dart';

/// Ce qui accompagne la photo : où, à quel zoom, quand, dans quel habit.
@immutable
class PawMapSnapshotMeta {
  const PawMapSnapshotMeta({
    required this.path,
    required this.lat,
    required this.lng,
    required this.zoom,
    required this.savedAt,
    this.night = false,
    this.satellite = false,
    this.uid = '',
    this.aspect = 0,
  });

  final String path;
  final double lat;
  final double lng;
  final double zoom;
  final DateTime savedAt;
  final bool night;
  final bool satellite;

  /// Compte à qui appartient la photo (jamais montrée à un autre compte).
  final String uid;

  /// Largeur / hauteur de la carte au moment de la photo (0 = inconnu).
  final double aspect;

  LatLng get center => LatLng(lat, lng);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'path': path,
        'lat': lat,
        'lng': lng,
        'zoom': zoom,
        'savedAt': savedAt.millisecondsSinceEpoch,
        'night': night,
        'satellite': satellite,
        'uid': uid,
        'aspect': aspect,
      };

  static PawMapSnapshotMeta? fromJson(dynamic raw) {
    if (raw is String) {
      try {
        raw = jsonDecode(raw);
      } catch (_) {
        return null;
      }
    }
    if (raw is! Map) return null;
    final path = raw['path'];
    final lat = (raw['lat'] as num?)?.toDouble();
    final lng = (raw['lng'] as num?)?.toDouble();
    final zoom = (raw['zoom'] as num?)?.toDouble();
    final at = (raw['savedAt'] as num?)?.toInt();
    if (path is! String ||
        path.isEmpty ||
        lat == null ||
        lng == null ||
        zoom == null ||
        at == null) {
      return null;
    }
    if (lat.abs() > 90 || lng.abs() > 180 || zoom < 2 || zoom > 21) return null;
    return PawMapSnapshotMeta(
      path: path,
      lat: lat,
      lng: lng,
      zoom: zoom,
      savedAt: DateTime.fromMillisecondsSinceEpoch(at),
      night: raw['night'] == true,
      satellite: raw['satellite'] == true,
      uid: (raw['uid'] ?? '').toString(),
      aspect: (raw['aspect'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Règles pures : faut-il montrer la photo ? faut-il en prendre une ?
class PawMapSnapshotRules {
  PawMapSnapshotRules._();

  static const Duration maxAge = Duration(days: 7);
  static const double maxDistanceKm = 20;
  static const Duration minInterval = Duration(seconds: 10);

  /// Distance à vol d'oiseau (haversine), en km.
  static double distanceKm(LatLng a, LatLng b) {
    const double r = 6371;
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLng = (b.longitude - a.longitude) * math.pi / 180;
    final la1 = a.latitude * math.pi / 180;
    final la2 = b.latitude * math.pi / 180;
    final h = math.pow(math.sin(dLat / 2), 2) +
        math.cos(la1) * math.cos(la2) * math.pow(math.sin(dLng / 2), 2);
    return 2 * r * math.asin(math.min(1.0, math.sqrt(h.toDouble())));
  }

  /// La photo peut-elle être affichée pour une ouverture à [target] ?
  static bool usable(
    PawMapSnapshotMeta? m, {
    required DateTime now,
    required LatLng target,
    required bool night,
    required bool satellite,
    required String uid,
    double aspect = 0,
  }) {
    if (m == null) return false;
    final age = now.difference(m.savedAt);
    if (age.isNegative || age > maxAge) return false;
    if (distanceKm(m.center, target) > maxDistanceKm) return false;
    if (m.night != night || m.satellite != satellite) return false;
    if (m.uid != uid) return false;
    if (aspect > 0 && m.aspect > 0 && (aspect - m.aspect).abs() / aspect > 0.03) {
      return false;
    }
    return true;
  }

  /// Une nouvelle photo est-elle due ? (au plus une fois par 10 s)
  static bool due(DateTime? last, DateTime now) =>
      last == null || now.difference(last) >= minInterval;
}

/// Lecture / écriture de la photo sur l'appareil.
class PawMapSnapshotStore {
  PawMapSnapshotStore._();

  /// Réduit une image PNG à la moitié de sa largeur (repli : l'originale).
  static Future<Uint8List> halve(Uint8List png) async {
    try {
      final buf = await ui.ImmutableBuffer.fromUint8List(png);
      final desc = await ui.ImageDescriptor.encoded(buf);
      final int w = desc.width;
      if (w <= 640) {
        desc.dispose();
        buf.dispose();
        return png;
      }
      final codec = await desc.instantiateCodec(targetWidth: w ~/ 2);
      final frame = await codec.getNextFrame();
      final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      frame.image.dispose();
      codec.dispose();
      desc.dispose();
      buf.dispose();
      if (data == null) return png;
      return data.buffer.asUint8List();
    } catch (_) {
      return png;
    }
  }

  static const String metaKey = 'pawmap601_snapshot';
  static const String fileName = 'pawmap_snapshot.png';

  /// Lecture SYNCHRONE (premier rendu) : la fiche dans GetStorage et
  /// l'existence du fichier. Null si rien d'utilisable.
  static PawMapSnapshotMeta? readSync() {
    try {
      final m = PawMapSnapshotMeta.fromJson(GetStorage().read(metaKey));
      if (m == null) return null;
      if (File(m.path).existsSync()) return m;
      // v603 — iPhone : après une MISE À JOUR de l'app, le chemin du dossier
      // de l'app change (la photo est toujours là, ailleurs). On la retrouve
      // dans le dossier actuel, connu depuis [warmUp].
      final dir = _supportDir;
      if (dir == null) return null;
      final moved = '$dir/$fileName';
      if (moved == m.path || !File(moved).existsSync()) return null;
      return PawMapSnapshotMeta(
        path: moved,
        lat: m.lat,
        lng: m.lng,
        zoom: m.zoom,
        savedAt: m.savedAt,
        night: m.night,
        satellite: m.satellite,
        uid: m.uid,
        aspect: m.aspect,
      );
    } catch (_) {
      return null;
    }
  }

  /// Dossier actuel de l'app (lu une fois au lancement par [warmUp]).
  static String? _supportDir;

  /// v603 — décode la photo PENDANT l'écran de démarrage (≈ 1 s) : quand
  /// la carte la pose, elle est déjà prête dans le cache d'images (même clé
  /// que `Image.file` : chemin + échelle 1). Ne lève jamais.
  static Future<void> warmUp() async {
    try {
      if (pawMap603NoCover) return;
      if (readSync() == null) {
        _supportDir = (await getApplicationSupportDirectory()).path;
      }
      final m = readSync();
      if (m == null) return;
      final stream =
          FileImage(File(m.path)).resolve(ImageConfiguration.empty);
      late final ImageStreamListener l;
      l = ImageStreamListener((_, __) {
        pawMap603Log('photo décodée d\'avance');
        stream.removeListener(l);
      }, onError: (_, __) => stream.removeListener(l));
      stream.addListener(l);
    } catch (_) {/* la carte la décodera elle-même */}
  }

  static bool _writing = false;

  /// Enregistre la photo (fichier temporaire puis renommage : jamais une
  /// image à moitié écrite) et sa fiche. Ne lève jamais.
  static Future<bool> save(
    Uint8List bytes, {
    required LatLng center,
    required double zoom,
    required bool night,
    required bool satellite,
    required String uid,
    double aspect = 0,
    DateTime? now,
  }) async {
    if (bytes.isEmpty || _writing) return false;
    _writing = true;
    try {
      // Mesuré au simulateur (29/09) : la photo pleine définition (≈ 1,7 Mo,
      // 1179 × 2556) mettait plus longtemps à se décoder que la carte à
      // arriver. Elle est enregistrée à moitié de sa largeur (≈ 4× moins de
      // pixels) : décodée à temps, à peine plus douce le temps d'un éclair.
      bytes = await halve(bytes);
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}/$fileName');
      final tmp = File('${dir.path}/$fileName.tmp');
      await tmp.writeAsBytes(bytes, flush: true);
      await tmp.rename(file.path);
      final meta = PawMapSnapshotMeta(
        path: file.path,
        lat: center.latitude,
        lng: center.longitude,
        zoom: zoom,
        savedAt: now ?? DateTime.now(),
        night: night,
        satellite: satellite,
        uid: uid,
        aspect: aspect,
      );
      await GetStorage().write(metaKey, meta.toJson());
      return true;
    } catch (e) {
      debugPrint('[PawMap601] photo non enregistrée : $e');
      return false;
    } finally {
      _writing = false;
    }
  }
}


// ─── v603 (PAM, 29/09) — la photo PAR-DESSUS la carte au démarrage ─────────
//
// Daniel (29/09, 602) : « il y a toujours la mini attente de la map ». Sur
// iPhone, la vue Google peint son propre fond gris OPAQUE ~0,3 s avant les
// tuiles : la photo 601, posée DESSOUS, était cachée. La même photo est donc
// aussi posée PAR-DESSUS, le temps que la carte soit prête, et retirée
// (fondu de 120 ms) à la PREMIÈRE de ces conditions :
//   · la carte est prête (premier « caméra à l'arrêt » après sa création,
//     plus un court délai de peinture mesuré — voir [readyGrace]) ;
//   · le premier geste de la personne, où qu'il soit ;
//   · un PLAFOND DUR de 800 ms après que l'onglet est devenu visible : un
//     vrai `Timer`, indépendant de Google (le voile du 595 attendait un
//     « caméra à l'arrêt » qui ne venait jamais : 5 s).
// Sans photo (premier lancement) : rien par-dessus.

/// Journal de mesure du 603 : seulement avec `--dart-define=HPS_PROBE603=true`
/// (jamais dans le build des stores).
const bool kPawMap603Probe =
    bool.fromEnvironment('HPS_PROBE603', defaultValue: false);

void pawMap603Log(String what) {
  if (kPawMap603Probe) {
    // ignore: avoid_print
    print('[P603] ${DateTime.now().millisecondsSinceEpoch} $what');
  }
}

/// Réglage de MESURE (probe seulement, sinon [compiled]) : variable
/// d'environnement ou ligne `NOM=valeur` du fichier `p603.txt` (iOS :
/// `Documents/` de l'app ; Android : dossier externe de l'app, poussé par
/// adb). Jamais lu dans le build des stores.
int pawMap603Int(String name, int compiled) {
  if (!kPawMap603Probe) return compiled;
  try {
    final env = Platform.environment[name];
    if (env != null) return int.parse(env.trim());
    // iOS : pas de HOME dans l'environnement ; tmp/ est dans le dossier
    // de l'app, à côté de Documents/.
    final home = Directory.systemTemp.parent.path;
    File f = File('$home/Documents/p603.txt');
    if (!f.existsSync()) {
      f = File(
          '/sdcard/Android/data/com.cardellihermanos.hopetsit/files/p603.txt');
    }
    if (f.existsSync()) {
      for (final line in f.readAsLinesSync()) {
        final kv = line.split('=');
        if (kv.length == 2 && kv[0].trim() == name) {
          return int.parse(kv[1].trim());
        }
      }
    }
  } catch (e) {
    pawMap603Log('réglage $name illisible : $e');
  }
  return compiled;
}

/// Mesure « AVANT » (comportement 602 : pas de photo par-dessus).
bool get pawMap603NoCover => pawMap603Int('HPS_NO_COVER', 0) == 1;

/// État de la photo posée par-dessus la carte. Logique sans widget, testée.
class PawMapLaunchCover extends ChangeNotifier {
  PawMapLaunchCover({
    this.cap = kCap,
    this.readyGrace = kReadyGrace,
  });

  /// Plafond dur : jamais plus longtemps que ça une fois l'onglet visible.
  static const Duration kCap = Duration(milliseconds: 800);

  /// Durée du fondu de sortie.
  static const Duration kFade = Duration(milliseconds: 120);

  /// « Caméra à l'arrêt » ne veut pas dire « tuiles peintes » : délai laissé
  /// à la vue Google pour peindre après son premier arrêt (mesuré au 603).
  static const Duration kReadyGrace = Duration(milliseconds: 150);

  final Duration cap;
  final Duration readyGrace;

  bool _up = false;
  bool _removed = true;
  bool _visible = false;
  Timer? _capTimer;
  Timer? _graceTimer;
  String? _reason;

  /// La photo est posée (opacité 1).
  bool get up => _up;

  /// La photo n'est plus dans l'arbre (fondu terminé ou jamais posée).
  bool get removed => _removed;

  /// Pourquoi elle est partie ('carte prête', 'geste', 'plafond'…).
  String? get reason => _reason;

  /// Le plafond est-il en route ?
  bool get capRunning => _capTimer?.isActive ?? false;

  /// Photo utilisable au lancement : on la pose.
  void show() {
    if (_up) return;
    _up = true;
    _removed = false;
    _reason = null;
    pawMap603Log('photo par-dessus POSÉE');
    notifyListeners();
  }

  /// L'onglet de la carte est visible : le plafond démarre (une seule fois).
  void visible() {
    _visible = true;
    if (!_up || _capTimer != null) return;
    pawMap603Log('onglet visible : plafond ${cap.inMilliseconds} ms');
    _capTimer = Timer(cap, () => dismiss('plafond'));
  }

  /// L'onglet de la carte est caché (autre onglet devant).
  void hidden() => _visible = false;

  /// La carte vient de s'arrêter pour la première fois : retrait après le
  /// court délai de peinture.
  void mapReady() {
    if (!_up || _graceTimer != null) return;
    if (readyGrace == Duration.zero) {
      dismiss('carte prête');
      return;
    }
    _graceTimer = Timer(readyGrace, () => dismiss('carte prête'));
  }

  /// Retrait (fondu), à la première condition remplie.
  void dismiss(String why) {
    if (!_up) return;
    _up = false;
    _reason = why;
    _capTimer?.cancel();
    _graceTimer?.cancel();
    pawMap603Log('photo par-dessus RETIRÉE : $why');
    // Onglet caché : personne ne voit le fondu (et il ne tournerait pas,
    // les animations y sont coupées) → la photo part tout de suite.
    if (!_visible) _removed = true;
    notifyListeners();
  }

  /// Fin du fondu : la photo quitte l'arbre.
  void faded() {
    if (_up || _removed) return;
    _removed = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _capTimer?.cancel();
    _graceTimer?.cancel();
    super.dispose();
  }
}

/// La photo posée par-dessus la carte (ne capte aucun toucher : le geste
/// passe à la carte, qui la retire).
class PawMapLaunchCoverView extends StatelessWidget {
  const PawMapLaunchCoverView({
    super.key,
    required this.cover,
    required this.image,
  });

  final PawMapLaunchCover cover;

  /// L'image (en production : `Image.file` de la photo 601).
  final Widget image;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: cover,
      builder: (_, __) {
        if (cover.removed) return const SizedBox.shrink();
        return IgnorePointer(
          child: AnimatedOpacity(
            key: const ValueKey<String>('pawmap_cover'),
            opacity: cover.up ? 1 : 0,
            duration: PawMapLaunchCover.kFade,
            onEnd: cover.faded,
            child: image,
          ),
        );
      },
    );
  }
}

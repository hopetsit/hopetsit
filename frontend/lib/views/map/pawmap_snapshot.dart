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
      if (!File(m.path).existsSync()) return null;
      return m;
    } catch (_) {
      return null;
    }
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

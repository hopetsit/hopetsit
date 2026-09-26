// v592 (26/09/2026) — Daniel : « je veux le vrai HD, comme sur le site ».
// Le site dessine la PawMap sur les tuiles OpenStreetMap (bâtiments, sentiers,
// noms de rues même en zoom fort) ; l'app utilisait le fond Google, bien moins
// détaillé dans beaucoup de quartiers (ex. Condado de Alhama). Ce fournisseur
// pose les MÊMES tuiles que le site par-dessus la carte Google (qui reste
// dessous : si une tuile n'arrive pas, Google s'affiche à sa place).
// Règles d'usage d'OpenStreetMap : User-Agent identifiable, cache local,
// pas plus de requêtes que nécessaire, mention « © OpenStreetMap » visible.
import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class PawOsmTileProvider implements TileProvider {
  PawOsmTileProvider({this.maxCached = 600});

  final int maxCached;
  static const _subdomains = ['a', 'b', 'c'];
  static const _userAgent =
      'HoPetSit/593 (+https://www.hopetsit.com; contact@hopetsit.com)';
  static const Duration _diskTtl = Duration(days: 14);

  // Cache mémoire LRU (la carte redemande souvent les mêmes tuiles).
  final LinkedHashMap<String, Uint8List> _cache =
      LinkedHashMap<String, Uint8List>();
  // v593 — requêtes en cours (une seule par tuile, partagée).
  final Map<String, Future<Uint8List?>> _inflight = {};
  final http.Client _client = http.Client();
  Directory? _dir;
  Future<Directory?>? _dirFuture;

  // v593 — MESURÉ au banc d'essai : une zone neuve mettait ~9 s à se remplir
  // alors qu'une tuile arrive en ~0,1 s. La carte Google demande les tuiles
  // une par une (le fournisseur répond de façon bloquante) : on part donc
  // chercher les 8 voisines EN MÊME TEMPS que la tuile demandée, et on garde
  // tout sur le téléphone 14 jours (réouverture instantanée).
  @override
  Future<Tile> getTile(int x, int y, int? zoom) async {
    final z = zoom ?? 0;
    if (z < 0 || z > 19) return TileProvider.noTile;
    final bytes = await _get(z, x, y);
    final n = 1 << z;
    for (var dx = -1; dx <= 1; dx++) {
      for (var dy = -1; dy <= 1; dy++) {
        if (dx == 0 && dy == 0) continue;
        final yy = y + dy;
        if (yy < 0 || yy >= n) continue;
        unawaited(_get(z, (x + dx) % n, yy));
      }
    }
    return bytes == null ? TileProvider.noTile : Tile(256, 256, bytes);
  }

  /// v593 — préchargement de la zone visible à l'ouverture (écran blanc
  /// signalé par Daniel) : toutes les tuiles autour du centre, en parallèle,
  /// au zoom courant et au zoom voisin, avant que la carte ne les demande.
  void prefetchAround(double lat, double lng, double zoom,
      {int radiusX = 3, int radiusY = 5}) {
    for (final z in {zoom.floor(), zoom.round()}) {
      if (z < 0 || z > 19) continue;
      final n = 1 << z;
      final x0 = ((lng + 180) / 360 * n).floor();
      final latR = lat * math.pi / 180;
      final y0 = ((1 - math.log(math.tan(latR) + 1 / math.cos(latR)) / math.pi) / 2 * n).floor();
      for (var dx = -radiusX; dx <= radiusX; dx++) {
        for (var dy = -radiusY; dy <= radiusY; dy++) {
          final yy = y0 + dy;
          if (yy < 0 || yy >= n) continue;
          unawaited(_get(z, (x0 + dx) % n, yy));
        }
      }
    }
  }

  Future<Uint8List?> _get(int z, int x, int y) {
    final key = '$z/$x/$y';
    final hit = _cache.remove(key);
    if (hit != null) {
      _cache[key] = hit;
      return Future.value(hit);
    }
    return _inflight[key] ??= _load(z, x, y, key).whenComplete(() {
      _inflight.remove(key);
    });
  }

  Future<Directory?> _cacheDir() => _dirFuture ??= () async {
        try {
          final base = await getTemporaryDirectory();
          final d = Directory('${base.path}/pawmap_osm');
          if (!await d.exists()) await d.create(recursive: true);
          return _dir = d;
        } catch (_) {
          return null;
        }
      }();

  Future<Uint8List?> _load(int z, int x, int y, String key) async {
    final dir = _dir ?? await _cacheDir();
    final file = dir == null ? null : File('${dir.path}/${z}_${x}_$y.png');
    try {
      if (file != null && await file.exists()) {
        final age = DateTime.now().difference(await file.lastModified());
        if (age < _diskTtl) {
          final b = await file.readAsBytes();
          if (b.isNotEmpty) return _remember(key, b);
        }
      }
    } catch (_) {/* cache disque illisible : on télécharge */}
    final sub = _subdomains[(x + y) % _subdomains.length];
    try {
      final resp = await _client
          .get(Uri.parse('https://$sub.tile.openstreetmap.org/$z/$x/$y.png'),
              headers: const {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200 || resp.bodyBytes.isEmpty) return null;
      if (file != null) {
        unawaited(file.writeAsBytes(resp.bodyBytes, flush: false).then((_) {}, onError: (_) {}));
      }
      return _remember(key, resp.bodyBytes);
    } catch (_) {
      return null;
    }
  }

  Uint8List _remember(String key, Uint8List b) {
    _cache[key] = b;
    while (_cache.length > maxCached) {
      _cache.remove(_cache.keys.first);
    }
    return b;
  }
}

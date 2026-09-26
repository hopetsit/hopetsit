// v592 (26/09/2026) — Daniel : « je veux le vrai HD, comme sur le site ».
// Le site dessine la PawMap sur les tuiles OpenStreetMap (bâtiments, sentiers,
// noms de rues même en zoom fort) ; l'app utilisait le fond Google, bien moins
// détaillé dans beaucoup de quartiers (ex. Condado de Alhama). Ce fournisseur
// pose les MÊMES tuiles que le site par-dessus la carte Google (qui reste
// dessous : si une tuile n'arrive pas, Google s'affiche à sa place).
// Règles d'usage d'OpenStreetMap : User-Agent identifiable, cache local,
// pas plus de requêtes que nécessaire, mention « © OpenStreetMap » visible.
import 'dart:collection';
import 'dart:typed_data';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class PawOsmTileProvider implements TileProvider {
  PawOsmTileProvider({this.maxCached = 400});

  final int maxCached;
  static const _subdomains = ['a', 'b', 'c'];
  static const _userAgent =
      'HoPetSit/592 (+https://www.hopetsit.com; contact@hopetsit.com)';

  // Cache mémoire LRU (la carte redemande souvent les mêmes tuiles).
  final LinkedHashMap<String, Uint8List> _cache =
      LinkedHashMap<String, Uint8List>();
  final http.Client _client = http.Client();

  @override
  Future<Tile> getTile(int x, int y, int? zoom) async {
    final z = zoom ?? 0;
    if (z < 0 || z > 19) return TileProvider.noTile;
    final key = '$z/$x/$y';
    final hit = _cache.remove(key);
    if (hit != null) {
      _cache[key] = hit;
      return Tile(256, 256, hit);
    }
    final sub = _subdomains[(x + y) % _subdomains.length];
    try {
      final resp = await _client
          .get(Uri.parse('https://$sub.tile.openstreetmap.org/$z/$x/$y.png'),
              headers: const {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200 || resp.bodyBytes.isEmpty) {
        return TileProvider.noTile;
      }
      _cache[key] = resp.bodyBytes;
      while (_cache.length > maxCached) {
        _cache.remove(_cache.keys.first);
      }
      return Tile(256, 256, resp.bodyBytes);
    } catch (_) {
      return TileProvider.noTile;
    }
  }
}

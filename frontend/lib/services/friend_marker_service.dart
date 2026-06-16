// v23.1 part 249 — Daniel : "sur lapp tu peux faire le meme delire le halo
// la photo de profile avec le cercle vert si walker bleu si sitter orange
// si owner et violet si famille".
//
// Service qui construit un BitmapDescriptor custom Google Maps avec la
// photo de profil de l'ami dans un cercle, bordure couleur role (vert/
// bleu/orange/silver), et anneau violet exterieur si famille. Parite
// design avec le composant FriendsLiveMap du website (v246+).
//
// Implementation :
//   1. Cache Map<key, BitmapDescriptor> pour eviter de regenerer le meme
//      marker plusieurs fois. Key = userId|avatarUrl|role|isFamily.
//   2. Si pas en cache, on lance un download async + canvas paint :
//        - retourne UN PLACEHOLDER sync (BitmapDescriptor.defaultMarker)
//          en attendant
//        - quand le bitmap final est pret, on bump une RxInt `rev` qui
//          force l'Obx du PawMap a rebuild -> marker remplace
//   3. Le download avatar utilise http simple (pas CachedNetworkImage
//      parce qu'on doit avoir les bytes bruts pour le canvas).

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class FriendMarkerService extends GetxService {
  /// Cache : key -> bitmap. Une fois calcule, on reutilise.
  final Map<String, BitmapDescriptor> _cache = {};

  /// Set de cles actuellement en chargement, pour eviter de declencher
  /// plusieurs downloads du meme avatar en parallele.
  final Set<String> _loading = {};

  /// v420 — Daniel : "la photo profil ne s'affiche pas sur la map, photo
  /// grise". Cause possible : un échec réseau transitoire mettait en cache
  /// le fallback gris DÉFINITIVEMENT (jamais re-téléchargé). On compte les
  /// échecs par clé et on retente jusqu'à 3 fois avant de figer le fallback.
  final Map<String, int> _failCount = {};

  /// Incrementee a chaque nouveau bitmap pret. Le PawMap _buildMarkers
  /// lit cette valeur via Obx -> rebuild auto quand un avatar finit
  /// de charger.
  final RxInt rev = 0.obs;

  static const _violetFamily = Color(0xFF8B5CF6);
  // v23.1.395 — anneau Paw Premium (or).
  static const _goldPremium = Color(0xFFE8A00A);
  static const _silver = Color(0xFFC0C0C0);

  String _cacheKey(String userId, String avatarUrl, String role, bool isFamily,
          bool isPremium) =>
      '$userId|$avatarUrl|$role|$isFamily|$isPremium';

  /// Lookup synchrone. Si pas en cache, declenche un build async et
  /// retourne un placeholder (marker plein couleur role) en attendant.
  BitmapDescriptor getOrPlaceholder({
    required String userId,
    required String avatarUrl,
    required String role,
    required bool isFamily,
    bool isPremium = false,
  }) {
    final key = _cacheKey(userId, avatarUrl, role, isFamily, isPremium);
    final cached = _cache[key];
    if (cached != null) return cached;
    if (!_loading.contains(key)) {
      _loading.add(key);
      // Lance build async sans attendre, mais ne throw pas.
      // ignore: discarded_futures
      _buildAndCache(key, avatarUrl, role, isFamily, isPremium);
    }
    return BitmapDescriptor.defaultMarkerWithHue(_hueForRole(role));
  }

  Future<void> _buildAndCache(
    String key,
    String avatarUrl,
    String role,
    bool isFamily,
    bool isPremium,
  ) async {
    try {
      Uint8List? avatarBytes;
      final isHttp = avatarUrl.isNotEmpty &&
          (avatarUrl.startsWith('http://') ||
              avatarUrl.startsWith('https://'));
      if (isHttp) {
        try {
          // Timeout 5s pour eviter de bloquer indefiniment si CDN down.
          // v420 — User-Agent explicite : certains CDN refusent le UA Dart
          // par defaut (403) → bytes null → photo grise. Un UA navigateur
          // basique evite ce rejet.
          final resp = await http.get(
            Uri.parse(avatarUrl),
            headers: const {'User-Agent': 'Mozilla/5.0 (HoPetSit)'},
          ).timeout(const Duration(seconds: 8));
          if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
            avatarBytes = resp.bodyBytes;
          }
        } catch (_) {/* defensive — on fallback cercle initiales */}
      }
      // v420 — echec reseau transitoire (URL valide mais download KO) : on
      // NE cache PAS le fallback gris, on retente au prochain rebuild
      // (jusqu'a 3 fois) au lieu de figer la photo grise pour toujours.
      final downloadFailed = isHttp && avatarBytes == null;
      final bytes = await _paintMarker(
        avatarBytes: avatarBytes,
        role: role,
        isFamily: isFamily,
        isPremium: isPremium,
      );
      final descriptor = BitmapDescriptor.bytes(bytes);
      if (downloadFailed && (_failCount[key] ?? 0) < 3) {
        _failCount[key] = (_failCount[key] ?? 0) + 1;
        // pas de mise en cache → nouveau download au prochain build.
      } else {
        _cache[key] = descriptor;
        _failCount.remove(key);
      }
      rev.value++;
    } catch (e) {
      // Si meme le paint plante, on laisse le placeholder default.
      debugPrint('[FriendMarkerService] build failed: $e');
    } finally {
      _loading.remove(key);
    }
  }

  /// Dessine le marker dans un Canvas 96x96 :
  ///   - Ring violet exterieur si famille (le plus large)
  ///   - Disque couleur role (fond du cercle)
  ///   - Photo profil clip circulaire au centre (ou cercle blanc + ? si null)
  ///   - Bordure blanche fine entre ring violet et fond role pour
  ///     bien separer visuellement.
  Future<Uint8List> _paintMarker({
    required Uint8List? avatarBytes,
    required String role,
    required bool isFamily,
    bool isPremium = false,
  }) async {
    // v23.1.350 — Daniel : "réduire un peu la taille des ronds amis et
    // famille" (ils dominaient la carte). 120 → 96 px (-20%), toutes les
    // couches (ring famille, disque rôle, photo) sont dérivées de `size`.
    const double size = 96.0;
    const double cx = size / 2;
    const double cy = size / 2;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, size, size),
    );

    final roleColor = _colorForRole(role);

    // Layer 1 : ring violet (famille) — fait toute la taille du bitmap.
    // v23.1.395 — Paw Premium : anneau OR prioritaire (badge 👑 ajouté en
    // dernier layer, par-dessus).
    if (isPremium) {
      final goldPaint = Paint()..color = _goldPremium;
      canvas.drawCircle(const Offset(cx, cy), size / 2 - 1, goldPaint);
    } else if (isFamily) {
      final familyPaint = Paint()..color = _violetFamily;
      canvas.drawCircle(const Offset(cx, cy), size / 2 - 1, familyPaint);
    }

    // Layer 2 : disque role color, leger inset si famille/premium pour que
    // le ring soit visible. Sinon disque pleine taille.
    final roleInset = (isFamily || isPremium) ? 10.0 : 4.0;
    final rolePaint = Paint()..color = roleColor;
    canvas.drawCircle(
      const Offset(cx, cy),
      size / 2 - roleInset,
      rolePaint,
    );

    // Layer 3 : bordure blanche fine pour separer photo / fond role.
    const double whiteRingThickness = 4.0;
    final photoRadius = size / 2 - roleInset - whiteRingThickness;
    final whiteRingPaint = Paint()..color = Colors.white;
    canvas.drawCircle(
      const Offset(cx, cy),
      photoRadius + whiteRingThickness / 2,
      whiteRingPaint,
    );

    // Layer 4 : photo profil clip dans le cercle interieur.
    if (avatarBytes != null) {
      try {
        final codec = await ui.instantiateImageCodec(
          avatarBytes,
          targetWidth: (photoRadius * 2).toInt(),
        );
        final frame = await codec.getNextFrame();
        final image = frame.image;
        final photoRect = Rect.fromCircle(
          center: const Offset(cx, cy),
          radius: photoRadius,
        );
        canvas.save();
        canvas.clipPath(Path()..addOval(photoRect));
        canvas.drawImageRect(
          image,
          Rect.fromLTWH(
            0,
            0,
            image.width.toDouble(),
            image.height.toDouble(),
          ),
          photoRect,
          Paint()..filterQuality = FilterQuality.medium,
        );
        canvas.restore();
        image.dispose();
      } catch (_) {
        _paintFallback(canvas, cx, cy, photoRadius);
      }
    } else {
      _paintFallback(canvas, cx, cy, photoRadius);
    }

    // v23.1.395 — couronne 👑 en haut du marqueur quand Paw Premium actif
    // (Daniel : « sur mon tel j'ai pas le badge »).
    if (isPremium) {
      final crown = TextPainter(
        text: const TextSpan(text: '👑', style: TextStyle(fontSize: 26)),
        textDirection: TextDirection.ltr,
      )..layout();
      crown.paint(canvas, Offset(cx - crown.width / 2, -2));
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    img.dispose();
    return byteData!.buffer.asUint8List();
  }

  /// Fallback dans le cercle photo quand on n'a pas d'avatar valide :
  /// fond gris clair + icone "?" gros au centre. Reste reconnaissable
  /// meme sur petit zoom.
  void _paintFallback(Canvas canvas, double cx, double cy, double radius) {
    final bgPaint = Paint()..color = const Color(0xFFE2E8F0);
    canvas.drawCircle(Offset(cx, cy), radius, bgPaint);
    final tp = TextPainter(
      text: const TextSpan(
        text: '👤',
        // v23.1.350 — mis à l'échelle avec le marqueur 120→96 px.
        style: TextStyle(fontSize: 45),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(
      canvas,
      Offset(cx - tp.width / 2, cy - tp.height / 2),
    );
  }

  Color _colorForRole(String role) {
    switch (role.toLowerCase()) {
      case 'walker':
        return const Color(0xFF16A34A); // vert
      case 'sitter':
        return const Color(0xFF2563EB); // bleu
      case 'owner':
        return const Color(0xFFEF4324); // orange brand
      default:
        return _silver;
    }
  }

  double _hueForRole(String role) {
    switch (role.toLowerCase()) {
      case 'walker':
        return BitmapDescriptor.hueGreen;
      case 'sitter':
        return BitmapDescriptor.hueAzure;
      case 'owner':
        return BitmapDescriptor.hueOrange;
      default:
        return BitmapDescriptor.hueViolet;
    }
  }
}

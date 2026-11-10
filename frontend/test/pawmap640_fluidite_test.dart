// 640 (PAM) — MESURE de ce que la carte renvoie au moteur Google Maps quand
// rien ne bouge (Daniel, 10/11 : « la fluidité de la carte est un peu
// molle »). Chaîne réelle côté Dart : vraies images d'épingles (mêmes
// peintres que l'écran), vrai calcul de différences du plugin
// (`MarkerUpdates.from`, appelé à CHAQUE reconstruction de la GoogleMap) et
// vraie mise en message (StandardMessageCodec, la base de Pigeon).
// Ce que ce banc NE mesure PAS : le temps passé côté natif (décodage du PNG,
// remplacement de l'image du marqueur) ni les images par seconde à l'écran.
// Les compteurs (marqueurs renvoyés, octets) sont exacts et vérifiés ; les
// durées sont affichées, jamais vérifiées (elles dépendent de la machine).
//   flutter test test/pawmap640_fluidite_test.dart --reporter expanded
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:hopetsit/views/map/widgets/pawmap_pins.dart';
import 'package:hopetsit/views/map/widgets/pawmap_zoom616.dart';

/// Densité de rendu d'un iPhone (pawPinRenderScale : 2,5 ; membres : 2).
const double _scPhoto = 2.5;
const double _scMember = 2;

Future<ui.Image> _avatar() async {
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  c.drawRect(
      const Rect.fromLTWH(0, 0, 168, 168),
      Paint()
        ..shader = const LinearGradient(
                colors: [Color(0xFFEF4324), Color(0xFF0E7C86)])
            .createShader(const Rect.fromLTWH(0, 0, 168, 168)));
  c.drawCircle(const Offset(84, 70), 34, Paint()..color = const Color(0xFFFFE9DC));
  return rec.endRecording().toImage(168, 168);
}

class _Img {
  _Img(this.icon, this.bytes, this.px, this.ms);
  final BitmapDescriptor icon;
  final int bytes;
  final int px;
  final double ms;
}

Future<_Img> _img(Size sz, double sc, void Function(Canvas) paint) async {
  // Un tour à blanc, puis la moyenne de 20 dessins complets.
  await renderPinPng(sz.width, sz.height, paint, scale: sc);
  final sw = Stopwatch()..start();
  late Uint8List png;
  for (var i = 0; i < 20; i++) {
    png = await renderPinPng(sz.width, sz.height, paint, scale: sc);
  }
  sw.stop();
  return _Img(
      BitmapDescriptor.bytes(png, width: sz.width, height: sz.height),
      png.lengthInBytes,
      (sz.width * sc).ceil() * (sz.height * sc).ceil(),
      sw.elapsedMicroseconds / 1000 / 20);
}

Future<_Img> _friendPhoto(ui.Image avatar, {int boostPhase = -1}) {
  final double m = boostPhase >= 0
      ? PawMapPinPainter.photoMarginGlow
      : PawMapPinPainter.photoMarginFriend640;
  final double s = PawMapPinPainter.photoBitmapSize(kPawFriendSize640, margin: m);
  return _img(
      Size(s, s),
      _scPhoto,
      (c) => PawMapPinPainter.paintPhotoDot(c,
          avatar: avatar,
          ringColor: PawMapLegend.friend,
          size: kPawFriendSize640,
          crownSize: kPawFriendCrown640,
          boostPhase: boostPhase >= 0 ? boostPhase / kBoostPhases : null,
          margin: m,
          fallbackTint: PawMapLegend.friend));
}

Future<_Img> _pastille(PawPinSpec639 s) =>
    _img(pawPinBitmap639(s), _scMember, (c) => paintPin639(c, s));

Marker _mk(String id, int i, BitmapDescriptor icon) => Marker(
      markerId: MarkerId(id),
      position: LatLng(-35 + (i % 10) * 0.001, -30 + (i ~/ 10) * 0.001),
      icon: icon,
      anchor: const Offset(0.5, 0.5),
      consumeTapEvents: true,
    );

/// Une reconstruction de la GoogleMap : différences + message, [n] fois.
({int changed, int bytes, double us}) _tick(Set<Marker> prev, Set<Marker> cur,
    {int n = 200}) {
  var changed = 0, bytes = 0;
  final sw = Stopwatch()..start();
  for (var i = 0; i < n; i++) {
    final u = MarkerUpdates.from(prev, cur);
    changed = u.markersToChange.length + u.markersToAdd.length;
    final msg = const StandardMessageCodec().encodeMessage(u.toJson());
    bytes = msg!.lengthInBytes;
  }
  sw.stop();
  return (changed: changed, bytes: bytes, us: sw.elapsedMicroseconds / n);
}

void main() {
  test('640 — images renvoyées au moteur de carte, par seconde, carte immobile',
      () async {
    final avatar = await _avatar();
    // ── Coût d'une image (dessin → image → PNG), à la densité d'un iPhone.
    final friendPast = await _pastille(
        PawPinSpec639(roles: const ['sitter'], halo: PawHalo639.friend));
    final friendPhoto = await _friendPhoto(avatar);
    final boostPhases = <_Img>[
      for (var p = 0; p < kBoostPhases; p++) await _friendPhoto(avatar, boostPhase: p),
    ];
    final member = await _pastille(PawPinSpec639(roles: const ['sitter']));
    final waves = <_Img>[
      for (var w = 0; w < kPawWaveSteps639; w++)
        await _pastille(PawPinSpec639(
            roles: const ['sitter'], halo: PawHalo639.follow, wave: w)),
    ];
    // ignore: avoid_print
    print('IMAGE | pastille ami 639 : ${friendPast.px} px, ${friendPast.bytes} o, '
        '${friendPast.ms.toStringAsFixed(2)} ms');
    // ignore: avoid_print
    print('IMAGE | photo ami 640    : ${friendPhoto.px} px, ${friendPhoto.bytes} o, '
        '${friendPhoto.ms.toStringAsFixed(2)} ms');
    // ignore: avoid_print
    print('IMAGE | photo ami boosté : ${boostPhases.first.px} px, '
        '${boostPhases.map((e) => e.bytes).join(' / ')} o (4 phases), '
        '${boostPhases.first.ms.toStringAsFixed(2)} ms');
    // ignore: avoid_print
    print('IMAGE | pastille onde    : ${waves.first.px} px, '
        '${waves.map((e) => e.bytes).join(' / ')} o (6 pas), '
        '${waves.first.ms.toStringAsFixed(2)} ms');

    // ── Carte au repos : 100 membres en pastille + la situation étudiée.
    const int n = 100;
    Set<Marker> base() =>
        {for (var i = 0; i < n; i++) _mk('nearby_$i', i, member.icon)};

    void report(String name, Set<Marker> a, Set<Marker> b, double ticksPerSec) {
      final r = _tick(a, b);
      // ignore: avoid_print
      print('REPOS | $name : ${r.changed} marqueur(s) renvoyé(s) par battement, '
          '${r.bytes} o, ${r.us.toStringAsFixed(0)} µs Dart ; '
          '× ${ticksPerSec.toStringAsFixed(2)}/s = '
          '${(r.changed * ticksPerSec).toStringAsFixed(1)} image(s)/s, '
          '${(r.bytes * ticksPerSec / 1024).toStringAsFixed(0)} Ko/s');
    }

    // Battements lus dans paw_map_screen.dart : halo 600 ms (1,67/s) si
    // quelque chose respire, sinon 1 sur 5 (0,33/s) ; onde 300 ms (3,33/s).
    const double idle = 1000 / 600 / 5, halo = 1000 / 600, wave = 1000 / 300;

    // A. Rien d'animé : la même liste, rien à renvoyer.
    final a0 = base();
    final rIdle = _tick(a0, a0);
    expect(rIdle.changed, 0);
    report('rien d\'animé', a0, a0, idle);

    // B. 639 : un ami boosté en PASTILLE (halo fixe) → rien à renvoyer.
    final b0 = base()..add(_mk('friend_1', 3, friendPast.icon));
    expect(_tick(b0, b0).changed, 0);
    report('639 ami boosté en pastille (fixe)', b0, b0, idle);

    // C. 640 sans correctif : le même ami en PHOTO, halo PawBoost qui respire
    //    (4 images) → 1 image renvoyée à chaque battement de 600 ms.
    final c0 = base()..add(_mk('friend_1', 3, boostPhases[0].icon));
    final c1 = base()..add(_mk('friend_1', 3, boostPhases[1].icon));
    final rC = _tick(c0, c1);
    expect(rC.changed, 1);
    report('640 ami boosté en photo (respire)', c0, c1, halo);

    // D. 640 livré : l'image du halo vient de la VRAIE fonction de l'écran
    //    (pawBoostPhase640) avec le VRAI coupe-circuit. kPawSmooth640 vrai →
    //    halo FIXE, rien à renvoyer ; faux → il respire comme en C.
    Set<Marker> d(int running) => base()
      ..add(_mk(
          'friend_1',
          3,
          boostPhases[pawBoostPhase640(
                  fixed: kPawFriendBoostFixed640,
                  reduceMotion: false,
                  running: running)]
              .icon));
    final rD = _tick(d(0), d(1));
    expect(rD.changed, kPawFriendBoostFixed640 ? 0 : 1);
    report('640 livré, ami boosté en photo (kPawSmooth640=$kPawSmooth640)', d(0),
        d(1), kPawFriendBoostFixed640 ? idle : halo);

    // E. Onde PawFollow : K membres, 6 images toutes les 300 ms. « avant » =
    //    le 639 ; « livré » = décision de la VRAIE fonction pawWaveAnimated640
    //    (au-delà de kPawWaveMax640 : halo violet fixe, plus de minuterie).
    final followFixed = await _pastille(
        PawPinSpec639(roles: const ['sitter'], halo: PawHalo639.follow));
    for (final k in const [1, 3, 4, 5, 20]) {
      Set<Marker> w(int step, {required bool animated}) => {
            for (var i = 0; i < n; i++)
              _mk(
                  'nearby_$i',
                  i,
                  i < k
                      ? (animated ? waves[step].icon : followFixed.icon)
                      : member.icon),
          };
      final r = _tick(w(0, animated: true), w(1, animated: true));
      expect(r.changed, k);
      report('avant (639) onde PawFollow, $k membre(s)', w(0, animated: true),
          w(1, animated: true), wave);
      final bool an = pawWaveAnimated640(k);
      final r2 = _tick(w(0, animated: an), w(1, animated: an));
      expect(r2.changed, an ? k : 0);
      report('livré (kPawSmooth640=$kPawSmooth640) onde PawFollow, $k membre(s)',
          w(0, animated: an), w(1, animated: an), an ? wave : idle);
    }

    // F. Pendant un geste : la règle de l'écran (pawMapRecalcDuringMove616,
    //    appelée par _onCameraMove) rejouée à 60 événements/s — ce n'est PAS
    //    l'écran lui-même. Chaque « recalcul » = une passe complète de
    //    marqueurs. Les battements (halo, onde) sont sautés pendant le geste.
    int recalcs(double z0, double z1, int ms) {
      var pinZoom = z0;
      DateTime? last;
      final t0 = DateTime(2026, 11, 10);
      var count = 0;
      for (var t = 0; t <= ms; t += 16) {
        final z = z0 + (z1 - z0) * t / ms;
        final now = t0.add(Duration(milliseconds: t));
        if (pawMapRecalcDuringMove616(zoom: z, pinZoom: pinZoom, lastAt: last, now: now)) {
          last = now;
          pinZoom = z;
          count++;
        }
      }
      return count;
    }

    final pan = recalcs(14, 14, 2000);
    final pinch = recalcs(12, 16, 1000);
    expect(pan, 0);
    expect(pinch, lessThanOrEqualTo(9));
    // ignore: avoid_print
    print('GESTE | déplacement de 2 s sans zoom : $pan passe(s) de marqueurs');
    // ignore: avoid_print
    print('GESTE | pincement 12 → 16 en 1 s : $pinch passe(s) de marqueurs');
    avatar.dispose();
  });
}

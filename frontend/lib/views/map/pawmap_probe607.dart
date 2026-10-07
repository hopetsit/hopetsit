// 607 (PAM, 02/10/2026) — MESURE de la fluidité de la PawMap (Daniel : « que
// toutes les icônes des utilisateurs y restent, des mini-lags »).
//
// Actif SEULEMENT dans un build de mesure (`--dart-define=HPS_PROBE603=true`)
// et si `HPS_GEST607=1` est écrit dans Documents/p603.txt. Jamais dans le
// build des stores (constante de compilation fausse → code mort retiré).
//
// Ce que la mesure rejoue, toujours à l'identique (avant / après) : Paris au
// zoom 12,5, trois glissés de carte, un zoom avant, un zoom arrière, un
// dernier glissé. Elle note, pour chaque marqueur posé sur la carte :
//   · « disparu » : présent à une image, absent à la suivante alors qu'on ne
//     fait que bouger la caméra (un rond qui clignote) ;
//   · les reconstructions complètes de la liste des marqueurs ;
//   · les images lentes de l'interface (> 16,7 ms) et leur retard cumulé.

import 'dart:async';
import 'package:flutter/scheduler.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'pawmap_osm_tiles.dart' show PawOsmTileProvider;
import 'pawmap_snapshot.dart' show kPawMap603Probe, pawMap603Log, pawMap603Int;

class PawProbe607 {
  PawProbe607._();
  static final PawProbe607 instance = PawProbe607._();

  bool get enabled => kPawMap603Probe && pawMap603Int('HPS_GEST607', 0) == 1;

  bool _running = false;
  bool _started = false;
  Set<String> _last = <String>{};
  final Map<String, int> _goneAt = <String, int>{};
  int _vanished = 0; // marqueurs absents d'une image à l'autre
  int _blinks = 0; // … et revenus en moins de 3 s (clignotement)
  int _emptyFrames = 0; // liste de membres vide alors qu'elle ne l'était pas
  int _setChanges = 0; // nouvelles listes de marqueurs envoyées à la carte
  int _builds = 0; // appels de _buildMarkers
  int _frames = 0;
  int _slow = 0;
  int _jankMs = 0;
  int _worst = 0;
  final List<double> uiMs613 = <double>[];
  final List<double> rasterMs613 = <double>[];
  int _tiles0 = 0, _net0 = 0;
  Set<Marker>? _lastSet;
  Set<Marker>? _lastSetSeen;
  String _phase = '';
  final Map<String, int> _blinksBy = <String, int>{};
  int _minIds = 1 << 30;
  // Marqueur dont l'IMAGE change d'une liste à l'autre (même id) : sur iOS,
  // chaque nouvelle image est renvoyée au SDK et le rond « saute ».
  int _iconSwaps = 0;
  // Marqueur affiché avec l'épingle Google par défaut (image pas prête).
  int _defaultIcons = 0;
  final Map<String, BitmapDescriptor> _iconOf = <String, BitmapDescriptor>{};
  final Map<String, int> _vanishBy = <String, int>{};
  int _maxIds = 0;

  /// Appelé à chaque reconstruction complète des marqueurs.
  void onBuildMarkers() {
    if (_running) _builds++;
  }

  /// Appelé avec la liste remise à la GoogleMap à chaque construction.
  void onMarkers(Set<Marker> markers) {
    if (!_running) return;
    if (!identical(markers, _lastSet)) _setChanges++;
    _lastSet = markers;
    final now = DateTime.now().millisecondsSinceEpoch;
    final ids = <String>{
      for (final m in markers)
        if (_isMember(m.markerId.value)) m.markerId.value,
    };
    if (!identical(markers, _lastSetSeen)) {
      _lastSetSeen = markers;
      for (final m in markers) {
        if (!_isMember(m.markerId.value)) continue;
        if (m.icon.toJson() is List && (m.icon.toJson() as List).first == 'defaultMarker') {
          _defaultIcons++;
        }
        final prev = _iconOf[m.markerId.value];
        if (prev != null && !identical(prev, m.icon)) _iconSwaps++;
        _iconOf[m.markerId.value] = m.icon;
      }
    }
    for (final id in _last) {
      if (!ids.contains(id)) {
        _vanished++;
        _vanishBy[_phase] = (_vanishBy[_phase] ?? 0) + 1;
        _goneAt[id] = now;
      }
    }
    for (final id in ids) {
      final t = _goneAt.remove(id);
      if (t != null && now - t < 3000) {
        _blinks++;
        _blinksBy[_phase] = (_blinksBy[_phase] ?? 0) + 1;
      }
    }
    if (_last.isNotEmpty && ids.isEmpty) _emptyFrames++;
    if (ids.length < _minIds) _minIds = ids.length;
    if (ids.length > _maxIds) _maxIds = ids.length;
    _last = ids;
  }

  static bool _isMember(String id) =>
      id == 'me' || id.startsWith('nearby_') || id.startsWith('friend_');

  void _onTimings(List<FrameTiming> ts) {
    for (final t in ts) {
      final ms = t.totalSpan.inMicroseconds / 1000.0;
      _frames++;
      uiMs613.add(t.buildDuration.inMicroseconds / 1000.0);
      rasterMs613.add(t.rasterDuration.inMicroseconds / 1000.0);
      if (ms > 16.7) {
        _slow++;
        _jankMs += (ms - 16.7).round();
      }
      if (ms > _worst) _worst = ms.round();
    }
  }

  /// Rejoue le parcours une fois, la carte prête.
  Future<void> run(Future<GoogleMapController?> Function() ctl) async {
    if (!enabled || _started) return;
    _started = true;
    final c = await ctl();
    if (c == null) return;
    const paris = LatLng(48.8566, 2.3522);
    await c.moveCamera(CameraUpdate.newLatLngZoom(paris, 12.5));
    await Future<void>.delayed(const Duration(seconds: 6));
    pawMap603Log('G607 DEBUT');
    _tiles0 = PawOsmTileProvider.getTileCalls613; _net0 = PawOsmTileProvider.netFetches613;
    _running = true;
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    Future<void> step(CameraUpdate u, int ms, int pause) async {
      _phase = u.toJson().toString().contains('zoom') ? 'zoom' : 'glisse';
      await c.animateCamera(u, duration: Duration(milliseconds: ms));
      await Future<void>.delayed(Duration(milliseconds: ms + pause));
    }

    await step(CameraUpdate.scrollBy(220, 0), 700, 900);
    await step(CameraUpdate.scrollBy(-160, 260), 700, 900);
    await step(CameraUpdate.scrollBy(-120, -300), 700, 900);
    await step(CameraUpdate.zoomTo(14.2), 900, 1500);
    await step(CameraUpdate.zoomTo(11.0), 900, 1500);
    await step(CameraUpdate.scrollBy(200, 120), 700, 2000);
    _running = false;
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    String pc(List<double> l) { if (l.isEmpty) return '-'; final v = [...l]..sort(); double q(double f) => v[((v.length - 1) * f).round()]; return 'p50=${q(.5).toStringAsFixed(1)} p90=${q(.9).toStringAsFixed(1)} max=${v.last.toStringAsFixed(1)} n=${v.length}'; }
    pawMap603Log('G613 UI ${pc(uiMs613)} | RASTER ${pc(rasterMs613)} | tuiles=${PawOsmTileProvider.getTileCalls613 - _tiles0} reseau=${PawOsmTileProvider.netFetches613 - _net0}');
    pawMap603Log('G607 FIN disparus=$_vanished clignotements=$_blinks '
        'cartesVides=$_emptyFrames listesEnvoyees=$_setChanges '
        'reconstructions=$_builds images=$_frames lentes=$_slow '
        'retardMs=$_jankMs pireMs=$_worst membresMin=$_minIds membresMax=$_maxIds '
        'clignotementsParPhase=$_blinksBy disparusParPhase=$_vanishBy '
        'imagesChangees=$_iconSwaps epinglesGoogle=$_defaultIcons');
  }

  /// Vues fixes pour les planches avant/après (HPS_VIEW607=1) : centre
  /// HPS_VIEW_LAT/LNG (× 1e6), zooms HPS_VIEW_Z0..Z1 (× 10) par pas de 5,
  /// chaque vue tenue HPS_VIEW_HOLD_MS (6 s par défaut).
  bool get viewEnabled => kPawMap603Probe && pawMap603Int('HPS_VIEW607', 0) == 1;
  bool _viewStarted = false;
  Future<void> runViews(Future<GoogleMapController?> Function() ctl) async {
    if (!viewEnabled || _viewStarted) return;
    _viewStarted = true;
    final c = await ctl();
    if (c == null) return;
    final lat = pawMap603Int('HPS_VIEW_LAT', 48902000) / 1e6;
    final lng = pawMap603Int('HPS_VIEW_LNG', 2483000) / 1e6;
    final z0 = pawMap603Int('HPS_VIEW_Z0', 110);
    final z1 = pawMap603Int('HPS_VIEW_Z1', 140);
    final hold = pawMap603Int('HPS_VIEW_HOLD_MS', 6000);
    await Future<void>.delayed(const Duration(seconds: 3));
    for (var z = z0; z <= z1; z += 5) {
      await c.moveCamera(CameraUpdate.newLatLngZoom(LatLng(lat, lng), z / 10));
      pawMap603Log('V607 vue z=${z / 10}');
      await Future<void>.delayed(Duration(milliseconds: hold));
    }
    pawMap603Log('V607 FIN');
  }
}

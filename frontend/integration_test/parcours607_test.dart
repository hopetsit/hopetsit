// ignore_for_file: avoid_print
// 607 (PAM, 02/10/2026) — passe « aucun bug » de Daniel, écran du Mac
// verrouillé : parcours de l'APP RÉELLE (main de l'app, vrai serveur, session
// de test déjà ouverte — aucun mot de passe tapé) avec de VRAIS appuis
// (`tester.tap`). Chaque étape écrit « [CAP] nom » : l'hôte prend alors la
// capture (`xcrun simctl io … screenshot`, voir parcours607.sh) ; et
// « [RESULTAT] OK|KO … » pour le rapport.
//
//   flutter test integration_test/parcours607_test.dart -d <udid> \
//     --dart-define=HPS_STEPS=1,2,5,6
//
// Étapes : 1 menu + PawMap (barres, boutons du haut, zoom, ma position, bouton
// rose, réglage de la barre) · 2 Balade (peluches, arrêt) · 3 suivi d'un ami ·
// 4 chat → carte · 5 changement de rôle · 6 zooms (Bondy, Paris, Dallas, Europe).
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hopetsit/controllers/auth_controller.dart';
import 'package:hopetsit/controllers/theme_controller.dart';
import 'package:hopetsit/data/network/secure_token_store.dart';
import 'package:hopetsit/firebase_options.dart';
import 'package:hopetsit/helper/dependency_injection.dart';
import 'package:hopetsit/main.dart' as app;
import 'package:hopetsit/services/live_map_service.dart';
import 'package:hopetsit/services/push_notification_service.dart';
import 'package:hopetsit/services/socket_service.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/views/map/paw_map_screen.dart';
import 'package:hopetsit/views/map/widgets/pawmap_overlap607.dart';
import 'package:hopetsit/views/map/widgets/pawmap_discreet.dart';
import 'package:hopetsit/views/profile/widgets/my_profiles_card.dart';
import 'package:hopetsit/widgets/app_dialog_kit.dart';
import 'package:hopetsit/widgets/paw_tab_bar.dart';
import 'package:integration_test/integration_test.dart';

const String kSteps = String.fromEnvironment('HPS_STEPS', defaultValue: '1,2,5,6');
bool _step(int n) => kSteps.split(',').contains('$n');

final List<String> _results = <String>[];

void _ok(String what, bool cond, {String? detail}) {
  final line = '${cond ? 'OK ' : 'KO '} $what${detail == null ? '' : ' — $detail'}';
  _results.add(line);
  print('[RESULTAT] $line');
}

Future<void> _pump(WidgetTester t, int ms) => t.pump(Duration(milliseconds: ms));

/// Capture prise par l'hôte : on tient l'image 1,6 s.
Future<void> _cap(WidgetTester t, String name) async {
  await _pump(t, 400);
  print('[CAP] $name');
  for (var i = 0; i < 8; i++) {
    await _pump(t, 200);
  }
}

/// Position du simulateur posée par l'hôte (`xcrun simctl location`).
Future<void> _loc(WidgetTester t, double lat, double lng) async {
  print('[LOC] $lat,$lng');
  await _pump(t, 1500);
}

Future<bool> _waitFor(WidgetTester t, bool Function() cond, {int seconds = 20}) async {
  for (var i = 0; i < seconds * 4; i++) {
    if (cond()) return true;
    await _pump(t, 250);
  }
  return cond();
}

bool _has(Finder f) => f.evaluate().isNotEmpty;
Finder _key(String k) => find.byKey(ValueKey<String>(k));

Future<bool> _tapKey(WidgetTester t, String k, {int settleMs = 900}) async {
  final f = _key(k);
  if (!_has(f)) return false;
  await t.ensureVisible(f.first);
  await _pump(t, 200);
  await t.tap(f.first, warnIfMissed: false);
  await _pump(t, settleMs);
  return true;
}

bool _tabBarVisible() => _has(find.byType(PawTabBar));

GoogleMap? _map() {
  final f = find.byType(GoogleMap);
  if (!_has(f)) return null;
  return f.evaluate().first.widget as GoogleMap;
}

Set<Marker> _markers() => _map()?.markers ?? const <Marker>{};
int _members() => _markers()
    .where((m) => m.markerId.value.startsWith('nearby_') || m.markerId.value.startsWith('mcluster_'))
    .length;

dynamic _mapState(WidgetTester t) {
  final f = find.byType(PawMapScreen);
  if (!_has(f)) return null;
  return t.state(f.first);
}

Future<GoogleMapController?> _ctl(WidgetTester t) async {
  final st = _mapState(t);
  if (st == null) return null;
  return await (st as dynamic).activeMapCtlForTest() as GoogleMapController?;
}

Future<void> _goTab(WidgetTester t, int i) async {
  await t.tap(_key('paw_tab_$i').first, warnIfMissed: false);
  await _pump(t, 1500);
}

Future<void> _closeOverlays(WidgetTester t) async {
  for (var i = 0; i < 3; i++) {
    final nav = Get.key.currentState;
    if (nav != null && nav.canPop()) {
      nav.pop();
      await _pump(t, 700);
    }
  }
}

/// Mesure sur la carte affichée : aucune pastille de groupe ne recouvre
/// « Moi » (centres en pixels écran au zoom courant).
Future<String> _meOverlap(WidgetTester t) async {
  final c = await _ctl(t);
  if (c == null) return 'pas de carte';
  final z = await c.getZoomLevel();
  final ms = _markers();
  final me = ms.where((m) => m.markerId.value == 'me');
  if (me.isEmpty) return 'pas de Moi (z ${z.toStringAsFixed(1)})';
  final mp = pawMercatorPx(me.first.position.latitude, me.first.position.longitude, z);
  var worst = 9999.0;
  String? who;
  for (final m in ms) {
    final id = m.markerId.value;
    if (!(id.startsWith('mcluster_') || id.startsWith('nearby_'))) continue;
    final p = pawMercatorPx(m.position.latitude, m.position.longitude, z);
    final d = (p - mp).distance;
    if (d < worst) {
      worst = d;
      who = id;
    }
  }
  return 'z ${z.toStringAsFixed(1)} : rond le plus proche de Moi à ${worst.toStringAsFixed(0)} px ($who)';
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('parcours 607 (étapes $kSteps)', (t) async {
    PushNotificationService.skipInitForIntegrationTests = true;
    await GetStorage.init();
    await dotenv.load(fileName: '.env');
    await SecureTokenStore.instance.migrateFromLegacyIfNeeded();
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    } catch (e) {
      print('[T] Firebase : $e');
    }
    setupDependencies();
    Get.put(ThemeController(), permanent: true);
    FlutterError.onError = (d) {
      final s = d.exceptionAsString();
      // Les erreurs d'images réseau (photos de membres) ne sont pas des bugs de l'app.
      if (s.contains('HTTP request failed') || s.contains('NetworkImageLoadException')) return;
      print('[ERREUR] FLUTTER ${s.split('\n').first}');
      _results.add('ERREUR FLUTTER : ${s.split('\n').first}');
    };
    // Guides de premier lancement : jamais par-dessus les captures.
    GetStorage().write('pawmap_intro_seen_count', 99);
    GetStorage().write('pawmap_live_hint_seen', true);

    await t.pumpWidget(app.MyApp());
    final inApp = await _waitFor(t, _tabBarVisible, seconds: 25);
    _ok('session de test ouverte, menu du bas présent', inApp);
    if (!inApp) {
      await _cap(t, '00_pas_de_session');
      return;
    }
    final auth = Get.find<AuthController>();
    print('[T] rôle actif : ${auth.userRole.value}');
    await _loc(t, 48.8566, 2.3522); // autorise la position + Paris (hôte)
    await _pump(t, 2000);
    await _cap(t, '00_accueil_${auth.userRole.value}');

    // ── 1. Menu + PawMap ───────────────────────────────────────────────
    if (_step(1)) {
      final names = ['accueil', 'chat', 'pawmap', 'reservations', 'profil'];
      for (var i = 0; i < 5; i++) {
        await _goTab(t, i);
        _ok('onglet ${names[i]} : menu toujours visible', _tabBarVisible());
        await _cap(t, '01_onglet_${i}_${names[i]}');
      }
      await _goTab(t, 2);
      await _pump(t, 3000);
      // Barres repliables (flèches à la couleur du rôle).
      for (final side in ['rail', 'capsule']) {
        final hid = await _tapKey(t, 'pawmap_${side}_hide');
        final shown = _has(_key('pawmap_${side}_show'));
        _ok('barre $side repliée par sa flèche', hid && shown);
        await _cap(t, '02_${side}_repliee');
        final back = await _tapKey(t, 'pawmap_${side}_show');
        _ok('barre $side dépliée', back && _has(_key('pawmap_${side}_hide')));
      }
      // 4 boutons du haut.
      for (final b in ['legend', 'search', 'options']) {
        final ok = await _tapKey(t, 'pawmap_header_$b', settleMs: 1500);
        _ok('bouton du haut « $b » répond', ok);
        await _cap(t, '03_haut_$b');
        if (b == 'options') {
          await _tapKey(t, 'sheet_close');
        } else {
          await _closeOverlays(t);
        }
        await _pump(t, 800);
      }
      final refreshed = await _tapKey(t, 'pawmap_header_refresh', settleMs: 2500);
      _ok('bouton du haut « actualiser » répond', refreshed);
      await _cap(t, '03_haut_refresh');
      // Zoom + / − et ma position.
      final c = await _ctl(t);
      final z0 = await c!.getZoomLevel();
      await _tapKey(t, 'pawmap_btn_zoom_in', settleMs: 1500);
      final z1 = await c.getZoomLevel();
      await _tapKey(t, 'pawmap_btn_zoom_out', settleMs: 1500);
      await _tapKey(t, 'pawmap_btn_zoom_out', settleMs: 1500);
      final z2 = await c.getZoomLevel();
      _ok('zoom + puis − (${z0.toStringAsFixed(1)} → ${z1.toStringAsFixed(1)} → ${z2.toStringAsFixed(1)})',
          z1 > z0 && z2 < z1);
      await c.moveCamera(CameraUpdate.newLatLngZoom(const LatLng(48.90, 2.48), 12));
      await _pump(t, 1500);
      await _tapKey(t, 'pawmap_btn_locate', settleMs: 3500);
      final pos = await c.getVisibleRegion();
      final centre = LatLng((pos.northeast.latitude + pos.southwest.latitude) / 2,
          (pos.northeast.longitude + pos.southwest.longitude) / 2);
      final dist = (centre.latitude - 48.8566).abs() + (centre.longitude - 2.3522).abs();
      _ok('« ma position » recentre sur le simulateur (Paris)', dist < 0.05,
          detail: '${centre.latitude.toStringAsFixed(4)},${centre.longitude.toStringAsFixed(4)}');
      await _cap(t, '04_ma_position');
      // Bouton rose : masquer puis réafficher les membres.
      await c.moveCamera(CameraUpdate.newLatLngZoom(const LatLng(48.8566, 2.3522), 11.5));
      await _pump(t, 4000);
      final before = _members();
      await _tapKey(t, 'capsule_everyone', settleMs: 2500);
      final hidden = _members();
      await _cap(t, '05_membres_masques');
      await _tapKey(t, 'capsule_everyone', settleMs: 3500);
      final after = _members();
      _ok('bouton rose : membres $before → $hidden → $after', before > 0 && hidden == 0 && after > 0);
      await _cap(t, '05_membres_revenus');
      // Réglage de la barre de droite.
      final edit = await _tapKey(t, 'capsule_customize', settleMs: 1200);
      _ok('réglage de la barre ouvert', edit && _has(_key('capsule_fixed_note')));
      await _cap(t, '06_reglage_barre');
      await _closeOverlays(t);
      _ok('menu présent après le réglage', _tabBarVisible());
    }

    // ── 2. Balade ──────────────────────────────────────────────────────
    if (_step(2)) {
      await _goTab(t, 2);
      final live = Get.find<LiveMapService>();
      final c = await _ctl(t);
      if (live.broadcasting.value) {
        live.stopBroadcasting();
        await _pump(t, 2000);
      }
      await _loc(t, 48.85661, 2.35221);
      // Harnais de test : l'app n'est pas lancée par son main() (zone Sentry),
      // la socket s'ouvre tard ; on rejoue l'identification de la carte comme
      // le fait le crochet de connexion de l'app.
      live.attach();
      await _pump(t, 2000);
      try {
        final perm = await Geolocator.checkPermission();
        final svc = await Geolocator.isLocationServiceEnabled();
        final last = await Geolocator.getLastKnownPosition();
        print('[T] GPS permission=$perm service=$svc derniere=$last');
        final cur = await Geolocator.getCurrentPosition().timeout(const Duration(seconds: 10));
        print('[T] GPS actuelle=$cur');
      } catch (e) {
        print('[T] GPS erreur $e');
      }
      await _tapKey(t, 'pawmap_walk_btn', settleMs: 1500);
      // Le simulateur ne renvoie une position qu'au changement : on la bouge un peu.
      await _loc(t, 48.85665, 2.35225);
      final on = await _waitFor(t, () => live.broadcasting.value, seconds: 25);
      _ok('Balade démarrée par le bouton', on);
      final badge = await _waitFor(t, () => _has(_key('pawmap_walk_badge')), seconds: 10);
      _ok('drapeau « en balade » au-dessus du bouton', badge);
      // Harnais : la socket de carte n'est pas identifiée hors du main() de
      // l'app → on envoie la position par la voie HTTP de secours de l'app
      // (même route que LiveMapService._postHttp).
      try {
        await Get.find<ApiClient>().post('/friends/live-position',
            body: {'lat': 48.85665, 'lng': 2.35225, 'city': 'Paris', 'duration': 'until_stop'},
            requiresAuth: true);
      } catch (e) {
        print('[T] live-position HTTP $e');
      }
      await _cap(t, '10_balade_demarree');
      // Peluches pendant la Balade (le serveur ne les donne qu'en Balade).
      final gotPlush = await _waitFor(t,
          () => _markers().any((m) => m.markerId.value.startsWith('plush_')), seconds: 45);
      print('[T] peluches : ${(_mapState(t) as dynamic).plushDebugForTest()}');
      try {
        final ls = await Get.find<ApiClient>().get('/friends/live-state', requiresAuth: true);
        print('[T] serveur live-state : $ls ; socket=${Get.find<SocketService>().isConnected} statut=${live.liveStatus.value}');
      } catch (e) {
        print('[T] live-state erreur $e');
      }
      _ok('peluches posées sur la carte pendant la Balade', gotPlush,
          detail: '${_markers().where((m) => m.markerId.value.startsWith('plush_')).length}');
      if (gotPlush && c != null) {
        final p = _markers().firstWhere((m) => m.markerId.value.startsWith('plush_'));
        await c.moveCamera(CameraUpdate.newLatLngZoom(p.position, 15.5));
        await _pump(t, 2500);
        await _cap(t, '11_peluche_sur_la_carte');
      }
      // Arrêt : bouton Balade → feuille unique → Arrêter → confirmation.
      await _tapKey(t, 'pawmap_walk_btn', settleMs: 1500);
      final sheet = _has(_key('pawmap_live_sheet'));
      _ok('feuille unique « En direct » ouverte', sheet);
      await _cap(t, '12_feuille_direct');
      await _tapKey(t, 'live_sheet_stop_walk', settleMs: 1200);
      await _tapKey(t, 'pawmap_stop_live_confirm', settleMs: 2000);
      final off = await _waitFor(t, () => !live.broadcasting.value, seconds: 15);
      _ok('Balade arrêtée', off);
      await _pump(t, 2000);
      _ok('drapeau disparu, plus de peluches',
          !_has(_key('pawmap_walk_badge')) && !_markers().any((m) => m.markerId.value.startsWith('plush_')));
      await _cap(t, '13_balade_arretee');
      _ok('menu présent après la Balade', _tabBarVisible());
    }

    // ── 5. Changement de rôle ──────────────────────────────────────────
    if (_step(5)) {
      for (final role in ['sitter', 'walker', 'owner']) {
        await _goTab(t, 4);
        await _pump(t, 1500);
        final card = find.byType(MyProfilesCard);
        if (_has(card)) await t.ensureVisible(card.first);
        await _pump(t, 600);
        final row = find.descendant(of: card, matching: find.text('my_profile_$role'.tr));
        if (!_has(row)) {
          _ok('profil $role trouvé dans « Mes profils »', false);
          continue;
        }
        await t.tap(row.first, warnIfMissed: false);
        await _pump(t, 1200);
        final confirm = find.byType(AppDialogPrimaryButton);
        if (_has(confirm)) await t.tap(confirm.first, warnIfMissed: false);
        final switched = await _waitFor(t, () => auth.userRole.value == role && _tabBarVisible(), seconds: 30);
        _ok('passage en $role', switched);
        await _pump(t, 2500);
        await _cap(t, '50_${role}_accueil');
        if (role != 'owner') {
          final neo = _has(_key('neo607_home_card')) || _has(_key('neo607_home_pioneer'));
          _ok('carte « Ramène tes clients » ($role)', neo);
          if (await _tapKey(t, 'neo607_home_more', settleMs: 1500)) {
            _ok('feuille lien perso ouverte', _has(_key('neo607_sheet')));
            await _cap(t, '51_${role}_feuille_lien');
            await _tapKey(t, 'neo607_copy', settleMs: 800);
            await _closeOverlays(t);
          }
        }
        await _goTab(t, 2);
        await _pump(t, 2500);
        final fill = _key('pawmap_bar_tab_fill');
        if (_has(fill)) {
          final deco = (t.widget<Container>(fill.first).decoration as BoxDecoration?);
          final cols = (deco?.gradient as LinearGradient?)?.colors ?? const <Color>[];
          _ok('flèches à la couleur du menu ($role)',
              cols.isNotEmpty && cols.first == pawMenuPaletteFor(role).top);
        } else {
          _ok('flèches présentes ($role)', false);
        }
        await _cap(t, '52_${role}_pawmap_couleur_role');
      }
    }

    // ── 6. Zooms ───────────────────────────────────────────────────────
    if (_step(6)) {
      await _goTab(t, 2);
      await _pump(t, 2500);
      // Un vrai glissé : la caméra ne « suit » plus ma position (comme un
      // utilisateur qui déplace la carte avant de regarder ailleurs).
      final gm = find.byType(GoogleMap);
      if (_has(gm)) {
        await t.drag(gm.first, const Offset(0, -120), warnIfMissed: false);
        await _pump(t, 1500);
      }
      final c = await _ctl(t);
      final views = <(String, LatLng, List<double>)>[
        ('bondy', const LatLng(48.902, 2.483), [12, 12.5, 13]),
        ('paris', const LatLng(48.8566, 2.3522), [11, 12, 13, 14]),
        ('dallas', const LatLng(32.7767, -96.797), [9, 10, 11, 12]),
        ('europe', const LatLng(48.5, 8.0), [3, 4, 5]),
      ];
      for (final (name, at, zs) in views) {
        for (final z in zs) {
          await c!.moveCamera(CameraUpdate.newLatLngZoom(at, z));
          await _pump(t, 4500);
          final m = await _meOverlap(t);
          print('[T] $name z$z : $m');
          await _cap(t, '60_${name}_z${z.toString().replaceAll('.', '_')}');
        }
      }
      // Rien sous « Moi » (Paris, là où se trouve le simulateur).
      await c!.moveCamera(CameraUpdate.newLatLngZoom(const LatLng(48.8566, 2.3522), 12));
      await _pump(t, 4500);
      final m = await _meOverlap(t);
      final px = double.tryParse(RegExp(r'à (\d+) px').firstMatch(m)?.group(1) ?? '') ?? 0;
      _ok('rien sous « Moi » à Paris z12', px >= 52, detail: m);
    }

    print('[BILAN] ${_results.where((r) => r.startsWith('OK')).length} OK, '
        '${_results.where((r) => !r.startsWith('OK')).length} KO');
    for (final r in _results) {
      print('[BILAN] $r');
    }
  }, timeout: const Timeout(Duration(minutes: 25)));
}

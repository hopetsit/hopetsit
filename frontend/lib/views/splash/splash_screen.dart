import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hopetsit/views/guest/guest_landing_screen.dart';
import 'package:hopetsit/data/network/secure_token_store.dart';
import 'package:hopetsit/services/deep_link_service.dart';
import 'package:hopetsit/utils/storage_keys.dart';
import 'package:hopetsit/views/pet_owner/bottom_nav/bottom_nav_wrapper.dart';
import 'package:hopetsit/views/pet_sitter/bottom_wrapper/sitter_nav_wrapper.dart';
import 'package:hopetsit/views/pet_walker/bottom_wrapper/walker_nav_wrapper.dart';
import 'package:hopetsit/widgets/paw_tab_bar.dart';

/// v570 — ÉCRAN DE LANCEMENT (handoff hi-fi « Splash Screen.dc.html »).
///
/// ⚠️ Cet écran porte AUSSI la logique de redirection (session, rôle, liens en
/// attente) et sert de page « route inconnue » (`unknownRoute` dans main.dart).
/// Seul le RENDU a changé ; `_checkAuthentication()` est inchangée, on ajoute
/// uniquement une durée d'affichage minimale (~1,6 s) pour que l'animation
/// d'ouverture ne soit pas coupée au milieu.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // ── Séquence du handoff (ms) ────────────────────────────────────────────
  static const int _introMs = 2000; // couvre coussinet → doigts → titre → loader
  static const int _padDur = 700;
  static const int _toeDur = 650;
  static const List<int> _toeDelays = <int>[550, 650, 750, 850];
  static const int _titleStart = 1100;
  static const int _titleDur = 600;
  static const int _loaderStart = 1500;
  static const int _loaderDur = 500;
  static const int _floatStart = 1600;
  static const int _minDisplayMs = 1600;

  late final AnimationController _intro;
  late final AnimationController _float;
  late final AnimationController _spin;
  late final DateTime _openedAt;

  @override
  void initState() {
    super.initState();
    _openedAt = DateTime.now();

    // Immersive status bar (fond rouge-orangé → icônes claires).
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ));

    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _introMs),
    )..forward();
    // Flottement : 0 → −8 → 0 en 3,2 s (1,6 s aller + 1,6 s retour).
    _float = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();

    Future<void>.delayed(const Duration(milliseconds: _floatStart), () {
      if (mounted) _float.repeat(reverse: true);
    });

    _checkAuthentication();
  }

  @override
  void dispose() {
    _intro.dispose();
    _float.dispose();
    _spin.dispose();
    super.dispose();
  }

  /// Laisse l'animation d'ouverture se terminer (≈1,6 s) avant la redirection.
  /// Si le check a pris plus longtemps, on part immédiatement.
  Future<void> _holdForIntro() async {
    final int elapsed = DateTime.now().difference(_openedAt).inMilliseconds;
    if (elapsed < _minDisplayMs) {
      await Future<void>.delayed(
        Duration(milliseconds: _minDisplayMs - elapsed),
      );
    }
  }

  /// v23.1 part 44 — fix Bug H "login as owner opens walker".
  ///
  /// Root cause : splash read `StorageKeys.userRole` directly. When storage
  /// was contaminated by a previous session (e.g. walker test → kill app
  /// without clean logout → storage still says walker), splash navigated
  /// based on that stale value even though the JWT could say something else.
  /// The walker case fell into the `else` branch (Onboarding) because only
  /// owner/sitter were handled.
  ///
  /// Fix : decode the JWT directly and use ITS role claim as the source of
  /// truth (the backend signs the JWT, so its role cannot drift). Storage
  /// is only consulted as a fallback if the JWT is missing/expired/malformed.
  /// The 3 roles (owner/sitter/walker) all have a proper navigation branch.
  String? _decodeRoleFromJwt(String? token) {
    if (token == null || token.isEmpty) return null;
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      var payload = parts[1].replaceAll('-', '+').replaceAll('_', '/');
      while (payload.length % 4 != 0) {
        payload += '=';
      }
      final bytes = base64.decode(payload);
      final json = jsonDecode(utf8.decode(bytes));
      final role = (json is Map && json['role'] is String)
          ? (json['role'] as String).toLowerCase()
          : null;
      // v23.1.154 — Daniel : "faite que lapli ne se ferme que si on met
      // manuelment deconnecter". Avant : si le JWT etait expire, on
      // retournait null → l'app forcait un retour a Onboarding (logout
      // implicite). Maintenant on retourne le role meme si exp est
      // depasse — les API calls renverront un 401 et le user verra un
      // snackbar mais restera connecte tant qu'il ne fait pas Profil
      // > Deconnecter. Le user peut reouvrir l'app sans devoir re-login
      // a chaque expiration JWT silencieuse.
      // (Le check d'expiration est conserve en debug pour info, mais
      // non bloquant.)
      if (json is Map && json['exp'] is num) {
        final expSec = (json['exp'] as num).toInt();
        final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        if (expSec <= nowSec) {
          debugPrint(
            '[HOPETSIT] JWT exp passed ($expSec <= $nowSec) — '
            'keeping user logged in (will see 401 on next API call).',
          );
        }
      }
      return (role != null && role.isNotEmpty) ? role : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _checkAuthentication() async {
    // v23.1 part 240 — Daniel : "je veux que lapp reste ouverte chaque
    // fois je la met en back ground elle se ferme". ROOT CAUSE FOUND :
    // v23.1 part 125 a migré le JWT depuis GetStorage vers SecureTokenStore
    // (Keystore Android). Quand l'OS kill le process en background (Samsung,
    // Oppo battery optimization), au cold restart le splash lisait UNIQUEMENT
    // GetStorage et trouvait null → forçait Onboarding. L'user voyait l'app
    // "se fermer" alors que c'est juste le splash qui ne savait pas où
    // chercher.
    //
    // FIX : on lit SecureTokenStore en priorité (source of truth depuis v125),
    // fallback GetStorage pour les vieilles installs jamais migrées.
    // Aussi : on raccourcit le splash de 2000ms → 800ms pour que le retour
    // se sente plus instant.
    await Future.delayed(const Duration(milliseconds: 800));

    final storage = GetStorage();
    // v240 — Secure-first, GetStorage fallback (deux sources possibles).
    // tokenSync renvoie null si pas encore hydraté → on force readToken()
    // qui fait un read disque keystore explicite. C'est cet appel qui était
    // manquant : main.dart appelait migrateFromLegacyIfNeeded() AVANT runApp,
    // mais sur certains devices le keystore n'est pas encore disponible à
    // ce moment, donc _hydrated=false et tokenSync=null. readToken() retry
    // le read et hydrate le cache.
    String? token = SecureTokenStore.instance.tokenSync;
    if (token == null || token.isEmpty) {
      try {
        token = await SecureTokenStore.instance.readToken();
      } catch (_) {/* defensive */}
    }
    if (token == null || token.isEmpty) {
      token = SecureTokenStore.currentToken();
    }
    final storedRole = storage.read<String>(StorageKeys.userRole);
    final jwtRole = _decodeRoleFromJwt(token);

    debugPrint(
      '[HOPETSIT] ========== SPLASH SCREEN - CHECKING AUTH ==========',
    );
    debugPrint('[HOPETSIT] Token exists: ${token != null && token.isNotEmpty}');
    debugPrint('[HOPETSIT] JWT role: $jwtRole');
    debugPrint('[HOPETSIT] Storage role: $storedRole');

    if (token == null || token.isEmpty) {
      // v535 — SPEC ONBOARDING P1.1 : un utilisateur SANS compte atterrit sur
      // la DÉCOUVERTE (liste des gardiens/promeneurs en lecture seule), plus
      // sur le mur login/signup. Le mur ne réapparaît qu'au moment d'AGIR
      // (contacter, réserver) — cf. SignupWallSheet. C'est LE correctif de
      // l'entonnoir à ~2 % d'inscriptions.
      debugPrint('[HOPETSIT] No token found, navigating to GuestLanding');
      await _holdForIntro();
      Get.offAll(() => const GuestLandingScreen());
      return;
    }

    // JWT is the source of truth. If it cannot be decoded (malformed) OR
    // the token is expired, treat as logged out.
    if (jwtRole == null) {
      debugPrint(
        '[HOPETSIT] JWT invalid/expired, clearing auth + Onboarding',
      );
      storage.remove(StorageKeys.authToken);
      storage.remove(StorageKeys.userRole);
      await _holdForIntro();
      Get.offAll(() => const GuestLandingScreen());
      return;
    }

    // Storage drift recovery : if storage disagrees with JWT, re-write
    // storage so AuthController.onInit reads the correct value next time.
    if (storedRole != jwtRole) {
      debugPrint(
        '[HOPETSIT] ⚠️ Role drift (storage=$storedRole, jwt=$jwtRole). Forcing JWT role.',
      );
      storage.write(StorageKeys.userRole, jwtRole);
    }

    await _holdForIntro();

    switch (jwtRole) {
      case 'owner':
        debugPrint('[HOPETSIT] Navigating to Owner Home');
        Get.offAll(() => const BottomNavWrapper());
        break;
      case 'sitter':
        debugPrint('[HOPETSIT] Navigating to Sitter Home');
        Get.offAll(() => const SitterNavWrapper());
        break;
      case 'walker':
        debugPrint('[HOPETSIT] Navigating to Walker Home');
        Get.offAll(() => const WalkerNavWrapper());
        break;
      default:
        debugPrint(
          '[HOPETSIT] Unknown JWT role "$jwtRole" → Onboarding',
        );
        Get.offAll(() => const GuestLandingScreen());
    }

    // v23.1 part 146 — fix écran noir au boot via deep link.
    // Le DeepLinkService a pu recevoir un Intent VIEW AVANT que
    // GetMaterialApp soit monté (cas où l'app est lancée par un lien
    // hopetsit.com depuis un email/Chrome/etc.). Les URIs reçues trop
    // tôt sont bufferisées dans `_pendingUris`. Maintenant que la nav
    // GetX est prête (Get.offAll vient de monter le bon écran), on
    // rejoue les URIs en attente : `_openPayment` peut push par-dessus
    // BottomNavWrapper, `/chat` peut routerNamed, etc.
    // Wrappé en addPostFrameCallback pour laisser le frame se peindre
    // avant la nav (évite tout flicker visuel).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DeepLinkService.instance.flushPending();
    });
  }

  /// Progression d'une phase de la séquence, en ms depuis l'affichage.
  double _phase(double ms, int start, int dur, Curve curve) =>
      curve.transform(((ms - start) / dur).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          // linear-gradient(165deg,#F26A46 0%,#DD4430 45%,#C7311F 100%)
          gradient: LinearGradient(
            begin: Alignment(-0.26, -0.97),
            end: Alignment(0.26, 0.97),
            colors: <Color>[
              Color(0xFFF26A46),
              Color(0xFFDD4430),
              Color(0xFFC7311F),
            ],
            stops: <double>[0.0, 0.45, 1.0],
          ),
        ),
        child: Stack(
          children: <Widget>[
            // ── Patte 210×210, centre vertical ≈ 355 ──────────────────────
            Positioned(
              top: 250.h,
              left: 0,
              right: 0,
              child: Center(
                child: AnimatedBuilder(
                  animation: Listenable.merge(<Listenable>[_intro, _float]),
                  builder: (BuildContext context, Widget? _) {
                    final double ms = _intro.value * _introMs;
                    final double pad = _phase(ms, 0, _padDur, kPawBounce);
                    final double padOpacity =
                        ((ms / _padDur).clamp(0.0, 1.0)).toDouble();
                    final double floatDy =
                        -8 * Curves.easeInOut.transform(_float.value);
                    final List<double> toeP = <double>[];
                    final List<double> toeO = <double>[];
                    for (int i = 0; i < 4; i++) {
                      toeP.add(_phase(ms, _toeDelays[i], _toeDur, kPawBounce));
                      toeO.add(
                        ((ms - _toeDelays[i]) / _toeDur).clamp(0.0, 1.0),
                      );
                    }
                    return Opacity(
                      opacity: padOpacity,
                      child: Transform.scale(
                        scale: 0.5 + 0.5 * pad,
                        child: Transform.translate(
                          offset: Offset(0, floatDy),
                          child: PawGlyph(
                            spec: kPawGlyphSplash,
                            size: 210.w,
                            toeProgress: toeP,
                            toeOpacity: toeO,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // ── Titre + sous-titre ────────────────────────────────────────
            Positioned(
              top: 500.h,
              left: 0,
              right: 0,
              child: AnimatedBuilder(
                animation: _intro,
                builder: (BuildContext context, Widget? child) {
                  final double t = _phase(
                    _intro.value * _introMs,
                    _titleStart,
                    _titleDur,
                    Curves.easeOut,
                  );
                  return Opacity(
                    opacity: t,
                    child: Transform.translate(
                      offset: Offset(0, 14 * (1 - t)),
                      child: child,
                    ),
                  );
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      // Marque : jamais traduite.
                      'HoPetSit',
                      style: GoogleFonts.manrope(
                        fontSize: 44.sp,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.88, // -.02em
                        color: Colors.white,
                        height: 1.0,
                      ),
                    ),
                    SizedBox(height: 10.h),
                    Text(
                      'Home Pets Sitting',
                      style: GoogleFonts.manrope(
                        fontSize: 17.sp,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.02, // .06em
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Anneau de chargement ──────────────────────────────────────
            Positioned(
              bottom: 110.h,
              left: 0,
              right: 0,
              child: Center(
                child: AnimatedBuilder(
                  animation: _intro,
                  builder: (BuildContext context, Widget? child) {
                    final double t = _phase(
                      _intro.value * _introMs,
                      _loaderStart,
                      _loaderDur,
                      Curves.easeOut,
                    );
                    return Opacity(
                      opacity: t,
                      child: Transform.translate(
                        offset: Offset(0, 14 * (1 - t)),
                        child: child,
                      ),
                    );
                  },
                  child: RotationTransition(
                    turns: _spin,
                    child: CustomPaint(
                      size: const Size(34, 34),
                      painter: _RingPainter(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Anneau 34 px : bordure 3 px blanche à 30 %, segment haut blanc plein.
class _RingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final Rect inner = rect.deflate(1.5);
    final Paint base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = Colors.white.withValues(alpha: 0.3);
    canvas.drawArc(inner, 0, math.pi * 2, false, base);
    final Paint head = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = Colors.white;
    canvas.drawArc(inner, -math.pi * 3 / 4, math.pi / 2, false, head);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) => false;
}

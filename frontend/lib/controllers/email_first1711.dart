// 1711 (NEO, ordre de Daniel du 17/11/2026) — inscription « E-MAIL D'ABORD ».
//
// Mesure de BOB (45 j) : 313 inscrits e-mail + mot de passe → 97 vérifiés
// (~30 %) ; Google / Apple = 100 %. L'app créait le compte PUIS demandait le
// code. Désormais : e-mail → code à 6 chiffres → le reste de l'assistant, et
// AUCUN compte n'est créé avant le bon code.
//
// Cette classe porte tout l'état de la « porte » posée devant l'assistant :
//   · `email`  : saisie de l'adresse (POST /auth/email-first/send) ;
//   · `code`   : saisie du code (POST /auth/email-first/check → `emailProof`) ;
//   · `done`   : adresse confirmée, la preuve part avec POST /auth/signup ;
//   · `legacy` : le serveur ne connaît pas encore la route (404) → parcours
//                d'avant (compte puis code), sans rien casser.
//
// L'adresse en attente et la preuve (valable 60 min) sont mémorisées : si la
// personne quitte l'app pour lire son e-mail — même si le téléphone ferme
// l'app entre-temps — elle retrouve l'écran du code avec son adresse.
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/localization/app_translations.dart';
import 'package:hopetsit/repositories/auth_repository.dart';
import 'package:hopetsit/services/firebase_analytics_service.dart';

enum EmailGatePhase { email, code, done, legacy }

class EmailFirst1711 {
  EmailFirst1711({
    required AuthRepository repo,
    required this.emailController,
  }) : _repo = repo;

  static const String storageKey = 'email_first_1711';
  static const int codeLength = 6;
  static const Duration _pendingTtl = Duration(minutes: 60);
  static final RegExp _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  final AuthRepository _repo;

  /// Champ e-mail de l'assistant (celui de `SignUpController`).
  final TextEditingController emailController;
  final TextEditingController codeController = TextEditingController();

  final Rx<EmailGatePhase> phase = EmailGatePhase.email.obs;
  final RxBool busy = false.obs;

  /// Message d'erreur DÉJÀ traduit ('' = aucun).
  final RxString error = ''.obs;

  /// Message d'information déjà traduit (ex. « Nouveau code envoyé »).
  final RxString info = ''.obs;

  /// Adresse corrigée proposée par le serveur (« …@gmail.con » → « .com »).
  final RxString suggestion = ''.obs;

  /// Un compte vérifié existe déjà pour l'adresse tapée.
  final RxBool exists = false.obs;

  /// Secondes avant de pouvoir redemander un code (0 = possible).
  final RxInt resendIn = 0.obs;

  /// Adresse à laquelle le code a été envoyé.
  final RxString pendingEmail = ''.obs;

  String _proof = '';
  String _proofEmail = '';
  DateTime? _proofExp;
  DateTime? _sentAt;
  DateTime? _resendAt;
  Timer? _timer;

  // ── lecture ────────────────────────────────────────────────────────────────

  /// Vrai tant que la porte doit être franchie (l'assistant ne s'affiche pas).
  bool get isGate =>
      phase.value == EmailGatePhase.email || phase.value == EmailGatePhase.code;

  /// Preuve encore valable (marge de 30 s : le temps d'atteindre le serveur).
  bool get hasValidProof =>
      _proof.isNotEmpty &&
      _proofExp != null &&
      DateTime.now().isBefore(_proofExp!.subtract(const Duration(seconds: 30)));

  /// Preuve à joindre à l'inscription (null si absente ou expirée).
  String? get proof => hasValidProof ? _proof : null;

  /// Adresse confirmée par le code ('' si aucune).
  String get confirmedEmail => hasValidProof ? _proofEmail : '';

  bool hasProofFor(String email) =>
      hasValidProof && _proofEmail == _norm(email);

  static String _norm(String v) => v.trim().toLowerCase();

  String _t(String key, [Map<String, String> params = const {}]) {
    var s = key.tr;
    params.forEach((k, v) => s = s.replaceAll('{$k}', v));
    return s;
  }

  void _funnel(String name) {
    try {
      FirebaseAnalyticsService.instance.logFunnel(name);
    } catch (_) {/* mesure jamais bloquante */}
  }

  // ── mémoire (retour dans l'app) ────────────────────────────────────────────

  /// Reprend là où la personne s'était arrêtée (appelé à l'ouverture de
  /// l'assistant). Preuve valable → adresse confirmée ; code envoyé il y a
  /// moins de 60 min → écran du code.
  void restore() {
    try {
      final raw = GetStorage().read(storageKey);
      if (raw is! Map) return;
      final email = _norm((raw['email'] ?? '').toString());
      if (email.isEmpty || !_emailRe.hasMatch(email)) return;
      final now = DateTime.now();
      final proof = (raw['proof'] ?? '').toString();
      final exp = _date(raw['proofExp']);
      if (proof.isNotEmpty && exp != null && now.isBefore(exp)) {
        _proof = proof;
        _proofEmail = email;
        _proofExp = exp;
        if (hasValidProof) {
          emailController.text = email;
          pendingEmail.value = email;
          phase.value = EmailGatePhase.done;
          return;
        }
      }
      final sentAt = _date(raw['sentAt']);
      if (sentAt != null && now.difference(sentAt) < _pendingTtl) {
        _sentAt = sentAt;
        _resendAt = _date(raw['resendAt']);
        emailController.text = email;
        pendingEmail.value = email;
        phase.value = EmailGatePhase.code;
        _startCountdown();
        return;
      }
      _forget();
    } catch (_) {/* mémoire illisible : on repart de l'adresse */}
  }

  static DateTime? _date(dynamic ms) =>
      ms is int ? DateTime.fromMillisecondsSinceEpoch(ms) : null;

  void _persist() {
    try {
      final email = pendingEmail.value;
      if (email.isEmpty) return;
      GetStorage().write(storageKey, <String, dynamic>{
        'email': email,
        if (_sentAt != null) 'sentAt': _sentAt!.millisecondsSinceEpoch,
        if (_resendAt != null) 'resendAt': _resendAt!.millisecondsSinceEpoch,
        if (_proof.isNotEmpty && _proofEmail == email) 'proof': _proof,
        if (_proofExp != null && _proofEmail == email)
          'proofExp': _proofExp!.millisecondsSinceEpoch,
      });
    } catch (_) {/* non bloquant */}
  }

  void _forget() {
    try {
      GetStorage().remove(storageKey);
    } catch (_) {/* non bloquant */}
  }

  // ── compte à rebours « Renvoyer dans 58 s » ────────────────────────────────

  void _startCountdown() {
    _timer?.cancel();
    _tick();
    if (resendIn.value <= 0) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final at = _resendAt;
    final left = at == null
        ? 0
        : (at.difference(DateTime.now()).inMilliseconds / 1000).ceil();
    resendIn.value = left > 0 ? left : 0;
    if (resendIn.value <= 0) {
      _timer?.cancel();
      _timer = null;
    }
  }

  // ── étape « Ton e-mail » ───────────────────────────────────────────────────

  /// La personne retouche l'adresse : les messages liés à l'ancienne saisie
  /// (suggestion, compte existant, erreur) disparaissent.
  void onEmailEdited() {
    if (suggestion.value.isNotEmpty) suggestion.value = '';
    if (exists.value) exists.value = false;
    if (error.value.isNotEmpty) error.value = '';
  }

  /// Bouton « Recevoir mon code » (ou « Continuer » si l'adresse est déjà
  /// confirmée).
  Future<void> submitEmail() async {
    if (busy.value) return;
    final email = _norm(emailController.text);
    error.value = '';
    info.value = '';
    suggestion.value = '';
    exists.value = false;
    if (!_emailRe.hasMatch(email) || email.length > 120) {
      error.value = _t('ef_err_email_invalid');
      return;
    }
    if (hasProofFor(email)) {
      emailController.text = email;
      phase.value = EmailGatePhase.done;
      return;
    }
    await _send(email, fromCodeStep: false);
  }

  /// Tap sur la suggestion « Tu voulais dire … ? » : corrige et envoie.
  Future<void> applySuggestion() async {
    final s = _norm(suggestion.value);
    if (s.isEmpty) return;
    emailController.text = s;
    await submitEmail();
  }

  /// « Renvoyer le code » (écran du code).
  Future<void> resend() async {
    if (busy.value || resendIn.value > 0 || pendingEmail.value.isEmpty) return;
    error.value = '';
    info.value = '';
    await _send(pendingEmail.value, fromCodeStep: true);
  }

  Future<void> _send(String email, {required bool fromCodeStep}) async {
    busy.value = true;
    try {
      final res = await _repo.emailFirstSend(
        email: email,
        lang: LocalizationService.getCurrentLanguageCode(),
      );
      final sug = _norm((res['suggestion'] ?? '').toString());
      if (sug.isNotEmpty && res['ok'] != true) {
        suggestion.value = sug;
        if (fromCodeStep) phase.value = EmailGatePhase.email;
        return;
      }
      if (res['exists'] == true && res['ok'] != true) {
        exists.value = true;
        if (fromCodeStep) phase.value = EmailGatePhase.email;
        return;
      }
      final retry = res['retryAfter'];
      _enterCode(email, retry is num ? retry.toInt() : 60);
      if (fromCodeStep) info.value = _t('ef_code_resent');
      _funnel(fromCodeStep ? 'signup_email_code_resent' : 'signup_email_code_sent');
    } on ApiException catch (e) {
      final code = e.details is Map ? (e.details as Map)['code'] : null;
      if (e.statusCode == 404) {
        // Serveur pas encore à jour : parcours d'avant (compte puis code).
        phase.value = EmailGatePhase.legacy;
        _funnel('signup_email_first_fallback');
        return;
      }
      if (e.statusCode == 429 && code == 'RESEND_TOO_SOON') {
        // Un code est déjà parti il y a moins de 60 s : on montre l'écran du
        // code avec le temps restant.
        final ra = e.details is Map ? (e.details as Map)['retryAfter'] : null;
        _enterCode(email, ra is num ? ra.toInt() : 60, countAsSent: false);
        return;
      }
      if (e.statusCode == 429) {
        error.value =
            _t(code == 'TOO_MANY' ? 'ef_err_too_many' : 'ef_err_wait');
      } else if (e.statusCode == 403) {
        error.value = _t('ef_err_test_account');
      } else if (e.statusCode == 400) {
        error.value = _t('ef_err_email_invalid');
      } else if (e.statusCode == 502) {
        error.value = _t('ef_err_not_sent');
      } else {
        error.value = _t('common_error_generic');
      }
    } on NetworkUnreachableException {
      error.value = _t('common_error_no_network');
    } on ApiTimeoutException {
      error.value = _t('common_error_no_network');
    } catch (_) {
      error.value = _t('common_error_generic');
    } finally {
      busy.value = false;
    }
  }

  void _enterCode(String email, int retryAfter, {bool countAsSent = true}) {
    final now = DateTime.now();
    if (pendingEmail.value != email) codeController.clear();
    pendingEmail.value = email;
    emailController.text = email;
    if (countAsSent || _sentAt == null) _sentAt = now;
    _resendAt = now.add(Duration(seconds: retryAfter.clamp(0, 3600)));
    // Une nouvelle adresse annule la preuve de l'ancienne.
    if (_proofEmail != email) {
      _proof = '';
      _proofEmail = '';
      _proofExp = null;
    }
    error.value = '';
    phase.value = EmailGatePhase.code;
    _persist();
    _startCountdown();
  }

  // ── étape « Code reçu par e-mail » ─────────────────────────────────────────

  /// La personne retape un code : le message du code précédent disparaît
  /// (les cases vidées après un mauvais code ne l'effacent pas).
  void onCodeEdited(String value) {
    if (value.isEmpty) return;
    if (error.value.isNotEmpty) error.value = '';
    if (info.value.isNotEmpty) info.value = '';
  }

  /// Vérifie le code (appelé à la 6e case, au collage, ou par le bouton).
  /// Renvoie vrai si l'adresse est confirmée.
  Future<bool> submitCode([String? typed]) async {
    if (busy.value) return false;
    final code = (typed ?? codeController.text).replaceAll(RegExp(r'\D'), '');
    info.value = '';
    if (code.length != codeLength) {
      error.value = _t('ef_err_code_len');
      return false;
    }
    final email = pendingEmail.value;
    if (email.isEmpty) {
      phase.value = EmailGatePhase.email;
      return false;
    }
    error.value = '';
    busy.value = true;
    try {
      final res = await _repo.emailFirstCheck(email: email, code: code);
      final p = (res['emailProof'] ?? '').toString();
      if (p.isEmpty) {
        error.value = _t('common_error_generic');
        return false;
      }
      final ttl = res['expiresIn'];
      _proof = p;
      _proofEmail = email;
      _proofExp = DateTime.now()
          .add(Duration(seconds: ttl is num ? ttl.toInt() : 3600));
      emailController.text = email;
      codeController.clear();
      _timer?.cancel();
      _timer = null;
      phase.value = EmailGatePhase.done;
      _persist();
      _funnel('signup_email_code_ok');
      return true;
    } on ApiException catch (e) {
      final d = e.details is Map ? e.details as Map : const {};
      final c = d['code'];
      if (e.statusCode == 404) {
        phase.value = EmailGatePhase.legacy;
        _funnel('signup_email_first_fallback');
      } else if (e.statusCode == 400 && c == 'CODE_INVALID') {
        final left = d['left'];
        codeController.clear();
        if (left is num && left <= 0) {
          error.value = _t('ef_err_blocked');
        } else if (left is num && left.toInt() == 1) {
          error.value = _t('ef_err_code_wrong_one');
        } else if (left is num) {
          error.value =
              _t('ef_err_code_wrong', {'n': left.toInt().toString()});
        } else {
          error.value = _t('ef_err_code_wrong_plain');
        }
        _funnel('signup_email_code_wrong');
      } else if (e.statusCode == 429 && c == 'TOO_MANY_TRIES') {
        codeController.clear();
        error.value = _t('ef_err_blocked');
      } else if (e.statusCode == 429) {
        error.value = _t('ef_err_wait');
      } else if (e.statusCode == 410) {
        codeController.clear();
        error.value = _t('ef_err_code_expired');
      } else {
        error.value = _t('common_error_generic');
      }
      return false;
    } on NetworkUnreachableException {
      error.value = _t('common_error_no_network');
      return false;
    } on ApiTimeoutException {
      error.value = _t('common_error_no_network');
      return false;
    } catch (_) {
      error.value = _t('common_error_generic');
      return false;
    } finally {
      busy.value = false;
    }
  }

  /// Extrait un code à 6 chiffres d'un texte collé (« 123 456 », « Ton code :
  /// 123456 »…). '' si aucun.
  static String extractCode(String text) {
    final m = RegExp(r'(?<!\d)(\d{3})[\s\-]?(\d{3})(?!\d)').firstMatch(text);
    if (m != null) return '${m.group(1)}${m.group(2)}';
    return '';
  }

  /// Bouton « Coller le code » : lit le presse-papiers, remplit les 6 cases
  /// et vérifie.
  Future<void> pasteFromClipboard() async {
    if (busy.value) return;
    String text = '';
    try {
      text = (await Clipboard.getData(Clipboard.kTextPlain))?.text ?? '';
    } catch (_) {/* presse-papiers indisponible */}
    final code = extractCode(text);
    if (code.isEmpty) {
      error.value = _t('ef_err_paste_empty');
      return;
    }
    codeController.text = code;
    await submitCode(code);
  }

  /// « Changer d'adresse » / retour arrière depuis l'écran du code.
  void changeEmail() {
    error.value = '';
    info.value = '';
    codeController.clear();
    phase.value = EmailGatePhase.email;
  }

  /// Retour arrière depuis la 1re étape de l'assistant : on revient à
  /// l'adresse (confirmée — « Continuer » ne renvoie pas de code).
  void backToEmail() {
    error.value = '';
    info.value = '';
    phase.value = EmailGatePhase.email;
  }

  /// Le serveur a refusé la preuve (expirée) : on redemande un code.
  void invalidateProof() {
    _proof = '';
    _proofEmail = '';
    _proofExp = null;
    _sentAt = null;
    _forget();
    info.value = '';
    error.value = _t('ef_err_proof_expired');
    phase.value = EmailGatePhase.email;
  }

  /// Compte créé : plus rien à garder.
  void clear() {
    _timer?.cancel();
    _timer = null;
    _proof = '';
    _proofEmail = '';
    _proofExp = null;
    _sentAt = null;
    _resendAt = null;
    resendIn.value = 0;
    pendingEmail.value = '';
    error.value = '';
    info.value = '';
    suggestion.value = '';
    exists.value = false;
    codeController.clear();
    phase.value = EmailGatePhase.email;
    _forget();
  }

  /// Tests : le délai de renvoi est écoulé (comme après 60 s hors de l'app).
  @visibleForTesting
  void debugExpireCountdown() {
    _resendAt = DateTime.now().subtract(const Duration(seconds: 1));
    _tick();
  }

  /// Tests : la preuve a dépassé ses 60 minutes.
  @visibleForTesting
  void debugExpireProof() {
    _proofExp = DateTime.now().subtract(const Duration(seconds: 1));
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}

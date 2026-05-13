// v23.1 part 125 — Phase 2 audit C4.
// Abstraction sur flutter_secure_storage pour le JWT et autres secrets
// sensibles. Au démarrage, on migre depuis GetStorage (où les anciens
// builds stockaient le token en clair) vers le keystore Android /
// Keychain iOS. La clé n'est pas effaçable par l'utilisateur ni par
// un backup Auto Backup (cf data_extraction_rules.xml côté manifest).

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_storage/get_storage.dart';

import '../../utils/logger.dart';
import '../../utils/storage_keys.dart';

class SecureTokenStore {
  SecureTokenStore._();
  static final SecureTokenStore instance = SecureTokenStore._();

  static const _aOptions = AndroidOptions(
    encryptedSharedPreferences: true,
    // EncryptedSharedPreferences utilise AES-256-GCM avec une clé
    // dérivée par le KeyStore Android. Pas d'export hors device.
  );
  static const _iOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
    // Pas synchronisé via iCloud Keychain — token strictement local.
  );

  final FlutterSecureStorage _secure = const FlutterSecureStorage(
    aOptions: _aOptions,
    iOptions: _iOptions,
  );

  /// Cache mémoire pour éviter un read disque sur chaque appel api_client.
  /// Hydraté lors de [migrateFromLegacyIfNeeded] et invalidé par [clear].
  String? _cachedToken;
  bool _hydrated = false;

  /// Migration one-shot : déplace le token depuis GetStorage vers secure
  /// storage si présent. À appeler une fois au boot, après GetStorage.init.
  /// Idempotent — peut être appelée plusieurs fois sans effet de bord.
  Future<void> migrateFromLegacyIfNeeded() async {
    try {
      // 1) Si déjà un token dans le secure store, on s'en sert et on
      //    purge le legacy au cas où il traînerait encore.
      final secureToken = await _secure.read(key: StorageKeys.authToken);
      if (secureToken != null && secureToken.isNotEmpty) {
        _cachedToken = secureToken;
        _hydrated = true;
        _purgeLegacy();
        return;
      }

      // 2) Sinon, on tente de lire dans GetStorage (legacy).
      final legacy = GetStorage().read<String>(StorageKeys.authToken);
      if (legacy != null && legacy.isNotEmpty) {
        await _secure.write(key: StorageKeys.authToken, value: legacy);
        _cachedToken = legacy;
        _purgeLegacy();
        if (kDebugMode) {
          AppLogger.logInfo(
            'SecureTokenStore: migrated JWT from GetStorage to secure storage',
          );
        }
      }
      _hydrated = true;
    } catch (e, st) {
      // Lecture secure échoue parfois sur Android < 6 (rare) — on tolère.
      AppLogger.logError(
        'SecureTokenStore.migrateFromLegacyIfNeeded failed',
        error: e,
        stackTrace: st,
      );
      _hydrated = true;
    }
  }

  /// Synchrone, optimisé pour les appels api_client. Renvoie null si
  /// pas (encore) hydraté.
  String? get tokenSync => _hydrated ? _cachedToken : null;

  /// Lecture asynchrone, force une lecture disque si pas hydraté.
  Future<String?> readToken() async {
    if (_hydrated) return _cachedToken;
    final v = await _secure.read(key: StorageKeys.authToken);
    _cachedToken = v;
    _hydrated = true;
    return v;
  }

  Future<void> writeToken(String token) async {
    await _secure.write(key: StorageKeys.authToken, value: token);
    _cachedToken = token;
    _hydrated = true;
    _purgeLegacy();
  }

  Future<void> clear() async {
    await _secure.delete(key: StorageKeys.authToken);
    _cachedToken = null;
    _purgeLegacy();
  }

  /// Vire le token legacy de GetStorage. Best-effort.
  void _purgeLegacy() {
    try {
      GetStorage().remove(StorageKeys.authToken);
    } catch (_) {/* ignore */}
  }
}

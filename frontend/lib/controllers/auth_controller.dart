import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/data/network/secure_token_store.dart';
import 'package:hopetsit/repositories/auth_repository.dart';
// v23.1 part 137 — import nécessaire pour rediriger les new users Google
// vers la page SignUpAs quand le backend répond 400 ROLE_REQUIRED.
import 'package:hopetsit/views/auth/sign_up_as.dart';
import 'package:hopetsit/repositories/user_repository.dart';
import 'package:hopetsit/services/firebase_analytics_service.dart';
import 'package:hopetsit/services/meta_events_service.dart';
import 'package:hopetsit/services/push_notification_service.dart';
import 'package:hopetsit/services/socket_service.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/localization/app_translations.dart';
import 'package:hopetsit/controllers/sitter_chat_controller.dart';
import 'package:hopetsit/utils/storage_keys.dart';
import 'package:hopetsit/utils/app_constants.dart';
import 'package:flutter/scheduler.dart';
import 'package:hopetsit/controllers/home_controller.dart';
import 'package:hopetsit/controllers/posts_controller.dart';
import 'package:hopetsit/controllers/profile_controller.dart';
import 'package:hopetsit/controllers/bookings_controller.dart';
import 'package:hopetsit/controllers/sitter_bookings_controller.dart';
import 'package:hopetsit/controllers/walker_bookings_controller.dart';
import 'package:hopetsit/controllers/notifications_controller.dart';
import 'package:hopetsit/controllers/unified_notification_controller.dart';
import 'package:hopetsit/controllers/sitter_profile_controller.dart';
import 'package:hopetsit/controllers/user_controller.dart';
// v23.1 — controllers à clear au logout pour éviter les fuites de cache
// entre comptes (Daniel se reconnectait et voyait les anciennes données).
import 'package:hopetsit/controllers/applications_controller.dart';
import 'package:hopetsit/controllers/chat_controller.dart';
import 'package:hopetsit/controllers/choose_service_controller.dart';
import 'package:hopetsit/repositories/sitter_repository.dart';
import 'package:hopetsit/views/auth/login_screen.dart';
import 'package:hopetsit/views/auth/otp_verification_screen.dart';
import 'package:hopetsit/views/auth/choose_service_screen.dart';
import 'package:hopetsit/views/pet_owner/bottom_nav/bottom_nav_wrapper.dart';
import 'package:hopetsit/views/pet_sitter/bottom_wrapper/sitter_nav_wrapper.dart';
import 'package:hopetsit/views/pet_walker/bottom_wrapper/walker_nav_wrapper.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:hopetsit/controllers/otp_verification_controller.dart';
import 'package:hopetsit/widgets/paypal_email_dialog.dart';
import 'package:crypto/crypto.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Controller handling user authentication flows.
class AuthController extends GetxController {
  AuthController(
    this._authRepository,
    this._storage, [
    UserRepository? userRepository,
  ]) : _userRepository = userRepository;

  final AuthRepository _authRepository;
  final GetStorage _storage;
  final UserRepository? _userRepository;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  // v23.1 part 200 — Daniel : "le bouton Google et Apple chargent en même
  // temps quand on clique sur un seul". Avant : un seul flag partagé
  // isSocialLoginLoading mettait le spinner sur LES DEUX boutons quand
  // l'utilisateur cliquait sur Google (ou Apple). Maintenant : 2 flags
  // indépendants. Le getter isSocialLoginLoading reste pour la rétrocompat
  // avec sign_up_screen.dart + onboarding_screen.dart (qui veulent juste
  // savoir si UN des deux est en cours, pour bloquer toute interaction).
  final RxBool isGoogleLoginLoading = false.obs;
  final RxBool isAppleLoginLoading = false.obs;
  bool get isSocialLoginLoadingValue =>
      isGoogleLoginLoading.value || isAppleLoginLoading.value;
  // Backward-compat shim : sign_up_screen + onboarding_screen lisent
  // `.isSocialLoginLoading.value`. On expose un RxBool qui reflète le OU
  // des 2 flags. Il faut le mettre à jour à chaque changement.
  final RxBool isSocialLoginLoading = false.obs;

  GoogleSignInAccount? _user;
  late GoogleSignIn _googleSignIn;

  final formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  final RxBool isLoading = false.obs;
  final RxBool isSwitchingRole = false.obs;
  final RxnString errorMessage = RxnString();
  final RxBool requiresEmailVerification = false.obs;
  final RxnString userRole = RxnString();
  // v22.5 — Bug R1 : list of roles the account exists as.
  // Populated at login from backend response. UI uses this to show
  // a \"switch role\" picker when length > 1.
  final RxList<String> availableRoles = <String>[].obs;
  bool _isShowingPayPalPrompt = false;

  @override
  void onInit() {
    super.onInit();
    // Load role from storage on initialization
    final storedRole = _storage.read<String>(StorageKeys.userRole);
    _initializeGoogleSignIn();
    if (storedRole != null && storedRole.isNotEmpty) {
      userRole.value = storedRole;
      debugPrint(
        '[HOPETSIT] ✅ AuthController initialized with role: $storedRole',
      );
    } else {
      debugPrint(
        '[HOPETSIT] ⚠️ No role found in storage during AuthController initialization',
      );
    }
    // v23.1 part 43 — sync userRole with JWT.role on every app start so a
    // role drift between localStorage and the backend's JWT can't survive.
    _syncRoleFromJwt();
    // v23.1.254 — confort total : refresh silencieux du token au démarrage
    // (expiration glissante). Garde le token frais 365j + reconnecte le
    // socket temps réel avec un token valide. Best-effort, n'attend pas.
    unawaited(refreshToken());
  }

  @override
  void onClose() {
    // Don't dispose controllers here - they should persist during auth flow
    // Since AuthController is permanent, controllers will persist across navigation
    // They will only be cleared (not disposed) in logout() method
    super.onClose();
  }

  Future<bool> login({String? preferredRole, bool skipFormValidation = false}) async {
    if (!skipFormValidation &&
        !(formKey.currentState?.validate() ?? false)) {
      return false;
    }

    isLoading.value = true;
    errorMessage.value = null;

    try {
      final response = await _authRepository.login(
        email: emailController.text.trim(),
        password: passwordController.text,
        // v425 — après une inscription, on connecte sur le rôle choisi
        // (sinon un email déjà sitter ouvrirait sitter au lieu de walker).
        role: preferredRole,
      );

      final token = _extractToken(response);
      if (token == null) {
        throw ApiException(
          'Token missing in login response.',
          details: response,
        );
      }

      // Save token
      // v23.1 part 125 — Phase 2 audit C4 : JWT écrit dans Keystore Android
      // / Keychain iOS via SecureTokenStore. GetStorage gardé en miroir
      // pour les anciens lecteurs qui n'ont pas encore migré.
      await SecureTokenStore.instance.writeToken(token);
      await _storage.write(StorageKeys.authToken, token);
      final tokenPreview = token.length > 20
          ? '${token.substring(0, 20)}...'
          : token;
      debugPrint('[HOPETSIT] ✅ Token saved: $tokenPreview');

      // Extract role from response
      final role = _extractRole(response);
      userRole.value = role;

      // Save role separately for easy access
      if (role != null) {
        await _storage.write(StorageKeys.userRole, role);
        debugPrint('[HOPETSIT] ✅ Role saved: $role');
      } else {
        debugPrint('[HOPETSIT] ⚠️ Role not found in response');
      }
      // v23.1 part 43 — defensive : if the response role and JWT role
      // disagree (shouldn't happen but defends against race), JWT wins.
      _syncRoleFromJwt();
      // v23.1 part 43 — re-register FCM token under new auth so phone push
      // notifications fire (sitter/walker/owner all need this each login).
      unawaited(_registerFcmTokenWithBackend());
      // v494 — Daniel : « mon ami espagnol reçoit notifs + emails en FR ».
      // CAUSE : appLocale n'était synchronisé qu'au chargement de l'accueil.
      // On pousse la langue UI (choisie OU langue du téléphone) DÈS le login →
      // notifications + emails partent dans la bonne langue (backend priorise
      // appLocale sur language). Guard _syncedThisSession = 1 seule fois/session.
      unawaited(LocalizationService.syncToBackend());

      // v22.5 — Bug R1 : multi-role detection
      final rawAvail = response['availableRoles'];
      if (rawAvail is List) {
        availableRoles.assignAll(
          rawAvail
              .map((e) {
                if (e is String) return e;
                if (e is Map && e['role'] is String) return e['role'] as String;
                return '';
              })
              .where((s) => s.isNotEmpty)
              .toSet()
              .toList(),
        );
      } else {
        availableRoles.clear();
      }

      // v22.5 — Bug R1 : if user has multiple roles available, hint at it.
      if (availableRoles.length > 1) {
        try {
          // Show a one-time info snackbar so the user knows they can switch.
          // Done with addPostFrameCallback so the LoginScreen finishes
          // navigating before the snackbar appears on the new screen.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            CustomSnackbar.showInfo(
              title: 'auth_multiple_roles_title'.tr,
              message: 'auth_multiple_roles_msg'
                  .trParams({'role': role.toString()}),
            );
          });
        } catch (_) { /* non-critical */ }
      }

      // Extract and save user data
      // (v523 : via _saveUserProfile — préserve l'avatar existant.)
      final userData = _extractUser(response);
      if (userData != null) {
        // Add role to user data if not already present
        final userDataWithRole = Map<String, dynamic>.from(userData);
        if (role != null && !userDataWithRole.containsKey('role')) {
          userDataWithRole['role'] = role;
        }
        await _saveUserProfile(userDataWithRole);
        debugPrint('[HOPETSIT] ✅ User profile saved:');
        debugPrint('[HOPETSIT]   - Name: ${userDataWithRole['name'] ?? 'N/A'}');
        debugPrint(
          '[HOPETSIT]   - Email: ${userDataWithRole['email'] ?? 'N/A'}',
        );
        debugPrint(
          '[HOPETSIT]   - Mobile: ${userDataWithRole['mobile'] ?? 'N/A'}',
        );
        debugPrint(
          '[HOPETSIT]   - Address: ${userDataWithRole['address'] ?? 'N/A'}',
        );
        debugPrint(
          '[HOPETSIT]   - Verified: ${userDataWithRole['verified'] ?? 'N/A'}',
        );
        debugPrint('[HOPETSIT]   - Role: ${userDataWithRole['role'] ?? 'N/A'}');
        debugPrint('[HOPETSIT]   - ID: ${userDataWithRole['id'] ?? 'N/A'}');
      } else {
        debugPrint('[HOPETSIT] ⚠️ User data not found in response');
      }

      return true;
    } on ApiException catch (error) {
      // Extract message from error details if available
      // API may return both "error" and "message" fields, prefer "message" when available
      String extractedMessage = error.message;
      if (error.details is Map<String, dynamic>) {
        final details = error.details as Map<String, dynamic>;
        if (details.containsKey('message') && details['message'] is String) {
          extractedMessage = details['message'] as String;
        }
      }

      errorMessage.value = extractedMessage;

      // Check if the error is about email verification
      // Check both the error message and status code (403 = Forbidden, often used for unverified accounts)
      final isEmailVerificationError =
          error.message.toLowerCase().contains('email not verified') ||
          error.message.toLowerCase().contains('please verify your account') ||
          error.statusCode == 403;

      requiresEmailVerification.value = isEmailVerificationError;

      if (isEmailVerificationError) {
        debugPrint(
          '[HOPETSIT] Email verification required. Status: ${error.statusCode}, Message: $extractedMessage',
        );
      }

      return false;
    } catch (error) {
      errorMessage.value = error.toString();
      requiresEmailVerification.value = false;
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _initializeGoogleSignIn() async {
    // v488 — Crash Crashlytics #2 (auth_controller:300, 5 users, builds
    // 23.1.139→485) : `GoogleSignIn.initialize()` peut lever une
    // `GoogleSignInException` (config Google Services manquante, Play Services
    // indisponible/obsolète, double init…). Comme cette méthode était appelée
    // en « fire-and-forget » dans onInit() SANS try/catch, l'exception
    // asynchrone n'était attrapée par personne → erreur Flutter FATALE = crash
    // au démarrage. On enveloppe TOUT : si l'init échoue, on log et on dégrade
    // proprement (le bouton « Continuer avec Google » affichera une erreur
    // traduite via le try/catch de loginWithGoogle, jamais de crash).
    try {
      _googleSignIn = GoogleSignIn.instance;

      // Use the correct client IDs from Firebase configuration
      await _googleSignIn.initialize(
        clientId: Platform.isIOS
            ? "470089536255-sedqnlp3c54m3jv0g21mcoq7a23i6487.apps.googleusercontent.com"
            : "470089536255-q9nrquiekrp6vmjdua2gio42r19fsrd4.apps.googleusercontent.com",
        serverClientId: Platform.isIOS
            ? "470089536255-sedqnlp3c54m3jv0g21mcoq7a23i6487.apps.googleusercontent.com"
            : "470089536255-q9nrquiekrp6vmjdua2gio42r19fsrd4.apps.googleusercontent.com",
      );

      // Listen to authentication events. onError évite qu'une erreur du flux
      // (déconnexion plugin, etc.) ne remonte en exception non attrapée.
      _googleSignIn.authenticationEvents.listen(
        (event) {
          _user = switch (event) {
            GoogleSignInAuthenticationEventSignIn() => event.user,
            GoogleSignInAuthenticationEventSignOut() => null,
          };
          update();
        },
        onError: (Object e) {
          debugPrint('[HOPETSIT] Google authEvents error (ignored): $e');
        },
      );
    } catch (e) {
      debugPrint('[HOPETSIT] Google Sign-In init failed (non-fatal): $e');
    }
  }

  /// [role] When provided (e.g. from sign up screen), sends this role to the backend
  /// for new user creation. Use 'owner' or 'sitter'. If null, uses stored userRole.
  Future<void> loginWithGoogle({String? role}) async {
    try {
      // v23.1 part 200 — flag indépendant Google (cf. déclaration plus haut)
      isGoogleLoginLoading.value = true;
      isSocialLoginLoading.value = true;
      // v23.1 part 142 — Daniel : 'verifie pkoi sitter creer un compte
      // seul'. Avant : roleToSend = role ?? userRole.value → si un user
      // avait fait un signup Sitter PRÉCÉDEMMENT, userRole.value=='sitter'
      // restait stocké dans GetStorage. Au nouveau click "Continue with
      // Google" depuis LoginScreen (role=null), le fallback prenait
      // 'sitter' → backend créait un Sitter direct sans demander.
      // Maintenant : on n'utilise PAS le fallback. Si role est null, on
      // envoie null au backend. Backend renvoie soit le user existant
      // (existingUser:true avec son vrai role), soit 400 ROLE_REQUIRED
      // → redirection vers SignUpAs.
      final roleToSend = role;
      debugPrint(
        '[HOPETSIT] Google sign-in: role parameter=$role, roleToSend=$roleToSend',
      );
      if (role != null) {
        userRole.value = role;
      }
      if (_googleSignIn.supportsAuthenticate()) {
        await _googleSignIn.authenticate(scopeHint: ['email']);
      } else {
        CustomSnackbar.showError(
          title: 'auth_google_signin_title',
          message: 'auth_google_signin_web_required',
        );
        return;
      }

      // Wait briefly to ensure authenticationEvents listener populates _user
      await Future.delayed(Duration(milliseconds: 200));
      if (_user == null) {
        CustomSnackbar.showError(
          title: 'auth_google_signin_title',
          message: 'auth_google_signin_failed',
        );
        return;
      }
      final googleAuth = _user!.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null) {
        CustomSnackbar.showError(
          title: 'auth_google_signin_title',
          message: 'auth_google_signin_token_missing',
        );
        return;
      }

      final credential = GoogleAuthProvider.credential(idToken: idToken);

      log(' [HOPETSIT] 🔐 Signing in with Google credential');
      await _auth.signInWithCredential(credential);

      // Backend requires Firebase ID token (JWT). Force refresh to get a fresh token.
      final firebaseUser = _auth.currentUser;
      final String? firebaseIdToken = await firebaseUser?.getIdToken(true);

      if (firebaseIdToken == null || firebaseIdToken.isEmpty) {
        CustomSnackbar.showError(
          title: 'auth_google_signin_title',
          message: 'auth_google_signin_firebase_token_failed',
        );
        return;
      }

      // Send Firebase ID token (and optional role for new users) to backend.
      // v23.1 part 137 — fix Daniel : "la page choisir owner/walker/sitter
      // a disparu". Avant, role était hardcodé à 'sitter' si pas fourni
      // → le backend créait directement un Sitter doc, sans demander à
      // l'utilisateur. Maintenant on envoie null pour les new users → le
      // backend renvoie 400 ROLE_REQUIRED → on ouvre SignUpAs juste après.
      final Map<String, dynamic> response;
      try {
        response = await _authRepository.googleSignInWithIdToken(
          idToken: firebaseIdToken,
          role: (roleToSend != null && roleToSend.isNotEmpty) ? roleToSend : null,
        );
      } on ApiException catch (e) {
        // v23.1 part 137 — 400 ROLE_REQUIRED → l'utilisateur est nouveau,
        // on doit lui faire choisir owner/sitter/walker AVANT de créer le
        // doc en base. On le redirige vers SignUpAs. Le idToken Firebase
        // reste valide ; quand il re-tap "Continue with Google" depuis le
        // SignUpScreen choisi, ça revient ici avec un role défini.
        final isRoleRequired = e.statusCode == 400 &&
            (e.details is Map &&
                ((e.details as Map)['code'] == 'ROLE_REQUIRED'));
        if (isRoleRequired) {
          CustomSnackbar.showInfo(
            title: 'auth_google_signin_title'.tr,
            message: 'Choisis ton type de compte (owner / sitter / walker).',
          );
          // ignore: use_build_context_synchronously
          Get.offAll(() => const SignUpAsScreen());
          return;
        }
        // Autre erreur : on remonte au catch global
        rethrow;
      }

      // Backend may return success with token/role/user without a "success" key
      final backendToken = _extractToken(response);
      final isSuccess =
          (response["success"] == true) ||
          (backendToken != null && backendToken.isNotEmpty);

      if (isSuccess && backendToken != null) {
        // v23.1 part 125 — Phase 2 audit C4 : SecureTokenStore mirror.
        await SecureTokenStore.instance.writeToken(backendToken);
        await _storage.write(StorageKeys.authToken, backendToken);
        debugPrint('[HOPETSIT] ✅ Token saved from Google sign-in');

        // v23.1 part 46 — fix Daniel "je reçois email mais pas push notif".
        // Root cause : `_registerFcmTokenWithBackend()` was called in the
        // email/password `login()` path but never in `loginWithGoogle()`
        // / `loginWithApple()`. So users who signed in via Google (most
        // of Daniel's test sessions, see /auth/google in Render logs)
        // ended up with a JWT but the backend never knew about their
        // FCM token. sendNotification logged `[notif.push] no fcmTokens`
        // for every push attempt, while the email channel still worked
        // because email was decrypted from the Owner doc directly.
        unawaited(_registerFcmTokenWithBackend());
      // v494 — Daniel : « mon ami espagnol reçoit notifs + emails en FR ».
      // CAUSE : appLocale n'était synchronisé qu'au chargement de l'accueil.
      // On pousse la langue UI (choisie OU langue du téléphone) DÈS le login →
      // notifications + emails partent dans la bonne langue (backend priorise
      // appLocale sur language). Guard _syncedThisSession = 1 seule fois/session.
      unawaited(LocalizationService.syncToBackend());
        // Same JWT-based role drift recovery as the password login path,
        // so role is consistent right after Google sign-in too.
        _syncRoleFromJwt();

        // Prefer the role we sent to the backend — some backends create the
        // user as 'sitter' by default and return 'sitter' even when we asked
        // for 'walker'. The role we sent is the truth for new signups.
        //
        // Also: a user may have an old orphan record (e.g. a Sitter document
        // from a previous app version) tied to the same Google email. When
        // they now sign up as a Walker, the backend sees existingUser=true,
        // role='sitter' and the frontend used to open the Sitter home. We
        // fix this defensively: if the caller explicitly asked for 'walker',
        // we trust that over whatever the backend returns.
        // v532 — CORRECTION : on ne force plus 'walker'. Le JWT est signé par
        // le backend avec le rôle du compte RÉELLEMENT trouvé (findAccountByEmail,
        // ordre owner > sitter > walker). Forcer 'walker' côté app ouvrait
        // l'interface promeneur avec un token owner : tous les appels
        // /walkers/me… échouaient et l'écran restait vide, sans qu'aucun
        // profil walker n'ait été créé. Pour un compte EXISTANT, le rôle du
        // backend fait foi ; le rôle demandé ne prime que sur une création.
        final backendRole = _extractRole(response);
        final isNewUser = response['existingUser'] != true;
        final role = isNewUser
            ? (roleToSend ?? backendRole)
            : (backendRole ?? roleToSend);
        userRole.value = role;
        if (role != null) {
          await _storage.write(StorageKeys.userRole, role);
        }

        // v22.5 — Bug R1 : multi-role detection
        final rawAvail = response['availableRoles'];
        if (rawAvail is List) {
          availableRoles.assignAll(
            rawAvail
                .map((e) {
                  if (e is String) return e;
                  if (e is Map && e['role'] is String) return e['role'] as String;
                  return '';
                })
                .where((s) => s.isNotEmpty)
                .toSet()
                .toList(),
          );
        } else {
          availableRoles.clear();
        }

        final userData = _extractUser(response);
        if (userData != null) {
          final userDataWithRole = Map<String, dynamic>.from(userData);
          if (role != null) {
            userDataWithRole['role'] = role;
          }
          await _saveUserProfile(userDataWithRole);
        }

        // Check if this is a new user (existingUser: false)
        final existingUser = response['existingUser'] as bool? ?? true;
        debugPrint(
          '[HOPETSIT] Google sign-in: existingUser=$existingUser, '
          'roleToSend=$roleToSend, backendRole=$backendRole, effective=$role',
        );

        if (!existingUser) {
          // v529 — signale l'inscription à Meta (optimisation campagnes install).
          unawaited(
            MetaEventsService.instance.logCompletedRegistration(method: 'google'),
          );
          // v532 — même signal vers Google Ads via Firebase Analytics, pour que
          // l'algo optimise sur les inscriptions réelles et non sur les installs.
          unawaited(
            FirebaseAnalyticsService.instance.logSignUp(method: 'google'),
          );
          // New user - navigate to choose service screen
          final email =
              userData?['email']?.toString() ??
              response['email']?.toString() ??
              firebaseUser?.email ??
              '';

          if (email.isNotEmpty && role != null) {
            // Map role to userType format — supports owner / sitter / walker.
            final userType = role == 'owner'
                ? 'pet_owner'
                : role == 'walker'
                    ? 'pet_walker'
                    : 'pet_sitter';

            debugPrint(
              '[HOPETSIT] Navigating new Google user: role=$role -> userType=$userType',
            );

            // Walkers have an implicit single service (dog_walking) so they
            // skip the ChooseServiceScreen and land straight on the walker
            // home shell.
            if (userType == 'pet_walker') {
              CustomSnackbar.showSuccess(
                title: 'auth_google_signin_title',
                message: 'auth_google_signin_success',
              );
              Get.offAll(() => const WalkerNavWrapper());
            } else {
              CustomSnackbar.showSuccess(
                title: 'auth_google_signin_title',
                message: 'auth_google_signin_choose_services',
              );

              Get.offAll(
                () => ChooseServiceScreen(
                  userType: userType,
                  email: email,
                  isFromProfile: false,
                ),
              );
            }
          } else {
            debugPrint(
              '[HOPETSIT] ⚠️ Missing email or role for new user navigation',
            );
            _navigateToHome();
          }
        } else {
          // Existing user - navigate to home
          CustomSnackbar.showSuccess(
            title: 'auth_google_signin_title',
            message: 'auth_google_signin_success',
          );
          _navigateToHome();
        }
      } else {
        CustomSnackbar.showError(
          title: 'auth_google_signin_title',
          message: 'auth_google_signin_failed',
        );
      }
    } catch (e) {
      debugPrint("Google Login Error: $e");
      // v448 — Daniel (screenshot) : pop-up rouge « Google Login Error …
      // canceled, [16] ». Le code 16 / "canceled" = l'utilisateur a FERMÉ le
      // sélecteur Google de lui-même → ce n'est PAS une erreur, on n'affiche
      // RIEN. Pour les VRAIES erreurs : message propre TRADUIT (fini
      // l'exception technique brute + le titre anglais codé en dur). Le titre
      // et le message sont traduits par CustomSnackbar (._t → .tr).
      final raw = e.toString().toLowerCase();
      final isCanceled = raw.contains('canceled') ||
          raw.contains('cancelled') ||
          raw.contains('[16]') ||
          raw.contains('code 16') ||
          raw.contains('aborted') ||
          raw.contains('sign_in_canceled') ||
          raw.contains('signinexceptioncode.canceled');
      if (!isCanceled) {
        CustomSnackbar.showError(
          title: 'auth_google_signin_title',
          message: 'auth_google_signin_failed',
        );
      }
    } finally {
      // v23.1 part 200 — clear Google flag + sync shim
      isGoogleLoginLoading.value = false;
      isSocialLoginLoading.value = isAppleLoginLoading.value;
    }
  }

  /// [role] When provided (e.g. from sign up screen), sends this role to the backend
  /// for new user creation. Use 'owner' or 'sitter'. If null, uses stored userRole.
  /// Implemented exactly like loginWithGoogle.
  /// v500 — SHA-256 (hex) d'une chaîne, pour hacher le nonce envoyé à Apple.
  String _sha256ofString(String input) {
    return sha256.convert(utf8.encode(input)).toString();
  }

  /// v523 — Daniel : « avec le même compte, si je me connecte d'un Android
  /// ou d'un iPhone, ma photo de profil disparaît et réapparaît ». CAUSE :
  /// certaines réponses de connexion (Apple surtout — Apple ne fournit
  /// jamais de photo) arrivent avec un avatar VIDE alors que le compte en a
  /// un sur le serveur → on écrasait le cache local et toute l'UI perdait
  /// la photo jusqu'au prochain refetch. RÈGLE : on ne rétrograde JAMAIS un
  /// avatar existant vers du vide pour le même compte (même email).
  Future<void> _saveUserProfile(Map<String, dynamic> profile) async {
    try {
      final old = _storage.read<Map<String, dynamic>>(StorageKeys.userProfile);
      String urlOf(dynamic a) =>
          a is Map ? (a['url'] ?? '').toString() : (a ?? '').toString();
      final newHasAvatar = urlOf(profile['avatar']).isNotEmpty;
      final oldHasAvatar = old != null && urlOf(old['avatar']).isNotEmpty;
      final sameUser = old != null &&
          (old['email'] ?? '').toString().toLowerCase() ==
              (profile['email'] ?? '').toString().toLowerCase();
      if (!newHasAvatar && oldHasAvatar && sameUser) {
        profile['avatar'] = old['avatar'];
      }
    } catch (_) {/* défensif — au pire on écrit tel quel */}
    await _storage.write(StorageKeys.userProfile, profile);
  }

  Future<void> loginWithApple({String? role}) async {
    try {
      // v23.1 part 200 — flag indépendant Apple
      isAppleLoginLoading.value = true;
      isSocialLoginLoading.value = true;
      // v23.1 part 142 — idem Google : pas de fallback userRole.value,
      // sinon un Sitter stocké d'une session précédente force la
      // création d'un compte Sitter au lieu de demander le rôle.
      final roleToSend = role;
      if (role != null) {
        userRole.value = role;
      }

      // v500 — Connexion Apple réécrite. firebase_auth 6.x EXIGE un « nonce »
      // sécurisé que l'ancienne lib `the_apple_sign_in` ne pouvait pas envoyer
      // → Firebase refusait (« Un problème est survenu »). On passe à
      // `sign_in_with_apple` (recommandée par Firebase) : nonce brut envoyé à
      // Firebase + son SHA-256 envoyé à Apple (anti-rejeu).
      final String rawNonce = generateNonce();
      final String hashedNonce = _sha256ofString(rawNonce);

      final AuthorizationCredentialAppleID appleCredential =
          await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      final String? appleIdToken = appleCredential.identityToken;
      if (appleIdToken == null || appleIdToken.isEmpty) {
        CustomSnackbar.showError(
          title: 'auth_apple_signin_failed',
          message: 'auth_apple_signin_failed_generic',
        );
        return;
      }

      // v501 — FIX invalid-credential : Firebase exige AUSSI le code
      // d'autorisation Apple (authorizationCode) passé comme accessToken,
      // sinon « [firebase_auth/invalid-credential] Invalid OAuth response
      // from apple.com ». (Réf. FlutterFire #13242 ; l'ancienne lib l'envoyait,
      // ma réécriture l'avait retiré.)
      final OAuthCredential authCredential = OAuthProvider('apple.com')
          .credential(
        idToken: appleIdToken,
        rawNonce: rawNonce,
        accessToken: appleCredential.authorizationCode,
      );

      await _auth.signInWithCredential(authCredential);

      final firebaseUser = _auth.currentUser;
      final String? firebaseIdToken = await firebaseUser?.getIdToken(true);

      if (firebaseIdToken == null || firebaseIdToken.isEmpty) {
        CustomSnackbar.showError(
          title: 'auth_apple_signin_failed',
          message: 'auth_google_signin_firebase_token_failed',
        );
        return;
      }

      // v23.1 part 137 — idem Google : ne pas default 'sitter' si pas de
      // role. Si new user → backend renvoie 400 ROLE_REQUIRED → SignUpAs.
      final Map<String, dynamic> response;
      try {
        response = await _authRepository.appleSignInWithIdToken(
          idToken: firebaseIdToken,
          role: (roleToSend != null && roleToSend.isNotEmpty) ? roleToSend : null,
        );
      } on ApiException catch (e) {
        final isRoleRequired = e.statusCode == 400 &&
            (e.details is Map &&
                ((e.details as Map)['code'] == 'ROLE_REQUIRED'));
        if (isRoleRequired) {
          CustomSnackbar.showInfo(
            title: 'auth_apple_signin_title'.tr,
            message: 'Choisis ton type de compte (owner / sitter / walker).',
          );
          Get.offAll(() => const SignUpAsScreen());
          return;
        }
        rethrow;
      }

      final backendToken = _extractToken(response);
      final isSuccess =
          (response['success'] == true) ||
          (backendToken != null && backendToken.isNotEmpty);

      if (isSuccess && backendToken != null) {
        // v23.1 part 125 — Phase 2 audit C4 : SecureTokenStore mirror.
        await SecureTokenStore.instance.writeToken(backendToken);
        await _storage.write(StorageKeys.authToken, backendToken);

        // v23.1 part 46 — same FCM register fix as the Google path. Without
        // this Apple sign-in users never got phone push notifs.
        unawaited(_registerFcmTokenWithBackend());
      // v494 — Daniel : « mon ami espagnol reçoit notifs + emails en FR ».
      // CAUSE : appLocale n'était synchronisé qu'au chargement de l'accueil.
      // On pousse la langue UI (choisie OU langue du téléphone) DÈS le login →
      // notifications + emails partent dans la bonne langue (backend priorise
      // appLocale sur language). Guard _syncedThisSession = 1 seule fois/session.
      unawaited(LocalizationService.syncToBackend());
        _syncRoleFromJwt();

        // Same defensive check as Google sign-in: if the caller explicitly
        // asked for 'walker', trust that over whatever the backend returns.
        // This covers old orphan Sitter records created from the same Apple
        // email in a previous version of the app.
        final backendRole = _extractRole(response);
        final role =
            (roleToSend == 'walker') ? 'walker' : (backendRole ?? roleToSend);
        userRole.value = role;
        if (role != null) {
          await _storage.write(StorageKeys.userRole, role);
        }

        final userData = _extractUser(response);
        if (userData != null) {
          final userDataWithRole = Map<String, dynamic>.from(userData);
          if (role != null && !userDataWithRole.containsKey('role')) {
            userDataWithRole['role'] = role;
          }
          await _saveUserProfile(userDataWithRole);
        }

        final existingUser = response['existingUser'] as bool? ?? true;

        if (!existingUser) {
          // v529 — signale l'inscription à Meta (optimisation campagnes install).
          unawaited(
            MetaEventsService.instance.logCompletedRegistration(method: 'apple'),
          );
          // v532 — même signal vers Google Ads via Firebase Analytics, pour que
          // l'algo optimise sur les inscriptions réelles et non sur les installs.
          unawaited(
            FirebaseAnalyticsService.instance.logSignUp(method: 'apple'),
          );
          final email =
              userData?['email']?.toString() ??
              response['email']?.toString() ??
              firebaseUser?.email ??
              '';

          if (email.isNotEmpty && role != null) {
            // Map role to userType format — supports owner / sitter / walker.
            final userType = role == 'owner'
                ? 'pet_owner'
                : role == 'walker'
                    ? 'pet_walker'
                    : 'pet_sitter';

            if (userType == 'pet_walker') {
              CustomSnackbar.showSuccess(
                title: 'common_success',
                message: 'auth_apple_signin_success',
              );
              Get.offAll(() => const WalkerNavWrapper());
            } else {
              CustomSnackbar.showSuccess(
                title: 'common_success',
                message: 'auth_google_signin_choose_services',
              );

              Get.offAll(
                () => ChooseServiceScreen(
                  userType: userType,
                  email: email,
                  isFromProfile: false,
                ),
              );
            }
          } else {
            _navigateToHome();
          }
        } else {
          CustomSnackbar.showSuccess(
            title: 'common_success',
            message: 'auth_apple_signin_success',
          );
          _navigateToHome();
        }
      } else {
        CustomSnackbar.showError(
          title: 'auth_apple_signin_failed',
          message: 'auth_apple_signin_failed_generic',
        );
      }
    } on SignInWithAppleAuthorizationException catch (e) {
      // v500 — l'utilisateur a annulé la feuille Apple → pas une erreur.
      if (e.code == AuthorizationErrorCode.canceled) {
        return;
      }
      CustomSnackbar.showError(
        title: 'auth_apple_signin_failed',
        message: 'auth_apple_signin_failed_generic',
      );
    } on ApiException {
      CustomSnackbar.showError(
        title: 'auth_apple_signin_failed',
        message: 'auth_apple_signin_failed_generic',
      );
    } catch (e) {
      // v448 — idem Google : si l'utilisateur ANNULE la feuille Apple
      // (canceled / code 1001 iOS), ce n'est PAS une erreur → on n'affiche
      // rien. Vraie erreur seulement → message propre traduit.
      final raw = e.toString().toLowerCase();
      final isCanceled = raw.contains('cancel') ||
          raw.contains('aborted') ||
          raw.contains('[16]') ||
          raw.contains('1001');
      if (!isCanceled) {
        CustomSnackbar.showError(
          title: 'auth_apple_signin_failed',
          message: 'common_error_generic',
        );
      }
    } finally {
      // v23.1 part 200 — clear Apple flag + sync shim
      isAppleLoginLoading.value = false;
      isSocialLoginLoading.value = isGoogleLoginLoading.value;
    }
  }

  /// Navigates to the appropriate home screen based on user role.
  ///
  /// v18.9.8 — reset les controllers user-scoped AVANT le `Get.offAll` pour
  /// éviter le flicker observé au switch rapide : avant, les controllers
  /// anciens étaient encore en cache quand le nouveau wrapper commençait
  /// son premier build, puis `_refreshDataAfterRoleSwitch` (post-frame)
  /// les supprimait → double rebuild visible.
  /// Transition `noTransition` pour un swap instantané (pas de fade-in).
  void _navigateToHome() {
    final role = userRole.value;

    // Reset les controllers AVANT la navigation pour que le nouveau home
    // démarre déjà propre (ses `onInit` tireront les data du bon rôle).
    try {
      _forceResetUserControllers();
      _clearServiceSelections();
    } catch (_) {
      // Non-bloquant — si un controller n'existe pas, on continue.
    }

    if (role == 'owner') {
      Get.offAll(
        () => const BottomNavWrapper(),
        transition: Transition.noTransition,
        duration: Duration.zero,
      );
    } else if (role == 'sitter') {
      Get.offAll(
        () => const SitterNavWrapper(),
        transition: Transition.noTransition,
        duration: Duration.zero,
      );
    } else if (role == 'walker') {
      // Walker role — uses its own nav shell, defined next to the sitter shell.
      Get.offAll(
        () => const WalkerNavWrapper(),
        transition: Transition.noTransition,
        duration: Duration.zero,
      );
    } else {
      // Fallback: go back if role is not recognized
      Get.back();
    }
  }

  String? _extractToken(Map<String, dynamic> response) {
    final token =
        response['token'] ??
        response['accessToken'] ??
        response['access_token'] ??
        response['data']?['token'] ??
        response['data']?['accessToken'] ??
        response['data']?['access_token'];

    if (token is String && token.isNotEmpty) {
      return token;
    }
    return null;
  }

  Map<String, dynamic>? _extractUser(Map<String, dynamic> response) {
    final user =
        response['user'] ??
        response['profile'] ??
        response['data']?['user'] ??
        response['data']?['profile'];
    if (user is Map<String, dynamic>) {
      return user;
    }
    if (user is Map) {
      return Map<String, dynamic>.from(user);
    }
    return null;
  }

  String? _extractRole(Map<String, dynamic> response) {
    // Check for role in various possible locations
    final role =
        response['role'] ??
        response['data']?['role'] ??
        response['user']?['role'] ??
        response['data']?['user']?['role'];

    if (role is String && role.isNotEmpty) {
      return role.toLowerCase(); // Normalize to lowercase
    }
    return null;
  }

  /// v23.1 part 43 — fix Daniel "logged in as owner but app opens as walker
  /// + impossible to switch back". Root cause : the frontend's userRole
  /// reads from localStorage at app start, but if the previous session was
  /// walker and the new login response role gets overwritten by some race
  /// condition, the displayed UI doesn't match what the backend's JWT says.
  /// Then trying to switch back fails with "targetRole must be different
  /// from the current role" because the backend reads its role from the
  /// JWT and rejects the switch.
  ///
  /// Fix : decode the JWT directly and use ITS role as the canonical source
  /// of truth. The JWT is signed by the backend so its role claim cannot
  /// drift out of sync.
  String? _decodeRoleFromJwt(String? token) {
    if (token == null || token.isEmpty) return null;
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      // Base64URL decode the payload (middle segment).
      var payload = parts[1].replaceAll('-', '+').replaceAll('_', '/');
      // Add padding if needed.
      while (payload.length % 4 != 0) {
        payload += '=';
      }
      final bytes = base64.decode(payload);
      final json = jsonDecode(utf8.decode(bytes));
      final role = (json is Map && json['role'] is String)
          ? (json['role'] as String).toLowerCase()
          : null;
      return (role != null && role.isNotEmpty) ? role : null;
    } catch (_) {
      return null;
    }
  }

  /// v23.1 part 43 — sync userRole + storage with the JWT's authoritative
  /// role claim. Call after login and on app startup.
  void _syncRoleFromJwt() {
    final token = _storage.read<String>(StorageKeys.authToken);
    final jwtRole = _decodeRoleFromJwt(token);
    if (jwtRole == null) return;
    if (userRole.value != jwtRole) {
      debugPrint(
        '[HOPETSIT] 🔄 Role drift detected (storage=${userRole.value}, jwt=$jwtRole). Forcing JWT role.',
      );
      userRole.value = jwtRole;
      _storage.write(StorageKeys.userRole, jwtRole);
    }
  }

  /// v23.1 part 43 — fix Daniel "0 notif phone/email" : after a successful
  /// login the FCM token must be re-registered against the new auth context.
  /// Without this, the backend never knows the user's FCM token, sendPush
  /// receives an empty array, and no phone push ever fires (in-app message
  /// arrives but no system push). Email goes via the same notif system —
  /// it's not gated on FCM, but the token registration is the most common
  /// missing step after a fresh login on a re-installed APK.
  Future<void> _registerFcmTokenWithBackend() async {
    try {
      final pushService = Get.isRegistered<PushNotificationService>()
          ? Get.find<PushNotificationService>()
          : null;
      if (pushService == null) {
        debugPrint('[HOPETSIT] ℹ️ PushNotificationService not registered yet.');
        return;
      }
      // Force the public re-register path on the push service. This will
      // call /users/fcm-token with the fresh JWT context.
      await pushService.reRegisterAfterLogin();
      debugPrint('[HOPETSIT] ✅ FCM token re-registered after login');
    } catch (e) {
      debugPrint('[HOPETSIT] ⚠️ FCM token re-register failed: $e');
    }
  }

  String? validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) {
      return 'error_email_required'.tr;
    }
    if (!GetUtils.isEmail(email)) {
      return 'error_email_invalid'.tr;
    }
    return null;
  }

  String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'error_password_required'.tr;
    }
    if (value.length < 8) {
      return 'error_password_length'.tr;
    }
    return null;
  }

  /// Handles login with navigation logic
  Future<void> handleLoginWithNavigation() async {
    final success = await login();

    if (success) {
      // Navigate based on user role
      _navigateToHome();

      CustomSnackbar.showSuccess(
        title: 'common_success',
        message: 'auth_welcome_back',
      );
    } else {
      // Check if email verification is required
      if (requiresEmailVerification.value) {
        final displayMessage =
            errorMessage.value ??
            'Email not verified. Please verify your account.';

        // Check if the message indicates a new code was sent
        final isNewCodeSent =
            displayMessage.toLowerCase().contains('new verification code') ||
            displayMessage.toLowerCase().contains(
              'verification code has been sent',
            ) ||
            displayMessage.toLowerCase().contains(
              'has been sent to your email',
            );

        if (isNewCodeSent) {
          // Show success/info message when new code is sent
          CustomSnackbar.showSuccess(
            title: 'snackbar_text_verification_code_sent',
            message: displayMessage,
          );
        } else {
          // Show error for other verification issues
          CustomSnackbar.showError(
            title: 'snackbar_text_email_not_verified',
            message: displayMessage,
          );
        }

        // Add a small delay to ensure snackbar is visible before navigating
        await Future.delayed(const Duration(milliseconds: 500));

        // Navigate to OTP verification screen
        debugPrint(
          '[HOPETSIT] Navigating to OTP verification screen for email: ${emailController.text.trim()}',
        );
        Get.to(
          () => OtpVerificationScreen(
            email: emailController.text.trim(),
            verificationType: VerificationType.login,
          ),
        );
      } else {
        CustomSnackbar.showError(
          title: 'signup_failed_title',
          message: 'signup_failed_generic_message',
        );
      }
    }
  }

  /// Switches between the 3 roles (owner / sitter / walker) via API.
  /// [targetRole] is optional — when omitted the backend does the legacy
  /// binary toggle owner<->sitter. For walker, a targetRole must be passed
  /// (e.g. 'walker', 'owner', 'sitter').
  Future<void> switchRole({String? targetRole}) async {
    isSwitchingRole.value = true;
    final repo =
        _userRepository ??
        (Get.isRegistered<UserRepository>()
            ? Get.find<UserRepository>()
            : null);
    if (repo == null) {
      _switchRoleLocalOnly(targetRole: targetRole);
      isSwitchingRole.value = false;
      return;
    }

    try {
      final response = await repo.switchRole(targetRole: targetRole);
      final newRole = _extractRole(response);

      // Backend may return a new token with updated role claim – save it so
      // subsequent requests (e.g. GET /users/me/profile, GET /blocks) succeed.
      final newToken = _extractToken(response);
      if (newToken != null && newToken.isNotEmpty) {
        // v23.1 part 125 — Phase 2 audit C4 : SecureTokenStore mirror.
        await SecureTokenStore.instance.writeToken(newToken);
        await _storage.write(StorageKeys.authToken, newToken);
        debugPrint('[HOPETSIT] ✅ New token saved after role switch');
        // v23.1 part 46 — re-register FCM token under the NEW role's doc.
        // Backend switchRole creates a fresh doc in the target collection
        // (Walker → Owner creates new Owner doc, deletes Walker doc) with
        // empty fcmTokens. Without this re-register the user's device is
        // unknown to the new role's notification routing — push notifs
        // for that role would silently skip with "no fcmTokens".
        unawaited(_registerFcmTokenWithBackend());
      // v494 — Daniel : « mon ami espagnol reçoit notifs + emails en FR ».
      // CAUSE : appLocale n'était synchronisé qu'au chargement de l'accueil.
      // On pousse la langue UI (choisie OU langue du téléphone) DÈS le login →
      // notifications + emails partent dans la bonne langue (backend priorise
      // appLocale sur language). Guard _syncedThisSession = 1 seule fois/session.
      unawaited(LocalizationService.syncToBackend());
      }

      final userData = _extractUser(response);
      if (userData != null) {
        final userDataWithRole = Map<String, dynamic>.from(userData);
        final role = newRole ?? userDataWithRole['role']?.toString();
        if (role != null && !userDataWithRole.containsKey('role')) {
          userDataWithRole['role'] = role;
        }
        await _saveUserProfile(userDataWithRole);
        debugPrint('[HOPETSIT] ✅ User profile updated after role switch');
      }

      if (newRole == null || newRole.isEmpty) {
        // API did not return role; fall back to targetRole hint, or legacy toggle.
        final currentRole = userRole.value;
        final toggled = targetRole ??
            (currentRole == 'owner' ? 'sitter' : 'owner');
        await _storage.write(StorageKeys.userRole, toggled);
        userRole.value = toggled;
        debugPrint('[HOPETSIT] ✅ Role switched to: $toggled (local fallback)');
      } else {
        await _storage.write(StorageKeys.userRole, newRole);
        userRole.value = newRole;
        debugPrint('[HOPETSIT] ✅ Role switched to: $newRole');
      }

      // Build a user-facing role label for the 3 possible roles.
      String roleLabel(String r) {
        switch (r) {
          case 'owner':
            return 'auth_role_pet_owner'.tr;
          case 'walker':
            return 'auth_role_pet_walker'.tr;
          case 'sitter':
          default:
            return 'auth_role_pet_sitter'.tr;
        }
      }

      CustomSnackbar.showSuccess(
        title: 'snackbar_text_role_switched',
        message: 'auth_role_switched_message'.tr.replaceAll(
          '@role',
          roleLabel(userRole.value ?? ''),
        ),
      );

      _navigateToHome();
      _scheduleRefreshAfterRoleSwitch();
    } on ApiException catch (e) {
      debugPrint('[HOPETSIT] ❌ Switch role API error: ${e.message}');
      // v23.1 — surface the real backend message so we can diagnose. Tries
      // `details` (preferred actionable cause) → falls back to message.
      String msg = e.message;
      final det = e.details;
      if (det is Map) {
        final d = det['details'];
        if (d is String && d.isNotEmpty) msg = d;
      }
      CustomSnackbar.showError(
        title: 'snackbar_text_switch_role_failed'.tr,
        message: msg,
      );
    } catch (e) {
      debugPrint('[HOPETSIT] ❌ Error switching role: $e');
      CustomSnackbar.showError(
        title: 'snackbar_text_switch_role_failed'.tr,
        message: e.toString(),
      );
    } finally {
      isSwitchingRole.value = false;
    }
  }

  void _switchRoleLocalOnly({String? targetRole}) {
    try {
      final currentRole = userRole.value;
      // Use explicit targetRole when provided; otherwise fall back to the
      // legacy binary toggle owner<->sitter (walker cannot toggle without an
      // explicit target).
      final newRole = targetRole ??
          (currentRole == 'owner' ? 'sitter' : 'owner');
      _storage.write(StorageKeys.userRole, newRole);
      userRole.value = newRole;

      String roleLabel(String r) {
        switch (r) {
          case 'owner':
            return 'auth_role_pet_owner'.tr;
          case 'walker':
            return 'auth_role_pet_walker'.tr;
          case 'sitter':
          default:
            return 'auth_role_pet_sitter'.tr;
        }
      }

      CustomSnackbar.showSuccess(
        title: 'auth_role_switched',
        message: 'auth_role_switched_message'.tr.replaceAll(
          '@role',
          roleLabel(newRole),
        ),
      );
      _navigateToHome();
      _scheduleRefreshAfterRoleSwitch();
    } catch (e) {
      CustomSnackbar.showError(
        title: 'snackbar_text_switch_role_failed',
        message: 'snackbar_text_failed_to_switch_role_please_try_again',
      );
    } finally {
      isSwitchingRole.value = false;
    }
  }

  /// Schedules a post-frame refresh so the new role's data is loaded (same as app startup).
  void _scheduleRefreshAfterRoleSwitch() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _refreshDataAfterRoleSwitch();
    });
  }

  /// Re-triggers startup APIs for the current role and clears the other role's cached data.
  ///
  /// v18.9.8 — le reset des controllers a été déplacé dans `_navigateToHome`
  /// (avant le `Get.offAll`) pour éviter le flicker. Ici on ne fait plus que
  /// les actions qui DOIVENT se faire APRÈS navigation (prompt PayPal, etc.).
  Future<void> _refreshDataAfterRoleSwitch() async {
    final role = userRole.value;
    if (role == null) return;

    try {
      if (role == 'sitter' && AppConstants.showPayPalOption) {
        await _promptForSitterPayPalEmailIfMissing();
      }
      debugPrint('[HOPETSIT] ✅ Data refreshed after role switch to $role');
    } catch (e) {
      debugPrint('[HOPETSIT] ⚠️ Refresh after role switch failed: $e');
    }
  }

  /// Deletes every user-scoped GetxController so they get re-created fresh
  /// (with their onInit load) the next time a widget looks them up. Mirrors
  /// the cleanup we do at logout — see `logout()`.
  void _forceResetUserControllers() {
    _forceDelete<UserController>();
    _forceDelete<ProfileController>();
    _forceDelete<SitterProfileController>();
    _forceDelete<HomeController>();
    _forceDelete<PostsController>();
    // v23.1 — bug #4 fix : booking + notification controllers also carry
    // user-scoped cache (RxList<BookingModel>). Without these deletes,
    // logging out account A and back in as account B kept A's bookings
    // in memory and they leaked into B's history screen + home banner.
    _forceDelete<BookingsController>();
    _forceDelete<SitterBookingsController>();
    _forceDelete<WalkerBookingsController>();
    _forceDelete<NotificationsController>();
    _forceDelete<UnifiedNotificationController>();
  }

  /// Walker-specific refresh after role switch. Walker has no dedicated
  /// profile endpoint yet (reuses the generic user profile), so this mostly
  /// reloads the shared feed + display name/avatar.
  // Kept for reference — may be re-used later if we want partial refresh
  // without the full force-delete done by _forceResetUserControllers().
  // ignore: unused_element
  Future<void> _refreshWalkerData() async {
    if (Get.isRegistered<UserController>()) {
      await Get.find<UserController>().loadMyProfile();
    }
    if (Get.isRegistered<PostsController>()) {
      final pc = Get.find<PostsController>();
      await pc.loadPostsWithoutMedia();
      await pc.loadMediaPosts();
    }
  }

  Future<void> _promptForSitterPayPalEmailIfMissing() async {
    try {
      // Always check latest payout email from backend first.
      final sitterRepo = Get.find<SitterRepository>();
      String? existingEmail;
      try {
        final payoutEmailResponse = await sitterRepo.getPayPalPayoutEmail();
        existingEmail =
            (payoutEmailResponse['paypalEmail'] as String?)?.trim() ??
            (payoutEmailResponse['email'] as String?)?.trim() ??
            (payoutEmailResponse['data'] is Map
                ? (payoutEmailResponse['data']['paypalEmail'] as String?)
                      ?.trim()
                : null) ??
            (payoutEmailResponse['sitter'] is Map
                ? (payoutEmailResponse['sitter']['paypalEmail'] as String?)
                      ?.trim()
                : null);
      } catch (_) {
        // Fallback to profile endpoint for backward compatibility.
        final profile = await sitterRepo.getMySitterProfile();
        existingEmail =
            (profile['paypalEmail'] as String?)?.trim() ??
            (profile['sitter'] is Map
                ? (profile['sitter']['paypalEmail'] as String?)?.trim()
                : null);
      }
      if (existingEmail != null && existingEmail.isNotEmpty) return;

      if (_isShowingPayPalPrompt || Get.isDialogOpen == true) return;
      _isShowingPayPalPrompt = true;

      final textController = TextEditingController();
      final isSaving = false.obs;

      await Get.dialog(
        Obx(
          () => PayPalEmailDialog(
            controller: textController,
            title: 'payout_add_paypal_email_title'.tr,
            subtitle: 'payout_add_paypal_email_subtitle'.tr,
            primaryText: 'common_save'.tr,
            secondaryText: 'common_later'.tr,
            isLoading: isSaving.value,
            onSecondary: () => Get.back(),
            onPrimary: () async {
              final email = textController.text.trim();
              if (email.isEmpty) {
                CustomSnackbar.showError(
                  title: 'common_error',
                  message: 'snackbar_text_please_enter_your_paypal_email',
                );
                return;
              }

              if (isSaving.value) return;
              isSaving.value = true;
              try {
                await sitterRepo.updatePayPalPayoutEmail(paypalEmail: email);
                Get.back();
              } catch (e) {
                debugPrint('[HOPETSIT] ⚠️ Failed to set PayPal email: $e');
              } finally {
                isSaving.value = false;
              }
            },
          ),
        ),
        barrierDismissible: false,
      );

      WidgetsBinding.instance.addPostFrameCallback((_) {
        textController.dispose();
      });
    } catch (e) {
      debugPrint('[HOPETSIT] ⚠️ PayPal prompt failed: $e');
    } finally {
      _isShowingPayPalPrompt = false;
    }
  }

  // ignore: unused_element
  void _clearOwnerCachedData() {
    if (Get.isRegistered<ProfileController>()) {
      final c = Get.find<ProfileController>();
      c.profile.value = null;
      c.userName.value = '';
      c.phoneNumber.value = '';
      c.email.value = '';
      c.profileImageUrl.value = '';
    }
    if (Get.isRegistered<UserController>()) {
      final uc = Get.find<UserController>();
      uc.profile.value = null;
      uc.userProfile.clear();
    }
  }

  // ignore: unused_element
  void _clearSitterCachedData() {
    if (Get.isRegistered<SitterProfileController>()) {
      final c = Get.find<SitterProfileController>();
      c.profile.value = null;
      c.userName.value = '';
      c.phoneNumber.value = '';
      c.email.value = '';
      c.profileImageUrl.value = '';
    }
    if (Get.isRegistered<UserController>()) {
      final uc = Get.find<UserController>();
      uc.profile.value = null;
      uc.userProfile.clear();
    }
  }

  /// Clears any locally cached service selections so invalid services
  /// (e.g., Dog Walking for owners) do not persist across role switches.
  void _clearServiceSelections() {
    // Untagged controller (e.g. profile flow)
    if (Get.isRegistered<ChooseServiceController>()) {
      final c = Get.find<ChooseServiceController>();
      c.clearAllServices();
    }

    // Tagged controllers used in signup flows
    if (Get.isRegistered<ChooseServiceController>(tag: 'pet_owner')) {
      final ownerController = Get.find<ChooseServiceController>(
        tag: 'pet_owner',
      );
      ownerController.clearAllServices();
    }

    if (Get.isRegistered<ChooseServiceController>(tag: 'pet_sitter')) {
      final sitterController = Get.find<ChooseServiceController>(
        tag: 'pet_sitter',
      );
      sitterController.clearAllServices();
    }
  }

  // ignore: unused_element
  Future<void> _refreshOwnerData() async {
    if (Get.isRegistered<UserController>()) {
      await Get.find<UserController>().loadMyProfile();
    }
    if (Get.isRegistered<ProfileController>()) {
      final pc = Get.find<ProfileController>();
      await pc.loadMyProfile();
      await pc.loadBlockedUsers();
    }
    if (Get.isRegistered<HomeController>()) {
      await Get.find<HomeController>().loadSitters();
    }
  }

  // ignore: unused_element
  Future<void> _refreshSitterData() async {
    if (Get.isRegistered<SitterProfileController>()) {
      await Get.find<SitterProfileController>().loadMyProfile();
    }
    if (Get.isRegistered<PostsController>()) {
      final pc = Get.find<PostsController>();
      await pc.loadPostsWithoutMedia();
      await pc.loadMediaPosts();
    }
    if (Get.isRegistered<UserController>()) {
      await Get.find<UserController>().loadMyProfile();
    }
  }

  /// Logs out the user by clearing all stored data and navigating to login screen
  Future<void> logout() async {
    // v23.1 part 121 — Daniel : "le bug de qd jme connecte les anciens
    // payment reaparaisse dans la barre de notification est revenue ds
    // owner". Cause : les notifications locales restent dans la barre du
    // système même après logout. Quand un user se reconnecte, elles sont
    // toujours visibles, faisant croire que ce sont les notifs du nouveau
    // compte. On les efface MAINTENANT au début du logout.
    try {
      if (Get.isRegistered<PushNotificationService>()) {
        final push = Get.find<PushNotificationService>();
        await push.clearAllLocalNotifications();
        // Aussi : retirer le FCM token du backend pour ne plus recevoir
        // de push à destination de l'ancien compte sur ce device.
        await push.unregisterCurrentToken();
      }
    } catch (_) {
      // best-effort, le logout doit toujours réussir.
    }

    // Clear all stored authentication data
    // v23.1 part 125 — Phase 2 audit C4 : purge SecureTokenStore aussi.
    await SecureTokenStore.instance.clear();
    await _storage.remove(StorageKeys.authToken);
    await _storage.remove(StorageKeys.userProfile);
    await _storage.remove(StorageKeys.userRole);
    // v449 — purge le tint de rôle (sinon le thème resterait teinté du
    // dernier rôle après déconnexion).
    AppColors.activeRoleOverride = null;
    // Code promo "% de réduction" appliqué : compte-spécifique → on purge au
    // logout pour ne pas le réutiliser sur un autre compte.
    await _storage.remove(StorageKeys.redeemedPromoDiscount);
    // v23.1 — keep StorageKeys.dismissedBannerBookings across logout: the
    // stored values are MongoDB ObjectIds unique to a booking, so they
    // cannot leak between accounts. Clearing them caused the dismissed
    // banner to reappear after every logout/login cycle (Daniel's bug).

    // Clear controller state
    userRole.value = null;
    errorMessage.value = null;
    requiresEmailVerification.value = false;
    availableRoles.clear();

    // Clear form fields (but don't dispose - they'll be reused)
    emailController.clear();
    passwordController.clear();

    // Force-remove controllers that carry user-scoped cache. Without this,
    // logging out Owner "Daniel C" and logging back in as Walker "Aeps Pieces"
    // kept the ProfileController in memory with Daniel's name/email, which
    // showed up on the Walker profile tab while the Walker home tab (which
    // reads from a different source) showed the correct data. Deleting these
    // forces a clean re-init on next access.
    _forceDelete<UserController>();
    _forceDelete<ProfileController>();
    _forceDelete<SitterProfileController>();
    _forceDelete<HomeController>();
    _forceDelete<PostsController>();
    // v23.1 — clear bookings/applications/notifications/chat too. Without
    // these, after logout owner A → login owner B, Daniel saw owner A's
    // old reservations and payments cached in memory.
    _forceDelete<BookingsController>();
    _forceDelete<SitterBookingsController>();
    _forceDelete<WalkerBookingsController>();
    _forceDelete<ApplicationsController>();
    _forceDelete<NotificationsController>();
    _forceDelete<UnifiedNotificationController>();
    _forceDelete<ChatController>();
    // v23.1.397 — Daniel : « Session expirée » à la reconnexion. Le
    // SitterChatController résiduel relançait des requêtes avec le token
    // effacé → 401 → snackbar parasite. On le purge, et on COUPE le socket
    // (sinon il restait connecté avec l'ancien token + ses hooks).
    _forceDelete<SitterChatController>();
    try {
      if (Get.isRegistered<SocketService>()) {
        Get.find<SocketService>().resetForLogout();
      }
    } catch (_) {/* le logout doit toujours réussir */}

    // Navigate to login screen
    Get.offAll(() => const LoginScreen());
  }

  /// Safely delete a GetxController tag/instance if registered.
  /// force: true drops permanent-marked instances too.
  void _forceDelete<T>() {
    try {
      if (Get.isRegistered<T>()) {
        Get.delete<T>(force: true);
      }
    } catch (_) {
      // Swallow: logout must never fail because of a stale controller.
    }
  }

  /// Returns true when the given error message / status code indicates the
  /// user's session is invalid and they need to re-authenticate. Callers use
  /// this to know when to trigger [handleLoginRequiredError].
  static bool isLoginRequiredError(String? message, {int? statusCode}) {
    // v23.1 part 241 — Daniel : "chat walker ou sitter rien ne saffiche
    // sa met session expirer alors quon as labonement follow". Root
    // cause : on consideraIT 401 ET 403 comme "session expiree", mais
    // 403 = forbidden (PAYMENT_REQUIRED, NOT_PARTICIPANT, CHAT_ACCESS_
    // REQUIRED), PAS session expiree. Resultat : quand le backend
    // renvoyait 403 (chat 402/payment ou autre), l'app affichait
    // "Session expirée" + bouffait les messages → chat blank + demandes
    // pawfollow_request invisibles. Fix : on ne considere session
    // expiree QUE pour 401 (vrai unauthorized), et on laisse les 403
    // bubbler aux handlers dedies (le chat a deja son propre traitement
    // 403 lignes plus bas).
    if (statusCode == 401) return true;
    if (message == null) return false;
    final lower = message.toLowerCase();
    // Patterns explicites de session expiree (401-like) uniquement.
    // On ENLEVE 'unauthorized' et 'jwt' car trop genericS — un 403
    // backend qui mentionne "JWT verified" passait par ici a tort.
    return lower.contains('login required') ||
        lower.contains('please login') ||
        lower.contains('not authenticated') ||
        lower.contains('invalid token') ||
        lower.contains('token expired');
  }

  /// v23.1.154 — Daniel : "faite que lapli ne se ferme que si on met
  /// manuelment deconnecter". Avant : tout 401/403 entrainait un logout
  /// + redirection forcee vers LoginScreen — frustrant quand le token
  /// expire au milieu d'une session. Maintenant : on affiche juste un
  /// snackbar discret pour signaler le probleme, et on laisse l'user
  /// continuer (les ecrans qui ont besoin de l'API afficheront leurs
  /// propres erreurs gracieusement). Seul le bouton "Deconnecter" dans
  /// Profil declenche un vrai logout via `authController.logout()`.
  ///
  /// Note : ce changement evite aussi que l'app se "fermer" toute seule
  /// quand un appel API non critique tombe en 401. Pour les ecrans
  /// vraiment cassés (chat live qui se reconnecte sans cesse), la
  /// reconnexion silencieuse continuera de retry — ils peuvent toujours
  /// se deconnecter manuellement.
  static bool _sessionExpiredSnackShown = false;
  static Future<void> handleLoginRequiredError() async {
    try {
      // v23.1.397 — Daniel : « Session expirée » parasite à la
      // déconnexion. Si AUCUN token n'est stocké, c'est une déconnexion
      // volontaire (ou une requête résiduelle post-logout) → on n'affiche
      // PAS le snackbar.
      try {
        final tok = GetStorage().read<String>(StorageKeys.authToken);
        if (tok == null || tok.isEmpty) return;
      } catch (_) {/* en cas de doute, comportement inchangé */}
      if (_sessionExpiredSnackShown) return;
      _sessionExpiredSnackShown = true;
      // Show a one-shot warning. Don't logout, don't redirect.
      CustomSnackbar.showWarning(
        title: 'auth_session_expired_title'.tr,
        message: 'auth_session_expired_msg'.tr,
      );
      // Reset the lock after 30s so it can show again on next failure.
      Future.delayed(const Duration(seconds: 30), () {
        _sessionExpiredSnackShown = false;
      });
    } catch (_) {
      // Snackbar may fail if context unavailable — silently ignore.
      // Critical : we NEVER auto-logout here.
    }
  }

  /// v23.1.254 — Daniel : "joue le confort total". Refresh silencieux du
  /// token à expiration glissante. Tant que l'app est ouverte au moins une
  /// fois par an, le token (365j) ne périme jamais → plus JAMAIS de
  /// "Session expirée", et le socket temps réel (messages, demandes d'amis,
  /// notifs) reste vivant.
  ///
  /// Appelé silencieusement :
  ///   - au démarrage de l'app si une session est déjà stockée,
  ///   - au retour de background (lifecycle resumed).
  ///
  /// Best-effort : si le refresh échoue (token déjà périmé, réseau down,
  /// backend en cold start), on ne fait RIEN de bruyant — l'app continue
  /// avec le token courant et retentera au prochain resume. On ne déconnecte
  /// JAMAIS l'utilisateur ici.
  static bool _refreshInFlight = false;
  Future<bool> refreshToken() async {
    if (_refreshInFlight) return false;
    // Pas de refresh si aucune session stockée.
    final current = SecureTokenStore.instance.tokenSync ??
        _storage.read<String>(StorageKeys.authToken);
    if (current == null || current.isEmpty) return false;

    _refreshInFlight = true;
    try {
      final response = await _authRepository.refresh();
      final token = _extractToken(response);
      if (token == null || token.isEmpty) return false;

      // Persiste le token frais (Keychain/Keystore + miroir GetStorage).
      await SecureTokenStore.instance.writeToken(token);
      await _storage.write(StorageKeys.authToken, token);

      // CRUCIAL : propage le token frais au socket pour que le temps réel
      // survive (sinon les reconnexions auto utilisent l'ancien token).
      try {
        if (Get.isRegistered<SocketService>()) {
          await Get.find<SocketService>().updateAuthToken(token);
        }
      } catch (_) {/* socket pas prêt — sera connecté au besoin */}

      debugPrint('[HOPETSIT] ✅ Token rafraîchi (sliding 365j)');
      return true;
    } catch (e) {
      // Échec non critique : on log discret et on continue.
      debugPrint('[HOPETSIT] ⚠️ refreshToken (non-critique): $e');
      return false;
    } finally {
      _refreshInFlight = false;
    }
  }

  /// v23.1 part 146 — Bridge de session web → app via `hopetsit://auth?ott=...`.
  ///
  /// Appelée par `DeepLinkService._handleAuthOtt` après un exchange réussi
  /// avec le backend (POST /auth/exchange). La réponse doit contenir au
  /// minimum un JWT (`token`) et un rôle (`role`). On stocke tout comme un
  /// login email/password classique et on navigue vers le home du rôle.
  ///
  /// Effets de bord :
  ///   - Écrit le JWT dans SecureTokenStore + miroir GetStorage.
  ///   - Écrit le rôle + le profil utilisateur dans GetStorage.
  ///   - Re-enregistre le token FCM auprès du backend (push notifs).
  ///   - Reset les controllers user-scoped pour éviter le cache du compte
  ///     précédent.
  ///   - Navigation `Get.offAll(...)` vers BottomNavWrapper / SitterNavWrapper
  ///     / WalkerNavWrapper selon le rôle.
  ///
  /// Retourne `true` si l'auto-login a réussi, `false` sinon (le caller peut
  /// afficher un toast d'erreur). Ne jette JAMAIS d'exception — c'est volontaire,
  /// vu que cette méthode est invoquée depuis un deep link async non-awaité.
  Future<bool> applyExchangedSession(Map<String, dynamic> response) async {
    try {
      final token = _extractToken(response);
      if (token == null || token.isEmpty) {
        debugPrint('[HOPETSIT] applyExchangedSession: token missing');
        return false;
      }

      // 1) Token — keystore + miroir GetStorage (cf. flow login normal).
      await SecureTokenStore.instance.writeToken(token);
      await _storage.write(StorageKeys.authToken, token);

      // 2) Role — JWT-derived si possible, sinon top-level dans la réponse.
      final role = _extractRole(response);
      if (role != null && role.isNotEmpty) {
        userRole.value = role;
        await _storage.write(StorageKeys.userRole, role);
      } else {
        debugPrint(
          '[HOPETSIT] applyExchangedSession: role missing — abort to avoid stale nav',
        );
        return false;
      }
      // JWT reste la source de vérité même après stockage initial.
      _syncRoleFromJwt();

      // 3) FCM token — re-register sous la nouvelle auth, sinon les push
      // continuent à arriver pour l'ancien user.
      unawaited(_registerFcmTokenWithBackend());
      // v494 — Daniel : « mon ami espagnol reçoit notifs + emails en FR ».
      // CAUSE : appLocale n'était synchronisé qu'au chargement de l'accueil.
      // On pousse la langue UI (choisie OU langue du téléphone) DÈS le login →
      // notifications + emails partent dans la bonne langue (backend priorise
      // appLocale sur language). Guard _syncedThisSession = 1 seule fois/session.
      unawaited(LocalizationService.syncToBackend());

      // 4) User profile (optionnel — l'app peut le refetch via UserController).
      final userData = _extractUser(response);
      if (userData != null) {
        final withRole = Map<String, dynamic>.from(userData);
        withRole.putIfAbsent('role', () => role);
        await _saveUserProfile(withRole);
      }

      // 5) Navigation. _navigateToHome() reset déjà les controllers
      // user-scoped + clear les service selections avant d'offAll.
      _navigateToHome();

      debugPrint('[HOPETSIT] ✅ applyExchangedSession success (role=$role)');
      return true;
    } catch (e, st) {
      debugPrint('[HOPETSIT] applyExchangedSession failed: $e\n$st');
      return false;
    }
  }
}

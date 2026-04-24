import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../controllers/auth_controller.dart';
import '../controllers/notifications_controller.dart';
import '../controllers/subscription_controller.dart';
import '../controllers/user_controller.dart';
import '../data/network/api_client.dart';
import '../repositories/auth_repository.dart';
import '../repositories/chat_repository.dart';
import '../repositories/owner_repository.dart';
import '../repositories/pet_repository.dart';
import '../repositories/post_repository.dart';
import '../repositories/sitter_repository.dart';
import '../repositories/user_repository.dart';
import '../repositories/walker_repository.dart';
import '../repositories/notifications_repository.dart';
import '../services/socket_service.dart';
import '../services/push_notification_service.dart';

/// Registers shared dependencies with GetX's service locator.
void setupDependencies() {
  if (!Get.isRegistered<GetStorage>()) {
    Get.put<GetStorage>(GetStorage(), permanent: true);
  }

  if (!Get.isRegistered<ApiClient>()) {
    Get.put<ApiClient>(
      ApiClient(storage: Get.find<GetStorage>()),
      permanent: true,
    );
  }

  if (!Get.isRegistered<AuthRepository>()) {
    Get.put<AuthRepository>(
      AuthRepository(Get.find<ApiClient>()),
      permanent: true,
    );
  }

  if (!Get.isRegistered<UserRepository>()) {
    Get.put<UserRepository>(
      UserRepository(Get.find<ApiClient>()),
      permanent: true,
    );
  }

  if (!Get.isRegistered<PetRepository>()) {
    Get.put<PetRepository>(
      PetRepository(Get.find<ApiClient>()),
      permanent: true,
    );
  }

  if (!Get.isRegistered<PostRepository>()) {
    Get.put<PostRepository>(
      PostRepository(Get.find<ApiClient>()),
      permanent: true,
    );
  }

  if (!Get.isRegistered<OwnerRepository>()) {
    Get.put<OwnerRepository>(
      OwnerRepository(Get.find<ApiClient>()),
      permanent: true,
    );
  }

  if (!Get.isRegistered<SitterRepository>()) {
    Get.put<SitterRepository>(
      SitterRepository(Get.find<ApiClient>()),
      permanent: true,
    );
  }

  // Session v16-owner-walker — WalkerRepository is injected into
  // SendRequestController + sitter_homescreen to derive base price from
  // walkRates. Without this registration every "Envoyer la demande" tap
  // crashed with "WalkerRepository not found" on first use.
  if (!Get.isRegistered<WalkerRepository>()) {
    Get.put<WalkerRepository>(
      WalkerRepository(Get.find<ApiClient>()),
      permanent: true,
    );
  }

  if (!Get.isRegistered<ChatRepository>()) {
    Get.put<ChatRepository>(
      ChatRepository(Get.find<ApiClient>()),
      permanent: true,
    );
  }

  if (!Get.isRegistered<NotificationsRepository>()) {
    Get.put<NotificationsRepository>(
      NotificationsRepository(Get.find<ApiClient>()),
      permanent: true,
    );
  }

  if (!Get.isRegistered<SocketService>()) {
    Get.put<SocketService>(
      SocketService(storage: Get.find<GetStorage>()),
      permanent: true,
    );
  }

  if (!Get.isRegistered<UserController>()) {
    Get.put<UserController>(
      UserController(Get.find<UserRepository>()),
      permanent: true,
    );
  }

  if (!Get.isRegistered<AuthController>()) {
    Get.put<AuthController>(
      AuthController(
        Get.find<AuthRepository>(),
        Get.find<GetStorage>(),
        Get.find<UserRepository>(),
      ),
      permanent: true,
    );
  }

  // SubscriptionController is lazy-loaded — it calls GET /subscriptions/status
  // which requires an auth token. Registering it lazily means it only kicks in
  // when the user opens the Boutique / Premium tab or other premium-gated UI.
  if (!Get.isRegistered<SubscriptionController>()) {
    Get.lazyPut<SubscriptionController>(() => SubscriptionController(), fenix: true);
  }

  // v20.0.18 — CRITICAL FIX : NotificationsController doit être init AU BOOT
  // pour que les badges (unreadHome/unreadChat/unreadBookings) s'affichent
  // dès l'ouverture de l'app. Avant ce fix, le controller n'était jamais
  // enregistré nulle part → les badges restaient à 0 et le socket listener
  // `notification.new` ne s'attachait pas. Permanent pour survivre aux
  // redémarrages de route.
  if (!Get.isRegistered<NotificationsController>()) {
    Get.put<NotificationsController>(
      NotificationsController(),
      permanent: true,
    );
  }

  // v18.6 — FCM push notifications fix.
  // Avant v18.6, PushNotificationService existait mais n'était jamais init,
  // donc aucun token FCM n'était récupéré ni enregistré côté backend →
  // aucun push n'arrivait. On l'enregistre ici en async permanent et on
  // laisse son onInit() déclencher init() au bon moment.
  if (!Get.isRegistered<PushNotificationService>()) {
    Get.putAsync<PushNotificationService>(
      () async {
        final service = PushNotificationService();
        await service.init();
        return service;
      },
      permanent: true,
    );
  }
}

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/models/friendship_model.dart';

/// Friends + requests state + actions.
class FriendController extends GetxController {
  final RxBool isLoading = false.obs;
  final RxList<Friendship> friends = <Friendship>[].obs;
  final RxList<Friendship> incomingRequests = <Friendship>[].obs;
  final RxList<Friendship> outgoingRequests = <Friendship>[].obs;

  @override
  void onInit() {
    super.onInit();
    refresh();
  }

  @override
  Future<void> refresh() async {
    isLoading.value = true;
    try {
      await Future.wait([loadFriends(), loadRequests()]);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadFriends() async {
    try {
      final api = Get.find<ApiClient>();
      final data = await api.get('/friends', requiresAuth: true);
      final list = (data['friends'] as List?) ?? const [];
      friends.value = list
          .map((f) => Friendship.fromJson((f as Map).cast<String, dynamic>()))
          .toList();
    } catch (e) {
      debugPrint('[Friends] loadFriends error: $e');
    }
  }

  Future<void> loadRequests() async {
    try {
      final api = Get.find<ApiClient>();
      final data = await api.get('/friends/requests', requiresAuth: true);
      final incoming = (data['incoming'] as List?) ?? const [];
      final outgoing = (data['outgoing'] as List?) ?? const [];
      incomingRequests.value = incoming
          .map((f) => Friendship.fromJson((f as Map).cast<String, dynamic>()))
          .toList();
      outgoingRequests.value = outgoing
          .map((f) => Friendship.fromJson((f as Map).cast<String, dynamic>()))
          .toList();
    } catch (e) {
      debugPrint('[Friends] loadRequests error: $e');
    }
  }

  Future<bool> sendRequest(String targetId, String targetRole) async {
    try {
      final api = Get.find<ApiClient>();
      await api.post(
        '/friends/request',
        body: {'targetId': targetId, 'targetRole': targetRole},
        requiresAuth: true,
      );
      await loadRequests();
      return true;
    } catch (e) {
      debugPrint('[Friends] sendRequest error: $e');
      return false;
    }
  }

  Future<bool> accept(String friendshipId) async {
    try {
      final api = Get.find<ApiClient>();
      await api.post('/friends/$friendshipId/accept', requiresAuth: true);
      await refresh();
      return true;
    } catch (e) {
      debugPrint('[Friends] accept error: $e');
      return false;
    }
  }

  Future<bool> decline(String friendshipId) async {
    try {
      final api = Get.find<ApiClient>();
      await api.post('/friends/$friendshipId/decline', requiresAuth: true);
      incomingRequests.removeWhere((f) => f.id == friendshipId);
      return true;
    } catch (e) {
      debugPrint('[Friends] decline error: $e');
      return false;
    }
  }

  Future<bool> unfriend(String friendshipId) async {
    try {
      final api = Get.find<ApiClient>();
      await api.delete('/friends/$friendshipId', requiresAuth: true);
      friends.removeWhere((f) => f.id == friendshipId);
      return true;
    } catch (e) {
      debugPrint('[Friends] unfriend error: $e');
      return false;
    }
  }

  Future<bool> setSharePosition(String friendshipId, bool share) async {
    try {
      final api = Get.find<ApiClient>();
      final data = await api.post(
        '/friends/$friendshipId/share',
        body: {'share': share},
        requiresAuth: true,
      );
      final updatedJson = (data['friendship'] as Map?)?.cast<String, dynamic>();
      if (updatedJson != null) {
        final updated = Friendship.fromJson(updatedJson);
        final idx = friends.indexWhere((f) => f.id == friendshipId);
        if (idx != -1) {
          friends[idx] = updated;
          friends.refresh();
        }
      }
      return true;
    } catch (e) {
      debugPrint('[Friends] setSharePosition error: $e');
      return false;
    }
  }
}

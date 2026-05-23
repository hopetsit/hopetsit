import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/models/friendship_model.dart';
import 'package:hopetsit/services/socket_service.dart';

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
    // v23.1 part 205 — Daniel : "je ne vois pas où les demandes d'amis
    // arrivent" + "amis ajouter ma liste est vide". Avant, le frontend ne
    // recevait AUCUN event temps réel pour les demandes/acceptations →
    // il fallait kill l'app pour les voir. Maintenant on s'abonne aux
    // events socket émis par le backend (`friend_request:accepted` côté
    // accept route, + on refresh aussi sur `notification.new` du type
    // friend_request_*).
    _attachFriendSocketListeners();
  }

  void _attachFriendSocketListeners() {
    try {
      final s = Get.find<SocketService>();
      // Le pattern .off avant .on évite le leak listeners au reconnect
      // (cf. fix v205 dans socket_service.dart).
      s.socket?.off('friend_request:accepted');
      s.socket?.on('friend_request:accepted', (_) {
        debugPrint('[Friends] socket friend_request:accepted → refresh');
        refresh();
      });
      // notification.new couvre les 2 directions (received + accepted)
      // si les events directs sont manqués (offline → push notif).
      s.socket?.off('friend_request:received');
      s.socket?.on('friend_request:received', (_) {
        debugPrint('[Friends] socket friend_request:received → refresh');
        loadRequests();
      });
    } catch (e) {
      debugPrint('[Friends] could not attach socket listeners: $e');
    }
  }

  @override
  Future<void> refresh() async {
    isLoading.value = true;
    try {
      // v23.1.183 — charge aussi les invitations Famille pour que le
      // banner home + la cloche reflètent les pending invitations.
      await Future.wait([
        loadFriends(),
        loadRequests(),
        loadFamilyInvitations(),
      ]);
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

  /// v23.1.172 — Daniel : "quand je demande invitation amis sa met met
  /// erreur impossible". On retourne maintenant le message d'erreur brut
  /// du backend pour que l'UI puisse afficher la VRAIE raison (déjà ami,
  /// pending, network, etc.) au lieu d'un "Impossible" générique.
  ///
  /// Retourne :
  ///   - "" (string vide) si succès
  ///   - "ALREADY_PENDING" / "ALREADY_ACCEPTED" / "SELF" / message libre si échec
  Future<String> sendRequest(String targetId, String targetRole) async {
    try {
      final api = Get.find<ApiClient>();
      await api.post(
        '/friends/request',
        body: {'targetId': targetId, 'targetRole': targetRole},
        requiresAuth: true,
      );
      await loadRequests();
      return '';
    } catch (e) {
      debugPrint('[Friends] sendRequest error: $e');
      // ApiException expose le body : on essaie d'extraire le champ `error`
      final raw = e.toString();
      // ex. ApiException: Already in state "pending". (id: 671abc)
      final match = RegExp(r'Already in state "(\w+)"').firstMatch(raw);
      if (match != null) {
        final state = match.group(1);
        return state == 'accepted' ? 'ALREADY_ACCEPTED' : 'ALREADY_PENDING';
      }
      if (raw.contains('Cannot befriend yourself')) return 'SELF';
      // Sinon on renvoie le message brut (sans le préfixe ApiException:).
      return raw.replaceAll('ApiException:', '').trim();
    }
  }

  /// v23.1 part 69 — Bug 9 : search users by email or name to send a
  /// friend request. Backend returns up to 10 owners/sitters/walkers
  /// whose email or name match the query.
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    try {
      final api = Get.find<ApiClient>();
      final r = await api.get(
        '/friends/search?q=${Uri.encodeQueryComponent(query)}',
        requiresAuth: true,
      );
      final list = (r is Map && r['users'] is List) ? r['users'] as List : [];
      return list.whereType<Map>().map((u) => Map<String, dynamic>.from(u)).toList();
    } catch (e) {
      debugPrint('[Friends] searchUsers error: $e');
      return [];
    }
  }

  // ── v23.1.174 — Block / Unblock / Blocked users list ─────────────────
  //
  // Daniel : "Manque boutons Bloquer et Supprimer dans la liste d'amis".
  // Backend Block.js + blockRoutes.js + blockController.js existent déjà
  // et supportent les 3 rôles (owner/sitter/walker). On wrap ici.

  final RxList<Map<String, dynamic>> blockedUsers =
      <Map<String, dynamic>>[].obs;

  /// Bloque un user (POST /blocks). Retourne true en cas de succès.
  Future<bool> blockUser({
    required String targetUserId,
    required String targetRole,
  }) async {
    try {
      final api = Get.find<ApiClient>();
      await api.post(
        '/blocks',
        body: {
          'targetUserId': targetUserId,
          'targetRole': targetRole,
        },
        requiresAuth: true,
      );
      // Après block on retire l'ami de la liste amis (le backend ne le
      // fait pas auto — friendship reste mais devient inutilisable).
      await refresh();
      await loadBlocked();
      return true;
    } catch (e) {
      debugPrint('[Friends] blockUser error: $e');
      return false;
    }
  }

  /// Débloque un user (DELETE /blocks/:id). Retourne true en cas de succès.
  Future<bool> unblockUser(String targetUserId) async {
    try {
      final api = Get.find<ApiClient>();
      await api.delete(
        '/blocks/$targetUserId',
        requiresAuth: true,
      );
      await loadBlocked();
      return true;
    } catch (e) {
      debugPrint('[Friends] unblockUser error: $e');
      return false;
    }
  }

  /// Charge la liste des users que J'AI bloqués.
  Future<void> loadBlocked() async {
    try {
      final api = Get.find<ApiClient>();
      final r = await api.get('/blocks', requiresAuth: true);
      if (r is Map && r['blocks'] is List) {
        blockedUsers.assignAll(
          (r['blocks'] as List)
              .whereType<Map>()
              .map((b) => Map<String, dynamic>.from(b))
              .toList(),
        );
      }
    } catch (e) {
      debugPrint('[Friends] loadBlocked error: $e');
      blockedUsers.clear();
    }
  }

  // ── v23.1.172 — PawFollow Famille (5 membres tracking) ────────────────
  //
  // Daniel : "le truc de famille je le vois pas non plus". On expose les
  // 3 endpoints famille via le controller pour que friends_screen puisse
  // afficher l'onglet "Famille".

  final RxBool hasFamilyPlan = false.obs;
  final RxList<Map<String, dynamic>> familyMembers =
      <Map<String, dynamic>>[].obs;
  final RxInt familyRemainingSlots = 0.obs;

  /// Charge les membres de ma famille PawFollow.
  Future<void> loadFamily() async {
    try {
      final api = Get.find<ApiClient>();
      final r = await api.get('/friends/family/members', requiresAuth: true);
      if (r is Map) {
        hasFamilyPlan.value = r['hasActiveFamilyPlan'] == true;
        final list = (r['members'] is List) ? r['members'] as List : [];
        familyMembers.assignAll(
          list.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList(),
        );
        familyRemainingSlots.value = (r['remainingSlots'] as int?) ?? 0;
      }
    } catch (e) {
      debugPrint('[Friends] loadFamily error: $e');
      hasFamilyPlan.value = false;
      familyMembers.clear();
      familyRemainingSlots.value = 0;
    }
  }

  /// Ajoute un ami à ma famille. Retourne "" en cas de succès ou code erreur.
  Future<String> addFamilyMember({
    required String userId,
    required String userRole,
    String? email,
  }) async {
    try {
      final api = Get.find<ApiClient>();
      await api.post(
        '/friends/family/invite-member',
        body: {
          'userId': userId,
          'userRole': userRole,
          if (email != null && email.isNotEmpty) 'email': email,
        },
        requiresAuth: true,
      );
      await loadFamily();
      return '';
    } catch (e) {
      debugPrint('[Friends] addFamilyMember error: $e');
      final raw = e.toString();
      if (raw.contains('FAMILY_PLAN_REQUIRED')) return 'FAMILY_PLAN_REQUIRED';
      if (raw.contains('FAMILY_FULL')) return 'FAMILY_FULL';
      if (raw.contains('Already a family member')) return 'ALREADY_MEMBER';
      return raw.replaceAll('ApiException:', '').trim();
    }
  }

  /// v23.1.174 — Ajoute un membre famille par EMAIL (peut être un user
  /// HoPetSit OU un non-utilisateur qui recevra une invitation email).
  /// Retourne :
  ///   - 'existing_user' : email correspondait à un user, ajouté à family
  ///   - 'email_invite_sent' : email envoyé pour inscription parrainage
  ///   - code erreur sinon (FAMILY_PLAN_REQUIRED, FAMILY_FULL, etc.)
  Future<String> addFamilyMemberByEmail(String email) async {
    try {
      final api = Get.find<ApiClient>();
      final r = await api.post(
        '/friends/family/invite-by-email',
        body: {'email': email.trim()},
        requiresAuth: true,
      );
      await loadFamily();
      if (r is Map && r['mode'] is String) {
        return r['mode'] as String;
      }
      return 'existing_user';
    } catch (e) {
      debugPrint('[Friends] addFamilyMemberByEmail error: $e');
      final raw = e.toString();
      if (raw.contains('FAMILY_PLAN_REQUIRED')) return 'FAMILY_PLAN_REQUIRED';
      if (raw.contains('FAMILY_FULL')) return 'FAMILY_FULL';
      if (raw.contains('Already a family member')) return 'ALREADY_MEMBER';
      return raw.replaceAll('ApiException:', '').trim();
    }
  }

  /// Retire un ami de ma famille.
  Future<bool> removeFamilyMember(String userId) async {
    try {
      final api = Get.find<ApiClient>();
      await api.delete(
        '/friends/family/member/$userId',
        requiresAuth: true,
      );
      await loadFamily();
      return true;
    } catch (e) {
      debugPrint('[Friends] removeFamilyMember error: $e');
      return false;
    }
  }

  /// v23.1.170 — GET /friends/:id/track-access
  /// Renvoie { canTrack: bool, reason: 'family' | 'shared' | 'none' | 'no_friendship' }
  Future<Map<String, dynamic>> checkTrackAccess(String otherUserId) async {
    try {
      final api = Get.find<ApiClient>();
      final r = await api.get(
        '/friends/$otherUserId/track-access',
        requiresAuth: true,
      );
      if (r is Map) return Map<String, dynamic>.from(r);
      return {'canTrack': false, 'reason': 'unknown'};
    } catch (e) {
      debugPrint('[Friends] checkTrackAccess error: $e');
      return {'canTrack': false, 'reason': 'error'};
    }
  }

  // ── v23.1.183 — Family invitation accept/refuse flow ───────────────────
  // Daniel : "developpe le sous menu amis famislle pour accepter refuse
  // rbloquer les demande damis et famille". Avant on auto-ajoutait
  // direct en famille ; maintenant le destinataire reçoit une invitation
  // pending qu'il peut accepter ou refuser depuis la cloche.

  /// Charge mes invitations famille en attente (incoming).
  final RxList<Map<String, dynamic>> incomingFamilyInvitations =
      <Map<String, dynamic>>[].obs;

  Future<void> loadFamilyInvitations() async {
    try {
      final api = Get.find<ApiClient>();
      final r = await api.get(
        '/friends/family/invitations',
        requiresAuth: true,
      );
      if (r is Map && r['invitations'] is List) {
        incomingFamilyInvitations.assignAll(
          (r['invitations'] as List)
              .whereType<Map>()
              .map((i) => Map<String, dynamic>.from(i))
              .toList(),
        );
      }
    } catch (e) {
      debugPrint('[Friends] loadFamilyInvitations error: $e');
      incomingFamilyInvitations.clear();
    }
  }

  Future<bool> acceptFamilyInvitation(String invitationId) async {
    try {
      final api = Get.find<ApiClient>();
      await api.post(
        '/friends/family/invitation/$invitationId/accept',
        requiresAuth: true,
      );
      await loadFamily();
      await loadFamilyInvitations();
      return true;
    } catch (e) {
      debugPrint('[Friends] acceptFamilyInvitation error: $e');
      return false;
    }
  }

  Future<bool> refuseFamilyInvitation(String invitationId) async {
    try {
      final api = Get.find<ApiClient>();
      await api.post(
        '/friends/family/invitation/$invitationId/refuse',
        requiresAuth: true,
      );
      incomingFamilyInvitations
          .removeWhere((i) => (i['id'] ?? i['_id']) == invitationId);
      return true;
    } catch (e) {
      debugPrint('[Friends] refuseFamilyInvitation error: $e');
      return false;
    }
  }

  /// v23.1.200 — Daniel : "bouton 💬 sur friend + family member" qui
  /// ouvre un chat 1-to-1. POST /api/v1/conversations/friend crée ou
  /// retourne la conversation friendChat existante. Backend autorise
  /// si friendship 'accepted' OU même famille PawFollow.
  /// Retourne le conversationId ou null en cas d'echec.
  Future<String?> startFriendChat({
    required String targetUserId,
    required String targetUserRole,
  }) async {
    try {
      final api = Get.find<ApiClient>();
      final r = await api.post(
        '/conversations/friend',
        body: {
          'targetUserId': targetUserId,
          'targetUserRole': targetUserRole,
        },
        requiresAuth: true,
      );
      if (r is Map && r['conversation'] is Map) {
        final c = Map<String, dynamic>.from(r['conversation'] as Map);
        return (c['id'] ?? c['_id'])?.toString();
      }
      return null;
    } catch (e) {
      debugPrint('[Friends] startFriendChat error: $e');
      return null;
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

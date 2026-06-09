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
  // v23.1 part 226 — Daniel : "debloque le partage de position si jai
  // un abo paw follow". Mirroir client-side du flag /diagnose backend.
  // Lu par _FriendTile pour rendre la switch read-only-ON + badge.
  final RxBool viewerHasPawFollow = false.obs;

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
      // v23.1 part 242 — Daniel : "messages et demandes instantanement
      // sans avoir a mettre a jour". Avant : on attachait les listeners
      // UNE FOIS au onInit avec s.socket?.on(...) → si la socket n'etait
      // pas encore connectee (cold start), socket==null → listeners
      // jamais attaches. Pareil sur reconnect background→fg : les
      // listeners etaient perdus. Fix : on enregistre via
      // addOnConnectedHook → re-attache automatiquement a chaque (re)
      // connect socket. Bonus : si la socket est deja UP, addOnConnectedHook
      // fire le callback immediatement (cf SocketService impl).
      void wireFriendListeners() {
        final socket = s.socket;
        if (socket == null) return;
        socket.off('friend_request:accepted');
        socket.on('friend_request:accepted', (_) {
          debugPrint('[Friends] socket friend_request:accepted → refresh');
          refresh();
        });
        socket.off('friend_request:received');
        socket.on('friend_request:received', (_) {
          debugPrint('[Friends] socket friend_request:received → refresh');
          loadRequests();
        });
      }

      wireFriendListeners();
      s.addOnConnectedHook(wireFriendListeners);
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
    // v23.1 part 218 — meme strategie que loadRequests : on appelle
    // /friends/diagnose (qui marche prouve) et on filtre les accepted
    // en Dart pour bypasser tout bug potentiel dans /friends GET.
    try {
      final api = Get.find<ApiClient>();
      final diag = await api.get('/friends/diagnose', requiresAuth: true);
      final all = (diag is Map ? diag['friendships'] : null);
      // v23.1 part 226 — read viewerHasPawFollow root flag from backend
      // pour debloquer le partage automatique de ma position.
      if (diag is Map) {
        viewerHasPawFollow.value = diag['viewerHasPawFollow'] == true;
      }
      if (all is! List) {
        friends.value = [];
        return;
      }
      final acceptedRaw = <Map<String, dynamic>>[];
      for (final f in all) {
        if (f is! Map) continue;
        if ((f['status'] ?? '').toString() == 'accepted') {
          acceptedRaw.add(_diagToFriendshipPayload(f));
        }
      }
      debugPrint(
        '[Friends] loadFriends (diag) total=${all.length} accepted=${acceptedRaw.length}',
      );
      friends.value =
          acceptedRaw.map((f) => Friendship.fromJson(f)).toList();
    } catch (e) {
      debugPrint('[Friends] loadFriends error: $e');
    }
  }

  Future<void> loadRequests() async {
    // v23.1 part 218 — Daniel a vu via le diagnostic v214 que
    // /friends/diagnose retourne correctement la friendship pending
    // pour ALLO MOTEUR, mais /friends/requests retournait EMPTY (UI :
    // "Pas de demande en attente"). On a tente v215 (fetch all + filter
    // in JS) mais ca ne resout toujours pas.
    //
    // Solution finale : on appelle DIRECTEMENT /friends/diagnose (qui
    // marche prouve) et on filtre en DART pour les statuts pending +
    // direction. Plus aucun bug Mongo possible — on dedupe la logique.
    try {
      final api = Get.find<ApiClient>();
      // 1) Get my id+model via /whoami
      final whoami = await api.get('/friends/whoami', requiresAuth: true);
      final myId = (whoami is Map ? whoami['id'] : null)?.toString() ?? '';
      // 2) Get all friendships via /diagnose (which works)
      final diag = await api.get('/friends/diagnose', requiresAuth: true);
      final all = (diag is Map ? diag['friendships'] : null);
      if (all is! List) {
        incomingRequests.value = [];
        outgoingRequests.value = [];
        return;
      }
      // 3) Filter in Dart : status='pending' + direction
      final incomingRaw = <Map<String, dynamic>>[];
      final outgoingRaw = <Map<String, dynamic>>[];
      for (final f in all) {
        if (f is! Map) continue;
        if ((f['status'] ?? '').toString() != 'pending') continue;
        final iAmRequester = f['iAmRequester'] == true;
        final iAmAddressee = !iAmRequester &&
            (f['addresseeId'] ?? '').toString() == myId;
        if (iAmAddressee) {
          incomingRaw.add(_diagToFriendshipPayload(f));
        } else if (iAmRequester) {
          outgoingRaw.add(_diagToFriendshipPayload(f));
        }
      }
      debugPrint(
        '[Friends] loadRequests (diag) myId=$myId total=${all.length} '
        'incoming=${incomingRaw.length} outgoing=${outgoingRaw.length}',
      );
      incomingRequests.value = incomingRaw
          .map((f) => Friendship.fromJson(f))
          .toList();
      outgoingRequests.value = outgoingRaw
          .map((f) => Friendship.fromJson(f))
          .toList();
    } catch (e) {
      debugPrint('[Friends] loadRequests error: $e');
    }
  }

  /// v23.1 part 218 — convertit un doc de /friends/diagnose (qui a
  /// otherModel/otherId/otherName/otherExists au lieu de other:{...})
  /// vers le format attendu par Friendship.fromJson.
  Map<String, dynamic> _diagToFriendshipPayload(Map f) {
    final otherId = (f['otherId'] ?? '').toString();
    final otherModel = (f['otherModel'] ?? '').toString();
    final otherName = (f['otherName'] ?? '').toString();
    final otherExists = f['otherExists'] == true;
    // v23.1 part 222 — propage hasPawFollow depuis le payload diagnose
    // backend. Si vrai, ce contact apparait dans "Personnes en live"
    // meme sans theirSharePosition=true (partage auto entre amis PawFollow).
    final otherHasPawFollow = f['otherHasPawFollow'] == true;
    return {
      'id': f['friendshipId'],
      'status': f['status'],
      'initiatedByMe': f['iAmRequester'] == true,
      'other': otherExists
          ? {
              'id': otherId,
              'model': otherModel,
              'name': otherName.isEmpty
                  ? (otherExists ? 'Utilisateur' : 'Utilisateur supprimé')
                  : otherName,
              // v23.1.267 — avatar propagé depuis /diagnose (otherAvatar).
              'avatar': (f['otherAvatar'] ?? '').toString(),
              'city': '',
              'hasPawFollow': otherHasPawFollow,
              // v23.1.280 — tier PawSpot pour l'anneau doré/bleu sur l'avatar.
              'pawSpotTier': (f['otherPawSpotTier'] ?? '').toString(),
            }
          : {
              'id': '',
              'model': otherModel.isEmpty ? 'Owner' : otherModel,
              'name': 'Utilisateur supprimé',
              'avatar': '',
              'city': '',
              'hasPawFollow': false,
            },
      // v23.1 part 226 — Daniel : "debloque le partage si jai un abo
      // paw follow". Si MOI j'ai PawFollow actif (mirroir de la valeur
      // root de /diagnose), mySharePosition est force a true cote UI :
      // ma position est partagee a tous mes amis automatiquement.
      'mySharePosition': viewerHasPawFollow.value,
      'myShareAutoByPawFollow': viewerHasPawFollow.value,
      // v23.1 part 222 — si l'ami a PawFollow actif, on considere qu'il
      // partage sa position avec moi (logique PawFollow Family).
      'theirSharePosition': otherHasPawFollow,
      'createdAt': f['createdAt'],
      'acceptedAt': f['acceptedAt'],
    };
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
        // v23.1 part 210 — Daniel : "le bug amis persiste il me dis deja
        // amis et jai personne ds la liste". AUTO-HEAL : si on detecte
        // un ALREADY_* mais que la liste accepted est vide, c'est un
        // friendship zombie. On purge automatiquement via reset-with
        // puis on retente une fois. Si la 2eme demande passe, l'UX est
        // seamless pour le user.
        final state = match.group(1);
        await loadFriends();
        if (friends.isEmpty) {
          debugPrint(
            '[Friends] ALREADY_$state but friends list EMPTY → auto-heal + retry',
          );
          final healed = await resetWith(targetId, targetRole);
          if (healed) {
            try {
              final api = Get.find<ApiClient>();
              await api.post(
                '/friends/request',
                body: {'targetId': targetId, 'targetRole': targetRole},
                requiresAuth: true,
              );
              await loadRequests();
              return '';
            } catch (retryErr) {
              debugPrint('[Friends] retry after reset failed: $retryErr');
            }
          }
        }
        return state == 'accepted' ? 'ALREADY_ACCEPTED' : 'ALREADY_PENDING';
      }
      if (raw.contains('Cannot befriend yourself')) return 'SELF';
      // Sinon on renvoie le message brut (sans le préfixe ApiException:).
      return raw.replaceAll('ApiException:', '').trim();
    }
  }

  /// v23.1 part 210 — Escape hatch pour le bug "deja amis + liste vide".
  /// Supprime cote backend TOUS les docs Friendship entre user courant
  /// et target, peu importe leur status. Permet de repartir d'une feuille
  /// blanche apres un etat zombie.
  /// targetRole doit etre 'owner' | 'sitter' | 'walker' (la route convertit
  /// en PascalCase pour le model).
  Future<bool> resetWith(String targetId, String targetRole) async {
    try {
      final api = Get.find<ApiClient>();
      final targetModel = targetRole.isEmpty
          ? 'Owner'
          : (targetRole[0].toUpperCase() + targetRole.substring(1).toLowerCase());
      await api.post(
        '/friends/reset-with/$targetId/$targetModel',
        body: {},
        requiresAuth: true,
      );
      debugPrint('[Friends] resetWith $targetModel:$targetId — done');
      return true;
    } catch (e) {
      debugPrint('[Friends] resetWith error: $e');
      return false;
    }
  }

  /// v23.1 part 214 — Diagnostic friend bug. Appelle GET /friends/whoami
  /// + GET /friends/diagnose et retourne un Map combine. Le frontend
  /// affiche ca dans un AlertDialog pour que Daniel puisse comparer
  /// son cote vs cote ALLO MOTEUR et trouver l'incompatibilite.
  Future<Map<String, dynamic>?> diagnose() async {
    try {
      final api = Get.find<ApiClient>();
      final whoami = await api.get('/friends/whoami', requiresAuth: true);
      final diag = await api.get('/friends/diagnose', requiresAuth: true);
      return {
        'whoami': whoami is Map ? whoami : {},
        'diagnose': diag is Map ? diag : {},
      };
    } catch (e) {
      debugPrint('[Friends] diagnose error: $e');
      return null;
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
  // v23.1.281 — Daniel : "je n'arrive pas à ajouter de membre famille". Cause :
  // il est MEMBRE d'une famille (pas titulaire) → seul le titulaire peut
  // ajouter/retirer. On distingue les 2 états pour afficher la bonne UI.
  //   - isFamilyHolder=true  → titulaire : UI "Inviter un membre".
  //   - isFamilyHolder=false → membre   : bannière "Tu es dans la famille de X".
  final RxBool isFamilyHolder = false.obs;
  final Rxn<Map<String, dynamic>> familyHolder = Rxn<Map<String, dynamic>>();

  /// Charge les membres de ma famille PawFollow.
  Future<void> loadFamily() async {
    try {
      final api = Get.find<ApiClient>();
      final r = await api.get('/friends/family/members', requiresAuth: true);
      if (r is Map) {
        hasFamilyPlan.value = r['hasActiveFamilyPlan'] == true;
        // v23.1.281 — défaut true si le backend ne renvoie pas encore isHolder
        // (Render pas redéployé) → on ne casse pas l'UI titulaire existante.
        isFamilyHolder.value = r.containsKey('isHolder')
            ? r['isHolder'] == true
            : true;
        familyHolder.value = (r['holder'] is Map)
            ? Map<String, dynamic>.from(r['holder'] as Map)
            : null;
        final list = (r['members'] is List) ? r['members'] as List : [];
        familyMembers.assignAll(
          list.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList(),
        );
        familyRemainingSlots.value = (r['remainingSlots'] as int?) ?? 0;
      }
    } catch (e) {
      debugPrint('[Friends] loadFamily error: $e');
      hasFamilyPlan.value = false;
      isFamilyHolder.value = false;
      familyHolder.value = null;
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
  /// v23.1.329 — Daniel : "le bouton retirer membre famille marche pas". AVANT
  /// on renvoyait juste un bool → en cas d'échec, ÉCHEC SILENCIEUX (aucun
  /// message). Maintenant on renvoie l'erreur (null = succès, sinon message)
  /// pour que l'UI l'affiche ET on guard l'id vide.
  Future<String?> removeFamilyMember(String userId) async {
    if (userId.trim().isEmpty) return 'ID du membre introuvable.';
    try {
      final api = Get.find<ApiClient>();
      await api.delete(
        '/friends/family/member/$userId',
        requiresAuth: true,
      );
      await loadFamily();
      return null;
    } catch (e) {
      debugPrint('[Friends] removeFamilyMember error: $e');
      return e.toString().replaceAll('ApiException:', '').trim();
    }
  }

  /// v23.1.282 — Un MEMBRE quitte la famille dont il fait partie. Le débloque
  /// pour devenir son propre titulaire (ou être réinvité ailleurs).
  Future<bool> leaveFamily() async {
    try {
      final api = Get.find<ApiClient>();
      await api.post('/friends/family/leave', body: {}, requiresAuth: true);
      await loadFamily();
      return true;
    } catch (e) {
      debugPrint('[Friends] leaveFamily error: $e');
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
      // v23.1 part 244 — Daniel : "qd je clic sur licone message que sa
      // ouvre un chat entre moi et la personne". Log explicite pour
      // diagnostiquer si le bouton message ne donne rien : on logue le
      // payload envoye + la reponse exacte, pour qu'on puisse voir cote
      // Render pourquoi le 403/500 si ca arrive.
      debugPrint(
        '[Friends] startFriendChat target=$targetUserId role=$targetUserRole',
      );
      final r = await api.post(
        '/conversations/friend',
        body: {
          'targetUserId': targetUserId,
          'targetUserRole': targetUserRole,
        },
        requiresAuth: true,
      );
      debugPrint('[Friends] startFriendChat response=$r');
      if (r is Map && r['conversation'] is Map) {
        final c = Map<String, dynamic>.from(r['conversation'] as Map);
        final id = (c['id'] ?? c['_id'])?.toString();
        debugPrint('[Friends] startFriendChat resolved convId=$id');
        return id;
      }
      debugPrint('[Friends] startFriendChat response had no conversation map');
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

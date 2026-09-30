// v605 (ZOE, 30/09/2026) — Daniel (vocal) : « quand je suis dans le chat, si
// je clique sur ton nom, si je suis ton ami, que je puisse voir ta position en
// direct sur la carte ».
//
// Appui sur le NOM ou la PHOTO de l'en-tête d'une discussion (propriétaire,
// gardien, promeneur) :
//   · AMI (amitié acceptée, n'importe lequel de ses rôles — même source que la
//     PawMap : `FriendController.friends` / `FriendProfile.matchesId`, qui
//     couvre `personIds`) → ONGLET PawMap du menu (menu jamais masqué), même
//     chemin que la liste d'amis (`pawMapFriendFocusFor` → `openPawMapOnFriend`) :
//       - en direct (couche amis : partage actif, n'importe lequel de ses
//         ids) → la carte vole sur lui et le SUIT ;
//       - sinon → centrée sur sa position de profil (floutée, rayon approxKm) ;
//       - « Masqué » / sans position → pastille « Cet ami n'est pas visible
//         sur la carte », pas de changement d'onglet ;
//   · PAS AMI → comportement inchangé depuis v569 : fiche « Ajouter en ami /
//     Bloquer » (`showChatPeerSheet`).
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/friend_controller.dart';
import 'package:hopetsit/models/friendship_model.dart';
import 'package:hopetsit/services/live_map_service.dart';
import 'package:hopetsit/utils/map_ui_state.dart';
import 'package:hopetsit/views/chat_shared/chat_peer_sheet.dart';
import 'package:hopetsit/views/chat_shared/chat_session.dart';
import 'package:hopetsit/views/chat_shared/chat_theme.dart';
import 'package:hopetsit/views/friends/tabs/friends_ui.dart';
import 'package:hopetsit/views/map/pawmap_friend_focus.dart';

/// Ce qu'a fait l'appui sur l'en-tête (lu par les tests).
enum ChatPeerTapOutcome {
  /// Ami → onglet PawMap (ou pastille « pas visible sur la carte »).
  friendMap,

  /// Pas ami → fiche « Ajouter en ami / Bloquer ».
  peerSheet,

  /// Correspondant inconnu (très vieille conversation) : rien.
  none,
}

/// Correspondant (id + rôle) de [conversationId] ; vide si inconnu.
({String id, String role}) chatPeerOf(ChatSession session, String conversationId) {
  for (final c in session.conversationsRx) {
    if (c.id == conversationId) return (id: c.contactId, role: c.contactRole);
  }
  return (id: '', role: '');
}

/// Profil de l'AMI [peerId] (amitié acceptée, tous ses rôles) ; null sinon.
FriendProfile? chatPeerFriend(Iterable<Friendship> friends, String peerId) {
  if (peerId.trim().isEmpty) return null;
  for (final f in friends) {
    final o = f.other;
    if (f.status == 'accepted' && o != null && o.matchesId(peerId)) return o;
  }
  return null;
}

/// Appui sur le nom / la photo de l'en-tête d'une discussion.
Future<ChatPeerTapOutcome> onChatPeerTap(
  BuildContext context, {
  required ChatSession session,
  required String conversationId,
  required String contactName,
  required String contactImage,
  required ChatRoleTheme theme,
}) async {
  final peer = chatPeerOf(session, conversationId);
  if (peer.id.isEmpty) return ChatPeerTapOutcome.none;

  final FriendController fc = Get.isRegistered<FriendController>()
      ? Get.find<FriendController>()
      : Get.put(FriendController());
  var friend = chatPeerFriend(fc.friends, peer.id);
  // Liste pas encore chargée depuis le chat : on la lit (3 s max) avant de
  // décider, pour ne pas proposer « Ajouter en ami » à un ami.
  if (friend == null && (fc.friends.isEmpty || fc.isLoading.value)) {
    try {
      await fc.loadFriends().timeout(const Duration(seconds: 3));
    } catch (_) {/* réseau lent : on décide avec ce qu'on a */}
    friend = chatPeerFriend(fc.friends, peer.id);
  }

  if (friend != null) {
    // Même cible que la liste d'amis (couche amis 587) : son direct (n'importe
    // lequel de ses ids) sinon sa position de PROFIL floutée ; jamais une
    // position exacte hors direct. `FriendProfile` du chat : nom / photo de
    // l'en-tête si la liste n'en a pas.
    final profile = friend.copyWith(
      avatar: friend.avatar.isEmpty ? contactImage : null,
    );
    final LiveMapService? live =
        Get.isRegistered<LiveMapService>() ? Get.find<LiveMapService>() : null;
    final focus = pawMapFriendFocusFor(profile,
        live: pawMapLivePositionOf(
            profile, live?.friendPositions ?? const <String, FriendPosition>{}));
    if (focus == null) {
      showFriendNotOnMap(context.mounted ? context : null);
    } else {
      openPawMapOnFriend(focus);
    }
    return ChatPeerTapOutcome.friendMap;
  }

  if (!context.mounted) return ChatPeerTapOutcome.none;
  unawaited(showChatPeerSheet(
    context,
    session: session,
    conversationId: conversationId,
    contactName: contactName,
    contactImage: contactImage,
    theme: theme,
  ));
  return ChatPeerTapOutcome.peerSheet;
}

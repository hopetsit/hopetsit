// v566 — Daniel : « les boutons dans Messages "Suivre en direct" plus jolis, et
// vérifie que tout est bien traduit, branché, fonctionnel ».
//
//  • PawFollowPill : pilule violette PawFollow (#7C3AED, dégradé doux, icône
//    blanche, ombre colorée). Quand un suivi est EN COURS : point vert animé
//    et libellé « En direct · voir la carte ».
//  • showPawFollowRequestSheet : feuille de demande (carte contact, explication
//    courte, bouton principal, état d'envoi, erreurs lisibles avec bouton vers
//    la boutique quand PawFollow / une réservation est nécessaire).
//  • pawFollowIsLive : vrai si la conversation porte une demande ACCEPTÉE
//    encore valable.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/controllers/chat_controller.dart';
import 'package:hopetsit/controllers/sitter_chat_controller.dart';
import 'package:hopetsit/services/live_map_service.dart';
import 'package:hopetsit/utils/map_ui_state.dart';
import 'package:hopetsit/views/map/pawmap_friend_focus.dart';
import 'package:hopetsit/views/map/widgets/pawmap_live_sheet.dart';
import 'package:hopetsit/services/live_share_starter.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/bottom_inset.dart';
import 'package:hopetsit/views/boost/coin_shop_screen.dart';
import 'package:hopetsit/views/chat_shared/chat_avatar.dart';
import 'package:hopetsit/views/chat_shared/chat_models.dart';
import 'package:hopetsit/views/chat_shared/pawfollow_state604.dart';
import 'package:hopetsit/widgets/app_dialog_kit.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';

/// Violet PawFollow (CLAUDE.md « Marque »).
const Color kPawFollowPurple = Color(0xFF7C3AED);
const Color kPawFollowPurpleSoft = Color(0xFF9B6BF5);
const Color kPawFollowPurpleDark = Color(0xFF6D28D9);
const Color kPawFollowLive = Color(0xFF22C55E);

/// Violet clair réservé au MODE SOMBRE : `kPawFollowPurple` en texte ou en
/// bordure sur un fond sombre tombe sous le seuil de lisibilité.
const Color kPawFollowPurpleOnDark = Color(0xFFC4B5FD);

const LinearGradient kPawFollowGradient = LinearGradient(
  colors: [kPawFollowPurpleSoft, kPawFollowPurple, kPawFollowPurpleDark],
  stops: [0.0, 0.55, 1.0],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

/// Dernière demande PawFollow ACCEPTÉE encore valable, ou null.
/// Valable = fin de garde dans le futur, ou (sans date de fin) acceptée il y a
/// moins de 12 h — une vieille carte ne doit pas afficher « En direct ».
ChatMessageBase? pawFollowLiveMessage(Iterable<ChatMessageBase> messages) {
  final now = DateTime.now();
  ChatMessageBase? found;
  for (final m in messages) {
    if (!m.isPawfollowRequest || m.isDeleted) continue;
    if (m.pawfollowStatus != 'accepted') continue;
    final end = m.pawfollowEndAt;
    final ok = end != null
        ? end.isAfter(now)
        : now.difference(m.timestamp).inHours < 12;
    if (ok) found = m;
  }
  return found;
}

bool pawFollowIsLive(Iterable<ChatMessageBase> messages) =>
    pawFollowLiveMessage(messages) != null;

// ───────── v603 (ZOE) — la pilule du chat à l'état RÉEL du partage ─────────
// Daniel (29/09) : la pilule « En direct · voir la carte » restait affichée
// après l'arrêt du direct. Elle ne regardait que la demande ACCEPTÉE (moins
// de 12 h), jamais le partage lui-même. Désormais :
//   • c'est MA position qui est suivie → mon direct réel (ce téléphone ou mon
//     autre téléphone), la même vérité que le bouton Balade de la PawMap et
//     la carte du chat du 602 ; arrêté → « Relancer le direct » ;
//   • c'est l'AUTRE qui partage → son direct tel que la PawMap le reçoit
//     (socket `map:friend-position` / `map:friend-offline`) ; arrêté ou
//     invisible pour moi → « Direct arrêté · redemander ».

/// État affiché par la pilule PawFollow d'une conversation.
enum PawFollowLiveStatus {
  /// Aucune demande acceptée en cours : pilule « Suivre » / « Partager ».
  none,

  /// Le partage de position tourne : « En direct · voir la carte ».
  live,

  /// Demande acceptée mais le partage est arrêté.
  stopped,
}

/// Règle PURE (testée). [peerLive] = l'autre partage-t-il ? null = inconnu
/// (sa position ne m'arrive pas : pour moi, rien n'est en direct).
PawFollowLiveStatus pawFollowLiveStatus({
  required bool accepted,
  required bool iShare,
  required bool myLive,
  required bool? peerLive,
}) {
  if (!accepted) return PawFollowLiveStatus.none;
  if (iShare) return myLive ? PawFollowLiveStatus.live : PawFollowLiveStatus.stopped;
  return peerLive == true ? PawFollowLiveStatus.live : PawFollowLiveStatus.stopped;
}

/// Ids de l'AUTRE personne d'une demande PawFollow (expéditeur, répondant,
/// contact de la conversation). Vide si inconnu.
Set<String> pawFollowPeerIds(ChatMessageBase m, {String contactId = ''}) {
  final md = m.metadata;
  final ids = <String>{
    if (contactId.isNotEmpty) contactId,
    if (!m.isFromCurrentUser) ...[
      m.senderId,
      (md['requesterId'] ?? '').toString(),
    ] else
      (md['respondedBy'] ?? '').toString(),
  };
  return ids
      .where((e) => e.trim().isNotEmpty)
      .map((e) => e.trim().toLowerCase())
      .toSet();
}

/// L'autre personne partage-t-elle sa position en ce moment (en direct ou
/// signal perdu depuis moins de 10 min) ? null = aucune position reçue.
/// Lue dans un `Obx` : suit les événements socket du direct.
bool? pawFollowPeerLiveNow(LiveMapService live, Set<String> peerIds) {
  if (peerIds.isEmpty) return null;
  // Abonne l'Obx au minuteur « signal perdu » (toutes les 30 s).
  live.staleTick.value;
  for (final fp in live.friendPositions.values) {
    if (fp.allIds.any(peerIds.contains)) {
      return fp.liveState != FriendLiveState.seen;
    }
  }
  return null;
}

/// État RÉEL de la pilule pour la conversation (à appeler dans un `Obx`).
PawFollowLiveStatus pawFollowLiveStatusFor(
  Iterable<ChatMessageBase> messages, {
  String contactId = '',
}) {
  final accepted = pawFollowLiveMessage(messages);
  if (accepted == null) return PawFollowLiveStatus.none;
  final iShare = pawfollowSharerIsMe(
    requesterRole: accepted.pawfollowRequesterRole,
    isMine: accepted.isFromCurrentUser,
  );
  if (!Get.isRegistered<LiveMapService>()) {
    return PawFollowLiveStatus.stopped;
  }
  final live = Get.find<LiveMapService>();
  final myLive = live.broadcasting.value || live.liveElsewhere.value;
  return pawFollowLiveStatus(
    accepted: true,
    iShare: iShare,
    myLive: myLive,
    peerLive: iShare
        ? null
        : pawFollowPeerLiveNow(
            live, pawFollowPeerIds(accepted, contactId: contactId)),
  );
}

/// Construit [build] avec MON direct réel et celui de l'AUTRE personne de la
/// demande [m] (null = inconnu), reconstruit à chaque événement du direct.
///
/// v604 (ZOE) — avec [conversationId], l'état SERVEUR du sens de cette
/// demande s'ajoute (socket `pawfollow:state` + relecture) : l'autre n'est
/// « en direct » que si le serveur le dit ET que la PawMap ne dit pas le
/// contraire ; ma position ne part « en direct » que si ce sens est encore
/// suivi côté serveur.
Widget pawFollowWithLiveState(
  ChatMessageBase m, {
  String contactId = '',
  String conversationId = '',
  required Widget Function(bool myLive, bool? peerLive) build,
}) {
  if (!Get.isRegistered<LiveMapService>()) return build(false, null);
  final live = Get.find<LiveMapService>();
  return Obx(() {
    bool myLive = live.broadcasting.value || live.liveElsewhere.value;
    bool? peerLive =
        pawFollowPeerLiveNow(live, pawFollowPeerIds(m, contactId: contactId));
    final PawFollowConvState? s = conversationId.isEmpty
        ? null
        : PawFollowStateStore.states[conversationId];
    if (s != null) {
      if (s.outgoing.messageId == m.id && !s.outgoing.following) {
        myLive = false;
      }
      if (s.incoming.messageId == m.id) {
        peerLive = s.incoming.live && peerLive != false;
      }
    }
    return build(myLive, peerLive);
  });
}

/// v604 (ZOE) — « Arrêter de suivre » / « Arrêter mon direct » depuis la
/// carte du chat, avec confirmation.
///   · je SUIS l'autre ([iShare] false) : le serveur ne termine QUE ce sens
///     (POST /conversations/:id/pawfollow/stop, scope 'following') ; mon
///     propre direct et le sens inverse d'un suivi mutuel restent intacts ;
///   · c'est MA position ([iShare] true) : j'arrête mon direct (même chemin
///     que la PawMap) ; le serveur termine alors les suivis de ma position,
///     jamais mon suivi de l'autre.
Future<void> pawFollowConfirmStop(
  BuildContext context, {
  required String conversationId,
  required String messageId,
  required bool iShare,
}) async {
  await showAppConfirmDialog(
    context,
    title: iShare
        ? 'chat604_stop_live_title'.tr
        : 'chat604_stop_following_title'.tr,
    message: iShare
        ? 'chat604_stop_live_msg'.tr
        : 'chat604_stop_following_msg'.tr,
    confirmLabel:
        iShare ? 'chat604_stop_my_live'.tr : 'chat604_stop_following'.tr,
    cancelLabel: 'common_cancel'.tr,
    destructive: true,
    icon: iShare
        ? Icons.location_disabled_rounded
        : Icons.visibility_off_rounded,
    accent: kPawFollowPurple,
    onConfirm: () async {
      try {
        if (iShare) {
          if (Get.isRegistered<LiveMapService>()) {
            await Get.find<LiveMapService>().stopEverywhere();
          }
          // Relecture : l'arrêt est traité côté serveur en < 1 s.
          unawaited(Future<void>.delayed(const Duration(milliseconds: 900),
              () => PawFollowStateStore.refresh(conversationId)));
          CustomSnackbar.showSuccess(
              title: 'chat604_stopped_live'.tr, message: '');
        } else {
          await PawFollowStateStore.stop(conversationId,
              scope: 'following', messageId: messageId);
          CustomSnackbar.showSuccess(
              title: 'chat604_stopped_following'.tr, message: '');
        }
      } catch (_) {
        CustomSnackbar.showError(
            title: 'chat604_stop_error'.tr, message: '');
      }
    },
  );
}

/// v605 (ZOE) — Daniel (30/09) : « tout le direct passe par le bouton
/// Balade ». Les arrêts du chat (« Arrêter de suivre », « Arrêter mon
/// direct ») passent TOUS par cette fonction unique, que BOB reliera à la
/// feuille « En direct » de PAM (ma balade / ceux que je suis / ceux qui me
/// suivent). Tant qu'elle n'est pas reliée : la confirmation du 604, qui
/// arrête le bon sens côté serveur.
Future<void> openLiveSheetFromChat(
  BuildContext context, {
  required String conversationId,
  required String messageId,
  required bool iShare,
}) {
  // v605 (PAM) — BRANCHEMENT 605 fait : la feuille unique « En direct »
  // (`showPawLiveSheet`, pawmap_live_sheet.dart). Mon direct (iShare) : la
  // ligne « Ma balade → Arrêter » de la feuille ; si ce téléphone ne sait pas
  // encore que je diffuse (état serveur seul), la confirmation du 604 qui
  // arrête côté serveur. Suivi (suiveur) : la ligne « Tu suis … → Arrêter de
  // suivre », qui termine CE sens côté serveur (PawFollowStateStore.stop).
  final LiveMapService? live =
      Get.isRegistered<LiveMapService>() ? Get.find<LiveMapService>() : null;
  if (live == null || (iShare && !live.meLive.value)) {
    return pawFollowConfirmStop(context,
        conversationId: conversationId, messageId: messageId, iShare: iShare);
  }
  final peer = _chatPeerOf(conversationId);
  if (!iShare && peer.$1.isEmpty && live.followingUserId.value == null) {
    // Correspondant introuvable (liste pas encore chargée) : l'arrêt serveur
    // de CE sens, sans feuille vide.
    return pawFollowConfirmStop(context,
        conversationId: conversationId, messageId: messageId, iShare: iShare);
  }
  return showPawLiveSheet(
    context,
    chatFollow: iShare || peer.$1.isEmpty
        ? null
        : PawLiveChatFollow(
            userId: peer.$1,
            name: peer.$2,
            avatar: peer.$3,
            onStop: () async {
              try {
                await PawFollowStateStore.stop(conversationId,
                    scope: 'following', messageId: messageId);
                CustomSnackbar.showSuccess(
                    title: 'chat604_stopped_following'.tr, message: '');
              } catch (_) {
                CustomSnackbar.showError(
                    title: 'chat604_stop_error'.tr, message: '');
              }
            },
          ),
    onFollowFriend: (fp) => openPawMapOnFriend(PawMapFriendFocus(
      userId: fp.userId,
      role: fp.role.isEmpty ? 'owner' : fp.role,
      name: fp.name,
      avatar: fp.avatar,
      lat: fp.latitude,
      lng: fp.longitude,
      live: true,
      personIds: fp.personIds,
    )),
  ).then((_) {
    // Relecture de l'état par sens (l'arrêt est traité en < 1 s).
    unawaited(Future<void>.delayed(const Duration(milliseconds: 900),
        () => PawFollowStateStore.refresh(conversationId)));
  });
}

/// v605 — (id, nom, photo) du correspondant d'une conversation, lus dans
/// les listes de conversations déjà chargées (propriétaire ou prestataire).
(String, String, String) _chatPeerOf(String conversationId) {
  final lists = <Iterable<ChatConversationBase>>[
    if (Get.isRegistered<ChatController>()) Get.find<ChatController>().conversations,
    if (Get.isRegistered<SitterChatController>())
      Get.find<SitterChatController>().conversations,
  ];
  for (final l in lists) {
    for (final c in l) {
      if (c.id == conversationId) return (c.contactId, c.contactName, c.contactImage);
    }
  }
  return ('', '', '');
}

/// v604 (ZOE) — pilule d'en-tête : ce qu'elle montre et la demande concernée.
class PawFollowHeader {
  const PawFollowHeader(this.kind, this.message);
  final PawFollowHeaderKind kind;

  /// Demande du sens affiché (null si inconnue dans les messages chargés).
  final ChatMessageBase? message;

  bool get live =>
      kind == PawFollowHeaderKind.peerLive || kind == PawFollowHeaderKind.myLive;
  bool get stopped =>
      kind == PawFollowHeaderKind.peerStopped ||
      kind == PawFollowHeaderKind.myStopped;
}

/// v604 (ZOE) — état de la pilule d'en-tête, lu dans un `Obx` : l'état
/// SERVEUR par sens de la conversation (jamais un cache seul), croisé avec
/// mon direct local et ce que la PawMap reçoit de l'autre. Tant que le
/// serveur n'a pas répondu : la règle du 603 (demande acceptée + direct réel).
PawFollowHeader pawFollowHeaderFor(
  Iterable<ChatMessageBase> messages, {
  required String conversationId,
  String contactId = '',
}) {
  final LiveMapService? live =
      Get.isRegistered<LiveMapService>() ? Get.find<LiveMapService>() : null;
  final bool myLive =
      live != null && (live.broadcasting.value || live.liveElsewhere.value);
  final PawFollowConvState? s = PawFollowStateStore.states[conversationId];
  ChatMessageBase? byId(String id) {
    if (id.isEmpty) return null;
    for (final m in messages) {
      if (m.id == id) return m;
    }
    return null;
  }

  if (s != null) {
    final inc = byId(s.incoming.messageId);
    final bool? peerLocal = live == null
        ? null
        : pawFollowPeerLiveNow(
            live,
            inc == null
                ? {if (contactId.isNotEmpty) contactId.toLowerCase()}
                : pawFollowPeerIds(inc, contactId: contactId));
    final kind =
        pawFollowHeaderKind(s, myLive: myLive, peerLiveLocal: peerLocal);
    final bool isIncoming = kind == PawFollowHeaderKind.peerLive ||
        kind == PawFollowHeaderKind.peerStopped;
    return PawFollowHeader(
        kind, isIncoming ? inc : byId(s.outgoing.messageId));
  }

  // Repli (serveur pas encore lu) : règle du 603.
  final accepted = pawFollowLiveMessage(messages);
  if (accepted == null) return const PawFollowHeader(PawFollowHeaderKind.none, null);
  final bool iShare = pawfollowSharerIsMe(
    requesterRole: accepted.pawfollowRequesterRole,
    isMine: accepted.isFromCurrentUser,
  );
  final st = pawFollowLiveStatusFor(messages, contactId: contactId);
  final PawFollowHeaderKind kind = switch (st) {
    PawFollowLiveStatus.none => PawFollowHeaderKind.none,
    PawFollowLiveStatus.live =>
      iShare ? PawFollowHeaderKind.myLive : PawFollowHeaderKind.peerLive,
    PawFollowLiveStatus.stopped =>
      iShare ? PawFollowHeaderKind.myStopped : PawFollowHeaderKind.peerStopped,
  };
  return PawFollowHeader(kind, accepted);
}

/// Id du contact de la conversation [conversationId] (vide si inconnu).
String pawFollowContactId(
    Iterable<ChatConversationBase> conversations, String conversationId) {
  for (final c in conversations) {
    if (c.id == conversationId) return c.contactId;
  }
  return '';
}

/// Point vert qui pulse (suivi en cours).
class PawFollowLiveDot extends StatefulWidget {
  const PawFollowLiveDot({super.key, this.size = 8});
  final double size;

  @override
  State<PawFollowLiveDot> createState() => _PawFollowLiveDotState();
}

class _PawFollowLiveDotState extends State<PawFollowLiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return SizedBox(
      width: s * 2,
      height: s * 2,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          final t = Curves.easeInOut.transform(_c.value);
          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: s + s * t,
                height: s + s * t,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: kPawFollowLive.withValues(alpha: 0.35 * (1 - t)),
                ),
              ),
              child!,
            ],
          );
        },
        child: Container(
          width: s,
          height: s,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: kPawFollowLive,
            border: Border.all(color: Colors.white, width: 1.2),
          ),
        ),
      ),
    );
  }
}

/// Pilule violette PawFollow (en-tête de la discussion).
class PawFollowPill extends StatelessWidget {
  const PawFollowPill({
    super.key,
    required this.label,
    required this.onTap,
    this.icon = Icons.my_location_rounded,
    this.live = false,
    this.maxWidth,
    this.stoppedLabel,
    this.stoppedIcon = Icons.replay_rounded,
  });

  /// Libellé hors suivi (« Suivre en direct mon animal », « Partager ma position »).
  final String label;
  final VoidCallback onTap;
  final IconData icon;

  /// true = suivi EN COURS → point vert + « En direct · voir la carte ».
  final bool live;
  final double? maxWidth;

  /// v603 — demande acceptée mais partage ARRÊTÉ : ce libellé (« Relancer le
  /// direct » / « Direct arrêté · redemander ») et [stoppedIcon], jamais le
  /// point vert.
  final String? stoppedLabel;
  final IconData stoppedIcon;

  @override
  Widget build(BuildContext context) {
    final bool stopped = !live && stoppedLabel != null;
    final text = live ? 'cs_pf_live_open'.tr : (stoppedLabel ?? label);
    final radius = BorderRadius.circular(999);
    return Padding(
      padding: EdgeInsets.only(right: 4.w),
      child: Center(
        child: Semantics(
          button: true,
          label: text,
          child: Container(
            constraints: BoxConstraints(maxWidth: maxWidth ?? 168.w),
            decoration: BoxDecoration(
              gradient: kPawFollowGradient,
              borderRadius: radius,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.85),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: kPawFollowPurple.withValues(alpha: 0.38),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: radius,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onTap();
                },
                child: Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: 11.w, vertical: 6.h),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (live)
                        const PawFollowLiveDot(size: 7)
                      else
                        Icon(stopped ? stoppedIcon : icon,
                            size: 15.sp, color: Colors.white),
                      SizedBox(width: 5.w),
                      Flexible(
                        // v583 (lot A, capture de Daniel : « Suivre en direct
                        // m… ») — JAMAIS coupé : 2 lignes coupées à l'espace,
                        // aucun « … » ; libellés courts cs_pf_pill_* (9 langues).
                        child: InterText(
                          text: text,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.visible,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bouton principal violet (feuille de demande, carte « Suivi actif »).
class PawFollowPrimaryButton extends StatelessWidget {
  const PawFollowPrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon = Icons.my_location_rounded,
    this.busy = false,
    this.live = false,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData icon;
  final bool busy;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !busy;
    final radius = BorderRadius.circular(18.r);
    return Opacity(
      opacity: enabled || busy ? 1 : 0.55,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 52),
        decoration: BoxDecoration(
          gradient: kPawFollowGradient,
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: kPawFollowPurple.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled
                ? () {
                    HapticFeedback.lightImpact();
                    onTap!();
                  }
                : null,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (busy)
                    SizedBox(
                      width: 18.sp,
                      height: 18.sp,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  else if (live)
                    const PawFollowLiveDot(size: 8)
                  else
                    Icon(icon, color: Colors.white, size: 20.sp),
                  SizedBox(width: 9.w),
                  Flexible(
                    child: InterText(
                      text: label,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

bool _dark(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

/// Rouge d'erreur lisible sur les deux fonds (valeur claire inchangée).
Color _errorFg(BuildContext context) =>
    _dark(context) ? const Color(0xFFF87171) : AppColors.errorColor;

/// Violet PawFollow en texte / bordure (valeur claire inchangée).
Color _pfPurpleFg(BuildContext context) =>
    _dark(context) ? kPawFollowPurpleOnDark : kPawFollowPurple;

/// Erreur lisible d'une demande de suivi.
class _PfError {
  const _PfError(this.title, this.body, {this.shop = false});
  final String title;
  final String body;
  final bool shop;
}

_PfError _mapPawFollowError(Object e) {
  final raw = e.toString();
  final low = raw.toLowerCase();
  final status = e is ApiException ? e.statusCode : null;
  if (e is NetworkUnreachableException) {
    return _PfError('cs_pf_err_network_title'.tr, 'cs_send_failed_body'.tr);
  }
  if (raw.contains('TRACKING_ENDED') || low.contains('service is over')) {
    return _PfError(
      'tracking_service_over_title'.tr,
      'tracking_service_over_msg'.tr,
      shop: true,
    );
  }
  if (status == 402 ||
      low.contains('pawfollow_required') ||
      low.contains('subscription')) {
    return _PfError('cs_pf_err_sub_title'.tr, 'cs_pf_err_sub_body'.tr,
        shop: true);
  }
  if (status == 403 ||
      low.contains('not paid') ||
      low.contains('paid booking') ||
      low.contains('payment required')) {
    return _PfError('cs_pf_err_booking_title'.tr, 'cs_pf_err_booking_body'.tr,
        shop: true);
  }
  final detail = e is ApiException ? e.message : raw;
  return _PfError(
    'follow_unavailable_title'.tr,
    detail.length > 160 ? detail.substring(0, 160) : detail,
  );
}

/// Feuille de demande PawFollow. `onSend` LÈVE en cas d'échec (l'erreur est
/// affichée dans la feuille) ; renvoie true si la demande est partie.
Future<bool> showPawFollowRequestSheet(
  BuildContext context, {
  required String contactName,
  required String contactImage,
  required Future<void> Function() onSend,
  bool sharing = false,
  String petName = '',
}) async {
  final sent = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.card(context),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
    ),
    builder: (sheet) => _PawFollowRequestSheet(
      contactName: contactName,
      contactImage: contactImage,
      onSend: onSend,
      sharing: sharing,
      petName: petName,
    ),
  );
  return sent == true;
}

class _PawFollowRequestSheet extends StatefulWidget {
  const _PawFollowRequestSheet({
    required this.contactName,
    required this.contactImage,
    required this.onSend,
    required this.sharing,
    required this.petName,
  });

  final String contactName;
  final String contactImage;
  final Future<void> Function() onSend;
  final bool sharing;
  final String petName;

  @override
  State<_PawFollowRequestSheet> createState() => _PawFollowRequestSheetState();
}

class _PawFollowRequestSheetState extends State<_PawFollowRequestSheet> {
  bool _sending = false;
  bool _sent = false;
  _PfError? _error;

  Future<void> _send() async {
    if (_sending || _sent) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.onSend();
      if (!mounted) return;
      setState(() {
        _sending = false;
        _sent = true;
      });
      HapticFeedback.mediumImpact();
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = _mapPawFollowError(e);
      });
    }
  }

  Widget _step(BuildContext context, IconData icon, String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26.w,
            height: 26.w,
            decoration: BoxDecoration(
              color: kPawFollowPurple
                  .withValues(alpha: _dark(context) ? 0.22 : 0.12),
              borderRadius: BorderRadius.circular(9.r),
            ),
            child: Icon(icon, size: 15.sp, color: _pfPurpleFg(context)),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 3.h),
              child: InterText(
                text: text,
                fontSize: 12.5.sp,
                color: AppColors.textSecondary(context),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sharing = widget.sharing;
    final err = _error;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20.w,
        10.h,
        20.w,
        // v569 — clavier ouvert : son inset remplace celui de la barre
        // système ; sinon on ajoute le dégagement bas de l'app.
        18.h +
            (MediaQuery.of(context).viewInsets.bottom > 0
                ? MediaQuery.of(context).viewInsets.bottom
                : appBottomInset(context)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 42.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: AppColors.greyColor.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(4.r),
              ),
            ),
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Container(
                width: 40.w,
                height: 40.w,
                decoration: BoxDecoration(
                  gradient: kPawFollowGradient,
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: Icon(
                  sharing
                      ? Icons.share_location_rounded
                      : Icons.my_location_rounded,
                  color: Colors.white,
                  size: 21.sp,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: PoppinsText(
                  text: sharing
                      ? 'cs_pf_sheet_title_share'.tr
                      : 'cs_pf_sheet_title_follow'.tr,
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary(context),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          // Carte contact
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: kPawFollowPurple.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(18.r),
              border: Border.all(
                color: kPawFollowPurple.withValues(alpha: 0.18),
              ),
            ),
            child: Row(
              children: [
                ChatAvatar(imageUrl: widget.contactImage, size: 46),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PoppinsText(
                        text: widget.contactName,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      InterText(
                        text: widget.petName.isNotEmpty
                            ? 'cs_pf_sheet_with_pet'
                                .trParams({'pet': widget.petName})
                            : (sharing
                                ? 'cs_pf_sheet_contact_share'.tr
                                : 'cs_pf_sheet_contact_follow'.tr),
                        fontSize: 12.sp,
                        color: AppColors.textSecondary(context),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),
          _step(
            context,
            Icons.send_rounded,
            sharing ? 'cs_pf_step_share_1'.tr : 'cs_pf_step_follow_1'.tr,
          ),
          _step(context, Icons.verified_user_rounded, 'cs_pf_step_2'.tr),
          _step(context, Icons.map_rounded, 'cs_pf_step_3'.tr),
          if (err != null) ...[
            SizedBox(height: 6.h),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                // Encart d'erreur : voile un peu plus dense et rouge éclairci
                // en mode sombre (le rouge d'origine y est illisible).
                color: AppColors.errorColor
                    .withValues(alpha: _dark(context) ? 0.16 : 0.08),
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(
                  color: AppColors.errorColor.withValues(alpha: 0.25),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InterText(
                    text: err.title,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w800,
                    color: _errorFg(context),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 3.h),
                  InterText(
                    text: err.body,
                    fontSize: 12.sp,
                    color: AppColors.textPrimary(context),
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                    height: 1.35,
                  ),
                  if (err.shop) ...[
                    SizedBox(height: 8.h),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop(false);
                        Get.to(() => const CoinShopScreen(initialTab: 1));
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _pfPurpleFg(context),
                        side: BorderSide(color: _pfPurpleFg(context)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14.r),
                        ),
                      ),
                      icon: Icon(Icons.storefront_rounded, size: 17.sp),
                      label: Text(
                        'cs_pf_go_shop'.tr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          SizedBox(height: 14.h),
          if (_sent)
            // Pastille de succès : en sombre le vert foncé sur un voile vert
            // très pâle passait sous le seuil de lisibilité → vert éclairci.
            Builder(builder: (ctx) {
              final isDark = Theme.of(ctx).brightness == Brightness.dark;
              final okGreen =
                  isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A);
              return Container(
                width: double.infinity,
                padding:
                    EdgeInsets.symmetric(vertical: 14.h, horizontal: 14.w),
                decoration: BoxDecoration(
                  color: kPawFollowLive
                      .withValues(alpha: isDark ? 0.18 : 0.12),
                  borderRadius: BorderRadius.circular(18.r),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_rounded,
                        color: okGreen, size: 20.sp),
                    SizedBox(width: 8.w),
                    Flexible(
                      child: InterText(
                        text: 'cs_pf_sent'.tr,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w800,
                        color: okGreen,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            })
          else
            PawFollowPrimaryButton(
              label: _sending
                  ? 'cs_pf_sending'.tr
                  : (err != null
                      ? 'chat_retry'.tr
                      : (sharing
                          ? 'cs_pf_cta_share'.tr
                          : 'cs_pf_cta_follow'.tr)),
              icon: sharing
                  ? Icons.share_location_rounded
                  : Icons.my_location_rounded,
              busy: _sending,
              onTap: _send,
            ),
          SizedBox(height: 6.h),
          Center(
            child: TextButton(
              onPressed:
                  _sending ? null : () => Navigator.of(context).pop(false),
              child: Text(
                'common_cancel'.tr,
                style: TextStyle(
                  color: AppColors.textSecondary(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

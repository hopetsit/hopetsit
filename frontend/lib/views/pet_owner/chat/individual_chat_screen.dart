import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/controllers/chat_controller.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/repositories/chat_repository.dart';
import 'package:hopetsit/repositories/owner_repository.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/storage_keys.dart';
import 'package:hopetsit/models/booking_model.dart';
import 'package:hopetsit/views/map/paw_map_screen.dart';
import 'package:hopetsit/views/pet_owner/chat/tracking_request_sheet.dart';
// v23.1 part 240 — LiveWalkMapScreen import retire : "Voir la carte" du
// chat n'utilise plus l'ancienne carte "suivre balade" mais ouvre la
// PawMap avec halo vert (walker) / bleu (sitter) automatique via
// focusUserId. La LiveWalkMapScreen reste pour d'autres flows (notif
// push -> deep link bookingId) mais le chat l'a abandonnee.
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:hopetsit/views/chat_shared/chat_composer.dart';
import 'package:hopetsit/views/chat_shared/chat_conversation_body.dart';
import 'package:hopetsit/views/chat_shared/chat_gates.dart';
import 'package:hopetsit/views/chat_shared/chat_header.dart';
import 'package:hopetsit/views/chat_shared/chat_models.dart';
import 'package:hopetsit/views/chat_shared/chat_theme.dart';
import 'package:hopetsit/views/chat_shared/contacts_locked_sheet.dart';
import 'package:hopetsit/views/chat_shared/pawfollow_widgets.dart';
import 'package:hopetsit/widgets/pawfollow_request_card.dart';
import 'package:hopetsit/widgets/app_text.dart';

class IndividualChatScreen extends StatefulWidget {
  final String conversationId;
  final String contactName;
  final String contactImage;

  const IndividualChatScreen({
    super.key,
    required this.conversationId,
    required this.contactName,
    required this.contactImage,
  });

  @override
  State<IndividualChatScreen> createState() => _IndividualChatScreenState();
}

class _IndividualChatScreenState extends State<IndividualChatScreen> {
  late ChatController chatController;
  late TextEditingController _localMessageController;
  VoidCallback? _sharedControllerListener;

  /// v500 — Daniel : « le clavier s'ouvre mais se referme en une demi-
  /// seconde ». FocusNode STABLE possédé par le State : sans lui, le
  /// TextField gérait son focus en interne et un rebuild déclenché ~0,5 s
  /// après l'ouverture (fin du rechargement réseau, resync badge, événement
  /// socket) pouvait le faire sauter → clavier fermé. Ce nœud survit à
  /// TOUS les rebuilds.
  final FocusNode _inputFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Ensure ChatController is properly initialized
    if (!Get.isRegistered<ChatController>()) {
      final chatRepository = Get.find<ChatRepository>();
      final storage = Get.find<GetStorage>();
      Get.put(ChatController(chatRepository, storage: storage));
    }

    chatController = Get.find<ChatController>();

    // Create a local controller that syncs with the shared one
    // Use a safe approach to get initial text
    String initialText = '';
    try {
      initialText = chatController.messageController.text;
    } catch (e) {
      // Controller might be disposed, use empty string
      initialText = '';
    }

    _localMessageController = TextEditingController(text: initialText);

    // Sync changes from local to shared controller
    _localMessageController.addListener(() {
      if (mounted) {
        try {
          if (chatController.messageController.text !=
              _localMessageController.text) {
            chatController.messageController.text =
                _localMessageController.text;
          }
        } catch (e) {
          // Controller might be disposed, ignore
        }
      }
    });

    // Sync changes from shared to local controller (when cleared after sending)
    _sharedControllerListener = () {
      if (mounted) {
        try {
          if (chatController.messageController.text.isEmpty &&
              _localMessageController.text.isNotEmpty) {
            _localMessageController.clear();
          }
        } catch (e) {
          // Controller might be disposed, ignore
        }
      }
    };

    // Only add listener if controller is still valid
    try {
      chatController.messageController.addListener(_sharedControllerListener!);
    } catch (e) {
      // If adding listener fails, controller is disposed - we'll work with local controller only
      _sharedControllerListener = null;
    }
    // Set contact information in controller
    chatController.setContactInfo(widget.contactName, widget.contactImage);
    // Load messages after the build is complete to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Always reload messages when entering the screen to ensure fresh data
        chatController.loadChatMessages(
          widget.conversationId,
          contactName: widget.contactName,
          contactImage: widget.contactImage,
        );
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload messages when screen becomes visible again
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // v500 — didChangeDependencies se déclenche AUSSI quand le CLAVIER
      // s'ouvre (MediaQuery change). Si l'utilisateur est en train d'écrire,
      // on ne recharge JAMAIS (le rechargement faisait sauter le focus →
      // clavier refermé « tout seul »).
      if (_inputFocusNode.hasFocus) return;
      if (mounted &&
          chatController.currentChatId.value != widget.conversationId) {
        chatController.setContactInfo(widget.contactName, widget.contactImage);
        chatController.loadChatMessages(
          widget.conversationId,
          contactName: widget.contactName,
          contactImage: widget.contactImage,
        );
      }
    });
  }

  @override
  void dispose() {
    // Remove listener to prevent memory leaks
    if (_sharedControllerListener != null) {
      try {
        chatController.messageController.removeListener(
          _sharedControllerListener!,
        );
      } catch (e) {
        // Controller might already be disposed, ignore
      }
    }
    _localMessageController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  // v23.1 part 68 — Bug 13 : "Suivre" button handler.
  // Looks up the most recent active paid booking with this contact, then
  // calls /bookings/:id/provider-location. Handles 4 cases :
  //   200      → opens PawMap (live location of the provider)
  //   402      → CoinShop tab 1 (PawFollow upsell)
  //   204      → snackbar "Le prestataire n'a pas encore partagé sa
  //              position"
  //   no book  → snackbar "Aucune réservation active à suivre"
  // v23.1.176 — Daniel : "demande suivre votre animale ds le chat ya pas".
  // Carte custom pour les messages type='pawfollow_request' qui affiche :
  //  - Icône + texte explicatif
  //  - Statut courant (pending / accepted / refused)
  //  - Si pending ET je suis le responder → boutons Accepter / Refuser
  // v23.1 part 200 — Daniel : "refonte carte chat pawfollow_request"
  // (mockup avec pet card top + dates orange + section GPS + badge statut +
  // boutons accept/refuse). Avant : on rendait une carte interne minimale
  // ici. Maintenant : on délègue au widget partagé `PawfollowRequestCard`
  // (qui est déjà utilisé côté sitter) — UI cohérente sur les 2 profils.
  // Le widget consomme directement le snapshot enrichi par le backend
  // (petName, petPhoto, startAt, endAt, lastLat/Lng, serviceType).
  Widget _buildPawfollowRequestCard(
    ChatMessage message,
    ChatController controller,
  ) {
    final myRole =
        (Get.find<GetStorage>().read<String>(StorageKeys.userRole) ?? 'owner')
            .toLowerCase();
    // v23.1 part 206 — Daniel : "qd la demande accepte japuis sur le
    // bouton ds le chat et sa menvoi sur la geoloc du walker/sitter sur
    // mon animal". Si la demande est accepted, on expose un onOpenMap.
    // v23.1 part 207 — Daniel screenshot : le bouton n'apparaissait pas
    // sur ses vieux messages accepted car bookingId vide dans metadata
    // (messages créés AVANT le snapshot backend v200). Fallback :
    //   - Si bookingId présent → LiveWalkMapScreen(bookingId)
    //   - Sinon → on resolve le booking via _onSuivreTap (fuzzy match
    //     sur le nom du contact, déjà utilisé pour le bouton "Suivre"
    //     du header). Au pire on ouvre la PawMap globale.
    // v23.1 part 209 — Daniel : "page blanche pas de balade" quand on tap
    // le bouton "Voir sur la carte". Cause : LiveWalkMapScreen ne montre
    // rien si /walks/active retourne null (le walker n'a pas démarré de
    // balade explicite). Fix : on passe AUSSI le snapshot lat/lng du
    // metadata du message → LiveWalkMapScreen fait du fallback (cf v209
    // dans live_walk_map_screen.dart).
    final fallbackLat = message.pawfollowLastLat;
    final fallbackLng = message.pawfollowLastLng;
    // v23.1 part 239 — Daniel : "voir la carte sa mouvre la carte google
    // dans la ville au lieu de mouvrir le paw map sur la position excat
    // du sitter". Root cause = fallbackLat/Lng du metadata du message
    // sont fixes au moment de la creation du message (souvent null ou
    // ville). On refresh la position FRESH via /conversations/:id/
    // peer-position qui lit User.location.coordinates mise a jour par
    // mapSocket toutes les 10s. resolvedLat/Lng overrides fallback si dispo.
    // v23.1 part 240 — Daniel : "quand on met voir la carte pour quoi tu
    // met suivre balade une nouvelle map au lieu dutiliser la paw map et
    // je vois le halo vert si c un walker ou halo bleu si c un sitter".
    // On abandonne LiveWalkMapScreen ici. resolveFresh() ne retourne plus
    // juste lat/lng, mais aussi peerId + peerRole, pour que la PawMap
    // injecte une FriendPosition synthetique et dessine le halo couleur.
    Future<({double? lat, double? lng, String? peerId, String? peerRole})> resolveFresh() async {
      try {
        final api = Get.find<ApiClient>();
        final r = await api.get(
          '/conversations/${widget.conversationId}/peer-position',
          requiresAuth: true,
        );
        if (r is Map) {
          final rLat = r['lat'];
          final rLng = r['lng'];
          final pid = r['peerId']?.toString();
          final prole = r['peerRole']?.toString();
          if (rLat is num && rLng is num) {
            return (
              lat: rLat.toDouble(),
              lng: rLng.toDouble(),
              peerId: pid,
              peerRole: prole,
            );
          }
          // Pas de coords mais on a peerId/role → on retourne quand meme.
          return (lat: null, lng: null, peerId: pid, peerRole: prole);
        }
      } catch (_) {/* defensive */}
      return (lat: fallbackLat, lng: fallbackLng, peerId: null, peerRole: null);
    }

    VoidCallback? openMap;
    if (message.pawfollowStatus == 'accepted') {
      openMap = () async {
        // v23.1 part 240 — on resolve fresh + on ouvre TOUJOURS la PawMap
        // (plus de LiveWalkMapScreen). focusUserId/Role injecte une
        // FriendPosition synthetique dans LiveMapService → halo vert
        // (walker) / bleu (sitter) automatique.
        final fresh = await resolveFresh();
        final useLat = fresh.lat ?? fallbackLat;
        final useLng = fresh.lng ?? fallbackLng;
        Get.to(() => PawMapScreen(
              initialLat: useLat,
              initialLng: useLng,
              focusUserId: fresh.peerId,
              focusUserRole: fresh.peerRole,
              focusUserName: widget.contactName,
            ));
      };
    }
    return PawfollowRequestCard(
      messageId: message.id,
      requesterRole: message.pawfollowRequesterRole,
      responderRole: message.pawfollowResponderRole,
      status: message.pawfollowStatus,
      myRole: myRole,
      onAccept: () => _respondPawfollow(message, 'accept'),
      onRefuse: () => _respondPawfollow(message, 'refuse'),
      onOpenMap: openMap,
      // v566 — réponse en cours (boutons figés) + expiration.
      busy: _respondingIds.contains(message.id),
      expiresAt: message.pawfollowExpiresAt,
      // v23.1 part 200 — snapshot booking
      petName: message.pawfollowPetName,
      petPhoto: message.pawfollowPetPhoto,
      startAt: message.pawfollowStartAt,
      endAt: message.pawfollowEndAt,
      lastLat: message.pawfollowLastLat,
      lastLng: message.pawfollowLastLng,
      serviceType: message.pawfollowServiceType,
    );
  }

  // v566 — réponses Accepter / Refuser en cours (anti double-tap).
  final Set<String> _respondingIds = <String>{};

  /// v566 — pilule d'en-tête « En direct · voir la carte » : ouvre la PawMap
  /// centrée sur le correspondant (position fraîche via peer-position).
  Future<void> _openLiveMap(ChatMessageBase message) async {
    double? lat = message.pawfollowLastLat;
    double? lng = message.pawfollowLastLng;
    String? peerId;
    String? peerRole;
    try {
      final r = await Get.find<ApiClient>().get(
        '/conversations/${widget.conversationId}/peer-position',
        requiresAuth: true,
      );
      if (r is Map) {
        if (r['lat'] is num && r['lng'] is num) {
          lat = (r['lat'] as num).toDouble();
          lng = (r['lng'] as num).toDouble();
        }
        peerId = r['peerId']?.toString();
        peerRole = r['peerRole']?.toString();
      }
    } catch (_) {/* on ouvre quand même la carte */}
    if (!mounted) return;
    Get.to(() => PawMapScreen(
          initialLat: lat,
          initialLng: lng,
          focusUserId: peerId,
          focusUserRole: peerRole,
          focusUserName: widget.contactName,
        ));
  }

  Future<void> _respondPawfollow(
    ChatMessage message,
    String action,
  ) async {
    if (_respondingIds.contains(message.id)) return;
    setState(() => _respondingIds.add(message.id));
    try {
      final repo = Get.find<OwnerRepository>();
      await repo.respondPawfollowRequest(
        messageId: message.id,
        action: action,
      );
      if (!mounted) return;
      CustomSnackbar.showSuccess(
        title: action == 'accept'
            ? 'pawfollow_accepted_title'.tr
            : 'pawfollow_refused_title'.tr,
        message: action == 'accept'
            ? 'pawfollow_accepted_msg'.tr
            : 'pawfollow_refused_msg'.tr,
      );
      // Refresh la conversation pour récupérer le statut mis à jour.
      await chatController.loadChatMessages(
        widget.conversationId,
        contactName: widget.contactName,
      );
    } catch (e) {
      if (!mounted) return;
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: e.toString().replaceAll('ApiException:', '').trim(),
      );
    } finally {
      if (mounted) setState(() => _respondingIds.remove(message.id));
    }
  }

  /// v566 — feuille de demande modernisée (views/chat_shared/
  /// pawfollow_widgets.dart) : s'ouvre TOUT DE SUITE (plus d'attente sur la
  /// liste des réservations), affiche l'envoi, puis une erreur lisible avec
  /// un bouton vers la boutique quand il faut PawFollow / une réservation.
  /// L'ancien écran plein format reste disponible (_onSuivreTapLegacy).
  Future<void> _onSuivreTap() async {
    String petName = '';
    for (final m in chatController.currentChatMessages.reversed) {
      if (m.isPawfollowRequest && m.pawfollowPetName.isNotEmpty) {
        petName = m.pawfollowPetName;
        break;
      }
    }
    final sent = await showPawFollowRequestSheet(
      context,
      contactName: widget.contactName,
      contactImage: widget.contactImage,
      petName: petName,
      onSend: () => Get.find<OwnerRepository>()
          .requestLiveTrackingByConversation(
        conversationId: widget.conversationId,
      ),
    );
    if (!sent || !mounted) return;
    await chatController.loadChatMessages(
      widget.conversationId,
      contactName: widget.contactName,
    );
  }

  // ignore: unused_element
  Future<void> _onSuivreTapLegacy() async {
    try {
      final repo = Get.find<OwnerRepository>();

      // v23.1 part 70 — Bug 12 : Daniel "bouton suivre chat marche pas".
      // Previous logic only matched booking where sitter.name == contactName,
      // which fails when :
      //   - contactName has trailing spaces / slightly different casing
      //   - the provider is a walker (booking.sitter is the populated
      //     sitter struct ; for walker bookings it contains the walker
      //     but the model holds different name normalization)
      //   - or the booking has multiple statuses ('paid' but also
      //     'agreed', 'accepted'). We were too restrictive.
      // Now we relax : ANY booking that's at least 'paid' (whatever
      // status flag) AND whose provider name fuzzily matches.
      final bookings = await repo.getMyBookings();
      String norm(String s) =>
          s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
      final wantedName = norm(widget.contactName);
      final candidate = bookings
          .where((b) {
            final pay = (b.paymentStatus ?? '').toLowerCase();
            final st  = b.status.toLowerCase();
            if (pay != 'paid') return false;
            if (st == 'cancelled' || st == 'refunded' || st == 'completed') {
              return false;
            }
            return norm(b.sitter.name) == wantedName ||
                norm(b.sitter.name).contains(wantedName) ||
                wantedName.contains(norm(b.sitter.name));
          })
          .toList()
          // Most recent first.
          ..sort((a, b) => (b.updatedAt).compareTo(a.updatedAt));

      // v23.1.193 — Daniel : "chat rien changer aucun bouton". Avant on
      // n'ouvrait le sheet QUE si bookingId trouve via fuzzy match nom
      // → quand le match foirait (espaces, casse, walker vs sitter),
      // Daniel ne voyait rien. Maintenant on ouvre TOUJOURS le sheet :
      //   - Si booking trouve → onConfirm = requestLiveTracking(bookingId)
      //   - Sinon → onConfirm = requestLiveTrackingByConversation
      // Le sheet utilise booking pour les details si dispo, sinon
      // fallback sur les infos de la conversation (contact name + avatar).
      final BookingModel? booking =
          candidate.isNotEmpty ? candidate.first : null;
      if (mounted) {
        await Get.to(() => TrackingRequestSheet(
              booking: booking,
              fallbackContactName: widget.contactName,
              fallbackContactImage: widget.contactImage,
              onConfirm: () async {
                try {
                  // v23.1.256 — DEEP FIX : on envoie TOUJOURS via la
                  // conversation ouverte (backend permissif) pour que la carte
                  // atterrisse à coup sûr dans CE chat. Avant, le chemin
                  // booking (requestLiveTracking) pouvait créer la carte
                  // ailleurs ou échouer → "demande s'affiche dans aucun profil".
                  await repo.requestLiveTrackingByConversation(
                    conversationId: widget.conversationId,
                  );
                } catch (e) {
                  if (mounted) {
                    // v23.1.349 — Daniel (bug grave) : "service fini, la
                    // demande de suivi doit être bloquée avec un message
                    // 'refaites un service ou prenez PawFollow/PawFamily'".
                    // Le backend renvoie 410 TRACKING_ENDED → message clair
                    // traduit au lieu de l'erreur brute.
                    final raw = e.toString();
                    if (raw.contains('TRACKING_ENDED') ||
                        raw.contains('Service is over')) {
                      CustomSnackbar.showWarning(
                        title: 'tracking_service_over_title'.tr,
                        message: 'tracking_service_over_msg'.tr,
                      );
                    } else {
                      CustomSnackbar.showError(
                        title: 'follow_unavailable_title'.tr,
                        message: raw.replaceAll('ApiException:', '').trim(),
                      );
                    }
                  }
                  return;
                }
                if (mounted) {
                  CustomSnackbar.showSuccess(
                    title: 'pawfollow_request_sent_title'.tr,
                    message: 'pawfollow_request_sent_msg'.tr,
                  );
                  await chatController.loadChatMessages(
                    widget.conversationId,
                    contactName: widget.contactName,
                  );
                }
              },
            ));
      }
    } catch (e) {
      CustomSnackbar.showError(
        title: 'follow_unavailable_title'.tr,
        message: e.toString().replaceAll('ApiException:', '').trim(),
      );
    }
  }

  /// v23.1 part 240 — Daniel : "sur les 3 profile rajoute partager mon
  /// adresse pour rdv fais un truc styler pour les 3 profile qduand y
  /// font recuperer lanimal y senvoi ladresse directement dans le chat".
  /// POST /conversations/:id/share-address → cree un message
  /// type='address_share' visible cote owner + sitter/walker.
  Future<void> _onShareAddressTap() async {
    try {
      final repo = Get.find<ChatRepository>();
      await repo.shareAddress(conversationId: widget.conversationId);
      if (!mounted) return;
      CustomSnackbar.showSuccess(
        title: 'address_share_sent_title'.tr,
        message: 'address_share_sent_msg'.tr,
      );
      await chatController.loadChatMessages(
        widget.conversationId,
        contactName: widget.contactName,
      );
    } catch (e) {
      if (!mounted) return;
      // v565 — point 14 : verrou contacts (402 CONTACTS_LOCKED) → feuille.
      if (maybeShowContactsLocked(context, e, theme: _theme)) return;
      final raw = e.toString().replaceAll('ApiException:', '').trim();
      final isMissingAddress = raw.toLowerCase().contains('no address');
      CustomSnackbar.showError(
        title: isMissingAddress
            ? 'address_share_no_profile_title'.tr
            : 'common_error'.tr,
        message: isMissingAddress
            ? 'address_share_no_profile_msg'.tr
            : raw,
      );
    }
  }

  /// v449 — Daniel : « améliore le partage de mon numéro sur les 3 profils ».
  /// Confirmation explicite, puis POST /conversations/:id/share-phone
  /// (role-agnostic) + feedback. Mirror de _onShareAddressTap.
  Future<void> _onSharePhoneTap() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: AppColors.card(dctx),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18.r),
        ),
        title: InterText(
          text: 'phone_share_confirm_title'.tr,
          fontSize: 16.sp,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary(dctx),
        ),
        content: InterText(
          text: 'phone_share_confirm_msg'.tr,
          fontSize: 13.sp,
          color: AppColors.textSecondary(dctx),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(false),
            child: InterText(
              text: 'common_cancel'.tr,
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary(dctx),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
            onPressed: () => Navigator.of(dctx).pop(true),
            child: InterText(
              text: 'chat_share_phone_button'.tr,
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final repo = Get.find<ChatRepository>();
      await repo.sharePhone(conversationId: widget.conversationId);
      if (!mounted) return;
      CustomSnackbar.showSuccess(
        title: 'phone_share_sent_title'.tr,
        message: 'phone_share_sent_msg'.tr,
      );
      await chatController.loadChatMessages(
        widget.conversationId,
        contactName: widget.contactName,
      );
    } catch (e) {
      if (!mounted) return;
      // v565 — point 14 : verrou contacts (402 CONTACTS_LOCKED) → feuille.
      if (maybeShowContactsLocked(context, e, theme: _theme)) return;
      final raw = e.toString().replaceAll('ApiException:', '').trim();
      final isMissing = raw.toLowerCase().contains('no phone');
      CustomSnackbar.showError(
        title: isMissing
            ? 'phone_share_no_profile_title'.tr
            : 'common_error'.tr,
        message: isMissing ? 'phone_share_no_profile_msg'.tr : raw,
      );
    }
  }

  // ── v565 — écran de discussion partagé (views/chat_shared/) ──────────────
  // Points 13 / 16 / 18 / 36 : en-tête avec présence, bulles Apple, menu « + »
  // (photo, caméra, vidéo, vocal, numéro, adresse, PawFollow, traduction),
  // réponse à un message, états vide / chargement / erreur. Les actions
  // propres au rôle restent dans cet écran (owner).
  ChatRoleTheme get _theme => ChatRoleTheme.forRole(chatController.myRole);

  Widget? _specialCard(ChatMessageBase m) {
    if (m is ChatMessage && m.isPawfollowRequest) {
      return _buildPawfollowRequestCard(m, chatController);
    }
    return null;
  }

  List<ChatMenuItem> _roleMenuItems() => [
        ChatMenuItem(
          icon: Icons.phone_rounded,
          label: 'chat_share_phone_button'.tr,
          subtitle: 'cs_action_share_phone_sub'.tr,
          color: _theme.accent,
          onTap: _onSharePhoneTap,
        ),
        ChatMenuItem(
          icon: Icons.home_rounded,
          label: 'cs_action_share_address'.tr,
          subtitle: 'cs_action_share_address_sub'.tr,
          color: _theme.accentDark,
          onTap: _onShareAddressTap,
        ),
        ChatMenuItem(
          icon: Icons.location_on_rounded,
          label: 'follow_button_live_my_pet'.tr,
          subtitle: 'cs_action_pawfollow_sub'.tr,
          color: kPawFollowPurple,
          highlight: true,
          onTap: _onSuivreTap,
        ),
      ];

  void _sendText() {
    if (!mounted || _localMessageController.text.trim().isEmpty) return;
    try {
      // Sync local controller to shared controller before sending (v500).
      chatController.messageController.text = _localMessageController.text;
      chatController.sendMessage();
    } catch (_) {
      // Controller might be disposed, skip sending.
    }
  }

  Widget _bottom() {
    // Lit les .value dans l'Obx du corps (chat_conversation_body) ; ici on
    // choisit simplement le panneau.
    if (chatController.isPaymentRequired.value) {
      return ChatPaymentGate(theme: _theme);
    }
    if (chatController.isChatLocked.value) {
      return ChatLockedNotice(theme: _theme);
    }
    return ChatComposer(
      session: chatController,
      theme: _theme,
      textController: _localMessageController,
      focusNode: _inputFocusNode,
      onSendText: _sendText,
      contactName: widget.contactName,
      roleMenuItems: _roleMenuItems(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = _theme;
    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      appBar: ChatHeaderBar(
        session: chatController,
        theme: t,
        contactName: widget.contactName,
        contactImage: widget.contactImage,
        actions: [
          // v566 — pilule violette PawFollow ; suivi EN COURS → point vert
          // animé + « En direct · voir la carte » (ouvre la PawMap).
          Obx(() {
            final live =
                pawFollowLiveMessage(chatController.currentChatMessages);
            return PawFollowPill(
              icon: Icons.my_location_rounded,
              label: 'follow_button_live_my_pet'.tr,
              live: live != null,
              onTap: live != null ? () => _openLiveMap(live) : _onSuivreTap,
            );
          }),
        ],
      ),
      body: ChatConversationBody(
        session: chatController,
        theme: t,
        conversationId: widget.conversationId,
        contactName: widget.contactName,
        specialCardBuilder: _specialCard,
        bottomBuilder: _bottom,
      ),
    );
  }
}

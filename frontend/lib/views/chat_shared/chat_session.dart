// v565 — « session de chat » : l'interface que les widgets partagés
// (views/chat_shared/*) attendent d'un contrôleur, et le mixin qui porte
// toute la logique NOUVELLE du build 565 (drapeaux admin, réponse à un
// message, envoi photo/vidéo réparé, message vocal, présence en ligne,
// traduction) — une seule implémentation pour ChatController (owner) et
// SitterChatController (sitter/walker).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/utils/logger.dart';
import 'package:hopetsit/views/chat_shared/chat_api.dart';
import 'package:hopetsit/views/chat_shared/chat_models.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:image_picker/image_picker.dart';

/// Ce que les écrans partagés lisent / appellent sur un contrôleur de chat.
abstract class ChatSession {
  RxList<ChatMessageBase> get messagesRx;
  RxList<ChatConversationBase> get conversationsRx;
  RxBool get isLoading;
  RxBool get isMessagesLoading;
  RxString get errorMessage;
  RxString get currentChatId;
  RxBool get isPaymentRequired;
  RxBool get isChatLocked;
  Rx<ChatFeatureFlags> get features;
  Rxn<ChatMessageBase> get replyTarget;
  RxBool get autoTranslate;
  RxBool get peerOnline;
  Rxn<DateTime> get peerLastSeen;
  RxMap<String, String> get translations;
  RxSet<String> get translating;
  TextEditingController get messageController;
  String get myRole;
  String get currentUserId;

  Future<void> sendMessage();
  Future<void> sendMediaFiles(List<File> files);
  Future<void> sendVoice(File file, int durationSeconds);
  Future<void> retryFailed(String messageId);
  Future<bool> deleteMessage(String messageId);
  Future<bool> deleteConversation(String conversationId);
  Future<void> loadChatMessages(
    String chatId, {
    String? contactName,
    String? contactImage,
  });
  Future<void> reloadConversations();
  Future<void> loadFeatures();
  void setReply(ChatMessageBase? message);
  Future<void> pickPhotos();
  Future<void> pickVideo();
  Future<void> takePhoto();
  Future<void> ensureTranslated(ChatMessageBase message);
  void syncPeerPresence(String chatId);
  String formatTime(DateTime dateTime);
}

/// Logique commune (build 565). Le contrôleur fournit les fabriques de ses
/// propres types (M / C) ; le mixin fait le reste.
mixin ChatSessionMixin<M extends ChatMessageBase,
    C extends ChatConversationBase> on GetxController implements ChatSession {
  // ── à fournir par le contrôleur ──────────────────────────────────────────
  RxList<M> get currentChatMessages;
  RxList<C> get conversations;

  /// Construit un message local (optimiste) du type du contrôleur.
  M buildLocalMessage({
    required String id,
    required String body,
    required String type,
    List<ChatAttachment> media,
    ChatReplyRef? replyTo,
    bool isPending,
    bool isFailed,
  });

  /// Mappe la réponse serveur (déjà déballée) vers le type du contrôleur.
  M mapServerMessage(Map<String, dynamic> raw);

  /// Copie avec statut.
  M withStatus(M m, {bool? isPending, bool? isFailed});

  /// Copie d'une conversation avec la présence mise à jour.
  C withPresence(C c, {required bool isOnline, DateTime? lastSeenAt});

  /// Met à jour l'aperçu « dernier message » de la conversation ouverte.
  void updateLastMessagePreview(String preview);

  // ── état partagé ─────────────────────────────────────────────────────────
  @override
  RxList<ChatMessageBase> get messagesRx => currentChatMessages;
  @override
  RxList<ChatConversationBase> get conversationsRx => conversations;

  @override
  final Rx<ChatFeatureFlags> features = const ChatFeatureFlags().obs;
  @override
  final Rxn<ChatMessageBase> replyTarget = Rxn<ChatMessageBase>();
  @override
  final RxBool autoTranslate = false.obs;
  @override
  final RxBool peerOnline = false.obs;
  @override
  final Rxn<DateTime> peerLastSeen = Rxn<DateTime>();
  @override
  final RxMap<String, String> translations = <String, String>{}.obs;
  @override
  final RxSet<String> translating = <String>{}.obs;

  final ImagePicker _mediaPicker = ImagePicker();

  /// Fichiers en attente / échoués, pour « réessayer ».
  final Map<String, _PendingUpload> _pendingUploads = {};

  // ── drapeaux admin ───────────────────────────────────────────────────────
  @override
  Future<void> loadFeatures() async {
    features.value = await ChatApi.fetchFeatures();
  }

  // ── réponse à un message ─────────────────────────────────────────────────
  @override
  void setReply(ChatMessageBase? message) {
    if (message != null && !features.value.reply) return;
    if (message != null && (message.isDeleted || message.isSystem)) return;
    replyTarget.value = message;
  }

  ChatReplyRef? snapshotReply() {
    final t = replyTarget.value;
    if (t == null) return null;
    final body = t.isVoice || t.visualMedia.isNotEmpty || t.isPhoneShare ||
            t.isAddressShare
        ? chatPreviewForKind(t.replyKind, t.message)
        : t.message;
    return ChatReplyRef(
      messageId: t.id,
      body: body.length > 120 ? body.substring(0, 120) : body,
      senderRole: t.senderRole,
      senderId: t.senderId,
      kind: t.replyKind,
    );
  }

  // ── envoi photo / vidéo (kind=media) ─────────────────────────────────────
  @override
  Future<void> pickPhotos() async {
    try {
      final picked = await _mediaPicker.pickMultiImage(
        imageQuality: 82,
        maxWidth: 1800,
        limit: 5,
      );
      if (picked.isEmpty) return;
      await sendMediaFiles(picked.map((x) => File(x.path)).toList());
    } catch (e) {
      AppLogger.logError('pickPhotos failed', error: e);
    }
  }

  @override
  Future<void> takePhoto() async {
    try {
      final x = await _mediaPicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 82,
        maxWidth: 1800,
      );
      if (x == null) return;
      await sendMediaFiles([File(x.path)]);
    } catch (e) {
      AppLogger.logError('takePhoto failed', error: e);
    }
  }

  @override
  Future<void> pickVideo() async {
    try {
      final x = await _mediaPicker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: 60),
      );
      if (x == null) return;
      await sendMediaFiles([File(x.path)]);
    } catch (e) {
      AppLogger.logError('pickVideo failed', error: e);
    }
  }

  @override
  Future<void> sendMediaFiles(List<File> files) async {
    if (currentChatId.value.isEmpty) return;
    if (!features.value.media) {
      CustomSnackbar.showWarning(
        title: 'common_error'.tr,
        message: 'cs_feature_disabled'.tr,
      );
      return;
    }
    final reply = snapshotReply();
    replyTarget.value = null;
    // Un message par fichier : requêtes courtes (Render + Cloudinary), bulle
    // individuelle, réessai unitaire — et jamais plus que la limite serveur.
    for (final file in files) {
      int size = 0;
      try {
        size = await file.length();
      } catch (_) {/* fichier inaccessible → l'upload échouera proprement */}
      if (size > ChatApi.maxFileBytes) {
        CustomSnackbar.showWarning(
          title: 'common_error'.tr,
          message: 'cs_file_too_big'.tr,
        );
        continue;
      }
      final type = guessResourceTypeFromUrl('https://x/${file.path}');
      final tempId = 'tmp_${DateTime.now().microsecondsSinceEpoch}';
      final local = buildLocalMessage(
        id: tempId,
        body: '',
        type: 'text',
        media: [
          ChatAttachment(
            url: 'https://local/${file.path.split('/').last}',
            resourceType: type == 'video' ? 'video' : 'image',
            localPath: file.path,
          ),
        ],
        replyTo: reply,
        isPending: true,
        isFailed: false,
      );
      currentChatMessages.add(local);
      _pendingUploads[tempId] = _PendingUpload(
        file: file,
        kind: 'media',
        replyToId: reply?.messageId,
      );
      updateLastMessagePreview(
          chatPreviewForKind(type == 'video' ? 'video' : 'image', ''));
      await _upload(tempId);
    }
  }

  // ── message vocal (kind=voice) ───────────────────────────────────────────
  @override
  Future<void> sendVoice(File file, int durationSeconds) async {
    if (currentChatId.value.isEmpty) return;
    if (!features.value.voice) {
      CustomSnackbar.showWarning(
        title: 'common_error'.tr,
        message: 'cs_feature_disabled'.tr,
      );
      return;
    }
    final reply = snapshotReply();
    replyTarget.value = null;
    final tempId = 'tmp_${DateTime.now().microsecondsSinceEpoch}';
    final local = buildLocalMessage(
      id: tempId,
      body: '',
      type: 'voice',
      media: [
        ChatAttachment(
          url: 'https://local/${file.path.split('/').last}',
          resourceType: 'audio',
          duration: durationSeconds.toDouble(),
          localPath: file.path,
        ),
      ],
      replyTo: reply,
      isPending: true,
      isFailed: false,
    );
    currentChatMessages.add(local);
    _pendingUploads[tempId] = _PendingUpload(
      file: file,
      kind: 'voice',
      duration: durationSeconds,
      replyToId: reply?.messageId,
    );
    updateLastMessagePreview(chatPreviewForKind('audio', ''));
    await _upload(tempId);
  }

  @override
  Future<void> retryFailed(String messageId) async {
    if (!_pendingUploads.containsKey(messageId)) return;
    final idx = currentChatMessages.indexWhere((m) => m.id == messageId);
    if (idx >= 0) {
      currentChatMessages[idx] =
          withStatus(currentChatMessages[idx], isPending: true, isFailed: false);
    }
    await _upload(messageId);
  }

  Future<void> _upload(String tempId) async {
    final p = _pendingUploads[tempId];
    if (p == null) return;
    try {
      final raw = await ChatApi.sendAttachment(
        conversationId: currentChatId.value,
        file: p.file,
        senderRole: myRole,
        senderId: currentUserId,
        kind: p.kind,
        durationSeconds: p.duration,
        replyToMessageId: p.replyToId,
      );
      _pendingUploads.remove(tempId);
      final idx = currentChatMessages.indexWhere((m) => m.id == tempId);
      M? mapped;
      try {
        mapped = mapServerMessage(raw);
      } catch (e) {
        AppLogger.logError('map uploaded message failed', error: e);
      }
      if (idx < 0) return;
      if (mapped != null && mapped.media.isNotEmpty) {
        currentChatMessages[idx] = mapped;
      } else {
        // Réponse illisible : on garde la bulle locale mais plus « en cours ».
        currentChatMessages[idx] =
            withStatus(currentChatMessages[idx], isPending: false);
      }
    } catch (e) {
      AppLogger.logError('chat upload failed', error: e);
      final idx = currentChatMessages.indexWhere((m) => m.id == tempId);
      if (idx >= 0) {
        currentChatMessages[idx] = withStatus(
          currentChatMessages[idx],
          isPending: false,
          isFailed: true,
        );
      }
      if (ChatApi.isFeatureDisabled(e)) {
        // Le drapeau a changé côté admin pendant la session : on cache le
        // bouton et on retire la bulle (rien ne partira).
        final f = features.value;
        features.value = p.kind == 'voice'
            ? ChatFeatureFlags(media: f.media, voice: false, reply: f.reply)
            : ChatFeatureFlags(media: false, voice: f.voice, reply: f.reply);
        _pendingUploads.remove(tempId);
        currentChatMessages.removeWhere((m) => m.id == tempId);
        CustomSnackbar.showWarning(
          title: 'common_error'.tr,
          message: 'cs_feature_disabled'.tr,
        );
        return;
      }
      final msg = e is ApiException
          ? '[${e.statusCode ?? '?'}] ${e.message}'
          : (e is NetworkUnreachableException
              ? 'cs_send_failed_body'.tr
              : e.toString());
      CustomSnackbar.showError(
        title: 'cs_send_failed_title'.tr,
        message: msg.length > 200 ? msg.substring(0, 200) : msg,
      );
    }
  }

  // ── présence ─────────────────────────────────────────────────────────────
  /// Handler socket `presence:update { userId, online, at }` (réf. stable).
  void handlePresenceUpdate(Map<String, dynamic> data) {
    try {
      final userId = (data['userId'] ?? data['id'] ?? '').toString();
      if (userId.isEmpty) return;
      final online = data['online'] == true;
      DateTime? at;
      final rawAt = data['at'];
      if (rawAt is String) at = DateTime.tryParse(rawAt);
      if (rawAt is int) at = DateTime.fromMillisecondsSinceEpoch(rawAt);
      var touched = false;
      for (var i = 0; i < conversations.length; i++) {
        final c = conversations[i];
        if (c.contactId == userId && c.isOnline != online) {
          conversations[i] = withPresence(
            c,
            isOnline: online,
            lastSeenAt: online ? c.lastSeenAt : (at ?? DateTime.now()),
          );
          touched = true;
        }
      }
      if (touched) conversations.refresh();
      final open = _openConversation();
      if (open != null && open.contactId == userId) {
        peerOnline.value = online;
        if (!online) peerLastSeen.value = at ?? DateTime.now();
      }
    } catch (e) {
      AppLogger.logError('presence:update handling failed', error: e);
    }
  }

  C? _openConversation() {
    final id = currentChatId.value;
    if (id.isEmpty) return null;
    for (final c in conversations) {
      if (c.id == id) return c;
    }
    return null;
  }

  @override
  void syncPeerPresence(String chatId) {
    for (final c in conversations) {
      if (c.id == chatId) {
        peerOnline.value = c.isOnline;
        peerLastSeen.value = c.lastSeenAt;
        return;
      }
    }
    peerOnline.value = false;
  }

  // ── traduction ───────────────────────────────────────────────────────────
  @override
  Future<void> ensureTranslated(ChatMessageBase message) async {
    final id = message.id;
    if (translations.containsKey(id) || translating.contains(id)) return;
    final text = message.message.trim();
    if (text.isEmpty) return;
    translating.add(id);
    try {
      final t = await ChatApi.translate(
        text: text,
        targetLang: Get.locale?.languageCode ?? 'fr',
      );
      translations[id] = t ?? '';
    } catch (e) {
      translations[id] = '';
    } finally {
      translating.remove(id);
    }
  }
}

class _PendingUpload {
  _PendingUpload({
    required this.file,
    required this.kind,
    this.duration,
    this.replyToId,
  });
  final File file;
  final String kind;
  final int? duration;
  final String? replyToId;
}

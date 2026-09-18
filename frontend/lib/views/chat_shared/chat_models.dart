// v565 — modèles partagés du chat (owner + sitter/walker).
//
// Les deux contrôleurs (ChatController / SitterChatController) gardaient
// deux copies quasi identiques des classes de message et de conversation.
// Depuis le build 565 elles héritent de ces bases : les widgets de
// `views/chat_shared/` ne connaissent que ChatMessageBase /
// ChatConversationBase et fonctionnent donc à l'identique sur les deux écrans.
//
// Contrat backend (docs/v565_contracts.md §5) :
//   attachments[] = { url, resourceType: 'image'|'video'|'audio', duration,
//                     thumbnailUrl, width, height }
//   replyTo       = { messageId, body (≤120), senderRole, senderId, kind }
//   type          = 'text' | 'voice' | 'pawfollow_request' | 'phone_share' |
//                   'address_share' | …
import 'package:get/get.dart';

/// Pièce jointe typée (photo, vidéo, vocal).
class ChatAttachment {
  const ChatAttachment({
    required this.url,
    required this.resourceType,
    this.duration,
    this.thumbnailUrl,
    this.width,
    this.height,
    this.localPath,
  });

  final String url;

  /// 'image' | 'video' | 'audio'
  final String resourceType;

  /// Durée en secondes (vidéo / vocal).
  final double? duration;
  final String? thumbnailUrl;
  final int? width;
  final int? height;

  /// Chemin local pendant l'envoi optimiste (aperçu avant l'URL Cloudinary).
  final String? localPath;

  bool get isImage => resourceType == 'image';
  bool get isVideo => resourceType == 'video';
  bool get isAudio => resourceType == 'audio';

  /// Vignette d'une vidéo Cloudinary : l'URL vidéo avec l'extension `.jpg`
  /// renvoie la première image (transformation implicite Cloudinary).
  String get posterUrl {
    if (thumbnailUrl != null &&
        thumbnailUrl!.isNotEmpty &&
        thumbnailUrl != url) {
      return thumbnailUrl!;
    }
    if (isVideo && url.contains('res.cloudinary.com')) {
      return url.replaceAll(RegExp(r'\.[A-Za-z0-9]{2,5}$'), '.jpg');
    }
    return url;
  }
}

/// Instantané du message cité (réponse façon WhatsApp).
class ChatReplyRef {
  const ChatReplyRef({
    required this.messageId,
    required this.body,
    required this.senderRole,
    required this.senderId,
    required this.kind,
  });

  final String messageId;
  final String body;
  final String senderRole;
  final String senderId;

  /// 'text' | 'image' | 'video' | 'audio' | 'phone_share' | 'address_share'
  final String kind;

  Map<String, dynamic> toJson() => {
        'messageId': messageId,
        'body': body,
        'senderRole': senderRole,
        'senderId': senderId,
        'kind': kind,
      };
}

/// Drapeaux admin `GET /app-config/chat-features` (§5).
class ChatFeatureFlags {
  const ChatFeatureFlags({
    this.media = true,
    this.voice = true,
    this.reply = true,
  });

  final bool media;
  final bool voice;
  final bool reply;

  static ChatFeatureFlags fromJson(dynamic raw) {
    if (raw is! Map) return const ChatFeatureFlags();
    bool flag(String k) {
      final v = raw[k];
      if (v == null) return true;
      if (v is bool) return v;
      return v.toString().toLowerCase() != 'false';
    }

    return ChatFeatureFlags(
      media: flag('media'),
      voice: flag('voice'),
      reply: flag('reply'),
    );
  }
}

/// Lit `attachments` (liste de Map ou de String) → pièces typées.
List<ChatAttachment> parseChatAttachments(dynamic raw) {
  if (raw is! List) return const [];
  final out = <ChatAttachment>[];
  for (final item in raw) {
    String url = '';
    String type = 'image';
    double? duration;
    String? thumb;
    int? w;
    int? h;
    if (item is String) {
      url = item;
    } else if (item is Map) {
      url = (item['url'] ??
              item['file'] ??
              item['fileUrl'] ??
              item['attachmentUrl'] ??
              '')
          .toString();
      type = (item['resourceType'] ?? item['resource_type'] ?? '')
          .toString()
          .toLowerCase();
      final d = item['duration'];
      if (d is num) duration = d.toDouble();
      if (d is String) duration = double.tryParse(d);
      final t = item['thumbnailUrl'];
      if (t is String && t.isNotEmpty) thumb = t;
      if (item['width'] is num) w = (item['width'] as num).toInt();
      if (item['height'] is num) h = (item['height'] as num).toInt();
    }
    if (url.isEmpty ||
        !(url.startsWith('http://') || url.startsWith('https://'))) {
      continue;
    }
    if (type != 'image' && type != 'video' && type != 'audio') {
      type = guessResourceTypeFromUrl(url);
    }
    out.add(ChatAttachment(
      url: url,
      resourceType: type,
      duration: duration,
      thumbnailUrl: thumb,
      width: w,
      height: h,
    ));
  }
  return out;
}

/// Devine le type d'une URL sans `resourceType` (anciens messages).
String guessResourceTypeFromUrl(String url) {
  final u = url.toLowerCase();
  final path = u.split('?').first;
  if (RegExp(r'\.(m4a|aac|mp3|wav|ogg|opus)$').hasMatch(path)) return 'audio';
  if (RegExp(r'\.(mp4|mov|webm|m4v|3gp|avi)$').hasMatch(path)) return 'video';
  if (u.contains('/video/upload/')) return 'video';
  return 'image';
}

/// Lit `replyTo` (objet) → instantané, ou null.
ChatReplyRef? parseChatReplyTo(dynamic raw) {
  if (raw is! Map) return null;
  final id = (raw['messageId'] ?? raw['_id'] ?? raw['id'] ?? '').toString();
  if (id.isEmpty) return null;
  return ChatReplyRef(
    messageId: id,
    body: (raw['body'] ?? '').toString(),
    senderRole: (raw['senderRole'] ?? '').toString(),
    senderId: (raw['senderId'] ?? '').toString(),
    kind: (raw['kind'] ?? 'text').toString(),
  );
}

/// v566 — état d'un message ENVOYÉ, façon WhatsApp.
///   sending   : horloge (envoi en cours)
///   sent      : une coche grise (le serveur l'a)
///   delivered : deux coches grises (remis à l'appareil du destinataire)
///   read      : deux coches bleues (#34B7F1) — le destinataire l'a lu
///   failed    : l'envoi a échoué (la bulle propose déjà « réessayer »)
enum ChatReceiptStatus { sending, sent, delivered, read, failed }

/// 'sent' | 'delivered' | 'read' (champ `lastMessageStatus` de la liste).
ChatReceiptStatus? chatReceiptStatusFromString(String? raw) {
  switch ((raw ?? '').toLowerCase()) {
    case 'read':
      return ChatReceiptStatus.read;
    case 'delivered':
      return ChatReceiptStatus.delivered;
    case 'sent':
      return ChatReceiptStatus.sent;
    case 'sending':
      return ChatReceiptStatus.sending;
    default:
      return null;
  }
}

/// Lit une date ISO / epoch ms du serveur (`deliveredAt`, `readAt`) → locale.
DateTime? parseChatReceiptDate(dynamic raw) {
  if (raw == null || raw == '') return null;
  if (raw is DateTime) return raw.toLocal();
  if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
  return DateTime.tryParse(raw.toString())?.toLocal();
}

/// Base commune des messages — tous les getters utilisés par les widgets.
abstract class ChatMessageBase {
  ChatMessageBase({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderImage,
    required this.message,
    required this.timestamp,
    required this.isFromCurrentUser,
    this.attachments = const [],
    this.isDeleted = false,
    this.senderRole = '',
    this.type = 'text',
    this.metadata = const {},
    this.media = const [],
    this.replyTo,
    this.isPending = false,
    this.isFailed = false,
    this.deliveredAt,
    this.readAt,
  });

  final String id;
  final String senderId;
  final String senderName;
  final String senderImage;
  final String message;
  final DateTime timestamp;
  final bool isFromCurrentUser;

  /// URLs brutes (compatibilité avec l'ancien rendu).
  final List<String> attachments;

  // v19.1.3 — soft-delete flag, backend hides body+attachments for deleted.
  final bool isDeleted;
  final String senderRole;

  /// 'text' | 'voice' | 'pawfollow_request' | 'phone_share' | 'address_share'
  final String type;
  final Map<String, dynamic> metadata;

  /// v565 — pièces typées (photo / vidéo / vocal).
  final List<ChatAttachment> media;

  /// v565 — message cité.
  final ChatReplyRef? replyTo;

  /// v565 — envoi optimiste en cours / échoué (bulle grisée, icône).
  final bool isPending;
  final bool isFailed;

  /// v566 — accusés serveur (null = pas encore remis / pas encore lu).
  final DateTime? deliveredAt;
  final DateTime? readAt;

  /// v566 — état affiché sous un message ENVOYÉ (coches façon WhatsApp).
  ChatReceiptStatus get receiptStatus {
    if (isFailed) return ChatReceiptStatus.failed;
    if (isPending) return ChatReceiptStatus.sending;
    if (readAt != null) return ChatReceiptStatus.read;
    if (deliveredAt != null) return ChatReceiptStatus.delivered;
    return ChatReceiptStatus.sent;
  }

  bool get isSystem => senderRole.toLowerCase() == 'system';

  bool get isVoice =>
      type == 'voice' || media.any((m) => m.isAudio) && media.length == 1;

  ChatAttachment? get voiceAttachment {
    for (final m in media) {
      if (m.isAudio) return m;
    }
    return null;
  }

  List<ChatAttachment> get visualMedia =>
      media.where((m) => m.isImage || m.isVideo).toList();

  /// Type « métier » du message pour la citation (§5 kind).
  String get replyKind {
    if (isPhoneShare) return 'phone_share';
    if (isAddressShare) return 'address_share';
    if (isVoice) return 'audio';
    if (media.any((m) => m.isVideo)) return 'video';
    if (media.any((m) => m.isImage) || attachments.isNotEmpty) return 'image';
    return 'text';
  }

  // v23.1.255 — messages système localisés par viewer.
  String get systemKind => (metadata['kind'] ?? '').toString();
  String get systemDisplayText {
    switch (systemKind) {
      case 'payment_confirmed':
        return 'chat_system_payment_confirmed'.tr;
      case 'rendezvous_prompt':
        return 'chat_system_rendezvous_prompt'.tr;
      default:
        return message;
    }
  }

  bool get isPawfollowRequest => type == 'pawfollow_request';

  // v449 — type 'phone_share' : le numéro est dans `body` et metadata.phone.
  bool get isPhoneShare => type == 'phone_share';
  String get phoneShareNumber {
    final m = (metadata['phone'] ?? '').toString();
    return m.isNotEmpty ? m : message;
  }

  // v23.1 part 240 — type 'address_share' : metadata { address, city, lat, lng }.
  bool get isAddressShare => type == 'address_share';
  String get addressShareAddress => (metadata['address'] ?? '').toString();
  String get addressShareCity => (metadata['city'] ?? '').toString();
  double? get addressShareLat => _num(metadata['lat']);
  double? get addressShareLng => _num(metadata['lng']);

  String get pawfollowStatus => (metadata['status'] ?? 'pending').toString();
  String get pawfollowResponderRole =>
      (metadata['responderRole'] ?? '').toString();
  String get pawfollowRequesterRole =>
      (metadata['requesterRole'] ?? '').toString();
  String get pawfollowPetName => (metadata['petName'] ?? '').toString();
  String get pawfollowPetPhoto => (metadata['petPhoto'] ?? '').toString();
  DateTime? get pawfollowStartAt => _date(metadata['startAt']);
  DateTime? get pawfollowEndAt => _date(metadata['endAt']);
  double? get pawfollowLastLat => _num(metadata['lastLat']);
  double? get pawfollowLastLng => _num(metadata['lastLng']);
  String get pawfollowServiceType =>
      (metadata['serviceType'] ?? '').toString();
  String get pawfollowBookingId => (metadata['bookingId'] ?? '').toString();

  /// v566 — échéance de la demande (au-delà : « Expirée », plus de boutons).
  DateTime? get pawfollowExpiresAt => _date(metadata['expiresAt']);

  static double? _num(dynamic raw) {
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw);
    return null;
  }

  static DateTime? _date(dynamic raw) {
    if (raw == null || raw == '') return null;
    return DateTime.tryParse(raw.toString());
  }
}

/// Base commune des conversations (liste).
abstract class ChatConversationBase {
  ChatConversationBase({
    required this.id,
    required this.contactName,
    required this.contactImage,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.isOnline,
    required this.unreadCount,
    this.contactId = '',
    this.contactRole = '',
    this.lastSeenAt,
    this.lastMessageMine = false,
    this.lastMessageStatus,
  });

  final String id;
  final String contactName;
  final String contactImage;
  final String lastMessage;
  final DateTime lastMessageTime;
  final bool isOnline;
  final int unreadCount;

  /// v565 — identité du correspondant pour la présence (`presence:update`).
  final String contactId;
  final String contactRole;
  final DateTime? lastSeenAt;

  /// v566 — le dernier message est le mien → coches devant l'aperçu.
  final bool lastMessageMine;
  final ChatReceiptStatus? lastMessageStatus;
}

/// Aperçu lisible d'un message pour la liste et les citations.
String chatPreviewForKind(String kind, String body) {
  switch (kind) {
    case 'audio':
    case 'voice':
      return 'cs_kind_voice'.tr;
    case 'image':
      return 'cs_kind_photo'.tr;
    case 'video':
      return 'cs_kind_video'.tr;
    case 'phone_share':
      return 'cs_kind_phone'.tr;
    case 'address_share':
      return 'cs_kind_address'.tr;
    default:
      return body.trim().isNotEmpty ? body.trim() : 'cs_kind_attachment'.tr;
  }
}

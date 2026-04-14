/// In-app notification from GET /notifications/my
class AppNotificationModel {
  AppNotificationModel({
    required this.id,
    required this.recipientRole,
    required this.recipientId,
    required this.actorRole,
    required this.actorId,
    required this.type,
    required this.title,
    required this.body,
    required this.data,
    this.readAt,
    required this.createdAt,
  });

  final String id;
  final String recipientRole;
  final String recipientId;
  final String actorRole;
  final String actorId;
  final String type;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final DateTime? readAt;
  final DateTime createdAt;

  bool get isUnread => readAt == null;

  factory AppNotificationModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is String && v.isNotEmpty) {
        try {
          return DateTime.parse(v);
        } catch (_) {
          return null;
        }
      }
      return null;
    }

    Map<String, dynamic> parseData(dynamic v) {
      if (v is Map<String, dynamic>) return v;
      if (v is Map) return Map<String, dynamic>.from(v);
      return {};
    }

    return AppNotificationModel(
      id: json['id']?.toString() ?? '',
      recipientRole: json['recipientRole']?.toString() ?? '',
      recipientId: json['recipientId']?.toString() ?? '',
      actorRole: json['actorRole']?.toString() ?? '',
      actorId: json['actorId']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      data: parseData(json['data']),
      readAt: parseDate(json['readAt']),
      createdAt: parseDate(json['createdAt']) ?? DateTime.now(),
    );
  }

  AppNotificationModel copyWith({
    DateTime? readAt,
  }) {
    return AppNotificationModel(
      id: id,
      recipientRole: recipientRole,
      recipientId: recipientId,
      actorRole: actorRole,
      actorId: actorId,
      type: type,
      title: title,
      body: body,
      data: data,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt,
    );
  }
}

import 'sitter_model.dart';

class BlockModel {
  final String id;
  final String blockerId;
  final String blockedRole;
  final String createdAt;
  final String updatedAt;
  final SitterModel blocked;

  BlockModel({
    required this.id,
    required this.blockerId,
    required this.blockedRole,
    required this.createdAt,
    required this.updatedAt,
    required this.blocked,
  });

  factory BlockModel.fromJson(Map<String, dynamic> json) {
    return BlockModel(
      id: json['id'] as String? ?? '',
      blockerId: json['blockerId'] as String? ?? '',
      blockedRole: json['blockedRole'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
      blocked: SitterModel.fromJson(
        json['blocked'] as Map<String, dynamic>? ?? {},
      ),
    );
  }
}

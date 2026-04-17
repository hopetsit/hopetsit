/// Lightweight friend profile — what the API returns inside a Friendship.
class FriendProfile {
  final String id;
  final String model; // 'Owner' | 'Sitter' | 'Walker'
  final String name;
  final String avatar;
  final String city;

  const FriendProfile({
    required this.id,
    required this.model,
    required this.name,
    this.avatar = '',
    this.city = '',
  });

  factory FriendProfile.fromJson(Map<String, dynamic> j) => FriendProfile(
        id: j['id']?.toString() ?? j['_id']?.toString() ?? '',
        model: (j['model'] as String?) ?? 'Owner',
        name: (j['name'] as String?) ?? '',
        avatar: (j['avatar'] as String?) ?? '',
        city: (j['city'] as String?) ?? '',
      );

  String get roleLowercase => model.toLowerCase();
}

/// One friendship record as exposed by the API.
class Friendship {
  final String id;
  final String status; // 'pending' | 'accepted' | 'declined'
  final bool initiatedByMe;
  final FriendProfile? other;
  final bool mySharePosition;
  final bool theirSharePosition;
  final DateTime? createdAt;
  final DateTime? acceptedAt;

  const Friendship({
    required this.id,
    required this.status,
    required this.initiatedByMe,
    required this.other,
    this.mySharePosition = true,
    this.theirSharePosition = true,
    this.createdAt,
    this.acceptedAt,
  });

  factory Friendship.fromJson(Map<String, dynamic> j) => Friendship(
        id: j['id']?.toString() ?? '',
        status: (j['status'] as String?) ?? 'pending',
        initiatedByMe: j['initiatedByMe'] == true,
        other: j['other'] == null
            ? null
            : FriendProfile.fromJson((j['other'] as Map).cast<String, dynamic>()),
        mySharePosition: j['mySharePosition'] == true,
        theirSharePosition: j['theirSharePosition'] == true,
        createdAt: DateTime.tryParse(j['createdAt']?.toString() ?? ''),
        acceptedAt: DateTime.tryParse(j['acceptedAt']?.toString() ?? ''),
      );
}

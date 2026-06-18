/// Lightweight friend profile — what the API returns inside a Friendship.
class FriendProfile {
  final String id;
  final String model; // 'Owner' | 'Sitter' | 'Walker'
  final String name;
  final String avatar;
  final String city;
  // v23.1 part 222 — Daniel : "si ils ont un plan PawFollow le chat se
  // debloque et on peux se partager la position, de plus je dois les
  // voir ds les personnes en live". Backend ajoute ce flag dans
  // fetchUserMini en regardant UserSubscription active.
  final bool hasPawFollow;
  // v23.1.280 — Daniel : "si l'ami a l'option PawSpot, anneau doré/bleu selon
  // l'option". Tier PawSpot actif ('bronze'|'silver'|'gold'|'platinum') ou ''.
  final String pawSpotTier;
  // v469 — Daniel : couronne 👑 Paw Premium visible par TOUS. Backend
  // (fetchUserMini) expose isPremium par contact.
  final bool isPremium;

  const FriendProfile({
    required this.id,
    required this.model,
    required this.name,
    this.avatar = '',
    this.city = '',
    this.hasPawFollow = false,
    this.pawSpotTier = '',
    this.isPremium = false,
  });

  factory FriendProfile.fromJson(Map<String, dynamic> j) => FriendProfile(
        id: j['id']?.toString() ?? j['_id']?.toString() ?? '',
        model: (j['model'] as String?) ?? 'Owner',
        name: (j['name'] as String?) ?? '',
        avatar: (j['avatar'] as String?) ?? '',
        city: (j['city'] as String?) ?? '',
        hasPawFollow: j['hasPawFollow'] == true,
        pawSpotTier: (j['pawSpotTier'] ?? '').toString().toLowerCase(),
        isPremium: j['isPremium'] == true,
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
  // v23.1 part 226 — Daniel : "debloque le partage de position si jai
  // un abonnement paw follow". Le backend force mySharePosition=true
  // ET expose ce flag separe pour que l'UI puisse :
  //   - rendre la Switch read-only (toggle desactive, vert plein)
  //   - afficher un badge "Auto · PawFollow" sous la switch
  final bool myShareAutoByPawFollow;
  final DateTime? createdAt;
  final DateTime? acceptedAt;

  const Friendship({
    required this.id,
    required this.status,
    required this.initiatedByMe,
    required this.other,
    this.mySharePosition = true,
    this.theirSharePosition = true,
    this.myShareAutoByPawFollow = false,
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
        myShareAutoByPawFollow: j['myShareAutoByPawFollow'] == true,
        createdAt: DateTime.tryParse(j['createdAt']?.toString() ?? ''),
        acceptedAt: DateTime.tryParse(j['acceptedAt']?.toString() ?? ''),
      );
}

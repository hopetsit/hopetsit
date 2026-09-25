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
  // v566 — contrat §6 (présence) : `GET /friends` renvoie `other.isOnline`
  // (calcul en direct) et `other.lastSeenAt`. Point vert sur les cartes amis.
  final bool isOnline;
  final DateTime? lastSeenAt;
  // v585 — Daniel : « john C est mon ami, mais en gardien la carte propose
  // Ajouter en ami ». Une amitié vaut pour la PERSONNE : `GET /friends` renvoie
  // tous les ids de rôle de l'ami (`other.personIds`), on compare à chacun.
  final List<String> personIds;
  // v587 (point 11, décision de Daniel du 25/09) — `GET /friends` renvoie la
  // position de PROFIL de l'ami, floutée ~1 km (`location.coordinates` =
  // [lng, lat], `approxKm`, `positionSource`) ; null s'il est « Masqué ».
  final double? mapLat;
  final double? mapLng;
  final double approxKm;
  final String positionSource;
  final String mapVisibility; // 'all' | 'friends' | 'hidden'

  const FriendProfile({
    required this.id,
    required this.model,
    required this.name,
    this.avatar = '',
    this.city = '',
    this.hasPawFollow = false,
    this.pawSpotTier = '',
    this.isPremium = false,
    this.isOnline = false,
    this.lastSeenAt,
    this.personIds = const <String>[],
    this.mapLat,
    this.mapLng,
    this.approxKm = 1.0,
    this.positionSource = '',
    this.mapVisibility = 'all',
  });

  /// Position de profil floutée connue (et ami non « Masqué ») ?
  bool get hasMapPosition =>
      mapLat != null && mapLng != null && mapVisibility != 'hidden';

  /// Cet id (de n'importe quel rôle) est-il celui de cette personne ?
  bool matchesId(String other) {
    final o = other.trim().toLowerCase();
    if (o.isEmpty) return false;
    if (id.trim().toLowerCase() == o) return true;
    return personIds.any((x) => x.trim().toLowerCase() == o);
  }

  FriendProfile copyWith({
    String? avatar,
    String? city,
    bool? isOnline,
    DateTime? lastSeenAt,
    double? mapLat,
    double? mapLng,
    double? approxKm,
    String? positionSource,
    String? mapVisibility,
    List<String>? personIds,
    bool clearMapPosition = false,
  }) =>
      FriendProfile(
        id: id,
        model: model,
        name: name,
        avatar: avatar ?? this.avatar,
        city: city ?? this.city,
        hasPawFollow: hasPawFollow,
        pawSpotTier: pawSpotTier,
        isPremium: isPremium,
        isOnline: isOnline ?? this.isOnline,
        lastSeenAt: lastSeenAt ?? this.lastSeenAt,
        personIds: personIds ?? this.personIds,
        mapLat: clearMapPosition ? null : (mapLat ?? this.mapLat),
        mapLng: clearMapPosition ? null : (mapLng ?? this.mapLng),
        approxKm: approxKm ?? this.approxKm,
        positionSource: positionSource ?? this.positionSource,
        mapVisibility: mapVisibility ?? this.mapVisibility,
      );

  static List<double>? _lngLat(Object? loc) {
    if (loc is! Map) return null;
    final c = loc['coordinates'];
    if (c is! List || c.length < 2 || c[0] is! num || c[1] is! num) return null;
    final lng = (c[0] as num).toDouble();
    final lat = (c[1] as num).toDouble();
    if (lat == 0 && lng == 0) return null;
    return [lng, lat];
  }

  factory FriendProfile.fromJson(Map<String, dynamic> j) => FriendProfile(
        id: j['id']?.toString() ?? j['_id']?.toString() ?? '',
        model: (j['model'] as String?) ?? 'Owner',
        name: (j['name'] as String?) ?? '',
        avatar: (j['avatar'] as String?) ?? '',
        city: (j['city'] as String?) ?? '',
        hasPawFollow: j['hasPawFollow'] == true,
        pawSpotTier: (j['pawSpotTier'] ?? '').toString().toLowerCase(),
        isPremium: j['isPremium'] == true,
        isOnline: j['isOnline'] == true,
        lastSeenAt: DateTime.tryParse(j['lastSeenAt']?.toString() ?? ''),
        personIds: j['personIds'] is List
            ? (j['personIds'] as List).map((e) => e.toString()).toList()
            : const <String>[],
        mapLat: _lngLat(j['location'])?[1],
        mapLng: _lngLat(j['location'])?[0],
        approxKm: (j['approxKm'] as num?)?.toDouble() ?? 1.0,
        positionSource: (j['positionSource'] ?? '').toString(),
        mapVisibility: const ['all', 'friends', 'hidden']
                .contains((j['mapVisibility'] ?? '').toString())
            ? j['mapVisibility'].toString()
            : 'all',
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

  Friendship copyWith({
    FriendProfile? other,
    bool? mySharePosition,
    bool? theirSharePosition,
  }) =>
      Friendship(
        id: id,
        status: status,
        initiatedByMe: initiatedByMe,
        other: other ?? this.other,
        mySharePosition: mySharePosition ?? this.mySharePosition,
        theirSharePosition: theirSharePosition ?? this.theirSharePosition,
        myShareAutoByPawFollow: myShareAutoByPawFollow,
        createdAt: createdAt,
        acceptedAt: acceptedAt,
      );

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

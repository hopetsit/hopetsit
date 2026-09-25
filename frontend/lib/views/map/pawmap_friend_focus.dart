// v588 (25/09/2026) — Daniel : « dans la liste d'amis de l'app, quand je
// clique sur sa photo, ça ne me renvoie pas vers lui sur la map ».
//
// Un appui sur un ami (photo ou ligne) dans « Mes amis », « En direct »,
// « PawFamily » ou la feuille « Amis en direct » de la PawMap ouvre l'ONGLET
// PawMap (menu conservé), vole en douceur sur lui (zoom 16), ouvre sa fiche
// courte, et lance le suivi s'il est en direct.
//
// Position = celle de la couche amis 587 (`pawmap_friends_layer.dart`) : le
// direct (partage actif, en direct ou signal perdu) sinon la position de
// PROFIL floutée renvoyée par `/friends`. Ami « Masqué » ou sans position →
// null : l'écran affiche la pastille « Cet ami n'est pas visible sur la
// carte ». Fonctions PURES (testées dans test/friends588_map_focus_test.dart).
import 'package:hopetsit/models/friendship_model.dart';
import 'package:hopetsit/services/live_map_service.dart';

/// Zoom du vol doux sur un ami.
const double kPawMapFriendFocusZoom = 16;

/// Cible d'un « voir cet ami sur la carte ».
class PawMapFriendFocus {
  final String userId;
  final String role; // 'owner' | 'sitter' | 'walker'
  final String name;
  final String avatar;
  final double lat;
  final double lng;

  /// Position DIRECTE (partage actif) → suivi lancé à l'arrivée.
  final bool live;
  final double approxKm;
  final bool premium;
  final bool online;
  final List<String> personIds;

  const PawMapFriendFocus({
    required this.userId,
    required this.role,
    required this.name,
    required this.lat,
    required this.lng,
    this.avatar = '',
    this.live = false,
    this.approxKm = 1,
    this.premium = false,
    this.online = false,
    this.personIds = const <String>[],
  });
}

/// Cible de [other] : direct s'il partage en ce moment, sinon sa position de
/// profil (sauf « Masqué ») ; null s'il n'est pas visible sur la carte.
PawMapFriendFocus? pawMapFriendFocusFor(FriendProfile other, {FriendPosition? live}) {
  if (other.id.isEmpty) return null;
  final role = other.model.toLowerCase();
  final ids = <String>[other.id, ...other.personIds.where((x) => x != other.id)];
  if (live != null && live.liveState != FriendLiveState.seen) {
    return PawMapFriendFocus(
      userId: other.id,
      role: role,
      name: other.name,
      avatar: other.avatar,
      lat: live.latitude,
      lng: live.longitude,
      live: true,
      approxKm: 0,
      premium: other.isPremium,
      online: other.isOnline,
      personIds: ids,
    );
  }
  if (!other.hasMapPosition) return null;
  return PawMapFriendFocus(
    userId: other.id,
    role: role,
    name: other.name,
    avatar: other.avatar,
    lat: other.mapLat!,
    lng: other.mapLng!,
    approxKm: other.approxKm,
    premium: other.isPremium,
    online: other.isOnline,
    personIds: ids,
  );
}

/// Position directe d'une personne (n'importe lequel de ses ids).
FriendPosition? pawMapLivePositionOf(
    FriendProfile other, Map<String, FriendPosition> positions) {
  final direct = positions[other.id];
  if (direct != null) return direct;
  for (final id in other.personIds) {
    final p = positions[id];
    if (p != null) return p;
  }
  return null;
}

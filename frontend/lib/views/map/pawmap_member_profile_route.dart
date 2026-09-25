// v584 (révision PawMap du 25/09, point 19) — « Voir le profil » depuis la
// fiche d'un membre de la carte : la page dépend du rôle DU MEMBRE, jamais du
// rôle du spectateur. Fonction pure (testée sur les 9 cas spectateur × membre).
import 'package:flutter/widgets.dart';

import '../service_provider/owner_profile_view_screen.dart';
import '../service_provider/service_provider_detail_screen.dart';
import '../service_provider/walker_detail_screen.dart';

Widget pawMapMemberProfilePage({
  required String id,
  required String role,
  String name = '',
  String avatar = '',
}) {
  switch (role.trim().toLowerCase()) {
    case 'walker':
      return WalkerDetailScreen(walkerId: id);
    case 'sitter':
      return ServiceProviderDetailScreen(sitterId: id, status: 'available');
    default:
      return OwnerProfileViewScreen(
        ownerId: id,
        ownerName: name,
        ownerAvatar: avatar.isEmpty ? null : avatar,
      );
  }
}

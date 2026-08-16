import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/friend_controller.dart';
import 'dart:async';

import 'package:hopetsit/controllers/chat_controller.dart';
import 'package:hopetsit/controllers/sitter_chat_controller.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/services/live_map_service.dart';
import 'package:hopetsit/models/friendship_model.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_switch.dart';
import 'package:hopetsit/utils/storage_keys.dart';
import 'package:hopetsit/views/boost/coin_shop_screen.dart';
import 'package:hopetsit/views/friends/blocked_users_screen.dart';
import 'package:hopetsit/views/map/paw_map_screen.dart';
import 'package:hopetsit/views/pet_owner/chat/individual_chat_screen.dart';
import 'package:hopetsit/views/pet_sitter/chat/sitter_individual_chat_screen.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:get_storage/get_storage.dart';
import 'package:share_plus/share_plus.dart';

/// Friends management screen — 2 tabs.
///   1. Mes amis — accepted friendships with a per-friend "share my position"
///      toggle and an "unfriend" option.
///   2. Demandes — incoming requests (accept/decline) + outgoing (pending).
// v414/v419 — « Mon cercle » (famille & amis PawFollow) = VIOLET partout.
// Constante AU NIVEAU FICHIER : utilisée par FriendsScreen ET les widgets/tabs
// privés (cartes amis, onglets Ajouter/Famille/Demandes) du même fichier.
const Color _circleViolet = Color(0xFF8B5CF6);

class FriendsScreen extends StatelessWidget {
  // v23.1 part 223 — Daniel : "personne en live met le bouton a coter
  // de famille et amis et alertes". On accepte un initialIndex pour
  // ouvrir directement sur l'onglet "Personnes en live" (index 4) quand
  // le user tape le nouveau bouton quick-action sur PawMap.
  const FriendsScreen({super.key, this.initialIndex = 0});
  final int initialIndex;

  @override
  Widget build(BuildContext context) {
    final FriendController controller = Get.isRegistered<FriendController>()
        ? Get.find<FriendController>()
        : Get.put(FriendController());

    // v23.1.172 — Daniel : "le truc de famille je le vois pas". On ajoute
    // un 3e onglet "Famille" qui montre les membres de PawFollow Famille
    // + permet d'inviter / retirer depuis la liste d'amis acceptés.
    // On précharge la famille à l'ouverture de l'écran.
    controller.loadFamily();
    // v23.1.185 — Daniel mockup : 5 tabs Mes amis / Ajouter / Live /
    // Animaux / Messages (au lieu des anciens 3 Mes amis / Demandes /
    // Famille). Les demandes pending sont desormais gerees inline dans
    // la cloche notif (v183 : NotificationCard accept/refuse buttons).
    // v23.1 part 205 — Daniel : "peut-etre rajouter Demande pour voir les
    // demandes d'amis". On ajoute un onglet "Demandes" dédié (le widget
    // _RequestsTab existait déjà mais n'était jamais câblé). Le badge
    // rouge avec le count d'incomingRequests bouge de "Ajouter" vers
    // "Demandes".
    // v23.1 part 210 — Daniel mockup : "reorganise comme sur la photo".
    // Famille et "Personnes en live" sont maintenant 2 onglets distincts
    // (avant fusionnes dans "Live"). Total : 7 onglets.
    // v23.1 part 225 — Daniel : "vire personne en live, je sais pas si on
    // vire pas aussi animeaux". Reponse : on vire les 2. Personnes en live
    // est desormais une screen autonome (PeopleLiveScreen) ouverte depuis
    // la card quick-action de PawMap. Animaux faisait doublon avec le
    // halo vert/bleu auto sur la map quand on suit un animal. Total : 5.
    // v23.1 part 244 — Daniel : "longlet a droite message efface le y sert
    // pas". Le tab Messages doublonnait l'onglet Chat principal du nav
    // bottom. On supprime l'onglet (de 5 vers 4). Le bouton 💬 cote chaque
    // ami suffit pour ouvrir une conv 1-to-1.
    return DefaultTabController(
      length: 4,
      initialIndex: initialIndex.clamp(0, 3),
      child: Scaffold(
        backgroundColor: AppColors.scaffold(context),
        appBar: AppBar(
          backgroundColor: AppColors.appBar(context),
          elevation: 0,
          title: Row(
            children: [
              Text('👥', style: TextStyle(fontSize: 20.sp)),
              SizedBox(width: 8.w),
              InterText(
                text: 'friends_screen_title'.tr,
                fontSize: 18.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary(context),
              ),
            ],
          ),
          // v23.1.170 — Daniel : "la demande inviter mais normal ou par
          // mail ne marche pas, il faut corriger". On ajoute un bouton
          // partage en haut à droite qui balance un message d'invitation
          // + lien deep-link via SharePlus (le destinataire peut le coller
          // dans WhatsApp/email/sms etc.).
          actions: [
            // v23.1.274 — Daniel : "dans mes amis enleve la petite icone
            // report de bug". Le bouton diagnostic (loupe bug) servait au
            // debug des demandes d'amis ; il est retire de la barre d'app
            // (la methode controller.diagnose() reste dispo si besoin).
            // v23.1.174 — Accès à la liste des bloqués depuis la barre d'app.
            IconButton(
              icon: Icon(Icons.block_rounded,
                  color: _circleViolet, size: 22.sp),
              tooltip: 'friend_blocked_list'.tr,
              onPressed: () => Get.to(() => const BlockedUsersScreen()),
            ),
            IconButton(
              icon: Icon(Icons.ios_share_rounded,
                  color: _circleViolet, size: 22.sp),
              tooltip: 'friends_invite_link_tooltip'.tr,
              onPressed: () async {
                try {
                  // v23.1.170 — On lit le profil utilisateur depuis le
                  // GetStorage (clé canonique 'user_profile') pour extraire
                  // id + name. Fallback générique si pas trouvé.
                  String myId = '';
                  String myName = '';
                  try {
                    final raw = GetStorage().read(StorageKeys.userProfile);
                    if (raw is Map) {
                      myId = (raw['id'] ?? raw['_id'] ?? '').toString();
                      myName = (raw['name'] ?? '').toString();
                    }
                  } catch (_) {/* noop */}
                  final link = myId.isNotEmpty
                      ? 'https://hopetsit.com/invite?from=$myId'
                      : 'https://hopetsit.com';
                  final text = 'friends_invite_message'.trParams({
                    'name': myName.isEmpty ? 'HoPetSit' : myName,
                    'link': link,
                  });
                  await SharePlus.instance.share(ShareParams(
                    text: text,
                    subject: 'friends_invite_subject'.tr,
                  ));
                } catch (e) {
                  CustomSnackbar.showError(
                    title: 'common_error'.tr,
                    message: e.toString(),
                  );
                }
              },
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            // v23.1 part 212 — Daniel : "le menu est decaler recentre le".
            // Avant : tabAlignment default = start → tabs slammed a gauche.
            // Maintenant : center → l'onglet selectionne se centre dans
            // la viewport quand on swipe, et les tabs ont du padding
            // symetrique.
            tabAlignment: TabAlignment.center,
            // v414 — Daniel : "la page cercle code couleur pas bleu mais
            // violet". Mon cercle (famille & amis PawFollow) = VIOLET partout.
            labelColor: _circleViolet,
            unselectedLabelColor: AppColors.greyText,
            indicatorColor: _circleViolet,
            tabs: [
              // 1. Mes amis — accepted friendships + status + distance.
              Tab(icon: const Icon(Icons.people_rounded),
                  text: 'friends_tab_friends'.tr),
              // v23.1 part 205 — Tab 2 : Demandes (dedie). Le badge rouge
              // count d'incoming requests vit ici (plus semantique que
              // sur Ajouter). _RequestsTab cable plus bas dans TabBarView.
              Tab(
                icon: Obx(() {
                  final n = controller.incomingRequests.length;
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.mark_email_unread_rounded),
                      if (n > 0)
                        Positioned(
                          right: -6,
                          top: -6,
                          child: Container(
                            padding: EdgeInsets.all(3.w),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            constraints: BoxConstraints(minWidth: 14.w, minHeight: 14.w),
                            child: Center(
                              child: Text(
                                '$n',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                }),
                text: 'friends_tab_requests'.tr,
              ),
              // 3. Ajouter — search by name/email + invite link.
              Tab(
                icon: const Icon(Icons.person_add_alt_1_rounded),
                text: 'friends_tab_add'.tr,
              ),
              // v23.1 part 225 — Daniel : "vire personne en live et je sais
              // pas si on vire pas aussi animeaux". Reponse : on vire les 2.
              // 4. Famille — membres PawFollow Famille (jusqu'a 5).
              Tab(
                icon: const Icon(Icons.people_alt_rounded),
                text: 'friends_tab_family'.tr,
              ),
              // v23.1 part 244 — onglet Messages supprime (Daniel : "longlet
              // a droite message efface le y sert pas"). Doublon avec le
              // chat principal du bottom nav.
            ],
          ),
        ),
        // v23.1.195 — Daniel : "les demande damis et famille senvoi mais
        // personne ne recoi ni linvitation ni la notification". Les push
        // notifs FCM peuvent etre perdues (tokens stales, etc.). On rend
        // les demandes pending TOUJOURS visibles via un banner en haut
        // de l'ecran, peu importe l'onglet selectionne.
        body: Column(
          children: [
            _PendingRequestsBanner(controller: controller),
            Expanded(
              child: TabBarView(
                children: [
                  _FriendsTab(controller: controller),
                  // v23.1 part 205 — onglet Demandes cable (Daniel
                  // "peut-etre rajouter Demande pour voir les demandes")
                  _RequestsTab(controller: controller),
                  _AddFriendTab(controller: controller),
                  _FamilyTab(controller: controller),
                  // v23.1 part 244 — _MessagesTab supprime (Daniel : doublon
                  // avec le chat principal).
                ],
              ),
            ),
          ],
        ),
        // v23.1.185 — Le FAB "Ajouter un ami" disparait : l'onglet
        // "Ajouter" remplit cette fonction maintenant (mockup Daniel).
      ),
    );
  }
}

class _FriendsTab extends StatelessWidget {
  const _FriendsTab({required this.controller});
  final FriendController controller;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: Obx(() {
        // v23.1.278 — Daniel : "quand j'enlève un membre de la famille, il
        // reste en violet". L'Obx n'observait que `friends`, pas
        // `familyMembers` → la tuile gardait isFamily=true (violet) après un
        // retrait. On déclare familyMembers.length comme dépendance pour que
        // la couleur/role de chaque tuile se recalcule dès l'ajout/retrait.
        // ignore: unused_local_variable
        final famLen = controller.familyMembers.length;
        if (controller.isLoading.value && controller.friends.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (controller.friends.isEmpty) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(24.w),
            children: [
              SizedBox(height: 40.h),
              Center(
                child: Column(
                  children: [
                    Text('🐾', style: TextStyle(fontSize: 50.sp)),
                    SizedBox(height: 12.h),
                    // v23.1 part 244 — i18n.
                    InterText(
                      text: 'friends_empty_title'.tr,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary(context),
                    ),
                    SizedBox(height: 4.h),
                    InterText(
                      text: 'friends_empty_subtitle'.tr,
                      fontSize: 13.sp,
                      color: AppColors.greyText,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          );
        }
        return ListView.separated(
          // v465 — Daniel : le dernier élément (et son bouton) était caché
          // derrière la barre système Samsung. On ajoute une marge basse =
          // inset système + 24 pour qu'il reste toujours visible/scrollable.
          padding: EdgeInsets.fromLTRB(12.w, 12.w, 12.w,
              24.h + MediaQuery.of(context).viewPadding.bottom),
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: controller.friends.length,
          separatorBuilder: (_, __) => SizedBox(height: 10.h),
          itemBuilder: (_, i) => _FriendTile(
            friendship: controller.friends[i],
            controller: controller,
          ),
        );
      }),
    );
  }
}

class _FriendTile extends StatelessWidget {
  const _FriendTile({required this.friendship, required this.controller});

  final Friendship friendship;
  final FriendController controller;

  @override
  Widget build(BuildContext context) {
    // v23.1 part 205 — Daniel : "amis ajouter ma liste est vide". Root
    // cause : `friendship.other!` crashait silencieusement la tile entière
    // dès qu'un orphelin (utilisateur supprimé) remontait sans `other`,
    // ce qui pouvait planter la liste complète à l'affichage. On rend la
    // chose null-safe : si other manque, on synthétise un FriendProfile
    // placeholder "Utilisateur supprimé" (id vide → désactive le tap
    // suivi + le chat 💬 plus bas).
    final other = friendship.other ??
        const FriendProfile(
          id: '',
          model: 'Owner',
          name: 'Utilisateur supprimé',
          avatar: '',
          city: '',
        );
    // v23.1.190 — Daniel : "le plus facile pour le code couleur famille
    // et amis en violet walker en vert sitter en bleu". Owner = friend /
    // famille → violet (cohérent avec la carte "Famille & Amis" du
    // PawMap header). Walker = vert, Sitter = bleu (deja en place).
    // v23.1.267 — Daniel : "les membres famille doivent se mettre en violet".
    // Le code couleur par rôle (sitter bleu / walker vert) masquait
    // l'appartenance famille. Si l'ami est AUSSI un membre de ma famille, on
    // force le violet, peu importe son rôle.
    final familyIds = controller.familyMembers
        .map((m) => (m['id'] ?? m['userId'] ?? '').toString())
        .where((s) => s.isNotEmpty)
        .toSet();
    final isFamily = other.id.isNotEmpty && familyIds.contains(other.id);
    final roleColor = isFamily
        ? const Color(0xFF8B5CF6)
        : ({
            'Owner': AppColors.primaryColor, // v23.1.295 — owner = ORANGE (était violet, confondu avec Famille)
            'Sitter': AppColors.sitterAccent,
            'Walker': AppColors.greenColor,
          }[other.model] ?? const Color(0xFF8B5CF6));
    // v23.1.280 — Daniel : "je veux ce design (web) dans amis famille : rôle +
    // badge FAMILLE, et si l'ami a PawSpot un anneau doré/bleu sur l'avatar".
    //   - roleColorPure : couleur du MÉTIER (jamais violet) pour le badge rôle.
    //   - pawSpotRing : doré (gold/platinum) ou bleu (bronze/silver) selon
    //     l'option PawSpot active, sinon null.
    //   - avatarRing : PawSpot prioritaire, sinon violet famille, sinon rôle.
    final roleColorPure = ({
          'Owner': AppColors.primaryColor, // v23.1.295 — owner = ORANGE
          'Sitter': AppColors.sitterAccent,
          'Walker': AppColors.greenColor,
        }[other.model] ??
        AppColors.primaryColor);
    Color? pawSpotRing;
    switch (other.pawSpotTier) {
      case 'gold':
      case 'platinum':
        pawSpotRing = const Color(0xFFF59E0B); // doré
        break;
      case 'silver':
      case 'bronze':
        pawSpotRing = const Color(0xFF3B82F6); // bleu
        break;
    }
    final avatarRing =
        pawSpotRing ?? (isFamily ? const Color(0xFF8B5CF6) : roleColorPure);

    // v23.1.170 — Daniel : "si une famille veux se suivre que juste en
    // cliquand sur le nom ds sa liste damis par exemplet sa le geoloclaise".
    // Tap sur la card → vérifie via /friends/:id/track-access si on peut
    // tracker (famille PawFollow Famille auto, OU friend share-position
    // activé), puis ouvre la PawMap. Sinon snackbar + lien upsell.
    return InkWell(
      borderRadius: BorderRadius.circular(16.r),
      onTap: () async {
        // v23.1 part 241 — Daniel : "qd on clic sur lami sa me met pas
        // sa position sur pawmap". Avant : on ouvrait PawMapScreen() SANS
        // params → _bootstrap centrait sur MA position. Maintenant : on
        // fetch la position fresh de l'ami (socket cache → fallback API
        // /friends/:id/last-position) et on passe focusUserId/Role/Name
        // → PawMap _bootstrap respecte initialLat/Lng (cf fix v240) +
        // injecte synthetic FriendPosition → halo couleur autour de lui.
        Future<void> openMapForFriend() async {
          double? lat;
          double? lng;
          // 1) socket cache (most fresh).
          try {
            final svc = Get.isRegistered<LiveMapService>()
                ? Get.find<LiveMapService>()
                : null;
            final pos = svc?.friendPositions[other.id];
            if (pos != null) {
              lat = pos.latitude;
              lng = pos.longitude;
            }
          } catch (_) {/* defensive */}
          // 2) fallback DB position via /friends/:id/last-position.
          if (lat == null || lng == null) {
            try {
              final api = Get.find<ApiClient>();
              final r = await api.get(
                '/friends/${other.id}/last-position',
                requiresAuth: true,
              );
              if (r is Map) {
                final rLat = r['lat'];
                final rLng = r['lng'];
                if (rLat is num && rLng is num) {
                  lat = rLat.toDouble();
                  lng = rLng.toDouble();
                }
              }
            } catch (_) {/* defensive */}
          }
          // v23.1.400 — Daniel : « le retour depuis Suivre me remet sur la
          // liste Amis au lieu de la carte ». Get.off REMPLACE l'écran Amis
          // par la carte-focus → le bouton retour ramène directement à la
          // carte (onglet, menu en bas), plus jamais sur la liste Amis.
          Get.off(() => PawMapScreen(
                initialLat: lat,
                initialLng: lng,
                focusUserId: other.id,
                focusUserRole: other.model.toLowerCase(),
                focusUserName: other.name,
              ));
        }

        // Quick local check : si l'ami partage avec moi → direct ouverture.
        if (friendship.theirSharePosition) {
          await openMapForFriend();
          return;
        }
        // Sinon on demande au backend (la famille bypass le share flag).
        final access = await controller.checkTrackAccess(other.id);
        final canTrack = access['canTrack'] == true;
        if (canTrack) {
          await openMapForFriend();
          return;
        }
        CustomSnackbar.showInfo(
          title: 'friends_tap_not_shared_title'.tr,
          message: 'friends_tap_not_shared_msg'
              .trParams({'name': other.name.isEmpty ? '—' : other.name}),
        );
      },
      child: Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: AppColors.cardShadow(context),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              // v23.1.280 — anneau coloré (PawSpot doré/bleu, sinon famille/role).
              border: Border.all(color: avatarRing, width: 2.4),
            ),
            child: CircleAvatar(
              radius: 23.r,
              backgroundColor: roleColor.withValues(alpha: 0.15),
              child: other.avatar.isNotEmpty
                  ? ClipOval(
                      // v23.1 part 233 — perf memCacheWidth 150 (3x retina).
                      child: CachedNetworkImage(
                        imageUrl: other.avatar,
                        width: 46.r,
                        height: 46.r,
                        memCacheWidth: 150,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) =>
                            Icon(Icons.person, color: roleColor, size: 22.sp),
                      ),
                    )
                  : Icon(Icons.person, color: roleColor, size: 22.sp),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InterText(
                  text: other.name.isEmpty ? 'Utilisateur' : other.name,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary(context),
                ),
                SizedBox(height: 4.h),
                // v23.1.280 — design web : badge RÔLE (couleur métier traduite)
                // + badge FAMILLE violet EN PLUS si famille + badge PawSpot
                // doré/bleu si l'ami a l'option. Wrap pour ne jamais déborder.
                Wrap(
                  spacing: 6.w,
                  runSpacing: 4.h,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _miniBadge(
                      label: <String, String>{
                            'Walker': 'role_walker'.tr,
                            'Sitter': 'role_sitter'.tr,
                            'Owner': 'role_owner'.tr,
                          }[other.model] ??
                          other.model,
                      color: roleColorPure,
                    ),
                    if (isFamily)
                      _miniBadge(
                        label: 'friends_tab_family'.tr,
                        color: const Color(0xFF8B5CF6),
                      ),
                    if (pawSpotRing != null)
                      _miniBadge(label: 'PawSpot', color: pawSpotRing),
                    if (other.city.isNotEmpty)
                      InterText(
                        text: other.city,
                        fontSize: 11.sp,
                        color: AppColors.greyText,
                      ),
                  ],
                ),
              ],
            ),
          ),
          // v23.1.200 — Daniel : "bouton 💬 sur friend" qui ouvre un
          // chat 1-to-1 avec cet ami. Cache si other.deleted (compte
          // supprime) ou other.id vide (defensive v201).
          // v23.1 part 205 — Daniel : "le chat dans l'onglet marche pas".
          // Root cause : on naviguait TOUJOURS vers IndividualChatScreen
          // (owner chat), même si le user courant est sitter/walker.
          // Maintenant : on délègue à _openFriendChatRoleAware qui lit le
          // rôle du user courant et navigue vers le bon écran.
          if (other.id.isNotEmpty)
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20.r),
                onTap: () => _openFriendChatRoleAware(
                  controller: controller,
                  other: other,
                ),
                child: Container(
                  width: 36.w, height: 36.w,
                  decoration: BoxDecoration(
                    // v419 — accent violet « Mon cercle » (maquette en violet).
                    color: _circleViolet.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.chat_bubble_rounded,
                      color: _circleViolet, size: 18.sp),
                ),
              ),
            ),
          if (other.id.isNotEmpty) SizedBox(width: 4.w),
          // v18.9.8 — Share position toggle : couleur selon rôle actif
          // (orange owner / bleu sitter / vert walker) au lieu de toujours
          // orange hardcodé.
          // v23.1 part 226 — Daniel : "debloque le partage si jai un
          // abo paw follow car le bouton est verrouille". Quand l'user
          // a PawFollow actif (myShareAutoByPawFollow=true exposed par
          // backend v226 + propage via FriendController.viewerHasPawFollow),
          // la Switch est forcee ON, read-only, et un mini badge
          // "Auto · PawFollow" remplace le label "Partager".
          // v23.1 part 244 — Daniel : "le bouton auto est toujour bloque je
          // dois etre en possibiliter metre on ou off". Cause : meme apres
          // le fix v243 round 2 cote backend (qui debloque le toggle),
          // l'UI affichait toujours le badge "Auto" en dessous, ce qui
          // donnait l'impression visuelle que la switch etait verrouillee
          // alors qu'elle etait fonctionnelle. Fix : on supprime le badge
          // Auto, on garde le label uniforme "Partager" en dessous.
          Column(
            children: [
              Transform.scale(
                scale: 0.75,
                child: AppSwitch(
                  value: friendship.mySharePosition,
                  // v419 — toggle violet (accent « Mon cercle », maquette violet).
                  accent: _circleViolet,
                  onChanged: (v) =>
                      controller.setSharePosition(friendship.id, v),
                ),
              ),
              InterText(
                text: 'friends_share_position_label'.tr,
                fontSize: 9.sp,
                color: AppColors.greyText,
              ),
            ],
          ),
          SizedBox(width: 4.w),
          // v23.1.174 — Daniel : "Manque boutons Bloquer et Supprimer dans
          // la liste d'amis". On a maintenant 3 actions au lieu d'une.
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, size: 18.sp, color: AppColors.greyText),
            onSelected: (v) async {
              if (v == 'block') {
                final confirmed = await Get.dialog<bool>(
                  AlertDialog(
                    title: Text('friend_block_confirm'.tr),
                    content: Text('friend_block_confirm_desc'
                        .trParams({'name': other.name})),
                    actions: [
                      TextButton(
                        onPressed: () => Get.back(result: false),
                        child: Text('common_cancel'.tr),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.errorColor,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => Get.back(result: true),
                        child: Text('friend_block'.tr),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  final ok = await controller.blockUser(
                    targetUserId: other.id,
                    targetRole: other.model.toLowerCase(),
                  );
                  if (ok) {
                    CustomSnackbar.showSuccess(
                      title: 'friend_blocked_title'.tr,
                      message: 'friend_blocked_msg'
                          .trParams({'name': other.name}),
                    );
                  }
                }
              } else if (v == 'unfriend') {
                final confirmed = await Get.dialog<bool>(
                  AlertDialog(
                    title: Text('friend_remove_confirm'.tr),
                    content: Text('friend_remove_confirm_desc'
                        .trParams({'name': other.name})),
                    actions: [
                      TextButton(
                        onPressed: () => Get.back(result: false),
                        child: Text('common_cancel'.tr),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.errorColor,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => Get.back(result: true),
                        child: Text('friend_remove'.tr),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  final ok = await controller.unfriend(friendship.id);
                  if (ok) {
                    CustomSnackbar.showSuccess(
                      title: 'friend_removed_title'.tr,
                      message: 'friend_removed_msg'.tr,
                    );
                  }
                }
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'block',
                child: Row(
                  children: [
                    Icon(Icons.block_rounded,
                        color: AppColors.errorColor, size: 18.sp),
                    SizedBox(width: 8.w),
                    Text('friend_block'.tr),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'unfriend',
                child: Row(
                  children: [
                    Icon(Icons.person_remove_rounded,
                        color: AppColors.textSecondary(context), size: 18.sp),
                    SizedBox(width: 8.w),
                    Text('friend_remove'.tr),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }

  // v23.1.280 — Daniel : "réorganise les badges que ça fasse propre". Mini
  // badge pilule (fond couleur 15% + texte couleur, gras) réutilisé pour le
  // rôle (couleur métier), FAMILLE (violet) et PawSpot (doré/bleu). Même
  // langage visuel que les cartes amis du site web.
  Widget _miniBadge({required String label, required Color color}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: InterText(
        text: label,
        fontSize: 9.sp,
        fontWeight: FontWeight.w700,
        color: color,
      ),
    );
  }
}

class _RequestsTab extends StatelessWidget {
  const _RequestsTab({required this.controller});
  final FriendController controller;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: Obx(() {
        final incoming = controller.incomingRequests;
        final outgoing = controller.outgoingRequests;
        if (incoming.isEmpty && outgoing.isEmpty) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(24.w),
            children: [
              SizedBox(height: 60.h),
              Center(
                child: InterText(
                  text: 'friends_no_pending_request'.tr,
                  fontSize: 13.sp,
                  color: AppColors.greyText,
                ),
              ),
            ],
          );
        }
        return ListView(
          padding: EdgeInsets.all(12.w),
          children: [
            if (incoming.isNotEmpty) ...[
              _sectionHeader(context, 'Reçues'),
              ...incoming.map(
                (f) => _IncomingTile(friendship: f, controller: controller),
              ),
              SizedBox(height: 20.h),
            ],
            if (outgoing.isNotEmpty) ...[
              _sectionHeader(context, 'Envoyées'),
              ...outgoing.map((f) => _OutgoingTile(friendship: f)),
            ],
          ],
        );
      }),
    );
  }

  Widget _sectionHeader(BuildContext context, String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h, top: 4.h, left: 4.w),
      child: InterText(
        text: text,
        fontSize: 12.sp,
        fontWeight: FontWeight.w700,
        color: AppColors.greyText,
      ),
    );
  }
}

class _IncomingTile extends StatelessWidget {
  const _IncomingTile({required this.friendship, required this.controller});
  final Friendship friendship;
  final FriendController controller;

  @override
  Widget build(BuildContext context) {
    final other = friendship.other;
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(14.r),
        boxShadow: AppColors.cardShadow(context),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22.r,
            backgroundColor: AppColors.primaryColor.withValues(alpha: 0.15),
            child: Icon(Icons.person, color: AppColors.primaryColor, size: 22.sp),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InterText(
                  text: other?.name ?? 'Utilisateur',
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary(context),
                ),
                SizedBox(height: 2.h),
                InterText(
                  text: 'souhaite être ami avec toi',
                  fontSize: 11.sp,
                  color: AppColors.greyText,
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.check_circle, color: Colors.green, size: 26.sp),
            onPressed: () async {
              final ok = await controller.accept(friendship.id);
              if (ok) {
                CustomSnackbar.showSuccess(
                  title: 'Accepté',
                  message: 'Vous êtes maintenant amis.',
                );
              }
            },
          ),
          IconButton(
            icon: Icon(Icons.cancel, color: Colors.red, size: 26.sp),
            onPressed: () => controller.decline(friendship.id),
          ),
        ],
      ),
    );
  }
}

class _OutgoingTile extends StatelessWidget {
  const _OutgoingTile({required this.friendship});
  final Friendship friendship;

  @override
  Widget build(BuildContext context) {
    final other = friendship.other;
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.divider(context)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20.r,
            backgroundColor: Colors.grey.shade200,
            child: Icon(Icons.schedule, color: AppColors.greyText, size: 18.sp),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InterText(
                  text: other?.name ?? 'Utilisateur',
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary(context),
                ),
                InterText(
                  text: 'friends_pending'.tr,
                  fontSize: 11.sp,
                  color: AppColors.greyText,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── v23.1.172 — Famille tab (PawFollow Famille €9.99) ─────────────────────
//
// Daniel : "le truc de famille je le vois pas non plus". Cet onglet montre :
//   - Si pas d'abo Famille actif : CTA "Souscris PawFollow Famille"
//   - Si abo actif : liste des membres + bouton "+ Inviter un ami" (filtre
//     parmi les amis acceptés) + bouton "Retirer" par membre.

class _FamilyTab extends StatelessWidget {
  const _FamilyTab({required this.controller});
  final FriendController controller;

  @override
  Widget build(BuildContext context) {
    // v23.1.274 — Daniel : "le paw follow famille change la police couleur
    // violet comme ca le code couleur de lapp a un sens". L'onglet Famille
    // utilise desormais le VIOLET famille (#8B5CF6) comme accent au lieu de
    // la couleur du role, pour rester coherent avec le halo famille de la
    // PawMap, le 4eme orteil violet du logo et la carte "Famille active".
    const accent = Color(0xFF8B5CF6);
    return RefreshIndicator(
      onRefresh: () => controller.loadFamily(),
      child: Obx(() {
        if (!controller.hasFamilyPlan.value) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(24.w),
            children: [
              SizedBox(height: 40.h),
              Container(
                padding: EdgeInsets.all(20.w),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: accent.withValues(alpha: 0.25)),
                ),
                child: Column(
                  children: [
                    Icon(Icons.family_restroom_rounded,
                        size: 56.sp, color: accent),
                    SizedBox(height: 12.h),
                    InterText(
                      text: 'family_no_plan_title'.tr,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary(context),
                    ),
                    SizedBox(height: 8.h),
                    InterText(
                      text: 'family_no_plan_desc'.tr,
                      fontSize: 12.sp,
                      color: AppColors.textSecondary(context),
                    ),
                    SizedBox(height: 16.h),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                        icon: const Icon(Icons.shopping_cart_rounded),
                        label: Text('family_no_plan_cta'.tr),
                        onPressed: () =>
                            Get.to(() => const CoinShopScreen(initialTab: 1)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }
        final members = controller.familyMembers;
        // v23.1 part 226 — Daniel screenshot mockup : "longlet famille
        // je le veux comme sa". Redesign :
        //   1. Top card "PawFollow Famille actif" avec shield+paw orange
        //      sur fond rose + illustration famille a droite + count
        //      "X / 5 membres ajoutes" + sous-texte explicatif.
        //   2. Section "Inviter un membre a ma famille" avec 2 grosses
        //      cards inline "Par nom" / "Par email" (icone rond orange
        //      + label + sous-texte + chevron) au lieu d'un bouton qui
        //      ouvre un bottom sheet 2-onglets.
        //   3. Liste des membres dessous (ou message si vide).
        return ListView(
          padding: EdgeInsets.all(12.w),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            // ── 1. Top hero card "PawFollow Famille actif" ──────────────
            // v23.1.274 — Daniel : "le paw follow famille change la police
            // couleur violet comme ca le code couleur de lapp a un sens".
            // La famille = VIOLET (#8B5CF6 / #7C3AED), comme le halo famille
            // sur la PawMap et le 4eme orteil du logo. On repasse donc cette
            // carte du theme orange historique au theme violet famille :
            // fond violet clair, anneau bouclier violet, titre + compteur
            // en violet. Coherent avec tout le code couleur de l'app.
            Container(
              padding: EdgeInsets.fromLTRB(16.w, 16.h, 12.w, 16.h),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF5F3FF), Color(0xFFEDE9FE)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Shield+paw violet ring icon (left) — code couleur famille.
                  Container(
                    width: 52.w,
                    height: 52.w,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.30),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(Icons.shield_rounded,
                        color: Colors.white, size: 28.sp),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InterText(
                          text: 'family_active_title'.tr,
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF7C3AED),
                        ),
                        SizedBox(height: 4.h),
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: '${members.length} / 5 ',
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF7C3AED),
                                ),
                              ),
                              TextSpan(
                                text: 'family_members_added'.tr,
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  color: AppColors.textPrimary(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 6.h),
                        InterText(
                          text: 'family_active_desc'.tr,
                          fontSize: 11.sp,
                          color: AppColors.textSecondary(context),
                        ),
                      ],
                    ),
                  ),
                  // Family illustration (emoji stack) — visible only on
                  // larger screens (right of the text).
                  SizedBox(width: 4.w),
                  Column(
                    children: [
                      Row(
                        children: [
                          Text('👨', style: TextStyle(fontSize: 18.sp)),
                          Text('👩', style: TextStyle(fontSize: 18.sp)),
                        ],
                      ),
                      Row(
                        children: [
                          Text('🧒', style: TextStyle(fontSize: 16.sp)),
                          Text('🐕', style: TextStyle(fontSize: 16.sp)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 16.h),
            // ── 2. "Inviter un membre" section header ──────────────────
            // v23.1 part 251 — Daniel : "Manque bouton a jouter un membre
            // et choisir liste amis ou famille". 2 corrections :
            //   a) Le gating utilisait familyRemainingSlots (Rx separe qui
            //      pouvait desync → "Famille pleine" affiche a tort alors
            //      que la hero card montrait "1/5"). On utilise desormais
            //      members.length < 5 (coherent avec la hero card).
            //   b) Ajout d'une grosse carte "Depuis mes amis" en 1er qui
            //      ouvre un picker de la liste d'amis (tap un ami → invite).
            // v23.1.281 — Daniel : "je n'arrive pas à ajouter de membre". Si je
            // suis MEMBRE (pas titulaire) d'une famille, je ne dois PAS voir l'UI
            // "Inviter un membre" (elle échoue, seul le titulaire peut ajouter).
            // On affiche à la place une bannière "Tu es dans la famille de X".
            if (!controller.isFamilyHolder.value) ...[
              Container(
                padding: EdgeInsets.all(14.w),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDE9FE),
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.30),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        color: const Color(0xFF7C3AED), size: 22.sp),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InterText(
                            text: (controller.familyHolder.value?['name'] ?? '')
                                    .toString()
                                    .isEmpty
                                ? 'family_you_are_member_generic'.tr
                                : 'family_you_are_member'.trParams({
                                    'name': (controller
                                                .familyHolder.value?['name'] ??
                                            '')
                                        .toString(),
                                  }),
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF7C3AED),
                          ),
                          SizedBox(height: 4.h),
                          InterText(
                            text: 'family_member_only_hint'.tr,
                            fontSize: 11.sp,
                            color: AppColors.textSecondary(context),
                          ),
                          SizedBox(height: 10.h),
                          // v23.1.282 — sortie : un membre peut quitter la
                          // famille pour redevenir libre (créer la sienne).
                          Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final confirmed = await Get.dialog<bool>(
                                  AlertDialog(
                                    title: Text('family_leave_button'.tr),
                                    content: Text('family_leave_confirm_desc'.tr),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Get.back(result: false),
                                        child: Text('common_cancel'.tr),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.errorColor,
                                          foregroundColor: Colors.white,
                                        ),
                                        onPressed: () => Get.back(result: true),
                                        child: Text('family_leave_button'.tr),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed != true) return;
                                final ok = await controller.leaveFamily();
                                if (ok) {
                                  CustomSnackbar.showSuccess(
                                    title: 'family_leave_button'.tr,
                                    message: 'family_left_msg'.tr,
                                  );
                                }
                              },
                              icon: Icon(Icons.logout_rounded,
                                  size: 16.sp, color: const Color(0xFF7C3AED)),
                              label: Text(
                                'family_leave_button'.tr,
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF7C3AED),
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                    color: Color(0xFF8B5CF6), width: 1.2),
                                padding: EdgeInsets.symmetric(
                                    horizontal: 12.w, vertical: 6.h),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10.r)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 18.h),
            ] else if (members.length < 5) ...[
              InterText(
                text: 'family_invite_section_title'.tr,
                fontSize: 14.sp,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary(context),
              ),
              SizedBox(height: 4.h),
              InterText(
                text: 'family_invite_section_desc'.tr,
                fontSize: 11.sp,
                color: AppColors.greyText,
              ),
              SizedBox(height: 10.h),
              // v251 — methode principale : choisir depuis ses amis.
              _FamilyInviteOptionCard(
                icon: Icons.group_rounded,
                title: 'family_add_from_friends'.tr,
                subtitle: 'family_add_from_friends_sub'.tr,
                onTap: () => _showAddFromFriendsSheet(context, controller),
              ),
              SizedBox(height: 10.h),
              // 2 cards inline "Par nom" / "Par email" (methodes secondaires)
              Row(
                children: [
                  Expanded(
                    child: _FamilyInviteOptionCard(
                      icon: Icons.person_rounded,
                      title: 'family_add_by_name'.tr,
                      subtitle: 'family_invite_by_name_sub'.tr,
                      onTap: () => _showAddByNameSheet(context, controller),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: _FamilyInviteOptionCard(
                      icon: Icons.mail_outline_rounded,
                      title: 'family_add_by_email'.tr,
                      subtitle: 'family_invite_by_email_sub'.tr,
                      onTap: () => _showAddByEmailSheet(context, controller),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 18.h),
            ] else
              Padding(
                padding: EdgeInsets.symmetric(vertical: 8.h),
                child: Center(
                  child: InterText(
                    text: 'family_full_msg'.tr,
                    fontSize: 12.sp,
                    color: AppColors.greyText,
                  ),
                ),
              ),
            // ── 3. Liste des membres (ou message vide) ─────────────────
            if (members.isNotEmpty) ...[
              InterText(
                text: 'family_members_list_title'.tr,
                fontSize: 13.sp,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary(context),
              ),
              SizedBox(height: 8.h),
              ...members.map((m) => _FamilyMemberTile(
                    member: m,
                    controller: controller,
                    isHolder: controller.isFamilyHolder.value,
                  )),
            ] else
              Padding(
                padding: EdgeInsets.symmetric(vertical: 18.h),
                child: Center(
                  child: InterText(
                    text: 'family_empty_msg'.tr,
                    fontSize: 13.sp,
                    color: AppColors.greyText,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      }),
    );
  }

  // v23.1 part 226 — bottom sheet dedie a "Par nom" (sans le TabController
  // 2-onglets). On garde le _FamilyAddByName existant.
  void _showAddByNameSheet(BuildContext context, FriendController controller) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: EdgeInsets.all(16.w),
        constraints: BoxConstraints(maxHeight: 480.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.person_rounded,
                    color: _circleViolet, size: 24.sp),
                SizedBox(width: 8.w),
                Expanded(
                  child: InterText(
                    text: 'family_add_by_name'.tr,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Expanded(child: _FamilyAddByName(ctx: ctx, controller: controller)),
          ],
        ),
      ),
    );
  }

  // v23.1 part 226 — bottom sheet dedie "Par email".
  void _showAddByEmailSheet(BuildContext context, FriendController controller) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Container(
          padding: EdgeInsets.all(16.w),
          constraints: BoxConstraints(maxHeight: 480.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.mail_outline_rounded,
                      color: _circleViolet, size: 24.sp),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: InterText(
                      text: 'family_add_by_email'.tr,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              _FamilyAddByEmail(ctx: ctx, controller: controller),
            ],
          ),
        ),
      ),
    );
  }

  // v23.1 part 251 — Daniel : "choisir liste amis ou famille". Bottom
  // sheet qui liste les amis acceptes (hors membres famille deja ajoutes)
  // et permet d'en inviter un en 1 tap → addFamilyMember.
  void _showAddFromFriendsSheet(
      BuildContext context, FriendController controller) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: EdgeInsets.all(16.w),
        constraints: BoxConstraints(maxHeight: 520.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.group_rounded,
                    color: _circleViolet, size: 24.sp),
                SizedBox(width: 8.w),
                Expanded(
                  child: InterText(
                    text: 'family_add_from_friends'.tr,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Expanded(
              child: Obx(() {
                // Amis acceptes pas deja dans la famille.
                final familyIds = controller.familyMembers
                    .map((m) => (m['id'] ?? m['userId'] ?? '').toString())
                    .toSet();
                final candidates = controller.friends
                    .where((f) =>
                        f.status == 'accepted' &&
                        (f.other?.id.isNotEmpty ?? false) &&
                        !familyIds.contains(f.other!.id))
                    .toList();
                if (candidates.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.w),
                      child: InterText(
                        text: 'family_add_from_friends_empty'.tr,
                        fontSize: 13.sp,
                        color: AppColors.greyText,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: candidates.length,
                  separatorBuilder: (_, __) => SizedBox(height: 8.h),
                  itemBuilder: (_, i) {
                    final other = candidates[i].other!;
                    final roleColor = {
                          'Owner': AppColors.primaryColor, // v23.1.295 — owner = ORANGE (était violet, confondu avec Famille)
                          'Sitter': AppColors.sitterAccent,
                          'Walker': AppColors.greenColor,
                        }[other.model] ??
                        const Color(0xFF8B5CF6);
                    return ListTile(
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 4.w),
                      leading: CircleAvatar(
                        radius: 22.r,
                        backgroundColor: roleColor.withValues(alpha: 0.15),
                        backgroundImage: other.avatar.isNotEmpty
                            ? CachedNetworkImageProvider(other.avatar,
                                maxWidth: 150)
                            : null,
                        child: other.avatar.isEmpty
                            ? Icon(Icons.person, color: roleColor, size: 22.sp)
                            : null,
                      ),
                      title: InterText(
                        text: other.name.isEmpty ? 'Utilisateur' : other.name,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary(context),
                      ),
                      subtitle: InterText(
                        text: other.model,
                        fontSize: 11.sp,
                        color: AppColors.greyText,
                      ),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _circleViolet,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20.r),
                          ),
                        ),
                        onPressed: () async {
                          final err = await controller.addFamilyMember(
                            userId: other.id,
                            userRole: other.model.toLowerCase(),
                          );
                          if (!ctx.mounted) return;
                          if (err.isEmpty) {
                            Navigator.of(ctx).pop();
                            CustomSnackbar.showSuccess(
                              title: 'family_invite_sent_title'.tr,
                              message: 'family_invite_sent_msg'
                                  .trParams({'name': other.name}),
                            );
                          } else {
                            CustomSnackbar.showError(
                              title: 'common_error'.tr,
                              message: err == 'FAMILY_FULL'
                                  ? 'family_full_msg'.tr
                                  : err == 'ALREADY_MEMBER'
                                      ? 'family_already_member'.tr
                                      : err,
                            );
                          }
                        },
                        child: InterText(
                          text: 'family_invite_btn'.tr,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

// v23.1 part 226 — Daniel mockup : "longlet famille je le veux comme sa".
// Card inline "Par nom" / "Par email" avec icone rond orange + label
// + sous-texte + chevron, qui ouvre le bottom sheet correspondant.
class _FamilyInviteOptionCard extends StatelessWidget {
  const _FamilyInviteOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14.r),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: AppColors.card(context),
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(color: AppColors.divider(context)),
          ),
          child: Row(
            children: [
              Container(
                width: 40.w,
                height: 40.w,
                decoration: BoxDecoration(
                  color: const Color(0xFFC92A12).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon,
                    color: const Color(0xFFC92A12), size: 22.sp),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InterText(
                      text: title,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFC92A12),
                      maxLines: 1,
                    ),
                    SizedBox(height: 2.h),
                    InterText(
                      text: subtitle,
                      fontSize: 10.sp,
                      color: AppColors.greyText,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: AppColors.greyText, size: 18.sp),
            ],
          ),
        ),
      ),
    );
  }
}

// ── v23.1.174 — Onglet "Par nom" ──────────────────────────────────────────
class _FamilyAddByName extends StatelessWidget {
  const _FamilyAddByName({required this.ctx, required this.controller});
  final BuildContext ctx;
  final FriendController controller;

  @override
  Widget build(BuildContext context) {
    final eligibleFriends = controller.friends
        .where((f) =>
            f.other != null &&
            !controller.familyMembers.any((m) => m['id'] == f.other!.id))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InterText(
          text: eligibleFriends.isEmpty
              ? 'family_add_member_no_friends'.tr
              : 'family_add_member_pick'.tr,
          fontSize: 12.sp,
          color: AppColors.greyText,
        ),
        SizedBox(height: 8.h),
        Expanded(
          child: ListView.separated(
            itemCount: eligibleFriends.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final f = eligibleFriends[i];
              final other = f.other!;
              return ListTile(
                leading: CircleAvatar(
                  radius: 18.r,
                  backgroundColor:
                      AppColors.primaryColor.withValues(alpha: 0.15),
                  // v23.1 part 231 — perf : CachedNetworkImageProvider 150px.
                  backgroundImage: other.avatar.isNotEmpty
                      ? CachedNetworkImageProvider(other.avatar, maxWidth: 150)
                      : null,
                  child: other.avatar.isEmpty
                      ? Icon(Icons.person, size: 18.sp)
                      : null,
                ),
                title: Text(other.name.isEmpty ? 'Utilisateur' : other.name),
                subtitle: Text(other.model),
                trailing: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    final err = await controller.addFamilyMember(
                      userId: other.id,
                      userRole: other.model.toLowerCase(),
                    );
                    if (!context.mounted) return;
                    if (err.isEmpty) {
                      Navigator.of(ctx).pop();
                      CustomSnackbar.showSuccess(
                        title: 'family_member_added_title'.tr,
                        message: 'family_member_added_msg'
                            .trParams({'name': other.name}),
                      );
                    } else {
                      final msg = err == 'FAMILY_FULL'
                          ? 'family_err_full'.tr
                          : err == 'ALREADY_MEMBER'
                              ? 'family_err_already_member'.tr
                              : err == 'FAMILY_PLAN_REQUIRED'
                                  ? 'family_err_plan_required'.tr
                                  : err;
                      CustomSnackbar.showError(
                        title: 'common_error'.tr,
                        message: msg,
                      );
                    }
                  },
                  child: Text('family_add_btn'.tr),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── v23.1.174 — Onglet "Par email" (nouveau, support non-utilisateurs) ───
class _FamilyAddByEmail extends StatefulWidget {
  const _FamilyAddByEmail({required this.ctx, required this.controller});
  final BuildContext ctx;
  final FriendController controller;

  @override
  State<_FamilyAddByEmail> createState() => _FamilyAddByEmailState();
}

class _FamilyAddByEmailState extends State<_FamilyAddByEmail> {
  final _emailCtrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InterText(
            text: 'family_add_by_email_desc'.tr,
            fontSize: 12.sp,
            color: AppColors.greyText,
          ),
          SizedBox(height: 12.h),
          TextField(
            controller: _emailCtrl,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              hintText: 'ami@example.com',
              prefixIcon: const Icon(Icons.mail_outline_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
          ),
          SizedBox(height: 16.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              icon: _sending
                  ? SizedBox(
                      width: 16.w,
                      height: 16.h,
                      child: const CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text('family_invite_send_btn'.tr),
              onPressed: _sending
                  ? null
                  : () async {
                      final email = _emailCtrl.text.trim();
                      if (email.isEmpty || !email.contains('@')) {
                        CustomSnackbar.showError(
                          title: 'common_error'.tr,
                          message: 'family_invite_invalid_email'.tr,
                        );
                        return;
                      }
                      setState(() => _sending = true);
                      // use_build_context_synchronously : on capture le
                      // Navigator du sheet AVANT l'await (pas de BuildContext
                      // utilisé après le gap async).
                      final sheetNavigator = Navigator.of(widget.ctx);
                      final mode = await widget.controller
                          .addFamilyMemberByEmail(email);
                      if (!mounted) return;
                      setState(() => _sending = false);
                      if (mode == 'existing_user') {
                        sheetNavigator.pop();
                        CustomSnackbar.showSuccess(
                          title: 'family_member_added_title'.tr,
                          message: 'family_invite_existing_user_msg'.tr,
                        );
                      } else if (mode == 'email_invite_sent') {
                        sheetNavigator.pop();
                        CustomSnackbar.showSuccess(
                          title: 'family_invite_sent'.tr,
                          message: 'family_invite_email_sent_msg'
                              .trParams({'email': email}),
                        );
                      } else {
                        final msg = mode == 'FAMILY_FULL'
                            ? 'family_err_full'.tr
                            : mode == 'ALREADY_MEMBER'
                                ? 'family_err_already_member'.tr
                                : mode == 'FAMILY_PLAN_REQUIRED'
                                    ? 'family_err_plan_required'.tr
                                    : mode;
                        CustomSnackbar.showError(
                          title: 'common_error'.tr,
                          message: msg,
                        );
                      }
                    },
            ),
          ),
        ],
      ),
    );
  }
}

class _FamilyMemberTile extends StatelessWidget {
  const _FamilyMemberTile({
    required this.member,
    required this.controller,
    this.isHolder = true,
  });
  final Map<String, dynamic> member;
  final FriendController controller;
  // v23.1.281 — seul le titulaire voit le bouton "retirer" (un membre ne peut
  // pas retirer les autres membres de la famille).
  final bool isHolder;

  @override
  Widget build(BuildContext context) {
    final name = (member['name'] ?? '').toString();
    final avatar = (member['avatar'] ?? '').toString();
    final role = (member['role'] ?? '').toString();
    final id = (member['id'] ?? '').toString();
    // v23.1.273 — Daniel : "ça me l'a mis dans la liste avant même
    // l'acceptation". Un membre invité reste 'pending' tant qu'il n'a pas
    // accepté → on l'affiche avec un badge "En attente" pour qu'il ne soit pas
    // confondu avec un membre actif.
    final status = (member['status'] ?? 'active').toString();
    final isPending = status == 'pending';
    // v23.1.336 — Daniel : "retirer famille bug 404 tjr". Le bouton retirer ne
    // doit s'afficher QUE pour les membres de MA famille (removable=true côté
    // backend). Les co-membres des familles où je suis juste MEMBRE ne sont pas
    // retirables → masquer le bouton (sinon retrait → 404).
    final removable = member['removable'] == true;
    // v23.1.280 — Daniel : "je veux ce design dans amis famille comme sur le
    // web : badge rôle (couleur métier) + badge FAMILLE, et anneau PawSpot
    // doré/bleu selon l'option". Parité avec _FriendTile + cartes web.
    final roleColorPure = ({
          'owner': AppColors.primaryColor, // v23.1.295 — owner = ORANGE
          'sitter': AppColors.sitterAccent,
          'walker': AppColors.greenColor,
        }[role.toLowerCase()] ??
        AppColors.primaryColor);
    final roleLabel = <String, String>{
          'walker': 'role_walker'.tr,
          'sitter': 'role_sitter'.tr,
          'owner': 'role_owner'.tr,
        }[role.toLowerCase()] ??
        (role.isEmpty ? 'role_owner'.tr : role);
    Color? pawSpotRing;
    switch ((member['pawSpotTier'] ?? '').toString().toLowerCase()) {
      case 'gold':
      case 'platinum':
        pawSpotRing = const Color(0xFFF59E0B); // doré
        break;
      case 'silver':
      case 'bronze':
        pawSpotRing = const Color(0xFF3B82F6); // bleu
        break;
    }
    // Famille → anneau violet par défaut, mais PawSpot prioritaire si présent.
    final avatarRing = pawSpotRing ?? const Color(0xFF8B5CF6);
    // v23.1.266 — Daniel : "quand j'appuie sur un membre famille ça ne me
    // renvoie pas à la PawMap". Le tile famille n'avait AUCUN onTap (contraire-
    // ment au tile ami). On ajoute le même comportement : fetch position
    // (socket cache → /friends/:id/last-position) puis ouvre la PawMap centrée
    // sur lui + suivi. La famille est toujours trackable (PawFollow Famille).
    return InkWell(
      borderRadius: BorderRadius.circular(14.r),
      onTap: id.isEmpty
          ? null
          : () async {
              double? lat;
              double? lng;
              try {
                final svc = Get.isRegistered<LiveMapService>()
                    ? Get.find<LiveMapService>()
                    : null;
                final pos = svc?.friendPositions[id];
                if (pos != null) {
                  lat = pos.latitude;
                  lng = pos.longitude;
                }
              } catch (_) {/* defensive */}
              if (lat == null || lng == null) {
                try {
                  final api = Get.find<ApiClient>();
                  final r = await api.get(
                    '/friends/$id/last-position',
                    requiresAuth: true,
                  );
                  if (r is Map) {
                    final rLat = r['lat'];
                    final rLng = r['lng'];
                    if (rLat is num && rLng is num) {
                      lat = rLat.toDouble();
                      lng = rLng.toDouble();
                    }
                  }
                } catch (_) {/* defensive */}
              }
              // v23.1.400 — Get.off : la carte-focus remplace l'écran Amis →
              // retour = carte (onglet, menu en bas), pas la liste Amis.
              Get.off(() => PawMapScreen(
                    initialLat: lat,
                    initialLng: lng,
                    focusUserId: id,
                    focusUserRole: role.toLowerCase(),
                    focusUserName: name,
                  ));
            },
      child: Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(14.r),
        boxShadow: AppColors.cardShadow(context),
      ),
      child: Row(
        children: [
          // v23.1.267 — Daniel : "les membres famille en violet". Chaque
          // entrée ici EST un membre famille → avatar cerclé violet.
          // v23.1.280 — PawSpot prioritaire : anneau doré/bleu si l'option est
          // active, sinon violet famille.
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: avatarRing, width: 2.4),
            ),
            child: CircleAvatar(
              radius: 22.r,
              backgroundColor: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
              // v23.1 part 231 — perf : CachedNetworkImageProvider+maxWidth.
              backgroundImage: avatar.isNotEmpty
                  ? CachedNetworkImageProvider(avatar, maxWidth: 150)
                  : null,
              child: avatar.isEmpty
                  ? const Icon(Icons.person,
                      color: Color(0xFF8B5CF6), size: 20)
                  : null,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InterText(
                  text: name.isEmpty ? '—' : name,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                ),
                SizedBox(height: 4.h),
                // v23.1.280 — design web : badge RÔLE (couleur métier) + badge
                // FAMILLE violet + badge PawSpot doré/bleu + En attente. Wrap
                // pour ne jamais déborder.
                Wrap(
                  spacing: 6.w,
                  runSpacing: 4.h,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _familyMiniBadge(label: roleLabel, color: roleColorPure),
                    _familyMiniBadge(
                      label: 'friends_tab_family'.tr,
                      color: const Color(0xFF8B5CF6),
                    ),
                    if (pawSpotRing != null)
                      _familyMiniBadge(label: 'PawSpot', color: pawSpotRing),
                    // v23.1.273 — badge "En attente" si l'invité n'a pas
                    // encore accepté la demande de famille.
                    if (isPending)
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 7.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: InterText(
                          text: '⏳ ${'family_member_pending'.tr}',
                          fontSize: 9.sp,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFB45309),
                          maxLines: 1,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          // v23.1.200 — Daniel : "bouton 💬 sur family member" pour ouvrir
          // un chat 1-to-1 avec ce membre famille. Cache si id vide
          // (defensive : compte supprime ou pending).
          // v23.1 part 205 — délègue à _openFriendChatRoleAware (cf. note
          // dans _FriendTile pour la fix nav role-aware).
          if (id.isNotEmpty)
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20.r),
                onTap: () => _openFriendChatRoleAware(
                  controller: controller,
                  other: FriendProfile(
                    id: id,
                    model: role,
                    name: name.isEmpty ? 'Membre famille' : name,
                  ),
                ),
                child: Container(
                  width: 36.w, height: 36.w,
                  decoration: BoxDecoration(
                    // v419 — accent violet « Mon cercle » (maquette en violet).
                    color: _circleViolet.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.chat_bubble_rounded,
                      color: _circleViolet, size: 18.sp),
                ),
              ),
            ),
          if (id.isNotEmpty) SizedBox(width: 4.w),
          // v23.1.281 — bouton retirer réservé au titulaire de la famille.
          if (isHolder && removable)
            IconButton(
              icon: Icon(Icons.person_remove_rounded,
                  color: AppColors.errorColor, size: 20.sp),
              tooltip: 'family_remove_member_tooltip'.tr,
              onPressed: () async {
                // v23.1.329 — Daniel : "le bouton retirer membre marche pas".
                // AVANT : échec silencieux (rien affiché si le retrait ratait).
                // MAINTENANT : succès OU message d'erreur clair.
                final err = await controller.removeFamilyMember(id);
                if (!context.mounted) return;
                if (err == null) {
                  CustomSnackbar.showSuccess(
                    title: 'family_member_removed_title'.tr,
                    message: 'family_member_removed_msg'
                        .trParams({'name': name}),
                  );
                } else {
                  CustomSnackbar.showError(
                    title: 'common_error'.tr,
                    message: err,
                  );
                }
              },
            ),
        ],
      ),
      ),
    );
  }

  // v23.1.280 — mini badge pilule (parité _FriendTile._miniBadge) pour
  // l'onglet Famille : rôle (couleur métier), FAMILLE (violet), PawSpot.
  Widget _familyMiniBadge({required String label, required Color color}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: InterText(
        text: label,
        fontSize: 9.sp,
        fontWeight: FontWeight.w700,
        color: color,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// v23.1.185 — Daniel mockup : nouvelles tabs Ajouter / Animaux / Messages.
// Le tab Demandes est supprime (notification cards v183 gerent l'accept/
// refuse inline dans la cloche).
// ─────────────────────────────────────────────────────────────────────────

class _AddFriendTab extends StatefulWidget {
  const _AddFriendTab({required this.controller});
  final FriendController controller;

  @override
  State<_AddFriendTab> createState() => _AddFriendTabState();
}

class _AddFriendTabState extends State<_AddFriendTab> {
  final TextEditingController _searchCtrl = TextEditingController();
  final RxList<Map<String, dynamic>> _results = <Map<String, dynamic>>[].obs;
  final RxBool _loading = false.obs;
  // v23.1 part 243 — Daniel : "difficulute a rajouter amis". Cause racine
  // partielle : _onSearch lance un GET /friends/search a CHAQUE keystroke
  // (pas de debounce). Sur reseau lent, le UI etait perpetuellement en
  // "loading" et les resultats clignotaient. Maintenant 300ms debounce :
  // on attend que l'user s'arrete de taper avant de hit le backend.
  Timer? _debounce;
  // v23.1 part 243 — garde la derniere requete recue pour ne pas
  // re-render des resultats perimes si l'user a deja efface le champ.
  String _lastQuery = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch(String q) {
    // v23.1 part 243 — debounce + cancellation. On annule le timer
    // precedent et on en cree un nouveau, donc seul le DERNIER input
    // declenche un appel reseau.
    _debounce?.cancel();
    if (q.trim().length < 2) {
      _results.clear();
      _loading.value = false;
      _lastQuery = '';
      return;
    }
    _lastQuery = q;
    _loading.value = true;
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final captured = q;
      try {
        final users = await widget.controller.searchUsers(captured);
        // Si l'user a tape autre chose entretemps, on jette le resultat.
        if (captured != _lastQuery) return;
        _results.assignAll(users);
      } finally {
        if (captured == _lastQuery) _loading.value = false;
      }
    });
  }

  Future<void> _onShareInvite() async {
    try {
      String myId = '';
      String myName = '';
      try {
        final raw = GetStorage().read(StorageKeys.userProfile);
        if (raw is Map) {
          myId = (raw['id'] ?? raw['_id'] ?? '').toString();
          myName = (raw['name'] ?? '').toString();
        }
      } catch (_) {/* noop */}
      final link = myId.isNotEmpty
          ? 'https://hopetsit.com/invite?from=$myId'
          : 'https://hopetsit.com';
      final text = 'friends_invite_message'.trParams({
        'name': myName.isEmpty ? 'HoPetSit' : myName,
        'link': link,
      });
      await SharePlus.instance.share(ShareParams(
        text: text,
        subject: 'friends_invite_subject'.tr,
      ));
    } catch (e) {
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: e.toString(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 24.h),
      children: [
        // Bouton partage lien (WhatsApp / SMS / email).
        OutlinedButton.icon(
          onPressed: _onShareInvite,
          icon: Icon(Icons.ios_share_rounded,
              color: _circleViolet, size: 20.sp),
          label: Padding(
            padding: EdgeInsets.symmetric(vertical: 4.h),
            child: InterText(
              text: 'friends_add_share_link'.tr,
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
              color: _circleViolet,
            ),
          ),
          style: OutlinedButton.styleFrom(
            side: BorderSide(
              color: _circleViolet.withValues(alpha: 0.4),
              width: 1.2,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14.r),
            ),
            minimumSize: Size(double.infinity, 48.h),
          ),
        ),
        SizedBox(height: 14.h),
        // Recherche par nom / email.
        Container(
          decoration: BoxDecoration(
            color: AppColors.inputFill(context),
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(color: AppColors.divider(context)),
          ),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'friends_add_search_hint'.tr,
              prefixIcon: Icon(Icons.search_rounded,
                  color: AppColors.greyText, size: 22.sp),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 14.w,
                vertical: 14.h,
              ),
            ),
            onChanged: _onSearch,
          ),
        ),
        SizedBox(height: 10.h),
        InterText(
          text: 'friends_add_search_help'.tr,
          fontSize: 11.sp,
          color: AppColors.greyText,
        ),
        SizedBox(height: 14.h),
        // Resultats.
        Obx(() {
          if (_loading.value) {
            return Padding(
              padding: EdgeInsets.symmetric(vertical: 24.h),
              child: const Center(child: CircularProgressIndicator()),
            );
          }
          if (_results.isEmpty) {
            if (_searchCtrl.text.isEmpty) {
              return Padding(
                padding: EdgeInsets.symmetric(vertical: 24.h),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.person_search_rounded,
                          color: AppColors.greyText.withValues(alpha: 0.5),
                          size: 48.sp),
                      SizedBox(height: 8.h),
                      InterText(
                        text: 'friends_add_search_empty'.tr,
                        fontSize: 13.sp,
                        color: AppColors.greyText,
                      ),
                    ],
                  ),
                ),
              );
            }
            return Padding(
              padding: EdgeInsets.symmetric(vertical: 24.h),
              child: Center(
                child: InterText(
                  text: 'friends_add_no_results'.tr,
                  fontSize: 13.sp,
                  color: AppColors.greyText,
                ),
              ),
            );
          }
          return Column(
            children: _results
                .map((u) => _buildResultTile(u, context))
                .toList(),
          );
        }),
      ],
    );
  }

  Widget _buildResultTile(Map<String, dynamic> u, BuildContext context) {
    final id = (u['id'] ?? '').toString();
    final role = (u['role'] ?? '').toString();
    final name = (u['name'] ?? '').toString();
    final avatar = (u['avatar'] ?? '').toString();
    // v23.1 part 219 — Daniel : "qd je demande amis l'email s'affiche
    // encore". J'avais fix la tile du dialog popup en v216, mais cette
    // tile-ci dans l'onglet "Ajouter" principal etait restee avec
    // l'email visible. Meme fix : name (ou fallback) en titre + juste
    // le role en subtitle. Plus jamais d'email expose dans l'UI search.
    final displayName =
        name.isNotEmpty ? name : 'friends_search_no_name'.tr;
    // v23.1.190 — owner = violet (Famille & Amis), walker = vert, sitter = bleu.
    final accent = role == 'walker'
        ? AppColors.greenColor
        : role == 'sitter'
            ? AppColors.sitterAccent
            : const Color(0xFF8B5CF6);
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(14.r),
        boxShadow: AppColors.cardShadow(context),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22.r,
            backgroundColor: accent.withValues(alpha: 0.15),
            // v23.1 part 231 — perf : CachedNetworkImageProvider+maxWidth.
            backgroundImage: avatar.isNotEmpty
                ? CachedNetworkImageProvider(avatar, maxWidth: 150)
                : null,
            child: avatar.isEmpty
                ? Icon(Icons.person, color: accent, size: 22.sp)
                : null,
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InterText(
                  text: displayName,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary(context),
                  maxLines: 1,
                ),
                SizedBox(height: 2.h),
                InterText(
                  text: role,
                  fontSize: 10.sp,
                  color: AppColors.greyText,
                  maxLines: 1,
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.r),
              ),
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
            ),
            onPressed: () async {
              final err = await widget.controller.sendRequest(id, role);
              if (!context.mounted) return;
              if (err.isEmpty) {
                CustomSnackbar.showSuccess(
                  title: 'friends_invite_sent_title'.tr,
                  message: 'friends_invite_sent_msg'.trParams({'name': name}),
                );
                _searchCtrl.clear();
                _results.clear();
              } else {
                final msg = err == 'ALREADY_PENDING'
                    ? 'friends_invite_err_already_pending'.tr
                    : err == 'ALREADY_ACCEPTED'
                        ? 'friends_invite_err_already_accepted'.tr
                        : err == 'SELF'
                            ? 'friends_invite_err_self'.tr
                            : err;
                CustomSnackbar.showError(
                  title: 'friends_invite_err_title'.tr,
                  message: msg,
                );
              }
            },
            child: InterText(
              text: 'friends_add_btn'.tr,
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// _PetsTab — Animaux : v23.1.185 Daniel mockup. Liste les animaux de mes
// amis acceptes + membres famille pour pouvoir les suivre / contacter
// rapidement. Endpoint dedie : GET /friends/pets renvoie tous les pets
// des friendships acceptes.
// ─────────────────────────────────────────────────────────────────────────

class _PetsTab extends StatefulWidget {
  const _PetsTab({required this.controller});
  final FriendController controller;

  @override
  State<_PetsTab> createState() => _PetsTabState();
}

class _PetsTabState extends State<_PetsTab> {
  final RxBool _loading = true.obs;
  final RxList<Map<String, dynamic>> _pets = <Map<String, dynamic>>[].obs;
  final RxnString _error = RxnString();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _loading.value = true;
    _error.value = null;
    try {
      final api = Get.find<ApiClient>();
      final r = await api.get('/friends/pets', requiresAuth: true);
      if (r is Map && r['pets'] is List) {
        _pets.assignAll(
          (r['pets'] as List)
              .whereType<Map>()
              .map((p) => Map<String, dynamic>.from(p))
              .toList(),
        );
      } else {
        _pets.clear();
      }
    } catch (e) {
      _error.value = e.toString();
      _pets.clear();
    } finally {
      _loading.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: Obx(() {
        if (_loading.value && _pets.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (_pets.isEmpty) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(24.w),
            children: [
              SizedBox(height: 40.h),
              Center(
                child: Column(
                  children: [
                    Text('🐾', style: TextStyle(fontSize: 50.sp)),
                    SizedBox(height: 12.h),
                    InterText(
                      text: 'friends_pets_empty_title'.tr,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary(context),
                    ),
                    SizedBox(height: 6.h),
                    InterText(
                      text: 'friends_pets_empty_msg'.tr,
                      fontSize: 12.sp,
                      color: AppColors.greyText,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          );
        }
        return ListView.separated(
          padding: EdgeInsets.all(12.w),
          itemCount: _pets.length,
          separatorBuilder: (_, __) => SizedBox(height: 8.h),
          itemBuilder: (_, i) => _buildPetTile(_pets[i], context),
        );
      }),
    );
  }

  Widget _buildPetTile(Map<String, dynamic> p, BuildContext context) {
    final petName = (p['petName'] ?? p['name'] ?? '').toString();
    final ownerName = (p['ownerName'] ?? '').toString();
    final breed = (p['breed'] ?? '').toString();
    final avatar = (p['avatar'] ?? '').toString();
    final ownerRole = (p['ownerRole'] ?? 'owner').toString().toLowerCase();
    final accent = AppColors.roleAccent(ownerRole);
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(14.r),
        boxShadow: AppColors.cardShadow(context),
      ),
      child: Row(
        children: [
          ClipOval(
            child: Container(
              width: 50.r,
              height: 50.r,
              color: accent.withValues(alpha: 0.15),
              child: avatar.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: avatar,
                      memCacheWidth: 150, // v23.1 part 233 — perf.
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) =>
                          Icon(Icons.pets, color: accent, size: 24.sp),
                    )
                  : Icon(Icons.pets, color: accent, size: 24.sp),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InterText(
                  text: petName.isEmpty ? '—' : petName,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary(context),
                ),
                SizedBox(height: 2.h),
                InterText(
                  text: ownerName.isNotEmpty
                      ? 'friends_pets_owned_by'.trParams({'name': ownerName})
                      : (breed.isNotEmpty ? breed : '—'),
                  fontSize: 11.sp,
                  color: AppColors.greyText,
                  maxLines: 1,
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded,
              color: AppColors.greyText, size: 22.sp),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// _MessagesTab — v23.1.185 Daniel mockup. Liste les conversations
// recentes avec mes amis (filtre client-side sur la chat list pour ne
// garder que celles dont l'autre partie est dans ma liste d'amis).
// ─────────────────────────────────────────────────────────────────────────

class _MessagesTab extends StatefulWidget {
  const _MessagesTab({required this.controller});
  final FriendController controller;

  @override
  State<_MessagesTab> createState() => _MessagesTabState();
}

class _MessagesTabState extends State<_MessagesTab> {
  final RxBool _loading = true.obs;
  final RxList<Map<String, dynamic>> _chats = <Map<String, dynamic>>[].obs;
  // v23.1 part 226 — Daniel : "message aussi marche pa page blanche".
  // L'erreur etait avalee silencieusement (catch + _chats.clear()) donc
  // l'utilisateur voyait une fausse "empty state" qui ressemble a une
  // page blanche. On expose maintenant l'erreur + on rend la empty
  // state actionnable (CTA "Demarrer une conv depuis l'onglet Amis").
  final RxnString _error = RxnString();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _loading.value = true;
    _error.value = null;
    try {
      final api = Get.find<ApiClient>();
      final r = await api.get('/conversations/list', requiresAuth: true);
      if (r is Map && r['conversations'] is List) {
        _chats.assignAll(
          (r['conversations'] as List)
              .whereType<Map>()
              .map((c) => Map<String, dynamic>.from(c))
              .toList(),
        );
      } else if (r is List) {
        _chats.assignAll(
          r.whereType<Map>().map((c) => Map<String, dynamic>.from(c)).toList(),
        );
      } else {
        _chats.clear();
      }
      // v23.1 part 241 — Daniel : "faire que les message sont les meme
      // dans chat et ds onglet message". Le bottom-nav Chat tab et le
      // Messages tab hittent les MEMES /conversations/list mais avec des
      // controllers separes → cache desynchronise si l'user switch sans
      // refresh. Fix : on cross-trigger le reload du ChatController
      // (owner) et SitterChatController (sitter/walker) quand on est
      // dans _MessagesTab, et inversement (chat_screen.dart le faisait
      // deja via addPostFrameCallback). Resultat : meme contenu visible
      // dans les 2 onglets, en temps reel.
      try {
        if (Get.isRegistered<ChatController>()) {
          unawaited(Get.find<ChatController>().reloadConversations());
        }
      } catch (_) {/* defensive */}
      try {
        if (Get.isRegistered<SitterChatController>()) {
          unawaited(Get.find<SitterChatController>().reloadConversations());
        }
      } catch (_) {/* defensive */}
    } catch (e) {
      _error.value = e.toString().replaceAll('ApiException:', '').trim();
      _chats.clear();
    } finally {
      _loading.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: Obx(() {
        if (_loading.value && _chats.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        // v23.1 part 226 — affichage erreur explicite si l'API a renvoye
        // une exception (vs juste empty). Daniel pourra capturer le path
        // exact en cas de 403/500.
        if (_error.value != null && _chats.isEmpty) {
          final err = _error.value!;
          final is403 = err.toLowerCase().contains('403') ||
              err.toLowerCase().contains('permission') ||
              err.toLowerCase().contains('forbidden');
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(24.w),
            children: [
              SizedBox(height: 60.h),
              Center(
                child: Column(
                  children: [
                    Icon(
                      is403
                          ? Icons.lock_outline_rounded
                          : Icons.wifi_off_rounded,
                      size: 48.sp,
                      color: is403 ? Colors.orange : AppColors.greyText,
                    ),
                    SizedBox(height: 12.h),
                    InterText(
                      text: is403
                          ? 'chat_error_403_title'.tr
                          : 'friends_messages_error_title'.tr,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary(context),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8.h),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12.w),
                      child: InterText(
                        text: err,
                        fontSize: 11.sp,
                        color: AppColors.greyText,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    SizedBox(height: 16.h),
                    OutlinedButton.icon(
                      onPressed: _load,
                      icon: Icon(Icons.refresh_rounded, size: 18.sp),
                      label: Text('chat_retry'.tr),
                    ),
                  ],
                ),
              ),
            ],
          );
        }
        if (_chats.isEmpty) {
          // v23.1 part 226 — empty state beefed up : grosse illustration
          // chat + titre clair + sous-texte explicatif + CTA visible
          // qui guide vers l'onglet Amis pour demarrer une conv.
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(24.w),
            children: [
              SizedBox(height: 40.h),
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 110.w,
                      height: 110.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFFFFF1ED),
                            const Color(0xFFFFE4D6),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Icon(Icons.chat_bubble_outline_rounded,
                          color: const Color(0xFFC92A12), size: 56.sp),
                    ),
                    SizedBox(height: 16.h),
                    InterText(
                      text: 'friends_messages_empty_title'.tr,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary(context),
                    ),
                    SizedBox(height: 8.h),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      child: InterText(
                        text: 'friends_messages_empty_msg'.tr,
                        fontSize: 13.sp,
                        color: AppColors.greyText,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    SizedBox(height: 20.h),
                    // CTA : guide vers l'onglet Amis pour demarrer une conv.
                    Container(
                      padding: EdgeInsets.all(14.w),
                      decoration: BoxDecoration(
                        color: AppColors.card(context),
                        borderRadius: BorderRadius.circular(14.r),
                        border: Border.all(
                          color: const Color(0xFFC92A12)
                              .withValues(alpha: 0.30),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.touch_app_rounded,
                              color: const Color(0xFFC92A12), size: 20.sp),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: InterText(
                              text: 'friends_messages_empty_cta'.tr,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 12.h),
                    TextButton.icon(
                      onPressed: _load,
                      icon: Icon(Icons.refresh_rounded, size: 16.sp),
                      label: Text('chat_retry'.tr,
                          style: TextStyle(fontSize: 12.sp)),
                    ),
                  ],
                ),
              ),
            ],
          );
        }
        return ListView.separated(
          padding: EdgeInsets.all(12.w),
          itemCount: _chats.length,
          separatorBuilder: (_, __) => SizedBox(height: 8.h),
          itemBuilder: (_, i) => _buildChatTile(_chats[i], context),
        );
      }),
    );
  }

  Widget _buildChatTile(Map<String, dynamic> c, BuildContext context) {
    final name = (c['contactName'] ?? c['name'] ?? '').toString();
    final lastMsg = (c['lastMessage'] ?? '').toString();
    final avatar = (c['contactImage'] ?? c['avatar'] ?? '').toString();
    final unread = (c['unreadCount'] ?? 0) is int
        ? (c['unreadCount'] as int)
        : 0;
    final convId = (c['id'] ?? c['_id'] ?? '').toString();
    // v23.1 part 207 — Daniel : "debloque le chat dans l'onglet famille
    // amis qu'on puisse lire ecrire effacer message entre amis". Avant :
    // les tuiles étaient un Container sans onTap, on ne pouvait pas
    // ouvrir la conversation. Maintenant : wrap dans Material+InkWell qui
    // ouvre l'écran chat role-aware (owner → IndividualChatScreen, sinon
    // SitterIndividualChatScreen).
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14.r),
        onTap: () {
          if (convId.isEmpty) return;
          final myRole = (Get.find<GetStorage>()
                  .read<String>(StorageKeys.userRole) ??
              'owner')
              .toLowerCase();
          final contactName = name.isEmpty ? 'Utilisateur' : name;
          if (myRole == 'sitter' || myRole == 'walker') {
            Get.to(() => SitterIndividualChatScreen(
                  conversationId: convId,
                  contactName: contactName,
                  contactImage: avatar,
                ));
          } else {
            Get.to(() => IndividualChatScreen(
                  conversationId: convId,
                  contactName: contactName,
                  contactImage: avatar,
                ));
          }
        },
        child: Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(14.r),
        boxShadow: AppColors.cardShadow(context),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22.r,
            backgroundColor: AppColors.primaryColor.withValues(alpha: 0.15),
            // v23.1 part 231 — perf : CachedNetworkImageProvider 150px.
            backgroundImage:
                (avatar.isNotEmpty && avatar.startsWith('http'))
                    ? CachedNetworkImageProvider(avatar, maxWidth: 150)
                    : null,
            child: avatar.isEmpty
                ? Icon(Icons.person,
                    color: AppColors.primaryColor, size: 22.sp)
                : null,
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InterText(
                  text: name.isEmpty ? '—' : name,
                  fontSize: 13.sp,
                  fontWeight: unread > 0
                      ? FontWeight.w800
                      : FontWeight.w700,
                  color: AppColors.textPrimary(context),
                  maxLines: 1,
                ),
                SizedBox(height: 2.h),
                InterText(
                  text: lastMsg.isEmpty ? '—' : lastMsg,
                  fontSize: 11.sp,
                  color: AppColors.greyText,
                  maxLines: 1,
                ),
              ],
            ),
          ),
          if (unread > 0)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              constraints: BoxConstraints(minWidth: 18.w, minHeight: 18.w),
              child: Center(
                child: Text(
                  '$unread',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          // v23.1 part 209 — Daniel : "rajoute un bouton ds message pour
          // effacer la conversation". Bouton poubelle rouge à droite de
          // chaque tile, ouvre une AlertDialog de confirmation, puis
          // appelle DELETE /conversations/:id (hard delete messages +
          // conversation).
          if (convId.isNotEmpty) ...[
            SizedBox(width: 6.w),
            IconButton(
              icon: Icon(Icons.delete_outline_rounded,
                  color: Colors.red.shade400, size: 20.sp),
              tooltip: 'chat_delete_conv'.tr,
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(minWidth: 28.w, minHeight: 28.w),
              onPressed: () => _confirmDeleteConv(context, convId, name),
            ),
          ],
        ],
      ),
        ), // Container
      ), // InkWell
    ); // Material
  }

  Future<void> _confirmDeleteConv(
      BuildContext context, String convId, String contactName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('chat_delete_conv_title'.tr),
        // v23.1 part 209 — utilise les cles existantes :
        //   chat_delete_conv_title  (titre)
        //   chat_delete_conv_msg    (corps avec @name placeholder)
        //   chat_delete_conv_confirm (label bouton "Supprimer")
        //   common_cancel           (label bouton "Annuler")
        content: Text('chat_delete_conv_msg'.tr
            .replaceAll('@name', contactName.isEmpty ? '—' : contactName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('common_cancel'.tr),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('chat_delete_conv_confirm'.tr),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final api = Get.find<ApiClient>();
      await api.delete('/conversations/$convId', requiresAuth: true);
      _chats.removeWhere((c) =>
          (c['id'] ?? c['_id'] ?? '').toString() == convId);
      CustomSnackbar.showSuccess(
        title: 'chat_delete_conv_done_title'.tr,
        message: 'chat_delete_conv_done_msg'.tr,
      );
    } catch (e) {
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: e.toString().replaceAll('ApiException:', '').trim(),
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────
// v23.1.195 — Daniel : "les demande damis et famille senvoi mais personne
// ne recoi". Banner toujours visible en haut de l'ecran Famille & Amis
// qui liste les demandes pending (amis + famille) et permet de les
// accepter/refuser en 1 tap. Indispensable car les push notifs peuvent
// se perdre (tokens FCM stales, etc.).
// ─────────────────────────────────────────────────────────────────────────

class _PendingRequestsBanner extends StatelessWidget {
  const _PendingRequestsBanner({required this.controller});

  final FriendController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final friendReqs = controller.incomingRequests;
      final familyInvites = controller.incomingFamilyInvitations;
      // v23.1.199 — Daniel : afficher AUSSI les demandes envoyees
      // (outgoing) avec statut "Demande en attente" + bouton "Annuler".
      final outgoing = controller.outgoingRequests
          .where((f) => f.status == 'pending').toList();
      if (friendReqs.isEmpty && familyInvites.isEmpty && outgoing.isEmpty) {
        return const SizedBox.shrink();
      }
      return Container(
        margin: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 4.h),
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFF1ED), Color(0xFFFFE4D6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: const Color(0xFFC92A12).withValues(alpha: 0.30),
            width: 1.2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.mark_email_unread_rounded,
                    color: const Color(0xFFC92A12), size: 18.sp),
                SizedBox(width: 6.w),
                InterText(
                  text: 'friends_pending_banner_title'.tr,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFFC92A12),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            // Demandes d'amis pending (recues).
            ...friendReqs.map((f) => _buildFriendRow(context, f)),
            // Invitations Famille pending (recues).
            ...familyInvites.map((i) => _buildFamilyRow(context, i)),
            // v23.1.199 — Demandes envoyees (outgoing) : sablier orange
            // + bouton "Annuler" qui appelle unfriend pour delete la
            // friendship pending cote backend.
            ...outgoing.map((f) => _buildOutgoingRow(context, f)),
          ],
        ),
      );
    });
  }

  Widget _buildOutgoingRow(BuildContext context, Friendship f) {
    final other = f.other;
    final name = other?.name ?? 'Utilisateur';
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16.r,
            backgroundColor: const Color(0xFFF59E0B).withValues(alpha: 0.18),
            child: Icon(Icons.hourglass_top_rounded,
                color: const Color(0xFFF59E0B), size: 16.sp),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InterText(
                  text: name,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary(context),
                  maxLines: 1,
                ),
                InterText(
                  text: 'friends_pending_banner_outgoing_msg'.tr,
                  fontSize: 10.sp,
                  color: AppColors.greyText,
                ),
              ],
            ),
          ),
          SizedBox(width: 6.w),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () async {
                final ok = await controller.unfriend(f.id);
                if (ok) {
                  CustomSnackbar.showInfo(
                    title: 'friends_pending_banner_cancelled_title'.tr,
                    message: 'friends_pending_banner_cancelled_msg'.tr,
                  );
                }
              },
              borderRadius: BorderRadius.circular(14.r),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(14.r),
                  border: Border.all(color: Colors.red, width: 1.2),
                ),
                child: InterText(
                  text: 'friends_pending_banner_cancel'.tr,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w800,
                  color: Colors.red,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendRow(BuildContext context, Friendship f) {
    final other = f.other;
    final name = other?.name ?? 'Utilisateur';
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16.r,
            backgroundColor: const Color(0xFF8B5CF6).withValues(alpha: 0.18),
            child: Icon(Icons.person,
                color: const Color(0xFF8B5CF6), size: 16.sp),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InterText(
                  text: name,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary(context),
                  maxLines: 1,
                ),
                InterText(
                  text: 'friends_pending_banner_friend_msg'.tr,
                  fontSize: 10.sp,
                  color: AppColors.greyText,
                ),
              ],
            ),
          ),
          SizedBox(width: 6.w),
          _smallBtn(
            icon: Icons.check_rounded,
            color: const Color(0xFFC92A12),
            onTap: () async {
              final ok = await controller.accept(f.id);
              if (ok) {
                CustomSnackbar.showSuccess(
                  title: 'common_done'.tr,
                  message: 'friend_request_accepted_msg'.tr,
                );
              }
            },
          ),
          SizedBox(width: 4.w),
          _smallBtn(
            icon: Icons.close_rounded,
            color: Colors.red,
            outlined: true,
            onTap: () => controller.decline(f.id),
          ),
        ],
      ),
    );
  }

  Widget _buildFamilyRow(BuildContext context, Map<String, dynamic> inv) {
    final id = (inv['id'] ?? inv['invitationId'] ?? '').toString();
    final name = (inv['familyOwnerName'] ?? '').toString();
    final displayName = name.isEmpty ? '—' : name;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16.r,
            backgroundColor: const Color(0xFFEC4899).withValues(alpha: 0.18),
            child: Icon(Icons.family_restroom_rounded,
                color: const Color(0xFFEC4899), size: 16.sp),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InterText(
                  text: displayName,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary(context),
                  maxLines: 1,
                ),
                InterText(
                  text: 'friends_pending_banner_family_msg'.tr,
                  fontSize: 10.sp,
                  color: AppColors.greyText,
                ),
              ],
            ),
          ),
          SizedBox(width: 6.w),
          _smallBtn(
            icon: Icons.check_rounded,
            color: const Color(0xFFC92A12),
            onTap: () async {
              final ok = await controller.acceptFamilyInvitation(id);
              if (ok) {
                CustomSnackbar.showSuccess(
                  title: 'common_done'.tr,
                  message: 'family_invitation_accepted_msg'.tr,
                );
              }
            },
          ),
          SizedBox(width: 4.w),
          _smallBtn(
            icon: Icons.close_rounded,
            color: Colors.red,
            outlined: true,
            onTap: () => controller.refuseFamilyInvitation(id),
          ),
        ],
      ),
    );
  }

  Widget _smallBtn({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool outlined = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18.r),
        child: Container(
          width: 30.w,
          height: 30.w,
          decoration: BoxDecoration(
            color: outlined ? Colors.transparent : color,
            shape: BoxShape.circle,
            border: outlined ? Border.all(color: color, width: 1.4) : null,
          ),
          child: Icon(icon, color: outlined ? color : Colors.white, size: 16.sp),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────
// v23.1 part 205 — Helper top-level pour ouvrir un chat 1-to-1 entre un
// utilisateur courant (de n'importe quel rôle) et un ami. Navigation
// role-aware :
//   - owner  → IndividualChatScreen
//   - sitter | walker → SitterIndividualChatScreen
// Avant : on naviguait TOUJOURS vers IndividualChatScreen (owner) — un
// sitter/walker qui tappait 💬 sur un ami ne voyait rien s'ouvrir car
// la screen owner attendait OwnerRepository qui n'est pas bind pour
// les autres rôles. Daniel : "le chat dans l'onglet marche pas".
// ────────────────────────────────────────────────────────────────────────
Future<void> _openFriendChatRoleAware({
  required FriendController controller,
  required FriendProfile other,
}) async {
  try {
    final convId = await controller.startFriendChat(
      targetUserId: other.id,
      targetUserRole: other.model.toLowerCase(),
    );
    if (convId == null || convId.isEmpty) {
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'friends_chat_failed'.tr,
      );
      return;
    }
    final myRole = (Get.find<GetStorage>().read<String>(StorageKeys.userRole) ??
            'owner')
        .toLowerCase();
    final contactName = other.name.isEmpty ? 'Utilisateur' : other.name;
    final contactImage = other.avatar;
    if (myRole == 'sitter' || myRole == 'walker') {
      Get.to(() => SitterIndividualChatScreen(
            conversationId: convId,
            contactName: contactName,
            contactImage: contactImage,
          ));
    } else {
      Get.to(() => IndividualChatScreen(
            conversationId: convId,
            contactName: contactName,
            contactImage: contactImage,
          ));
    }
  } catch (e) {
    CustomSnackbar.showError(
      title: 'common_error'.tr,
      message: 'friends_chat_failed'.tr,
    );
  }
}

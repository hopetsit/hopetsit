// v23.1 part 225 — Daniel : "vire personne en live de l'onglet famille amis".
// L'onglet a ete supprime de FriendsScreen, mais la card quick-action
// "Personnes live position" du header PawMap doit toujours marcher. On
// extrait ici le contenu de l'ancien _PeopleLiveTab dans une screen
// autonome avec son propre AppBar.
//
// Affiche la liste des amis/membres famille qui partagent leur position
// EN CE MOMENT (theirSharePosition == true) OU qui ont un plan PawFollow
// actif (partage auto via la mecanique PawFollow Family).
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/friend_controller.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/services/live_map_service.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/views/map/paw_map_screen.dart';
import 'package:hopetsit/widgets/app_text.dart';

class PeopleLiveScreen extends StatelessWidget {
  const PeopleLiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final FriendController controller = Get.isRegistered<FriendController>()
        ? Get.find<FriendController>()
        : Get.put(FriendController());
    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      appBar: AppBar(
        backgroundColor: AppColors.appBar(context),
        elevation: 0,
        title: Row(
          children: [
            Icon(Icons.gps_fixed_rounded,
                color: const Color(0xFF10B981), size: 20.sp),
            SizedBox(width: 8.w),
            InterText(
              text: 'pawmap_quick_people_live'.tr,
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary(context),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: controller.refresh,
        child: Obx(() {
          // v23.1 part 222 — filtre etendu :
          //  (a) amis acceptes qui partagent explicitement leur position
          //  (b) amis acceptes avec PawFollow plan actif (auto-share via
          //      la mecanique PawFollow Family).
          final livePeople = controller.friends
              .where((f) =>
                  f.status == 'accepted' &&
                  (f.theirSharePosition ||
                      (f.other?.hasPawFollow ?? false)))
              .toList();
          if (livePeople.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(24.w),
              children: [
                SizedBox(height: 80.h),
                Center(
                  child: Column(
                    children: [
                      Icon(Icons.gps_off_rounded,
                          size: 56.sp, color: AppColors.greyText),
                      SizedBox(height: 12.h),
                      InterText(
                        text: 'friends_people_live_empty_title'.tr,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary(context),
                      ),
                      SizedBox(height: 4.h),
                      InterText(
                        text: 'friends_people_live_empty_msg'.tr,
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
            padding: EdgeInsets.all(12.w),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: livePeople.length,
            separatorBuilder: (_, __) => SizedBox(height: 10.h),
            itemBuilder: (_, i) {
              final f = livePeople[i];
              final other = f.other;
              if (other == null) return const SizedBox.shrink();
              // v23.1.190 — code couleur role (Owner=violet, Walker=vert,
              // Sitter=bleu) pour le halo + accent. v23.1 part 225 etend :
              // walker vert / sitter bleu est aussi le code halo de la
              // map quand on les suit.
              final roleColor = {
                'Owner': const Color(0xFF8B5CF6),
                'Sitter': AppColors.sitterAccent,
                'Walker': AppColors.greenColor,
              }[other.model] ??
                  const Color(0xFF8B5CF6);
              return InkWell(
                borderRadius: BorderRadius.circular(16.r),
                // v23.1 part 239 — Daniel : "je clic sur witoulek qui est
                // a murcia et sa me met ma geolocalisation a pego". Root
                // cause : PawMapScreen ouverte sans initialLat/Lng →
                // centre sur la position du user au lieu de l'ami.
                // Fix : on lit la derniere position broadcast de l'ami
                // depuis LiveMapService.friendPositions (event socket
                // map:friend-position) et on passe ces coords a PawMap.
                onTap: () async {
                  double? lat;
                  double? lng;
                  // 1) Try real-time socket position (most fresh).
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
                  // 2) Fallback to DB position via /friends/:id/last-position
                  // (v23.1 part 239 — Daniel : witoulek pas vu en live →
                  // friendPositions vide → fallback DB qui retourne sa
                  // derniere position broadcastee).
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
                    } catch (_) {/* defensive — open PawMap centered on user */}
                  }
                  Get.to(() => PawMapScreen(
                        initialLat: lat,
                        initialLng: lng,
                      ));
                },
                child: Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: AppColors.card(context),
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(
                      color: roleColor.withValues(alpha: 0.30),
                      width: 1.2,
                    ),
                    boxShadow: AppColors.cardShadow(context),
                  ),
                  child: Row(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 24.r,
                            backgroundColor: roleColor.withValues(alpha: 0.18),
                            // v23.1 part 231 — perf cache + maxWidth.
                            backgroundImage: (other.avatar.isNotEmpty &&
                                    other.avatar.startsWith('http'))
                                ? CachedNetworkImageProvider(other.avatar, maxWidth: 150)
                                : null,
                            child: other.avatar.isEmpty
                                ? Icon(Icons.person,
                                    color: roleColor, size: 24.sp)
                                : null,
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 14.w,
                              height: 14.w,
                              decoration: BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.card(context),
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InterText(
                              text: other.name.isEmpty ? '—' : other.name,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary(context),
                            ),
                            SizedBox(height: 2.h),
                            Row(
                              children: [
                                Icon(Icons.gps_fixed_rounded,
                                    color: Colors.green, size: 12.sp),
                                SizedBox(width: 4.w),
                                InterText(
                                  text: 'friends_people_live_subtitle'.tr,
                                  fontSize: 11.sp,
                                  color: AppColors.textSecondary(context),
                                ),
                                SizedBox(width: 8.w),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 6.w, vertical: 1.h),
                                  decoration: BoxDecoration(
                                    color:
                                        roleColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6.r),
                                  ),
                                  child: InterText(
                                    text: other.model,
                                    fontSize: 9.sp,
                                    fontWeight: FontWeight.w700,
                                    color: roleColor,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          color: AppColors.greyText, size: 22.sp),
                    ],
                  ),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}

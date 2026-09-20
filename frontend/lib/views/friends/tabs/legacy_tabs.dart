// v566 — onglets HISTORIQUES de l'écran Amis, déplacés tels quels depuis
// friends_screen.dart lors du découpage par onglet (aucune fonction retirée) :
//   - FriendsPetsTab     : animaux de mes amis (GET /friends/pets) — retiré de
//     la barre d'onglets en v225 (doublon du halo PawMap).
//   - FriendsMessagesTab : conversations avec mes amis — retiré en v244
//     (doublon de l'onglet Chat principal).
// Ils ne sont plus câblés dans FriendsScreen mais restent disponibles.
import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/controllers/chat_controller.dart';
import 'package:hopetsit/controllers/friend_controller.dart';
import 'package:hopetsit/controllers/sitter_chat_controller.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/storage_keys.dart';
import 'package:hopetsit/views/chat_shared/chat_delete_sheet.dart';
import 'package:hopetsit/views/pet_owner/chat/individual_chat_screen.dart';
import 'package:hopetsit/views/pet_sitter/chat/sitter_individual_chat_screen.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';

// ─────────────────────────────────────────────────────────────────────────
// FriendsPetsTab — Animaux : v23.1.185 Daniel mockup. Liste les animaux de mes
// amis acceptes + membres famille pour pouvoir les suivre / contacter
// rapidement. Endpoint dedie : GET /friends/pets renvoie tous les pets
// des friendships acceptes.
// ─────────────────────────────────────────────────────────────────────────

class FriendsPetsTab extends StatefulWidget {
  const FriendsPetsTab({super.key, required this.controller});
  final FriendController controller;

  @override
  State<FriendsPetsTab> createState() => _FriendsPetsTabState();
}

class _FriendsPetsTabState extends State<FriendsPetsTab> {
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
                      color: AppColors.textSecondary(context),
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
                  color: AppColors.textSecondary(context),
                  maxLines: 1,
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded,
              color: AppColors.textSecondary(context), size: 22.sp),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// FriendsMessagesTab — v23.1.185 Daniel mockup. Liste les conversations
// recentes avec mes amis (filtre client-side sur la chat list pour ne
// garder que celles dont l'autre partie est dans ma liste d'amis).
// ─────────────────────────────────────────────────────────────────────────

class FriendsMessagesTab extends StatefulWidget {
  const FriendsMessagesTab({super.key, required this.controller});
  final FriendController controller;

  @override
  State<FriendsMessagesTab> createState() => _FriendsMessagesTabState();
}

class _FriendsMessagesTabState extends State<FriendsMessagesTab> {
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
      // dans FriendsMessagesTab, et inversement (chat_screen.dart le faisait
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
                      color: is403 ? Colors.orange : AppColors.textSecondary(context),
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
                        color: AppColors.textSecondary(context),
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
          // v571 — mode sombre : le disque pêche #FFF1ED/#FFE4D6 était une
          // tache blanche sur le fond sombre, et l'icône rouge foncé dessus
          // n'était plus lisible. Clair inchangé.
          final bool isDark = Theme.of(context).brightness == Brightness.dark;
          const Color ctaRed = Color(0xFFC92A12);
          final Color illuIcon =
              isDark ? Color.lerp(ctaRed, Colors.white, 0.45)! : ctaRed;
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
                          colors: isDark
                              ? [
                                  ctaRed.withValues(alpha: 0.26),
                                  ctaRed.withValues(alpha: 0.12),
                                ]
                              : [
                                  const Color(0xFFFFF1ED),
                                  const Color(0xFFFFE4D6),
                                ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Icon(Icons.chat_bubble_outline_rounded,
                          color: illuIcon, size: 56.sp),
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
                        color: AppColors.textSecondary(context),
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
                          color: illuIcon.withValues(alpha: 0.30),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.touch_app_rounded,
                              color: illuIcon, size: 20.sp),
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
          final contactName = name.isEmpty ? 'common_user'.tr : name;
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
                  color: AppColors.textSecondary(context),
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
              onPressed: () => _confirmDeleteConv(context, convId, name, avatar),
            ),
          ],
        ],
      ),
        ), // Container
      ), // InkWell
    ); // Material
  }

  // v569 — MÊME feuille de confirmation que la liste des conversations
  // (views/chat_shared/chat_delete_sheet.dart) : l'ancienne AlertDialog
  // annonçait une suppression « pour les deux parties », ce que le serveur ne
  // fait pas (il masque la conversation pour moi seul). Un seul texte, honnête,
  // partout.
  Future<void> _confirmDeleteConv(BuildContext context, String convId,
      String contactName, String contactImage) async {
    final confirm = await showChatDeleteSheet(
      context,
      contactName: contactName,
      contactImage: contactImage,
    );
    if (!confirm) return;
    // Retrait optimiste : la ligne part tout de suite, elle revient si le
    // serveur refuse.
    final index = _chats.indexWhere(
        (c) => (c['id'] ?? c['_id'] ?? '').toString() == convId);
    final removed = index >= 0 ? _chats[index] : null;
    if (index >= 0) _chats.removeAt(index);
    try {
      final api = Get.find<ApiClient>();
      await api.delete('/conversations/$convId', requiresAuth: true);
      CustomSnackbar.showSuccess(
        title: 'chatdel569_deleted_title'.tr,
        message: 'chatdel569_deleted_body'.tr,
      );
    } catch (e) {
      if (removed != null) {
        _chats.insert(index.clamp(0, _chats.length), removed);
      }
      CustomSnackbar.showError(
        title: 'chatdel569_failed_title'.tr,
        message: 'chatdel569_failed_body'.tr,
      );
    }
  }
}

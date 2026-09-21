// v566 — briques communes des sous-pages « Amis » (Mes amis / Demandes /
// Ajouter / Famille / Personnes en direct / Utilisateurs bloqués).
// Style Apple minimaliste + « Paw Buttons » : cartes à coins 20 sans bordure,
// ombre douce, pastilles de rôle, boutons pilule teintés. Couleur d'accent =
// couleur du rôle COURANT (owner orange, gardien bleu, promeneur vert) ;
// violet réservé à la Famille PawFollow, vert à « en ligne / accepter ».
import 'package:hopetsit/widgets/role_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hopetsit/controllers/friend_controller.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/models/friendship_model.dart';
import 'package:hopetsit/services/live_map_service.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/storage_keys.dart';
import 'package:hopetsit/views/chat_shared/chat_avatar.dart';
import 'package:hopetsit/views/map/paw_map_screen.dart';
import 'package:hopetsit/views/pet_owner/chat/individual_chat_screen.dart';
import 'package:hopetsit/views/pet_sitter/chat/sitter_individual_chat_screen.dart';
import 'package:hopetsit/views/profile/widgets/profile_ui_kit.dart';
import 'package:hopetsit/views/service_provider/owner_profile_view_screen.dart';
import 'package:hopetsit/views/service_provider/service_provider_detail_screen.dart';
import 'package:hopetsit/views/service_provider/walker_detail_screen.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:share_plus/share_plus.dart';

/// Violet « Famille PawFollow » (CLAUDE.md › Marque / couleurs).
const Color kFamilyViolet = Color(0xFF7C3AED);

/// Vert « en ligne / accepter ».
const Color kFriendsGreen = Color(0xFF16A34A);

/// Couleur du MÉTIER d'un membre (jamais violet).
Color friendRoleColor(String? roleOrModel) =>
    profileAccentFor((roleOrModel ?? '').toLowerCase());

/// Libellé traduit du rôle (`Owner` / `sitter` / …).
/// v576 — même source que la pastille partagée : `role_sitter` valait
/// « Petsitter » en français (franglais) alors que l'app dit « Gardien ».
String friendRoleLabel(String? roleOrModel) =>
    roleLabelKey(roleOrModel ?? '').tr;

/// Anneau PawSpot : doré (gold / platinum), bleu (bronze / silver), sinon null.
Color? pawSpotRingColor(String? tier) {
  switch ((tier ?? '').toLowerCase()) {
    case 'gold':
    case 'platinum':
      return const Color(0xFFF59E0B);
    case 'silver':
    case 'bronze':
      return const Color(0xFF3B82F6);
  }
  return null;
}

/// « il y a X » (mêmes clés que la PawMap).
String friendsTimeAgo(DateTime at) {
  final diff = DateTime.now().difference(at);
  if (diff.inMinutes < 1) return 'pawmap_time_just_now'.tr;
  if (diff.inMinutes < 60) {
    return 'pawmap_time_min_short'.trParams({'n': diff.inMinutes.toString()});
  }
  if (diff.inHours < 24) {
    return 'pawmap_time_hours_short'.trParams({'n': diff.inHours.toString()});
  }
  return 'pawmap_time_days_short'.trParams({'n': diff.inDays.toString()});
}

// ── Carte ────────────────────────────────────────────────────────────────

/// Carte blanche à coins 20, ombre douce. `onTap` optionnel (effet d'encre).
class FriendsCard extends StatelessWidget {
  const FriendsCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.tint,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;

  /// Liseré discret (ex. violet pour un membre de la famille).
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(20.r);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: radius,
        boxShadow: AppColors.cardShadow(context),
        border: tint == null
            ? null
            : Border.all(color: tint!.withValues(alpha: 0.28), width: 1.2),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: padding ?? EdgeInsets.all(14.w),
            child: child,
          ),
        ),
      ),
    );
  }
}

// ── Avatar ───────────────────────────────────────────────────────────────

/// Avatar rond cerclé (PawSpot > famille > rôle) + point de présence.
class FriendAvatar extends StatelessWidget {
  const FriendAvatar({
    super.key,
    required this.imageUrl,
    required this.ringColor,
    this.online,
    this.size = 46,
  });

  final String imageUrl;
  final Color ringColor;

  /// null = pas de point.
  final bool? online;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2.2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ringColor, width: 2.2),
      ),
      child: ChatAvatar(imageUrl: imageUrl, size: size, online: online),
    );
  }
}

// ── Pastilles ────────────────────────────────────────────────────────────

class FriendsBadge extends StatelessWidget {
  const FriendsBadge({super.key, required this.label, required this.color, this.icon});
  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    // v571 — audit mode sombre : une pastelle « fond teinté + texte de la même
    // couleur » devient illisible sur une carte sombre (ambre #B45309 ≈ 2,4:1).
    // En sombre : fond un peu plus dense et texte éclairci. Clair inchangé.
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color fg =
        isDark ? Color.lerp(color, Colors.white, 0.45)! : color;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.18 : 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10.sp, color: fg),
            SizedBox(width: 3.w),
          ],
          Flexible(
            child: InterText(
              text: label,
              fontSize: 10.sp,
              fontWeight: FontWeight.w700,
              color: fg,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Compteur rond (onglet Demandes, en-têtes de section).
class FriendsCountDot extends StatelessWidget {
  const FriendsCountDot({super.key, required this.count, required this.color});
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.5.h),
      constraints: BoxConstraints(minWidth: 18.w),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontSize: 10.sp,
          fontWeight: FontWeight.w800,
          height: 1.2,
        ),
      ),
    );
  }
}

// ── En-tête de section ───────────────────────────────────────────────────

class FriendsSectionHeader extends StatelessWidget {
  const FriendsSectionHeader({
    super.key,
    required this.title,
    this.count,
    this.color,
    this.trailing,
  });
  final String title;
  final int? count;
  final Color? color;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(6.w, 6.h, 6.w, 10.h),
      child: Row(
        children: [
          Flexible(
            child: InterText(
              text: title.toUpperCase(),
              fontSize: 11.5.sp,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: AppColors.textSecondary(context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (count != null && count! > 0) ...[
            SizedBox(width: 8.w),
            FriendsCountDot(
              count: count!,
              color: color ?? AppColors.textSecondary(context),
            ),
          ],
          if (trailing != null) ...[const Spacer(), trailing!],
        ],
      ),
    );
  }
}

// ── Champ de recherche ───────────────────────────────────────────────────

class FriendsSearchField extends StatelessWidget {
  const FriendsSearchField({
    super.key,
    required this.controller,
    required this.hint,
    required this.accent,
    required this.onChanged,
    this.loading = false,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String hint;
  final Color accent;
  final ValueChanged<String> onChanged;
  final bool loading;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46.h,
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: AppColors.cardShadow(context),
      ),
      alignment: Alignment.center,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        keyboardType: keyboardType,
        textInputAction: TextInputAction.search,
        cursorColor: accent,
        style: TextStyle(
          fontSize: 14.sp,
          color: AppColors.textPrimary(context),
        ),
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          hintText: hint,
          hintStyle: TextStyle(fontSize: 13.5.sp, color: AppColors.textSecondary(context)),
          prefixIcon: Icon(Icons.search_rounded, color: accent, size: 20.sp),
          suffixIcon: loading
              ? Padding(
                  padding: EdgeInsets.all(13.w),
                  child: SizedBox(
                    width: 16.w,
                    height: 16.w,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(accent),
                    ),
                  ),
                )
              : ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (_, v, __) => v.text.isEmpty
                      ? const SizedBox.shrink()
                      : IconButton(
                          icon: Icon(Icons.cancel_rounded,
                              size: 18.sp, color: AppColors.textSecondary(context)),
                          onPressed: () {
                            controller.clear();
                            onChanged('');
                          },
                        ),
                ),
          contentPadding: EdgeInsets.symmetric(vertical: 12.h),
        ),
      ),
    );
  }
}

// ── Boutons pilule ───────────────────────────────────────────────────────

/// Bouton pilule compact. `filled` = plein (action principale), sinon teinté.
/// `loading` remplace le contenu par un spinner et bloque le tap.
class FriendsPillButton extends StatelessWidget {
  const FriendsPillButton({
    super.key,
    required this.label,
    required this.color,
    required this.onTap,
    this.icon,
    this.filled = false,
    this.loading = false,
    this.expand = false,
  });

  final String label;
  final Color color;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool filled;
  final bool loading;

  /// true = occupe toute la largeur offerte (dans un `Expanded`).
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !loading;
    // v571 — mode sombre : la variante teintée (texte = `color` sur `color` à
    // 10 %) manque de contraste sur une carte sombre → texte éclairci et fond
    // un peu plus dense. La variante pleine (blanc sur couleur) ne bouge pas.
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = filled
        ? Colors.white
        : (isDark ? Color.lerp(color, Colors.white, 0.40)! : color);
    final bg =
        filled ? color : color.withValues(alpha: isDark ? 0.16 : 0.10);
    return Opacity(
      opacity: enabled || loading ? 1 : 0.55,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: Container(
            height: 36.h,
            width: expand ? double.infinity : null,
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            alignment: Alignment.center,
            child: loading
                ? SizedBox(
                    width: 15.w,
                    height: 15.w,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(fg),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 15.sp, color: fg),
                        SizedBox(width: 5.w),
                      ],
                      Flexible(
                        child: InterText(
                          text: label,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w700,
                          color: fg,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// ── États de liste ───────────────────────────────────────────────────────

/// Squelette de chargement (3 cartes grisées) — évite le spinner plein écran.
class FriendsSkeletonList extends StatelessWidget {
  const FriendsSkeletonList({super.key, this.count = 4});
  final int count;

  @override
  Widget build(BuildContext context) {
    final base = AppColors.divider(context);
    Widget bar(double w, double h) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: base,
            borderRadius: BorderRadius.circular(6.r),
          ),
        );
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
      itemCount: count,
      separatorBuilder: (_, __) => SizedBox(height: 12.h),
      itemBuilder: (_, __) => FriendsCard(
        child: Row(
          children: [
            Container(
              width: 46.w,
              height: 46.w,
              decoration: BoxDecoration(color: base, shape: BoxShape.circle),
            ),
            SizedBox(width: 12.w),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                bar(130.w, 12.h),
                SizedBox(height: 8.h),
                bar(80.w, 10.h),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// État vide / erreur scrollable (compatible tirer-pour-rafraîchir).
class FriendsStateView extends StatelessWidget {
  const FriendsStateView({
    super.key,
    required this.icon,
    required this.title,
    required this.accent,
    this.message,
    this.actionLabel,
    this.onAction,
    this.error = false,
    this.footer,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Color accent;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool error;
  final Widget? footer;

  /// Erreur réseau standard + « Réessayer ».
  factory FriendsStateView.loadError({
    required Color accent,
    required VoidCallback onRetry,
  }) =>
      FriendsStateView(
        icon: Icons.wifi_off_rounded,
        title: 'friends566_error_title'.tr,
        message: 'friends566_error_msg'.tr,
        accent: accent,
        error: true,
        actionLabel: 'common_retry'.tr,
        onAction: onRetry,
      );

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16.w, 28.h, 16.w, 28.h),
      children: [
        ProfileEmptyState(
          icon: icon,
          title: title,
          message: message,
          accent: accent,
          actionLabel: actionLabel,
          onAction: onAction,
          error: error,
        ),
        if (footer != null) footer!,
      ],
    );
  }
}

// ── Feuilles ─────────────────────────────────────────────────────────────

/// Confirmation « Apple » en feuille basse. Renvoie true si confirmé.
Future<bool> confirmFriendsAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required Color accent,
  IconData icon = Icons.help_outline_rounded,
  bool danger = false,
}) async {
  final c = danger ? AppColors.errorColor : accent;
  final ok = await showProfileSheet<bool>(
    context,
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(20.w, 10.h, 20.w, 16.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ProfileSheetHandle(),
          SizedBox(height: 14.h),
          Container(
            width: 56.w,
            height: 56.w,
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: c, size: 26.sp),
          ),
          SizedBox(height: 12.h),
          PoppinsText(
            text: title,
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary(ctx),
            textAlign: TextAlign.center,
            maxLines: 3,
          ),
          SizedBox(height: 6.h),
          InterText(
            text: message,
            fontSize: 13.sp,
            color: AppColors.textSecondary(ctx),
            textAlign: TextAlign.center,
            height: 1.4,
            maxLines: 6,
          ),
          SizedBox(height: 18.h),
          ProfilePrimaryButton(
            label: confirmLabel,
            accent: c,
            onTap: () => Navigator.of(ctx).pop(true),
          ),
          SizedBox(height: 8.h),
          ProfileSecondaryButton(
            label: 'common_cancel'.tr,
            accent: AppColors.textSecondary(ctx),
            onTap: () => Navigator.of(ctx).pop(false),
          ),
        ],
      ),
    ),
  );
  return ok == true;
}

/// En-tête standard d'une feuille (poignée + icône + titre + fermer).
class FriendsSheetHeader extends StatelessWidget {
  const FriendsSheetHeader({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
  });
  final String title;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const ProfileSheetHandle(),
        SizedBox(height: 8.h),
        Row(
          children: [
            Container(
              width: 36.w,
              height: 36.w,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(icon, color: color, size: 19.sp),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: PoppinsText(
                text: title,
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary(context),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: Icon(Icons.close_rounded,
                  color: AppColors.textSecondary(context)),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Lien d'invitation ────────────────────────────────────────────────────

Map<String, String> _myIdentity() {
  String id = '';
  String name = '';
  String role = '';
  try {
    final raw = GetStorage().read(StorageKeys.userProfile);
    if (raw is Map) {
      id = (raw['id'] ?? raw['_id'] ?? '').toString();
      name = (raw['name'] ?? '').toString();
      role = (raw['role'] ?? '').toString();
    }
    if (role.isEmpty) {
      role = (GetStorage().read(StorageKeys.userRole) ?? '').toString();
    }
  } catch (_) {/* noop */}
  return {'id': id, 'name': name, 'role': role};
}

/// Lien d'invitation personnel. v546 — le rôle est indispensable : une
/// demande d'ami cible un document owner / sitter / walker.
String friendsInviteLink() {
  final me = _myIdentity();
  final id = me['id'] ?? '';
  final role = me['role'] ?? '';
  if (id.isEmpty) return 'https://hopetsit.com';
  return 'https://hopetsit.com/invite?from=$id'
      '${role.isNotEmpty ? '&role=$role' : ''}';
}

/// Message d'invitation traduit (nom + lien).
String friendsInviteMessage() {
  final name = _myIdentity()['name'] ?? '';
  return 'friends_invite_message'.trParams({
    'name': name.isEmpty ? 'HoPetSit' : name,
    'link': friendsInviteLink(),
  });
}

/// Partage natif (feuille système) du lien d'invitation.
Future<void> shareFriendsInvite() async {
  try {
    await SharePlus.instance.share(ShareParams(
      text: friendsInviteMessage(),
      subject: 'friends_invite_subject'.tr,
    ));
  } catch (e) {
    CustomSnackbar.showError(title: 'common_error'.tr, message: e.toString());
  }
}

Future<void> copyFriendsInviteLink() async {
  await Clipboard.setData(ClipboardData(text: friendsInviteLink()));
  CustomSnackbar.showSuccess(
    title: 'friends566_link_copied'.tr,
    message: friendsInviteLink(),
  );
}

// ── Navigation ───────────────────────────────────────────────────────────

/// v23.1 part 205 — chat 1-à-1 avec un ami, navigation selon MON rôle :
///   owner → IndividualChatScreen ; sitter | walker → SitterIndividualChatScreen.
Future<void> openFriendChatRoleAware({
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
    final contactName = other.name.isEmpty ? 'common_user'.tr : other.name;
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

/// Position d'un membre : socket (la plus fraîche) sinon
/// `GET /friends/:id/last-position`. `(null, null)` si inconnue.
Future<(double?, double?)> resolveFriendLatLng(String userId) async {
  double? lat;
  double? lng;
  try {
    final svc =
        Get.isRegistered<LiveMapService>() ? Get.find<LiveMapService>() : null;
    final pos = svc?.friendPositions[userId];
    if (pos != null) {
      lat = pos.latitude;
      lng = pos.longitude;
    }
  } catch (_) {/* défensif */}
  if (lat == null || lng == null) {
    try {
      final api = Get.find<ApiClient>();
      final r = await api.get('/friends/$userId/last-position',
          requiresAuth: true);
      if (r is Map && r['lat'] is num && r['lng'] is num) {
        lat = (r['lat'] as num).toDouble();
        lng = (r['lng'] as num).toDouble();
      }
    } catch (_) {/* défensif */}
  }
  return (lat, lng);
}

/// Ouvre la PawMap centrée sur un membre (halo + suivi). v23.1.400 —
/// `Get.off` : la carte REMPLACE l'écran Amis, le retour ramène à la carte.
Future<void> openPawMapOnMember({
  required String userId,
  required String role,
  required String name,
}) async {
  final (lat, lng) = await resolveFriendLatLng(userId);
  Get.off(() => PawMapScreen(
        initialLat: lat,
        initialLng: lng,
        focusUserId: userId,
        focusUserRole: role.toLowerCase(),
        focusUserName: name,
      ));
}

/// « Suivre en direct » un AMI : ouverture directe s'il partage sa position,
/// sinon `GET /friends/:id/track-access` (la famille passe outre le réglage).
Future<void> followFriendLive({
  required FriendController controller,
  required Friendship friendship,
}) async {
  final other = friendship.other;
  if (other == null || other.id.isEmpty) return;
  var canTrack = friendship.theirSharePosition;
  if (!canTrack) {
    final access = await controller.checkTrackAccess(other.id);
    canTrack = access['canTrack'] == true;
  }
  if (!canTrack) {
    CustomSnackbar.showInfo(
      title: 'friends_tap_not_shared_title'.tr,
      message: 'friends_tap_not_shared_msg'
          .trParams({'name': other.name.isEmpty ? '—' : other.name}),
    );
    return;
  }
  await openPawMapOnMember(
    userId: other.id,
    role: other.model,
    name: other.name,
  );
}

/// « Voir le profil » d'un membre selon SON rôle.
void openMemberProfile({
  required String userId,
  required String role,
  required String name,
  String avatar = '',
  String city = '',
}) {
  if (userId.isEmpty) return;
  switch (role.toLowerCase()) {
    case 'walker':
      Get.to(() => WalkerDetailScreen(walkerId: userId));
      break;
    case 'sitter':
      Get.to(() => ServiceProviderDetailScreen(
            sitterId: userId,
            status: 'available',
          ));
      break;
    default:
      Get.to(() => OwnerProfileViewScreen(
            ownerId: userId,
            ownerName: name.isEmpty ? 'common_user'.tr : name,
            ownerAvatar: avatar.isEmpty ? null : avatar,
            ownerCity: city.isEmpty ? null : city,
          ));
  }
}

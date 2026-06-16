import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/models/post_model.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/app_images.dart';
import 'package:hopetsit/utils/post_price_estimator.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:hopetsit/widgets/report_dialog.dart';

class PetPostCard extends StatelessWidget {
  final String userName;
  final String userEmail;
  final String? userAvatar;
  final List<String> petImages; // Changed to list
  final String? postBody;
  final String? petName;
  final String? serviceTypes;
  final String? dateRange;
  final String? location;
  final bool isNetworkImage;
  final int likeCount;
  final int commentCount;
  final bool isLiked;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final VoidCallback? onDelete;
  /// v18.6 — callback "Modifier l'annonce". Si null, l'icône stylo n'est
  /// pas affichée. Désactivée UI-side quand isReserved=true pour éviter
  /// de modifier une annonce déjà prise.
  final VoidCallback? onEdit;
  final VoidCallback? onViewPetDetails;
  final VoidCallback? onSendRequest;
  final bool isRequestLoading;
  final String? requestButtonText;
  final bool isCancelRequest;
  final VoidCallback? onBlockUser;
  final VoidCallback? onReportPost;

  /// v16.3g — estimated earning for the current walker/sitter viewing
  /// this post. When provided, a price block (brut + net + breakdown) is
  /// displayed right above the action buttons.
  final PostPriceEstimate? priceEstimate;

  /// v16.3h — role of the viewer ('walker' | 'sitter' | null). Controls the
  /// accent color of the price block (green for walker, blue for sitter).
  final String? viewerRole;

  /// Session v17.1 — when the post has an active reservation (owner already
  /// accepted a sitter/walker application), the card shows a "Reserved"
  /// badge in the header so other providers know the slot is taken.
  /// [reservedProviderRole] ('walker' | 'sitter' | null) colours the badge.
  final bool isReserved;
  /// v18.6 — #24 : true quand l'owner consulte SA propre publication.
  /// Force la couleur du badge "Réservé" en orange HoPetSit pour un état
  /// immédiatement lisible côté owner. Sur le feed sitter/walker, garde
  /// la couleur du provider qui a réservé.
  final bool ownerViewOfOwnPost;
  final String? reservedProviderRole;

  /// v420 — maquette "Daniel C" : liste des animaux de l'annonce (nom +
  /// nb de photos + caractère + type), pour la bande animaux et la carte
  /// "Caractère des animaux". Null/vide ⇒ ces sections sont masquées.
  final List<PostPet>? pets;

  /// v420 — "À propos de moi" du propriétaire affiché sous la demande de
  /// réservation. Null/vide ⇒ masqué.
  final String? ownerBio;

  const PetPostCard({
    super.key,
    required this.userName,
    required this.userEmail,
    this.userAvatar,
    required this.petImages, // Changed to list
    this.postBody,
    this.petName,
    this.serviceTypes,
    this.dateRange,
    this.location,
    this.isNetworkImage = false,
    required this.likeCount,
    required this.commentCount,
    this.isLiked = false,
    this.onLike,
    this.onComment,
    this.onShare,
    this.onDelete,
    this.onEdit,
    this.onViewPetDetails,
    this.onSendRequest,
    this.isRequestLoading = false,
    this.requestButtonText,
    this.isCancelRequest = false,
    this.onBlockUser,
    this.onReportPost,
    this.priceEstimate,
    this.viewerRole,
    this.isReserved = false,
    this.ownerViewOfOwnPost = false,
    this.reservedProviderRole,
    this.pets,
    this.ownerBio,
    // v23.1 part 116 — Daniel : "sitter et walker aussi vois que lannonce
    // et booster et en haut". Quand isOwnerBoosted=true, on affiche un
    // ruban "🚀 Urgent" en haut de la card pour attirer l'œil.
    this.isOwnerBoosted = false,
    this.ownerBoostTier,
  });

  /// v23.1 part 116 — owner boost annotation (du backend listPosts).
  final bool isOwnerBoosted;
  final String? ownerBoostTier;

  /// v425 — maquettes 221/223/224 : la carte prend la couleur du RÔLE qui la
  /// regarde — orange (owner sur sa propre annonce), vert (promeneur), bleu
  /// (pet-sitter). Avant tout était orange même côté walker/sitter.
  Color get _accent {
    switch (viewerRole) {
      case 'walker':
        return const Color(0xFF16A34A);
      case 'sitter':
        return const Color(0xFF2563EB);
      default:
        return AppColors.primaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    // v23.1 part 116 — bordure rouge + halo subtil pour les posts boostés.
    final boostBorder = isOwnerBoosted
        ? Border.all(
            color: const Color(0xFFE8472A),
            width: 2.w,
          )
        : Border.all(
            color: AppColors.divider(context).withValues(alpha: 0.35),
            width: 1.w,
          );
    // v23.1 part 232 — Daniel : "sa surrame le scroll est au ralenti".
    // RepaintBoundary isole chaque card du repaint des voisins quand on
    // scrolle. Sur Oppo low-end : gros gain de fluidite scroll feed.
    return RepaintBoundary(
      child: Container(
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(19.r),
        border: boostBorder,
        // v23.1 part 232 — perf : blurRadius 16 → 5 pour scroll fluide
        // sur Oppo low-end GPU. Le ruban URGENT reste visuel mais le
        // shadow est 10x moins couteux GPU-side.
        boxShadow: isOwnerBoosted
            ? const [
                BoxShadow(
                  color: Color(0x2EE8472A), // alpha 0.18 hex-baked
                  blurRadius: 5,
                  offset: Offset(0, 2),
                ),
              ]
            : AppColors.cardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // v23.1 part 116 — Ruban "🚀 URGENT" en haut pour les posts dont
          // l'owner a un boost actif. Plus le tier est haut, plus c'est
          // explicite (Platinum = "URGENT — Boost Platinum").
          if (isOwnerBoosted) _buildUrgentBanner(),
          // Header with profile info
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: AppColors.inputFill(context),
              borderRadius: BorderRadius.only(
                topLeft: isOwnerBoosted ? Radius.zero : Radius.circular(19.r),
                topRight: isOwnerBoosted ? Radius.zero : Radius.circular(19.r),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 25.r,
                  backgroundColor: AppColors.primaryColor,
                  child: CircleAvatar(
                    radius: 22.r,
                    // v23.1 part 243 round 3 — perf : NetworkImage brut
                    // decode le bitmap pleine resolution serveur (~5-10 MB
                    // pour un avatar 50px). CachedNetworkImageProvider + maxWidth
                    // limite a un thumbnail 150px = ~30 KB.
                    backgroundImage:
                        userAvatar != null && userAvatar!.isNotEmpty
                        ? CachedNetworkImageProvider(userAvatar!, maxWidth: 150)
                              as ImageProvider
                        : AssetImage(AppImages.placeholderImage)
                              as ImageProvider,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: InterText(
                              text: userName,
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary(context),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isReserved) ...[
                            SizedBox(width: 8.w),
                            _buildReservedBadge(),
                          ],
                        ],
                      ),
                      SizedBox(height: 3.h),
                      InterText(
                        text: 'role_pet_owner'.tr,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary(context),
                      ),
                    ],
                  ),
                ),
                // v18.6 — stylo Modifier (désactivé si isReserved) + poubelle
                // relookée (rond rouge pastel, icône blanche). Les 2 sont
                // côte à côte dans un wrapper animé.
                if (onEdit != null)
                  Container(
                    margin: EdgeInsets.only(right: 4.w),
                    decoration: BoxDecoration(
                      color: isReserved
                          ? AppColors.grey300Color.withValues(alpha: 0.4)
                          : const Color(0xFF2563EB).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: isReserved ? null : onEdit,
                      icon: Icon(
                        Icons.edit_outlined,
                        color: isReserved
                            ? AppColors.grey500Color
                            : const Color(0xFF2563EB),
                        size: 20.sp,
                      ),
                      tooltip: 'post_action_edit'.tr,
                    ),
                  ),
                if (onDelete != null)
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.errorColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: onDelete,
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        color: AppColors.errorColor,
                        size: 20.sp,
                      ),
                      tooltip: 'post_action_delete'.tr,
                    ),
                  ),
                if (onBlockUser != null || onReportPost != null)
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, size: 20.sp, color: AppColors.textSecondary(context)),
                    tooltip: 'post_more_options'.tr,
                    onSelected: (value) {
                      if (value == 'block' && onBlockUser != null) {
                        onBlockUser!();
                      } else if (value == 'report' && onReportPost != null) {
                        onReportPost!();
                      }
                    },
                    itemBuilder: (context) => [
                      if (onBlockUser != null)
                        PopupMenuItem<String>(
                          value: 'block',
                          child: Row(
                            children: [
                              Icon(Icons.block, color: AppColors.errorColor, size: 18.sp),
                              SizedBox(width: 8.w),
                              Text('post_action_block_user'.tr),
                            ],
                          ),
                        ),
                      if (onReportPost != null)
                        PopupMenuItem<String>(
                          value: 'report',
                          child: Row(
                            children: [
                              Icon(Icons.flag_outlined, color: AppColors.textSecondary(context), size: 18.sp),
                              SizedBox(width: 8.w),
                              Text('post_action_report'.tr),
                            ],
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),

          // v425 — maquette 221 : grande photo bannière (1re photo) + badge
          // "N photos", tap → galerie plein écran. Remplace l'ancienne grille.
          if (petImages.isNotEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 0),
              child: _buildHeroBanner(context),
            )
          else
            SizedBox(height: 4.h),

          // v420/v425 — maquette : bande des animaux (avatar + nom + nb de
          // photos + ›) puis carte "Caractère des animaux".
          if (pets != null && pets!.isNotEmpty) ...[
            SizedBox(height: 14.h),
            _buildPetsStrip(context),
          ],
          if (_hasCharacterData)
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 0),
              child: _buildCharacterCard(context),
            ),

          if ((postBody ?? '').trim().isNotEmpty ||
              (petName ?? '').trim().isNotEmpty ||
              (serviceTypes ?? '').trim().isNotEmpty ||
              (dateRange ?? '').trim().isNotEmpty ||
              (location ?? '').trim().isNotEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 8.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 12.h),
                    decoration: BoxDecoration(
                      color: AppColors.inputFill(context),
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(
                        color: AppColors.divider(context).withValues(alpha: 0.4),
                        width: 1.w,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Section header — "Demande de réservation" + statut.
                        Row(
                          children: [
                            Container(
                              width: 4.w,
                              height: 14.h,
                              decoration: BoxDecoration(
                                color: _accent,
                                borderRadius: BorderRadius.circular(2.r),
                              ),
                            ),
                            SizedBox(width: 8.w),
                            Expanded(
                              child: InterText(
                                text: 'post_card_reservation_request'.tr,
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary(context),
                              ),
                            ),
                            _buildRequestStatusBadge(context),
                          ],
                        ),
                        SizedBox(height: 12.h),
                        _buildReservationGrid(context),
                      ],
                    ),
                  ),
                  // v420 — "À propos de moi" du propriétaire (maquette).
                  if ((ownerBio ?? '').trim().isNotEmpty) ...[
                    SizedBox(height: 10.h),
                    _buildAboutOwner(context),
                  ],
                  if (priceEstimate != null && !priceEstimate!.isZero) ...[
                    SizedBox(height: 10.h),
                    _buildPriceBlock(context, priceEstimate!),
                  ],
                  if (onViewPetDetails != null || onSendRequest != null) ...[
                    SizedBox(height: 10.h),
                    Row(
                      children: [
                        if (onViewPetDetails != null)
                          Expanded(
                            child: _buildSoftButton(
                              icon: Icons.visibility_outlined,
                              text: 'sitter_post_pet_details'.tr,
                              onTap: onViewPetDetails,
                            ),
                          ),
                        if (onViewPetDetails != null && onSendRequest != null)
                          SizedBox(width: 8.w),
                        if (onSendRequest != null)
                          Expanded(
                            // v18.5 — #18 : quand le post est réservé
                            // (badge "Réservé"), on désactive le bouton
                            // "Envoyer la demande" et on le remplace par
                            // un label "Déjà réservé" grisé. Empêche
                            // d'envoyer une candidature sur une annonce
                            // déjà prise.
                            child: _buildPrimaryButton(
                              onTap: (isRequestLoading || isReserved)
                                  ? null
                                  : onSendRequest,
                              isLoading: isRequestLoading,
                              isCancelRequest: isCancelRequest,
                              buttonText: isReserved
                                  ? 'post_already_reserved_cta'.tr
                                  : (requestButtonText ??
                                      (isCancelRequest
                                          ? 'service_card_cancel'.tr
                                          : 'send_request_button'.tr)),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

          // v23.1 — like count redesign : compteur intégré dans une pill
          // douce avec icône cœur rouge, taille discrète, n'apparaît que
          // si > 0 (au lieu d'un "0" laid).
          if (likeCount > 0)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: 10.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10.r),
                      border: Border.all(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.18),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.favorite_rounded,
                          size: 13.sp,
                          color: const Color(0xFFEF4444),
                        ),
                        SizedBox(width: 5.w),
                        InterText(
                          text: likeCount == 1
                              ? '$likeCount ${'post_likes_singular'.tr}'
                              : '$likeCount ${'post_likes_plural'.tr}',
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFEF4444),
                        ),
                      ],
                    ),
                  ),
                // GestureDetector(
                //   onTap: onComment,
                //   child: InterText(
                //     text: commentCount == 1
                //         ? 'post_comments_count_singular'.trParams({
                //             'count': commentCount.toString(),
                //           })
                //         : 'post_comments_count_plural'.trParams({
                //             'count': commentCount.toString(),
                //           }),
                //     fontSize: 12.sp,
                //     fontWeight: FontWeight.w400,
                //     color: AppColors.greyText,
                //   ),
                // ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Divider(color: AppColors.divider(context).withValues(alpha: 0.2)),
          ),

          // v23.1 — Like + Share redesign moderne : gradient subtil, ombre
          // douce, animation de scale au tap, icônes plus claires.
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 0),
            child: Row(
              children: [
                Expanded(
                  child: _buildActionPill(
                    context: context,
                    icon: isLiked
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    label: likeCount > 0
                        ? '${'post_action_like'.tr} · $likeCount'
                        : 'post_action_like'.tr,
                    isActive: isLiked,
                    accent: const Color(0xFFEF4444),
                    onTap: onLike,
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: _buildActionPill(
                    context: context,
                    icon: Icons.ios_share_rounded,
                    label: 'post_action_share'.tr,
                    isActive: false,
                    accent: const Color(0xFF2563EB),
                    onTap: onShare,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),
        ],
      ),
      ),
    );
  }

  // ── v420 — maquette "Daniel C" : helpers détail d'annonce ────────────────

  /// Types d'animaux distincts (ex. "Chien, Chat").
  String get _petTypesLabel {
    if (pets == null || pets!.isEmpty) return '';
    final seen = <String>{};
    final labels = <String>[];
    for (final p in pets!) {
      final c = p.category.trim().toLowerCase();
      if (c.isEmpty || seen.contains(c)) continue;
      seen.add(c);
      labels.add(_categoryLabel(c));
    }
    return labels.join(', ');
  }

  String _categoryLabel(String c) {
    switch (c) {
      case 'dog':
        return 'pet_type_dog'.tr;
      case 'cat':
        return 'pet_type_cat'.tr;
      case 'small':
      case 'small_animal':
        return 'pet_type_small'.tr;
      case 'nac':
        return 'pet_type_nac'.tr;
      case 'bird':
        return 'pet_type_bird'.tr;
      default:
        return c.isEmpty ? c : c[0].toUpperCase() + c.substring(1);
    }
  }

  /// Bande des animaux concernés — lignes "avatar | 🐕 Nom • N photos ›"
  /// (maquette 221). Couleur du nom = accent du rôle.
  Widget _buildPetsStrip(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Wrap(
        spacing: 18.w,
        runSpacing: 10.h,
        children: pets!.map((p) {
          final count = p.photos.length;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 18.r,
                backgroundColor: _accent.withValues(alpha: 0.12),
                backgroundImage: p.avatar.isNotEmpty
                    ? CachedNetworkImageProvider(p.avatar, maxWidth: 150)
                        as ImageProvider
                    : null,
                child: p.avatar.isEmpty
                    ? Icon(Icons.pets, size: 16.sp, color: _accent)
                    : null,
              ),
              SizedBox(width: 8.w),
              Text(_speciesEmoji(p.category), style: TextStyle(fontSize: 13.sp)),
              SizedBox(width: 4.w),
              InterText(
                text: p.petName,
                fontSize: 13.sp,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary(context),
              ),
              SizedBox(width: 6.w),
              InterText(
                text: count <= 1
                    ? '• $count ${'post_photos_count_one'.tr}'
                    : '• $count ${'post_photos_count'.tr}',
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
                color: _accent,
              ),
              SizedBox(width: 2.w),
              Icon(Icons.chevron_right_rounded,
                  size: 16.sp, color: AppColors.greyColor),
            ],
          );
        }).toList(),
      ),
    );
  }

  /// v425 — grande photo bannière (maquette 221) + badge "N photos".
  Widget _buildHeroBanner(BuildContext context) {
    final first = petImages.first;
    return GestureDetector(
      onTap: () => _openPhotoViewer(context, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.r),
        child: Stack(
          children: [
            SizedBox(
              width: double.infinity,
              height: 190.h,
              child: isNetworkImage
                  ? CachedNetworkImage(
                      imageUrl: first,
                      fit: BoxFit.cover,
                      placeholder: (c, _) =>
                          Container(color: AppColors.lightGreyColor),
                      errorWidget: (c, _, __) => Container(
                        color: AppColors.lightGreyColor,
                        child: Icon(Icons.broken_image,
                            color: AppColors.greyColor),
                      ),
                    )
                  : Image.asset(first, fit: BoxFit.cover),
            ),
            if (petImages.length > 1)
              Positioned(
                right: 10.w,
                top: 10.h,
                child: Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.photo_camera_rounded,
                          size: 13.sp, color: Colors.white),
                      SizedBox(width: 5.w),
                      InterText(
                        text: '${petImages.length} ${'post_photos_count'.tr}',
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _speciesEmoji(String category) {
    switch (category.trim().toLowerCase()) {
      case 'dog':
      case 'chien':
        return '🐕';
      case 'cat':
      case 'chat':
        return '🐈';
      case 'bird':
      case 'oiseau':
        return '🐦';
      case 'small':
      case 'small_animal':
      case 'lapin':
      case 'rongeur':
      case 'petit':
        return '🐹';
      case 'nac':
      case 'reptile':
        return '🦎';
      default:
        return '🐾';
    }
  }

  /// Animaux ayant des données de caractère (bio OU traits).
  List<PostPet> get _petsWithCharacter =>
      pets == null
          ? const <PostPet>[]
          : pets!
              .where((p) =>
                  p.bio.trim().isNotEmpty || p.characterTraits.isNotEmpty)
              .toList();

  bool get _hasCharacterData => _petsWithCharacter.isNotEmpty;

  /// Carte "Caractère des animaux" — un bloc PAR animal (icône espèce + nom +
  /// race + description), maquette 221. 2 animaux côte à côte, sinon empilés.
  Widget _buildCharacterCard(BuildContext context) {
    final withChar = _petsWithCharacter;
    Widget body;
    if (withChar.length == 2) {
      body = IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _petCharacterBlock(context, withChar[0])),
            Container(
              width: 1,
              margin: EdgeInsets.symmetric(horizontal: 12.w),
              color: AppColors.divider(context).withValues(alpha: 0.5),
            ),
            Expanded(child: _petCharacterBlock(context, withChar[1])),
          ],
        ),
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < withChar.length; i++) ...[
            if (i > 0)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 10.h),
                child: Divider(
                    height: 1,
                    color: AppColors.divider(context).withValues(alpha: 0.5)),
              ),
            _petCharacterBlock(context, withChar[i]),
          ],
        ],
      );
    }
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 12.h),
      decoration: BoxDecoration(
        color: AppColors.inputFill(context),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: AppColors.divider(context).withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pets_rounded, size: 16.sp, color: _accent),
              SizedBox(width: 8.w),
              InterText(
                text: 'post_character_section'.tr,
                fontSize: 13.sp,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary(context),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          body,
        ],
      ),
    );
  }

  /// Bloc caractère d'UN animal : icône espèce + nom + race + description.
  Widget _petCharacterBlock(BuildContext context, PostPet p) {
    final desc = p.bio.trim().isNotEmpty
        ? p.bio.trim()
        : p.characterTraits.map((t) => 'pet_trait_$t'.tr).join(', ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(_speciesEmoji(p.category), style: TextStyle(fontSize: 18.sp)),
            SizedBox(width: 6.w),
            Flexible(
              child: InterText(
                text: p.petName,
                fontSize: 14.sp,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary(context),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        if (p.breed.isNotEmpty) ...[
          SizedBox(height: 2.h),
          InterText(
            text: p.breed,
            fontSize: 12.sp,
            color: AppColors.greyText,
          ),
        ],
        if (desc.isNotEmpty) ...[
          SizedBox(height: 6.h),
          InterText(
            text: desc,
            fontSize: 12.5.sp,
            color: AppColors.textSecondary(context),
            maxLines: 5,
          ),
        ],
      ],
    );
  }

  /// Section "À propos de moi" du propriétaire.
  Widget _buildAboutOwner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 12.h),
      decoration: BoxDecoration(
        color: AppColors.inputFill(context),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: AppColors.divider(context).withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_rounded, size: 15.sp, color: _accent),
              SizedBox(width: 8.w),
              InterText(
                text: 'post_about_owner'.tr,
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary(context),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          InterText(
            text: ownerBio!.trim(),
            fontSize: 12.sp,
            color: AppColors.textSecondary(context),
            maxLines: 6,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// Ligne label : valeur de la demande de réservation.
  /// Grille 3 colonnes de la demande de réservation (maquette 221) :
  /// chaque case = pastille icône + libellé + valeur.
  Widget _buildReservationGrid(BuildContext context) {
    final cells = <Widget>[];
    void add(IconData icon, String label, String value) {
      if (value.trim().isEmpty) return;
      cells.add(_resCell(context, icon, label, value.trim()));
    }

    add(Icons.calendar_today_rounded, 'post_field_dates'.tr, dateRange ?? '');
    add(Icons.location_on_rounded, 'post_field_location'.tr, location ?? '');
    if (pets != null && pets!.isNotEmpty) {
      add(Icons.pets_rounded, 'post_field_pet_count'.tr, '${pets!.length}');
    }
    add(Icons.category_rounded, 'post_field_pet_types'.tr, _petTypesLabel);
    if ((serviceTypes ?? '').trim().isNotEmpty) {
      add(Icons.volunteer_activism_rounded, 'post_field_service'.tr,
          _localizedServices(serviceTypes!.trim()));
    }
    add(Icons.notes_rounded, 'post_field_details'.tr,
        _localizePostBody((postBody ?? '').trim()));
    if ((pets == null || pets!.isEmpty) && (petName ?? '').trim().isNotEmpty) {
      add(Icons.pets_rounded, 'post_field_animals'.tr, petName!.trim());
    }

    final rows = <Widget>[];
    for (int i = 0; i < cells.length; i += 3) {
      final end = (i + 3) > cells.length ? cells.length : (i + 3);
      final chunk = cells.sublist(i, end);
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int j = 0; j < 3; j++)
                Expanded(
                  child: j < chunk.length ? chunk[j] : const SizedBox(),
                ),
            ],
          ),
        ),
      );
    }
    return Column(children: rows);
  }

  Widget _resCell(
      BuildContext context, IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.fromLTRB(0, 6.h, 6.w, 6.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30.w,
            height: 30.w,
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 15.sp, color: _accent),
          ),
          SizedBox(height: 6.h),
          InterText(
            text: label,
            fontSize: 10.5.sp,
            color: AppColors.greyText,
            maxLines: 2,
          ),
          SizedBox(height: 1.h),
          InterText(
            text: value,
            fontSize: 11.5.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary(context),
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  /// Badge de statut de la demande ("En attente" tant que non réservée).
  Widget _buildRequestStatusBadge(BuildContext context) {
    if (isReserved) return const SizedBox.shrink();
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule_rounded,
              size: 11.sp, color: const Color(0xFFB45309)),
          SizedBox(width: 4.w),
          InterText(
            text: 'post_status_pending'.tr,
            fontSize: 10.sp,
            fontWeight: FontWeight.w700,
            color: const Color(0xFFB45309),
          ),
        ],
      ),
    );
  }

  /// v23.1 — bouton action moderne : gradient subtil, ombre douce, état
  /// "actif" (liké/partagé) avec rempli plein couleur, "inactif" avec
  /// fond très clair et bordure légère. Animation tactile via InkWell.
  Widget _buildActionPill({
    required BuildContext context,
    required IconData icon,
    required String label,
    required bool isActive,
    required Color accent,
    VoidCallback? onTap,
  }) {
    final bg = isActive ? accent : accent.withValues(alpha: 0.06);
    final fg = isActive ? Colors.white : accent;
    final shadowColor = accent.withValues(alpha: isActive ? 0.32 : 0.0);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14.r),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(14.r),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14.r),
          splashColor: accent.withValues(alpha: 0.15),
          highlightColor: accent.withValues(alpha: 0.05),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 11.h, horizontal: 14.w),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(
                color: isActive
                    ? Colors.transparent
                    : accent.withValues(alpha: 0.18),
                width: 1.2,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18.sp, color: fg),
                SizedBox(width: 8.w),
                Flexible(
                  child: InterText(
                    text: label,
                    fontSize: 13.sp,
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

  // Maps known post body strings (any language) from backend to the user's
  // current locale. v23.1.168 — Daniel : la string était stockée en FR pur
  // dans la DB ("Demande de réservation") donc quand l'utilisateur changeait
  // la langue de l'app, l'en-tête restait en FR.
  String _localizePostBody(String body) {
    switch (body.toLowerCase().trim()) {
      case 'reservation request':
      case 'demande de réservation':
      case 'demande de reservation':
      case 'solicitud de reserva':
      case 'reservierungsanfrage':
      case 'richiesta di prenotazione':
      case 'pedido de reserva':
        return 'post_card_reservation_request'.tr;
      default:
        return body;
    }
  }

  // Maps raw backend service strings (e.g. "house sitting", "dog walking")
  // to localized labels. Preserves unknown values verbatim.
  String _localizedServices(String raw) {
    final items = raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty);
    String map(String s) {
      switch (s.toLowerCase()) {
        case 'house sitting':
        case 'house_sitting':
          return 'post_card_service_house_sitting'.tr;
        case 'dog walking':
        case 'dog_walking':
          return 'post_card_service_dog_walking'.tr;
        case 'pet sitting':
        case 'pet_sitting':
          return 'post_card_service_pet_sitting'.tr;
        case 'pet grooming':
        case 'pet_grooming':
          return 'post_card_service_pet_grooming'.tr;
        case 'pet training':
        case 'pet_training':
          return 'post_card_service_pet_training'.tr;
        case 'overnight care':
        case 'overnight_care':
          return 'post_card_service_overnight_care'.tr;
        case 'pet boarding':
        case 'pet_boarding':
          return 'post_card_service_pet_boarding'.tr;
        default:
          return s;
      }
    }
    return items.map(map).join(', ');
  }


  /// Session v17.1 — tiny "Reserved" pill rendered in the card header when
  /// the post has an active reservation. Colour matches the provider role
  /// that reserved it (green walker / blue sitter). Uses the `reserved_badge`
  /// translation key; falls back to "Réservé" when the key is missing.
  Widget _buildReservedBadge() {
    final role = (reservedProviderRole ?? '').toLowerCase();
    // v18.6 — #24 : quand l'owner visualise SES propres publications
    // (ownerViewOfOwnPost=true, passé depuis "Mes publications"), on force
    // la couleur orange HoPetSit pour que le badge soit immédiatement
    // reconnaissable comme état du post. Pour les autres rôles (sitter/
    // walker qui voient le post d'un owner), on garde la couleur du
    // provider qui a réservé (vert walker / bleu sitter).
    final Color accent = ownerViewOfOwnPost
        ? AppColors.primaryColor
        : (role == 'walker'
            ? const Color(0xFF16A34A)
            : role == 'sitter'
                ? const Color(0xFF2563EB)
                : const Color(0xFF6B7280));
    final String label = 'reserved_badge'.tr == 'reserved_badge'
        ? 'Réservé'
        : 'reserved_badge'.tr;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_rounded, size: 11.sp, color: accent),
          SizedBox(width: 4.w),
          InterText(
            text: label,
            fontSize: 10.sp,
            fontWeight: FontWeight.w700,
            color: accent,
          ),
        ],
      ),
    );
  }

  /// v16.3g — earning estimate block for the walker/sitter viewing this
  /// post. v16.3h: accent color depends on viewer role (green for walker,
  /// blue for sitter, fallback to primary color).
  Widget _buildPriceBlock(BuildContext context, PostPriceEstimate est) {
    final role = (viewerRole ?? '').toLowerCase();
    Color accent;
    if (role == 'walker') {
      accent = const Color(0xFF16A34A); // green-600
    } else if (role == 'sitter') {
      accent = const Color(0xFF2563EB); // blue-600
    } else {
      accent = AppColors.primaryColor;
    }
    final brutLabel = _formatMoneyShort(est.brut, est.currency);
    final netLabel = _formatMoneyShort(est.net, est.currency);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.10),
            accent.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: accent.withValues(alpha: 0.25),
          width: 1.w,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.payments_outlined, size: 16.sp, color: accent),
              SizedBox(width: 6.w),
              InterText(
                text: 'post_price_estimate_title'.tr,
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
                color: accent,
              ),
            ],
          ),
          SizedBox(height: 8.h),
          // Brut + net side-by-side.
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InterText(
                      text: 'post_price_brut_label'.tr,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary(context),
                    ),
                    SizedBox(height: 2.h),
                    InterText(
                      text: brutLabel,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary(context),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1.w,
                height: 28.h,
                color: accent.withValues(alpha: 0.25),
                margin: EdgeInsets.symmetric(horizontal: 10.w),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InterText(
                      text: 'post_price_net_label'.tr,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w500,
                      color: accent,
                    ),
                    SizedBox(height: 2.h),
                    InterText(
                      text: netLabel,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          InterText(
            text: est.breakdown,
            fontSize: 10.sp,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary(context),
          ),
        ],
      ),
    );
  }

  String _formatMoneyShort(double amount, String currency) {
    final symbol = _symbolFor(currency);
    final isInt = amount == amount.roundToDouble();
    final formatted = isInt
        ? amount.toInt().toString()
        : amount.toStringAsFixed(2);
    return '$symbol$formatted';
  }

  String _symbolFor(String code) {
    switch (code.toUpperCase()) {
      case 'EUR':
        return '€';
      case 'USD':
      case 'CAD':
      case 'AUD':
        return '\$';
      case 'GBP':
        return '£';
      default:
        return '$code ';
    }
  }

  Widget _buildSoftButton({
    required IconData icon,
    required String text,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 9.h),
        decoration: BoxDecoration(
          color: AppColors.primaryColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(
            color: AppColors.primaryColor.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16.sp, color: AppColors.primaryColor),
            SizedBox(width: 6.w),
            Flexible(
              child: InterText(
                text: text,
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
                color: AppColors.primaryColor,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrimaryButton({
    required VoidCallback? onTap,
    required bool isLoading,
    required bool isCancelRequest,
    required String buttonText,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18.r),
      child: Builder(
        builder: (context) => Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 9.h),
          decoration: BoxDecoration(
            color: isCancelRequest
                ? AppColors.card(context)
                : AppColors.primaryColor,
            borderRadius: BorderRadius.circular(18.r),
            border: Border.all(
              color: isCancelRequest
                  ? AppColors.errorColor
                  : AppColors.primaryColor,
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading) ...[
                SizedBox(
                  width: 14.w,
                  height: 14.h,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isCancelRequest ? AppColors.errorColor : Colors.white,
                    ),
                  ),
                ),
                SizedBox(width: 6.w),
              ] else ...[
                Icon(
                  isCancelRequest ? Icons.cancel_outlined : Icons.send_outlined,
                  size: 16.sp,
                  color: isCancelRequest ? AppColors.errorColor : Colors.white,
                ),
                SizedBox(width: 6.w),
              ],
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: InterText(
                    text: isLoading
                        ? (isCancelRequest
                              ? 'request_cancel_button_cancelling'.tr
                              : 'send_request_button_sending'.tr)
                        : buttonText,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: isCancelRequest ? AppColors.errorColor : Colors.white,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // v425 — remplacé par _buildHeroBanner (maquette 221). Conservé au cas où.
  // ignore: unused_element
  Widget _buildImagesGrid(BuildContext context) {
    final imageCount = petImages.length;
    final spacing = 4.w; // Consistent spacing

    if (imageCount == 1) {
      // Single image - full width
      return _buildImageItem(context, petImages[0], 0, 1);
    } else if (imageCount == 2) {
      // Two images - side by side
      return Row(
        children: [
          Expanded(child: _buildImageItem(context, petImages[0], 0, 2)),
          SizedBox(width: spacing),
          Expanded(child: _buildImageItem(context, petImages[1], 1, 2)),
        ],
      );
    } else if (imageCount == 3) {
      // Three images - one large, two small
      return Row(
        children: [
          Expanded(
            flex: 2,
            child: _buildImageItem(context, petImages[0], 0, 3),
          ),
          SizedBox(width: spacing),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildImageItem(context, petImages[1], 1, 3),
                SizedBox(height: spacing),
                _buildImageItem(context, petImages[2], 2, 3),
              ],
            ),
          ),
        ],
      );
    } else if (imageCount == 4) {
      // Four images - 2x2 grid
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildImageItem(context, petImages[0], 0, 4)),
              SizedBox(width: spacing),
              Expanded(child: _buildImageItem(context, petImages[1], 1, 4)),
            ],
          ),
          SizedBox(height: spacing),
          Row(
            children: [
              Expanded(child: _buildImageItem(context, petImages[2], 2, 4)),
              SizedBox(width: spacing),
              Expanded(child: _buildImageItem(context, petImages[3], 3, 4)),
            ],
          ),
        ],
      );
    } else {
      // More than 4 images - show first 4 in 2x2 grid with overlay
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildImageItem(context, petImages[0], 0, imageCount),
              ),
              SizedBox(width: spacing),
              Expanded(
                child: _buildImageItem(context, petImages[1], 1, imageCount),
              ),
            ],
          ),
          SizedBox(height: spacing),
          Row(
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildImageItem(context, petImages[2], 2, imageCount),
                    if (imageCount > 4)
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12.r),
                          color: Colors.black.withValues(alpha: 0.6),
                        ),
                        child: Center(
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 16.w,
                              vertical: 8.h,
                            ),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black.withValues(alpha: 0.3),
                            ),
                            child: InterText(
                              text: '+${imageCount - 4}',
                              fontSize: 24.sp,
                              fontWeight: FontWeight.bold,
                              color: AppColors.whiteColor,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(width: spacing),
              Expanded(
                child: _buildImageItem(context, petImages[3], 3, imageCount),
              ),
            ],
          ),
        ],
      );
    }
  }

  Widget _buildImageItem(
    BuildContext context,
    String imageUrl,
    int index,
    int total,
  ) {
    final height = _getImageHeight(total, index);
    final borderRadius = 12.r; // Consistent border radius

    return GestureDetector(
      onTap: () => _openPhotoViewer(context, index),
      onLongPress: () => ReportDialog.show(
        context: context,
        targetType: 'photo',
        targetId: '',
        photoUrl: imageUrl,
      ),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          color: AppColors.lightGrey,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: Stack(
            fit: StackFit.expand,
            children: [
              isNetworkImage
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      memCacheWidth: 800, // v235.5 perf post image.
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: AppColors.lightGrey,
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.primaryColor,
                            ),
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: AppColors.lightGrey,
                        child: _buildImageLoadError(
                          context,
                          imageUrl: url,
                          isNetwork: true,
                        ),
                      ),
                    )
                  : Image.asset(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: AppColors.lightGrey,
                          child: _buildImageLoadError(context),
                        );
                      },
                    ),
              // Subtle overlay on hover/tap for better UX
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _openPhotoViewer(context, index),
                  borderRadius: BorderRadius.circular(borderRadius),
                  child: Container(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _getImageHeight(int total, int index) {
    // More consistent heights
    if (total == 1) {
      return 280.h; // Single image - slightly reduced for consistency
    } else if (total == 2) {
      return 220.h; // Two images - taller for better visibility
    } else if (total == 3) {
      if (index == 0) {
        return 220.h; // Large image
      } else {
        return 108.h; // Small images - calculated to fit perfectly
      }
    } else {
      // 4 or more images - consistent square-ish aspect ratio
      return 160.h;
    }
  }

  Widget _buildImageLoadError(
    BuildContext context, {
    String? imageUrl,
    bool isNetwork = false,
  }) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.broken_image_outlined,
            size: 26.sp,
            color: AppColors.textSecondary(context),
          ),
          SizedBox(height: 8.h),
          TextButton.icon(
            onPressed: () async {
              if (isNetwork && imageUrl != null && imageUrl.isNotEmpty) {
                await CachedNetworkImage.evictFromCache(imageUrl);
              }
              (context as Element).markNeedsBuild();
            },
            icon: Icon(
              Icons.refresh,
              size: 16.sp,
              color: AppColors.primaryColor,
            ),
            label: InterText(
              text: 'common_refresh'.tr,
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              color: AppColors.primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  void _openPhotoViewer(BuildContext context, int initialIndex) {
    Get.to(
      () => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          iconTheme: const IconThemeData(color: Colors.white),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Get.back(),
          ),
        ),
        body: PhotoViewGallery.builder(
          scrollPhysics: const BouncingScrollPhysics(),
          builder: (BuildContext context, int index) {
            return PhotoViewGalleryPageOptions(
              imageProvider: isNetworkImage
                  ? NetworkImage(petImages[index])
                  : AssetImage(petImages[index]) as ImageProvider,
              initialScale: PhotoViewComputedScale.contained,
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 2,
            );
          },
          itemCount: petImages.length,
          loadingBuilder: (context, event) => Center(
            child: CircularProgressIndicator(
              value: event == null
                  ? 0
                  : event.cumulativeBytesLoaded / event.expectedTotalBytes!,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
            ),
          ),
          backgroundDecoration: const BoxDecoration(color: Colors.black),
          pageController: PageController(initialPage: initialIndex),
          onPageChanged: (index) {
            // Optional: track page changes
          },
        ),
      ),
    );
  }

  /// v23.1 part 116 — Ruban URGENT pour les posts dont l'owner a un Boost
  /// profil actif. Le tier décide de l'intensité visuelle.
  /// v23.1 part 117 — i18n keys post_urgent_*.
  Widget _buildUrgentBanner() {
    String label;
    Color bg;
    String emoji;
    switch (ownerBoostTier) {
      case 'platinum':
        label = 'post_urgent_platinum'.tr;
        bg = const Color(0xFFC81E1E);
        emoji = '🔥';
        break;
      case 'gold':
        label = 'post_urgent_gold'.tr;
        bg = const Color(0xFFE8472A);
        emoji = '🚀';
        break;
      case 'silver':
        label = 'post_urgent_silver'.tr;
        bg = const Color(0xFFEA580C);
        emoji = '🚀';
        break;
      case 'bronze':
      default:
        label = 'post_urgent_bronze'.tr;
        bg = const Color(0xFFF59E0B);
        emoji = '🚀';
    }
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [bg, bg.withValues(alpha: 0.85)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(19.r),
          topRight: Radius.circular(19.r),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: TextStyle(fontSize: 14.sp)),
          SizedBox(width: 6.w),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 11.sp,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

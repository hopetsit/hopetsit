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

  /// v435 — Daniel : "Lieu de garde" choisi par l'owner ('at_owner' |
  /// 'at_sitter' | 'both'). Affiché comme une case de la grille de
  /// réservation. Null/vide ⇒ la case est masquée.
  final String? serviceLocation;

  /// v442 — détail annonce prestataire (maquettes walker/sitter) : libellé
  /// « Publié il y a 2 h » affiché sous le nom du propriétaire. Null/vide ⇒
  /// masqué.
  final String? publishedLabel;

  /// v442 — libellé de distance « 2 km de vous » affiché à côté de la
  /// localisation dans l'en-tête. Null/vide ⇒ masqué.
  final String? distanceLabel;

  /// v442 — durée d'UNE sortie pour une demande de promenade (minutes),
  /// dérivée de la fenêtre start/end de l'annonce côté hôte. Null ⇒ la case
  /// « Durée » de la grille walker est masquée.
  final int? walkDurationMinutes;

  /// v442 — nombre de sorties par jour pour une demande de promenade. Null ⇒
  /// défaut « 1 fois / jour » (cas le plus courant : une sortie).
  final int? walkTimesPerDay;

  /// v443 — Daniel : l'heure quitte la cellule « Dates » (qui n'affiche plus
  /// que la DATE) pour une petite horloge sous la cellule « Service » (ex.
  /// « 14:00 → 15:00 »). Calculé par les appelants via PostDateLabel.timeLabel.
  /// Null/vide ⇒ aucune horloge (annonce sans heure réelle).
  final String? serviceTime;

  /// #107 — quand un prestataire (promeneur / pet-sitter) consulte l'annonce
  /// d'un owner, l'en-tête (avatar + nom) devient cliquable pour ouvrir le
  /// profil PROPRIÉTAIRE en lecture seule. Null ⇒ en-tête non cliquable (cas
  /// « Mes publications » de l'owner sur sa propre annonce).
  final VoidCallback? onOwnerTap;

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
    this.serviceLocation,
    this.publishedLabel,
    this.distanceLabel,
    this.walkDurationMinutes,
    this.walkTimesPerDay,
    this.serviceTime,
    this.onOwnerTap,
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

  /// v442 — true quand un prestataire (promeneur / pet-sitter) consulte le
  /// détail d'une annonce owner. Pilote les variantes maquettes (grille
  /// Durée/Fréquence vs Animaux/Service, titre caractère, gain « PawMap 10% »).
  bool get _isWalkerView => (viewerRole ?? '').toLowerCase() == 'walker';
  bool get _isSitterView => (viewerRole ?? '').toLowerCase() == 'sitter';
  bool get _isProviderView => _isWalkerView || _isSitterView;


  @override
  Widget build(BuildContext context) {
    // v23.1 part 116 — bordure rouge + halo subtil pour les posts boostés.
    // v442 — détail prestataire : bordure boost teintée à l'accent du rôle
    // (vert walker / bleu sitter) pour matcher le ruban « BOOST ACTIF ».
    final boostBorderColor =
        _isProviderView ? _accent : const Color(0xFFE8472A);
    final boostBorder = isOwnerBoosted
        ? Border.all(
            color: boostBorderColor,
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
                // #107 — en-tête (avatar + nom) cliquable côté prestataire :
                // ouvre le profil propriétaire en lecture seule. Quand
                // onOwnerTap est null (owner sur « Mes publications »), le
                // GestureDetector reste inerte (pas d'onTap).
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onOwnerTap,
                    child: Row(
                      children: [
                // v442 — avatar + pastille « vérifié » colorée au rôle
                // (maquettes walker vert / sitter bleu) pour le détail
                // prestataire ; sinon l'avatar simple (owner / feed).
                Stack(
                  clipBehavior: Clip.none,
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
                            ? CachedNetworkImageProvider(userAvatar!,
                                    maxWidth: 150) as ImageProvider
                            : AssetImage(AppImages.placeholderImage)
                                  as ImageProvider,
                      ),
                    ),
                    if (_isProviderView)
                      Positioned(
                        right: -1.w,
                        bottom: -1.h,
                        child: Container(
                          padding: EdgeInsets.all(2.w),
                          decoration: BoxDecoration(
                            color: AppColors.card(context),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.verified_rounded,
                            size: 15.sp,
                            color: _accent,
                          ),
                        ),
                      ),
                  ],
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
                      // v442 — détail prestataire : sous le nom on affiche la
                      // localisation (+ distance) puis « Publié il y a … » au
                      // lieu du simple libellé de rôle. L'owner / le feed
                      // gardent le libellé « Propriétaire ».
                      if (_isProviderView &&
                          ((location ?? '').trim().isNotEmpty ||
                              (publishedLabel ?? '').trim().isNotEmpty)) ...[
                        if ((location ?? '').trim().isNotEmpty)
                          Row(
                            children: [
                              Icon(Icons.location_on_rounded,
                                  size: 12.sp,
                                  color: AppColors.textSecondary(context)),
                              SizedBox(width: 3.w),
                              Flexible(
                                child: InterText(
                                  text: (distanceLabel ?? '').trim().isNotEmpty
                                      ? '${location!.trim()} • ${distanceLabel!.trim()}'
                                      : location!.trim(),
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textSecondary(context),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        if ((publishedLabel ?? '').trim().isNotEmpty) ...[
                          SizedBox(height: 2.h),
                          Row(
                            children: [
                              Icon(Icons.schedule_rounded,
                                  size: 12.sp,
                                  color: AppColors.textSecondary(context)),
                              SizedBox(width: 3.w),
                              Flexible(
                                child: InterText(
                                  text: publishedLabel!.trim(),
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textSecondary(context),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ] else
                        InterText(
                          text: 'role_pet_owner'.tr,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary(context),
                        ),
                    ],
                  ),
                ),
                      ],
                    ),
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
          // v442 — masquée pour le détail prestataire (maquettes walker/sitter)
          // où les photos vivent dans la bande animaux ; conservée pour
          // owner / feed.
          if (petImages.isNotEmpty && !_isProviderView)
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
          // v442 — owner / feed : la carte « Caractère des animaux » reste
          // AVANT la grille (comportement historique). Côté prestataire elle
          // passe APRÈS la grille (cf. bloc réservation ci-dessous, maquettes).
          if (_hasCharacterData && !_isProviderView)
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
                      // v435 — Daniel : la grille "Demande de réservation"
                      // paraissait grise. On la teinte de l'accent du rôle
                      // (orange pâle côté owner, vert walker / bleu sitter)
                      // pour qu'elle ne lise plus comme un bloc neutre.
                      color: _accent.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(
                        color: _accent.withValues(alpha: 0.20),
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
                  // v442 — détail prestataire (maquettes) : la carte caractère
                  // (« À propos de la promenade » walker / « Caractère de vos
                  // animaux » sitter) vient APRÈS la grille, puis « 📋
                  // Informations importantes ».
                  if (_isProviderView && _hasCharacterData) ...[
                    SizedBox(height: 10.h),
                    _buildCharacterCard(context),
                  ],
                  if (_hasImportantInfo) ...[
                    SizedBox(height: 10.h),
                    _buildImportantInfoCard(context),
                  ],
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
                              // v442 — maquettes : « 🐾 Voir les détails du
                              // chien » (promenade 1 chien) / « 🐾 Voir les
                              // animaux » (sitter) ; sinon libellé générique.
                              icon: Icons.pets_rounded,
                              text: _isWalkerView
                                  ? 'post_view_dog_details'.tr
                                  : _isSitterView
                                      ? 'post_view_pets'.tr
                                      : 'sitter_post_pet_details'.tr,
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
                                  // v442 — détail prestataire : CTA « Postuler
                                  // à cette demande » (maquettes).
                                  : (requestButtonText ??
                                      (isCancelRequest
                                          ? 'service_card_cancel'.tr
                                          : (_isProviderView
                                              ? 'post_apply_cta'.tr
                                              : 'send_request_button'.tr))),
                            ),
                          ),
                      ],
                    ),
                    // v442 — note rassurante sous les CTA (maquettes) :
                    // « 🛡️ Le propriétaire examinera votre profil… ».
                    if (_isProviderView && !isReserved && !isCancelRequest) ...[
                      SizedBox(height: 8.h),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.shield_outlined,
                              size: 13.sp,
                              color: AppColors.textSecondary(context)),
                          SizedBox(width: 6.w),
                          Expanded(
                            child: InterText(
                              text: 'post_apply_review_note'.tr,
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary(context),
                              maxLines: 3,
                            ),
                          ),
                        ],
                      ),
                    ],
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
                  // v442 — détail prestataire (maquettes) : « 🔖 Sauvegarder »
                  // (réutilise le mécanisme « j'aime » comme favori) ; sinon
                  // « J'aime » classique sur le feed / owner.
                  child: _buildActionPill(
                    context: context,
                    icon: _isProviderView
                        ? (isLiked
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded)
                        : (isLiked
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded),
                    label: _isProviderView
                        ? 'post_action_save'.tr
                        : (likeCount > 0
                            ? '${'post_action_like'.tr} · $likeCount'
                            : 'post_action_like'.tr),
                    isActive: isLiked,
                    accent: _isProviderView ? _accent : const Color(0xFFEF4444),
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
                    accent: _isProviderView
                        ? _accent
                        : const Color(0xFF2563EB),
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

  /// v442 — libellé d'âge localisé (« 4 ans » / « 1 an »).
  String _ageLabel(int years) =>
      years <= 1 ? '$years ${'pet_year_unit'.tr}' : '$years ${'pet_years_unit'.tr}';

  /// v442 — libellé de sexe localisé (Mâle / Femelle). '' si inconnu.
  String _sexLabel(String sex) {
    switch (sex.trim().toLowerCase()) {
      case 'male':
      case 'm':
      case 'mâle':
      case 'macho':
        return 'pet_sex_male'.tr;
      case 'female':
      case 'f':
      case 'femelle':
      case 'hembra':
        return 'pet_sex_female'.tr;
      default:
        return '';
    }
  }

  /// Bande des animaux concernés (maquettes walker/sitter) — avatar + nom
  /// (accent rôle) + race + âge + chip de sexe. Côté propriétaire / feed on
  /// garde la version compacte « Nom • N photos › ».
  Widget _buildPetsStrip(BuildContext context) {
    if (_isProviderView) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < pets!.length; i++) ...[
                if (i > 0) SizedBox(width: 12.w),
                Expanded(child: _buildPetStripCard(context, pets![i])),
              ],
            ],
          ),
        ),
      );
    }
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

  /// v442 — bloc animal (détail prestataire) : photo + nom (accent) + race +
  /// âge + chip de sexe (maquettes Hélios / Tommy).
  Widget _buildPetStripCard(BuildContext context, PostPet p) {
    final sex = _sexLabel(p.sex);
    final metaParts = <String>[
      if (p.breed.trim().isNotEmpty) p.breed.trim(),
      if (p.age != null) _ageLabel(p.age!),
    ];
    return Container(
      padding: EdgeInsets.fromLTRB(10.w, 10.h, 10.w, 10.h),
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: _accent.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20.r,
                backgroundColor: _accent.withValues(alpha: 0.12),
                backgroundImage: p.avatar.isNotEmpty
                    ? CachedNetworkImageProvider(p.avatar, maxWidth: 150)
                        as ImageProvider
                    : null,
                child: p.avatar.isEmpty
                    ? Icon(Icons.pets, size: 18.sp, color: _accent)
                    : null,
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: InterText(
                  text: p.petName,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w800,
                  color: _accent,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (metaParts.isNotEmpty) ...[
            SizedBox(height: 8.h),
            InterText(
              text: metaParts.join(' • '),
              fontSize: 11.5.sp,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary(context),
              maxLines: 2,
            ),
          ],
          if (sex.isNotEmpty) ...[
            SizedBox(height: 6.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: InterText(
                text: sex,
                fontSize: 10.5.sp,
                fontWeight: FontWeight.w700,
                color: _accent,
              ),
            ),
          ],
        ],
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

  /// Animaux ayant des données de caractère (bio OU traits OU infos clés
  /// — vaccins / stérilisé / compatibilité — v440).
  List<PostPet> get _petsWithCharacter =>
      pets == null
          ? const <PostPet>[]
          : pets!
              .where((p) =>
                  p.bio.trim().isNotEmpty ||
                  p.characterTraits.isNotEmpty ||
                  p.vaccinationStatus.isNotEmpty ||
                  p.sterilized ||
                  !p.compatibilities.isEmpty)
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
        // v441 — Daniel : carte « Caractère des animaux » en JAUNE PÂLE
        // (au lieu du gris inputFill).
        color: const Color(0xFFFEF9E7),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: const Color(0xFFF6D86B).withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pets_rounded, size: 16.sp, color: const Color(0xFFB8860B)),
              SizedBox(width: 8.w),
              InterText(
                // v442 — titre adapté au rôle : promeneur (1 chien) →
                // « À propos de la promenade » ; pet-sitter → « Caractère de
                // vos animaux » ; owner / feed → titre générique historique.
                text: _isWalkerView
                    ? 'post_walk_about_section'.tr
                    : _isSitterView
                        ? 'post_pets_character_section'.tr
                        : 'post_character_section'.tr,
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
  /// v442 — pour le détail prestataire (walker/sitter), les traits de
  /// caractère sont affichés en lignes ✓ vertes (maquettes) ; la bio reste
  /// affichée en texte. Pour owner / feed on garde la bio (ou traits joints).
  Widget _petCharacterBlock(BuildContext context, PostPet p) {
    final traits = p.characterTraits;
    final desc = p.bio.trim().isNotEmpty
        ? p.bio.trim()
        : (_isProviderView ? '' : traits.map((t) => 'pet_trait_$t'.tr).join(', '));
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
                // v442 — nom de l'animal coloré à l'accent du rôle côté
                // prestataire (vert walker / bleu sitter), sinon noir.
                color: _isProviderView ? _accent : AppColors.textPrimary(context),
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
        // v442 — traits de caractère en lignes ✓ vertes (maquettes prestataire).
        if (_isProviderView && traits.isNotEmpty) ...[
          SizedBox(height: 6.h),
          for (final t in traits) _traitCheckLine(context, 'pet_trait_$t'.tr),
        ],
        // v440 — infos clés (vacciné / stérilisé / compatibilité) en chips.
        if (_petInfoChips(p).isNotEmpty) ...[
          SizedBox(height: 8.h),
          Wrap(
            spacing: 6.w,
            runSpacing: 6.h,
            children: _petInfoChips(p),
          ),
        ],
      ],
    );
  }

  /// v440 — petites pastilles d'info pour un animal sur la carte d'annonce.
  List<Widget> _petInfoChips(PostPet p) {
    final chips = <Widget>[];
    if (p.vaccinationStatus == 'up_to_date') {
      chips.add(_infoChip('pet_vax_up_to_date'.tr, const Color(0xFF16A34A),
          Icons.vaccines_rounded));
    } else if (p.vaccinationStatus == 'partial') {
      chips.add(_infoChip('pet_vax_partial'.tr, const Color(0xFFF59E0B),
          Icons.vaccines_rounded));
    }
    if (p.sterilized) {
      chips.add(_infoChip('pet_sterilized'.tr, _accent, Icons.healing_rounded));
    }
    // Compatibilité : on surface celles qui sont 'compatible'.
    final c = p.compatibilities;
    if (c.withChildren == 'compatible') {
      chips.add(_infoChip('pet_compat_children'.tr, const Color(0xFF2563EB),
          Icons.child_care_rounded));
    }
    if (c.withDogs == 'compatible') {
      chips.add(_infoChip('pet_compat_dogs'.tr, const Color(0xFF2563EB),
          Icons.pets_rounded));
    }
    if (c.withCats == 'compatible') {
      chips.add(_infoChip('pet_compat_cats'.tr, const Color(0xFF2563EB),
          Icons.pets_rounded));
    }
    return chips;
  }

  Widget _infoChip(String label, Color color, IconData icon) => Container(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11.sp, color: color),
            SizedBox(width: 4.w),
            InterText(
              text: label,
              fontSize: 10.sp,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ],
        ),
      );

  /// v442 — ligne « ✓ trait » verte (maquettes prestataire : caractère animal).
  Widget _traitCheckLine(BuildContext context, String label) => Padding(
        padding: EdgeInsets.only(bottom: 4.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.check_circle_rounded,
                size: 13.sp, color: const Color(0xFF16A34A)),
            SizedBox(width: 6.w),
            Expanded(
              child: InterText(
                text: label,
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary(context),
                maxLines: 2,
              ),
            ),
          ],
        ),
      );

  /// v442 — « 📋 Informations importantes » (maquettes prestataire) : les
  /// notes/détails de l'owner en liste à puces. Masquée si vide.
  bool get _hasImportantInfo =>
      _isProviderView && (postBody ?? '').trim().isNotEmpty;

  Widget _buildImportantInfoCard(BuildContext context) {
    final raw = _localizePostBody((postBody ?? '').trim());
    // Découpe en lignes (retours à la ligne ou puces), nettoyées.
    final lines = raw
        .split(RegExp(r'[\n•]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final items = lines.isEmpty ? [raw] : lines;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 12.h),
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: _accent.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.assignment_outlined, size: 15.sp, color: _accent),
              SizedBox(width: 8.w),
              InterText(
                text: 'post_important_info_section'.tr,
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary(context),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          for (final it in items)
            Padding(
              padding: EdgeInsets.only(bottom: 4.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: 6.h, right: 7.w),
                    child: Container(
                      width: 5.w,
                      height: 5.w,
                      decoration: BoxDecoration(
                        color: _accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Expanded(
                    child: InterText(
                      text: it,
                      fontSize: 12.sp,
                      color: AppColors.textSecondary(context),
                      maxLines: 4,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Section "À propos de moi" du propriétaire.
  Widget _buildAboutOwner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 12.h),
      decoration: BoxDecoration(
        // v443 — Daniel : « le cadre gris propriétaire doit être en jaune ».
        // Le cadre « À propos de moi » (propriétaire) passe en JAUNE clair
        // (au lieu de l'orange pâle v441).
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: const Color(0xFFF6C343).withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_rounded, size: 15.sp, color: const Color(0xFFB8860B)),
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

  /// v442 — durée d'une sortie pour la grille walker (« 1 heure par sortie »,
  /// « 30 min par sortie »). Vide si non renseignée.
  String _walkDurationLabel() {
    final m = walkDurationMinutes;
    if (m == null || m <= 0) return '';
    if (m % 60 == 0) {
      final h = m ~/ 60;
      final hLabel = h == 1 ? 'pet_walk_hour_one'.tr : 'pet_walk_hours'.tr;
      return '$h $hLabel ${'post_walk_per_outing'.tr}';
    }
    return '$m ${'pet_walk_minutes'.tr} ${'post_walk_per_outing'.tr}';
  }

  /// v442 — fréquence des sorties pour la grille walker (« 1 fois / jour »).
  /// Défaut 1×/jour (cas le plus courant) quand non précisé.
  String _walkFrequencyLabel() {
    final n = (walkTimesPerDay != null && walkTimesPerDay! > 0)
        ? walkTimesPerDay!
        : 1;
    final times = n == 1 ? 'post_walk_time_one'.tr : 'post_walk_times'.tr;
    return '$n $times ${'post_walk_per_day'.tr}';
  }

  /// Ligne label : valeur de la demande de réservation.
  /// Grille 3 colonnes de la demande de réservation (maquette 221) :
  /// chaque case = pastille icône + libellé + valeur.
  /// v443 — Daniel : couleur du texte du SERVICE dans la grille selon le type
  /// (bleu pet-sitting / vert promenade) ; null = couleur de texte par défaut.
  /// Détecté depuis serviceTypes (clés backend ou libellés localisés déjà
  /// résolus). Inconnu ⇒ null (texte neutre).
  Color? get _serviceTextColor {
    final raw = (serviceTypes ?? '').toLowerCase();
    if (raw.trim().isEmpty) return null;
    final isWalk = raw.contains('walk') ||
        raw.contains('promenade') ||
        raw.contains('promeneur') ||
        raw.contains('paseo') ||
        raw.contains('passeggi') ||
        raw.contains('gassi') ||
        raw.contains('passeio');
    if (isWalk) return const Color(0xFF16A34A);
    final isSitting = raw.contains('sitting') ||
        raw.contains('garde') ||
        raw.contains('hébergement') ||
        raw.contains('hebergement') ||
        raw.contains('boarding') ||
        raw.contains('care') ||
        raw.contains('cuidado') ||
        raw.contains('guardia') ||
        raw.contains('betreuung') ||
        raw.contains('custodia');
    if (isSitting) return const Color(0xFF2563EB);
    return null;
  }

  Widget _buildReservationGrid(BuildContext context) {
    final cells = <Widget>[];
    void add(IconData icon, String label, String value) {
      if (value.trim().isEmpty) return;
      cells.add(_resCell(context, icon, label, value.trim()));
    }

    // v443 — cellule « Service » : valeur colorée par type (bleu/vert) + petite
    // horloge sous le texte quand l'annonce porte une heure réelle.
    void addService(String value) {
      if (value.trim().isEmpty) return;
      cells.add(_resCell(
        context,
        Icons.volunteer_activism_rounded,
        'post_field_service'.tr,
        value.trim(),
        valueColor: _serviceTextColor,
        timeLabel: (serviceTime ?? '').trim(),
      ));
    }

    // v442 — maquette WALKER : grille Dates / Lieu / Durée / Fréquence.
    if (_isWalkerView) {
      add(Icons.calendar_today_rounded, 'post_field_dates'.tr, dateRange ?? '');
      add(Icons.location_on_rounded, 'post_field_location'.tr, location ?? '');
      final duration = _walkDurationLabel();
      if (duration.isNotEmpty) {
        add(Icons.timelapse_rounded, 'post_field_walk_duration'.tr, duration);
      }
      add(Icons.repeat_rounded, 'post_field_walk_frequency'.tr,
          _walkFrequencyLabel());
      return _gridFromCells(cells);
    }

    // v442 — maquette SITTER : grille Dates / Lieu / Animaux (compte) / Service.
    if (_isSitterView) {
      add(Icons.calendar_today_rounded, 'post_field_dates'.tr, dateRange ?? '');
      add(Icons.location_on_rounded, 'post_field_location'.tr, location ?? '');
      if (pets != null && pets!.isNotEmpty) {
        add(Icons.pets_rounded, 'post_field_pet_count'.tr, '${pets!.length}');
      }
      if ((serviceTypes ?? '').trim().isNotEmpty) {
        addService(_localizedServices(serviceTypes!.trim()));
      }
      final svcLoc = _localizedServiceLocation((serviceLocation ?? '').trim());
      if (svcLoc.isNotEmpty) {
        add(Icons.home_rounded, 'post_field_service_location'.tr, svcLoc);
      }
      return _gridFromCells(cells);
    }

    // Owner / feed — grille générique historique (inchangée).
    add(Icons.calendar_today_rounded, 'post_field_dates'.tr, dateRange ?? '');
    add(Icons.location_on_rounded, 'post_field_location'.tr, location ?? '');
    if (pets != null && pets!.isNotEmpty) {
      add(Icons.pets_rounded, 'post_field_pet_count'.tr, '${pets!.length}');
    }
    add(Icons.category_rounded, 'post_field_pet_types'.tr, _petTypesLabel);
    if ((serviceTypes ?? '').trim().isNotEmpty) {
      addService(_localizedServices(serviceTypes!.trim()));
    }
    // v435 — Daniel : afficher le "Lieu de garde" choisi à la publication.
    final svcLoc = _localizedServiceLocation((serviceLocation ?? '').trim());
    if (svcLoc.isNotEmpty) {
      add(Icons.home_rounded, 'post_field_service_location'.tr, svcLoc);
    }
    add(Icons.notes_rounded, 'post_field_details'.tr,
        _localizePostBody((postBody ?? '').trim()));
    if ((pets == null || pets!.isEmpty) && (petName ?? '').trim().isNotEmpty) {
      add(Icons.pets_rounded, 'post_field_animals'.tr, petName!.trim());
    }

    return _gridFromCells(cells);
  }

  /// v442 — agence une liste de cases en grille 3 colonnes (factorisé pour les
  /// variantes walker / sitter / owner de la grille de réservation).
  Widget _gridFromCells(List<Widget> cells) {
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
      BuildContext context, IconData icon, String label, String value,
      {Color? valueColor, String? timeLabel}) {
    final hasTime = (timeLabel ?? '').trim().isNotEmpty;
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
            // v443 — texte du Service coloré par type (bleu sitting / vert
            // promenade) ; sinon couleur de texte par défaut.
            color: valueColor ?? AppColors.textPrimary(context),
            maxLines: 3,
          ),
          // v443 — Daniel : l'heure quitte la cellule « Dates » pour une petite
          // horloge sous « Service ». Affichée uniquement si une heure réelle
          // existe (pas minuit).
          if (hasTime) ...[
            SizedBox(height: 4.h),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.schedule_rounded, size: 12.sp, color: _accent),
                SizedBox(width: 3.w),
                Expanded(
                  child: InterText(
                    text: timeLabel!.trim(),
                    fontSize: 10.5.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary(context),
                    maxLines: 2,
                  ),
                ),
              ],
            ),
          ],
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

  // v435 — mappe la valeur backend de serviceLocation vers un libellé court
  // (Chez moi / Chez le sitter / Les deux). Valeur inconnue ⇒ '' (case masquée).
  String _localizedServiceLocation(String raw) {
    switch (raw.toLowerCase()) {
      case 'at_owner':
        return 'post_field_service_location_at_owner'.tr;
      case 'at_sitter':
        return 'post_field_service_location_at_sitter'.tr;
      case 'both':
        return 'post_field_service_location_both'.tr;
      default:
        return '';
    }
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
    final accent = _accent;
    // v442 — détail prestataire (maquettes) : « 👛 Votre gain estimé » avec
    // ligne Client paie / Commission PawMap 10% / Vous recevez 90%.
    if (_isProviderView) {
      return _buildProviderGainBlock(context, est, accent);
    }

    // Owner / feed — layout brut + net historique (inchangé).
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

  /// v442/v443 — « 👛 Votre gain estimé » du prestataire (maquettes walker/sitter).
  ///
  /// MODÈLE DE PAIEMENT (backend pricing.js) : la commission de 20% est payée
  /// par le PROPRIÉTAIRE EN PLUS du tarif ; le prestataire reçoit son tarif
  /// PLEIN (la commission n'est PAS déduite de son gain).
  ///   • est.net  = ce que le prestataire reçoit (= son tarif plein)
  ///   • est.brut = ce que le propriétaire paie (tarif + 20%)
  /// → « Vous recevez » = est.net (gros chiffre), « Le client paie » = est.brut.
  Widget _buildProviderGainBlock(
      BuildContext context, PostPriceEstimate est, Color accent) {
    final clientTotal = est.brut;
    final providerEarnings = est.net;
    final totalLabel = _formatMoneyShort(clientTotal, est.currency);
    final earningsLabel = _formatMoneyShort(providerEarnings, est.currency);

    Widget line(String label, String value, {Color? valueColor}) => Padding(
          padding: EdgeInsets.only(bottom: 6.h),
          child: Row(
            children: [
              Expanded(
                child: InterText(
                  text: label,
                  fontSize: 11.5.sp,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary(context),
                ),
              ),
              InterText(
                text: value,
                fontSize: 12.5.sp,
                fontWeight: FontWeight.w700,
                color: valueColor ?? AppColors.textPrimary(context),
              ),
            ],
          ),
        );

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
        border: Border.all(color: accent.withValues(alpha: 0.25), width: 1.w),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_wallet_outlined,
                  size: 16.sp, color: accent),
              SizedBox(width: 6.w),
              InterText(
                text: 'post_gain_estimate_title'.tr,
                fontSize: 12.sp,
                fontWeight: FontWeight.w800,
                color: accent,
              ),
            ],
          ),
          SizedBox(height: 10.h),
          line('post_gain_client_pays'.tr, totalLabel),
          Divider(
            height: 14.h,
            color: accent.withValues(alpha: 0.25),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: InterText(
                  text: 'post_gain_you_get'.tr,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary(context),
                ),
              ),
              InterText(
                text: earningsLabel,
                fontSize: 22.sp,
                fontWeight: FontWeight.w900,
                color: accent,
              ),
            ],
          ),
          SizedBox(height: 6.h),
          InterText(
            text: 'post_gain_variation_note'.tr,
            fontSize: 10.sp,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary(context),
            maxLines: 3,
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
          // v442 — bouton secondaire teinté à l'accent du rôle (vert walker /
          // bleu sitter / orange owner) au lieu d'orange fixe.
          color: _accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(
            color: _accent.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16.sp, color: _accent),
            SizedBox(width: 6.w),
            Flexible(
              child: InterText(
                text: text,
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
                color: _accent,
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
            // v442 — bouton principal teinté à l'accent du rôle.
            color: isCancelRequest ? AppColors.card(context) : _accent,
            borderRadius: BorderRadius.circular(18.r),
            border: Border.all(
              color: isCancelRequest ? AppColors.errorColor : _accent,
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
                  // v442 — détail prestataire : « ✓ Postuler à cette demande ».
                  isCancelRequest
                      ? Icons.cancel_outlined
                      : (_isProviderView
                          ? Icons.check_rounded
                          : Icons.send_outlined),
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
    // v442 — détail prestataire (maquettes) : ruban « 🚀 BOOST ACTIF » teinté
    // à l'accent du rôle (vert walker / bleu sitter) au lieu du ruban URGENT
    // rouge/orange par tier (qui reste côté owner / feed).
    if (_isProviderView) {
      label = 'post_boost_active'.tr;
      bg = _accent;
      emoji = '🚀';
    } else {
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

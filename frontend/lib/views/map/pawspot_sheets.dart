import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
// v532 — partage d'un spot (auto-promotion) + repli copie du lien.
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hopetsit/controllers/pawspot_controller.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/bottom_inset.dart';
import 'package:hopetsit/utils/storage_keys.dart';
import 'package:hopetsit/views/boost/coin_shop_screen.dart';
import 'package:hopetsit/views/map/widgets/map_sheet_kit.dart';
import 'package:hopetsit/widgets/action_banner_kit.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_confirmation_dialog.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:hopetsit/widgets/rounded_text_button.dart';

/// v23.1.353 — refonte PawSpot (Daniel) : sheets de CRÉATION et de DÉTAIL
/// des spots communautaires de la PawMap. Les clés i18n `pawspot_*`
/// existent déjà dans les 6 langues.

const Color _kGold = Color(0xFFE8A00A);
const Color _kGoldPaw = Color(0xFFFFD700);
const Color _kOrange = Color(0xFFC92A12);
const Color _kViolet = Color(0xFF7C3AED);

/// Ouvre la sheet de création d'un PawSpot. La position du spot est figée au
/// centre de la carte au moment de l'ouverture. Retourne `true` si un spot a
/// été publié (le caller recharge la couche).
Future<bool?> showPawSpotCreateSheet(
  BuildContext context, {
  required PawSpotController controller,
  required LatLng position,
  // v555 — « Photo du spot » (grande carte) : la photo est prise AVANT
  // d'ouvrir la fiche, elle arrive ici déjà envoyée.
  String initialPhotoUrl = '',
}) {
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: AppColors.card(context),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    useSafeArea: true,
    builder: (_) => _PawSpotCreateSheet(
      controller: controller,
      position: position,
      initialPhotoUrl: initialPhotoUrl,
    ),
  );
}

/// Ouvre la sheet de détail d'un PawSpot. [onDirections] est appelé après
/// fermeture quand l'utilisateur tape "Itinéraire" (le caller dessine la
/// polyline + appelle visit() en best-effort). [onChanged] est appelé après
/// une mutation (suppression, mise en avant...) pour recharger la couche.
void showPawSpotDetailSheet(
  BuildContext context, {
  required PawSpotModel spot,
  required PawSpotController controller,
  required void Function(PawSpotModel spot) onDirections,
  VoidCallback? onChanged,
}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.card(context),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    useSafeArea: true,
    builder: (_) => _PawSpotDetailSheet(
      spot: spot,
      controller: controller,
      onDirections: onDirections,
      onChanged: onChanged,
    ),
  );
}

// ════════════════════════════════════════════════════════════════════════════
// CRÉATION
// ════════════════════════════════════════════════════════════════════════════

class _PawSpotCreateSheet extends StatefulWidget {
  const _PawSpotCreateSheet({
    required this.controller,
    required this.position,
    this.initialPhotoUrl = '',
  });

  final PawSpotController controller;
  final LatLng position;
  final String initialPhotoUrl;

  @override
  State<_PawSpotCreateSheet> createState() => _PawSpotCreateSheetState();
}

class _PawSpotCreateSheetState extends State<_PawSpotCreateSheet> {
  String? _type;
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  late String _photoUrl = widget.initialPhotoUrl;
  bool _uploadingPhoto = false;
  bool _submitting = false;

  // v567 — « compteur de tags gratuits restants ». Le serveur le renvoyait
  // (freeSpotLimit / mySpotsCount) mais AUCUN écran ne l'affichait : on
  // découvrait la limite de 3 en se prenant le refus 402 au 4e tag.
  // null = pas encore chargé ; -1 = illimité (abonné / staff).
  int? _freeLeft;

  @override
  void initState() {
    super.initState();
    _loadFreeLeft();
  }

  Future<void> _loadFreeLeft() async {
    final me = await widget.controller.myPoints();
    if (!mounted || me == null) return;
    final raw = me['freeSpotsLeft'];
    setState(() {
      if (me['subscribed'] == true || raw == null) {
        _freeLeft = -1; // illimité
      } else {
        _freeLeft = (raw as num).toInt();
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    if (_uploadingPhoto) return;
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1280,
        imageQuality: 80,
      );
      if (picked == null) return;
      setState(() => _uploadingPhoto = true);
      final url = await widget.controller.uploadPhoto(File(picked.path));
      if (!mounted) return;
      setState(() {
        _uploadingPhoto = false;
        _photoUrl = url ?? '';
      });
      if (url == null) {
        CustomSnackbar.showError(
          title: 'common_error'.tr,
          message: 'pawspot_add_photo'.tr,
        );
      }
    } catch (e) {
      debugPrint('[PawSpot] pickPhoto error: $e');
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _publish() async {
    if (_submitting) return;
    if (_type == null) {
      CustomSnackbar.showWarning(
        title: 'pawspot_add_type_label'.tr,
        message: 'pawspot_add_type_hint'.tr,
      );
      return;
    }
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      CustomSnackbar.showWarning(
        title: 'pawspot_add_name_label'.tr,
        message: 'pawspot_add_name_hint'.tr,
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final res = await widget.controller.create(
        type: _type!,
        name: name,
        description: _descCtrl.text.trim(),
        photoUrl: _photoUrl,
        lat: widget.position.latitude,
        lng: widget.position.longitude,
      );
      if (!mounted) return;
      // v567 — on annonce les points RÉELLEMENT crédités par le serveur
      // (avant : toujours « +10 », alors qu'un abonné Paw Premium en reçoit 20
      // grâce aux « points doublés » — sa récompense était invisible).
      final earned = (res['pointsEarned'] as num?)?.toInt() ?? 0;
      final capped = res['dailyCapReached'] == true;
      Navigator.of(context).pop(true);
      if (capped || earned == 0) {
        CustomSnackbar.showWarning(
          title: 'PawSpot 🐾',
          message: pawSpotTr(
            'pawspot567_daily_cap',
            'Daily points limit reached: this spot earns no PawPoints',
          ),
        );
      } else {
        CustomSnackbar.showSuccess(
          title: 'PawSpot 🐾',
          message: 'pawspot_published_msg'.trParams({'points': '$earned'}),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      if (PawSpotController.errorCode(e) == 'PAWSPOT_REQUIRED') {
        Navigator.of(context).pop(false);
        CustomSnackbar.showWarning(
          title: 'pawspot_subscribe_required'.tr,
          message: 'pawspot_limit_reached'.tr,
        );
        Get.to(() => const CoinShopScreen(initialTab: 2));
        return;
      }
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'pawmap_snack_search_failed_msg'.tr,
      );
    }
  }

  // v573 — champs du kit PawMap : surface `scaffold`, filet `divider`,
  // coins 14, focus à la couleur PawSpot.
  InputDecoration _fieldDecoration(String hint) =>
      mapFieldDecoration(context, hint: hint, focusTint: _kGold);

  /// v573 — le type passe par une rangée maison + feuille de choix (icône dans
  /// un rond teinté, libellé, coche) au lieu du `DropdownButton` Material.
  /// La valeur retenue et sa validation à la publication sont inchangées.
  Future<void> _pickType() async {
    final picked = await showMapChoiceSheet<String>(
      context: context,
      title: 'pawspot_add_type_label'.tr,
      subtitle: 'pawspot_add_type_hint'.tr,
      selected: _type,
      tint: _kGold,
      options: PawSpotTypes.all
          .map((t) => MapChoiceOption<String>(
                value: t,
                label: '${PawSpotTypes.emoji(t)}  ${PawSpotTypes.label(t)}',
                icon: Icons.place_rounded,
                tint: PawSpotTypes.color(t),
              ))
          .toList(),
    );
    if (picked != null && mounted) setState(() => _type = picked);
  }

  Widget _label(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6.h),
      child: InterText(
        text: text,
        fontSize: 12.sp,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary(context),
      ),
    );
  }

  /// v567 — « il te reste N tags gratuits » / « tags illimités ».
  Widget _freeLeftChip() {
    final left = _freeLeft ?? 0;
    final unlimited = left < 0;
    final none = !unlimited && left <= 0;
    final Color tint = AppColors.accentOn(
      context,
      unlimited
          ? const Color(0xFF16A34A)
          : none
              ? _kOrange
              : _kGold,
    );
    final String text;
    if (unlimited) {
      text = '∞ ${pawSpotTr('pawspot567_unlimited_tags', 'Unlimited tags')}';
    } else if (none) {
      text = pawSpotTr(
        'pawspot567_no_free_left',
        'No free tag left — subscribe for unlimited tagging',
      );
    } else if (left == 1) {
      text = pawSpotTr('pawspot567_free_left_one', '1 free tag left');
    } else {
      text = pawSpotTr('pawspot567_free_left', '{n} free tags left')
          .replaceAll('{n}', '$left');
    }
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: tint.withValues(alpha: 0.5)),
      ),
      child: InterText(
        text: text,
        fontSize: 11.sp,
        fontWeight: FontWeight.w700,
        color: tint,
        maxLines: 2,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Suit le clavier (isScrollControlled) pour que le bouton publier reste
      // visible pendant la saisie.
      // v556 — Daniel (capture) : « en grande carte, quand on prend la photo,
      // Publier le PawSpot est masqué par le menu ». `useSafeArea` ne suffit
      // pas : sur son Samsung `viewPadding.bottom` vaut 0 (edge-to-edge) et le
      // bouton finissait sous la barre système. Même règle que la carte
      // (`_navInset`) : marge système réelle, ou 48 si le système annonce 0.
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20.w,
          16.h,
          20.w,
          // v569 — utilitaire unique `appBottomInset` (iOS = inset réel,
          // Android = jamais moins de 48 px).
          20.h + appBottomInset(context),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const MapSheetHandle(),
            MapSheetTitle(
              title: 'pawspot_add_title'.tr,
              emoji: '🐾',
              tint: _kGold,
              onClose: () => Navigator.of(context).pop(false),
            ),
            SizedBox(height: 6.h),
            // Position = centre de la carte au moment de l'ouverture.
            Row(
              children: [
                Icon(Icons.place_rounded,
                    size: 14.sp, color: AppColors.accentOn(context, _kGold)),
                SizedBox(width: 4.w),
                Expanded(
                  child: InterText(
                    text:
                        '${widget.position.latitude.toStringAsFixed(5)}, ${widget.position.longitude.toStringAsFixed(5)}',
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            // v567 — tags gratuits restants (serveur : freeSpotsLeft).
            if (_freeLeft != null) ...[
              SizedBox(height: 8.h),
              _freeLeftChip(),
            ],
            SizedBox(height: 14.h),
            _label('pawspot_add_type_label'.tr),
            MapSheetCard(
              radius: 14.r,
              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
              color: AppColors.scaffold(context),
              onTap: _pickType,
              child: MapChoiceRow(
                dense: true,
                icon: _type == null
                    ? Icons.category_outlined
                    : Icons.place_rounded,
                tint: _type == null ? _kGold : PawSpotTypes.color(_type!),
                label: _type == null
                    ? 'pawspot_add_type_hint'.tr
                    : '${PawSpotTypes.emoji(_type!)}  ${PawSpotTypes.label(_type!)}',
                showChevron: true,
              ),
            ),
            SizedBox(height: 12.h),
            _label('pawspot_add_name_label'.tr),
            TextField(
              controller: _nameCtrl,
              maxLength: 80,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary(context),
              ),
              decoration: _fieldDecoration('pawspot_add_name_hint'.tr)
                  .copyWith(counterText: ''),
            ),
            SizedBox(height: 12.h),
            _label('pawspot_add_desc_label'.tr),
            TextField(
              controller: _descCtrl,
              minLines: 3,
              maxLines: 5,
              maxLength: 500,
              style: TextStyle(
                fontSize: 13.sp,
                color: AppColors.textPrimary(context),
              ),
              decoration: _fieldDecoration('pawspot_add_desc_hint'.tr)
                  .copyWith(counterText: ''),
            ),
            SizedBox(height: 12.h),
            // Photo optionnelle (+5 pts) — upload Cloudinary existant.
            Builder(builder: (ctx) {
              final Color gold = AppColors.accentOn(ctx, _kGold);
              final bool hasPhoto = _photoUrl.isNotEmpty;
              return InkWell(
                borderRadius: BorderRadius.circular(16.r),
                onTap: _pickPhoto,
                child: Container(
                  width: double.infinity,
                  padding:
                      EdgeInsets.symmetric(vertical: 12.h, horizontal: 12.w),
                  decoration: BoxDecoration(
                    color: hasPhoto
                        ? gold.withValues(alpha: 0.06)
                        : AppColors.card(ctx),
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(
                      color: hasPhoto ? gold : AppColors.divider(ctx),
                      width: 1.3,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_uploadingPhoto)
                        MapSkeletonBox(width: 36.w, height: 36.w, radius: 10.r)
                      else if (hasPhoto)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10.r),
                          child: CachedNetworkImage(
                            imageUrl: _photoUrl,
                            width: 36.w,
                            height: 36.w,
                            fit: BoxFit.cover,
                          ),
                        )
                      else
                        Icon(Icons.add_a_photo_outlined,
                            size: 18.sp, color: AppColors.textSecondary(ctx)),
                      SizedBox(width: 8.w),
                      Flexible(
                        child: InterText(
                          text: 'pawspot_add_photo'.tr,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                          color:
                              hasPhoto ? gold : AppColors.textSecondary(ctx),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (hasPhoto) ...[
                        SizedBox(width: 6.w),
                        Icon(Icons.check_circle_rounded,
                            size: 16.sp, color: gold),
                      ],
                    ],
                  ),
                ),
              );
            }),
            SizedBox(height: 18.h),
            // v573 — bouton du kit (`CustomButton`) à la place de
            // l'`ElevatedButton` Material. Action inchangée.
            CustomButton(
              width: double.infinity,
              height: 52.h,
              radius: 16.r,
              bgColor: _kOrange,
              textColor: Colors.white,
              onTap: _submitting ? null : _publish,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_submitting)
                    SizedBox(
                      width: 16.w,
                      height: 16.w,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  else
                    Icon(Icons.publish_rounded,
                        color: Colors.white, size: 18.sp),
                  SizedBox(width: 8.w),
                  Flexible(
                    child: InterText(
                      text: 'pawspot_publish_btn'.tr,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// DÉTAIL
// ════════════════════════════════════════════════════════════════════════════

class _PawSpotDetailSheet extends StatefulWidget {
  const _PawSpotDetailSheet({
    required this.spot,
    required this.controller,
    required this.onDirections,
    this.onChanged,
  });

  final PawSpotModel spot;
  final PawSpotController controller;
  final void Function(PawSpotModel spot) onDirections;
  final VoidCallback? onChanged;

  @override
  State<_PawSpotDetailSheet> createState() => _PawSpotDetailSheetState();
}

class _PawSpotDetailSheetState extends State<_PawSpotDetailSheet> {
  late int _likesCount = widget.spot.likesCount;
  late int _validationsCount = widget.spot.validationsCount;
  // v567 — état RÉEL renvoyé par le serveur (likedByMe / validatedByMe).
  // Avant, le cœur repartait TOUJOURS vide : rouvrir une fiche déjà aimée puis
  // retaper le cœur retirait le like en croyant l'ajouter.
  late bool _liked = widget.spot.likedByMe;
  late bool _validated = widget.spot.validatedByMe;
  bool _likeBusy = false;
  bool _validateBusy = false;
  List<Map<String, dynamic>> _comments = const [];
  bool _commentsLoading = true;
  final TextEditingController _commentCtrl = TextEditingController();
  bool _sendingComment = false;

  /// Suis-je le créateur du spot ?
  /// v567 — on fait d'abord confiance au serveur (`isMine`), qui compare sur
  /// le VRAI identifiant du profil courant. Le repli GetStorage reste pour les
  /// spots déjà en mémoire avant la mise à jour du serveur.
  bool get _isCreator {
    if (widget.spot.isMine) return true;
    try {
      final raw = GetStorage().read(StorageKeys.userProfile);
      final myId = raw is Map ? (raw['id'] ?? '').toString() : '';
      return myId.isNotEmpty && myId == widget.spot.creatorId;
    } catch (_) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    final list = await widget.controller.comments(widget.spot.id);
    if (!mounted) return;
    setState(() {
      _comments = list;
      _commentsLoading = false;
    });
  }

  Future<void> _toggleLike() async {
    if (_likeBusy) return;
    setState(() => _likeBusy = true);
    final r = await widget.controller.like(widget.spot.id);
    if (!mounted) return;
    setState(() {
      _likeBusy = false;
      if (r != null) {
        _liked = r['liked'] == true;
        _likesCount = ((r['likesCount'] as num?) ?? _likesCount).toInt();
      }
    });
  }

  Future<void> _validateSpot() async {
    if (_validateBusy) return;
    setState(() => _validateBusy = true);
    final r = await widget.controller.validate(widget.spot.id);
    if (!mounted) return;
    setState(() {
      _validateBusy = false;
      if (r != null) {
        _validationsCount =
            ((r['validationsCount'] as num?) ?? _validationsCount).toInt();
        _validated = true;
      }
    });
    if (r == null) return;
    if (r['already'] == true) {
      // v567 — avant, un 2e tap ne disait rien du tout.
      CustomSnackbar.showInfo(
        title: 'PawSpot 🐾',
        message: pawSpotTr(
          'pawspot567_already_validated',
          'You already validated this spot',
        ),
      );
      return;
    }
    // v567 — on affichait le LIBELLÉ DU BOUTON (« Valider ce spot ») comme
    // message de confirmation. On confirme maintenant vraiment.
    CustomSnackbar.showSuccess(
      title: 'PawSpot 🐾',
      message: pawSpotTr('pawspot567_validate_thanks', 'Thanks! Spot validated'),
    );
    widget.onChanged?.call();
  }

  Future<void> _sendComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty || _sendingComment) return;
    setState(() => _sendingComment = true);
    final res = await widget.controller.comment(widget.spot.id, text);
    if (!mounted) return;
    setState(() => _sendingComment = false);
    if (res != null) {
      _commentCtrl.clear();
      // v23.1.357 — Daniel : "que ça comptabilise les points sur la PawMap".
      // v567 — les +2 ne sont crédités qu'au PREMIER commentaire d'une
      // personne sur un spot donné (anti-ferme à points). On n'annonce donc
      // « +2 PawPoints » que si le serveur les a vraiment donnés.
      final earned = (res['pointsEarned'] as num?)?.toInt() ?? 0;
      if (earned > 0) {
        CustomSnackbar.showSuccess(
          title: 'pawspot_reward_redeemed'.tr,
          message: 'pawspot_points_comment'.tr,
        );
      } else {
        CustomSnackbar.showSuccess(
          title: 'PawSpot 🐾',
          message: pawSpotTr('pawspot567_comment_posted', 'Comment posted'),
        );
      }
      setState(() => _commentsLoading = true);
      await _loadComments();
    }
  }

  /// Ouvre le dialogue de confirmation partagé et attend la réponse.
  /// `barrierDismissible: false` côté `CustomConfirmationDialog` garantit
  /// qu'un des deux callbacks est toujours appelé.
  Future<bool> _askDelete() {
    final completer = Completer<bool>();
    CustomConfirmationDialog.show(
      context: context,
      message: 'pawspot_delete_confirm'.tr,
      yesText: 'common_delete'.tr,
      cancelText: 'common_cancel'.tr,
      yesButtonColor: AppColors.errorColor,
      onYes: () {
        if (!completer.isCompleted) completer.complete(true);
      },
      onCancel: () {
        if (!completer.isCompleted) completer.complete(false);
      },
    );
    return completer.future;
  }

  Future<void> _confirmDelete() async {
    // v573 — dialogue de confirmation partagé de l'app
    // (`CustomConfirmationDialog`) : carte coins 24, disque rouge, boutons du
    // kit. Le `Colors.red` brut de l'ancien `ElevatedButton` disparaît ;
    // la suppression elle-même est inchangée.
    final bool confirmed = await _askDelete();
    if (!confirmed || !mounted) return;
    final res = await widget.controller.deleteSpot(widget.spot.id);
    if (!mounted) return;
    Navigator.of(context).pop();
    if (res != null) {
      // v567 — supprimer son spot REPREND les PawPoints qu'il avait rapportés
      // (avant : on gardait les points, donc créer/supprimer en boucle en
      // fabriquait à l'infini). On le dit clairement plutôt que de laisser
      // l'utilisateur voir son total baisser sans explication.
      final revoked = (res['pointsRevoked'] as num?)?.toInt() ?? 0;
      CustomSnackbar.showSuccess(
        title: 'PawSpot 🐾',
        message: revoked > 0
            ? pawSpotTr(
                'pawspot567_points_revoked',
                'Spot deleted · {n} PawPoints taken back',
              ).replaceAll('{n}', '$revoked')
            : 'common_delete'.tr,
      );
      widget.onChanged?.call();
    } else {
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'pawmap_snack_search_failed_msg'.tr,
      );
    }
  }

  /// Mise en avant 7 j (50 pts) — récompense premium réservée au créateur.
  Future<void> _featureSpot() async {
    try {
      await widget.controller
          .redeemReward('feature_spot', spotId: widget.spot.id);
      if (!mounted) return;
      CustomSnackbar.showSuccess(
        title: 'PawSpot 🐾',
        message: 'pawspot_reward_redeemed'.tr,
      );
      widget.onChanged?.call();
    } catch (e) {
      if (!mounted) return;
      final code = PawSpotController.errorCode(e);
      if (code == 'INSUFFICIENT_POINTS') {
        CustomSnackbar.showError(
          title: 'pawspot_points_title'.tr,
          message: 'pawspot_reward_feature'.tr,
        );
      } else if (code == 'PAWSPOT_REQUIRED') {
        CustomSnackbar.showWarning(
          title: 'pawspot_subscribe_required'.tr,
          message: 'pawspot_shop_subtitle'.tr,
        );
        Get.to(() => const CoinShopScreen(initialTab: 2));
      } else {
        CustomSnackbar.showError(
          title: 'common_error'.tr,
          message: 'pawmap_snack_search_failed_msg'.tr,
        );
      }
    }
  }

  Widget _statChip(String emoji, String value, String label) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 4.w),
        decoration: BoxDecoration(
          color: AppColors.scaffold(context),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: AppColors.divider(context)),
        ),
        child: Column(
          children: [
            InterText(
              text: '$emoji $value',
              fontSize: 13.sp,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary(context),
            ),
            SizedBox(height: 2.h),
            InterText(
              text: label,
              fontSize: 10.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary(context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  /// v532 — partage du spot vers WhatsApp / Instagram / SMS…
  ///
  /// Le message contient le nom du lieu, sa ville et le lien `/spot/<id>` du
  /// site. Cette page est rendue côté SERVEUR : la messagerie affiche donc un
  /// vrai aperçu (photo + titre), ce qui donne envie d'ouvrir — c'est tout
  /// l'intérêt pour l'acquisition. Le paramètre `?from=app` permet de mesurer
  /// ce que ce canal rapporte.
  Future<void> _shareSpot() async {
    final spot = widget.spot;
    final url = 'https://www.hopetsit.com/spot/${spot.id}?from=app';
    final text = '${'pawspot_share_message'.trParams({
      'name': spot.name,
    })}\n$url';
    try {
      await SharePlus.instance.share(ShareParams(text: text));
    } catch (_) {
      // Feuille de partage indisponible : on copie le lien en repli.
      await Clipboard.setData(ClipboardData(text: url));
      CustomSnackbar.showSuccess(
        title: 'pawspot_share_copied'.tr,
        message: '',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final spot = widget.spot;
    final typeColor = PawSpotTypes.color(spot.type);
    // v573 — variantes lisibles en mode sombre (helpers contextuels).
    final Color typeTone = AppColors.accentOn(context, typeColor);
    final Color goldTone = AppColors.accentOn(context, _kGold);
    final Color violetTone = AppColors.accentOn(context, _kViolet);
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20.w,
          16.h,
          20.w,
          // v569 — `viewPadding.bottom` vaut 0 sur le Samsung de Daniel : les
          // boutons du bas de la fiche finissaient sous la barre système.
          16.h +
              (MediaQuery.of(context).viewInsets.bottom > 0
                  ? MediaQuery.of(context).viewInsets.bottom
                  : appBottomInset(context)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const MapSheetHandle(),
            // ── Photo (si présente) + badge 🐾 doré en surimpression ─────
            if (spot.photoUrl.isNotEmpty) ...[
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18.r),
                    child: CachedNetworkImage(
                      imageUrl: spot.photoUrl,
                      width: double.infinity,
                      height: 160.h,
                      fit: BoxFit.cover,
                      // v573 — squelette simple au lieu d'une roue centrée.
                      placeholder: (_, __) => MapSkeletonBox(
                        height: 160.h,
                        radius: 18.r,
                      ),
                      errorWidget: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                  if (spot.isGolden)
                    Positioned(
                      top: 8.h,
                      right: 8.w,
                      child: Container(
                        padding: EdgeInsets.all(6.w),
                        decoration: BoxDecoration(
                          color: _kGoldPaw,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: Text('🐾', style: TextStyle(fontSize: 14.sp)),
                      ),
                    ),
                ],
              ),
              SizedBox(height: 12.h),
            ],
            // ── Nom + chip type ──────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (spot.photoUrl.isEmpty && spot.isGolden) ...[
                  Text('🐾', style: TextStyle(fontSize: 22.sp)),
                  SizedBox(width: 6.w),
                ],
                Expanded(
                  child: PoppinsText(
                    text: spot.name,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary(context),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: 8.w),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 120.w),
                  child: Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: typeTone.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10.r),
                      border:
                          Border.all(color: typeTone.withValues(alpha: 0.4)),
                    ),
                    child: InterText(
                      text: PawSpotTypes.label(spot.type),
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                      color: typeTone,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
            if (spot.communityValidated) ...[
              SizedBox(height: 8.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: _kGoldPaw.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(color: goldTone),
                ),
                child: InterText(
                  text: '🏆 ${'pawspot_validated_badge'.tr}',
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w800,
                  color: goldTone,
                  maxLines: 1,
                ),
              ),
            ],
            SizedBox(height: 6.h),
            InterText(
              text: 'pawspot_added_by'
                  .trParams({'name': spot.creatorName.isNotEmpty ? spot.creatorName : '—'}),
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary(context),
            ),
            SizedBox(height: 12.h),
            // ── Stats : ⭐ qualité / 🏆 validations / 👣 visites ──────────
            Row(
              children: [
                _statChip('⭐', spot.quality.toStringAsFixed(1),
                    'pawspot_quality'.tr),
                SizedBox(width: 8.w),
                _statChip('🏆', '$_validationsCount',
                    'pawspot_validations'.tr),
                SizedBox(width: 8.w),
                _statChip('👣', '${spot.visitsCount}', 'pawspot_visits'.tr),
              ],
            ),
            if (spot.description.isNotEmpty) ...[
              SizedBox(height: 12.h),
              InterText(
                text: spot.description,
                fontSize: 13.sp,
                color: AppColors.textPrimary(context),
              ),
            ],
            SizedBox(height: 14.h),
            // ── Actions : ❤️ like / 🏆 valider / itinéraire ──────────────
            // v567 — sur SON PROPRE spot, le serveur refuse le ❤️ comme la
            // validation (anti-triche : l'auteur comptait sinon dans les 10
            // likes qui déclenchaient SES propres +10 points). On affiche donc
            // le compteur de likes en lecture seule et « Ton spot » à la place
            // du bouton Valider, au lieu de boutons qui échouent en silence.
            // v573 — boutons du kit (`ActionPillButton`) : mêmes conditions
            // d'activation, mêmes actions, plus aucun Outlined/Elevated brut
            // ni `Colors.red` en dur.
            Row(
              children: [
                ActionPillButton(
                  label: '$_likesCount',
                  icon: _liked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  tone: AppColors.errorColor,
                  kind: _liked ? ActionPillKind.ghost : ActionPillKind.outlined,
                  compact: true,
                  busy: _likeBusy,
                  onPressed: _isCreator ? null : _toggleLike,
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: ActionPillButton(
                    label: _isCreator
                        ? pawSpotTr('pawspot567_my_spot', 'Your spot')
                        : _validated
                            ? 'pawspot_validated_badge'.tr
                            : 'pawspot_validate_btn'.tr,
                    icon: Icons.emoji_events_rounded,
                    tone: goldTone,
                    kind: ActionPillKind.outlined,
                    compact: true,
                    expand: true,
                    busy: _validateBusy,
                    onPressed: (_validateBusy || _isCreator || _validated)
                        ? null
                        : _validateSpot,
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: ActionPillButton(
                    label: 'pawspot_directions_btn'.tr,
                    icon: Icons.directions_rounded,
                    tone: violetTone,
                    compact: true,
                    expand: true,
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onDirections(spot);
                    },
                  ),
                ),
              ],
            ),
            // ── v532 — PARTAGE (auto-promotion) ──────────────────────────
            // Daniel : « améliore le partage de la carte entre amis sur
            // WhatsApp, Insta etc. pour faire de l'auto-pub ». Le lien pointe
            // vers /spot/<id>, une page rendue côté serveur : la conversation
            // affiche la photo du lieu, son nom et sa ville, puis propose de
            // télécharger l'app. Sans cette page, on partageait une URL nue.
            SizedBox(height: 10.h),
            ActionPillButton(
              label: 'pawspot_share'.tr,
              icon: Icons.ios_share_rounded,
              tone: typeTone,
              kind: ActionPillKind.outlined,
              compact: true,
              expand: true,
              onPressed: _shareSpot,
            ),
            // ── Boutons créateur : supprimer + mise en avant ─────────────
            if (_isCreator) ...[
              SizedBox(height: 10.h),
              Row(
                children: [
                  Expanded(
                    child: ActionPillButton(
                      label: 'pawspot_reward_feature'.tr,
                      icon: Icons.rocket_launch_rounded,
                      tone: goldTone,
                      kind: ActionPillKind.outlined,
                      compact: true,
                      expand: true,
                      onPressed: _featureSpot,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  // Bouton rond du kit : pas de libellé, donc jamais de
                  // débordement en allemand / polonais.
                  ActionRoundButton(
                    icon: Icons.delete_outline_rounded,
                    tone: AppColors.errorColor,
                    filled: false,
                    semanticLabel: 'common_delete'.tr,
                    onPressed: _confirmDelete,
                  ),
                ],
              ),
            ],
            SizedBox(height: 16.h),
            // ── Commentaires ─────────────────────────────────────────────
            PoppinsText(
              text: 'pawspot_comments_title'.tr,
              fontSize: 13.sp,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary(context),
            ),
            SizedBox(height: 8.h),
            if (_commentsLoading)
              // v573 — squelettes de lignes au lieu d'une roue centrée.
              const MapLineSkeletonList(count: 2)
            else if (_comments.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 10.h),
                child: InterText(
                  text: 'pawspot_comment_hint'.tr,
                  fontSize: 12.sp,
                  color: AppColors.textSecondary(context),
                ),
              )
            else
              ..._comments.take(5).map(
                    (c) => Padding(
                      padding: EdgeInsets.only(bottom: 8.h),
                      child: MapSheetCard(
                        radius: 14.r,
                        padding: EdgeInsets.symmetric(
                            horizontal: 10.w, vertical: 8.h),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('💬', style: TextStyle(fontSize: 13.sp)),
                            SizedBox(width: 8.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  InterText(
                                    text: (c['authorName'] ?? '—').toString(),
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textSecondary(context),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  SizedBox(height: 2.h),
                                  InterText(
                                    text: (c['text'] ?? '').toString(),
                                    fontSize: 12.sp,
                                    height: 1.4,
                                    color: AppColors.textPrimary(context),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
            SizedBox(height: 6.h),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentCtrl,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendComment(),
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: AppColors.textPrimary(context),
                    ),
                    decoration: mapFieldDecoration(
                      context,
                      hint: 'pawspot_comment_hint'.tr,
                      focusTint: _kOrange,
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                // Bouton rond du kit (envoi). Pendant l'envoi il est désactivé,
                // comme avant.
                ActionRoundButton(
                  icon: Icons.send_rounded,
                  tone: _kOrange,
                  semanticLabel: 'pawmap_btn_send'.tr,
                  onPressed: _sendingComment ? null : _sendComment,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// v23.1.356 — maquette Daniel : « Voir les spots ». Liste des PawSpots
/// chargés autour du centre courant, avec mes PawPoints en tête (relus à
/// chaque ouverture, pas de cache). Tap sur une ligne → le caller centre la
/// carte et ouvre la sheet détail.
Future<void> showPawSpotListSheet(
  BuildContext context, {
  required PawSpotController controller,
  required void Function(PawSpotModel spot) onOpenSpot,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.card(context),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    useSafeArea: true,
    builder: (ctx) {
      final spots = controller.spots.toList();
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w,
              16.h + appBottomInsetInsideSafeArea(ctx)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const MapSheetHandle(),
              MapSheetTitle(
                title: 'pawspot_list_title'.tr,
                emoji: '🐾',
                tint: _kGold,
              ),
              SizedBox(height: 10.h),
              // Mes PawPoints — relus à CHAQUE ouverture ("que ça
              // comptabilise les points", Daniel).
              FutureBuilder<Map<String, dynamic>?>(
                future: controller.myPoints(),
                builder: (c, snap) {
                  final pts = (snap.data?['points'] as num?)?.toInt();
                  final badge = snap.data?['badge'];
                  final badgeEmoji =
                      badge is Map ? (badge['emoji'] ?? '').toString() : '';
                  final Color gold = AppColors.accentOn(ctx, _kGold);
                  return Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                    decoration: BoxDecoration(
                      color: gold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(color: gold.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.emoji_events_rounded,
                            size: 16.sp, color: gold),
                        SizedBox(width: 6.w),
                        Flexible(
                          child: InterText(
                            text: 'pawmap_my_points_chip'
                                .trParams({'points': pts?.toString() ?? '…'}),
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary(ctx),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (badgeEmoji.isNotEmpty) ...[
                          SizedBox(width: 5.w),
                          Text(badgeEmoji, style: TextStyle(fontSize: 14.sp)),
                        ],
                      ],
                    ),
                  );
                },
              ),
              SizedBox(height: 12.h),
              if (spots.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 24.h),
                  child: MapEmptyBlock(
                    icon: Icons.place_outlined,
                    emoji: '🐾',
                    tint: _kGold,
                    compact: true,
                    title: 'pawspot_list_title'.tr,
                    message: 'pawspot_list_empty'.tr,
                  ),
                )
              else
                // v573 — cartes maison à la place des `ListTile` + `Divider` :
                // pastille couleur du type, nom, méta, chevron. Le tap fait
                // exactement la même chose qu'avant.
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.only(bottom: 4.h),
                    itemCount: spots.length,
                    separatorBuilder: (_, __) => SizedBox(height: 8.h),
                    itemBuilder: (c, i) {
                      final s = spots[i];
                      final Color color =
                          AppColors.accentOn(c, PawSpotTypes.color(s.type));
                      return MapSheetCard(
                        radius: 16.r,
                        padding: EdgeInsets.symmetric(
                            horizontal: 10.w, vertical: 10.h),
                        onTap: () {
                          Navigator.of(ctx).pop();
                          onOpenSpot(s);
                        },
                        child: Row(
                          children: [
                            Container(
                              width: 38.w,
                              height: 38.w,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: s.isGolden ? _kGoldPaw : color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: AppColors.card(c), width: 2),
                              ),
                              child: Text('🐾',
                                  style: TextStyle(fontSize: 16.sp)),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  InterText(
                                    text: s.name,
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary(c),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  SizedBox(height: 2.h),
                                  InterText(
                                    text:
                                        '${PawSpotTypes.label(s.type)}  ·  ❤️ ${s.likesCount}'
                                        '${s.isGolden ? '  ·  🐾✨' : ''}',
                                    fontSize: 12.sp,
                                    color: AppColors.textSecondary(c),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 6.w),
                            Icon(Icons.chevron_right_rounded,
                                size: 20.sp, color: AppColors.textTertiary(c)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

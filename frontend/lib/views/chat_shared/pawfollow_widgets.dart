// v566 — Daniel : « les boutons dans Messages "Suivre en direct" plus jolis, et
// vérifie que tout est bien traduit, branché, fonctionnel ».
//
//  • PawFollowPill : pilule violette PawFollow (#7C3AED, dégradé doux, icône
//    blanche, ombre colorée). Quand un suivi est EN COURS : point vert animé
//    et libellé « En direct · voir la carte ».
//  • showPawFollowRequestSheet : feuille de demande (carte contact, explication
//    courte, bouton principal, état d'envoi, erreurs lisibles avec bouton vers
//    la boutique quand PawFollow / une réservation est nécessaire).
//  • pawFollowIsLive : vrai si la conversation porte une demande ACCEPTÉE
//    encore valable.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/bottom_inset.dart';
import 'package:hopetsit/views/boost/coin_shop_screen.dart';
import 'package:hopetsit/views/chat_shared/chat_avatar.dart';
import 'package:hopetsit/views/chat_shared/chat_models.dart';
import 'package:hopetsit/widgets/app_text.dart';

/// Violet PawFollow (CLAUDE.md « Marque »).
const Color kPawFollowPurple = Color(0xFF7C3AED);
const Color kPawFollowPurpleSoft = Color(0xFF9B6BF5);
const Color kPawFollowPurpleDark = Color(0xFF6D28D9);
const Color kPawFollowLive = Color(0xFF22C55E);

const LinearGradient kPawFollowGradient = LinearGradient(
  colors: [kPawFollowPurpleSoft, kPawFollowPurple, kPawFollowPurpleDark],
  stops: [0.0, 0.55, 1.0],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

/// Dernière demande PawFollow ACCEPTÉE encore valable, ou null.
/// Valable = fin de garde dans le futur, ou (sans date de fin) acceptée il y a
/// moins de 12 h — une vieille carte ne doit pas afficher « En direct ».
ChatMessageBase? pawFollowLiveMessage(Iterable<ChatMessageBase> messages) {
  final now = DateTime.now();
  ChatMessageBase? found;
  for (final m in messages) {
    if (!m.isPawfollowRequest || m.isDeleted) continue;
    if (m.pawfollowStatus != 'accepted') continue;
    final end = m.pawfollowEndAt;
    final ok = end != null
        ? end.isAfter(now)
        : now.difference(m.timestamp).inHours < 12;
    if (ok) found = m;
  }
  return found;
}

bool pawFollowIsLive(Iterable<ChatMessageBase> messages) =>
    pawFollowLiveMessage(messages) != null;

/// Point vert qui pulse (suivi en cours).
class PawFollowLiveDot extends StatefulWidget {
  const PawFollowLiveDot({super.key, this.size = 8});
  final double size;

  @override
  State<PawFollowLiveDot> createState() => _PawFollowLiveDotState();
}

class _PawFollowLiveDotState extends State<PawFollowLiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return SizedBox(
      width: s * 2,
      height: s * 2,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          final t = Curves.easeInOut.transform(_c.value);
          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: s + s * t,
                height: s + s * t,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: kPawFollowLive.withValues(alpha: 0.35 * (1 - t)),
                ),
              ),
              child!,
            ],
          );
        },
        child: Container(
          width: s,
          height: s,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: kPawFollowLive,
            border: Border.all(color: Colors.white, width: 1.2),
          ),
        ),
      ),
    );
  }
}

/// Pilule violette PawFollow (en-tête de la discussion).
class PawFollowPill extends StatelessWidget {
  const PawFollowPill({
    super.key,
    required this.label,
    required this.onTap,
    this.icon = Icons.my_location_rounded,
    this.live = false,
    this.maxWidth,
  });

  /// Libellé hors suivi (« Suivre en direct mon animal », « Partager ma position »).
  final String label;
  final VoidCallback onTap;
  final IconData icon;

  /// true = suivi EN COURS → point vert + « En direct · voir la carte ».
  final bool live;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final text = live ? 'cs_pf_live_open'.tr : label;
    final radius = BorderRadius.circular(999);
    return Padding(
      padding: EdgeInsets.only(right: 4.w),
      child: Center(
        child: Semantics(
          button: true,
          label: text,
          child: Container(
            constraints: BoxConstraints(maxWidth: maxWidth ?? 168.w),
            decoration: BoxDecoration(
              gradient: kPawFollowGradient,
              borderRadius: radius,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.85),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: kPawFollowPurple.withValues(alpha: 0.38),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: radius,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onTap();
                },
                child: Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: 11.w, vertical: 7.h),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (live)
                        const PawFollowLiveDot(size: 7)
                      else
                        Icon(icon, size: 15.sp, color: Colors.white),
                      SizedBox(width: 5.w),
                      Flexible(
                        child: InterText(
                          text: text,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bouton principal violet (feuille de demande, carte « Suivi actif »).
class PawFollowPrimaryButton extends StatelessWidget {
  const PawFollowPrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon = Icons.my_location_rounded,
    this.busy = false,
    this.live = false,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData icon;
  final bool busy;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !busy;
    final radius = BorderRadius.circular(18.r);
    return Opacity(
      opacity: enabled || busy ? 1 : 0.55,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 52),
        decoration: BoxDecoration(
          gradient: kPawFollowGradient,
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: kPawFollowPurple.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled
                ? () {
                    HapticFeedback.lightImpact();
                    onTap!();
                  }
                : null,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (busy)
                    SizedBox(
                      width: 18.sp,
                      height: 18.sp,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  else if (live)
                    const PawFollowLiveDot(size: 8)
                  else
                    Icon(icon, color: Colors.white, size: 20.sp),
                  SizedBox(width: 9.w),
                  Flexible(
                    child: InterText(
                      text: label,
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
          ),
        ),
      ),
    );
  }
}

/// Erreur lisible d'une demande de suivi.
class _PfError {
  const _PfError(this.title, this.body, {this.shop = false});
  final String title;
  final String body;
  final bool shop;
}

_PfError _mapPawFollowError(Object e) {
  final raw = e.toString();
  final low = raw.toLowerCase();
  final status = e is ApiException ? e.statusCode : null;
  if (e is NetworkUnreachableException) {
    return _PfError('cs_pf_err_network_title'.tr, 'cs_send_failed_body'.tr);
  }
  if (raw.contains('TRACKING_ENDED') || low.contains('service is over')) {
    return _PfError(
      'tracking_service_over_title'.tr,
      'tracking_service_over_msg'.tr,
      shop: true,
    );
  }
  if (status == 402 ||
      low.contains('pawfollow_required') ||
      low.contains('subscription')) {
    return _PfError('cs_pf_err_sub_title'.tr, 'cs_pf_err_sub_body'.tr,
        shop: true);
  }
  if (status == 403 ||
      low.contains('not paid') ||
      low.contains('paid booking') ||
      low.contains('payment required')) {
    return _PfError('cs_pf_err_booking_title'.tr, 'cs_pf_err_booking_body'.tr,
        shop: true);
  }
  final detail = e is ApiException ? e.message : raw;
  return _PfError(
    'follow_unavailable_title'.tr,
    detail.length > 160 ? detail.substring(0, 160) : detail,
  );
}

/// Feuille de demande PawFollow. `onSend` LÈVE en cas d'échec (l'erreur est
/// affichée dans la feuille) ; renvoie true si la demande est partie.
Future<bool> showPawFollowRequestSheet(
  BuildContext context, {
  required String contactName,
  required String contactImage,
  required Future<void> Function() onSend,
  bool sharing = false,
  String petName = '',
}) async {
  final sent = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.card(context),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
    ),
    builder: (sheet) => _PawFollowRequestSheet(
      contactName: contactName,
      contactImage: contactImage,
      onSend: onSend,
      sharing: sharing,
      petName: petName,
    ),
  );
  return sent == true;
}

class _PawFollowRequestSheet extends StatefulWidget {
  const _PawFollowRequestSheet({
    required this.contactName,
    required this.contactImage,
    required this.onSend,
    required this.sharing,
    required this.petName,
  });

  final String contactName;
  final String contactImage;
  final Future<void> Function() onSend;
  final bool sharing;
  final String petName;

  @override
  State<_PawFollowRequestSheet> createState() => _PawFollowRequestSheetState();
}

class _PawFollowRequestSheetState extends State<_PawFollowRequestSheet> {
  bool _sending = false;
  bool _sent = false;
  _PfError? _error;

  Future<void> _send() async {
    if (_sending || _sent) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.onSend();
      if (!mounted) return;
      setState(() {
        _sending = false;
        _sent = true;
      });
      HapticFeedback.mediumImpact();
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = _mapPawFollowError(e);
      });
    }
  }

  Widget _step(BuildContext context, IconData icon, String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26.w,
            height: 26.w,
            decoration: BoxDecoration(
              color: kPawFollowPurple.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9.r),
            ),
            child: Icon(icon, size: 15.sp, color: kPawFollowPurple),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 3.h),
              child: InterText(
                text: text,
                fontSize: 12.5.sp,
                color: AppColors.textSecondary(context),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sharing = widget.sharing;
    final err = _error;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20.w,
        10.h,
        20.w,
        // v569 — clavier ouvert : son inset remplace celui de la barre
        // système ; sinon on ajoute le dégagement bas de l'app.
        18.h +
            (MediaQuery.of(context).viewInsets.bottom > 0
                ? MediaQuery.of(context).viewInsets.bottom
                : appBottomInset(context)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 42.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: AppColors.greyColor.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(4.r),
              ),
            ),
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Container(
                width: 40.w,
                height: 40.w,
                decoration: BoxDecoration(
                  gradient: kPawFollowGradient,
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: Icon(
                  sharing
                      ? Icons.share_location_rounded
                      : Icons.my_location_rounded,
                  color: Colors.white,
                  size: 21.sp,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: PoppinsText(
                  text: sharing
                      ? 'cs_pf_sheet_title_share'.tr
                      : 'cs_pf_sheet_title_follow'.tr,
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary(context),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          // Carte contact
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: kPawFollowPurple.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(18.r),
              border: Border.all(
                color: kPawFollowPurple.withValues(alpha: 0.18),
              ),
            ),
            child: Row(
              children: [
                ChatAvatar(imageUrl: widget.contactImage, size: 46),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PoppinsText(
                        text: widget.contactName,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      InterText(
                        text: widget.petName.isNotEmpty
                            ? 'cs_pf_sheet_with_pet'
                                .trParams({'pet': widget.petName})
                            : (sharing
                                ? 'cs_pf_sheet_contact_share'.tr
                                : 'cs_pf_sheet_contact_follow'.tr),
                        fontSize: 12.sp,
                        color: AppColors.textSecondary(context),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),
          _step(
            context,
            Icons.send_rounded,
            sharing ? 'cs_pf_step_share_1'.tr : 'cs_pf_step_follow_1'.tr,
          ),
          _step(context, Icons.verified_user_rounded, 'cs_pf_step_2'.tr),
          _step(context, Icons.map_rounded, 'cs_pf_step_3'.tr),
          if (err != null) ...[
            SizedBox(height: 6.h),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: AppColors.errorColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(
                  color: AppColors.errorColor.withValues(alpha: 0.25),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InterText(
                    text: err.title,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w800,
                    color: AppColors.errorColor,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 3.h),
                  InterText(
                    text: err.body,
                    fontSize: 12.sp,
                    color: AppColors.textPrimary(context),
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                    height: 1.35,
                  ),
                  if (err.shop) ...[
                    SizedBox(height: 8.h),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop(false);
                        Get.to(() => const CoinShopScreen(initialTab: 1));
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kPawFollowPurple,
                        side: const BorderSide(color: kPawFollowPurple),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14.r),
                        ),
                      ),
                      icon: Icon(Icons.storefront_rounded, size: 17.sp),
                      label: Text(
                        'cs_pf_go_shop'.tr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          SizedBox(height: 14.h),
          if (_sent)
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 14.w),
              decoration: BoxDecoration(
                color: kPawFollowLive.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18.r),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_rounded,
                      color: const Color(0xFF16A34A), size: 20.sp),
                  SizedBox(width: 8.w),
                  Flexible(
                    child: InterText(
                      text: 'cs_pf_sent'.tr,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF16A34A),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            )
          else
            PawFollowPrimaryButton(
              label: _sending
                  ? 'cs_pf_sending'.tr
                  : (err != null
                      ? 'chat_retry'.tr
                      : (sharing
                          ? 'cs_pf_cta_share'.tr
                          : 'cs_pf_cta_follow'.tr)),
              icon: sharing
                  ? Icons.share_location_rounded
                  : Icons.my_location_rounded,
              busy: _sending,
              onTap: _send,
            ),
          SizedBox(height: 6.h),
          Center(
            child: TextButton(
              onPressed:
                  _sending ? null : () => Navigator.of(context).pop(false),
              child: Text(
                'common_cancel'.tr,
                style: TextStyle(
                  color: AppColors.textSecondary(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// v565 (point 24 / contrat §7) — feuille « Animal récupéré » / « Animal rendu ».
//
// Remplace, pour le build 565, la feuille v532 `views/shared/handover_proof_sheet.dart`
// (conservée intacte : elle appartient à un autre lot). Différences :
//   • la PHOTO est FACULTATIVE dans les deux sens (Daniel, 14/09 : « photo
//     optionnelle, position GPS horodatée ») ;
//   • la POSITION GPS est capturée à l'ouverture (silencieuse, meilleure
//     précision possible en 8 s) et renvoyée avec la preuve (`lat`/`lng`) ;
//   • à la récupération, le CODE de remise dicté par le propriétaire reste
//     proposé : il faut au moins le code OU la photo OU la position pour valider.
//
// Renvoie `null` si l'utilisateur annule, sinon [HandoverActionResult].
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';

class HandoverActionResult {
  final File? photo;
  final String? code;
  final double? lat;
  final double? lng;
  const HandoverActionResult({this.photo, this.code, this.lat, this.lng});
}

/// Capture GPS « meilleur effort » : jamais d'exception, null si refusé,
/// désactivé ou trop long. Utilisée par la feuille et réutilisable par le
/// bandeau d'accueil.
Future<Position?> captureHandoverPosition({
  Duration timeout = const Duration(seconds: 8),
}) async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return null;
    }
    return await Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: timeout,
      ),
    );
  } catch (_) {
    try {
      return await Geolocator.getLastKnownPosition();
    } catch (_) {
      return null;
    }
  }
}

class HandoverActionSheet extends StatefulWidget {
  /// true = récupération (début), false = rendu (fin).
  final bool isPickup;
  final Color accent;
  const HandoverActionSheet({
    super.key,
    required this.isPickup,
    required this.accent,
  });

  static Future<HandoverActionResult?> show({
    required bool isPickup,
    Color accent = AppColors.primaryColor,
  }) {
    return Get.bottomSheet<HandoverActionResult>(
      HandoverActionSheet(isPickup: isPickup, accent: accent),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  @override
  State<HandoverActionSheet> createState() => _HandoverActionSheetState();
}

class _HandoverActionSheetState extends State<HandoverActionSheet> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _codeCtrl = TextEditingController();
  File? _photo;
  bool _picking = false;
  // GPS : null tant que la recherche tourne ; `_gpsDone` = recherche finie.
  Position? _pos;
  bool _gpsDone = false;

  @override
  void initState() {
    super.initState();
    captureHandoverPosition().then((p) {
      if (!mounted) return;
      setState(() {
        _pos = p;
        _gpsDone = true;
      });
    });
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final x = await _picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1600,
      );
      if (x != null && mounted) setState(() => _photo = File(x.path));
    } catch (_) {
      // Permission refusée / appareil indisponible : on peut valider sans.
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  bool get _canSubmit {
    if (widget.isPickup) {
      final code = _codeCtrl.text.trim();
      if (code.isNotEmpty && code.length != 4) return false;
      return code.length == 4 || _photo != null || _pos != null;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final accent = widget.accent;
    final sub = AppColors.textSecondary(context);
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        padding: EdgeInsets.fromLTRB(20.w, 10.h, 20.w, 16.h),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(2.r),
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
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Icon(
                        widget.isPickup
                            ? Icons.pets_rounded
                            : Icons.home_rounded,
                        color: accent,
                        size: 22.sp,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: PoppinsText(
                        text: widget.isPickup
                            ? 'v565_ho_btn_picked_up'.tr
                            : 'v565_ho_btn_returned'.tr,
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary(context),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                InterText(
                  text: widget.isPickup
                      ? 'v565_ho_sheet_pickup_desc'.tr
                      : 'v565_ho_sheet_return_desc'.tr,
                  fontSize: 13.sp,
                  color: sub,
                ),
                SizedBox(height: 14.h),

                // ── Position GPS ──────────────────────────────────────────
                _GpsChip(done: _gpsDone, pos: _pos, accent: accent),
                SizedBox(height: 14.h),

                // ── Photo (facultative) ───────────────────────────────────
                InterText(
                  text: 'v565_ho_photo_optional'.tr,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary(context),
                ),
                SizedBox(height: 8.h),
                GestureDetector(
                  onTap: _picking ? null : () => _pick(ImageSource.camera),
                  child: Container(
                    height: 130.h,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(
                        color: _photo != null
                            ? accent
                            : Colors.grey.withValues(alpha: 0.30),
                        width: 1.2,
                      ),
                      image: _photo != null
                          ? DecorationImage(
                              image: FileImage(_photo!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: _photo != null
                        ? null
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.photo_camera_rounded,
                                  size: 30.sp, color: accent),
                              SizedBox(height: 6.h),
                              InterText(
                                text: 'handover_take_photo'.tr,
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary(context),
                              ),
                            ],
                          ),
                  ),
                ),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed:
                          _picking ? null : () => _pick(ImageSource.gallery),
                      icon: Icon(Icons.image_outlined, size: 18.sp),
                      label: InterText(
                        text: 'handover_from_gallery'.tr,
                        fontSize: 12.sp,
                      ),
                    ),
                    if (_photo != null)
                      TextButton.icon(
                        onPressed: () => setState(() => _photo = null),
                        icon: Icon(Icons.close_rounded, size: 18.sp),
                        label: InterText(
                          text: 'handover_remove_photo'.tr,
                          fontSize: 12.sp,
                        ),
                      ),
                  ],
                ),

                // ── Code de remise (récupération) ─────────────────────────
                if (widget.isPickup) ...[
                  SizedBox(height: 6.h),
                  InterText(
                    text: 'handover_code_label'.tr,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary(context),
                  ),
                  SizedBox(height: 8.h),
                  TextField(
                    controller: _codeCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24.sp,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 10,
                      color: AppColors.textPrimary(context),
                    ),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: '––––',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                    ),
                  ),
                  SizedBox(height: 4.h),
                  InterText(
                    text: 'handover_code_hint'.tr,
                    fontSize: 11.sp,
                    color: sub,
                  ),
                ],

                SizedBox(height: 18.h),
                SizedBox(
                  width: double.infinity,
                  height: 52.h,
                  child: ElevatedButton(
                    onPressed: _canSubmit
                        ? () => Get.back(
                              result: HandoverActionResult(
                                photo: _photo,
                                code: widget.isPickup &&
                                        _codeCtrl.text.trim().length == 4
                                    ? _codeCtrl.text.trim()
                                    : null,
                                lat: _pos?.latitude,
                                lng: _pos?.longitude,
                              ),
                            )
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      disabledBackgroundColor: accent.withValues(alpha: 0.35),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                    ),
                    child: PoppinsText(
                      text: widget.isPickup
                          ? 'handover_confirm_pickup'.tr
                          : 'handover_confirm_return'.tr,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                SizedBox(height: 4.h),
                Center(
                  child: TextButton(
                    onPressed: () => Get.back(),
                    child: InterText(
                      text: 'common_cancel'.tr,
                      fontSize: 13.sp,
                      color: sub,
                    ),
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

class _GpsChip extends StatelessWidget {
  final bool done;
  final Position? pos;
  final Color accent;
  const _GpsChip({required this.done, required this.pos, required this.accent});

  @override
  Widget build(BuildContext context) {
    final ok = pos != null;
    final label = !done
        ? 'v565_ho_gps_pending'.tr
        : ok
            ? 'v565_ho_gps_captured'.tr
            : 'v565_ho_gps_none'.tr;
    final color = !done
        ? AppColors.textSecondary(context)
        : ok
            ? const Color(0xFF16A34A)
            : const Color(0xFFE8920A);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        children: [
          if (!done)
            SizedBox(
              width: 14.w,
              height: 14.w,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            )
          else
            Icon(
              ok ? Icons.gps_fixed_rounded : Icons.gps_off_rounded,
              size: 16.sp,
              color: color,
            ),
          SizedBox(width: 8.w),
          Expanded(
            child: InterText(
              text: label,
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: color,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';

/// v532 — feuille de PREUVE DE REMISE de l'animal.
///
/// Daniel : « améliore le système de vérification quand je laisse mon chien et
/// quand je le récupère ». Avant, « J'ai récupéré l'animal » et « J'ai rendu
/// l'animal » étaient deux simples boutons : le prestataire pouvait les
/// enchaîner depuis son canapé, et le propriétaire n'avait AUCUNE trace de ce
/// qui s'était réellement passé.
///
/// Cette feuille recueille les deux preuves :
///   • une PHOTO de l'animal prise sur place (appareil photo par défaut) ;
///   • à la récupération uniquement, le CODE à 4 chiffres que le propriétaire
///     lit dans sa propre app et dicte au prestataire — c'est lui qui atteste
///     la rencontre physique.
///
/// Renvoie `null` si l'utilisateur annule, sinon la preuve saisie.
class HandoverProofResult {
  final File? photo;
  final String? code;
  const HandoverProofResult({this.photo, this.code});
}

class HandoverProofSheet extends StatefulWidget {
  /// true = récupération de l'animal (début de garde, code demandé),
  /// false = restitution (fin de garde, photo seule).
  final bool isPickup;
  const HandoverProofSheet({super.key, required this.isPickup});

  /// Ouvre la feuille et retourne la preuve, ou `null` si annulé.
  static Future<HandoverProofResult?> show({required bool isPickup}) {
    return Get.bottomSheet<HandoverProofResult>(
      HandoverProofSheet(isPickup: isPickup),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  @override
  State<HandoverProofSheet> createState() => _HandoverProofSheetState();
}

class _HandoverProofSheetState extends State<HandoverProofSheet> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _codeCtrl = TextEditingController();
  File? _photo;
  bool _picking = false;

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
        // Compression : la preuve n'a pas besoin d'être en pleine résolution,
        // et la remise se fait souvent en 4G.
        imageQuality: 70,
        maxWidth: 1600,
      );
      if (x != null && mounted) setState(() => _photo = File(x.path));
    } catch (_) {
      // Permission refusée / appareil indisponible : on laisse l'utilisateur
      // réessayer ou valider sans photo.
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  bool get _canSubmit {
    if (widget.isPickup) {
      // À la récupération, on veut au moins l'une des deux preuves.
      return _photo != null || _codeCtrl.text.trim().length == 4;
    }
    return _photo != null;
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22.r)),
        ),
        padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 20.h),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              PoppinsText(
                text: widget.isPickup
                    ? 'handover_pickup_title'.tr
                    : 'handover_return_title'.tr,
                fontSize: 18.sp,
                fontWeight: FontWeight.w700,
              ),
              SizedBox(height: 6.h),
              InterText(
                text: widget.isPickup
                    ? 'handover_pickup_desc'.tr
                    : 'handover_return_desc'.tr,
                fontSize: 13.sp,
                color: Colors.grey,
              ),
              SizedBox(height: 16.h),

              // ── Photo ────────────────────────────────────────────────────
              GestureDetector(
                onTap: _picking ? null : () => _pick(ImageSource.camera),
                child: Container(
                  height: 150.h,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14.r),
                    border: Border.all(
                      color: _photo != null
                          ? AppColors.primaryColor
                          : Colors.grey.withValues(alpha: 0.35),
                      width: 1.4,
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
                                size: 34.sp, color: AppColors.primaryColor),
                            SizedBox(height: 8.h),
                            InterText(
                              text: 'handover_take_photo'.tr,
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ],
                        ),
                ),
              ),
              SizedBox(height: 8.h),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: _picking ? null : () => _pick(ImageSource.gallery),
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

              // ── Code à 4 chiffres (récupération seulement) ───────────────
              if (widget.isPickup) ...[
                SizedBox(height: 8.h),
                InterText(
                  text: 'handover_code_label'.tr,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
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
                  ),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '––––',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                ),
                SizedBox(height: 4.h),
                InterText(
                  text: 'handover_code_hint'.tr,
                  fontSize: 11.sp,
                  color: Colors.grey,
                ),
              ],

              SizedBox(height: 18.h),
              SizedBox(
                width: double.infinity,
                height: 50.h,
                child: ElevatedButton(
                  onPressed: _canSubmit
                      ? () => Get.back(
                            result: HandoverProofResult(
                              photo: _photo,
                              code: widget.isPickup
                                  ? _codeCtrl.text.trim()
                                  : null,
                            ),
                          )
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                  ),
                  child: PoppinsText(
                    text: widget.isPickup
                        ? 'handover_confirm_pickup'.tr
                        : 'handover_confirm_return'.tr,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              SizedBox(height: 6.h),
              Center(
                child: TextButton(
                  onPressed: () => Get.back(),
                  child: InterText(
                    text: 'common_cancel'.tr,
                    fontSize: 13.sp,
                    color: Colors.grey,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

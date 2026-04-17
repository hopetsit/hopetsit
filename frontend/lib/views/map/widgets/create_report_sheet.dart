import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hopetsit/controllers/map_report_controller.dart';
import 'package:hopetsit/models/map_report_model.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';

/// Bottom sheet used by PawMap "Signaler" FAB — Premium users pick a report
/// type, add an optional note, and drop the report at [initialPoint] (the
/// current map center). The sheet is stateful so the pick+note can update
/// without rebuilding the whole map.
class CreateReportSheet extends StatefulWidget {
  const CreateReportSheet({
    super.key,
    required this.initialPoint,
    this.city,
  });

  final LatLng initialPoint;
  final String? city;

  /// Convenience: opens the sheet and returns true if a report was created.
  static Future<bool> show(
    BuildContext context, {
    required LatLng initialPoint,
    String? city,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateReportSheet(initialPoint: initialPoint, city: city),
    );
    return result ?? false;
  }

  @override
  State<CreateReportSheet> createState() => _CreateReportSheetState();
}

class _CreateReportSheetState extends State<CreateReportSheet> {
  final _noteController = TextEditingController();
  String? _selectedType;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedType == null) {
      CustomSnackbar.showError(
        title: 'Type requis',
        message: 'Choisis un type de signalement avant d\'envoyer.',
      );
      return;
    }
    final controller = Get.isRegistered<MapReportController>()
        ? Get.find<MapReportController>()
        : Get.put(MapReportController());

    final report = await controller.createReport(
      type: _selectedType!,
      point: widget.initialPoint,
      note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      city: widget.city,
    );

    if (!mounted) return;
    if (report != null) {
      CustomSnackbar.showSuccess(
        title: 'Signalement envoyé',
        message: 'Visible 48h autour de vous. Merci !',
      );
      Navigator.of(context).pop(true);
    } else if (controller.premiumRequired.value) {
      Navigator.of(context).pop(false);
    } else {
      CustomSnackbar.showError(
        title: 'Envoi impossible',
        message: 'Réessaie dans un instant.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 24.h),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Grabber
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: AppColors.divider(context),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              SizedBox(height: 14.h),

              // Title
              Row(
                children: [
                  Text('📣', style: TextStyle(fontSize: 22.sp)),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: PoppinsText(
                      text: 'Signaler autour de moi',
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4.h),
              InterText(
                text: 'Visible 48h par les utilisateurs Premium à proximité.',
                fontSize: 12.sp,
                color: AppColors.textSecondary(context),
              ),
              SizedBox(height: 16.h),

              // Type grid
              Wrap(
                spacing: 8.w,
                runSpacing: 8.h,
                children: ReportTypes.all.map((t) {
                  final selected = _selectedType == t;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedType = t),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primaryColor
                            : AppColors.card(context),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(
                          color: selected
                              ? AppColors.primaryColor
                              : AppColors.divider(context),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            ReportTypes.emoji(t),
                            style: TextStyle(fontSize: 16.sp),
                          ),
                          SizedBox(width: 6.w),
                          InterText(
                            text: ReportTypes.labelFr(t),
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: selected
                                ? Colors.white
                                : AppColors.textPrimary(context),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),

              // Selected hint
              if (_selectedType != null) ...[
                SizedBox(height: 12.h),
                Container(
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16.sp, color: AppColors.primaryColor),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: InterText(
                          text: ReportTypes.hintFr(_selectedType!),
                          fontSize: 12.sp,
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              SizedBox(height: 16.h),

              // Note field
              InterText(
                text: 'Note (optionnel)',
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary(context),
              ),
              SizedBox(height: 6.h),
              TextField(
                controller: _noteController,
                maxLines: 3,
                maxLength: 500,
                decoration: InputDecoration(
                  hintText: 'Un détail utile pour les autres propriétaires…',
                  filled: true,
                  fillColor: AppColors.scaffold(context),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: BorderSide(color: AppColors.divider(context)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: BorderSide(color: AppColors.primaryColor, width: 1.5),
                  ),
                ),
              ),

              SizedBox(height: 12.h),

              // Location indicator
              Row(
                children: [
                  Icon(Icons.place, size: 16.sp, color: AppColors.primaryColor),
                  SizedBox(width: 6.w),
                  Expanded(
                    child: InterText(
                      text: 'Position: ${widget.initialPoint.latitude.toStringAsFixed(5)}, ${widget.initialPoint.longitude.toStringAsFixed(5)}',
                      fontSize: 11.sp,
                      color: AppColors.greyText,
                    ),
                  ),
                ],
              ),

              SizedBox(height: 16.h),

              // Submit button
              Obx(() {
                final controller = Get.isRegistered<MapReportController>()
                    ? Get.find<MapReportController>()
                    : null;
                final submitting = controller?.isSubmitting.value ?? false;
                return SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: submitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                    ),
                    icon: submitting
                        ? SizedBox(
                            width: 16.w,
                            height: 16.w,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded, color: Colors.white),
                    label: InterText(
                      text: submitting ? 'Envoi…' : 'Publier le signalement',
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

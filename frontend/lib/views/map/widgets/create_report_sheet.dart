import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hopetsit/controllers/map_report_controller.dart';
import 'package:hopetsit/controllers/subscription_controller.dart';
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
    this.preselectedType,
  });

  final LatLng initialPoint;
  final String? city;

  /// Optional type pre-selected when the sheet opens — used by the "Quick
  /// signal" chips on the PawMap (Perdu / Trouvé / Point d'eau) so the user
  /// lands directly on the right category without having to tap again.
  final String? preselectedType;

  /// Convenience: opens the sheet and returns true if a report was created.
  static Future<bool> show(
    BuildContext context, {
    required LatLng initialPoint,
    String? city,
    String? preselectedType,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateReportSheet(
        initialPoint: initialPoint,
        city: city,
        preselectedType: preselectedType,
      ),
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
  void initState() {
    super.initState();
    _selectedType = widget.preselectedType;
  }

  /// Reads the current Premium status from the SubscriptionController. Returns
  /// false when the controller isn't registered yet (fresh install / before
  /// first status refresh), which is the safer default.
  bool get _isPremium {
    final c = Get.isRegistered<SubscriptionController>()
        ? Get.find<SubscriptionController>()
        : null;
    return c?.isPremium ?? false;
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _showPremiumLockedSnack() {
    CustomSnackbar.showError(
      title: 'Premium requis',
      message:
          'Ce type de signalement est réservé aux membres Premium. Passe Premium pour débloquer tous les types.',
    );
  }

  Future<void> _submit() async {
    if (_selectedType == null) {
      CustomSnackbar.showError(
        title: 'Type requis',
        message: 'Choisis un type de signalement avant d\'envoyer.',
      );
      return;
    }
    // Client-side guard — the backend will also reject with 402, but catching
    // it here gives a clearer message and avoids a round-trip.
    if (!ReportTypes.isFree(_selectedType!) && !_isPremium) {
      _showPremiumLockedSnack();
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
    // `viewPadding.bottom` is the system navigation bar / gesture area —
    // add it to our bottom padding so the Publier button is never hidden
    // underneath Android's 3-button nav bar.
    final safeBottom = MediaQuery.of(context).viewPadding.bottom;
    // Session v15-4 — refonte compacte pour tenir sur 1 écran :
    //   • section "Gratuits" en tête avec les 4 types libres
    //   • section "Premium" en grille 3 colonnes pour les 15 Premium
    //   • description corrigée (4 types gratuits, pas 3)
    //   • paddings réduits + note sur 2 lignes
    final freeTypes = ReportTypes.freeTypes;
    final premiumTypes =
        ReportTypes.all.where((t) => !ReportTypes.isFree(t)).toList();

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 16.h + safeBottom),
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
              SizedBox(height: 10.h),

              // Title + subtitle compact
              Row(
                children: [
                  Text('📣', style: TextStyle(fontSize: 20.sp)),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: PoppinsText(
                      text: 'Signaler autour de moi',
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 2.h),
              InterText(
                text: _isPremium
                    ? 'Visible 48h par les utilisateurs à proximité.'
                    : '${freeTypes.length} types gratuits. Les autres réservés Premium.',
                fontSize: 11.sp,
                color: AppColors.textSecondary(context),
              ),
              SizedBox(height: 12.h),

              // Section 1 — Gratuits (fond vert pâle, toujours cliquables)
              _buildFreeSection(context, freeTypes),
              SizedBox(height: 10.h),

              // Section 2 — Premium (grille 3 colonnes, cadenassée pour
              // les non-Premium)
              _buildPremiumSection(context, premiumTypes),

              // Hint sous la sélection — compact, disparaît par défaut.
              if (_selectedType != null) ...[
                SizedBox(height: 8.h),
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: 10.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color:
                        AppColors.primaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 14.sp,
                          color: AppColors.primaryColor),
                      SizedBox(width: 6.w),
                      Expanded(
                        child: InterText(
                          text: ReportTypes.hintFr(_selectedType!),
                          fontSize: 11.sp,
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              SizedBox(height: 10.h),

              // Note field — 2 lignes par défaut, maxLength retiré du
              // bas visuel pour gagner de la place.
              InterText(
                text: 'Note (optionnel)',
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary(context),
              ),
              SizedBox(height: 4.h),
              TextField(
                controller: _noteController,
                maxLines: 2,
                maxLength: 500,
                style: TextStyle(fontSize: 13.sp),
                decoration: InputDecoration(
                  hintText: 'Un détail utile pour les autres…',
                  hintStyle: TextStyle(fontSize: 12.sp),
                  filled: true,
                  fillColor: AppColors.scaffold(context),
                  counterText: '',
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: 10.w, vertical: 10.h),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.r),
                    borderSide: BorderSide(
                        color: AppColors.divider(context)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.r),
                    borderSide: BorderSide(
                        color: AppColors.primaryColor, width: 1.5),
                  ),
                ),
              ),

              SizedBox(height: 6.h),

              // Location indicator compact
              Row(
                children: [
                  Icon(Icons.place,
                      size: 13.sp, color: AppColors.primaryColor),
                  SizedBox(width: 4.w),
                  Expanded(
                    child: InterText(
                      text:
                          '${widget.initialPoint.latitude.toStringAsFixed(5)}, ${widget.initialPoint.longitude.toStringAsFixed(5)}',
                      fontSize: 10.sp,
                      color: AppColors.greyText,
                    ),
                  ),
                ],
              ),

              SizedBox(height: 10.h),

              // Submit button — padding réduit pour économiser du vertical
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
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                    ),
                    icon: submitting
                        ? SizedBox(
                            width: 14.w,
                            height: 14.w,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(Icons.send_rounded,
                            size: 16.sp, color: Colors.white),
                    label: InterText(
                      text: submitting ? 'Envoi…' : 'Publier le signalement',
                      fontSize: 13.sp,
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

  /// Section "Gratuits" — petit header + Wrap des types free.
  /// Fond vert pâle pour signaler visuellement que le groupe entier est
  /// accessible sans Premium (plus besoin du badge "GRATUIT" par chip).
  Widget _buildFreeSection(BuildContext context, List<String> types) {
    return Container(
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: AppColors.greenColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
            color: AppColors.greenColor.withValues(alpha: 0.25), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_rounded,
                  size: 14.sp, color: AppColors.greenColor),
              SizedBox(width: 4.w),
              InterText(
                text: 'Gratuits',
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.greenColor,
              ),
              SizedBox(width: 6.w),
              InterText(
                text: '· accessible à tous',
                fontSize: 10.sp,
                color: AppColors.textSecondary(context),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Wrap(
            spacing: 6.w,
            runSpacing: 6.h,
            children: types.map((t) => _buildTypeChip(
                  context,
                  type: t,
                  locked: false,
                  isFreeBadge: false, // le container entier sert de badge
                )).toList(),
          ),
        ],
      ),
    );
  }

  /// Section "Premium" — grille 3 colonnes, cadenassée pour les non-Premium.
  /// GridView préfère des cellules uniformes → on obtient une lecture plus
  /// régulière que le Wrap d'avant qui faisait des largeurs variables.
  Widget _buildPremiumSection(
      BuildContext context, List<String> types) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              _isPremium ? Icons.star_rounded : Icons.lock_rounded,
              size: 14.sp,
              color: _isPremium
                  ? const Color(0xFFFF9500)
                  : AppColors.textSecondary(context),
            ),
            SizedBox(width: 4.w),
            InterText(
              text: 'Premium',
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary(context),
            ),
            SizedBox(width: 6.w),
            InterText(
              text: _isPremium
                  ? '· ${types.length} types débloqués'
                  : '· ${types.length} types réservés',
              fontSize: 10.sp,
              color: AppColors.textSecondary(context),
            ),
          ],
        ),
        SizedBox(height: 6.h),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 6.h,
          crossAxisSpacing: 6.w,
          childAspectRatio: 2.4,
          children: types
              .map((t) => _buildTypeChip(
                    context,
                    type: t,
                    locked: !_isPremium,
                    isFreeBadge: false,
                    compact: true,
                  ))
              .toList(),
        ),
      ],
    );
  }

  /// Chip unifié utilisé par les deux sections. [compact] resserre le
  /// padding et masque le label au-delà de 1 ligne (cellules de grille).
  Widget _buildTypeChip(
    BuildContext context, {
    required String type,
    required bool locked,
    required bool isFreeBadge,
    bool compact = false,
  }) {
    final selected = _selectedType == type;
    final bg = selected
        ? AppColors.primaryColor
        : (locked
            ? AppColors.scaffold(context)
            : AppColors.card(context));
    final borderColor = selected
        ? AppColors.primaryColor
        : (locked
            ? AppColors.divider(context).withValues(alpha: 0.6)
            : AppColors.divider(context));
    final textColor = selected
        ? Colors.white
        : (locked
            ? AppColors.textSecondary(context)
            : AppColors.textPrimary(context));

    return GestureDetector(
      onTap: () {
        if (locked) {
          _showPremiumLockedSnack();
          return;
        }
        setState(() => _selectedType = type);
      },
      child: Opacity(
        opacity: locked ? 0.72 : 1.0,
        child: Container(
          padding: EdgeInsets.symmetric(
              horizontal: compact ? 6.w : 10.w,
              vertical: compact ? 6.h : 8.h),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10.r),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                ReportTypes.emoji(type),
                style: TextStyle(fontSize: compact ? 13.sp : 15.sp),
              ),
              SizedBox(width: 4.w),
              Flexible(
                child: InterText(
                  text: ReportTypes.labelFr(type),
                  fontSize: compact ? 10.sp : 11.sp,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                  maxLines: 1,
                ),
              ),
              if (locked) ...[
                SizedBox(width: 3.w),
                Icon(
                  Icons.lock_rounded,
                  size: 10.sp,
                  color: AppColors.textSecondary(context),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

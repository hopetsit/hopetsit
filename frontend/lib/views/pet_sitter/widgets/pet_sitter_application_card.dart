import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/app_images.dart';
import 'package:hopetsit/widgets/app_text.dart';

class PetSitterApplication {
  final String id;
  final String petName;
  final String petType;
  final String petImage;
  final String weight;
  final String height;
  final String color;
  final String date;
  final String time;
  final String phoneNumber;
  final String email;
  final String location;
  final String status; // 'pending', 'accepted', 'rejected'
  final String paymentStatus; // 'pending', 'paid', 'failed'
  final String ownerId; // Owner ID for starting chat
  // v18.5 — #20 : exposer le prix TTC + la part nette (80%) au provider
  // AVANT qu'il accepte, pour qu'il sache ce qu'il va toucher.
  final double? totalPrice;
  final double? netPayout;
  final String? currency;
  // v18.5 — #20 : rôle du provider pour colorer l'écran (walker=vert,
  // sitter=bleu). Derivé du serviceType du booking côté caller.
  final String providerRole;

  PetSitterApplication({
    required this.id,
    required this.petName,
    required this.petType,
    required this.petImage,
    required this.weight,
    required this.height,
    required this.color,
    required this.date,
    required this.time,
    required this.phoneNumber,
    required this.email,
    required this.location,
    required this.ownerId,
    this.status = 'pending',
    this.paymentStatus = 'pending',
    this.totalPrice,
    this.netPayout,
    this.currency,
    this.providerRole = 'sitter',
  });
}

class PetSitterApplicationCard extends StatefulWidget {
  final PetSitterApplication application;
  final Future<void> Function()? onAccept;
  final VoidCallback? onReject;
  final VoidCallback? onStartChat;

  const PetSitterApplicationCard({
    super.key,
    required this.application,
    this.onAccept,
    this.onReject,
    this.onStartChat,
  });

  @override
  State<PetSitterApplicationCard> createState() =>
      _PetSitterApplicationCardState();
}

class _PetSitterApplicationCardState extends State<PetSitterApplicationCard> {
  bool _isAccepting = false;
  bool _isRejecting = false;

  PetSitterApplication get application => widget.application;

  // v18.5 — #20 : couleur du rôle pour cet écran.
  Color get _roleAccent => application.providerRole == 'walker'
      ? const Color(0xFF16A34A)
      : const Color(0xFF2563EB);

  @override
  Widget build(BuildContext context) {
    final onStartChat = widget.onStartChat;
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.fromLTRB(20.w, 20.w, 0, 20.w),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(17.r),
        boxShadow: AppColors.cardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pet Profile Section
          _buildPetProfileSection(),

          SizedBox(height: 10.h),

          // Details Section
          _buildDetailsSection(),

          // v18.5 — #20 : carte prix mise en avant — le provider voit
          // combien l'owner paie ET combien il touchera net avant d'accepter.
          if (application.totalPrice != null && application.totalPrice! > 0)
            Padding(
              padding: EdgeInsets.only(top: 14.h, right: 16.w),
              child: _buildPriceBreakdownCard(),
            ),

          SizedBox(height: 20.h),

          // Start Chat Button
          if (onStartChat != null)
            Padding(
              padding: EdgeInsets.only(bottom: 12.h, right: 16.w),
              child: GestureDetector(
                onTap: onStartChat,
                child: Center(
                  child: Container(
                    width: Get.size.width / 2,
                    height: 48.h,
                    decoration: BoxDecoration(
                      color: AppColors.primaryColor,
                      borderRadius: BorderRadius.circular(24.r),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_outlined,
                          color: AppColors.whiteColor,
                          size: 20.sp,
                        ),
                        SizedBox(width: 8.w),
                        InterText(
                          text: 'sitter_chat_with_owner'.tr,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                          color: AppColors.whiteColor,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Action Buttons
          if (application.status == 'pending') _buildActionButtons(context),
          SizedBox(height: 10.h),
          Padding(
            padding: EdgeInsets.only(right: 16.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (application.status != 'paid')
                  Flexible(child: _buildStatusChip(application.status)),
                // else
                //   Container(),

                // if (application.paymentStatus == 'paid')
                Flexible(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: _buildPaymentStatusChip(application.paymentStatus),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPetProfileSection() {
    return Row(
      children: [
        // Pet Profile Picture and Name
        // Column(
        //   crossAxisAlignment: CrossAxisAlignment.center,
        //   children: [
        //     CircleAvatar(
        //       radius: 45.r,
        //       backgroundColor: AppColors.greyColor.withValues(alpha: 0.3),
        //       backgroundImage:
        //           application.petImage.isNotEmpty &&
        //               (application.petImage.startsWith('http://') ||
        //                   application.petImage.startsWith('https://'))
        //           ? CachedNetworkImageProvider(application.petImage)
        //           : null,
        //       child:
        //           application.petImage.isEmpty ||
        //               (!application.petImage.startsWith('http://') &&
        //                   !application.petImage.startsWith('https://'))
        //           ? Icon(Icons.person, size: 40.sp, color: AppColors.greyColor)
        //           : null,
        //     ),
        //   ],
        // ),
        // SizedBox(width: 12.w),

        // Attribute Boxes
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildAttributeBox(
                  'sitter_pet_weight'.tr,
                  application.weight,
                  _roleAccent,
                ),
                SizedBox(width: 8.w),
                _buildAttributeBox(
                  'sitter_pet_height'.tr,
                  application.height,
                  _roleAccent,
                ),
                SizedBox(width: 8.w),
                _buildAttributeBox(
                  'sitter_pet_color'.tr,
                  application.color,
                  _roleAccent,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// v18.5 — #20 : petite carte qui affiche le prix payé par l'owner
  /// et la part nette (80%) que le provider touchera. Colorée selon le
  /// rôle. Affichée SEULEMENT si totalPrice > 0.
  Widget _buildPriceBreakdownCard() {
    final currency = application.currency ?? 'EUR';
    final total = application.totalPrice ?? 0;
    final net = application.netPayout ?? (total * 0.8);
    final currencySymbol = currency.toUpperCase() == 'EUR'
        ? '€'
        : currency.toUpperCase() == 'GBP'
            ? '£'
            : currency.toUpperCase() == 'USD'
                ? '\$'
                : '';
    String fmt(double v) {
      final s = v.toStringAsFixed(2);
      return '$currencySymbol$s';
    }

    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: _roleAccent.withValues(alpha: 0.08),
        border: Border.all(color: _roleAccent.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Row(
        children: [
          Icon(
            Icons.euro_rounded,
            color: _roleAccent,
            size: 22.sp,
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InterText(
                  text: 'application_card_price_label'.tr,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary(context),
                ),
                SizedBox(height: 2.h),
                PoppinsText(
                  text: 'application_card_you_receive'.trParams({
                    'amount': fmt(net),
                  }),
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                  color: _roleAccent,
                ),
                SizedBox(height: 2.h),
                InterText(
                  text: 'application_card_owner_pays'.trParams({
                    'amount': fmt(total),
                  }),
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttributeBox(String title, String value, Color valueColor) {
    // v18.6 — boîtes agrandies pour éviter "Pas encore d..." tronqué.
    // Largeur 92.w (au lieu de 78), hauteur auto, padding plus généreux,
    // et texte clean avec fallback "—" quand vide.
    final displayValue = value.isEmpty || value.trim().toLowerCase() == 'pas encore défini'
        ? 'application_card_color_unknown'.tr
        : value;
    return Container(
      constraints: BoxConstraints(minHeight: 76.h, minWidth: 92.w),
      padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 8.w),
      decoration: BoxDecoration(
        color: AppColors.detailBoxColor,
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          PoppinsText(
            text: title,
            fontSize: 10.sp,
            fontWeight: FontWeight.w400,
            color: AppColors.textSecondary(context),
          ),
          SizedBox(height: 4.h),
          PoppinsText(
            text: displayValue,
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            color: valueColor,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PoppinsText(
          text: application.petName,
          fontSize: 16.sp,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary(context),
        ),
        SizedBox(height: 12.h),
        _buildDetailRow(
          AppImages.calendarIcon,
          'sitter_detail_date'.tr,
          application.date,
        ),
        SizedBox(height: 12.h),
        _buildDetailRow(
          AppImages.timeIcon,
          'sitter_detail_time'.tr,
          application.time,
        ),
        SizedBox(height: 12.h),
        _buildDetailRow(
          AppImages.callIcon,
          'sitter_detail_phone'.tr,
          application.phoneNumber,
        ),
        SizedBox(height: 12.h),
        // v16.3i — email row removed per user request (no need to expose
        // emails on the acceptance / reservation card, phone is enough).
        _buildDetailRow(
          AppImages.locationIcon,
          'sitter_detail_location'.tr,
          application.location,
        ),
      ],
    );
  }

  Widget _buildDetailRow(String iconPath, String label, String value) {
    final displayValue = value.isEmpty ? 'sitter_not_available_yet'.tr : value;
    return Row(
      children: [
        Image.asset(
          iconPath,
          width: 25.w,
          height: 25.h,
          color: AppColors.primaryColor,
        ),
        SizedBox(width: 5.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InterText(
                text: displayValue,
                fontSize: 13.sp,
                fontWeight: FontWeight.w400,
                color: value.isEmpty ? AppColors.textSecondary(context) : AppColors.textSecondary(context),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    final showReject = widget.application.status == 'pending';
    return Row(
      children: [
        if (showReject) ...[
          Expanded(
            child: GestureDetector(
              onTap: _isRejecting || _isAccepting || widget.onReject == null
                  ? null
                  : () async {
                      setState(() => _isRejecting = true);
                      try {
                        widget.onReject!();
                      } finally {
                        if (mounted) setState(() => _isRejecting = false);
                      }
                    },
              child: Container(
                height: 48.h,
                decoration: BoxDecoration(
                  color: AppColors.card(context),
                  // v18.5 — #20 : Rejeter reste rouge (contraste), accepter
                  // utilise la couleur du rôle (vert walker / bleu sitter).
                  border: Border.all(color: const Color(0xFFEF4444)),
                  borderRadius: BorderRadius.circular(24.r),
                ),
                child: Center(
                  child: _isRejecting
                      ? SizedBox(
                          width: 22.w,
                          height: 22.h,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFFEF4444),
                            ),
                          ),
                        )
                      : InterText(
                          text: 'sitter_reject'.tr,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFFEF4444),
                        ),
                ),
              ),
            ),
          ),
          SizedBox(width: 12.w),
        ],
        Expanded(
          child: GestureDetector(
            onTap: _isAccepting || _isRejecting
                ? null
                : () async {
                    if (widget.onAccept == null) return;
                    setState(() => _isAccepting = true);
                    try {
                      await widget.onAccept!();
                    } finally {
                      if (mounted) setState(() => _isAccepting = false);
                    }
                  },
            child: Container(
              height: 48.h,
              decoration: BoxDecoration(
                // v18.5 — #20 : Accepter utilise la couleur du rôle.
                color: _isAccepting
                    ? _roleAccent.withValues(alpha: 0.7)
                    : _roleAccent,
                borderRadius: BorderRadius.circular(24.r),
              ),
              child: Center(
                child: _isAccepting
                    ? SizedBox(
                        width: 22.w,
                        height: 22.h,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.whiteColor,
                          ),
                        ),
                      )
                    : InterText(
                        text: 'sitter_accept'.tr,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                        color: AppColors.whiteColor,
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(String status) {
    final statusLower = status.toLowerCase();
    Color backgroundColor;
    Color textColor;
    IconData icon;
    String displayText;

    switch (statusLower) {
      case 'agreed':
        backgroundColor = AppColors.greenColor.withValues(alpha: 0.1);
        textColor = AppColors.greenColor;
        icon = Icons.check_circle;
        displayText = 'status_agreed_label'.tr;
        break;
      case 'pending':
        backgroundColor = Colors.orange.withValues(alpha: 0.1);
        textColor = Colors.orange;
        icon = Icons.timer;
        displayText = 'status_pending_label'.tr;
        break;
      case 'rejected':
        backgroundColor = AppColors.errorColor.withValues(alpha: 0.1);
        textColor = AppColors.errorColor;
        icon = Icons.close_rounded;
        displayText = 'status_rejected_label'.tr;
        break;
      default:
        backgroundColor = AppColors.greyColor.withValues(alpha: 0.1);
        textColor = AppColors.greyColor;
        icon = Icons.info;
        displayText = status.toUpperCase();
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14.sp, color: textColor),
          SizedBox(width: 6.w),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: InterText(
                text: 'sitter_status_label'.tr.replaceAll(
                  '@status',
                  displayText,
                ),
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
                color: textColor,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentStatusChip(String paymentStatus) {
    final statusLower = paymentStatus.toLowerCase();
    Color backgroundColor;
    Color textColor;
    IconData icon;
    String displayText;

    switch (statusLower) {
      case 'paid':
        backgroundColor = AppColors.greenColor.withValues(alpha: 0.1);
        textColor = AppColors.greenColor;
        icon = Icons.check_circle;
        displayText = 'status_paid_label'.tr.toUpperCase();
        break;
      case 'pending':
        backgroundColor = Colors.orange.withValues(alpha: 0.1);
        textColor = Colors.orange;
        icon = Icons.timer;
        displayText = 'status_pending_label'.tr.toUpperCase();
        break;
      case 'rejected':
        backgroundColor = AppColors.errorColor.withValues(alpha: 0.1);
        textColor = AppColors.errorColor;
        icon = Icons.close_rounded;
        displayText = 'status_rejected_label'.tr;
        break;
      default:
        backgroundColor = AppColors.greyColor.withValues(alpha: 0.1);
        textColor = AppColors.greyColor;
        icon = Icons.info;
        displayText = paymentStatus.toUpperCase();
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14.sp, color: textColor),
          SizedBox(width: 6.w),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: InterText(
                text: 'sitter_payment_status_label'.tr.replaceAll(
                  '@status',
                  displayText,
                ),
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
                color: textColor,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

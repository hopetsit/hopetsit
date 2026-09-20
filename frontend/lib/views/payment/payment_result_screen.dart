import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/controllers/chat_controller.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/models/booking_model.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/currency_helper.dart';
import 'package:hopetsit/utils/bottom_inset.dart';
import 'package:hopetsit/utils/logger.dart';
import 'package:hopetsit/views/payment/widgets/payment_ui_kit.dart';
import 'package:hopetsit/views/pet_owner/chat/individual_chat_screen.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:hopetsit/views/profile/widgets/profile_ui_kit.dart';
import 'package:intl/intl.dart';

/// Résultat de paiement (succès / échec).
///
/// v565 (point 28) — kit Profil : boutons du rôle, carte de détails coins 20,
/// pastille de statut, montant mis en avant, date localisée (avant : mois en
/// anglais en dur).
class PaymentResultScreen extends StatelessWidget {
  final bool isSuccess;
  final String? message;
  final String? transactionId;
  final double? amount;
  final String? currency;
  final VoidCallback? onContinue;
  final BookingModel? booking;

  const PaymentResultScreen({
    super.key,
    required this.isSuccess,
    this.message,
    this.transactionId,
    this.amount,
    this.currency,
    this.onContinue,
    this.booking,
  });

  @override
  Widget build(BuildContext context) {
    final accent = isSuccess ? _resolveAccentColor() : AppColors.primaryColor;
    final resultMessage = message ??
        (isSuccess ? null : 'pay569_failed_generic'.tr);
    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      body: SafeArea(
        child: SingleChildScrollView(
          // v569 — dégagement bas unique de l'app (aucun autre inset n'est
          // appliqué sur cet écran : le SafeArea ne couvre pas le Samsung).
          padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w,
              20.h + appBottomInsetInsideSafeArea(context)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(height: 24.h),

              // v569 — grand disque animé : le cercle grandit puis la coche
              // (ou la croix) se dessine ; retour haptique au montage.
              PayResultBadge(success: isSuccess),

              SizedBox(height: 18.h),

              // v18.5 — la marque sous le disque : la confirmation reste
              // « HoPetSit », pas un toast générique.
              InterText(
                text: 'HoPetSit',
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                color: AppColors.textSecondary(context),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: 14.h),

              // Title
              PoppinsText(
                text: isSuccess ? 'payment_success_title'.tr : 'payment_failed_title'.tr,
                fontSize: 24.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary(context),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: 10.h),
              PayStatusChip(
                label: isSuccess
                    ? 'status_paid_label'.tr
                    : 'status_payment_failed_label'.tr,
                color: isSuccess ? const Color(0xFF16A34A) : AppColors.errorColor,
              ),
              if (isSuccess && amount != null) ...[
                SizedBox(height: 14.h),
                InterText(
                  text: 'pay569_amount_paid'.tr,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary(context),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 2.h),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: PoppinsText(
                    text: _formatPrice(
                      amount!,
                      currency ??
                          booking?.pricing?.currency ??
                          booking?.sitter.currency ??
                          CurrencyHelper.eur,
                    ),
                    fontSize: 32.sp,
                    fontWeight: FontWeight.w800,
                    color: accent,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                  ),
                ),
              ],

              SizedBox(height: 16.h),

              // Message
              if (resultMessage != null) ...[
                InterText(
                  text: resultMessage,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary(context),
                  textAlign: TextAlign.center,
                  height: 1.4,
                  maxLines: 5,
                ),
                SizedBox(height: 24.h),
              ],

              // v569 — « Et maintenant ? » : uniquement ce qui est vrai du
              // flux existant (le prestataire reçoit la notification de
              // paiement, la conversation est ouverte par le webhook, puis
              // la remise de l'animal à la date de la réservation).
              if (isSuccess) ...[
                PayNextSteps(
                  title: 'pay569_next_steps_title'.tr,
                  accent: accent,
                  steps: _nextSteps(),
                ),
                SizedBox(height: 16.h),
              ],

              // Transaction Details Card
              if (isSuccess && (transactionId != null || amount != null))
                _buildTransactionDetailsCard(context),

              if (!isSuccess) SizedBox(height: 24.h),

              // v20.1 — #P3 fix : auto-open chat avec le sitter/walker dès
              // que le paiement passe (le backend a déjà unlock la
              // conversation côté webhook). Le primary CTA devient
              // "Discuter avec le sitter/walker" en succès. L'ancien bouton
              // "Retour à l'accueil" reste en secondary text-link pour
              // ceux qui veulent juste fermer.
              ProfilePrimaryButton(
                label: isSuccess
                    ? _chatButtonLabel()
                    : 'payment_try_again'.tr,
                accent: accent,
                icon: isSuccess ? Icons.chat_bubble_rounded : Icons.refresh_rounded,
                onTap: () {
                  if (isSuccess) {
                    _openChatWithProvider();
                  } else {
                    (onContinue ?? Get.back)();
                  }
                },
              ),

              SizedBox(height: 10.h),
              // Back to Home
              ProfileSecondaryButton(
                label: 'common_back_to_home'.tr,
                accent:
                    isSuccess ? AppColors.textSecondary(context) : accent,
                icon: Icons.home_rounded,
                onTap: () => Get.until(
                  (route) =>
                      route.isFirst || route.settings.name == '/home',
                ),
              ),

              SizedBox(height: 24.h),
            ],
          ),
        ),
      ),
    );
  }

  /// v569 — les 2-3 étapes qui suivent réellement un paiement réussi.
  List<PayStep> _nextSteps() {
    final steps = <PayStep>[
      PayStep(
        icon: Icons.notifications_active_rounded,
        text: 'pay569_step_provider'.tr,
      ),
      PayStep(
        icon: Icons.chat_bubble_rounded,
        text: 'pay569_step_chat'.tr,
      ),
    ];
    final date = _handoverDate();
    steps.add(PayStep(
      icon: Icons.pets_rounded,
      text: date.isEmpty
          ? 'pay569_step_handover_generic'.tr
          : 'pay569_step_handover'.tr.replaceAll('@date', date),
    ));
    return steps;
  }

  /// Date de la réservation, formatée dans la langue de l'app. Vide si la
  /// réservation n'en porte pas (on affiche alors la version générique).
  String _handoverDate() {
    final raw = (booking?.date ?? '').trim();
    if (raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      return DateFormat.yMMMd(Get.locale?.languageCode).format(dt);
    } catch (_) {
      return raw;
    }
  }

  Widget _buildTransactionDetailsCard(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(18.w),
      margin: EdgeInsets.only(bottom: 24.h),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: AppColors.cardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PoppinsText(
            text: 'payment_transaction_details'.tr,
            fontSize: 16.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary(context),
          ),
          SizedBox(height: 16.h),
          if (transactionId != null) ...[
            _buildDetailRow('payment_transaction_id_label'.tr, transactionId!, context),
            SizedBox(height: 12.h),
          ],
          if (amount != null) ...[
            _buildDetailRow(
              'payment_amount_label'.tr,
              _formatPrice(
                amount!,
                currency ??
                    booking?.pricing?.currency ??
                    booking?.sitter.currency ??
                    CurrencyHelper.eur,
              ),
              context,
            ),
            SizedBox(height: 12.h),
          ],
          _buildDetailRow('payment_date_label'.tr, _formatDate(DateTime.now()), context),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          child: InterText(
            text: label,
            fontSize: 14.sp,
            fontWeight: FontWeight.w400,
            color: AppColors.textSecondary(context),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: InterText(
              text: value,
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary(context),
              textAlign: TextAlign.right,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }

  String _formatPrice(double price, String currency) {
    return CurrencyHelper.format(currency, price);
  }

  // v565 — date localisée (avant : mois anglais en dur).
  String _formatDate(DateTime date) {
    return DateFormat.yMMMd(Get.locale?.languageCode).format(date);
  }

  /// v18.5 — #17 : resolve the role accent color (green for walker,
  /// blue for sitter, fallback primary). Used to color the "back to home"
  /// button on the payment success screen so it matches the role that was
  /// just paid.
  ///
  /// v18.9.8 — utilise les constantes centralisées AppColors (walkerAccent /
  /// sitterAccent) au lieu de Color(0xFF16A34A) / Color(0xFF2563EB) dupliqués.
  Color _resolveAccentColor() {
    if (booking == null) return AppColors.primaryColor;
    final service = (booking!.serviceType ?? '').toLowerCase();
    if (service.contains('dog_walking') || service.contains('walking')) {
      return AppColors.walkerAccent;
    }
    if (service.contains('sitting') ||
        service.contains('day_care') ||
        service.contains('boarding')) {
      return AppColors.sitterAccent;
    }
    return AppColors.primaryColor;
  }

  // ─── v20.1 — chat auto-open after payment ──────────────────────────────

  /// Returns the localised CTA label for the success-mode primary button.
  /// Falls back to "Back to home" if we don't have a provider on the
  /// booking (defensive — shouldn't happen on a real booking flow).
  String _chatButtonLabel() {
    if (booking == null) return 'common_back_to_home'.tr;
    final service = (booking!.serviceType ?? '').toLowerCase();
    if (service.contains('dog_walking') || service.contains('walking')) {
      return 'payment_chat_with_walker'.tr;
    }
    return 'payment_chat_with_sitter'.tr;
  }

  /// Hits POST /conversations/start?sitterId=XXX with a one-line opener
  /// then navigates to IndividualChatScreen with the returned conversation.
  /// The backend already created/unlocked the conversation on
  /// payment_intent.succeeded → /start is therefore an idempotent op that
  /// just returns the existing one (and posts an additional opener msg).
  ///
  /// On any failure we fall back gracefully to the home screen so the
  /// user is never stranded on a dead button.
  Future<void> _openChatWithProvider() async {
    final providerId = booking?.sitter.id ?? '';
    if (providerId.isEmpty) {
      AppLogger.logError(
        '[payment_result] missing providerId on booking — falling back to home',
      );
      Get.until((route) => route.isFirst || route.settings.name == '/home');
      return;
    }
    // v23.1 part 38 — fix Daniel : détecte si le booking est un walker ou
    // sitter pour appeler la bonne query param. Avant, on hardcodait
    // ?sitterId= même pour les walkers → backend renvoyait 404 "Sitter not found"
    // → bouton Discussion ne marchait pas après paiement walker.
    final serviceType = (booking?.serviceType ?? '').toLowerCase();
    final isWalkerBooking = serviceType.contains('walking');
    final queryParam = isWalkerBooking
        ? 'walkerId=$providerId'
        : 'sitterId=$providerId';
    try {
      final api = Get.find<ApiClient>();
      final res = await api.post(
        '/conversations/start?$queryParam',
        body: {
          // The webhook already posted a system welcome — this opener
          // is the owner's first message, kept neutral & short.
          'message': 'payment_chat_opener_message'.tr,
        },
        requiresAuth: true,
      );

      String conversationId = '';
      if (res is Map && res['conversation'] is Map) {
        conversationId =
            (res['conversation']['id'] ??
                    res['conversation']['_id'] ??
                    '')
                .toString();
      }
      if (conversationId.isEmpty) {
        throw Exception('no conversation id in response');
      }

      // v23.1.170 — Daniel : "jai payer un walker on commence a secirre ds
      // le chat et la il yavais que des numlero qui saffichet et ecran
      // noir crash". Cause #2 (en plus du nested payload fix) : `Get.offAll`
      // détruit la route hôte → ChatController.onClose() ferme les Rx, mais
      // l'instance reste enregistrée via `Get.put` non-permanent → quand
      // IndividualChatScreen.initState retrouve l'instance morte → Obx
      // accède à des Rx fermés → écran noir + crash. On force-delete
      // l'instance AVANT le offAll pour que le nouveau screen recrée tout
      // proprement depuis zero.
      //
      // v23.1 part 240 — Daniel screenshot : "une fois que jeffectue un
      // paiement au sitter et que je commence a lui parler lapp crash
      // ecran noir". Le delete + offAll consecutifs creaient une race :
      // Get.delete dispose le controller pendant qu'un autre Obx (e.g.
      // ChatListScreen sous le payment) le lit encore → exception unhandled
      // → next frame ecran noir. FIX : on differe le delete au prochain
      // frame APRES que offAll ait nettoye la stack. addPostFrameCallback
      // garantit que la nav est faite avant que delete frappe l'arbre.
      final convId = conversationId;
      final contactName = booking?.sitter.name ?? '';
      final contactImage = booking?.sitter.avatar.url ?? '';
      // Differe le delete au post-frame pour eviter la race.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          if (Get.isRegistered<ChatController>()) {
            Get.delete<ChatController>(force: true);
          }
        } catch (_) {/* noop */}
      });
      // Use Get.off (not offAll) to replace ONLY the payment screen.
      // Get.offAll detruit toute la pile → autres Obx en cours de build
      // referencaient l'ancien controller. Get.off est plus chirurgical.
      Get.off(
        () => IndividualChatScreen(
          conversationId: convId,
          contactName: contactName,
          contactImage: contactImage,
        ),
      );
    } catch (e) {
      AppLogger.logError(
        '[payment_result] failed to open chat after payment',
        error: e,
      );
      CustomSnackbar.showWarning(
        title: 'common_info'.tr,
        message: 'payment_chat_open_fallback'.tr,
      );
      Get.until((route) => route.isFirst || route.settings.name == '/home');
    }
  }

}

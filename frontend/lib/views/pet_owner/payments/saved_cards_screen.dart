import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/repositories/owner_repository.dart';
import 'package:hopetsit/services/airwallex_payment_service.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/views/booking/widgets/booking_ui_kit.dart';
import 'package:hopetsit/views/profile/widgets/profile_ui_kit.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';

/// v23.1 — Mes cartes (saved Airwallex payment_consents).
/// Owner can see all cards saved on Airwallex side and detach any of them.
///
/// v565 (point 28) — modernisation : kit Profil (scaffold, cartes groupées,
/// feuilles de confirmation), états chargement / vide / erreur avec
/// « Réessayer », chip « Par défaut » sur la première carte (c'est elle
/// que l'écran de paiement présélectionne), flux d'ajout extrait dans
/// [runAddCardVerificationFlow] pour être partagé avec « Mes paiements ».
class SavedCardsScreen extends StatefulWidget {
  const SavedCardsScreen({super.key});

  @override
  State<SavedCardsScreen> createState() => _SavedCardsScreenState();
}

/// Libellé « VISA •••• 1234 » d'une carte renvoyée par
/// GET /owner/payments/methods.
String savedCardLabel(Map<String, dynamic> c) {
  final brand = (c['brand']?.toString() ?? '').toUpperCase();
  final last4 = c['last4']?.toString() ?? '';
  final b = brand.isNotEmpty ? brand : 'CARD';
  return last4.isNotEmpty ? '$b •••• $last4' : b;
}

/// Sous-titre « Expire 04/27 · Titulaire » d'une carte.
String savedCardSubtitle(Map<String, dynamic> c) {
  final mm = c['expiryMonth']?.toString();
  final yy = c['expiryYear']?.toString();
  final holder = c['cardholder']?.toString() ?? '';
  final parts = <String>[];
  if (mm != null && mm.isNotEmpty && yy != null && yy.isNotEmpty) {
    parts.add('v565_pay_expires'.trParams({
      'mm': mm.padLeft(2, '0'),
      'yy': yy.length > 2 ? yy.substring(yy.length - 2) : yy,
    }));
  }
  if (holder.isNotEmpty) parts.add(holder);
  return parts.join(' · ');
}

/// Feuille de confirmation « Apple » : titre, message, bouton principal
/// (danger ou accent) + Annuler. Renvoie true si confirmé.
Future<bool> showPaymentConfirmSheet(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required Color accent,
  IconData icon = Icons.help_outline_rounded,
  bool danger = false,
}) async {
  final c = danger ? AppColors.errorColor : accent;
  final ok = await showProfileSheet<bool>(
    context,
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 16.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ProfileSheetHandle(),
          Row(
            children: [
              Container(
                width: 44.w,
                height: 44.w,
                decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: Icon(icon, color: c, size: 22.sp),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: PoppinsText(
                  text: title,
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary(ctx),
                  maxLines: 2,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          InterText(
            text: message,
            fontSize: 13.5.sp,
            color: AppColors.textSecondary(ctx),
            height: 1.45,
            maxLines: 8,
          ),
          SizedBox(height: 20.h),
          ProfilePrimaryButton(
            label: confirmLabel,
            accent: c,
            onTap: () => Navigator.of(ctx).pop(true),
          ),
          SizedBox(height: 8.h),
          ProfileSecondaryButton(
            label: 'common_cancel'.tr,
            accent: AppColors.greyText,
            onTap: () => Navigator.of(ctx).pop(false),
          ),
        ],
      ),
    ),
  );
  return ok == true;
}

/// Flux « Ajouter une carte » sans réservation : confirmation (0,50 €
/// remboursé automatiquement), création du PaymentIntent de vérification
/// côté backend, page sécurisée Airwallex, puis rechargement par
/// l'appelant. Renvoie true si une carte a bien été enregistrée.
Future<bool> runAddCardVerificationFlow(
  BuildContext context, {
  required OwnerRepository repo,
  required Color accent,
  // v568 — remplacement d'une carte : Airwallex ne permet pas de modifier
  // un numéro. On enregistre la nouvelle, on la passe par défaut, puis on
  // désactive l'ancienne (fait par l'appelant après un retour `true`).
  String? replaceConsentId,
  bool skipConfirm = false,
}) async {
  // 1. Confirmation : explique la charge 0,50 € + remboursement auto.
  if (!skipConfirm) {
    final ok = await showPaymentConfirmSheet(
      context,
      title: 'saved_cards_verify_title'.tr,
      message: 'saved_cards_verify_message'.tr,
      confirmLabel: 'saved_cards_verify_confirm'.tr,
      accent: accent,
      icon: Icons.add_card_rounded,
    );
    if (!ok) return false;
  }

  try {
    // 2. Backend creates the verification PI.
    final intent = await repo.verifyCard(replaceConsentId: replaceConsentId);
    final piId = intent['paymentIntentId'] as String? ?? '';
    final secret = intent['clientSecret'] as String? ?? '';
    final amount = (intent['amount'] as num?)?.toDouble() ?? 0.50;
    final currency = (intent['currency'] as String?) ?? 'EUR';
    // v568 — sans customerId, la page Airwallex n'enregistre pas la carte
    // sur le client : elle était « vérifiée » puis perdue.
    final customerId = (intent['customerId'] as String?) ?? '';

    if (piId.isEmpty || secret.isEmpty) {
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'saved_cards_verify_failed'.tr,
      );
      return false;
    }

    // 3. Open the Airwallex WebView for the user to enter card details.
    final result = await AirwallexPaymentService.confirmPaymentIntent(
      intentId: piId,
      clientSecret: secret,
      amount: amount,
      currency: currency,
      customerId: customerId.isEmpty ? null : customerId,
    );

    if (!result.isSuccess) {
      if (result.outcome != AirwallexPaymentOutcome.cancelled) {
        CustomSnackbar.showError(
          title: 'common_error'.tr,
          message: result.errorMessage ?? 'saved_cards_verify_failed'.tr,
        );
      }
      return false;
    }

    // 4. Success — refund is triggered by the webhook server-side.
    CustomSnackbar.showSuccess(
      title: 'common_success'.tr,
      message: 'saved_cards_verify_success'.tr,
    );
    // Small delay so Airwallex has time to register the consent before reload.
    await Future.delayed(const Duration(seconds: 2));
    return true;
  } on ApiException catch (e) {
    CustomSnackbar.showError(title: 'common_error'.tr, message: e.message);
    return false;
  } catch (e) {
    CustomSnackbar.showError(title: 'common_error'.tr, message: e.toString());
    return false;
  }
}

/// Message d'erreur lisible d'une exception API (details.details > message).
String paymentErrorMessage(Object e) {
  if (e is ApiException) {
    if (e.details is Map) {
      final d = (e.details as Map)['details'];
      if (d is String && d.isNotEmpty) return d;
      final err = (e.details as Map)['error'];
      if (err is String && err.isNotEmpty) return err;
    }
    if (e.message.isNotEmpty) return e.message;
  }
  return e.toString();
}

class _SavedCardsScreenState extends State<SavedCardsScreen> {
  late final OwnerRepository _repo;
  final RxList<Map<String, dynamic>> cards = <Map<String, dynamic>>[].obs;
  final RxBool isLoading = false.obs;
  final RxnString errorMessage = RxnString();

  // v23.1 — busy flag pour éviter double-tap pendant la vérification.
  final RxBool _verifying = false.obs;

  Color get _accent => currentRoleAccent();

  @override
  void initState() {
    super.initState();
    _repo = Get.isRegistered<OwnerRepository>()
        ? Get.find<OwnerRepository>()
        : OwnerRepository(Get.find<ApiClient>());
    _load();
  }

  Future<void> _load() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final list = await _repo.getOwnerPaymentMethods();
      cards.assignAll(list);
    } on ApiException catch (e) {
      errorMessage.value = paymentErrorMessage(e);
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _confirmAndDelete(Map<String, dynamic> card) async {
    final id = card['id']?.toString() ?? '';
    if (id.isEmpty) return;
    final confirmed = await showPaymentConfirmSheet(
      context,
      title: 'saved_cards_delete_title'.tr,
      message: '${savedCardLabel(card)}\n${'saved_cards_delete_message'.tr}',
      confirmLabel: 'common_delete'.tr,
      accent: _accent,
      icon: Icons.delete_outline_rounded,
      danger: true,
    );
    if (!confirmed) return;
    try {
      await _repo.deleteOwnerPaymentMethod(id);
      cards.removeWhere((c) => c['id']?.toString() == id);
      CustomSnackbar.showSuccess(
        title: 'common_success'.tr,
        message: 'saved_cards_delete_success'.tr,
      );
    } catch (e) {
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: paymentErrorMessage(e),
      );
    }
  }

  Future<void> _onAddCardTap() async {
    if (_verifying.value) return;
    _verifying.value = true;
    try {
      final added = await runAddCardVerificationFlow(
        context,
        repo: _repo,
        accent: _accent,
      );
      if (added) await _load();
    } finally {
      _verifying.value = false;
    }
  }

  /// v568 — carte par défaut : c'est elle qui sera proposée au paiement
  /// (réservation, abonnement, boutique, don), sur les 3 profils.
  Future<void> _setDefault(Map<String, dynamic> card) async {
    final id = card['id']?.toString() ?? '';
    if (id.isEmpty) return;
    try {
      await _repo.setDefaultOwnerPaymentMethod(id);
      CustomSnackbar.showSuccess(
        title: 'common_success'.tr,
        message: 'cards568_set_default_done'.tr,
      );
      await _load();
    } catch (e) {
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: paymentErrorMessage(e),
      );
    }
  }

  /// v568 — « Modifier » une carte. Airwallex ne permet PAS de changer le
  /// numéro d'une carte enregistrée : on enregistre la nouvelle, on la passe
  /// par défaut, puis on retire l'ancienne. Le message l'explique.
  Future<void> _replace(Map<String, dynamic> card) async {
    final oldId = card['id']?.toString() ?? '';
    if (oldId.isEmpty || _verifying.value) return;
    final confirmed = await showPaymentConfirmSheet(
      context,
      title: 'cards568_replace_title'.tr,
      message: '${savedCardLabel(card)}\n\n${'cards568_replace_message'.tr}',
      confirmLabel: 'cards568_replace_confirm'.tr,
      accent: _accent,
      icon: Icons.published_with_changes_rounded,
    );
    if (!confirmed || !mounted) return;

    _verifying.value = true;
    try {
      final added = await runAddCardVerificationFlow(
        context,
        repo: _repo,
        accent: _accent,
        replaceConsentId: oldId,
        skipConfirm: true,
      );
      if (!added) return;

      // La nouvelle carte est la plus récente du client Airwallex.
      final refreshed = await _repo.getOwnerPaymentMethods();
      final fresh = refreshed.firstWhereOrNull(
        (c) => c['id']?.toString() != oldId,
      );
      var oldRemoved = false;
      try {
        if (fresh != null) {
          await _repo.setDefaultOwnerPaymentMethod(fresh['id'].toString());
        }
        await _repo.deleteOwnerPaymentMethod(oldId);
        oldRemoved = true;
      } catch (_) {
        // L'ancienne carte a survécu : on le dit au lieu de laisser croire
        // que le remplacement est complet.
        oldRemoved = false;
      }
      CustomSnackbar.showSuccess(
        title: 'common_success'.tr,
        message: oldRemoved
            ? 'cards568_replace_done'.tr
            : 'cards568_replace_old_kept'.tr,
      );
      await _load();
    } finally {
      _verifying.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accent;
    return ProfileSubPageScaffold(
      title: 'saved_cards_title'.tr,
      accent: accent,
      scroll: false,
      padding: EdgeInsets.zero,
      // v23.1 — bouton « Ajouter une carte » : flux de vérification réel.
      // Charge €0.50 (auto-remboursé par webhook) pour enregistrer la carte
      // sans qu'il y ait besoin d'une vraie réservation.
      bottom: Obx(() => ProfilePrimaryButton(
            label: _verifying.value
                ? 'saved_cards_verifying'.tr
                : 'saved_cards_add_button'.tr,
            accent: accent,
            icon: Icons.add_card_rounded,
            loading: _verifying.value,
            onTap: _verifying.value ? null : _onAddCardTap,
          )),
      body: RefreshIndicator(
        color: accent,
        onRefresh: _load,
        child: Obx(() {
          if (isLoading.value && cards.isEmpty) {
            return BookingLoadingList(accent: accent);
          }
          if (errorMessage.value != null && cards.isEmpty) {
            return BookingErrorState(
              message: errorMessage.value!,
              onRetry: _load,
            );
          }
          if (cards.isEmpty) {
            return BookingEmptyState(
              icon: Icons.credit_card_off_rounded,
              title: 'saved_cards_empty_title'.tr,
              subtitle: 'saved_cards_empty_message'.tr,
              accent: accent,
            );
          }
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
            children: [
              ProfileGroupCard(
                children: [
                  // v568 — « par défaut » n'est plus « la première de la
                  // liste » : c'est le choix de l'utilisateur, renvoyé par
                  // le serveur (isDefault).
                  for (var i = 0; i < cards.length; i++)
                    SavedCardRow(
                      card: cards[i],
                      accent: accent,
                      isDefault: cards[i]['isDefault'] == true || (i == 0 &&
                          !cards.any((c) => c['isDefault'] == true)),
                      onDelete: () => _confirmAndDelete(cards[i]),
                      onSetDefault: () => _setDefault(cards[i]),
                      onReplace: () => _replace(cards[i]),
                    ),
                ],
              ),
              SizedBox(height: 10.h),
              ProfileInfoBanner(
                icon: Icons.verified_user_outlined,
                text:
                    '${'v565_pay_default_hint'.tr}\n${'v565_pay_cards_hint'.tr}',
                accent: accent,
              ),
            ],
          );
        }),
      ),
    );
  }
}

/// Rangée d'une carte enregistrée : marque + 4 derniers chiffres, expiration
/// / titulaire, chip « Par défaut » (1re carte), corbeille.
class SavedCardRow extends StatelessWidget {
  final Map<String, dynamic> card;
  final Color accent;
  final bool isDefault;
  final VoidCallback onDelete;
  // v568 — gestion complète d'une carte : par défaut / remplacer / supprimer.
  // Optionnels pour ne casser aucun appelant existant.
  final VoidCallback? onSetDefault;
  final VoidCallback? onReplace;
  const SavedCardRow({
    super.key,
    required this.card,
    required this.accent,
    required this.isDefault,
    required this.onDelete,
    this.onSetDefault,
    this.onReplace,
  });

  bool get _isExpired => card['isExpired'] == true;

  /// Feuille d'actions « Cette carte » : par défaut, remplacer, supprimer.
  Future<void> _openActions(BuildContext context) async {
    await showProfileSheet<void>(
      context,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ProfileSheetHandle(),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 6.h),
              child: PoppinsText(
                text: '${'cards568_actions_title'.tr} · ${savedCardLabel(card)}',
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary(ctx),
                maxLines: 2,
              ),
            ),
            ProfileGroupCard(
              children: [
                if (onSetDefault != null && !isDefault && !_isExpired)
                  ProfileRow(
                    icon: Icons.star_rounded,
                    color: accent,
                    title: 'cards568_set_default'.tr,
                    onTap: () {
                      Navigator.of(ctx).pop();
                      onSetDefault!();
                    },
                  ),
                if (onReplace != null)
                  ProfileRow(
                    icon: Icons.published_with_changes_rounded,
                    color: accent,
                    title: 'cards568_replace'.tr,
                    onTap: () {
                      Navigator.of(ctx).pop();
                      onReplace!();
                    },
                  ),
                ProfileRow(
                  icon: Icons.delete_outline_rounded,
                  color: AppColors.errorColor,
                  title: 'cards568_delete'.tr,
                  onTap: () {
                    Navigator.of(ctx).pop();
                    onDelete();
                  },
                ),
              ],
            ),
            SizedBox(height: 10.h),
            InterText(
              text: 'cards568_security_note'.tr,
              fontSize: 12.sp,
              color: AppColors.textSecondary(ctx),
              height: 1.4,
              maxLines: 4,
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) => Container(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: InterText(
          text: label,
          fontSize: 10.5.sp,
          fontWeight: FontWeight.w700,
          color: color,
          maxLines: 1,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final subtitle = _isExpired
        ? '${savedCardSubtitle(card)}\n${'cards568_expired_hint'.tr}'
        : savedCardSubtitle(card);
    final hasMenu = onSetDefault != null || onReplace != null;
    return ProfileRow(
      icon: Icons.credit_card_rounded,
      color: _isExpired ? AppColors.errorColor : accent,
      title: savedCardLabel(card),
      subtitle: subtitle,
      showChevron: false,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isExpired) _chip('cards568_expired'.tr, AppColors.errorColor),
          if (isDefault && !_isExpired)
            _chip('v565_pay_default_card'.tr, accent),
          if (hasMenu)
            IconButton(
              tooltip: 'cards568_manage'.tr,
              icon: Icon(Icons.more_horiz_rounded,
                  color: AppColors.textSecondary(context), size: 22.sp),
              onPressed: () => _openActions(context),
            )
          else
            IconButton(
              tooltip: 'common_delete'.tr,
              icon: Icon(Icons.delete_outline_rounded,
                  color: AppColors.errorColor, size: 22.sp),
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }
}

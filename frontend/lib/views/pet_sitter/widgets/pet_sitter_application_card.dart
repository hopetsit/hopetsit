// v569 — carte « demande reçue » du gardien / promeneur, remise au langage
// visuel du lot (mêmes blocs et mêmes pilules que la carte d'annonce et que
// les bandeaux d'action).
//
// ⚠️ DESIGN UNIQUEMENT : le modèle [PetSitterApplication], les paramètres du
// constructeur, les callbacks (`onAccept`, `onReject`, `onStartChat`,
// `onViewOwnerProfile`), les conditions d'affichage (téléphone visible
// seulement si payé, « Voir profil » et actions seulement si `pending`) et
// les états « en cours » sont inchangés.
//
// Corrections de branchement signalées :
//   • les pastilles d'état affichaient la VALEUR TECHNIQUE en majuscules
//     (« COMPLETED », « CANCELLED ») dès que le statut sortait des 3 cas
//     prévus → libellés traduits pour tous les statuts connus ;
//   • le montant perdait sa devise hors EUR / GBP / USD (symbole vide :
//     « 45.00 » sans rien) → `NumberFormat.simpleCurrency` sur la devise de
//     la donnée, repli « 45.00 CHF ». Plus aucun « € » codé en dur ;
//   • les boîtes d'attributs défilaient horizontalement dans une carte déjà
//     dans une liste verticale (et débordaient en allemand) → `Wrap`.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/booking_date_format.dart';
import 'package:hopetsit/views/pet_sitter/widgets/post_card_kit.dart';
import 'package:hopetsit/widgets/action_banner_kit.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:intl/intl.dart';

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

  // v527 — retour Jose (R3-6) : le détail de demande vu par le prestataire
  // n'affichait NI le nom NI la photo du propriétaire (seulement un bouton
  // « Voir profil »). On expose les infos owner pour la petite carte en haut.
  final String ownerName;
  final String ownerAvatar;
  final String ownerCity;

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
    // v527 — retour Jose (R3-6) : infos propriétaire (optionnelles).
    this.ownerName = '',
    this.ownerAvatar = '',
    this.ownerCity = '',
  });
}

class PetSitterApplicationCard extends StatefulWidget {
  final PetSitterApplication application;
  final Future<void> Function()? onAccept;
  final VoidCallback? onReject;
  final VoidCallback? onStartChat;
  // v23.1 part 58 — sitter/walker need to see who's behind the booking before
  // accepting/refusing. Caller supplies a callback that opens an owner-profile
  // bottom sheet with name, avatar, email, phone, address, etc.
  final VoidCallback? onViewOwnerProfile;

  const PetSitterApplicationCard({
    super.key,
    required this.application,
    this.onAccept,
    this.onReject,
    this.onStartChat,
    this.onViewOwnerProfile,
  });

  @override
  State<PetSitterApplicationCard> createState() =>
      _PetSitterApplicationCardState();
}

class _PetSitterApplicationCardState extends State<PetSitterApplicationCard> {
  bool _isAccepting = false;
  bool _isRejecting = false;

  PetSitterApplication get application => widget.application;

  bool get _busy => _isAccepting || _isRejecting;

  // v18.5 — #20 : couleur du rôle pour cet écran.
  Color get _roleAccent => application.providerRole == 'walker'
      ? ActionTone.walker
      : ActionTone.sitter;

  // v18.7 : pour cacher les boîtes d'attribut vides/non-définies.
  bool _hasValue(String s) {
    final v = s.trim().toLowerCase();
    if (v.isEmpty) return false;
    if (v == 'pas encore défini' || v == 'pas encore defini') return false;
    if (v == 'non défini' || v == 'non defini') return false;
    if (v == 'n/a' || v == '-') return false;
    return true;
  }

  // ─── Libellés d'état ─────────────────────────────────────────────────────

  /// Libellé TRADUIT d'un statut. Avant v569, tout statut sorti des trois cas
  /// prévus s'affichait en brut et en majuscules (« COMPLETED »).
  String _statusLabel(String raw) {
    switch (raw.toLowerCase().trim()) {
      case 'agreed':
        return 'status_agreed_label'.tr;
      case 'accepted':
      case 'confirmed':
        return 'status_accepted_label'.tr;
      case 'pending':
        return 'status_pending_label'.tr;
      case 'rejected':
        return 'status_rejected_label'.tr;
      case 'cancelled':
      case 'canceled':
        return 'status_cancelled_label'.tr;
      case 'paid':
        return 'status_paid_label'.tr;
      case 'completed':
      case 'done':
        return 'lists569_status_completed'.tr;
      case 'failed':
        return 'status_failed_label'.tr;
      case 'refunded':
        return 'status_refunded_label'.tr;
      default:
        // Statut inconnu du catalogue : lisible plutôt que « HOUSE_SITTING ».
        final v = raw.trim().replaceAll('_', ' ');
        if (v.isEmpty) return '';
        return v[0].toUpperCase() + v.substring(1).toLowerCase();
    }
  }

  Color _statusTone(String raw) {
    switch (raw.toLowerCase().trim()) {
      case 'agreed':
      case 'accepted':
      case 'confirmed':
      case 'paid':
      case 'completed':
      case 'done':
        return ActionTone.success;
      case 'pending':
        return ActionTone.pending;
      case 'rejected':
      case 'cancelled':
      case 'canceled':
      case 'failed':
      case 'refunded':
        return ActionTone.danger;
      default:
        return AppColors.grey500Color;
    }
  }

  IconData _statusIcon(String raw) {
    switch (raw.toLowerCase().trim()) {
      case 'agreed':
      case 'accepted':
      case 'confirmed':
      case 'paid':
      case 'completed':
      case 'done':
        return Icons.check_circle_rounded;
      case 'pending':
        return Icons.schedule_rounded;
      case 'rejected':
      case 'cancelled':
      case 'canceled':
      case 'failed':
      case 'refunded':
        return Icons.cancel_rounded;
      default:
        return Icons.info_rounded;
    }
  }

  /// Montant dans la devise de la DONNÉE (plus de symbole vide hors
  /// EUR / GBP / USD), formaté selon la langue de l'app.
  String _money(double v) {
    final code = (application.currency ?? 'EUR').toUpperCase();
    try {
      return NumberFormat.simpleCurrency(
        locale: Get.locale?.toLanguageTag(),
        name: code,
      ).format(v);
    } catch (_) {
      return '${v.toStringAsFixed(2)} $code';
    }
  }

  @override
  Widget build(BuildContext context) {
    final onStartChat = widget.onStartChat;
    final isPending = application.status.toLowerCase().trim() == 'pending';

    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 16.h),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(PostCardKit.cardRadius.r),
        boxShadow: AppColors.cardShadow(context),
        border: Border.all(color: AppColors.divider(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── En-tête : propriétaire + pastille d'état ───────────────────
          if (application.ownerName.trim().isNotEmpty ||
              application.status != 'paid') ...[
            _buildHeader(context),
            SizedBox(height: 12.h),
          ],

          // ── Bloc « L'animal » : nom + attributs ────────────────────────
          _buildPetBlock(context),
          SizedBox(height: 10.h),

          // ── Bloc détails : date, heure, téléphone, lieu ────────────────
          _buildDetailsBlock(context),

          // v18.5 — #20 : carte prix mise en avant — le provider voit
          // combien l'owner paie ET combien il touchera net avant d'accepter.
          if (application.totalPrice != null && application.totalPrice! > 0) ...[
            SizedBox(height: 10.h),
            _buildPriceBreakdownCard(context),
          ],

          SizedBox(height: 14.h),

          // ── Actions secondaires ────────────────────────────────────────
          if (onStartChat != null) ...[
            PostSecondaryButton(
              icon: Icons.chat_bubble_rounded,
              label: 'sitter_chat_with_owner'.tr,
              color: _roleAccent,
              onTap: onStartChat,
            ),
            SizedBox(height: 8.h),
          ],

          // v23.1 part 58 — "Voir profil propriétaire" : sitter / walker
          // peut voir l'owner avant d'accepter / refuser.
          if (isPending && widget.onViewOwnerProfile != null) ...[
            PostSecondaryButton(
              icon: Icons.person_rounded,
              label: 'sitter_view_owner_profile'.tr,
              color: _roleAccent,
              onTap: widget.onViewOwnerProfile,
            ),
            SizedBox(height: 10.h),
          ],

          // ── Actions principales ────────────────────────────────────────
          if (isPending) _buildActionButtons(context),

          // ── Pastille de paiement (l'état de la demande est en en-tête) ──
          if (application.paymentStatus.trim().isNotEmpty) ...[
            SizedBox(height: 12.h),
            Align(
              alignment: Alignment.centerLeft,
              child: ActionStatusPill(
                label: 'sitter_payment_status_label'.tr.replaceAll(
                  '@status',
                  _statusLabel(application.paymentStatus),
                ),
                icon: _statusIcon(application.paymentStatus),
                tone: _statusTone(application.paymentStatus),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// v527 — retour Jose (R3-6) : propriétaire (photo + nom + ville) en haut,
  /// avec la pastille d'état de la demande à droite.
  Widget _buildHeader(BuildContext context) {
    final avatarUrl = application.ownerAvatar.trim();
    final city = application.ownerCity.trim();
    final name = application.ownerName.trim();
    // Condition d'origine conservée : l'état de la DEMANDE est masqué quand
    // il vaut déjà « paid » (la pastille de paiement le dit mieux).
    final showStatus = application.status != 'paid';
    final statusPill = showStatus
        ? ActionStatusPill(
            label: _statusLabel(application.status),
            icon: _statusIcon(application.status),
            tone: _statusTone(application.status),
          )
        : null;

    if (name.isEmpty) {
      return statusPill == null
          ? const SizedBox.shrink()
          : Align(alignment: Alignment.centerLeft, child: statusPill);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 24.r,
          backgroundColor: _roleAccent.withValues(alpha: 0.12),
          backgroundImage: avatarUrl.isNotEmpty
              ? CachedNetworkImageProvider(avatarUrl, maxWidth: 150)
              : null,
          child: avatarUrl.isEmpty
              ? Icon(Icons.person, size: 24.sp, color: _roleAccent)
              : null,
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              InterText(
                text: name,
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary(context),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 3.h),
              Row(
                children: [
                  Icon(
                    Icons.location_on_rounded,
                    size: 12.sp,
                    color: AppColors.textSecondary(context),
                  ),
                  SizedBox(width: 3.w),
                  Flexible(
                    child: InterText(
                      text: city.isNotEmpty
                          ? city
                          : 'lists569_owner_section'.tr,
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (statusPill != null) ...[
          SizedBox(width: 8.w),
          statusPill,
        ],
      ],
    );
  }

  Widget _buildPetBlock(BuildContext context) {
    // v569 — `Wrap` au lieu d'un défilement horizontal dans une liste
    // verticale : les 3 boîtes tiennent sur 2 lignes en allemand / polonais.
    final chips = <Widget>[
      if (_hasValue(application.weight))
        _attributeChip(context, 'sitter_pet_weight'.tr, application.weight),
      if (_hasValue(application.height))
        _attributeChip(context, 'sitter_pet_height'.tr, application.height),
      if (_hasValue(application.color))
        _attributeChip(context, 'sitter_pet_color'.tr, application.color),
    ];

    return PostBlock(
      accent: _roleAccent,
      title: 'lists569_pet_section'.tr,
      titleIcon: Icons.pets_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PoppinsText(
            text: application.petName.trim().isNotEmpty
                ? application.petName.trim()
                : 'lists569_pet_fallback'.tr,
            fontSize: 15.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (chips.isNotEmpty) ...[
            SizedBox(height: 10.h),
            Wrap(spacing: 8.w, runSpacing: 8.h, children: chips),
          ],
        ],
      ),
    );
  }

  Widget _attributeChip(BuildContext context, String title, String value) {
    // v18.6 — fallback propre quand la valeur est vide.
    final displayValue =
        value.isEmpty || value.trim().toLowerCase() == 'pas encore défini'
            ? 'application_card_color_unknown'.tr
            : value;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 7.h),
      decoration: BoxDecoration(
        color: _roleAccent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: _roleAccent.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          InterText(
            text: title,
            fontSize: 10.sp,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 2.h),
          InterText(
            text: displayValue,
            fontSize: 12.5.sp,
            fontWeight: FontWeight.w700,
            color: _roleAccent,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsBlock(BuildContext context) {
    // v18.8 — on n'affiche le numéro du propriétaire que si la réservation
    // est PAYÉE (paymentStatus=='paid'). Avant paiement, contact privé.
    final showPhone = application.paymentStatus.toLowerCase() == 'paid' &&
        application.phoneNumber.trim().isNotEmpty;

    // Pas de titre : chaque puce porte déjà son libellé traduit (« Date »,
    // « Heure », « Téléphone », « Lieu »), donc un intitulé de bloc unique
    // serait faux dès qu'une ligne n'est pas une date.
    return PostBlock(
      accent: _roleAccent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PostBullet(
            icon: Icons.calendar_today_rounded,
            accent: _roleAccent,
            label: 'sitter_detail_date'.tr,
            // v18.9.1 — date localisée : FR "mer. 23 avr. 2026".
            value: _valueOrFallback(
                BookingDateFormat.localizedDate(application.date)),
          ),
          PostBullet(
            icon: Icons.schedule_rounded,
            accent: _roleAccent,
            label: 'sitter_detail_time'.tr,
            // v18.9.1 — heure localisée : FR "13:14" au lieu de "1:14 PM".
            value: _valueOrFallback(
                BookingDateFormat.localizedTime(application.time)),
          ),
          if (showPhone)
            PostBullet(
              icon: Icons.call_rounded,
              accent: _roleAccent,
              label: 'sitter_detail_phone'.tr,
              value: application.phoneNumber,
            ),
          if (application.location.trim().isNotEmpty)
            PostBullet(
              icon: Icons.location_on_rounded,
              accent: _roleAccent,
              label: 'sitter_detail_location'.tr,
              value: application.location,
            ),
        ],
      ),
    );
  }

  String _valueOrFallback(String value) =>
      value.trim().isEmpty ? 'sitter_not_available_yet'.tr : value;

  /// v411 refonte — carte « Votre gain estimé » (maquette Postuler).
  /// Total payé par l'owner → − Commission PawMap (taux RÉEL) → Vous recevez.
  /// La commission est déduite des vraies valeurs (total payé − net), donc le
  /// taux affiché reflète 20 % (ou 15 % pour un prestataire Top).
  Widget _buildPriceBreakdownCard(BuildContext context) {
    final total = application.totalPrice ?? 0;
    final net = application.netPayout ?? (total * 0.8);
    final commission = (total - net).clamp(0, double.infinity).toDouble();
    // Taux réel = commission / net (≈ 20 % ou 15 % Top). Net = base prestataire.
    final ratePct = net > 0 ? (commission / net * 100).round() : 20;

    Widget row(
      String label,
      String value, {
      Color? valueColor,
      bool bold = false,
    }) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 3.h),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: InterText(
                text: label,
                fontSize: bold ? 13.sp : 12.sp,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                color: bold ? _roleAccent : AppColors.textSecondary(context),
                maxLines: 2,
              ),
            ),
            SizedBox(width: 8.w),
            PoppinsText(
              text: value,
              fontSize: bold ? 17.sp : 13.sp,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: valueColor ?? AppColors.textPrimary(context),
              maxLines: 1,
            ),
          ],
        ),
      );
    }

    return PostBlock(
      accent: _roleAccent,
      title: 'application_gain_title'.tr,
      titleIcon: Icons.account_balance_wallet_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          row('application_gain_owner_total'.tr, _money(total)),
          row(
            '${'application_gain_commission'.tr} ($ratePct%)',
            '-${_money(commission)}',
            valueColor: AppColors.errorColor,
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 6.h),
            child: Divider(
              height: 1,
              color: _roleAccent.withValues(alpha: 0.25),
            ),
          ),
          row(
            'application_gain_you_receive'.tr,
            _money(net),
            valueColor: _roleAccent,
            bold: true,
          ),
          SizedBox(height: 6.h),
          InterText(
            text: 'application_gain_hint'.tr,
            fontSize: 10.sp,
            color: AppColors.textSecondary(context),
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  /// Accepter / Refuser — kit commun : principale pleine couleur du rôle,
  /// destructive en rouge texte, ≥ 44 px, anti double-tap.
  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ActionPillButton(
            label: 'sitter_reject'.tr,
            icon: Icons.close_rounded,
            tone: ActionTone.danger,
            kind: ActionPillKind.danger,
            expand: true,
            haptic: true,
            busy: _isRejecting,
            onPressed: (_busy || widget.onReject == null)
                ? null
                : () {
                    setState(() => _isRejecting = true);
                    try {
                      widget.onReject!();
                    } finally {
                      if (mounted) setState(() => _isRejecting = false);
                    }
                  },
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: ActionPillButton(
            label: 'sitter_accept'.tr,
            icon: Icons.check_rounded,
            tone: _roleAccent,
            expand: true,
            haptic: true,
            busy: _isAccepting,
            onPressed: (_busy || widget.onAccept == null)
                ? null
                : () async {
                    setState(() => _isAccepting = true);
                    try {
                      await widget.onAccept!();
                    } finally {
                      if (mounted) setState(() => _isAccepting = false);
                    }
                  },
          ),
        ),
      ],
    );
  }
}

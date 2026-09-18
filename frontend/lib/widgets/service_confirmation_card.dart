import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:hopetsit/models/booking_model.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';

/// v23.1.259 — Carte de confirmation de service (Daniel).
///
/// Affiche, sur l'écran détail réservation, l'état du flux de confirmation et
/// le bon bouton selon le rôle :
///   PROVIDER (sitter/walker) :
///     awaiting_start/none  → "J'ai récupéré l'animal"   (onStart)
///     in_progress          → "J'ai rendu l'animal"       (onComplete)
///     awaiting_confirmation→ "En attente de l'owner"     (info)
///     confirmed            → "Confirmé — paiement libéré"
///     disputed             → "Problème signalé"
///   OWNER :
///     awaiting_start/none  → "Pas encore démarré"
///     in_progress          → "Service en cours"
///     awaiting_confirmation→ carte CONFIRMER / SIGNALER UN PROBLÈME
///     confirmed            → "Confirmé"
///     disputed             → "Litige en cours"
///
/// Ne s'affiche que pour les réservations PAYÉES (le flux ne concerne que
/// l'argent en séquestre). Pour `confirmationStatus == 'none'` (bookings
/// payés avant que le backend ne pose 'awaiting_start') on traite comme
/// `awaiting_start` côté provider → le prestataire peut démarrer le service
/// et le système reste visible sur toute réservation payée.
///
/// v23.1.265 — Daniel : "les deux boutons tournent en même temps". Le `busy`
/// du parent est par-réservation, pas par-bouton → quand l'owner tape
/// CONFIRMER, le spinner s'affichait AUSSI sur SIGNALER. La carte est
/// désormais Stateful et mémorise quel bouton a été tapé (`_pending`) : seul
/// ce bouton-là tourne, l'autre est juste désactivé le temps de l'appel.
/// v565 (point 24 / contrat §7) — la carte devient la « chronologie de
/// remise » : prévu → récupéré → rendu → confirmé, lue depuis `timeline` et
/// `handover` quand le serveur les renvoie, sinon dérivée de
/// `confirmationStatus` (compatibilité listes / vieux backend). Elle affiche
/// aussi les rappels (30 min avant, retard 1 h), la photo/position de chaque
/// étape et, côté propriétaire, le bouton « Confirmer la récupération »
/// (`onConfirmPickup`) en plus de « Confirmer le rendu » (`onConfirm`).
/// Tous les nouveaux paramètres sont facultatifs : les anciens appels
/// (sans `booking`) continuent de marcher.
class ServiceConfirmationCard extends StatefulWidget {
  const ServiceConfirmationCard({
    super.key,
    required this.confirmationStatus,
    required this.role,
    required this.isPaid,
    this.busy = false,
    this.onStart,
    this.onComplete,
    this.onConfirm,
    this.onDispute,
    this.onConfirmPickup,
    this.booking,
    this.accent,
  });

  final String confirmationStatus;
  final String role; // 'owner' | 'sitter' | 'walker'
  final bool isPaid;
  final bool busy;
  final Future<void> Function()? onStart;
  final Future<void> Function()? onComplete;
  final Future<void> Function()? onConfirm;
  final Future<void> Function()? onDispute;
  /// v565 — owner : confirmer la récupération déclarée par le prestataire.
  final Future<void> Function()? onConfirmPickup;
  /// v565 — la réservation complète (chronologie, handover, dates, photos).
  final BookingModel? booking;
  /// v565 — couleur du rôle (orange owner / bleu sitter / vert walker).
  final Color? accent;

  @override
  State<ServiceConfirmationCard> createState() =>
      _ServiceConfirmationCardState();
}

class _ServiceConfirmationCardState extends State<ServiceConfirmationCard> {
  /// Identifiant du bouton actuellement tapé ('start'|'complete'|'confirm'|
  /// 'dispute'|'confirm_pickup'). Seul ce bouton affiche le spinner.
  String? _pending;
  Timer? _tick;

  bool get _isProvider =>
      widget.role == 'sitter' || widget.role == 'walker';
  String get _status =>
      widget.confirmationStatus.isEmpty ? 'none' : widget.confirmationStatus;
  Color get _accent =>
      widget.accent ??
      (widget.role == 'walker'
          ? const Color(0xFF16A34A)
          : widget.role == 'sitter'
              ? const Color(0xFF2563EB)
              : AppColors.primaryColor);

  @override
  void initState() {
    super.initState();
    // Les rappels « dans X min » se recalculent chaque minute.
    _tick = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ServiceConfirmationCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.busy && _pending != null) {
      _pending = null;
    }
  }

  // ── État dérivé (handover > timeline > confirmationStatus) ───────────────
  BookingHandover? get _h => widget.booking?.handover;

  String? _tlAt(String step) {
    final tl = widget.booking?.timeline ?? const <BookingTimelineStep>[];
    for (final e in tl) {
      if (e.step == step && e.at != null) return e.at;
    }
    return null;
  }

  bool get _pickedUp {
    if (_h?.pickedUp == true) return true;
    if (_tlAt('picked_up') != null) return true;
    if ((widget.booking?.serviceStartedAt ?? '').isNotEmpty) return true;
    return _status == 'in_progress' ||
        _status == 'awaiting_confirmation' ||
        _status == 'confirmed';
  }

  bool get _pickupConfirmed =>
      _h?.pickupConfirmed == true || _tlAt('pickup_confirmed') != null;

  bool get _returned {
    if (_h?.returned == true) return true;
    if (_tlAt('returned') != null) return true;
    if ((widget.booking?.serviceEndedAt ?? '').isNotEmpty) return true;
    return _status == 'awaiting_confirmation' || _status == 'confirmed';
  }

  bool get _returnConfirmed =>
      _status == 'confirmed' ||
      _h?.returnConfirmed == true ||
      _tlAt('return_confirmed') != null;

  /// Le propriétaire doit confirmer la récupération (handover connu, action
  /// disponible).
  bool get _pickupAwaitingOwner =>
      _pickedUp && !_pickupConfirmed && _h != null && !_returned;

  String? get _pickedUpAt =>
      _h?.pickupProviderAt ?? _tlAt('picked_up') ?? widget.booking?.serviceStartedAt;
  String? get _pickupConfirmedAt =>
      _h?.pickupOwnerConfirmedAt ?? _h?.pickupAutoConfirmedAt ?? _tlAt('pickup_confirmed');
  String? get _returnedAt =>
      _h?.returnProviderAt ?? _tlAt('returned') ?? widget.booking?.serviceEndedAt;
  String? get _returnConfirmedAt =>
      _h?.returnOwnerConfirmedAt ??
      _h?.returnAutoConfirmedAt ??
      _tlAt('return_confirmed') ??
      _tlAt('completed');

  static String _fmt(BuildContext context, DateTime? d) {
    if (d == null) return '';
    final l = d.toLocal();
    final now = DateTime.now();
    final loc = MaterialLocalizations.of(context);
    final time = loc.formatTimeOfDay(TimeOfDay.fromDateTime(l),
        alwaysUse24HourFormat: true);
    final sameDay =
        l.year == now.year && l.month == now.month && l.day == now.day;
    if (sameDay) return time;
    return '${loc.formatShortMonthDay(l)} · $time';
  }

  static DateTime? _parse(String? iso) =>
      iso == null ? null : DateTime.tryParse(iso);

  @override
  Widget build(BuildContext context) {
    if (!widget.isPaid) return const SizedBox.shrink();
    final st = _status;
    final accent = _accent;

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(top: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: accent.withValues(alpha: 0.18), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30.w,
                height: 30.w,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9.r),
                ),
                child: Icon(Icons.verified_user_rounded,
                    color: accent, size: 16.sp),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: InterText(
                  text: 'service_card_header'.tr,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_awaitingMe(st)) _badge(context, 'v565_ho_awaiting_you'.tr, accent),
            ],
          ),
          SizedBox(height: 12.h),
          _timeline(context, accent),
          ..._reminder(context),
          SizedBox(height: 10.h),
          ..._buildBody(context, st, accent),
        ],
      ),
    );
  }

  bool _awaitingMe(String st) {
    if (_isProvider) return false;
    if (st == 'confirmed' || st == 'disputed') return false;
    return (_pickupAwaitingOwner && widget.onConfirmPickup != null) ||
        st == 'awaiting_confirmation' ||
        (_returned && !_returnConfirmed);
  }

  Widget _badge(BuildContext context, String text, Color c) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: InterText(
        text: text,
        fontSize: 10.sp,
        fontWeight: FontWeight.w700,
        color: c,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  // ── Chronologie prévu / récupéré / rendu / confirmé ──────────────────────
  Widget _timeline(BuildContext context, Color accent) {
    final b = widget.booking;
    final planned = b?.plannedStart;
    final steps = <_Step>[
      _Step(
        label: 'v565_ho_step_planned'.tr,
        at: planned,
        done: true,
        current: !_pickedUp,
      ),
      _Step(
        label: 'v565_ho_step_picked_up'.tr,
        at: _parse(_pickedUpAt),
        done: _pickedUp,
        current: _pickedUp && !_returned,
        note: _pickedUp
            ? (_pickupConfirmed
                ? [
                    _h?.pickupAutoConfirmedAt != null
                        ? 'v565_ho_confirmed_auto'.tr
                        : 'v565_ho_confirmed_by_owner'.tr,
                    if (_parse(_pickupConfirmedAt) != null)
                      _fmt(context, _parse(_pickupConfirmedAt)),
                  ].join(' ')
                : (_h != null ? 'v565_ho_pending_owner'.tr : null))
            : null,
        photoUrl: b?.pickupProofUrl,
        hasGps: _h?.pickupLat != null,
      ),
      _Step(
        label: 'v565_ho_step_returned'.tr,
        at: _parse(_returnedAt),
        done: _returned,
        current: _returned && !_returnConfirmed,
        photoUrl: b?.returnProofUrl,
        hasGps: _h?.returnLat != null,
      ),
      _Step(
        label: 'v565_ho_step_confirmed'.tr,
        at: _parse(_returnConfirmedAt),
        done: _returnConfirmed,
        current: _returnConfirmed,
        note: _returnConfirmed
            ? (_h?.returnAutoConfirmedAt != null
                ? 'v565_ho_confirmed_auto'.tr
                : null)
            : null,
      ),
    ];

    final grey = AppColors.textSecondary(context).withValues(alpha: 0.35);
    return Column(
      children: [
        for (int i = 0; i < steps.length; i++)
          _stepRow(context, steps[i], accent, grey, last: i == steps.length - 1),
      ],
    );
  }

  Widget _stepRow(BuildContext context, _Step s, Color accent, Color grey,
      {required bool last}) {
    final c = s.done ? accent : grey;
    final primary = AppColors.textPrimary(context);
    final secondary = AppColors.textSecondary(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 22.w,
          child: Column(
            children: [
              Container(
                width: 14.w,
                height: 14.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: s.done ? accent : Colors.transparent,
                  border: Border.all(
                    color: s.current && !s.done ? accent : c,
                    width: 2,
                  ),
                ),
                child: s.done
                    ? Icon(Icons.check_rounded, size: 9.sp, color: Colors.white)
                    : null,
              ),
              if (!last)
                Container(
                  width: 2,
                  height: 22.h,
                  color: s.done ? accent.withValues(alpha: 0.5) : grey,
                ),
            ],
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: last ? 0 : 6.h),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: InterText(
                              text: s.label,
                              fontSize: 13.sp,
                              fontWeight:
                                  s.done || s.current ? FontWeight.w700 : FontWeight.w500,
                              color: s.done || s.current ? primary : secondary,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (s.hasGps) ...[
                            SizedBox(width: 4.w),
                            Icon(Icons.location_on_rounded,
                                size: 13.sp, color: accent),
                          ],
                        ],
                      ),
                      if (s.at != null || s.note != null)
                        InterText(
                          text: [
                            if (s.at != null) _fmt(context, s.at),
                            if (s.note != null) s.note!,
                          ].join(' · '),
                          fontSize: 11.sp,
                          color: secondary,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                if ((s.photoUrl ?? '').isNotEmpty) ...[
                  SizedBox(width: 8.w),
                  GestureDetector(
                    onTap: () => _openPhoto(context, s.photoUrl!),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8.r),
                      child: CachedNetworkImage(
                        imageUrl: s.photoUrl!,
                        width: 34.w,
                        height: 34.w,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _openPhoto(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.all(16.w),
        child: GestureDetector(
          onTap: () => Navigator.of(ctx).pop(),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16.r),
            child: CachedNetworkImage(imageUrl: url, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }

  // ── Rappels (30 min avant / à l'heure / retard 1 h) ──────────────────────
  List<Widget> _reminder(BuildContext context) {
    final b = widget.booking;
    if (b == null || _status == 'confirmed' || _status == 'disputed') {
      return const [];
    }
    final now = DateTime.now();
    String? text;
    Color color = _accent;
    if (!_pickedUp) {
      final start = b.plannedStart;
      if (start != null) {
        final diff = start.difference(now);
        if (diff.inMinutes > 0 && diff.inMinutes <= 30) {
          text = 'v565_ho_reminder_pickup'.tr
              .replaceAll('@min', diff.inMinutes.toString());
        } else if (diff.inMinutes <= 0 && now.difference(start).inMinutes < 60) {
          text = 'v565_ho_pickup_now'.tr;
        } else if (now.difference(start).inMinutes >= 60 &&
            now.difference(start).inHours < 48) {
          text = 'v565_ho_pickup_overdue'.tr;
          color = const Color(0xFFE8920A);
        }
      }
    } else if (!_returned) {
      final end = b.plannedEnd;
      if (end != null) {
        final diff = end.difference(now);
        if (diff.inMinutes > 0 && diff.inMinutes <= 30) {
          text = 'v565_ho_reminder_return'.tr
              .replaceAll('@min', diff.inMinutes.toString());
        } else if (diff.inMinutes <= 0 && now.difference(end).inMinutes < 60) {
          text = 'v565_ho_return_now'.tr;
        }
      }
    }
    if (text == null) return const [];
    return [
      SizedBox(height: 10.h),
      Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Row(
          children: [
            Icon(Icons.alarm_rounded, size: 16.sp, color: color),
            SizedBox(width: 8.w),
            Expanded(
              child: InterText(
                text: text,
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: color,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    ];
  }

  // ── Corps : boutons et états ─────────────────────────────────────────────
  List<Widget> _buildBody(BuildContext context, String st, Color accent) {
    if (st == 'confirmed') {
      return [_infoLine(context, '✅ ${'service_card_confirmed'.tr}', green: true)];
    }
    if (st == 'disputed') {
      return [
        _infoLine(
          context,
          '⚠️ ${(_isProvider ? 'service_card_disputed_provider' : 'service_card_disputed_owner').tr}',
          warn: true,
        ),
      ];
    }

    if (_isProvider) {
      if (_returned && !_returnConfirmed) {
        return [
          _infoLine(context, 'service_card_awaiting_owner'.tr),
          SizedBox(height: 4.h),
          _hint(context, 'v565_ho_auto_confirm_hint'.tr),
        ];
      }
      if (_pickedUp) {
        return [
          if (_h != null && !_pickupConfirmed) ...[
            _infoLine(context, 'v565_ho_pending_owner_pickup'.tr),
            SizedBox(height: 4.h),
            _hint(context, 'v565_ho_auto_confirm_hint'.tr),
          ] else
            _infoLine(context, 'service_card_in_progress'.tr),
          SizedBox(height: 10.h),
          _actionButton(
            action: 'complete',
            label: 'v565_ho_btn_returned'.tr,
            icon: Icons.home_rounded,
            onTap: widget.onComplete,
            color: const Color(0xFF16A34A),
          ),
        ];
      }
      return [
        _actionButton(
          action: 'start',
          label: 'v565_ho_btn_picked_up'.tr,
          icon: Icons.pets_rounded,
          onTap: widget.onStart,
          color: accent,
        ),
      ];
    }

    // OWNER
    if (_returned && !_returnConfirmed) {
      return [
        InterText(
          text: 'service_card_owner_confirm_desc'.tr,
          fontSize: 13.sp,
          color: AppColors.textSecondary(context),
        ),
        SizedBox(height: 4.h),
        _hint(context, 'v565_ho_auto_confirm_hint'.tr),
        SizedBox(height: 12.h),
        Row(
          children: [
            Expanded(
              child: _actionButton(
                action: 'confirm',
                label: 'v565_ho_btn_confirm_return'.tr,
                icon: Icons.check_circle_rounded,
                onTap: widget.onConfirm,
                color: const Color(0xFF16A34A),
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: _actionButton(
                action: 'dispute',
                label: 'service_card_dispute_btn'.tr,
                onTap: widget.onDispute,
                color: const Color(0xFFDC2626),
                outlined: true,
              ),
            ),
          ],
        ),
      ];
    }
    if (_pickupAwaitingOwner && widget.onConfirmPickup != null) {
      return [
        InterText(
          text: 'v565_ho_owner_confirm_pickup_desc'.tr,
          fontSize: 13.sp,
          color: AppColors.textSecondary(context),
        ),
        SizedBox(height: 4.h),
        _hint(context, 'v565_ho_auto_confirm_hint'.tr),
        SizedBox(height: 12.h),
        _actionButton(
          action: 'confirm_pickup',
          label: 'v565_ho_btn_confirm_pickup'.tr,
          icon: Icons.check_circle_rounded,
          onTap: widget.onConfirmPickup,
          color: accent,
        ),
      ];
    }
    if (_pickedUp) {
      return [_infoLine(context, 'service_card_owner_in_progress'.tr)];
    }
    return [_infoLine(context, 'service_card_owner_not_started'.tr)];
  }

  Widget _hint(BuildContext context, String text) {
    return InterText(
      text: text,
      fontSize: 11.sp,
      color: AppColors.textSecondary(context),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _infoLine(BuildContext context, String text,
      {bool green = false, bool warn = false}) {
    final c = green
        ? const Color(0xFF16A34A)
        : warn
            ? const Color(0xFFDC2626)
            : AppColors.textSecondary(context);
    return InterText(
      text: text,
      fontSize: 13.sp,
      fontWeight: (green || warn) ? FontWeight.w700 : FontWeight.w500,
      color: c,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _actionButton({
    required String action,
    required String label,
    required Future<void> Function()? onTap,
    required Color color,
    IconData? icon,
    bool outlined = false,
  }) {
    final spinning = widget.busy && _pending == action;
    final disabled = widget.busy || onTap == null;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: disabled
            ? null
            : () {
                setState(() => _pending = action);
                onTap();
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: outlined ? Colors.transparent : color,
          foregroundColor: outlined ? color : Colors.white,
          disabledBackgroundColor:
              outlined ? Colors.transparent : color.withValues(alpha: 0.4),
          elevation: 0,
          side: outlined ? BorderSide(color: color, width: 1.3) : null,
          padding: EdgeInsets.symmetric(vertical: 13.h, horizontal: 10.w),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14.r),
          ),
        ),
        child: spinning
            ? SizedBox(
                width: 18.w,
                height: 18.w,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: outlined ? color : Colors.white,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 16.sp, color: outlined ? color : Colors.white),
                    SizedBox(width: 6.w),
                  ],
                  Flexible(
                    child: InterText(
                      text: label,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      color: outlined ? color : Colors.white,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _Step {
  final String label;
  final DateTime? at;
  final bool done;
  final bool current;
  final String? note;
  final String? photoUrl;
  final bool hasGps;
  const _Step({
    required this.label,
    required this.at,
    required this.done,
    required this.current,
    this.note,
    this.photoUrl,
    this.hasGps = false,
  });
}

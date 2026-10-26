// 624 (PAM, 26/10/2026) — « Poser mes dates » : petite feuille avec les DATES
// SEULES (une date + une heure pour une balade), comme `PostDatesEditor620`
// du site de LEO. Aucun code postal, aucun animal, aucun lieu : FLO a mesuré
// que 27 demandes réelles sur 28 n'ont pas de code postal, et l'ancien
// formulaire complet l'exigeait (publish_reservation_request_controller).
// PATCH /posts/:id { dateMode, startDate, endDate } : le serveur recalcule les
// candidatures en attente (totaux frais compris) et prévient les candidats.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../../controllers/applications_controller.dart';
import '../../../../models/post_model.dart';
import '../../../../repositories/post_repository.dart';
import '../../../../utils/app_colors.dart';
import '../../../../utils/bottom_inset.dart';
import '../../../../widgets/action_banner_kit.dart';
import '../../../../widgets/app_text.dart';

/// Vrai si la demande est une balade seule (une date + une heure).
bool postIsWalkOnly2610(PostModel p) =>
    p.serviceTypes.isNotEmpty && p.serviceTypes.every((s) => s == 'dog_walking');

/// Dates envoyées au serveur. Balade : début = jour + heure locale, fin =
/// début + durée (60 min par défaut, 15 au moins). Garde : jour début / fin.
/// Renvoie null si la saisie est incomplète ou dans le désordre. Pure.
({String dateMode, DateTime start, DateTime end})? postDatesPayload2610({
  required bool walk,
  required String mode,
  required DateTime? startDay,
  required DateTime? endDay,
  TimeOfDay? time,
  int? walkMinutes,
}) {
  if (startDay == null) return null;
  if (walk) {
    final t = time ?? const TimeOfDay(hour: 10, minute: 0);
    final s = DateTime(startDay.year, startDay.month, startDay.day, t.hour, t.minute);
    final m = (walkMinutes ?? 60) < 15 ? 15 : (walkMinutes ?? 60);
    return (dateMode: 'exact', start: s, end: s.add(Duration(minutes: m)));
  }
  if (endDay == null) return null;
  final s = DateTime(startDay.year, startDay.month, startDay.day);
  final e = DateTime(endDay.year, endDay.month, endDay.day);
  if (e.isBefore(s)) return null;
  return (dateMode: mode == 'approx' ? 'approx' : 'exact', start: s, end: e);
}

class PostDatesSheet2610 {
  PostDatesSheet2610._();

  /// Ouvre la feuille ; renvoie vrai si les dates ont été enregistrées.
  static Future<bool> show(BuildContext context, PostModel post) async {
    final r = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DatesSheet(post: post),
    );
    return r == true;
  }
}

class _DatesSheet extends StatefulWidget {
  const _DatesSheet({required this.post});
  final PostModel post;

  @override
  State<_DatesSheet> createState() => _DatesSheetState();
}

class _DatesSheetState extends State<_DatesSheet> {
  late String _mode = widget.post.dateMode == 'approx' ? 'approx' : 'exact';
  DateTime? _start;
  DateTime? _end;
  TimeOfDay _time = const TimeOfDay(hour: 10, minute: 0);
  bool _busy = false;
  String _err = '';

  bool get _walk => postIsWalkOnly2610(widget.post);

  @override
  void initState() {
    super.initState();
    final p = widget.post;
    if (p.dateMode != 'tbd') {
      _start = p.startDate?.toLocal();
      _end = p.endDate?.toLocal();
      final s = p.startDate?.toLocal();
      if (s != null && (s.hour != 0 || s.minute != 0)) {
        _time = TimeOfDay(hour: s.hour, minute: s.minute);
      }
    }
  }

  String _fmt(DateTime? d) => d == null
      ? '—'
      : DateFormat.yMMMEd(Get.locale?.languageCode ?? 'fr').format(d);

  Future<void> _pickDay({required bool start}) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final first = start ? today : (_start ?? today);
    final init = (start ? _start : _end) ?? first;
    final d = await showDatePicker(
      context: context,
      initialDate: init.isBefore(first) ? first : init,
      firstDate: first,
      lastDate: today.add(const Duration(days: 730)),
    );
    if (d == null || !mounted) return;
    setState(() {
      _err = '';
      if (start) {
        _start = d;
        // Fin pré-remplie au jour du début (comme le site).
        if (_end == null || _end!.isBefore(d)) _end = d;
      } else {
        _end = d;
      }
    });
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: _time);
    if (t != null && mounted) setState(() => _time = t);
  }

  Future<void> _save() async {
    final pl = postDatesPayload2610(
      walk: _walk,
      mode: _mode,
      startDay: _start,
      endDay: _end,
      time: _time,
      walkMinutes: widget.post.walkDurationMinutes,
    );
    if (pl == null) {
      setState(() => _err = (_start == null || (!_walk && _end == null))
          ? 'cand2610_dates_period_required'.tr
          : 'cand2610_dates_order'.tr);
      return;
    }
    setState(() {
      _busy = true;
      _err = '';
    });
    try {
      await Get.find<PostRepository>().updatePost(
        widget.post.id,
        dateMode: pl.dateMode,
        // Balade : instant précis (heure locale → UTC) ; garde : le jour à
        // 00 h UTC, comme le site (`new Date("AAAA-MM-JJ").toISOString()`).
        startDate: _walk
            ? pl.start.toUtc()
            : DateTime.utc(pl.start.year, pl.start.month, pl.start.day),
        endDate: _walk
            ? pl.end.toUtc()
            : DateTime.utc(pl.end.year, pl.end.month, pl.end.day),
      );
      // Les totaux recalculés par le serveur s'affichent tout de suite.
      if (Get.isRegistered<ApplicationsController>()) {
        await Get.find<ApplicationsController>().loadApplications();
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _err = 'cand2610_editor_error'.tr;
        });
      }
    }
  }

  Widget _field(String label, String value, VoidCallback onTap, Key key) {
    return Expanded(
      child: GestureDetector(
        key: key,
        behavior: HitTestBehavior.opaque,
        onTap: _busy ? null : onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
          decoration: BoxDecoration(
            color: AppColors.card(context),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: AppColors.primaryColor.withValues(alpha: 0.45)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InterText(
                text: label,
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary(context),
              ),
              SizedBox(height: 3.h),
              InterText(
                text: value,
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary(context),
                maxLines: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tone = AppColors.primaryColor;
    final on = AppColors.accentOn(context, tone);
    Widget modeChip(String m) {
      final sel = _mode == m;
      return GestureDetector(
        key: Key('dates2610_mode_$m'),
        onTap: _busy ? null : () => setState(() => _mode = m),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: sel ? tone.withValues(alpha: 0.12) : AppColors.card(context),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: sel ? tone : AppColors.divider(context), width: 1.5),
          ),
          child: InterText(
            text: 'cand2610_mode_$m'.tr,
            fontSize: 13.sp,
            fontWeight: FontWeight.w700,
            color: sel ? on : AppColors.textPrimary(context),
          ),
        ),
      );
    }

    final approx = !_walk && _mode == 'approx';
    return Container(
      key: const Key('dates2610_sheet'),
      decoration: BoxDecoration(
        color: AppColors.scaffold(context),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 18.h + appBottomInset(context)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44.w,
              height: 4.h,
              margin: EdgeInsets.only(bottom: 12.h),
              decoration: BoxDecoration(
                color: AppColors.divider(context),
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
          ),
          Row(
            children: [
              Icon(Icons.edit_calendar_rounded, size: 20.sp, color: on),
              SizedBox(width: 8.w),
              Expanded(
                child: PoppinsText(
                  text: 'cand2610_editor_title'.tr,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary(context),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          if (!_walk) ...[
            Wrap(spacing: 8.w, children: [modeChip('exact'), modeChip('approx')]),
            SizedBox(height: 12.h),
          ],
          Row(
            children: [
              _field(
                _walk
                    ? 'cand2610_date_label'.tr
                    : (approx ? 'cand2610_approx_from'.tr : 'edit_post_start_date'.tr),
                _fmt(_start),
                () => _pickDay(start: true),
                const Key('dates2610_start'),
              ),
              SizedBox(width: 8.w),
              _walk
                  ? _field('cand2610_time_label'.tr, _time.format(context), _pickTime,
                      const Key('dates2610_time'))
                  : _field(
                      approx ? 'cand2610_approx_to'.tr : 'edit_post_end_date'.tr,
                      _fmt(_end),
                      () => _pickDay(start: false),
                      const Key('dates2610_end')),
            ],
          ),
          if (_err.isNotEmpty) ...[
            SizedBox(height: 10.h),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: InterText(
                text: _err,
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: on,
              ),
            ),
          ],
          SizedBox(height: 16.h),
          ActionPillButton(
            key: const Key('dates2610_save'),
            label: _busy ? 'cand2610_editor_saving'.tr : 'cand2610_editor_save'.tr,
            icon: Icons.check_rounded,
            tone: tone,
            expand: true,
            busy: _busy,
            onPressed: _save,
          ),
          SizedBox(height: 6.h),
          ActionPillButton(
            label: 'cand2610_editor_cancel'.tr,
            tone: AppColors.textSecondary(context),
            kind: ActionPillKind.ghost,
            expand: true,
            onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }
}

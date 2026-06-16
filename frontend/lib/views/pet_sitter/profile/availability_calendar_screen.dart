import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/storage_keys.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';

/// Sprint 5 step 6 — Sitter / Walker availability calendar.
/// Tap a day to toggle its availability.
/// Green = available, red = blocked, plain = not set.
///
/// v426 — rendu role-aware : un walker partage le même écran mais doit taper
/// /walkers/me/availability (les /sitters/me/* renvoient 403 pour un walker →
/// le calendrier ne sauvait rien). Le rôle est résolu automatiquement depuis
/// le profil persisté si non fourni explicitement.
class AvailabilityCalendarScreen extends StatefulWidget {
  const AvailabilityCalendarScreen({super.key, this.role});

  /// 'sitter' | 'walker'. Si null, résolu depuis le profil persisté.
  final String? role;

  @override
  State<AvailabilityCalendarScreen> createState() =>
      _AvailabilityCalendarScreenState();
}

class _AvailabilityCalendarScreenState
    extends State<AvailabilityCalendarScreen> {
  final ApiClient _api = Get.isRegistered<ApiClient>()
      ? Get.find<ApiClient>()
      : ApiClient();
  final Set<DateTime> _available = <DateTime>{};
  final Set<DateTime> _unavailable = <DateTime>{};
  DateTime _focusedDay = DateTime.now();
  bool _saving = false;

  /// Resolved API base — '/walkers' for walkers, '/sitters' otherwise.
  late final String _base = _resolveBase();

  String _resolveBase() {
    var role = widget.role;
    if (role == null || role.isEmpty) {
      try {
        final profile =
            GetStorage().read<Map<String, dynamic>>(StorageKeys.userProfile);
        role = profile?['role']?.toString() ??
            profile?['activeRole']?.toString();
      } catch (_) {
        role = null;
      }
    }
    return role == 'walker' ? '/walkers' : '/sitters';
  }

  DateTime _utcMidnight(DateTime d) =>
      DateTime.utc(d.year, d.month, d.day);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final resp = await _api.get(
        '$_base/me/availability',
        requiresAuth: true,
      );
      if (resp is Map) {
        setState(() {
          _available
            ..clear()
            ..addAll(((resp['availableDates'] as List?) ?? [])
                .map((e) => DateTime.tryParse(e.toString()))
                .whereType<DateTime>()
                .map(_utcMidnight));
          _unavailable
            ..clear()
            ..addAll(((resp['unavailableDates'] as List?) ?? [])
                .map((e) => DateTime.tryParse(e.toString()))
                .whereType<DateTime>()
                .map(_utcMidnight));
        });
      }
    } catch (_) {
      // best effort
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _api.put(
        '$_base/me/availability',
        body: {
          'availableDates':
              _available.map((d) => d.toIso8601String()).toList(),
          'unavailableDates':
              _unavailable.map((d) => d.toIso8601String()).toList(),
        },
        requiresAuth: true,
      );
      CustomSnackbar.showSuccess(title: 'common_success', message: 'common_saved');
    } catch (e) {
      CustomSnackbar.showError(title: 'common_error', message: e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toggle(DateTime day) {
    final d = _utcMidnight(day);
    setState(() {
      if (_available.contains(d)) {
        _available.remove(d);
        _unavailable.add(d);
      } else if (_unavailable.contains(d)) {
        _unavailable.remove(d);
      } else {
        _available.add(d);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      appBar: AppBar(
        backgroundColor: AppColors.appBar(context),
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
        title: Text('availability_title'.tr, style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary(context))),
        actions: [
          IconButton(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? SizedBox(
                    width: 20.w,
                    height: 20.h,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
          ),
        ],
      ),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2024, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            // v441 — styles theme-aware : sans ça, table_calendar rend les
            // numéros de jour / en-têtes / libellés de semaine en texte sombre
            // → invisibles sur fond sombre (le bug « dark bleeding through »).
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary(context),
              ),
              leftChevronIcon: Icon(Icons.chevron_left,
                  color: AppColors.textPrimary(context)),
              rightChevronIcon: Icon(Icons.chevron_right,
                  color: AppColors.textPrimary(context)),
            ),
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: TextStyle(color: AppColors.textSecondary(context)),
              weekendStyle: TextStyle(color: AppColors.textSecondary(context)),
            ),
            calendarStyle: CalendarStyle(
              defaultTextStyle:
                  TextStyle(color: AppColors.textPrimary(context)),
              weekendTextStyle:
                  TextStyle(color: AppColors.textPrimary(context)),
              outsideTextStyle:
                  TextStyle(color: AppColors.textSecondary(context)),
              todayTextStyle: const TextStyle(color: Colors.white),
              todayDecoration: BoxDecoration(
                color: AppColors.primaryColor.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
            ),
            onDayLongPressed: (sel, foc) {
              setState(() => _focusedDay = foc);
              _toggle(sel);
            },
            onDaySelected: (sel, foc) {
              setState(() => _focusedDay = foc);
              _toggle(sel);
            },
            selectedDayPredicate: (day) => false,
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (ctx, day, focused) {
                final d = _utcMidnight(day);
                Color? bg;
                if (_available.contains(d)) bg = Colors.green.shade300;
                if (_unavailable.contains(d)) bg = Colors.red.shade300;
                if (bg == null) return null;
                return Container(
                  margin: EdgeInsets.all(4.w),
                  decoration: BoxDecoration(
                    color: bg,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${day.day}',
                    style: const TextStyle(color: Colors.white),
                  ),
                );
              },
            ),
          ),
          SizedBox(height: 16.h),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'availability_instructions'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary(context)),
            ),
          ),
        ],
      ),
    );
  }
}

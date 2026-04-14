import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';

/// Sprint 5 step 6 — Sitter availability calendar.
/// Tap a day to toggle its availability.
/// Green = available, red = blocked, plain = not set.
class AvailabilityCalendarScreen extends StatefulWidget {
  const AvailabilityCalendarScreen({super.key});

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
        '/sitters/me/availability',
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
        '/sitters/me/availability',
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
      appBar: AppBar(
        title: Text('Availability'),
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
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Tap a day: 1st tap = available (green), 2nd = blocked (red), 3rd = clear.',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

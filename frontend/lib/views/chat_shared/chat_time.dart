// v565 — formats de temps du chat, localisés sans initialisation intl :
// heure via MaterialLocalizations (suit la langue du téléphone).
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// « 14:05 » / « 2:05 PM » selon la locale.
String chatClock(BuildContext context, DateTime d) {
  try {
    return MaterialLocalizations.of(context)
        .formatTimeOfDay(TimeOfDay.fromDateTime(d));
  } catch (_) {
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Étiquette de jour pour les séparateurs : Aujourd'hui / Hier / date.
String chatDayLabel(BuildContext context, DateTime d) {
  final now = DateTime.now();
  if (_sameDay(d, now)) return 'cs_today'.tr;
  if (_sameDay(d, now.subtract(const Duration(days: 1)))) {
    return 'cs_yesterday'.tr;
  }
  try {
    return MaterialLocalizations.of(context).formatMediumDate(d);
  } catch (_) {
    return '${d.day}/${d.month}/${d.year}';
  }
}

/// Heure dans la liste des conversations : heure si aujourd'hui, « Hier »,
/// sinon date courte.
String chatListTime(BuildContext context, DateTime d) {
  final now = DateTime.now();
  if (_sameDay(d, now)) return chatClock(context, d);
  if (_sameDay(d, now.subtract(const Duration(days: 1)))) {
    return 'cs_yesterday'.tr;
  }
  try {
    return MaterialLocalizations.of(context).formatShortMonthDay(d);
  } catch (_) {
    return '${d.day}/${d.month}';
  }
}

/// « il y a 5 min » (clés time_* existantes).
String chatRelative(DateTime d) {
  final diff = DateTime.now().difference(d);
  if (diff.inDays > 0) {
    return 'time_days_ago'.trParams({'count': diff.inDays.toString()});
  }
  if (diff.inHours > 0) {
    return 'time_hours_ago'.trParams({'count': diff.inHours.toString()});
  }
  if (diff.inMinutes > 0) {
    return 'time_minutes_ago'.trParams({'count': diff.inMinutes.toString()});
  }
  return 'time_just_now'.tr;
}

/// Statut d'en-tête : « En ligne » / « Vu il y a 5 min » / « Hors ligne ».
String chatPresenceLabel(bool online, DateTime? lastSeen) {
  if (online) return 'cs_online'.tr;
  if (lastSeen == null) return 'cs_offline'.tr;
  return 'cs_last_seen'.trParams({'when': chatRelative(lastSeen)});
}

/// « 0:07 » pour une durée en secondes.
String chatDuration(num? seconds) {
  final s = (seconds ?? 0).round();
  final m = s ~/ 60;
  final r = (s % 60).toString().padLeft(2, '0');
  return '$m:$r';
}

bool chatSameDay(DateTime a, DateTime b) => _sameDay(a, b);

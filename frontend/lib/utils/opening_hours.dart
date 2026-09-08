/// v559 — Daniel (option A) : « horaires et téléphone dans la fiche du lieu,
/// sans lien sortant ». Les lieux viennent d'OpenStreetMap, dont le champ
/// `opening_hours` a une syntaxe normalisée (« Mo-Fr 09:00-19:00; Sa
/// 09:00-13:00 », « 24/7 », « Tu-Su 10:00-20:00; Mo off »…). On lit le
/// sous-ensemble courant et on renvoie « ouvert jusqu'à… » / « fermé, ouvre
/// … ». Tout ce qu'on ne comprend pas (texte libre, jours fériés, semaines
/// paires…) → `null` : l'écran affiche alors les horaires bruts, jamais un
/// statut faux. Même logique côté site (website/src/lib/openingHours.ts) —
/// garder les deux fichiers alignés.
class OpeningHoursStatus {
  const OpeningHoursStatus({
    required this.isOpen,
    this.always = false,
    this.closesAt,
    this.opensAt,
  });

  /// Ouvert en ce moment.
  final bool isOpen;

  /// « 24/7 » : ouvert en permanence.
  final bool always;

  /// Si ouvert : heure de fermeture (aujourd'hui, ou demain matin si la
  /// plage passe minuit).
  final DateTime? closesAt;

  /// Si fermé : prochaine ouverture connue (dans les 7 jours), sinon null.
  final DateTime? opensAt;
}

class _Range {
  const _Range(this.start, this.end); // minutes depuis minuit ; end > 1440 = passe minuit
  final int start;
  final int end;
}

const _dayNames = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

final _daySpecRe = RegExp(
  r'^((?:(?:Mo|Tu|We|Th|Fr|Sa|Su)(?:-(?:Mo|Tu|We|Th|Fr|Sa|Su))?)(?:\s*,\s*(?:Mo|Tu|We|Th|Fr|Sa|Su)(?:-(?:Mo|Tu|We|Th|Fr|Sa|Su))?)*)\s*(.*)$',
);
final _timeRangeRe = RegExp(r'^(\d{1,2}):(\d{2})\s*-\s*(\d{1,2}):(\d{2})$');
final _ruleSplitRe = RegExp(r',\s*(?=(?:Mo|Tu|We|Th|Fr|Sa|Su|PH|SH)\b)');

/// Analyse `raw` et évalue l'état à l'instant `now` (heure locale du
/// téléphone — les lieux sont à proximité, donc même fuseau).
/// Retourne null si la syntaxe n'est pas comprise.
OpeningHoursStatus? evaluateOpeningHours(String raw, DateTime now) {
  final text = raw.trim();
  if (text.isEmpty) return null;
  if (text == '24/7') {
    return const OpeningHoursStatus(isOpen: true, always: true);
  }
  final week = List<List<_Range>>.generate(7, (_) => <_Range>[]);
  bool anyRule = false;

  for (final part in text.split(';')) {
    final chunk = part.trim();
    if (chunk.isEmpty) continue;
    // « Mo-Fr 10:00-18:00, Sa 09:00-15:00 » = deux règles ; mais « Su,Mo off »
    // = UNE règle sur deux jours : un morceau qui n'est qu'une liste de jours
    // est recollé au suivant.
    final pieces = chunk.split(_ruleSplitRe).map((p) => p.trim()).toList();
    final rules = <String>[];
    String pending = '';
    for (final p in pieces) {
      if (p.isEmpty) continue;
      final onlyDays = _daySpecRe.firstMatch(p);
      if (onlyDays != null && (onlyDays.group(2) ?? '').trim().isEmpty) {
        pending = pending.isEmpty ? p : '$pending,$p';
        continue;
      }
      rules.add(pending.isEmpty ? p : '$pending,$p');
      pending = '';
    }
    if (pending.isNotEmpty) rules.add(pending);
    for (final ruleRaw in rules) {
      final rule = ruleRaw.trim();
      if (rule.isEmpty) continue;
      // Jours fériés / vacances scolaires : hors périmètre, on ignore la règle.
      if (rule.startsWith('PH') || rule.startsWith('SH')) continue;

      List<int> days;
      String rest;
      final m = _daySpecRe.firstMatch(rule);
      if (m != null && (m.group(1) ?? '').isNotEmpty) {
        days = _expandDays(m.group(1)!);
        if (days.isEmpty) return null;
        rest = (m.group(2) ?? '').trim();
      } else {
        days = List<int>.generate(7, (i) => i);
        rest = rule;
      }

      final lower = rest.toLowerCase();
      if (rest.isEmpty || lower == '24/7' || lower == 'open') {
        for (final d in days) {
          week[d] = [const _Range(0, 1440)];
        }
        anyRule = true;
        continue;
      }
      if (lower == 'off' || lower == 'closed') {
        for (final d in days) {
          week[d] = <_Range>[];
        }
        anyRule = true;
        continue;
      }
      final ranges = <_Range>[];
      for (final tr in rest.split(',')) {
        final tm = _timeRangeRe.firstMatch(tr.trim());
        if (tm == null) return null; // syntaxe inconnue → pas de statut
        final s = int.parse(tm.group(1)!) * 60 + int.parse(tm.group(2)!);
        var e = int.parse(tm.group(3)!) * 60 + int.parse(tm.group(4)!);
        if (s > 1440 || e > 1440 + 720) return null;
        if (e <= s) e += 1440; // passe minuit
        ranges.add(_Range(s, e));
      }
      for (final d in days) {
        week[d] = List<_Range>.from(ranges);
      }
      anyRule = true;
    }
  }
  if (!anyRule) return null;

  final today = now.weekday - 1; // Mo = 0
  final nowMin = now.hour * 60 + now.minute;
  final midnight = DateTime(now.year, now.month, now.day);

  // Ouvert maintenant ? (plage du jour, ou plage d'hier qui passe minuit)
  for (final r in week[today]) {
    if (r.start <= nowMin && nowMin < r.end) {
      return OpeningHoursStatus(
        isOpen: true,
        closesAt: midnight.add(Duration(minutes: r.end)),
      );
    }
  }
  final yesterday = (today + 6) % 7;
  for (final r in week[yesterday]) {
    if (r.end > 1440 && nowMin < r.end - 1440) {
      return OpeningHoursStatus(
        isOpen: true,
        closesAt: midnight.add(Duration(minutes: r.end - 1440)),
      );
    }
  }

  // Fermé : prochaine ouverture dans les 7 jours.
  for (int offset = 0; offset < 8; offset++) {
    final d = (today + offset) % 7;
    final starts = week[d].map((r) => r.start).toList()..sort();
    for (final s in starts) {
      if (offset == 0 && s <= nowMin) continue;
      return OpeningHoursStatus(
        isOpen: false,
        opensAt: midnight.add(Duration(days: offset, minutes: s)),
      );
    }
  }
  return const OpeningHoursStatus(isOpen: false);
}

List<int> _expandDays(String spec) {
  final out = <int>{};
  for (final item in spec.split(',')) {
    final t = item.trim();
    if (t.contains('-')) {
      final p = t.split('-');
      final a = _dayNames.indexOf(p[0].trim());
      final b = _dayNames.indexOf(p[1].trim());
      if (a < 0 || b < 0) return const [];
      var i = a;
      while (true) {
        out.add(i);
        if (i == b) break;
        i = (i + 1) % 7;
      }
    } else {
      final a = _dayNames.indexOf(t);
      if (a < 0) return const [];
      out.add(a);
    }
  }
  return out.toList()..sort();
}

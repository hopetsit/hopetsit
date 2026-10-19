// 618 (PAM, 19/10/2026) — COLLECTION DU MOIS (PROCHAIN_BUILD_618 §C,
// décision de Daniel du 19/10).
//
// Chaque mois civil (Europe/Paris), les 5 peluches dans le thème du mois
// (novembre = automne, décembre = hiver…). Les 5 attrapées pendant le mois
// = +500 PawPoints (×2 Premium) + badge « Collection <mois> <année> ».
// Démarre le 01/11/2026 (octobre = la collection d'origine).
//
// Le thème est DESSINÉ EN CODE par-dessus la peluche (écharpe, bonnet,
// flocons, cœurs…) : aucune image externe. Le serveur fait foi (contrat
// `GET /plush/collection` → `monthly`) ; sans `monthly` (ancien serveur),
// l'app n'affiche que la date du prochain départ, jamais un faux compteur.
//
// Réponse à la question de Daniel « que faire une fois toute la collection
// chopée ? » : UN message clair, « Collection complète ! Prochaine
// collection : celle de novembre, dès le 1er ».
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../utils/app_colors.dart';
import 'pawmap_plush607.dart';

/// Premier mois de la collection du mois (clé 'YYYY-MM').
const String kPawMonthlyStartKey618 = '2026-11';

/// Couleur par défaut de chaque thème (le serveur envoie la sienne).
const Map<String, Color> kPawMonthThemeColors618 = <String, Color>{
  'snow': Color(0xFF5B8DEF),
  'hearts': Color(0xFFE0457B),
  'spring': Color(0xFF3FA34D),
  'flowers': Color(0xFFD9569E),
  'picnic': Color(0xFFE07A2E),
  'beach': Color(0xFF1E9BD7),
  'summer': Color(0xFFF2A516),
  'holidays': Color(0xFF14A39A),
  'back_to_school': Color(0xFF7A3FB8),
  'halloween': Color(0xFFE8651A),
  'autumn': Color(0xFFC2571A),
  'winter': Color(0xFF2F6FD6),
};

/// Thème de chaque mois (miroir de MONTH_THEMES côté serveur).
const List<String> kPawMonthThemes618 = <String>[
  'snow', 'hearts', 'spring', 'flowers', 'picnic', 'beach',
  'summer', 'holidays', 'back_to_school', 'halloween', 'autumn', 'winter',
];

Color _hexColor(String? h, Color fallback) {
  if (h == null) return fallback;
  final c = h.replaceAll('#', '');
  if (c.length != 6) return fallback;
  final v = int.tryParse(c, radix: 16);
  return v == null ? fallback : Color(0xFF000000 | v);
}

/// Nom traduit du mois (1..12).
String pawMonthName618(int month) => 'month618_m${month.clamp(1, 12)}'.tr;

/// Mois (1..12) d'une clé 'YYYY-MM' ; null si illisible.
int? pawMonthOfKey618(String key) {
  if (key.length < 7) return null;
  final m = int.tryParse(key.substring(5, 7));
  return (m != null && m >= 1 && m <= 12) ? m : null;
}

/// Clé du mois suivant ('2026-11' → '2026-12', '2026-12' → '2027-01').
String pawNextMonthKey618(String key) {
  final y = int.tryParse(key.substring(0, 4)) ?? 2026;
  final m = pawMonthOfKey618(key) ?? 10;
  final ny = m == 12 ? y + 1 : y;
  final nm = m == 12 ? 1 : m + 1;
  return '$ny-${nm.toString().padLeft(2, '0')}';
}

/// La collection du mois, telle que le serveur la décrit.
class PawMonthly618 {
  const PawMonthly618({
    required this.key,
    required this.theme,
    required this.label,
    required this.color,
    required this.caughtTypes,
    required this.complete,
    required this.bonusPoints,
    this.startsAt,
    this.endsAt,
    this.bonusGranted = false,
  });

  final String key;
  final String theme;
  final String label;
  final Color color;
  final List<String> caughtTypes;
  final bool complete;
  final int bonusPoints;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final bool bonusGranted;

  int get month => pawMonthOfKey618(key) ?? 11;

  bool startedAt(DateTime now) => startsAt == null || !now.isBefore(startsAt!);

  /// null si absent ou illisible (ancien serveur).
  static PawMonthly618? fromJson(dynamic j, {String? lang}) {
    if (j is! Map) return null;
    final key = (j['key'] ?? '').toString();
    if (pawMonthOfKey618(key) == null) return null;
    final theme = (j['theme'] ?? '').toString();
    final labels = j['labels'];
    String label = (j['label'] ?? '').toString();
    if (lang != null && labels is Map && (labels[lang] ?? '').toString().isNotEmpty) {
      label = labels[lang].toString();
    }
    final caught = (j['caughtTypes'] as List? ?? const [])
        .map((e) => e.toString())
        .where(kPawPlushTypes.contains)
        .toSet()
        .toList();
    return PawMonthly618(
      key: key,
      theme: theme,
      label: label,
      color: _hexColor(j['color']?.toString(), kPawMonthThemeColors618[theme] ?? const Color(0xFFC2571A)),
      caughtTypes: caught,
      complete: j['complete'] == true || caught.length >= kPawPlushTypes.length,
      bonusPoints: (j['bonusPoints'] as num?)?.toInt() ?? 500,
      startsAt: DateTime.tryParse((j['startsAt'] ?? '').toString()),
      endsAt: DateTime.tryParse((j['endsAt'] ?? '').toString()),
      bonusGranted: j['bonusGranted'] == true,
    );
  }
}

/// Compte à rebours : avant le départ « Départ dans 12 j, le 1er », pendant
/// le mois « Encore 5 j » (heures sous un jour). Vide si dates inconnues.
String pawMonthlyCountdown618(PawMonthly618 m, DateTime now) {
  if (m.startsAt != null && now.isBefore(m.startsAt!)) {
    final d = m.startsAt!.difference(now);
    if (d.inHours < 24) {
      return 'month618_starts_in_hours'.trParams({'n': '${math.max(1, d.inHours)}'});
    }
    return 'month618_starts_in_days'.trParams({'n': '${(d.inHours / 24).ceil()}'});
  }
  if (m.endsAt != null && now.isBefore(m.endsAt!)) {
    final d = m.endsAt!.difference(now);
    if (d.inHours < 24) {
      return 'month618_ends_in_hours'.trParams({'n': '${math.max(1, d.inHours)}'});
    }
    return 'month618_ends_in_days'.trParams({'n': '${(d.inHours / 24).ceil()}'});
  }
  return '';
}

/// Le message de fin, ou '' s'il n'y a rien à dire.
/// · collection d'origine complète et collection du mois pas commencée (ou
///   absente) → « Collection complète ! Prochaine collection : celle de
///   novembre, dès le 1er » ;
/// · collection du mois en cours complète → « Collection de novembre
///   complète ! Prochaine : celle de décembre, dès le 1er ».
String pawCollectionDoneMessage618({
  required bool originComplete,
  required PawMonthly618? monthly,
  required DateTime now,
}) {
  if (monthly != null && monthly.startedAt(now)) {
    if (!monthly.complete) return '';
    final next = pawMonthOfKey618(pawNextMonthKey618(monthly.key)) ?? 12;
    return 'month618_month_done'.trParams({
      'month': pawMonthName618(monthly.month),
      'next': pawMonthName618(next),
    });
  }
  if (!originComplete) return '';
  final int month = monthly?.month ?? _nextCollectionMonth(now);
  return 'month618_origin_done'.trParams({'month': pawMonthName618(month)});
}

/// Sans contrat serveur : le prochain 1er du mois, jamais avant novembre 2026.
int _nextCollectionMonth(DateTime now) {
  final start = DateTime(2026, 11, 1);
  if (now.isBefore(start)) return 11;
  return now.month == 12 ? 1 : now.month + 1;
}

// ── habillage du mois, dessiné en code ───────────────────────────────────

/// Une peluche habillée du thème du mois ([theme] inconnu = peluche seule).
class PawThemedPlush618 extends StatelessWidget {
  const PawThemedPlush618({
    super.key,
    required this.type,
    required this.theme,
    required this.color,
    this.size = 44,
    this.caught = true,
  });

  final String type;
  final String theme;
  final Color color;
  final double size;
  final bool caught;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: caught ? 1 : 0.42,
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          foregroundPainter: PawMonthThemePainter618(theme: theme, color: color),
          child: Padding(
            padding: EdgeInsets.all(size * 0.06),
            child: Image.asset(pawPlushAsset(type), fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Icon(Icons.toys_rounded, color: color, size: size * 0.7)),
          ),
        ),
      ),
    );
  }
}

/// L'accessoire du mois : écharpe (automne), bonnet (hiver), flocons
/// (neige), cœurs, fleurs, soleil, lunettes de soleil, chapeau de rentrée,
/// citrouille… Formes simples, couleurs pleines (aucun gris).
class PawMonthThemePainter618 extends CustomPainter {
  PawMonthThemePainter618({required this.theme, required this.color});
  final String theme;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final fill = Paint()..color = color;
    final white = Paint()..color = Colors.white;
    final edge = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, w * 0.025);
    switch (theme) {
      case 'autumn':
        // Écharpe nouée sous le museau + feuille d'érable en haut à droite.
        // Écharpe en bas du médaillon (sous le museau, jamais dessus).
        final scarf = RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.24, h * 0.78, w * 0.52, h * 0.1), Radius.circular(h * 0.05));
        canvas.drawRRect(scarf, fill);
        canvas.drawRRect(scarf, edge);
        final tail = Path()
          ..moveTo(w * 0.6, h * 0.84)
          ..lineTo(w * 0.7, h * 0.99)
          ..lineTo(w * 0.56, h * 0.97)
          ..close();
        canvas.drawPath(tail, fill);
        canvas.drawPath(tail, edge);
        _leaf(canvas, Offset(w * 0.84, h * 0.16), w * 0.13, const Color(0xFFE8901A));
        break;
      case 'winter':
        // Bonnet à pompon.
        final hat = Path()
          ..moveTo(w * 0.24, h * 0.3)
          ..quadraticBezierTo(w * 0.5, -h * 0.08, w * 0.76, h * 0.3)
          ..close();
        canvas.drawPath(hat, fill);
        final band = RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.2, h * 0.26, w * 0.6, h * 0.09), Radius.circular(h * 0.04));
        canvas.drawRRect(band, white);
        canvas.drawCircle(Offset(w * 0.5, h * 0.06), w * 0.07, white);
        break;
      case 'snow':
        for (final o in [Offset(w * 0.12, h * 0.18), Offset(w * 0.88, h * 0.3), Offset(w * 0.84, h * 0.82)]) {
          _flake(canvas, o, w * 0.09, color);
        }
        break;
      case 'hearts':
        _heart(canvas, Offset(w * 0.86, h * 0.16), w * 0.14, color);
        _heart(canvas, Offset(w * 0.12, h * 0.3), w * 0.1, color);
        break;
      case 'spring':
        _flower(canvas, Offset(w * 0.8, h * 0.14), w * 0.1, color, const Color(0xFFFFD34D));
        break;
      case 'flowers':
        for (final o in [Offset(w * 0.3, h * 0.12), Offset(w * 0.5, h * 0.06), Offset(w * 0.7, h * 0.12)]) {
          _flower(canvas, o, w * 0.08, color, const Color(0xFFFFD34D));
        }
        break;
      case 'picnic':
        // Nœud vichy.
        final c = Offset(w * 0.5, h * 0.7);
        final bow = Path()
          ..moveTo(c.dx, c.dy)
          ..lineTo(c.dx - w * 0.16, c.dy - h * 0.08)
          ..lineTo(c.dx - w * 0.16, c.dy + h * 0.08)
          ..close()
          ..moveTo(c.dx, c.dy)
          ..lineTo(c.dx + w * 0.16, c.dy - h * 0.08)
          ..lineTo(c.dx + w * 0.16, c.dy + h * 0.08)
          ..close();
        canvas.drawPath(bow, fill);
        canvas.drawPath(bow, edge);
        canvas.drawCircle(c, w * 0.04, white);
        break;
      case 'beach':
        // Vague + soleil.
        final wave = Path()..moveTo(0, h * 0.92);
        for (var i = 0; i < 4; i++) {
          wave.quadraticBezierTo(w * (0.125 + i * 0.25), h * 0.82, w * (0.25 + i * 0.25), h * 0.92);
        }
        canvas.drawPath(
            wave,
            Paint()
              ..color = color
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(1.5, w * 0.05)
              ..strokeCap = StrokeCap.round);
        _sun(canvas, Offset(w * 0.86, h * 0.14), w * 0.08, const Color(0xFFF2A516));
        break;
      case 'summer':
        _sun(canvas, Offset(w * 0.84, h * 0.16), w * 0.1, color);
        break;
      case 'holidays':
        // Lunettes de soleil.
        final l = Rect.fromCenter(center: Offset(w * 0.38, h * 0.42), width: w * 0.2, height: h * 0.13);
        final r = Rect.fromCenter(center: Offset(w * 0.62, h * 0.42), width: w * 0.2, height: h * 0.13);
        canvas.drawRRect(RRect.fromRectAndRadius(l, Radius.circular(h * 0.05)), fill);
        canvas.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(h * 0.05)), fill);
        canvas.drawLine(Offset(l.right, l.center.dy), Offset(r.left, r.center.dy),
            Paint()
              ..color = color
              ..strokeWidth = math.max(1, w * 0.03));
        break;
      case 'back_to_school':
        // Toque carrée.
        final top = Path()
          ..moveTo(w * 0.5, h * 0.0)
          ..lineTo(w * 0.86, h * 0.12)
          ..lineTo(w * 0.5, h * 0.24)
          ..lineTo(w * 0.14, h * 0.12)
          ..close();
        canvas.drawPath(top, fill);
        canvas.drawLine(Offset(w * 0.78, h * 0.15), Offset(w * 0.82, h * 0.32),
            Paint()
              ..color = const Color(0xFFFFC23D)
              ..strokeWidth = math.max(1, w * 0.03));
        break;
      case 'halloween':
        _pumpkin(canvas, Offset(w * 0.84, h * 0.82), w * 0.12, color);
        break;
      default:
        _sparkle(canvas, Offset(w * 0.86, h * 0.14), w * 0.1, color);
    }
  }

  static void _leaf(Canvas c, Offset o, double r, Color col) {
    final p = Path()
      ..moveTo(o.dx, o.dy - r)
      ..quadraticBezierTo(o.dx + r, o.dy - r * 0.2, o.dx, o.dy + r)
      ..quadraticBezierTo(o.dx - r, o.dy - r * 0.2, o.dx, o.dy - r)
      ..close();
    c.drawPath(p, Paint()..color = col);
    c.drawLine(Offset(o.dx, o.dy - r * 0.6), Offset(o.dx, o.dy + r * 1.3),
        Paint()
          ..color = const Color(0xFF8A3A06)
          ..strokeWidth = math.max(1, r * 0.18));
  }

  static void _flake(Canvas c, Offset o, double r, Color col) {
    final p = Paint()
      ..color = col
      ..strokeWidth = math.max(1, r * 0.28)
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      final a = i * math.pi / 3;
      c.drawLine(Offset(o.dx - r * math.cos(a), o.dy - r * math.sin(a)),
          Offset(o.dx + r * math.cos(a), o.dy + r * math.sin(a)), p);
    }
  }

  static void _heart(Canvas c, Offset o, double r, Color col) {
    final p = Path()
      ..moveTo(o.dx, o.dy + r * 0.8)
      ..cubicTo(o.dx - r * 1.4, o.dy - r * 0.2, o.dx - r * 0.5, o.dy - r * 1.1, o.dx, o.dy - r * 0.35)
      ..cubicTo(o.dx + r * 0.5, o.dy - r * 1.1, o.dx + r * 1.4, o.dy - r * 0.2, o.dx, o.dy + r * 0.8)
      ..close();
    c.drawPath(p, Paint()..color = col);
    c.drawPath(
        p,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(0.8, r * 0.15));
  }

  static void _flower(Canvas c, Offset o, double r, Color petal, Color heart) {
    for (var i = 0; i < 5; i++) {
      final a = i * 2 * math.pi / 5;
      c.drawCircle(Offset(o.dx + r * 0.7 * math.cos(a), o.dy + r * 0.7 * math.sin(a)), r * 0.5,
          Paint()..color = petal);
    }
    c.drawCircle(o, r * 0.42, Paint()..color = heart);
  }

  static void _sun(Canvas c, Offset o, double r, Color col) {
    final ray = Paint()
      ..color = col
      ..strokeWidth = math.max(1, r * 0.25)
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      c.drawLine(Offset(o.dx + r * 1.15 * math.cos(a), o.dy + r * 1.15 * math.sin(a)),
          Offset(o.dx + r * 1.6 * math.cos(a), o.dy + r * 1.6 * math.sin(a)), ray);
    }
    c.drawCircle(o, r, Paint()..color = col);
  }

  static void _pumpkin(Canvas c, Offset o, double r, Color col) {
    c.drawOval(Rect.fromCenter(center: o, width: r * 2.2, height: r * 1.7), Paint()..color = col);
    c.drawOval(Rect.fromCenter(center: o, width: r * 0.9, height: r * 1.7),
        Paint()
          ..color = const Color(0xFFB0430E)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(0.8, r * 0.14));
    c.drawLine(Offset(o.dx, o.dy - r * 0.85), Offset(o.dx + r * 0.2, o.dy - r * 1.25),
        Paint()
          ..color = const Color(0xFF2E7D32)
          ..strokeWidth = math.max(1, r * 0.25)
          ..strokeCap = StrokeCap.round);
  }

  static void _sparkle(Canvas c, Offset o, double r, Color col) {
    final p = Path()
      ..moveTo(o.dx, o.dy - r)
      ..quadraticBezierTo(o.dx, o.dy, o.dx + r, o.dy)
      ..quadraticBezierTo(o.dx, o.dy, o.dx, o.dy + r)
      ..quadraticBezierTo(o.dx, o.dy, o.dx - r, o.dy)
      ..quadraticBezierTo(o.dx, o.dy, o.dx, o.dy - r)
      ..close();
    c.drawPath(p, Paint()..color = col);
  }

  @override
  bool shouldRepaint(covariant PawMonthThemePainter618 old) => old.theme != theme || old.color != color;
}

// ── carte « Collection du mois » (page PawPoints) ────────────────────────

class PawMonthlyCard618 extends StatelessWidget {
  const PawMonthlyCard618({super.key, required this.monthly, required this.now});
  final PawMonthly618 monthly;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final m = monthly;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final ink = AppColors.textPrimary(context);
    final sub = AppColors.textSecondary(context);
    final started = m.startedAt(now);
    final caught = started ? m.caughtTypes.length : 0;
    final countdown = pawMonthlyCountdown618(m, now);
    final Color tint = Color.lerp(m.color, dark ? Colors.black : Colors.white, dark ? 0.55 : 0.86)!;
    final String title =
        '${'month618_title'.tr} · ${pawMonthName618(m.month)}';
    return Container(
      key: const ValueKey<String>('month618_card'),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: m.color.withValues(alpha: 0.8), width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(title,
                  style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w800, color: ink)),
            ),
            Container(
              key: const ValueKey<String>('month618_counter'),
              padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 3.h),
              decoration: BoxDecoration(color: m.color, borderRadius: BorderRadius.circular(999)),
              child: Text('$caught/${kPawPlushTypes.length}',
                  style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w900, color: Colors.white)),
            ),
          ]),
          SizedBox(height: 2.h),
          if (m.label.isNotEmpty)
            Text('month618_theme_line'.trParams({'theme': m.label}),
                style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700, color: dark ? Colors.white : m.color)),
          if (countdown.isNotEmpty) ...[
            SizedBox(height: 2.h),
            Text(countdown,
                key: const ValueKey<String>('month618_countdown'),
                style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: sub)),
          ],
          SizedBox(height: 10.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final t in kPawPlushTypes)
                Expanded(
                  child: Column(children: [
                    PawThemedPlush618(
                      key: ValueKey<String>('month618_plush_$t'),
                      type: t,
                      theme: m.theme,
                      color: m.color,
                      size: 46.w,
                      caught: started && m.caughtTypes.contains(t),
                    ),
                    SizedBox(height: 3.h),
                    Text('plush607_type_$t'.tr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10.sp, color: sub)),
                  ]),
                ),
            ],
          ),
          SizedBox(height: 10.h),
          Text(
            started && m.complete
                ? 'month618_complete'.trParams({'points': '${m.bonusPoints}'})
                : 'month618_bonus'.trParams({'points': '${m.bonusPoints}'}),
            key: const ValueKey<String>('month618_bonus'),
            style: TextStyle(
              fontSize: 11.5.sp,
              height: 1.3,
              fontWeight: started && m.complete ? FontWeight.w800 : FontWeight.w500,
              color: started && m.complete ? (dark ? Colors.white : m.color) : sub,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bandeau « Collection complète ! Prochaine collection : … ».
class PawCollectionDoneBanner618 extends StatelessWidget {
  const PawCollectionDoneBanner618({super.key, required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey<String>('month618_done_banner'),
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color, Color.lerp(color, const Color(0xFFFFC23D), 0.35)!]),
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Row(children: [
        Icon(Icons.emoji_events_rounded, color: Colors.white, size: 20.sp),
        SizedBox(width: 8.w),
        Expanded(
          child: Text(text,
              style: TextStyle(fontSize: 12.5.sp, height: 1.3, fontWeight: FontWeight.w800, color: Colors.white)),
        ),
      ]),
    );
  }
}

import 'package:hopetsit/models/post_model.dart';

/// v440 — libellé de période d'une annonce, INCLUANT l'heure (HH:mm) quand
/// elle est renseignée (promenade / garde avec horaire), sinon date seule.
///
/// Centralise la logique auparavant dupliquée dans home_screen,
/// my_posts_screen et notification_post_view_screen (le feed sitter avait
/// déjà sa propre version horaire). Owner et provider voient ainsi la même
/// information d'horaire sur la cellule « Dates » de la grille de réservation.
class PostDateLabel {
  static String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  /// '' si minuit (= « pas d'heure ») sinon 'HH:mm'.
  static String _time(DateTime d) {
    if (d.hour == 0 && d.minute == 0) return '';
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  static String _dateWithTime(DateTime d) {
    final t = _time(d);
    return t.isEmpty ? _date(d) : '${_date(d)} $t';
  }

  /// Construit le label depuis un [PostModel] (null si aucune date).
  static String? forPost(PostModel post) {
    final s = post.startDate?.toLocal();
    final e = post.endDate?.toLocal();
    return build(s, e);
  }

  /// v443 — Daniel : l'heure quitte la cellule « Dates » pour une petite
  /// horloge sous « Service ». forPost (= dates + heure) reste utilisé
  /// ailleurs ; la grille de réservation utilise désormais dateOnly + timeLabel.
  ///
  /// Libellé de période SANS heure (null si aucune date).
  static String? dateOnly(PostModel post) {
    final s = post.startDate?.toLocal();
    final e = post.endDate?.toLocal();
    if (s != null && e != null) {
      final sameDay = s.year == e.year && s.month == e.month && s.day == e.day;
      if (sameDay) return _date(s);
      return '${_date(s)} → ${_date(e)}';
    }
    if (s != null) return _date(s);
    if (e != null) return _date(e);
    return null;
  }

  /// v443 — libellé d'heure SEUL pour la cellule « Service » (horloge).
  /// '' si aucune heure réelle (minuit = « pas d'heure »). Même jour avec
  /// heure de fin → « 14:00 → 15:00 », sinon « 14:00 ».
  static String timeLabel(PostModel post) {
    final s = post.startDate?.toLocal();
    final e = post.endDate?.toLocal();
    final st = s == null ? '' : _time(s);
    final et = e == null ? '' : _time(e);
    if (st.isEmpty && et.isEmpty) return '';
    if (s != null && e != null) {
      final sameDay = s.year == e.year && s.month == e.month && s.day == e.day;
      if (sameDay && st.isNotEmpty && et.isNotEmpty) return '$st → $et';
    }
    // Pas de fenêtre même-jour exploitable : on affiche l'heure de début (ou
    // de fin à défaut).
    return st.isNotEmpty ? st : et;
  }

  /// Construit le label depuis deux DateTime locaux. Affiche l'heure dès
  /// qu'une heure non nulle est présente. Même jour → « 20/06 14:00 → 15:00 ».
  static String? build(DateTime? s, DateTime? e) {
    if (s != null && e != null) {
      final sameDay = s.year == e.year && s.month == e.month && s.day == e.day;
      if (sameDay) {
        final st = _time(s);
        final et = _time(e);
        if (st.isEmpty && et.isEmpty) return _date(s);
        return '${_date(s)} $st → $et';
      }
      return '${_dateWithTime(s)} → ${_dateWithTime(e)}';
    }
    if (s != null) return _dateWithTime(s);
    if (e != null) return _dateWithTime(e);
    return null;
  }
}

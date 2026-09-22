import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/intl.dart';
import 'package:hopetsit/controllers/sitter_bookings_controller.dart';
import 'package:hopetsit/controllers/walker_bookings_controller.dart';
import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/models/booking_model.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/storage_keys.dart';
import 'package:hopetsit/views/profile/widgets/edit_profile_widgets.dart';
import 'package:hopetsit/views/profile/widgets/profile_ui_kit.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
import 'package:hopetsit/utils/bottom_inset.dart';

/// Calendrier de disponibilités — écran COMMUN sitter / walker (v565, lot
/// app-calendar-wallet, demande de Daniel du 18/09 : « rends l'utilisation du
/// calendrier plus facile pour cliquer les dates où je suis présent »).
///
/// Usage :
///   • 1 tap sur un jour = disponible (vert plein + coche), re-tap = bloqué
///     (gris barré). Aucun menu intermédiaire.
///   • Appui long puis glisser = on « peint » une plage (la valeur du premier
///     jour touché est appliquée à tous les jours survolés).
///   • Bouton « Sélection multiple » = glisser directement (le défilement de
///     la page est suspendu pendant ce mode).
///   • Raccourcis : Tout le mois / Semaine en cours / Week-ends / Effacer le mois.
///   • Jours passés grisés non cliquables ; jours réservés (réservations déjà
///     chargées par le contrôleur du rôle) verrouillés avec pastille.
///   • Enregistrement AUTOMATIQUE 1,2 s après le dernier tap (pastille
///     Enregistré ✓ / Enregistrement… / Non enregistré), bouton « Enregistrer »
///     conservé en secours.
///
/// Serveur : routes et format INCHANGÉS — `GET/PUT /sitters/me/availability`
/// ou `/walkers/me/availability`, corps `{ availableDates, unavailableDates }`
/// en ISO 8601 minuit UTC (le serveur normalise déjà à minuit UTC).
class AvailabilityCalendarScreen extends StatefulWidget {
  const AvailabilityCalendarScreen({super.key, this.role});

  /// 'sitter' | 'walker'. Si null, résolu depuis le profil persisté.
  final String? role;

  @override
  State<AvailabilityCalendarScreen> createState() =>
      _AvailabilityCalendarScreenState();
}

enum _SaveState { saved, saving, unsaved, error }

class _AvailabilityCalendarScreenState
    extends State<AvailabilityCalendarScreen> {
  final ApiClient _api = Get.isRegistered<ApiClient>()
      ? Get.find<ApiClient>()
      : ApiClient();

  final Set<DateTime> _available = <DateTime>{};
  final Set<DateTime> _unavailable = <DateTime>{};
  final Set<DateTime> _booked = <DateTime>{};

  late DateTime _month; // 1er jour du mois affiché (local)
  bool _loading = true;
  String _loadError = '';
  bool _saving = false;
  bool _dirty = false;
  int _gen = 0; // génération des modifications (évite d'écraser un tap survenu pendant un PUT)
  _SaveState _saveState = _SaveState.saved;
  Timer? _debounce;

  bool _multiSelect = false;
  bool? _paintAvailable; // valeur peinte pendant un glissement
  DateTime? _lastPainted;

  // Géométrie de la grille (calculée au build, utilisée pour le hit-test).
  double _cellW = 0;
  double _cellH = 0;
  int _leading = 0; // cases vides avant le 1er du mois (semaine = lundi)

  static const Color _green = Color(0xFF16A34A);
  static const Duration _autosaveDelay = Duration(milliseconds: 1200);

  /// Base API — '/walkers' pour un walker, '/sitters' sinon.
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

  bool get _isWalker => _base == '/walkers';
  Color get _accent =>
      _isWalker ? AppColors.walkerAccent : AppColors.sitterAccent;

  // ── Dates ───────────────────────────────────────────────────────────────
  DateTime _key(DateTime d) => DateTime.utc(d.year, d.month, d.day);
  DateTime get _today => _key(DateTime.now());
  DateTime get _currentMonth {
    final n = DateTime.now();
    return DateTime(n.year, n.month, 1);
  }

  bool _isPast(DateTime d) => d.isBefore(_today);
  bool _isBooked(DateTime d) => _booked.contains(d);
  bool _isEditable(DateTime d) => !_isPast(d) && !_isBooked(d);
  bool _inMonth(DateTime d, DateTime month) =>
      d.year == month.year && d.month == month.month;

  int _daysInMonth(DateTime m) => DateTime(m.year, m.month + 1, 0).day;

  @override
  void initState() {
    super.initState();
    _month = _currentMonth;
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    // Filet de sécurité : on quitte l'écran avec des changements en attente
    // → un dernier PUT en arrière-plan (sans attendre).
    if (_dirty && !_saving) {
      _api
          .put('$_base/me/availability', body: _body(), requiresAuth: true)
          .catchError((_) => null);
    }
    super.dispose();
  }

  // ── Chargement ──────────────────────────────────────────────────────────
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = '';
    });
    try {
      final resp = await _api.get(
        '$_base/me/availability',
        requiresAuth: true,
      );
      if (resp is Map) {
        _available
          ..clear()
          ..addAll(_parseList(resp['availableDates']));
        _unavailable
          ..clear()
          ..addAll(_parseList(resp['unavailableDates']));
      }
      _collectBooked();
      _dirty = false;
      _saveState = _SaveState.saved;
    } catch (e) {
      _loadError = e is ApiException && e.message.isNotEmpty
          ? e.message
          : 'availability_load_error'.tr;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Iterable<DateTime> _parseList(dynamic raw) => ((raw as List?) ?? const [])
      .map((e) => DateTime.tryParse(e.toString()))
      .whereType<DateTime>()
      .map((d) => DateTime.utc(d.toUtc().year, d.toUtc().month, d.toUtc().day));

  /// Jours couverts par une réservation active du rôle, si le contrôleur de
  /// réservations est déjà chargé (aucun appel réseau supplémentaire).
  void _collectBooked() {
    _booked.clear();
    List<BookingModel> list = const <BookingModel>[];
    try {
      if (_isWalker && Get.isRegistered<WalkerBookingsController>()) {
        list = Get.find<WalkerBookingsController>().bookings.toList();
      } else if (!_isWalker && Get.isRegistered<SitterBookingsController>()) {
        list = Get.find<SitterBookingsController>().bookings.toList();
      }
    } catch (_) {
      list = const <BookingModel>[];
    }
    const inactive = {
      'cancelled', 'canceled', 'rejected', 'declined', 'refunded',
      'completed', 'expired', 'failed',
    };
    for (final b in list) {
      final status = b.status.toLowerCase();
      if (inactive.contains(status)) continue;
      final start = b.plannedStart;
      if (start == null) continue;
      final end = b.plannedEnd ?? start;
      var d = _key(start);
      final last = _key(end.isBefore(start) ? start : end);
      var guard = 0;
      while (!d.isAfter(last) && guard < 90) {
        _booked.add(d);
        d = d.add(const Duration(days: 1));
        guard++;
      }
    }
  }

  // ── Enregistrement ──────────────────────────────────────────────────────
  Map<String, dynamic> _body() => {
        'availableDates': _available.map((d) => d.toIso8601String()).toList(),
        'unavailableDates':
            _unavailable.map((d) => d.toIso8601String()).toList(),
      };

  void _scheduleSave() {
    _debounce?.cancel();
    _debounce = Timer(_autosaveDelay, () => _save(auto: true));
  }

  Future<void> _save({bool auto = false}) async {
    _debounce?.cancel();
    if (!mounted) return;
    if (_saving) {
      // Un PUT est en vol : on repasse après.
      _debounce = Timer(const Duration(milliseconds: 600), () => _save(auto: true));
      return;
    }
    final gen = _gen;
    setState(() {
      _saving = true;
      _saveState = _SaveState.saving;
    });
    try {
      await _api.put(
        '$_base/me/availability',
        body: _body(),
        requiresAuth: true,
      );
      if (!mounted) return;
      setState(() {
        if (_gen == gen) {
          _dirty = false;
          _saveState = _SaveState.saved;
        } else {
          // Des taps ont eu lieu pendant l'envoi → nouvel enregistrement.
          _saveState = _SaveState.unsaved;
          _scheduleSave();
        }
      });
      if (!auto) {
        CustomSnackbar.showSuccess(
          title: 'common_success'.tr,
          message: 'availability_saved'.tr,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saveState = _SaveState.error);
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: e is ApiException && e.message.isNotEmpty
            ? e.message
            : 'cal_save_error'.tr,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Édition ─────────────────────────────────────────────────────────────
  /// Applique un état à un jour (sans setState). Retourne true si changé.
  bool _setDay(DateTime d, bool available) {
    if (!_isEditable(d)) return false;
    final changed = available
        ? !_available.contains(d)
        : !_unavailable.contains(d);
    if (available) {
      _unavailable.remove(d);
      _available.add(d);
    } else {
      _available.remove(d);
      _unavailable.add(d);
    }
    if (changed) {
      _dirty = true;
      _gen++;
      _saveState = _SaveState.unsaved;
    }
    return changed;
  }

  void _tap(DateTime? d) {
    if (d == null) return;
    if (_isPast(d)) {
      CustomSnackbar.showInfo(
          title: 'availability_title'.tr, message: 'cal_past_locked'.tr);
      return;
    }
    if (_isBooked(d)) {
      CustomSnackbar.showInfo(
          title: 'cal_legend_booked'.tr, message: 'cal_booked_locked'.tr);
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      // 1 tap = disponible ; re-tap = bloqué ; re-tap = disponible…
      _setDay(d, !_available.contains(d));
    });
    _scheduleSave();
  }

  void _dragStart(Offset local) {
    final d = _dayAt(local);
    if (d == null) return;
    _paintAvailable = _isEditable(d) ? !_available.contains(d) : true;
    _lastPainted = null;
    _dragUpdate(local);
  }

  void _dragUpdate(Offset local) {
    final d = _dayAt(local);
    if (d == null || d == _lastPainted) return;
    _lastPainted = d;
    if (!_isEditable(d)) return;
    final paint = _paintAvailable ?? true;
    setState(() {
      if (_setDay(d, paint)) HapticFeedback.selectionClick();
    });
  }

  void _dragEnd() {
    _paintAvailable = null;
    _lastPainted = null;
    if (_dirty) _scheduleSave();
  }

  /// Raccourcis : appliquent « disponible » aux jours éditables ciblés.
  void _applyQuick(Iterable<DateTime> days, {bool available = true}) {
    var changed = false;
    setState(() {
      for (final d in days) {
        if (_setDay(d, available)) changed = true;
      }
    });
    if (changed) {
      HapticFeedback.lightImpact();
      _scheduleSave();
    }
  }

  Iterable<DateTime> _monthDays(DateTime m) sync* {
    final n = _daysInMonth(m);
    for (var i = 1; i <= n; i++) {
      yield DateTime.utc(m.year, m.month, i);
    }
  }

  void _quickAllMonth() => _applyQuick(_monthDays(_month));

  void _quickWeekends() => _applyQuick(_monthDays(_month)
      .where((d) => d.weekday == DateTime.saturday || d.weekday == DateTime.sunday));

  void _quickThisWeek() {
    final t = _today;
    final monday = t.subtract(Duration(days: t.weekday - 1));
    final days = List.generate(7, (i) => monday.add(Duration(days: i)));
    if (!_inMonth(t, _month)) setState(() => _month = _currentMonth);
    _applyQuick(days);
  }

  void _clearMonth() {
    var changed = false;
    setState(() {
      for (final d in _monthDays(_month)) {
        if (_isPast(d)) continue;
        if (_available.remove(d)) changed = true;
        if (_unavailable.remove(d)) changed = true;
      }
      if (changed) {
        _dirty = true;
        _gen++;
        _saveState = _SaveState.unsaved;
      }
    });
    if (changed) {
      HapticFeedback.lightImpact();
      _scheduleSave();
    }
  }

  // ── Navigation mois ─────────────────────────────────────────────────────
  bool get _canGoPrev => _month.isAfter(_currentMonth);
  bool get _canGoNext =>
      _month.isBefore(DateTime(_currentMonth.year, _currentMonth.month + 18, 1));

  void _shiftMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta, 1);
    });
  }

  // ── Hit-test de la grille ───────────────────────────────────────────────
  DateTime? _dayAt(Offset p) {
    if (_cellW <= 0 || _cellH <= 0) return null;
    final col = (p.dx / _cellW).floor();
    final row = (p.dy / _cellH).floor();
    if (col < 0 || col > 6 || row < 0) return null;
    final day = row * 7 + col - _leading + 1;
    if (day < 1 || day > _daysInMonth(_month)) return null;
    return DateTime.utc(_month.year, _month.month, day);
  }

  // ── Libellés localisés ──────────────────────────────────────────────────
  String get _locale => Get.locale?.toString() ?? 'fr';

  String _monthTitle() {
    String s;
    try {
      s = DateFormat.yMMMM(_locale).format(_month);
    } catch (_) {
      s = '${_month.month.toString().padLeft(2, '0')}/${_month.year}';
    }
    return s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
  }

  List<String> _weekdayLabels() {
    return List.generate(7, (i) {
      // 2024-01-01 est un lundi.
      final d = DateTime(2024, 1, 1 + i);
      String s;
      try {
        s = DateFormat.E(_locale).format(d);
      } catch (_) {
        s = const ['L', 'M', 'M', 'J', 'V', 'S', 'D'][i];
      }
      s = s.replaceAll('.', '').trim();
      if (s.length > 3) s = s.substring(0, 3);
      return s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
    });
  }

  int get _availableThisMonth => _available
      .where((d) => _inMonth(d, _month) && !_isPast(d))
      .length;
  int get _availableTotal => _available.where((d) => !_isPast(d)).length;

  // ── UI ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final accent = _accent;
    return ProfileSubPageScaffold(
      title: 'availability_title'.tr,
      accent: accent,
      scroll: false,
      padding: EdgeInsets.zero,
      body: _loading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(accent),
              ),
            )
          : _loadError.isNotEmpty
              ? ProfileEmptyState(
                  icon: Icons.event_busy_rounded,
                  title: 'availability_load_error_title'.tr,
                  message: _loadError,
                  accent: accent,
                  error: true,
                  actionLabel: 'common_retry'.tr,
                  onAction: _load,
                )
              : Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        // En sélection multiple, le glissement peint les jours :
                        // le défilement de la page est suspendu.
                        physics: _multiSelect
                            ? const NeverScrollableScrollPhysics()
                            : const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ProfileInfoBanner(
                              icon: _multiSelect
                                  ? Icons.gesture_rounded
                                  : Icons.touch_app_rounded,
                              text: _multiSelect
                                  ? 'cal_multi_hint'.tr
                                  : 'cal_tap_hint'.tr,
                              accent: accent,
                            ),
                            SizedBox(height: 12.h),
                            _statusRow(context, accent),
                            SizedBox(height: 12.h),
                            _calendarCard(context, accent),
                            SizedBox(height: 12.h),
                            _quickActionsCard(context, accent),
                            SizedBox(height: 12.h),
                            _legendCard(context, accent),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      // v569 — barre d'action collée en bas : le SafeArea de
              // ProfileSubPageScaffold n'applique rien sur le Samsung de
              // Daniel → le bouton passait sous la barre système.
              padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w,
                  12.h + appBottomInsetInsideSafeArea(context)),
                      child: ProfileSaveBar(
                        label: 'availability_save'.tr,
                        accent: accent,
                        loading: _saving,
                        icon: Icons.check_rounded,
                        note: 'cal_autosave_note'.tr,
                        onTap: (_saving || !_dirty) ? null : () => _save(),
                      ),
                    ),
                  ],
                ),
    );
  }

  /// Compteur « N jours disponibles ce mois · T au total » + pastille d'état.
  Widget _statusRow(BuildContext context, Color accent) {
    final IconData icon;
    final String text;
    final Color color;
    switch (_saveState) {
      case _SaveState.saved:
        icon = Icons.check_circle_rounded;
        text = 'cal_saved'.tr;
        color = _green;
        break;
      case _SaveState.saving:
        icon = Icons.sync_rounded;
        text = 'cal_saving'.tr;
        color = accent;
        break;
      case _SaveState.unsaved:
        icon = Icons.edit_rounded;
        text = 'cal_unsaved'.tr;
        color = const Color(0xFFE8920A);
        break;
      case _SaveState.error:
        icon = Icons.error_rounded;
        text = 'cal_unsaved'.tr;
        color = AppColors.errorColor;
        break;
    }
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PoppinsText(
                text: 'cal_days_available_month'
                    .trParams({'n': '$_availableThisMonth'}),
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary(context),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              InterText(
                text: 'cal_days_available_total'
                    .trParams({'n': '$_availableTotal'}),
                fontSize: 11.5.sp,
                color: AppColors.textSecondary(context),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        SizedBox(width: 8.w),
        ProfileStatusPill(icon: icon, text: text, color: color),
      ],
    );
  }

  Widget _calendarCard(BuildContext context, Color accent) {
    return Container(
      padding: EdgeInsets.fromLTRB(10.w, 6.h, 10.w, 12.h),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: AppColors.cardShadow(context),
      ),
      child: Column(
        children: [
          _monthHeader(context, accent),
          SizedBox(height: 6.h),
          _weekdayRow(context),
          SizedBox(height: 4.h),
          _grid(context, accent),
        ],
      ),
    );
  }

  Widget _monthHeader(BuildContext context, Color accent) {
    Widget nav(IconData icon, bool enabled, VoidCallback onTap, String tip) {
      return Tooltip(
        message: tip,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(12.r),
          child: Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              color: enabled
                  ? accent.withValues(alpha: 0.10)
                  : AppColors.divider(context).withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(icon,
                size: 22.sp,
                color: enabled ? accent : AppColors.textSecondary(context)),
          ),
        ),
      );
    }

    return Row(
      children: [
        nav(Icons.chevron_left_rounded, _canGoPrev, () => _shiftMonth(-1),
            'cal_prev_month'.tr),
        Expanded(
          child: Column(
            children: [
              PoppinsText(
                text: _monthTitle(),
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary(context),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 4.h),
              _multiSelectToggle(context, accent),
            ],
          ),
        ),
        nav(Icons.chevron_right_rounded, _canGoNext, () => _shiftMonth(1),
            'cal_next_month'.tr),
      ],
    );
  }

  Widget _multiSelectToggle(BuildContext context, Color accent) {
    final on = _multiSelect;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _multiSelect = !on);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
        decoration: BoxDecoration(
          color: on ? accent : accent.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(on ? Icons.check_rounded : Icons.gesture_rounded,
                size: 13.sp, color: on ? Colors.white : accent),
            SizedBox(width: 5.w),
            Flexible(
              child: InterText(
                text: on ? 'cal_done'.tr : 'cal_multi_on'.tr,
                fontSize: 11.sp,
                fontWeight: FontWeight.w700,
                color: on ? Colors.white : accent,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _weekdayRow(BuildContext context) {
    final labels = _weekdayLabels();
    return Row(
      children: List.generate(7, (i) {
        return Expanded(
          child: Center(
            child: InterText(
              text: labels[i],
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary(context),
              maxLines: 1,
            ),
          ),
        );
      }),
    );
  }

  Widget _grid(BuildContext context, Color accent) {
    final days = _daysInMonth(_month);
    _leading = DateTime(_month.year, _month.month, 1).weekday - 1; // lundi = 0
    final rows = ((_leading + days) / 7).ceil();
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final w = constraints.maxWidth;
        _cellW = w / 7;
        final double maxH = 48.h;
        _cellH = _cellW < maxH ? _cellW : maxH;
        final gridRows = <Widget>[];
        for (var r = 0; r < rows; r++) {
          final cells = <Widget>[];
          for (var c = 0; c < 7; c++) {
            final idx = r * 7 + c - _leading + 1;
            Widget cell;
            if (idx < 1 || idx > days) {
              cell = const SizedBox.shrink();
            } else {
              cell = _dayCell(
                  context, DateTime.utc(_month.year, _month.month, idx), accent);
            }
            cells.add(SizedBox(width: _cellW, height: _cellH, child: cell));
          }
          gridRows.add(Row(children: cells));
        }
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) => _tap(_dayAt(d.localPosition)),
          // Appui long + glisser = peindre une plage (toujours actif).
          onLongPressStart: (d) {
            HapticFeedback.mediumImpact();
            _dragStart(d.localPosition);
          },
          onLongPressMoveUpdate: (d) => _dragUpdate(d.localPosition),
          onLongPressEnd: (_) => _dragEnd(),
          onLongPressCancel: _dragEnd,
          // Sélection multiple = glisser directement (défilement suspendu).
          onPanStart: _multiSelect ? (d) => _dragStart(d.localPosition) : null,
          onPanUpdate: _multiSelect ? (d) => _dragUpdate(d.localPosition) : null,
          onPanEnd: _multiSelect ? (_) => _dragEnd() : null,
          onPanCancel: _multiSelect ? _dragEnd : null,
          child: Column(mainAxisSize: MainAxisSize.min, children: gridRows),
        );
      },
    );
  }

  Widget _dayCell(BuildContext context, DateTime d, Color accent) {
    final past = _isPast(d);
    final booked = _isBooked(d);
    final available = !past && !booked && _available.contains(d);
    final blocked = !past && !booked && _unavailable.contains(d);
    final today = d == _today;
    final dark = Get.isDarkMode;

    Color bg = Colors.transparent;
    Color fg = AppColors.textPrimary(context);
    Border? border;
    TextDecoration deco = TextDecoration.none;
    Widget? mark;

    if (past) {
      fg = AppColors.textSecondary(context).withValues(alpha: 0.45);
    } else if (booked) {
      bg = accent.withValues(alpha: 0.12);
      fg = accent;
      border = Border.all(color: accent.withValues(alpha: 0.6), width: 1.2);
      mark = Icon(Icons.lock_rounded, size: 9.sp, color: accent);
    } else if (available) {
      bg = _green;
      fg = Colors.white;
      mark = Icon(Icons.check_rounded, size: 10.sp, color: Colors.white);
    } else if (blocked) {
      bg = dark ? const Color(0xFF2A3340) : const Color(0xFFEEE4E2);
      fg = AppColors.textSecondary(context);
      deco = TextDecoration.lineThrough;
      mark = Icon(Icons.close_rounded,
          size: 9.sp, color: AppColors.textSecondary(context));
    }
    if (today && bg == Colors.transparent) {
      border = Border.all(color: accent, width: 1.5);
      fg = accent;
    }

    return Padding(
      padding: EdgeInsets.all(3.w),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12.r),
          border: border,
          boxShadow: available
              ? [
                  BoxShadow(
                    color: _green.withValues(alpha: 0.30),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${d.day}',
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: (available || today || booked)
                    ? FontWeight.w800
                    : FontWeight.w600,
                color: fg,
                decoration: deco,
                decorationColor: fg,
                height: 1.0,
              ),
            ),
            if (mark != null) ...[SizedBox(height: 1.h), mark],
          ],
        ),
      ),
    );
  }

  Widget _quickActionsCard(BuildContext context, Color accent) {
    Widget chip(IconData icon, String label, VoidCallback onTap,
        {bool danger = false}) {
      final c = danger ? AppColors.errorColor : accent;
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: c.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15.sp, color: c),
              SizedBox(width: 6.w),
              InterText(
                text: label,
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: c,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: AppColors.cardShadow(context),
      ),
      child: Wrap(
        spacing: 8.w,
        runSpacing: 8.h,
        children: [
          chip(Icons.calendar_month_rounded, 'cal_all_month'.tr, _quickAllMonth),
          chip(Icons.view_week_rounded, 'cal_this_week'.tr, _quickThisWeek),
          chip(Icons.weekend_rounded, 'cal_weekends'.tr, _quickWeekends),
          chip(Icons.layers_clear_rounded, 'cal_clear_month'.tr, _clearMonth,
              danger: true),
        ],
      ),
    );
  }

  Widget _legendCard(BuildContext context, Color accent) {
    Widget item(Widget swatch, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            swatch,
            SizedBox(width: 6.w),
            Flexible(
              child: InterText(
                text: label,
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary(context),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
    Widget box(Color fill, {Color? borderColor, Widget? child}) => Container(
          width: 16.w,
          height: 16.w,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(5.r),
            border: borderColor != null
                ? Border.all(color: borderColor, width: 1.3)
                : null,
          ),
          alignment: Alignment.center,
          child: child,
        );
    final dark = Get.isDarkMode;
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: AppColors.cardShadow(context),
      ),
      child: Wrap(
        spacing: 14.w,
        runSpacing: 8.h,
        children: [
          item(
            box(_green,
                child: Icon(Icons.check_rounded, size: 11.sp, color: Colors.white)),
            'availability_legend_available'.tr,
          ),
          item(
            box(dark ? const Color(0xFF2A3340) : const Color(0xFFEEE4E2),
                child: Icon(Icons.close_rounded,
                    size: 10.sp, color: AppColors.textSecondary(context))),
            'availability_legend_blocked'.tr,
          ),
          item(
            box(accent.withValues(alpha: 0.12),
                borderColor: accent,
                child: Icon(Icons.lock_rounded, size: 9.sp, color: accent)),
            'cal_legend_booked'.tr,
          ),
          item(
            box(Colors.transparent, borderColor: accent),
            'cal_legend_today'.tr,
          ),
          item(
            box(Colors.transparent,
                borderColor: AppColors.divider(context)),
            'availability_legend_unset'.tr,
          ),
          item(
            box(AppColors.divider(context).withValues(alpha: 0.5)),
            'cal_legend_past'.tr,
          ),
        ],
      ),
    );
  }
}

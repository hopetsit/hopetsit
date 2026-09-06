// v23.1.186 — Daniel mockup : ecran Alertes dedie avec tabs (Tous /
// Perdus / Danger / Autres) et badges de severite (Urgent / Moyen / Info).
// v23.1 part 211 — Daniel "ameliore et connecte aussi toute cette page".
// Refonte complete :
//   - AppBar : search + filter icons cables
//   - Chips horizontales : radius (5/10/25/50/100 km) + periode (24h/48h/7j/30j)
//   - Empty state mockup : icone + section "Que pouvez-vous faire ?" 3 actions
//   - Gros CTA inline "Signaler un animal perdu" (en plus du FAB)
//   - Footer info cards (Communaute active / Alertes proches / Notifs)
//   - FIX critique : on envoie LAT/LNG (avant : 400 systematique)
//   - FIX critique : radiusKm + sinceHours envoyes au backend
//   - FIX critique : multi-type filter (avant : backend rejetait CSV)

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:hopetsit/data/network/api_client.dart';
import 'package:hopetsit/models/map_report_model.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/pawmap_theme.dart';
import 'package:hopetsit/views/map/paw_map_screen.dart';
import 'package:hopetsit/views/map/widgets/create_report_sheet.dart';
import 'package:hopetsit/views/notifications/notifications_screen.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  static const _tabs = <_TabDef>[
    _TabDef(key: 'all', labelKey: 'alerts_tab_all', filter: null),
    _TabDef(key: 'lost', labelKey: 'alerts_tab_lost', filter: [
      ReportTypes.lostPet,
    ]),
    _TabDef(key: 'danger', labelKey: 'alerts_tab_danger', filter: [
      ReportTypes.aggressiveDog,
      ReportTypes.hazard,
      ReportTypes.deadAnimal,
    ]),
    _TabDef(key: 'other', labelKey: 'alerts_tab_other', filter: [
      ReportTypes.foundPet,
      ReportTypes.waterActive,
      ReportTypes.waterBroken,
      ReportTypes.poop,
      ReportTypes.other,
    ]),
  ];

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  // v23.1 part 211 — state partage entre tous les tabs : radius (km),
  // periode (heures), recherche libre. Modifies via les chips ou bottom
  // sheet du filter icon → declenche reload de chaque _AlertsList.
  // v23.1 part 218 — Daniel : sa PawMap montre 2 alertes "Autour de vous"
  // mais Alertes screen dit "Aucune alerte". PawMap utilise un radius
  // plus large + pas de filtre temporel. On align : defaults 50km/7j
  // (au lieu de 25km/48h) pour eviter le faux negatif. L'user peut
  // toujours reduire via les chips.
  final RxDouble _radiusKm = 50.0.obs;
  final RxInt _sinceHours = 168.obs;
  final RxString _searchQuery = ''.obs;
  // Position GPS resolue UNE fois au mount, partagee.
  final Rx<LatLng?> _myPos = Rx<LatLng?>(null);
  final RxBool _resolvingPos = true.obs;

  @override
  void initState() {
    super.initState();
    _resolveMyPos();
  }

  Future<void> _resolveMyPos() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
      _myPos.value = LatLng(pos.latitude, pos.longitude);
    } catch (_) {
      // Fallback : on garde null → l'API renverra 400 mais l'UI affichera
      // un message specifique au lieu de tourner en boucle.
      _myPos.value = null;
    } finally {
      _resolvingPos.value = false;
    }
  }

  void _openRadiusPicker() {
    final options = <double>[5, 10, 25, 50, 100];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.card(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.all(16.w),
              child: InterText(
                text: 'alerts_filter_radius_title'.tr,
                fontSize: 15.sp,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary(context),
              ),
            ),
            ...options.map((km) => ListTile(
                  leading: Icon(Icons.gps_fixed_rounded,
                      color: AppColors.primaryColor, size: 20.sp),
                  title: Text('${km.toInt()} km'),
                  trailing: Obx(() => _radiusKm.value == km
                      ? Icon(Icons.check_circle_rounded,
                          color: AppColors.primaryColor)
                      : const SizedBox.shrink()),
                  onTap: () {
                    _radiusKm.value = km;
                    Navigator.of(ctx).pop();
                  },
                )),
            SizedBox(height: 8.h),
          ],
        ),
      ),
    );
  }

  void _openPeriodPicker() {
    final options = <int>[24, 48, 168, 720]; // 24h / 48h / 7j / 30j
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.card(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.all(16.w),
              child: InterText(
                text: 'alerts_filter_period_title'.tr,
                fontSize: 15.sp,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary(context),
              ),
            ),
            ...options.map((h) => ListTile(
                  leading: Icon(Icons.schedule_rounded,
                      color: AppColors.primaryColor, size: 20.sp),
                  title: Text(_periodLabel(h)),
                  trailing: Obx(() => _sinceHours.value == h
                      ? Icon(Icons.check_circle_rounded,
                          color: AppColors.primaryColor)
                      : const SizedBox.shrink()),
                  onTap: () {
                    _sinceHours.value = h;
                    Navigator.of(ctx).pop();
                  },
                )),
            SizedBox(height: 8.h),
          ],
        ),
      ),
    );
  }

  String _periodLabel(int hours) {
    if (hours <= 24) return 'alerts_period_24h'.tr;
    if (hours <= 48) return 'alerts_period_48h'.tr;
    if (hours <= 168) return 'alerts_period_7d'.tr;
    return 'alerts_period_30d'.tr;
  }

  void _openSearch() {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController(text: _searchQuery.value);
        return AlertDialog(
          title: Text('alerts_search_title'.tr),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'alerts_search_hint'.tr,
              prefixIcon: const Icon(Icons.search),
            ),
            onSubmitted: (v) {
              _searchQuery.value = v.trim();
              Navigator.of(ctx).pop();
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                _searchQuery.value = '';
                Navigator.of(ctx).pop();
              },
              child: Text('common_clear'.tr),
            ),
            TextButton(
              onPressed: () {
                _searchQuery.value = ctrl.text.trim();
                Navigator.of(ctx).pop();
              },
              child: Text('common_search'.tr),
            ),
          ],
        );
      },
    );
  }

  // v23.1 part 211 — bouton "Activer les notifications" du mockup.
  // Navigue vers l'ecran notifications ou demande permission FCM si
  // pas encore accordee.
  Future<void> _enableNotifications() async {
    try {
      // On ouvre le centre notifications (qui demande automatiquement
      // les permissions au premier render si necessaire).
      Get.to(() => const NotificationsScreen());
    } catch (e) {
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: e.toString(),
      );
    }
  }

  // v23.1 part 222 — Daniel : "dans la page alerte rien ne fonctionne
  // jai mis des alertes elle ne saffiche tjr pas". Appelle l'endpoint
  // diagnose qui retourne TOUS mes reports + la raison d'exclusion
  // de /nearby. Permet de voir si c'est un report (0,0), expired,
  // premium-only, trop loin, etc.
  // v493 — bouton bug retiré de l'UI (Daniel) ; méthode conservée pour debug.
  // ignore: unused_element
  Future<void> _runAlertsDiagnose() async {
    final pos = _myPos.value;
    try {
      final api = Get.find<ApiClient>();
      // v23.1 part 224 — Daniel : "alerte page erreur 404 api exception".
      // Cause : le backend monte les routes map sur /map-reports (avec
      // TIRET) mais alerts_screen utilisait /map/reports (avec slash)
      // depuis v211. PawMap utilisait deja le bon path via
      // map_report_controller.dart. Ce bug existait silencieusement
      // depuis v211 — la page Alertes n'a JAMAIS fonctionne, le catch
      // swallowait l'erreur 404 et affichait l'empty state.
      final path = pos != null
          ? '/map-reports/diagnose-mine?lat=${pos.latitude}&lng=${pos.longitude}'
          : '/map-reports/diagnose-mine';
      final r = await api.get(path, requiresAuth: true);
      if (!mounted) return;
      if (r is! Map) {
        CustomSnackbar.showError(
          title: 'common_error'.tr,
          message: 'alerts_diagnose_failed'.tr,
        );
        return;
      }
      final me = (r['me'] as Map?) ?? {};
      final mine = (r['myReports'] as List?) ?? [];
      final all = (r['allReportsLast7d'] as List?) ?? [];
      final buf = StringBuffer();
      buf.writeln('━━━ MOI ━━━');
      buf.writeln('id      : ${me['id']}');
      buf.writeln('Premium : ${me['isPremium']}');
      buf.writeln('lat/lng : ${me['lat']}, ${me['lng']}');
      buf.writeln('');
      buf.writeln('━━━ MES REPORTS (${mine.length}) ━━━');
      if (mine.isEmpty) {
        buf.writeln('Aucun report cree par moi.');
      }
      for (final f in mine) {
        if (f is! Map) continue;
        buf.writeln('• ${f['type']}  age=${f['ageHours']}h');
        buf.writeln('  coords=${f['coords']}  city="${f['city']}"');
        buf.writeln('  hidden=${f['hidden']}  show=${f['wouldShowInNearby']}');
        if (f['excludedBy'] is List && (f['excludedBy'] as List).isNotEmpty) {
          buf.writeln('  excludedBy=${f['excludedBy']}');
        }
        buf.writeln('');
      }
      buf.writeln('━━━ TOUS LES REPORTS 7J (${all.length}) ━━━');
      int wouldShow = 0;
      for (final f in all) {
        if (f is Map && f['wouldShowInNearby'] == true) wouldShow++;
      }
      buf.writeln('Visibles pour moi dans /nearby : $wouldShow / ${all.length}');
      buf.writeln('');
      buf.writeln('TIP: ${r['tip'] ?? ''}');
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('alerts_diagnose_title'.tr),
          content: SingleChildScrollView(
            child: SelectableText(
              buf.toString(),
              style: TextStyle(fontFamily: 'monospace', fontSize: 10.sp),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('common_close'.tr),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: e.toString().replaceAll('ApiException:', '').trim(),
      );
    }
  }

  Future<void> _signalLostPet() async {
    // v23.1 part 213 — Daniel : "j'ai signaler et ya ecrit aucune alerte".
    // Cause : ancien code fallback a LatLng(0,0) si pas de GPS → report
    // stocke off-Afrique → invisible dans le radius user. Maintenant :
    // si pas de GPS valide, on AFFICHE UNE ERREUR au lieu de creer
    // un report fantome.
    LatLng? point = _myPos.value;
    if (point == null) {
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 8),
          ),
        );
        point = LatLng(pos.latitude, pos.longitude);
        _myPos.value = point;
      } catch (_) {/* on tombera sur le check ci-dessous */}
    }
    if (point == null || (point.latitude == 0 && point.longitude == 0)) {
      CustomSnackbar.showError(
        title: 'alerts_no_gps_title'.tr,
        message: 'alerts_no_gps_msg'.tr,
      );
      return;
    }
    if (!mounted) return;
    await CreateReportSheet.show(
      context,
      initialPoint: point,
      preselectedType: ReportTypes.lostPet,
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: AlertsScreen._tabs.length,
      child: Scaffold(
        backgroundColor: PawMapTheme.bg,
        appBar: AppBar(
          backgroundColor: PawMapTheme.bg,
          elevation: 0,
          title: Row(
            children: [
              Icon(Icons.notifications_active_rounded,
                  color: const Color(0xFFF59E0B), size: 22.sp),
              SizedBox(width: 8.w),
              InterText(
                text: 'alerts_screen_title'.tr,
                fontSize: 18.sp,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary(context),
              ),
            ],
          ),
          actions: [
            // v493 — Daniel : retiré le bouton « bug » (diagnostic dev) en haut
            // à droite de Mes signaux / Alertes. Le diagnostic reste accessible
            // côté code (_runAlertsDiagnose) mais n'est plus exposé à l'user.
            IconButton(
              icon: Icon(Icons.search_rounded,
                  color: AppColors.primaryColor, size: 22.sp),
              tooltip: 'alerts_search_title'.tr,
              onPressed: _openSearch,
            ),
            IconButton(
              icon: Icon(Icons.tune_rounded,
                  color: AppColors.primaryColor, size: 22.sp),
              tooltip: 'alerts_filter_title'.tr,
              onPressed: () {
                showModalBottomSheet<void>(
                  context: context,
                  backgroundColor: AppColors.card(context),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20.r)),
                  ),
                  builder: (ctx) => SafeArea(
                    child: Padding(
                      padding: EdgeInsets.all(16.w),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InterText(
                            text: 'alerts_filter_title'.tr,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary(context),
                          ),
                          SizedBox(height: 12.h),
                          ListTile(
                            leading: Icon(Icons.gps_fixed_rounded,
                                color: AppColors.primaryColor),
                            title: Text('alerts_filter_radius_title'.tr),
                            subtitle: Obx(() =>
                                Text('${_radiusKm.value.toInt()} km')),
                            onTap: () {
                              Navigator.of(ctx).pop();
                              _openRadiusPicker();
                            },
                          ),
                          ListTile(
                            leading: Icon(Icons.schedule_rounded,
                                color: AppColors.primaryColor),
                            title: Text('alerts_filter_period_title'.tr),
                            subtitle: Obx(
                                () => Text(_periodLabel(_sinceHours.value))),
                            onTap: () {
                              Navigator.of(ctx).pop();
                              _openPeriodPicker();
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            labelColor: PawMapTheme.rose,
            unselectedLabelColor: AppColors.greyText,
            indicatorColor: PawMapTheme.rose,
            tabs: AlertsScreen._tabs
                .map((t) => Tab(text: t.labelKey.tr))
                .toList(),
          ),
        ),
        body: Column(
          children: [
            // ── Chips de filtre (mockup) ───────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 6.h),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20.r),
                      onTap: _openRadiusPicker,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 12.w, vertical: 8.h),
                        decoration: BoxDecoration(
                          color: AppColors.primaryColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20.r),
                          border: Border.all(
                            color: AppColors.primaryColor.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.location_on_rounded,
                                color: AppColors.primaryColor, size: 14.sp),
                            SizedBox(width: 6.w),
                            Obx(() => InterText(
                                  text: 'alerts_chip_radius'.trParams({
                                    'km': _radiusKm.value.toInt().toString(),
                                  }),
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary(context),
                                )),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20.r),
                      onTap: _openPeriodPicker,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 12.w, vertical: 8.h),
                        decoration: BoxDecoration(
                          color: AppColors.card(context),
                          borderRadius: BorderRadius.circular(20.r),
                          border: Border.all(color: AppColors.divider(context)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.schedule_rounded,
                                color: AppColors.greyText, size: 14.sp),
                            SizedBox(width: 6.w),
                            Expanded(
                              child: Obx(() => InterText(
                                    text: _periodLabel(_sinceHours.value),
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary(context),
                                    maxLines: 1,
                                  )),
                            ),
                            Icon(Icons.keyboard_arrow_down_rounded,
                                color: AppColors.greyText, size: 16.sp),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: AlertsScreen._tabs
                    .map((t) => _AlertsList(
                          filterTypes: t.filter,
                          myPos: _myPos,
                          resolvingPos: _resolvingPos,
                          radiusKm: _radiusKm,
                          sinceHours: _sinceHours,
                          searchQuery: _searchQuery,
                          onWidenSearch: () {
                            _radiusKm.value = 100;
                            _sinceHours.value = 720;
                          },
                          onSeeNearby: () {
                            _radiusKm.value = 25;
                            _sinceHours.value = 48;
                          },
                          onEnableNotifs: _enableNotifications,
                          onSignalLost: _signalLostPet,
                        ))
                    .toList(),
              ),
            ),
          ],
        ),
        // v23.1 part 212 — Daniel : "sur la page alerte enleve le bouton
        // signaler en bas a droite". Le FAB faisait doublon avec le gros
        // CTA inline rouge "Signaler un animal perdu" deja present dans
        // l'empty state. On le supprime pour eviter la duplication.
      ),
    );
  }
}

class _TabDef {
  final String key;
  final String labelKey;
  final List<String>? filter;
  const _TabDef(
      {required this.key, required this.labelKey, required this.filter});
}

class _AlertsList extends StatefulWidget {
  const _AlertsList({
    required this.filterTypes,
    required this.myPos,
    required this.resolvingPos,
    required this.radiusKm,
    required this.sinceHours,
    required this.searchQuery,
    required this.onWidenSearch,
    required this.onSeeNearby,
    required this.onEnableNotifs,
    required this.onSignalLost,
  });
  final List<String>? filterTypes;
  final Rx<LatLng?> myPos;
  final RxBool resolvingPos;
  final RxDouble radiusKm;
  final RxInt sinceHours;
  final RxString searchQuery;
  final VoidCallback onWidenSearch;
  final VoidCallback onSeeNearby;
  final VoidCallback onEnableNotifs;
  final VoidCallback onSignalLost;

  @override
  State<_AlertsList> createState() => _AlertsListState();
}

class _AlertsListState extends State<_AlertsList>
    with AutomaticKeepAliveClientMixin {
  final RxBool _loading = true.obs;
  final RxList<MapReport> _reports = <MapReport>[].obs;
  final RxnString _error = RxnString();
  Worker? _radiusWorker;
  Worker? _periodWorker;
  Worker? _posWorker;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
    // v23.1 part 211 — reload quand radius / period / position change.
    _radiusWorker = ever<double>(widget.radiusKm, (_) => _load());
    _periodWorker = ever<int>(widget.sinceHours, (_) => _load());
    _posWorker = ever<LatLng?>(widget.myPos, (_) => _load());
  }

  @override
  void dispose() {
    _radiusWorker?.dispose();
    _periodWorker?.dispose();
    _posWorker?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final pos = widget.myPos.value;
    if (pos == null) {
      // Pas de GPS → on attend la resolution (resolvingPos)
      _loading.value = widget.resolvingPos.value;
      _reports.clear();
      return;
    }
    _loading.value = true;
    _error.value = null;
    try {
      final api = Get.find<ApiClient>();
      // v23.1 part 211 — FIX critique : envoie lat/lng + radiusKm +
      // sinceHours au backend (avant : 400 systematique).
      // v23.1 part 224 — fix path : /map-reports avec tiret (pas /map/reports)
      String path = '/map-reports/nearby?lat=${pos.latitude}&lng=${pos.longitude}'
          '&radiusKm=${widget.radiusKm.value.toInt()}'
          '&sinceHours=${widget.sinceHours.value}';
      if (widget.filterTypes != null && widget.filterTypes!.isNotEmpty) {
        path += '&type=${widget.filterTypes!.join(',')}';
      }
      final r = await api.get(path, requiresAuth: true);
      List raw = const [];
      if (r is Map && r['reports'] is List) {
        raw = r['reports'] as List;
      } else if (r is List) {
        raw = r;
      }
      _reports.assignAll(
        raw
            .whereType<Map>()
            .map((m) => MapReport.fromJson(Map<String, dynamic>.from(m)))
            .toList(),
      );
    } catch (e) {
      _error.value = e.toString();
      _reports.clear();
    } finally {
      _loading.value = false;
    }
  }

  List<MapReport> _filtered() {
    final q = widget.searchQuery.value.toLowerCase();
    if (q.isEmpty) return _reports;
    return _reports.where((r) {
      return r.note.toLowerCase().contains(q) ||
          r.city.toLowerCase().contains(q) ||
          r.type.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RefreshIndicator(
      onRefresh: _load,
      child: Obx(() {
        // v23.1 part 217 — Daniel : "aucune alerte ne s'affiche". Cause
        // possible : GPS denied/not resolved. Avant : empty state generique
        // sans info. Maintenant : si pas de pos ET pas en cours de
        // resolution → message GPS-denied explicite avec CTA pour re-tenter.
        if (widget.myPos.value == null) {
          if (widget.resolvingPos.value) {
            return const Center(child: CircularProgressIndicator());
          }
          return _GpsRequiredState(
            onRetry: () async {
              widget.resolvingPos.value = true;
              try {
                final pos = await Geolocator.getCurrentPosition(
                  locationSettings: const LocationSettings(
                    accuracy: LocationAccuracy.high,
                    timeLimit: Duration(seconds: 10),
                  ),
                );
                widget.myPos.value = LatLng(pos.latitude, pos.longitude);
              } catch (_) {
                widget.myPos.value = null;
                if (mounted) {
                  CustomSnackbar.showError(
                    title: 'alerts_no_gps_title'.tr,
                    message: 'alerts_no_gps_msg'.tr,
                  );
                }
              } finally {
                widget.resolvingPos.value = false;
              }
            },
            onOpenSettings: () async {
              await Geolocator.openLocationSettings();
            },
          );
        }
        if (_loading.value && _reports.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        final filtered = _filtered();
        if (filtered.isEmpty) {
          return _EmptyState(
            onSeeNearby: widget.onSeeNearby,
            onWidenSearch: widget.onWidenSearch,
            onEnableNotifs: widget.onEnableNotifs,
            onSignalLost: widget.onSignalLost,
          );
        }
        // v23.1 part 225 — Daniel : "dans longlet alerte sur tous tu peux
        // laisser le bouton orange signaler un animal perdu". On garde le
        // CTA visible en TETE de liste sur l'onglet Tous (filterTypes ==
        // null) meme quand la liste a des alertes. Sur les autres tabs
        // (Perdus/Danger/Autres) on ne le repete pas pour pas surcharger.
        final showSignalBanner = widget.filterTypes == null;
        return ListView.builder(
          padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 90.h),
          itemCount: filtered.length + (showSignalBanner ? 1 : 0),
          itemBuilder: (_, i) {
            if (showSignalBanner && i == 0) {
              return Padding(
                padding: EdgeInsets.only(bottom: 12.h),
                child: _SignalLostBanner(onTap: widget.onSignalLost),
              );
            }
            final reportIndex = showSignalBanner ? i - 1 : i;
            return Padding(
              padding: EdgeInsets.only(bottom: 8.h),
              child: _ReportCard(report: filtered[reportIndex]),
            );
          },
        );
      }),
    );
  }
}

// v23.1 part 211 — Empty state mockup avec :
//   - Icone bouclier + paws + sparkles
//   - Section "Que pouvez-vous faire ?" 3 actions
//   - Gros CTA inline "Signaler un animal perdu"
//   - Footer info (Communaute / Alertes proches / Notifs)
class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.onSeeNearby,
    required this.onWidenSearch,
    required this.onEnableNotifs,
    required this.onSignalLost,
  });
  final VoidCallback onSeeNearby;
  final VoidCallback onWidenSearch;
  final VoidCallback onEnableNotifs;
  final VoidCallback onSignalLost;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 100.h),
      children: [
        SizedBox(height: 16.h),
        // ── Hero illustration : bouclier + paws + sparkles ────────────
        Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text('✨', style: TextStyle(fontSize: 18.sp)),
              Positioned(
                left: 30.w,
                top: 0,
                child: Text('✨', style: TextStyle(fontSize: 12.sp)),
              ),
              Positioned(
                right: 30.w,
                top: 10.h,
                child: Text('✨', style: TextStyle(fontSize: 10.sp)),
              ),
              Container(
                margin: EdgeInsets.only(top: 24.h),
                width: 100.w,
                height: 100.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryColor.withValues(alpha: 0.08),
                ),
                child: Icon(Icons.shield_outlined,
                    size: 50.sp,
                    color: AppColors.greyText.withValues(alpha: 0.6)),
              ),
              Positioned(
                bottom: 8.h,
                child: Text('🐾',
                    style: TextStyle(fontSize: 16.sp)),
              ),
            ],
          ),
        ),
        SizedBox(height: 16.h),
        InterText(
          text: 'alerts_empty_title'.tr,
          fontSize: 18.sp,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary(context),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 6.h),
        InterText(
          text: 'alerts_empty_msg'.tr,
          fontSize: 13.sp,
          color: AppColors.greyText,
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 18.h),
        // ── Section "Que pouvez-vous faire ?" ─────────────────────────
        Container(
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            color: AppColors.card(context),
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(color: AppColors.divider(context)),
          ),
          child: Column(
            children: [
              InterText(
                text: 'alerts_what_can_you_do'.tr,
                fontSize: 13.sp,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary(context),
              ),
              SizedBox(height: 12.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _ActionPill(
                    icon: Icons.search_rounded,
                    label: 'alerts_action_see_nearby'.tr,
                    color: const Color(0xFFC92A12),
                    onTap: onSeeNearby,
                  ),
                  _ActionPill(
                    icon: Icons.location_searching_rounded,
                    label: 'alerts_action_widen'.tr,
                    color: const Color(0xFFF59E0B),
                    onTap: onWidenSearch,
                  ),
                  _ActionPill(
                    icon: Icons.notifications_active_rounded,
                    label: 'alerts_action_enable_notifs'.tr,
                    color: const Color(0xFF2563EB),
                    onTap: onEnableNotifs,
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: 12.h),
        // ── Gros CTA inline "Signaler un animal perdu" ───────────────
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14.r),
            onTap: onSignalLost,
            child: Container(
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFDC2626), Color(0xFFC92A12)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14.r),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFDC2626).withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.campaign_rounded,
                      color: Colors.white, size: 26.sp),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InterText(
                          text: 'alerts_signal_lost_title'.tr,
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                        SizedBox(height: 2.h),
                        InterText(
                          text: 'alerts_signal_lost_subtitle'.tr,
                          fontSize: 11.sp,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios_rounded,
                      color: Colors.white, size: 16.sp),
                ],
              ),
            ),
          ),
        ),
        SizedBox(height: 14.h),
        // ── Footer info cards ──────────────────────────────────────────
        Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: AppColors.card(context),
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(color: AppColors.divider(context)),
          ),
          child: Row(
            children: [
              Expanded(
                child: _InfoCard(
                  icon: Icons.verified_user_rounded,
                  iconColor: const Color(0xFF16A34A),
                  title: 'alerts_info_community_title'.tr,
                  subtitle: 'alerts_info_community_msg'.tr,
                ),
              ),
              Expanded(
                child: _InfoCard(
                  icon: Icons.location_on_rounded,
                  iconColor: const Color(0xFFC92A12),
                  title: 'alerts_info_nearby_title'.tr,
                  subtitle: 'alerts_info_nearby_msg'.tr,
                ),
              ),
              Expanded(
                child: _InfoCard(
                  icon: Icons.notifications_active_rounded,
                  iconColor: const Color(0xFF8B5CF6),
                  title: 'alerts_info_smart_title'.tr,
                  subtitle: 'alerts_info_smart_msg'.tr,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// v23.1 part 225 — Daniel : "sur tous tu peux laisser le bouton orange
// signaler un animal perdu". Banner compact reutilise comme header de
// liste sur l'onglet "Tous" quand des alertes sont presentes (sinon
// l'empty state contient deja le gros CTA full-width).
class _SignalLostBanner extends StatelessWidget {
  const _SignalLostBanner({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14.r),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFDC2626), Color(0xFFC92A12)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14.r),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFDC2626).withValues(alpha: 0.30),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(Icons.campaign_rounded, color: Colors.white, size: 22.sp),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InterText(
                      text: 'alerts_signal_lost_title'.tr,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                    SizedBox(height: 1.h),
                    InterText(
                      text: 'alerts_signal_lost_subtitle'.tr,
                      fontSize: 10.sp,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                  color: Colors.white, size: 14.sp),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12.r),
      onTap: onTap,
      child: SizedBox(
        width: 90.w,
        child: Column(
          children: [
            Container(
              width: 44.w,
              height: 44.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.12),
              ),
              child: Icon(icon, color: color, size: 22.sp),
            ),
            SizedBox(height: 6.h),
            InterText(
              text: label,
              fontSize: 10.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary(context),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 24.sp),
          SizedBox(height: 6.h),
          InterText(
            text: title,
            fontSize: 10.sp,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary(context),
            textAlign: TextAlign.center,
            maxLines: 2,
          ),
          SizedBox(height: 2.h),
          InterText(
            text: subtitle,
            fontSize: 9.sp,
            color: AppColors.greyText,
            textAlign: TextAlign.center,
            maxLines: 3,
          ),
        ],
      ),
    );
  }
}

// v23.1 part 217 — Daniel : "aucune alerte ne s'affiche dans la page".
// Si GPS denied, on affichait l'empty state generique (3 actions + CTA
// signaler). Probleme : Daniel ne sait pas si c'est 0 alerte OU GPS
// cassé. Nouveau widget dedie qui dit "active la localisation" + 2
// boutons : "Reessayer" + "Ouvrir parametres systeme".
class _GpsRequiredState extends StatelessWidget {
  const _GpsRequiredState({
    required this.onRetry,
    required this.onOpenSettings,
  });
  final VoidCallback onRetry;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 60.h),
      children: [
        SizedBox(height: 40.h),
        Center(
          child: Container(
            width: 100.w,
            height: 100.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFF59E0B).withValues(alpha: 0.10),
            ),
            child: Icon(Icons.location_off_rounded,
                size: 56.sp, color: const Color(0xFFF59E0B)),
          ),
        ),
        SizedBox(height: 16.h),
        InterText(
          text: 'alerts_no_gps_title'.tr,
          fontSize: 18.sp,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary(context),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 6.h),
        InterText(
          text: 'alerts_no_gps_msg'.tr,
          fontSize: 13.sp,
          color: AppColors.greyText,
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 18.h),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC92A12),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 14.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14.r),
              ),
            ),
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            label: InterText(
              text: 'common_retry'.tr,
              fontSize: 14.sp,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
            onPressed: onRetry,
          ),
        ),
        SizedBox(height: 10.h),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppColors.divider(context)),
              padding: EdgeInsets.symmetric(vertical: 14.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14.r),
              ),
            ),
            icon: Icon(Icons.settings_rounded,
                color: AppColors.textPrimary(context)),
            label: InterText(
              text: 'alerts_gps_open_settings'.tr,
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary(context),
            ),
            onPressed: onOpenSettings,
          ),
        ),
      ],
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report});
  final MapReport report;

  /// Severity tag : urgent (rouge) / moyen (orange) / info (vert/gris).
  ({Color color, String label}) _severity() {
    switch (report.type) {
      case ReportTypes.lostPet:
      case ReportTypes.aggressiveDog:
      case ReportTypes.deadAnimal:
        return (color: const Color(0xFFDC2626), label: 'alerts_severity_urgent'.tr);
      case ReportTypes.hazard:
      case ReportTypes.poop:
      case ReportTypes.waterBroken:
        return (color: const Color(0xFFF59E0B), label: 'alerts_severity_medium'.tr);
      default:
        return (color: const Color(0xFF16A34A), label: 'alerts_severity_info'.tr);
    }
  }

  String _typeLabel() {
    final key = 'map_report_label_${report.type}';
    final tr = key.tr;
    return tr == key ? report.type : tr;
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'time_just_now'.tr;
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}j';
  }

  @override
  Widget build(BuildContext context) {
    final sev = _severity();
    final emoji = ReportTypes.emoji(report.type);
    // v23.1 part 213 — Daniel : "si tu clic dessus sa te montre sur la
    // map". Wrap dans Material + InkWell qui navigue vers PawMap centree
    // sur les coordonnees du report.
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14.r),
        onTap: () {
          if (report.latitude == 0 && report.longitude == 0) {
            // Defensive : un report a (0,0) est invalide → on n'ouvre
            // pas la map (eviterait de zoomer au large de l'Afrique).
            Get.off(() => const PawMapScreen());
            return;
          }
          Get.off(() => PawMapScreen(
                initialLat: report.latitude,
                initialLng: report.longitude,
              ));
        },
        child: Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(14.r),
        boxShadow: AppColors.cardShadow(context),
        border: Border.all(color: AppColors.divider(context)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10.r),
            child: Container(
              width: 60.w,
              height: 60.w,
              color: sev.color.withValues(alpha: 0.10),
              child: report.photoUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: report.photoUrl,
                      memCacheWidth: 400, // v235 perf.
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Center(
                        child: Text(emoji, style: TextStyle(fontSize: 28.sp)),
                      ),
                    )
                  : Center(
                      child: Text(emoji, style: TextStyle(fontSize: 28.sp)),
                    ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InterText(
                  text: _typeLabel(),
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w800,
                  color: sev.color,
                  maxLines: 1,
                ),
                SizedBox(height: 4.h),
                if (report.note.isNotEmpty)
                  InterText(
                    text: report.note,
                    fontSize: 11.sp,
                    color: AppColors.textSecondary(context),
                    maxLines: 2,
                  ),
                SizedBox(height: 6.h),
                Row(
                  children: [
                    if (report.city.isNotEmpty) ...[
                      Icon(Icons.location_on_outlined,
                          size: 12.sp, color: AppColors.greyText),
                      SizedBox(width: 3.w),
                      Flexible(
                        child: InterText(
                          text: report.city,
                          fontSize: 10.sp,
                          color: AppColors.greyText,
                          maxLines: 1,
                        ),
                      ),
                      SizedBox(width: 8.w),
                    ],
                    InterText(
                      text: _timeAgo(report.createdAt),
                      fontSize: 10.sp,
                      color: AppColors.greyText,
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
            decoration: BoxDecoration(
              color: sev.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(color: sev.color.withValues(alpha: 0.4)),
            ),
            child: InterText(
              text: sev.label,
              fontSize: 9.sp,
              fontWeight: FontWeight.w800,
              color: sev.color,
            ),
          ),
        ],
      ),
        ), // Container
      ), // InkWell
    ); // Material
  }
}

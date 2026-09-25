import 'package:hopetsit/widgets/paw_pattern_background.dart';
import 'package:flutter/material.dart';
import 'package:hopetsit/widgets/role_chip.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hopetsit/controllers/auth_controller.dart';
import 'package:hopetsit/controllers/edit_sitter_profile_controller.dart'
    show providerRatesVersion;
import 'package:hopetsit/controllers/notifications_controller.dart';
import 'package:hopetsit/controllers/posts_controller.dart';
import 'package:hopetsit/controllers/sitter_profile_controller.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/repositories/pet_repository.dart';
import 'package:hopetsit/repositories/sitter_repository.dart';
import 'package:hopetsit/repositories/walker_repository.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/bottom_inset.dart';
import 'package:hopetsit/utils/logger.dart';
import 'package:hopetsit/utils/post_price_estimator.dart';
import 'package:hopetsit/utils/storage_keys.dart';
import 'package:hopetsit/views/booking/widgets/booking_ui_kit.dart';
import 'package:hopetsit/views/profile/widgets/contact_info_gate.dart';
import 'package:hopetsit/models/post_model.dart';
import 'package:hopetsit/views/pet_sitter/widgets/pet_detail_screen.dart';
import 'package:hopetsit/views/pet_sitter/widgets/pet_post_card.dart';
import 'package:hopetsit/views/pet_sitter/widgets/reservation_request_filter_dialog.dart';
import 'package:hopetsit/views/notifications/notifications_screen.dart';
import 'package:hopetsit/views/service_provider/owner_profile_view_screen.dart';
import 'package:hopetsit/utils/home_radius_prefs.dart';
import 'package:hopetsit/utils/search_radius.dart';
import 'package:hopetsit/views/shared/widgets/around_me_search_bar.dart';
import 'package:hopetsit/views/shared/widgets/city_picker_sheet.dart';
import 'package:hopetsit/views/shared/widgets/home_empty_kit.dart';
// v571 — actions de l'état vide : profil du rôle, invitation, boutique.
import 'package:hopetsit/views/boost/coin_shop_screen.dart';
import 'package:hopetsit/views/friends/tabs/friends_ui.dart'
    show shareFriendsInvite;
import 'package:hopetsit/views/pet_sitter/profile/edit_sitter_profile_screen.dart';
import 'package:hopetsit/views/pet_walker/profile/edit_walker_profile_screen.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/custom_app_bar.dart';
import 'package:hopetsit/widgets/home_quick_action_bar.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';
// v575 — audit P0-1 / P1-6 : bornes de durée de promenade partagées.
import 'package:hopetsit/utils/walk_duration.dart';
// Comments removed from publications
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Sort order for the sitter reservation feed (same as owner My Posts).
enum SitterFeedSortOrder { newestFirst, oldestFirst }

class SitterHomescreen extends StatefulWidget {
  const SitterHomescreen({super.key});

  @override
  State<SitterHomescreen> createState() => _SitterHomescreenState();
}

class _SitterHomescreenState extends State<SitterHomescreen> {
  final Map<String, bool> _loadingStates = {};
  final Map<String, String> _pendingApplicationIds = {};
  final Map<String, String> _pendingApplicationIdsByFingerprint = {};
  // Session v17.1 — stable post-id-based lookup. Populated from the backend's
  // `application.postId` field (v17.1) AND when the sitter sends a new
  // application for a post in the current session. Checked FIRST by the
  // card render code; the fingerprint map is kept as a fallback for legacy
  // applications that pre-date v17.1 (no postId stored).
  final Map<String, String> _pendingApplicationIdsByPostId = {};
  // v442 — #100 : filtres avancés + bouton « Trier » retirés du feed (barre
  // « Autour de moi » = source unique). Ces 2 champs gardent un défaut figé
  // (pas de filtre, tri du plus récent) pour le reste du pipeline du feed.
  final ReservationRequestFilterState _filterState =
      const ReservationRequestFilterState();
  final SitterFeedSortOrder _sortOrder = SitterFeedSortOrder.newestFirst;
  Position? _userPosition;

  // v441 — barre « Autour de moi » + rayon km (maquettes 50/51, partagée avec
  // l'accueil owner via AroundMeSearchBar). Le provider (walker/sitter)
  // parcourt les annonces owner autour d'un point choisi, filtrées par
  // distance. Source UNIQUE du rayon + de l'ancre de recherche pour le feed.
  //   _searchCityLabel : libellé affiché (« Paris, France ») ; vide ⇒ position.
  //   _anchorLat/Lng   : point d'ancrage du filtre distance ; null ⇒ GPS
  //                      (_userPosition) puis profil.
  //   _radiusKm        : rayon courant (50 → 500 km), défaut 50.
  // Par défaut on amorce l'ancre sur la localisation enregistrée du profil
  // (comme l'accueil owner) ; cf _seedAnchorFromProfile().
  String _searchCityLabel = '';
  double? _anchorLat;
  double? _anchorLng;
  double _radiusKm = 50.0;

  // v16.3i — provider rates cache for estimated-earning block on post cards.
  // Walker: walkRates from /walkers/me/rates (per-duration prices).
  // Sitter: hourly/daily/weekly/monthly from GET /sitters/:id.
  double _providerHourlyRate = 0.0;
  double _providerDailyRate = 0.0;
  double _providerWeeklyRate = 0.0;
  // v23.1 part 114 — exact per-duration rates for walker (30/60 min).
  double _providerWalkRate30 = 0.0;
  double _providerWalkRate60 = 0.0;
  double _providerMonthlyRate = 0.0;
  String _providerCurrency = 'EUR';

  Worker? _ratesVersionWorker;

  @override
  void initState() {
    super.initState();
    // Lot D — rayon retenu pour ce rôle (appareil, sinon compte), sinon 50 km.
    _radiusKm = HomeRadiusPrefs.resolve(
      _isWalkerViewer ? 'walker' : 'sitter',
      min: _kMinRadiusKm,
      max: _kMaxRadiusKm,
      fallback: _kDefaultRadiusKm,
    );
    _seedAnchorFromProfile();
    _loadPendingApplications();
    _loadUserPosition();
    _loadProviderRates();
    // v20.0.19 — écoute le broadcast "tarifs modifiés" publié par
    // edit_sitter_profile_controller.updateRatesOnly. Dès que le sitter ou
    // walker save ses tarifs dans "Mes tarifs", on recharge immédiatement
    // les rates locaux → les estimations sur les cards se mettent à jour
    // sans avoir besoin de pull-to-refresh.
    _ratesVersionWorker = ever<int>(providerRatesVersion, (_) {
      if (mounted) _loadProviderRates();
    });
  }

  @override
  void dispose() {
    _ratesVersionWorker?.dispose();
    super.dispose();
  }

  /// v16.3i — fetch the current provider's rates so the price block on
  /// post cards can be computed. Silent on failure (block will just stay
  /// hidden).
  Future<void> _loadProviderRates() async {
    try {
      final role = Get.isRegistered<AuthController>()
          ? (Get.find<AuthController>().userRole.value ?? '').toLowerCase()
          : '';
      if (role == 'walker') {
        final walkerRepo = Get.isRegistered<WalkerRepository>()
            ? Get.find<WalkerRepository>()
            : null;
        if (walkerRepo == null) return;
        final rates = await walkerRepo.getMyWalkerRates();
        double hourly = 0.0;
        double halfHour = 0.0;
        for (final r in rates) {
          if (!r.enabled || r.basePrice <= 0) continue;
          if (r.durationMinutes == 60 && hourly == 0.0) hourly = r.basePrice;
          if (r.durationMinutes == 30 && halfHour == 0.0)
            halfHour = r.basePrice;
        }
        // Prefer hourly; if only half-hour exists, extrapolate x2 so the
        // estimator still has a value for jobs of 1h+.
        final derivedHourly = hourly > 0 ? hourly : halfHour * 2;
        if (!mounted) return;
        setState(() {
          _providerHourlyRate = derivedHourly;
          // v23.1 part 114 — store the EXACT 30/60 rates so the estimator
          // can use them directly for posts of those specific durations
          // (au lieu de proratiser depuis hourly).
          _providerWalkRate30 = halfHour;
          _providerWalkRate60 = hourly;
        });
      } else if (role == 'sitter') {
        final storage = GetStorage();
        final userProfile = storage.read<Map<String, dynamic>>(
          StorageKeys.userProfile,
        );
        final sitterId = userProfile?['id']?.toString();
        if (sitterId == null || sitterId.isEmpty) return;
        final sitterRepo = Get.isRegistered<SitterRepository>()
            ? Get.find<SitterRepository>()
            : null;
        if (sitterRepo == null) return;
        final profile = await sitterRepo.getSitterProfile(sitterId);
        // Session v17.2 — the backend wraps the sitter profile under a
        // `sitter` key (GET /sitters/:id returns `{ sitter: { hourlyRate,
        // dailyRate, weeklyRate, monthlyRate, currency, ... } }`). The
        // previous code read `profile['hourlyRate']` which was always
        // undefined, so all rates silently stayed at 0 and the price
        // estimator short-circuited on `hasAnyRate == false`. We now look
        // inside `profile['sitter']` first and fall back to the top level
        // for robustness (in case a route returns a flat shape).
        final sitterPayload = (profile['sitter'] is Map)
            ? Map<String, dynamic>.from(profile['sitter'] as Map)
            : profile;
        double n(dynamic v) => v is num
            ? v.toDouble()
            : double.tryParse(v?.toString() ?? '') ?? 0.0;
        if (!mounted) return;
        setState(() {
          _providerHourlyRate = n(sitterPayload['hourlyRate']);
          _providerDailyRate = n(sitterPayload['dailyRate']);
          _providerWeeklyRate = n(sitterPayload['weeklyRate']);
          _providerMonthlyRate = n(sitterPayload['monthlyRate']);
          final cur =
              sitterPayload['currency']?.toString() ??
              sitterPayload['hourlyRateCurrency']?.toString();
          if (cur != null && cur.isNotEmpty) {
            _providerCurrency = cur.toUpperCase();
          }
        });
      }
    } catch (e) {
      AppLogger.logDebug('loadProviderRates failed: $e');
    }
  }

  // v441 — accent du rôle pour la barre « Autour de moi » : walker vert
  // (#16A34A), sitter bleu (#2563EB). Le rôle est détecté au runtime car cet
  // écran est partagé entre les deux nav wrappers.
  static const Color _kSitterAccent = Color(0xFF2563EB);
  static const Color _kWalkerAccent = Color(0xFF16A34A);

  bool get _isWalkerViewer {
    final role = Get.isRegistered<AuthController>()
        ? (Get.find<AuthController>().userRole.value ?? '').toLowerCase()
        : (GetStorage().read(StorageKeys.userRole) ?? '')
              .toString()
              .toLowerCase();
    return role == 'walker';
  }

  Color get _accent => _isWalkerViewer ? _kWalkerAccent : _kSitterAccent;

  /// v441 — amorce l'ancre du filtre distance sur la localisation enregistrée
  /// du profil (ville + lat/lng), comme le fait l'accueil owner. Tant que
  /// l'utilisateur n'a pas choisi une autre ville, le feed est filtré autour
  /// de chez lui. Silencieux si le profil n'a pas de coordonnées.
  void _seedAnchorFromProfile() {
    try {
      final profile =
          GetStorage().read(StorageKeys.userProfile) as Map<String, dynamic>?;
      if (profile == null) return;
      String city = '';
      String country = '';
      double? lat;
      double? lng;
      final loc = profile['location'];
      if (loc is Map) {
        city = (loc['city'] as String?)?.trim() ?? '';
        country = (loc['country'] as String?)?.trim() ?? '';
        lat =
            (loc['lat'] as num?)?.toDouble() ??
            (loc['latitude'] as num?)?.toDouble();
        lng =
            (loc['lng'] as num?)?.toDouble() ??
            (loc['longitude'] as num?)?.toDouble();
      }
      if (city.isEmpty) city = (profile['city'] as String?)?.trim() ?? '';
      if (country.isEmpty) {
        country = (profile['country'] as String?)?.trim() ?? '';
      }
      lat ??=
          (profile['lat'] as num?)?.toDouble() ??
          (profile['latitude'] as num?)?.toDouble();
      lng ??=
          (profile['lng'] as num?)?.toDouble() ??
          (profile['longitude'] as num?)?.toDouble();
      if (lat != null && lng != null) {
        _anchorLat = lat;
        _anchorLng = lng;
      }
      final parts = [city, country].where((s) => s.isNotEmpty).toList();
      if (parts.isNotEmpty) _searchCityLabel = parts.join(', ');
    } catch (_) {
      /* noop */
    }
  }

  /// Libellé de la carte « Autour de moi » : ville choisie/profil sinon GPS.
  String _anchorCityLabel() {
    if (_searchCityLabel.isNotEmpty) return _searchCityLabel;
    return 'home_my_position'.tr;
  }

  /// Point d'ancrage effectif du filtre distance : ville choisie/profil en
  /// priorité, sinon la position GPS de l'appareil. Null si rien de connu (on
  /// n'applique alors aucun filtre distance → toutes les annonces visibles).
  ({double lat, double lng})? get _effectiveAnchor {
    if (_anchorLat != null && _anchorLng != null) {
      return (lat: _anchorLat!, lng: _anchorLng!);
    }
    if (_userPosition != null) {
      return (lat: _userPosition!.latitude, lng: _userPosition!.longitude);
    }
    return null;
  }

  /// v441 — filtre distance (Haversine via Geolocator.distanceBetween) des
  /// annonces owner autour de l'ancre « Autour de moi », dans le rayon courant.
  /// Toujours actif (le slider est en permanence visible, comme l'accueil
  /// owner). Tolérance : une annonce SANS coordonnées GPS reste affichée — on
  /// ne masque pas un owner qui n'a pas saisi son adresse précise.
  List<PostModel> _filterByRadius(List<PostModel> source) {
    final anchor = _effectiveAnchor;
    if (anchor == null) return source; // pas d'ancre → pas de filtre.
    final radiusKm = _radiusKm.clamp(_kMinRadiusKm, _kMaxRadiusKm);
    return source.where((post) {
      final lat = post.location?.lat;
      final lng = post.location?.lng;
      if (lat == null || lng == null) return true; // tolérance sans coords.
      // Lot D — même règle que le serveur (haversine, borne inclusive).
      return withinRadiusKm(haversineKm(anchor.lat, anchor.lng, lat, lng), radiusKm);
    }).toList();
  }

  /// v441 — barre « Autour de moi » + rayon (widget partagé). Le slider pilote
  /// le rayon du filtre distance ; le tap localisation ouvre le picker de
  /// ville. Accent = couleur du rôle (vert walker / bleu sitter).
  Widget _buildAroundMeBar(BuildContext context) {
    return AroundMeSearchBar(
      accent: _accent,
      cityLabel: _anchorCityLabel(),
      radiusKm: _radiusKm,
      minRadiusKm: _kMinRadiusKm,
      maxRadiusKm: _kMaxRadiusKm,
      onTapCity: () => _showAroundMeCityPicker(context),
      // Glissement : la barre affiche la valeur toute seule (état local du
      // widget) — AUCUN setState ici : avant le lot D, tout l'écran (et ses
      // dizaines de cartes) était reconstruit à chaque pixel = les mini-lags.
      onRadiusChanged: (_) {},
      // Relâchement : on applique la valeur (le feed se re-filtre une fois)
      // et on la mémorise pour ce rôle.
      onRadiusCommit: _applyRadius,
    );
  }

  /// Lot D — applique un rayon (relâchement du curseur, « Élargir ») : une
  /// seule reconstruction du flux, valeur entière, mémorisée par rôle.
  void _applyRadius(double km) {
    final v = clampRadiusKm(km, min: _kMinRadiusKm, max: _kMaxRadiusKm);
    if (v != _radiusKm && mounted) setState(() => _radiusKm = v);
    HomeRadiusPrefs.write(_isWalkerViewer ? 'walker' : 'sitter', v);
  }

  /// v441 — compteur résultats : « N résultats trouvés » (clé existante
  /// home_results_found réutilisée). Reflète le nombre d'annonces affichées
  /// après filtre distance.
  Widget _buildAroundMeResults(BuildContext context, int count) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text('🎯', style: TextStyle(fontSize: 14.sp)),
        SizedBox(width: 6.w),
        Expanded(
          child: PoppinsText(
            text: 'home_around_me'.tr,
            fontSize: 13.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(width: 6.w),
        InterText(
          text: 'home_results_found'.trParams({'count': count.toString()}),
          fontSize: 12.sp,
          fontWeight: FontWeight.w600,
          color: _accent,
        ),
      ],
    );
  }

  /// v441 — sheet de changement de ville. v571 : la feuille est désormais la
  /// feuille PARTAGÉE `showCityPickerSheet` (même géocodage Nominatim, même
  /// « utiliser ma position », même valeur renvoyée qu'avant, rendu modernisé).
  /// Choisir une ville fixe l'ancre + relance le filtre ; « ma position » remet
  /// l'ancre sur la position GPS de l'appareil.
  Future<void> _showAroundMeCityPicker(BuildContext context) async {
    final result = await showCityPickerSheet(
      context,
      accent: _accent,
      initialCity: _searchCityLabel,
      subtitle: 'home571_city_hint_provider'.tr,
    );
    if (result == null || !mounted) return;
    setState(() {
      if (result.useMyPosition) {
        _searchCityLabel = '';
        _anchorLat = null;
        _anchorLng = null;
      } else {
        _searchCityLabel = result.city.trim();
        _anchorLat = result.lat;
        _anchorLng = result.lng;
      }
    });
  }

  Future<void> _loadUserPosition() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        final requested = await Geolocator.requestPermission();
        if (requested == LocationPermission.denied ||
            requested == LocationPermission.deniedForever) {
          AppLogger.logDebug('Location permission denied');
          return;
        }
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
      if (mounted) {
        setState(() => _userPosition = position);
      }
    } catch (e) {
      AppLogger.logError('Failed to load user position', error: e);
    }
  }

  List<PostModel> _applyRequestFilters(List<PostModel> source) {
    return source.where((post) {
      if (post.location == null &&
          post.startDate == null &&
          post.endDate == null &&
          post.serviceTypes.isEmpty) {
        return false;
      }

      if (_filterState.city != null && _filterState.city!.trim().isNotEmpty) {
        final city = post.location?.city ?? '';
        if (!city.toLowerCase().contains(
          _filterState.city!.trim().toLowerCase(),
        )) {
          return false;
        }
      }

      if (_filterState.serviceType != null &&
          _filterState.serviceType!.isNotEmpty) {
        final types = post.serviceTypes.map((e) => e.toLowerCase()).toList();
        if (!types.contains(_filterState.serviceType!.toLowerCase())) {
          return false;
        }
      }

      if (_filterState.dateRange != null) {
        final start = post.startDate;
        final end = post.endDate;
        if (start == null && end == null) return false;
        final postStart = start ?? end!;
        final postEnd = end ?? start!;
        final range = _filterState.dateRange!;
        if (postEnd.isBefore(range.start) || postStart.isAfter(range.end)) {
          return false;
        }
      }

      // v441 — le filtre DISTANCE n'est plus géré ici : il l'est en amont par
      // _filterByRadius (barre « Autour de moi » + rayon, source unique). On
      // ne garde dans ce dialog que les filtres ville-texte / service / dates.

      return true;
    }).toList();
  }

  static String _formatDateShort(DateTime d) {
    const months = 'JanFebMarAprMayJunJulAugSepOctNovDec';
    final i = (d.month - 1) * 3;
    return '${d.day} ${months.substring(i, i + 3)}';
  }

  // v443 — Daniel : la cellule « Dates » n'affiche plus que la DATE ; l'heure
  // part dans une horloge sous « Service » (cf _postTimeLabel + serviceTime).
  static String? _postDateRangeLabel(PostModel post) {
    final s = post.startDate;
    final e = post.endDate;
    if (s != null && e != null) {
      final sl = s.toLocal();
      final el = e.toLocal();
      final sameDay =
          sl.year == el.year && sl.month == el.month && sl.day == el.day;
      if (sameDay) return _formatDateShort(sl);
      return '${_formatDateShort(sl)} → ${_formatDateShort(el)}';
    }
    if (s != null) return _formatDateShort(s.toLocal());
    if (e != null) return _formatDateShort(e.toLocal());
    return null;
  }

  // v443 — heure SEULE pour l'horloge sous « Service » (« 14h → 15h », « 14h »).
  // '' si aucune heure réelle (minuit). Réutilise _formatTimeShort (style « 14h »).
  static String _postTimeLabel(PostModel post) {
    final s = post.startDate;
    final e = post.endDate;
    final sl = s?.toLocal();
    final el = e?.toLocal();
    final startT = sl == null ? '' : _formatTimeShort(sl);
    final endT = el == null ? '' : _formatTimeShort(el);
    if (startT.isEmpty && endT.isEmpty) return '';
    if (sl != null && el != null) {
      final sameDay =
          sl.year == el.year && sl.month == el.month && sl.day == el.day;
      if (sameDay && startT.isNotEmpty && endT.isNotEmpty) {
        return '$startT → $endT';
      }
    }
    return startT.isNotEmpty ? startT : endT;
  }

  static String _formatTimeShort(DateTime d) {
    if (d.hour == 0 && d.minute == 0) return '';
    final h = d.hour.toString();
    final m = d.minute.toString().padLeft(2, '0');
    return d.minute == 0 ? '${h}h' : '${h}h$m';
  }

  // v20.0.19 — i18n des service types sur les cards de publication côté sitter.
  // Avant ce fix, on affichait juste `t.replaceAll('_', ' ')` → "day care",
  // "dog walking", "pet sitting" en anglais brut même en FR/ES/etc.
  // Maintenant on mappe chaque valeur canonique vers une clé i18n existante.
  static String _serviceTypesDisplay(List<String> types) {
    if (types.isEmpty) return '';
    return types.map(_localizeServiceType).join(', ');
  }

  static String _localizeServiceType(String raw) {
    final v = raw.trim().toLowerCase();
    switch (v) {
      case 'day_care':
      case 'daycare':
      case 'garderie':
        return 'choose_service_card_day_care_title'.tr;
      case 'dog_walking':
      case 'walking':
      case 'promenade':
        return 'choose_service_card_dog_walking_title'.tr;
      case 'pet_sitting':
      case 'petsitting':
        return 'service_pet_sitting'.tr;
      case 'house_sitting':
      case 'housesitting':
        return 'service_house_sitting'.tr;
      case 'overnight_stay':
      case 'overnight':
        return 'service_overnight_stay'.tr;
      case 'long_stay':
      case 'longstay':
        return 'service_long_stay'.tr;
      case 'home_visit':
      case 'homevisit':
        return 'service_home_visit'.tr;
      default:
        // Fallback : raw humanisé (avec majuscule) si la clé n'existe pas.
        return raw.replaceAll('_', ' ');
    }
  }

  /// v16.3g — Build an earning estimate for [post] using the rates loaded by
  /// [_loadProviderRates] from the backend (walker /walkers/me/rates, sitter
  /// GET /sitters/:id). Returns null when no post dates, no usable rate, or
  /// user is not a provider.
  PostPriceEstimate? _estimateForPost(PostModel post) {
    try {
      final role = Get.isRegistered<AuthController>()
          ? (Get.find<AuthController>().userRole.value ?? '').toLowerCase()
          : '';
      if (role != 'sitter' && role != 'walker') return null;
      // If rates haven't loaded yet, we simply skip — the block stays hidden.
      final hasAnyRate =
          _providerHourlyRate > 0 ||
          _providerDailyRate > 0 ||
          _providerWeeklyRate > 0 ||
          _providerMonthlyRate > 0;
      if (!hasAnyRate) return null;

      return estimatePostPrice(
        post: post,
        userRole: role,
        hourlyRate: _providerHourlyRate,
        dailyRate: _providerDailyRate,
        weeklyRate: _providerWeeklyRate,
        monthlyRate: _providerMonthlyRate,
        currency: _providerCurrency,
        // v23.1 part 114 — passe les tarifs exacts pour 30/60 min.
        walkRate30: _providerWalkRate30 > 0 ? _providerWalkRate30 : null,
        walkRate60: _providerWalkRate60 > 0 ? _providerWalkRate60 : null,
      );
    } catch (e) {
      AppLogger.logDebug('estimateForPost failed: $e');
      return null;
    }
  }

  List<PostModel> _sortFeedPosts(List<PostModel> posts) {
    final sorted = List<PostModel>.from(posts);
    sorted.sort((a, b) {
      final cmp = a.createdAt.compareTo(b.createdAt);
      return _sortOrder == SitterFeedSortOrder.newestFirst ? -cmp : cmp;
    });
    return sorted;
  }

  static String _defaultTimeSlotForPost(PostModel post) {
    final start = post.startDate?.toLocal();
    if (start != null) {
      final h24 = start.hour;
      final h12 = h24 % 12 == 0 ? 12 : h24 % 12;
      final minute = start.minute.toString().padLeft(2, '0');
      final amPm = h24 < 12 ? 'AM' : 'PM';
      return '$h12:$minute $amPm';
    }
    return 'All Day';
  }

  static String _serviceDateForPost(PostModel post) {
    final source = post.startDate ?? post.endDate ?? DateTime.now();
    return source
        .toUtc()
        .copyWith(hour: 0, minute: 0, second: 0, millisecond: 0)
        .toIso8601String();
  }

  static String? _startDateForPost(PostModel post) {
    return post.startDate?.toUtc().toIso8601String();
  }

  static String? _endDateForPost(PostModel post) {
    return post.endDate?.toUtc().toIso8601String();
  }

  String _normalizeIso(String? v) {
    if (v == null || v.trim().isEmpty) return '';
    final parsed = DateTime.tryParse(v);
    if (parsed == null) return v.trim();
    return parsed.toUtc().toIso8601String();
  }

  String _buildRequestFingerprint({
    required String ownerId,
    required String petId,
    required String serviceType,
    required String serviceDate,
    required String timeSlot,
    String? startDate,
    String? endDate,
  }) {
    return [
      ownerId.trim(),
      petId.trim(),
      serviceType.trim().toLowerCase(),
      _normalizeIso(serviceDate),
      _normalizeIso(startDate),
      _normalizeIso(endDate),
      timeSlot.trim().toLowerCase(),
    ].join('|');
  }

  /// v575 — audit P1-6 / P1-7 : durée de la promenade proposée à l'annonce.
  ///
  /// AVANT, la vraie durée était ÉCRASÉE : `<= 45 ? 30 : 60`. Une annonce de
  /// 90 minutes partait donc à 60, et le propriétaire payait moins que ce
  /// qu'il avait demandé (ou recevait une promenade plus courte).
  /// Désormais, dans l'ordre :
  ///   1. `walkDurationMinutes` — la durée que le propriétaire a CHOISIE
  ///      (nouveau champ de l'annonce, v575) ;
  ///   2. fin − début de l'annonce, arrondi au multiple de 15 le plus proche
  ///      et borné à 15–300 minutes (mêmes bornes que le serveur) ;
  ///   3. 30 minutes en dernier recours (annonce sans dates, comme avant).
  static int? _durationForPostService(PostModel post, String serviceType) {
    final normalized = serviceType
        .trim()
        .toLowerCase()
        .replaceAll('-', '_')
        .replaceAll(' ', '_');
    if (normalized != 'dog_walking' && normalized != 'walking') {
      return null;
    }

    return walkDurationForPost(
      chosen: post.walkDurationMinutes,
      start: post.startDate,
      end: post.endDate,
    );
  }

  /// DEEP WORK — résout l'id de l'animal à utiliser pour la demande envoyée par
  /// le prestataire. Ordre : 1) premier animal résolu de l'annonce (post.pets,
  /// le plus fiable car enrichi par le backend), 2) premier id du tableau
  /// post.petIds (multi-animaux), 3) post.petId (legacy mono-animal). Retourne
  /// null UNIQUEMENT s'il n'y a réellement aucun animal rattaché à l'annonce.
  static String? _resolvePostPetId(PostModel post) {
    if (post.pets.isNotEmpty && post.pets.first.id.trim().isNotEmpty) {
      return post.pets.first.id.trim();
    }
    if (post.petIds.isNotEmpty && post.petIds.first.trim().isNotEmpty) {
      return post.petIds.first.trim();
    }
    final single = post.petId?.trim() ?? '';
    if (single.isNotEmpty) return single;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final PostsController postsController = Get.put(PostsController());
    // Initialize SitterProfileController to call GET /sitters/{sitterId} API
    final SitterProfileController profileController = Get.put(
      SitterProfileController(),
    );

    final notificationsController = Get.isRegistered<NotificationsController>()
        ? Get.find<NotificationsController>()
        : Get.put(NotificationsController(), permanent: true);

    return Obx(
      () => Scaffold(
        // v23.1 — bg blanc (au lieu de scaffold lightGrey) pour éliminer
        // tout grey leak derrière la nav bar (cas Accueil tab).
        backgroundColor: AppColors.appBar(context),
        // v23.1 part 221 — Daniel : "sur la page acceuil owner et sitter
        // je veux que se soit comme la page de walker". Remplacement du
        // HomeHeader custom 70h par un AppBar standard leger (cf note
        // dans home_screen.dart owner).
        appBar: AppBar(
          elevation: 0,
          backgroundColor: AppColors.appBar(context),
          surfaceTintColor: Colors.transparent,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: PoppinsText(
                  text: profileController.userName.value.isNotEmpty
                      ? profileController.userName.value
                      : 'common_user'.tr,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary(context),
                ),
              ),
              SizedBox(width: 8.w),
              // v569 — pastille de rôle à côté du nom (Daniel).
              RoleChip(
                role: Get.isRegistered<AuthController>()
                    ? (Get.find<AuthController>().userRole.value ?? 'sitter')
                    : 'sitter',
                compact: true,
              ),
            ],
          ),
          actions: [
            Obx(() {
              final role = Get.isRegistered<AuthController>()
                  ? (Get.find<AuthController>().userRole.value ?? 'sitter')
                  : 'sitter';
              return BoostQuickAction(role: role);
            }),
            SizedBox(width: 4.w),
            // v569 — cloche modernisée + nombre de non-lus.
            Obx(() => NotificationBellAction(
                  count: notificationsController.unreadCount.value,
                  role: Get.isRegistered<AuthController>() ? (Get.find<AuthController>().userRole.value ?? 'sitter') : 'sitter',
                  onTap: () {
                    Get.to(() => const NotificationsScreen())?.then((_) {
                      notificationsController.refreshUnreadCount();
                    });
                  },
                )),
            SizedBox(width: 8.w),
          ],
        ),
        body: PawPatternBackground(
 color: _accent,
 child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              // v20.0.19 — also reload rates so the "Estimation" block on
              // post cards updates when the sitter just saved new rates in
              // "Mes tarifs". Avant ce fix, _loadProviderRates ne tournait
              // qu'au initState : un sitter qui modifiait son tarif et
              // revenait sur la home voyait toujours l'ancien estimé (ou
              // pas d'estimé du tout si dailyRate était à 0).
              await Future.wait([
                postsController.refreshPosts(),
                profileController.loadMyProfile(),
                _loadPendingApplications(),
                _loadProviderRates(),
              ]);
            },
            color: AppColors.primaryColor,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              // v468 — dégage le bas au-dessus du menu pleine largeur
              padding: EdgeInsets.fromLTRB(
                16.w,
                16.w,
                16.w,
                110.h + appBottomInset(context),
              ),
              child: Column(
                children: [
                  // v21.1.1 — Quick action bar. Le rôle EST détecté au
                  // runtime depuis GetStorage : SitterHomescreen est aussi
                  // utilisé par WalkerNavWrapper (feed partagé), donc on
                  // ne peut pas hardcoder 'sitter' sinon le walker charge
                  // les bookings du sitter (vides) et la barre reste muette.
                  HomeQuickActionBar(
                    role: () {
                      final r = (GetStorage().read(StorageKeys.userRole) ?? '')
                          .toString()
                          .toLowerCase();
                      if (r == 'walker') return 'walker';
                      if (r == 'owner') return 'owner';
                      return 'sitter';
                    }(),
                  ),
                  Obx(() {
                    // Session v15-6 — the Sitter/Walker feed is now driven by
                    // `reservationRequests` which comes from /posts/requests
                    // (already filtered by role on the backend). The legacy
                    // combinedPosts path is kept as a fallback for safety —
                    // if reservationRequests is empty but a media post exists
                    // we still show something.
                    final combinedPosts = <PostModel>[
                      ...postsController.reservationRequests,
                      ...postsController.posts,
                    ];

                    // v23.1 part 143 — Daniel : "je veux que on vois les
                    // filtre pres de chez moi constament". Avant : quand
                    // combinedPosts.isEmpty, on retournait juste un
                    // bouton refresh, masquant TOUTE la barre de filtres
                    // (incluant le slider distance "Près de chez moi").
                    // Maintenant : on garde le spinner pendant le chargement,
                    // mais quand vide on LAISSE LE FLOW continuer pour
                    // que la barre de filtres + le slider distance restent
                    // affichés. L'empty state s'affichera plus bas (icône
                    // inbox + bouton refresh), juste sous les filtres.
                    if (postsController.isLoading.value &&
                        combinedPosts.isEmpty) {
                      // v565 — squelette de chargement (kit Réservations).
                      return BookingLoadingList(accent: _accent);
                    }
                    // Note : pas de early-return empty ici. Le flow continue
                    // avec uniquePosts/rolePrefiltered/feedPosts/sortedFeed
                    // potentiellement vides → barre de filtres visible,
                    // empty state plus bas.

                    // Deduplicate by post id and keep stable ordering.
                    final seenIds = <String>{};
                    final uniquePosts = combinedPosts.where((post) {
                      if (post.id.isEmpty) return true;
                      if (seenIds.contains(post.id)) return false;
                      seenIds.add(post.id);
                      return true;
                    }).toList();

                    // Role-based split for the shared feed:
                    //  - Walker sees ONLY walking requests (`dog_walking`)
                    //  - Sitter sees garderie + garde multi-jours requests
                    //    (`pet_sitting`, `house_sitting`, `day_care`) and
                    //    does NOT see `dog_walking` requests (those are
                    //    exclusive to the Walker role).
                    //  - Other roles see everything (safety net).
                    final currentRole = Get.isRegistered<AuthController>()
                        ? (Get.find<AuthController>().userRole.value ?? '')
                        : '';
                    List<PostModel> rolePrefiltered;
                    if (currentRole == 'walker') {
                      rolePrefiltered = uniquePosts
                          .where(
                            (p) => p.serviceTypes
                                .map((t) => t.toLowerCase())
                                .contains('dog_walking'),
                          )
                          .toList();
                    } else if (currentRole == 'sitter') {
                      const sitterServices = <String>{
                        'pet_sitting',
                        'house_sitting',
                        'day_care',
                      };
                      rolePrefiltered = uniquePosts.where((p) {
                        final types = p.serviceTypes
                            .map((t) => t.toLowerCase())
                            .toSet();
                        // Include posts that request any sitter service.
                        return types.any(sitterServices.contains);
                      }).toList();
                    } else {
                      rolePrefiltered = uniquePosts;
                    }

                    // v441 — filtre distance « Autour de moi » TOUJOURS appliqué
                    // (barre + slider visibles en permanence). Les autres
                    // filtres (ville texte / service / dates) du dialog
                    // s'ajoutent par-dessus quand actifs.
                    final distanceFiltered = _filterByRadius(rolePrefiltered);
                    final feedPosts = _filterState.hasActiveFilters
                        ? _applyRequestFilters(distanceFiltered)
                        : distanceFiltered;

                    final sortedFeed = _sortFeedPosts(feedPosts);
                    // v571 — même lot SANS le filtre distance : sert à
                    // proposer « Les plus proches de toi » quand le rayon
                    // courant ne laisse rien.
                    final beforeDistance = _filterState.hasActiveFilters
                        ? _applyRequestFilters(rolePrefiltered)
                        : rolePrefiltered;

                    return Column(
                      children: [
                        // v441 — barre « Autour de moi » + rayon km (maquettes
                        // 50/51, partagée avec l'accueil owner). Remplace
                        // l'ancien bouton « Près de chez moi » + l'inline
                        // slider : SOURCE UNIQUE du rayon + de l'ancre de
                        // recherche du feed. Accent vert (walker) / bleu
                        // (sitter).
                        _buildAroundMeBar(context),
                        SizedBox(height: 10.h),
                        // Compteur « 🎯 Autour de moi · N résultats trouvés ».
                        _buildAroundMeResults(context, sortedFeed.length),
                        // v442 — #100 : anciens filtres avancés + bouton « Trier »
                        // RETIRÉS (redondants avec la barre « Autour de moi » +
                        // rayon ci-dessus, source unique du périmètre du feed).
                        SizedBox(height: 12.h),
                        if (sortedFeed.isEmpty)
                          // v571 — plus jamais d'écran vide et triste : soit on
                          // propose les annonces les plus proches hors rayon,
                          // soit on affiche le kit d'accueil (illustration +
                          // cartes d'action + rafraîchir à la couleur du rôle).
                          _buildEmptyArea(
                            context,
                            postsController: postsController,
                            currentRole: currentRole,
                            outOfRange: beforeDistance,
                          )
                        else
                          // Display all posts from API
                          ...sortedFeed.map(
                            (post) => _buildPostTile(
                              post,
                              postsController: postsController,
                              currentRole: currentRole,
                            ),
                          ),
                        SizedBox(height: 50.h),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
),
      ),
    );
  }

  /// v571 — distance (km) entre l'ancre « Autour de moi » et une annonce.
  /// null si l'annonce n'a pas de coordonnées ou s'il n'y a pas d'ancre.
  double? _distanceKmTo(PostModel post) {
    final anchor = _effectiveAnchor;
    if (anchor == null) return null;
    final lat = post.location?.lat;
    final lng = post.location?.lng;
    if (lat == null || lng == null) return null;
    return haversineKm(anchor.lat, anchor.lng, lat, lng); // Lot D : même règle que le filtre
  }

  /// v571 — écran de modification du profil DU RÔLE (même écran que l'onglet
  /// Profil › « Modifier le profil »).
  void _openMyProfileEditor() {
    if (_isWalkerViewer) {
      Get.to(() => const EditWalkerProfileScreen());
    } else {
      Get.to(() => const EditSitterProfileScreen());
    }
  }

  /// v571 — ce qu'on affiche quand le feed filtré est VIDE.
  ///
  ///   · s'il existe des annonces hors rayon (avec coordonnées) → section
  ///     « Les plus proches de toi » : carte-info « Rien dans un rayon de X km »
  ///     + bouton « Élargir à Y km », puis les 10 annonces les plus proches,
  ///     chacune avec sa pastille de distance ;
  ///   · sinon → le kit d'accueil (illustration qui respire, cartes d'action,
  ///     bouton « Rafraîchir » à la couleur du rôle).
  Widget _buildEmptyArea(
    BuildContext context, {
    required PostsController postsController,
    required String currentRole,
    required List<PostModel> outOfRange,
  }) {
    final nearest = <({PostModel post, double km})>[];
    for (final post in outOfRange) {
      final km = _distanceKmTo(post);
      if (km == null) continue;
      // Les annonces DANS le rayon sont déjà couvertes par le feed (si elles
      // n'y sont pas, c'est un autre filtre : on ne les remonte pas ici).
      if (km <= _radiusKm) continue;
      nearest.add((post: post, km: km));
    }
    nearest.sort((a, b) => a.km.compareTo(b.km));
    final shortlist = nearest.take(10).toList();

    if (shortlist.isEmpty) {
      return HomeEmptyKit(
        accent: _accent,
        onRefresh: () => postsController.refreshPosts(),
        onCompleteProfile: _openMyProfileEditor,
        onInvite: shareFriendsInvite,
        onBoost: () => Get.to(() => const CoinShopScreen()),
      );
    }

    // Plus petite valeur (arrondie au 10 km SUPÉRIEUR, bornée au max) qui
    // inclut l'annonce la plus proche.
    final suggested = ((shortlist.first.km / 10).ceil() * 10).clamp(
      _kMinRadiusKm.toInt(),
      _kMaxRadiusKm.toInt(),
    );
    final currentKm = _radiusKm.round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeRadiusHintCard(
          accent: _accent,
          currentKm: currentKm,
          suggestedKm: suggested,
          onExpand: suggested > currentKm
              ? () => _applyRadius(suggested.toDouble())
              : null,
        ),
        PoppinsText(
          text: 'home571_nearest_title'.tr,
          fontSize: 14.sp,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary(context),
          maxLines: 2,
        ),
        SizedBox(height: 10.h),
        ...shortlist.map(
          (e) => _buildPostTile(
            e.post,
            postsController: postsController,
            currentRole: currentRole,
            distanceKm: e.km.round(),
          ),
        ),
      ],
    );
  }

  /// v571 — rendu d'UNE carte d'annonce. Extrait tel quel du `build` pour
  /// être réutilisé par la section « Les plus proches de toi » SANS dupliquer
  /// le rendu. [distanceKm] non nul ajoute la pastille « à 82 km » au-dessus.
  Widget _buildPostTile(
    PostModel post, {
    required PostsController postsController,
    required String currentRole,
    int? distanceKm,
  }) {
    // Get all image URLs from the post
    final imageUrls = post.images
        .map((img) => img.url)
        .where((url) => url.isNotEmpty)
        .toList();
    final petName = post.pets.isNotEmpty
        ? post.pets.first.petName
        : null;
    // DEEP WORK — résolution robuste du petId pour la
    // demande : on prend l'animal résolu de l'annonce en
    // priorité (post.pets), puis on retombe sur post.petIds
    // / post.petId pour les anciennes annonces où la liste
    // d'animaux sérialisée serait vide alors qu'un pet
    // existe bien. Évite le faux « annonce incomplète ».
    final petId = _resolvePostPetId(post);
    final ownerId = post.owner.id.isNotEmpty
        ? post.owner.id
        : '';
    final rawCity = post.location?.city.trim();
    final locationLabel =
        (rawCity != null && rawCity.isNotEmpty)
        ? rawCity
        : null;
    final dateRangeLabel = _postDateRangeLabel(post);
    final serviceTypesLabel = _serviceTypesDisplay(
      post.serviceTypes,
    );
    // Session v17.1 — lookup priority:
    //   1) in-session map (when the sitter just sent
    //      the request this session)
    //   2) stable post-id map (populated from
    //      application.postId — 100% reliable across
    //      logouts)
    //   3) legacy multi-field fingerprint (fallback
    //      for apps sent before v17.1 without postId).
    final pendingApplicationId =
        _pendingApplicationIds[post.id] ??
        _pendingApplicationIdsByPostId[post.id] ??
        _pendingApplicationIdsByFingerprint[_buildRequestFingerprint(
          ownerId: ownerId,
          petId: petId ?? '',
          serviceType: post.serviceTypes.isNotEmpty
              ? post.serviceTypes.first
              : '',
          serviceDate: _serviceDateForPost(post),
          startDate: _startDateForPost(post),
          endDate: _endDateForPost(post),
          timeSlot: _defaultTimeSlotForPost(post),
        )];
    final isCancelMode = pendingApplicationId != null;

    final priceEstimate = _estimateForPost(post);
    final Widget card = Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: PetPostCard(
        userName: post.owner.name,
        userEmail: '',
        userAvatar: post.owner.avatar.isNotEmpty
            ? post.owner.avatar
            : null,
        petImages: imageUrls,
        // v420 — maquette détail annonce : animaux + bio.
        pets: post.pets,
        ownerBio: post.owner.bio,
        serviceLocation: post.serviceLocation,
        meetingPoint: post.meetingPoint,
        postBody: post.body,
        petName: petName,
        serviceTypes: serviceTypesLabel.isEmpty
            ? null
            : serviceTypesLabel,
        dateRange: dateRangeLabel,
        // v443 — heure → horloge sous « Service ».
        serviceTime: _postTimeLabel(post),
        location: locationLabel,
        isNetworkImage: imageUrls.isNotEmpty,
        likeCount: post.likesCount,
        priceEstimate: priceEstimate,
        viewerRole: currentRole,
        // #107 — en-tête annonce cliquable côté
        // prestataire → profil propriétaire (lecture
        // seule) avec ses animaux. Désactivé si l'owner
        // est inconnu.
        onOwnerTap: ownerId.isNotEmpty
            ? () => _openOwnerProfile(post, ownerId)
            : null,
        // DEEP WORK — chaque animal de la bande annonce
        // est cliquable → fiche complète (même chemin que
        // « Voir les animaux »).
        onPetTap: (id) => _handleCardTap(id),
        // Session v17.1 — show the "Réservé" badge when
        // the owner has already accepted someone for
        // this post.
        isReserved: post.isReserved,
        reservedProviderRole:
            post.reservedBy?.providerRole,
        // v23.1 part 116 — annonce boostée (owner a un
        // Boost actif). Affiche le ruban "🚀 URGENT".
        isOwnerBoosted: post.isOwnerBoosted,
        ownerBoostTier: post.ownerBoostTier,
        // Comments disabled on publications
        commentCount: 0,
        isLiked: postsController.isPostLiked(post.id),
        onViewPetDetails: petId != null
            ? () async => _handleCardTap(petId)
            : null,
        // v23.1.153 — Daniel : "le bouton demande
        // direct n'apparait pas". Avant : si
        // ownerId/petId/serviceTypes manquaient
        // dans le post (cas owner sans pet, ou
        // post sans serviceType), le callback
        // etait null → bouton invisible →
        // sitter/walker ne pouvait plus envoyer
        // de demande. Maintenant : on TOUJOURS
        // passe un callback (le bouton est visible)
        // et on valide les donnees a l'interieur,
        // avec snackbar explicite si quelque
        // chose manque.
        onSendRequest: () async {
          // v565 (point 25) — coordonnées obligatoires
          // avant de postuler à une annonce.
          if (!await ensureContactInfo(
            context,
            role: _isWalkerViewer ? 'walker' : 'sitter',
          )) {
            return;
          }
          if (ownerId.isEmpty ||
              petId == null ||
              post.serviceTypes.isEmpty) {
            CustomSnackbar.showError(
              title: 'common_error'.tr,
              message: 'post_incomplete_for_request'.tr,
            );
            return;
          }
          if (isCancelMode) {
            await _handleCancelRequest(
              requestKey: post.id,
              applicationId: pendingApplicationId,
            );
          } else {
            await _handleSendRequest(
              requestKey: post.id,
              ownerId: ownerId,
              petId: petId,
              serviceType: post.serviceTypes.first,
              serviceDate: _serviceDateForPost(post),
              startDate: _startDateForPost(post),
              endDate: _endDateForPost(post),
              timeSlot: _defaultTimeSlotForPost(post),
              houseSittingVenue: post.houseSittingVenue,
              duration: _durationForPostService(
                post,
                post.serviceTypes.first,
              ),
              // v17.1 — forward the post id so the
              // backend stores Application.postId.
              postId: post.id,
            );
          }
        },
        requestButtonText: isCancelMode
            ? 'request_cancel_button'.tr
            : 'send_request_button'.tr,
        isCancelRequest: isCancelMode,
        isRequestLoading:
            _loadingStates[post.id] ?? false,
        onLike: () {
          // Toggle like with optimistic update
          postsController.toggleLike(post.id);
        },
        // Comments disabled on publications
        onComment: null,
        onBlockUser: ownerId.isNotEmpty
            ? () => _handleBlockOwner(
                ownerId: ownerId,
                ownerName: post.owner.name,
              )
            : null,
        onReportPost: () =>
            _handleReportPost(postId: post.id),
        // v23.1.170 — Daniel : "quand je partage la
        // demande dune publication sa menvoi lannonce
        // de la photo corrige sur les 3 profile".
        // Sitter envoyait `shareText = post.body` sans
        // lien deep-link → WhatsApp/Telegram/Instagram
        // priorise l'image et tronque le texte. On
        // mirror le pattern owner home (l.494) : texte
        // i18n avec @link + subject traduit.
        onShare: () {
          () async {
            try {
              final petName = post.pets.isNotEmpty
                  ? post.pets.first.petName
                  : '';
              // v23.1.170 — voir home_screen.dart
              // pour le pourquoi du .com au lieu de
              // .app (domaine inexistant).
              final link =
                  'https://hopetsit.com/post/${post.id}';
              final subject = 'share_post_subject'
                  .trParams({
                    'petName': petName.isEmpty
                        ? 'HoPetSit'
                        : petName,
                  });
              final shareText = 'share_post_body'
                  .trParams({'link': link});

              final filesToShare = <XFile>[];

              if (imageUrls.isNotEmpty) {
                final tmp = await getTemporaryDirectory();
                for (
                  var i = 0;
                  i < imageUrls.length;
                  i++
                ) {
                  final imageUrl = imageUrls[i];
                  if (imageUrl.startsWith('http')) {
                    // v23.1.175 — Daniel : 14 crashes
                    // _Uri.resolve FormatException sur
                    // v169/v170. Cause : Uri.parse(url)
                    // throw si url contient espace ou
                    // caractères interdits. Fix : tryParse.
                    final uri = Uri.tryParse(imageUrl);
                    if (uri == null || !uri.hasScheme) {
                      continue;
                    }
                    final resp = await http.get(uri);
                    if (resp.statusCode == 200) {
                      final bytes = resp.bodyBytes;
                      final file = File(
                        '${tmp.path}/share_${post.id}_$i.jpg',
                      );
                      await file.writeAsBytes(bytes);
                      filesToShare.add(XFile(file.path));
                    }
                  } else {
                    // Treat as local asset path.
                    try {
                      final data = await rootBundle.load(
                        imageUrl,
                      );
                      final bytes = data.buffer
                          .asUint8List();
                      final file = File(
                        '${tmp.path}/share_${post.id}_$i.png',
                      );
                      await file.writeAsBytes(bytes);
                      filesToShare.add(XFile(file.path));
                    } catch (_) {
                      // Ignore only failed image and continue sharing others.
                    }
                  }
                }
              }

              if (filesToShare.isNotEmpty) {
                await SharePlus.instance.share(
                  ShareParams(
                    files: filesToShare,
                    text: shareText,
                    subject: subject,
                  ),
                );
              } else {
                await SharePlus.instance.share(
                  ShareParams(
                    text: shareText,
                    subject: subject,
                  ),
                );
              }
            } catch (error) {
              AppLogger.logError(
                'SitterHomescreen: share failed',
                error: error,
              );
              CustomSnackbar.showError(
                title: 'common_error'.tr,
                message: 'share_failed'.tr,
              );
            }
          }();
        },
      ),
    );
    if (distanceKm == null) return card;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeDistancePill(accent: _accent, km: distanceKm),
        card,
      ],
    );
  }

  Future<void> _handleSendRequest({
    required String requestKey,
    required String ownerId,
    required String? petId,
    required String serviceType,
    required String serviceDate,
    String? startDate,
    String? endDate,
    required String timeSlot,
    String? houseSittingVenue,
    int? duration,
    // Session v17.1 — postId of the originating Post, forwarded to the
    // backend so Application.postId is set. This is what the sitter home
    // screen uses as the stable key to decide whether to show Cancel vs
    // Send-request on each post card after a fresh login.
    String? postId,
  }) async {
    // Button is only enabled when petId is non-null, but guard anyway.
    if (petId == null || petId.isEmpty) {
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'request_pet_required'.tr,
      );
      return;
    }

    setState(() {
      _loadingStates[requestKey] = true;
    });

    try {
      final sitterRepository = Get.find<SitterRepository>();
      final basePrice = await _resolveProviderBasePrice(sitterRepository);
      if (basePrice <= 0) {
        CustomSnackbar.showError(
          title: 'common_error'.tr,
          message: 'request_sitter_pricing_error'.tr,
        );
        return;
      }
      final normalizedService = serviceType
          .trim()
          .toLowerCase()
          .replaceAll('-', '_')
          .replaceAll(' ', '_');
      final venueForHouseSitting = normalizedService == 'house_sitting'
          ? ((houseSittingVenue == 'owners_home' ||
                    houseSittingVenue == 'sitters_home')
                ? houseSittingVenue
                : 'owners_home')
          : null;

      final response = await sitterRepository.createApplication(
        ownerId: ownerId,
        petIds: [petId],
        serviceType: serviceType,
        houseSittingVenue: venueForHouseSitting,
        serviceDate: serviceDate,
        startDate: startDate,
        endDate: endDate,
        timeSlot: timeSlot,
        basePrice: basePrice,
        duration: duration,
        postId: postId, // v17.1 — stable post reference
      );

      final application =
          response['application'] as Map<String, dynamic>? ?? const {};
      final applicationId = application['id']?.toString() ?? '';
      final duplicatePrevented = response['duplicatePrevented'] == true;
      final fingerprint = _buildRequestFingerprint(
        ownerId: ownerId,
        petId: petId,
        serviceType: serviceType,
        serviceDate: serviceDate,
        startDate: startDate,
        endDate: endDate,
        timeSlot: timeSlot,
      );
      if (applicationId.isNotEmpty && mounted) {
        setState(() {
          _pendingApplicationIds[requestKey] = applicationId;
          _pendingApplicationIdsByFingerprint[fingerprint] = applicationId;
          // v17.1 — record the stable (postId → appId) mapping so reloads
          // after logout/login resolve the Cancel button reliably.
          if (postId != null && postId.isNotEmpty) {
            _pendingApplicationIdsByPostId[postId] = applicationId;
          }
        });
      }

      CustomSnackbar.showSuccess(
        title: 'common_success'.tr,
        message: duplicatePrevented
            ? (response['message']?.toString() ?? 'request_send_success'.tr)
            : 'request_send_success'.tr,
      );
    } on ApiException catch (error) {
      // v575 — audit P2-3 : toutes les erreurs étaient remplacées par
      // « Échec de l'envoi de la demande », y compris celles qui disent
      // EXACTEMENT quoi corriger (durée invalide, tarif manquant, annonce
      // déjà réservée…). On affiche le message du serveur quand il existe,
      // et un message dédié pour sa propre annonce (code `OWN_POST`).
      AppLogger.logError('Failed to send request', error: error.message);
      final details = error.details;
      final code = details is Map ? (details['code'] ?? '').toString() : '';
      final serverMessage = error.message.trim();
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: code == 'OWN_POST'
            ? 'fixes575_own_post'.tr
            : (serverMessage.isNotEmpty
                ? serverMessage
                : 'request_send_failed'.tr),
      );
    } catch (error) {
      AppLogger.logError('Failed to send request', error: error);
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'request_send_failed'.tr,
      );
    } finally {
      if (mounted) {
        setState(() {
          _loadingStates[requestKey] = false;
        });
      }
    }
  }

  Future<void> _handleCancelRequest({
    required String requestKey,
    required String? applicationId,
  }) async {
    if (applicationId == null || applicationId.isEmpty) {
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'request_cancel_error'.tr,
      );
      return;
    }

    setState(() {
      _loadingStates[requestKey] = true;
    });

    try {
      final sitterRepository = Get.find<SitterRepository>();
      await sitterRepository.cancelApplicationRequest(
        applicationId: applicationId,
      );

      if (mounted) {
        setState(() {
          _pendingApplicationIds.remove(requestKey);
          _pendingApplicationIdsByFingerprint.removeWhere(
            (_, id) => id == applicationId,
          );
          // v17.1 — also drop the stable post-id mapping so the button flips
          // back to "Send request" immediately.
          _pendingApplicationIdsByPostId.removeWhere(
            (_, id) => id == applicationId,
          );
        });
      }

      CustomSnackbar.showSuccess(
        title: 'common_success'.tr,
        message: 'request_cancel_success'.tr,
      );
    } on ApiException catch (error) {
      AppLogger.logError('Failed to cancel request', error: error.message);
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: error.message,
      );
    } catch (error) {
      AppLogger.logError('Failed to cancel request', error: error);
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'request_cancel_error'.tr,
      );
    } finally {
      if (mounted) {
        setState(() {
          _loadingStates[requestKey] = false;
        });
      }
    }
  }

  Future<void> _loadPendingApplications() async {
    try {
      final sitterRepository = Get.find<SitterRepository>();
      final applications = await sitterRepository.getMyApplicationsRaw();

      if (!mounted) return;
      setState(() {
        _pendingApplicationIdsByFingerprint.clear();
        _pendingApplicationIdsByPostId.clear();
        for (final app in applications) {
          final status = (app['status']?.toString() ?? '').toLowerCase();
          if (status != 'pending') continue;

          final appId = app['id']?.toString() ?? '';
          if (appId.isEmpty) continue;

          // Session v17.1 — if the application carries a stable postId
          // reference (applications created on v17.1+ servers), record it
          // in the postId map. The card rendering code checks this first
          // before falling back to the fragile fingerprint map.
          final postIdValue = app['postId']?.toString();
          if (postIdValue != null &&
              postIdValue.isNotEmpty &&
              postIdValue != 'null') {
            _pendingApplicationIdsByPostId[postIdValue] = appId;
          }

          final owner = app['owner'];
          final ownerId = owner is Map ? owner['id']?.toString() ?? '' : '';
          if (ownerId.isEmpty) continue;

          final petIds = app['petIds'];
          String petId = '';
          if (petIds is List && petIds.isNotEmpty) {
            petId = petIds.first?.toString() ?? '';
          }
          if (petId.isEmpty) continue;

          final serviceType = app['serviceType']?.toString() ?? '';
          final serviceDate = app['serviceDate']?.toString() ?? '';
          final startDate = app['startDate']?.toString();
          final endDate = app['endDate']?.toString();
          final timeSlot = app['timeSlot']?.toString() ?? '';
          if (serviceType.isEmpty || serviceDate.isEmpty || timeSlot.isEmpty) {
            continue;
          }

          final key = _buildRequestFingerprint(
            ownerId: ownerId,
            petId: petId,
            serviceType: serviceType,
            serviceDate: serviceDate,
            startDate: startDate,
            endDate: endDate,
            timeSlot: timeSlot,
          );
          _pendingApplicationIdsByFingerprint[key] = appId;
        }
      });
    } catch (error) {
      AppLogger.logError('Failed to load pending applications', error: error);
    }
  }

  /// Session v16-owner-walker — renamed from `_resolveSitterBasePrice`
  /// so it can cover both provider roles. When the connected user is a
  /// walker we fetch their walkRates and convert to an hourly equivalent
  /// (60-min rate, or 30-min × 2, or per-hour prorata of 90/120 slots).
  /// Otherwise the existing sitter path runs unchanged, so the large
  /// majority of calls (Sitter → annonce Owner) keep the same behaviour.
  Future<double> _resolveProviderBasePrice(
    SitterRepository sitterRepository,
  ) async {
    try {
      final storage = GetStorage();
      final userProfile = storage.read<Map<String, dynamic>>(
        StorageKeys.userProfile,
      );
      final providerId = userProfile?['id']?.toString() ?? '';
      if (providerId.isEmpty) {
        return 0;
      }

      final role = Get.isRegistered<AuthController>()
          ? (Get.find<AuthController>().userRole.value ?? '')
          : '';

      if (role == 'walker') {
        // Fetch the walker's own rate grid and normalise to an hourly
        // equivalent. We don't want to crash when walkRates is empty or
        // every entry is disabled — just return 0 and let the UI ask the
        // walker to set a rate in the profile first.
        final walkerRepository = Get.find<WalkerRepository>();
        final walker = await walkerRepository.getWalkerProfile(providerId);
        double? findRate(int minutes) {
          for (final r in walker.walkRates) {
            if (r.durationMinutes == minutes && r.enabled && r.basePrice > 0) {
              return r.basePrice;
            }
          }
          return null;
        }

        final hour = findRate(60);
        if (hour != null) return hour;
        final half = findRate(30);
        if (half != null) return half * 2;
        final ninety = findRate(90);
        if (ninety != null) return ninety * (60 / 90);
        final twoHours = findRate(120);
        if (twoHours != null) return twoHours / 2;
        return 0;
      }

      // Sitter path — /sitters/me/profile is not available in current
      // backend env; use /sitters/{id}.
      final profile = await sitterRepository.getSitterProfile(providerId);
      final data =
          profile['sitter'] as Map<String, dynamic>? ??
          profile['profile'] as Map<String, dynamic>? ??
          profile;

      final fromHourly = (data['hourlyRate'] as num?)?.toDouble();
      if (fromHourly != null && fromHourly > 0) {
        return fromHourly;
      }
      final fromDaily = (data['dailyRate'] as num?)?.toDouble();
      if (fromDaily != null && fromDaily > 0) {
        return fromDaily;
      }
      final fromWeekly = (data['weeklyRate'] as num?)?.toDouble();
      if (fromWeekly != null && fromWeekly > 0) {
        return fromWeekly;
      }
      final fromMonthly = (data['monthlyRate'] as num?)?.toDouble();
      if (fromMonthly != null && fromMonthly > 0) {
        return fromMonthly;
      }
      final fromRateString = double.tryParse(data['rate']?.toString() ?? '');
      if (fromRateString != null && fromRateString > 0) {
        return fromRateString;
      }
    } catch (error) {
      AppLogger.logError('Failed to resolve provider base price', error: error);
    }

    // Do not send fallback for invalid/unknown provider pricing.
    return 0;
  }

  /// #107 — ouvre le profil PROPRIÉTAIRE en lecture seule depuis l'en-tête de
  /// l'annonce. Réutilise les données déjà portées par le post (owner + pets) ;
  /// les fiches animaux sont chargées au tap d'une carte (même chemin que
  /// _handleCardTap).
  void _openOwnerProfile(PostModel post, String ownerId) {
    final rawCity = post.location?.city.trim();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OwnerProfileViewScreen(
          ownerId: ownerId,
          ownerName: post.owner.name,
          ownerAvatar: post.owner.avatar.isNotEmpty ? post.owner.avatar : null,
          ownerBio: post.owner.bio,
          ownerCity: (rawCity != null && rawCity.isNotEmpty) ? rawCity : null,
          pets: post.pets,
        ),
      ),
    );
  }

  Future<void> _handleCardTap(String petId) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: EdgeInsets.all(20.w),
          decoration: BoxDecoration(
            color: AppColors.card(context),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.primaryColor,
                ),
              ),
              SizedBox(height: 16.h),
              InterText(
                text: 'pet_detail_loading'.tr,
                fontSize: 14.sp,
                fontWeight: FontWeight.w400,
                color: AppColors.textPrimary(context),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final petRepository = Get.find<PetRepository>();
      final pet = await petRepository.getPetById(petId);

      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Map pet data to PetDetailScreen format
      final age = pet.age.isNotEmpty ? pet.age : 'label_not_available'.tr;
      final gender = 'pet_detail_gender_unknown'
          .tr; // Gender not in PetModel, using default
      final weight = pet.weight.isNotEmpty
          ? '${pet.weight} kg'
          : 'label_not_available'.tr;
      final height = pet.height.isNotEmpty
          ? '${pet.height} cm'
          : 'label_not_available'.tr;
      // v21.1 — `color` (couleur de l'animal) supprimé de PetDetailScreen.
      final description = pet.bio.isNotEmpty
          ? pet.bio
          : 'pet_detail_no_description'.tr;

      // Get gallery images from photos
      final List<String> galleryImages = [];
      if (pet.photos.isNotEmpty) {
        for (var photo in pet.photos) {
          if (photo is Map<String, dynamic> && photo['url'] != null) {
            galleryImages.add(photo['url'].toString());
          } else if (photo is String) {
            galleryImages.add(photo);
          }
        }
      }

      // Get vaccinations
      final vaccinations = pet.vaccinations.isNotEmpty
          ? pet.vaccinations
          : ['pet_detail_no_vaccinations'.tr];

      // Get pet images array (avatar + gallery images, removing duplicates)
      final List<String> petImages = [];
      if (pet.avatar.url.isNotEmpty) {
        petImages.add(pet.avatar.url);
      }
      // Add gallery images that are different from avatar
      for (var galleryImage in galleryImages) {
        if (!petImages.contains(galleryImage)) {
          petImages.add(galleryImage);
        }
      }
      // If no images at all, use empty list (will show placeholder)

      // Get sitter profile image
      final SitterProfileController profileController =
          Get.find<SitterProfileController>();
      final sitterProfileImage = profileController.profileImageUrl.value;

      // Get owner information from pet model
      final ownerName = pet.owner?.name;
      final ownerAvatar = pet.owner?.avatar;
      // v22.1 — Bug 11c : ville propriétaire pour la page détails animal.
      final ownerCity = pet.owner?.city;
      final ownerCreatedAt = pet.owner?.createdAt;
      final ownerUpdatedAt = pet.owner?.updatedAt;

      // Get additional pet details
      final passportNumber = pet.passportNumber.isNotEmpty
          ? pet.passportNumber
          : null;
      final chipNumber = pet.chipNumber.isNotEmpty ? pet.chipNumber : null;
      final medicationAllergies = pet.medicationAllergies.isNotEmpty
          ? pet.medicationAllergies
          : null;
      final dob = pet.dob.isNotEmpty ? pet.dob : null;
      final category = pet.category.isNotEmpty ? pet.category : null;

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PetDetailScreen(
              petName: pet.petName,
              breed: pet.breed.isNotEmpty
                  ? pet.breed
                  : 'pet_detail_breed_unknown'.tr,
              age: age,
              gender: gender,
              weight: weight,
              height: height,
              description: description,
              vaccinations: vaccinations,
              galleryImages: galleryImages,
              petImages: petImages,
              sitterProfileImage: sitterProfileImage,
              ownerName: ownerName,
              ownerAvatar: ownerAvatar,
              ownerCity: ownerCity,
              ownerCreatedAt: ownerCreatedAt,
              ownerUpdatedAt: ownerUpdatedAt,
              passportNumber: passportNumber,
              chipNumber: chipNumber,
              medicationAllergies: medicationAllergies,
              dob: dob,
              category: category,
            ),
          ),
        );
      }
    } on ApiException catch (error) {
      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }
      AppLogger.logError('Failed to load pet details', error: error.message);
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: error.message,
      );
    } catch (error) {
      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }
      AppLogger.logError('Failed to load pet details', error: error);
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'pet_detail_load_error'.tr,
      );
    }
  }

  Future<void> _handleBlockOwner({
    required String ownerId,
    required String ownerName,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.card(dialogContext),
        title: InterText(
          text: 'block_user_title'.tr,
          fontSize: 16.sp,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary(dialogContext),
        ),
        content: InterText(
          text: 'block_user_confirm_message'.tr.replaceAll('{name}', ownerName),
          fontSize: 14.sp,
          color: AppColors.textPrimary(dialogContext),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: InterText(
              text: 'common_cancel'.tr,
              fontSize: 14.sp,
              color: AppColors.textSecondary(dialogContext),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: InterText(
              text: 'block_user_action'.tr,
              fontSize: 14.sp,
              color: AppColors.errorColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    // TODO: wire real block API; for now surface a success snackbar.
    CustomSnackbar.showSuccess(
      title: 'common_success'.tr,
      message: 'block_user_confirm_message'.tr.replaceAll('{name}', ownerName),
    );
  }

  /// v23.1 part 240 — Daniel : "deja quand la barre est a 0 sa dois
  /// mafficher uniquement les profile de 0 a 50km de chez moi et apres
  /// plus je monte plus sa safiche avec le bon kms, et sa verifie sur
  /// chaque profile et chaque barre dans owner sitter et walker". Sitter
  /// side : meme contrainte que owner home — slider min 50 km, plus de
  /// mode "toutes les distances".
  // v441 — bornes du rayon « Autour de moi » (slider 50 → 500 km). L'ancien
  // _buildInlineDistanceSlider + le StatefulWidget _InlineDistanceSlider ont
  // été supprimés : le rayon est maintenant porté par la barre partagée
  // AroundMeSearchBar (cf _buildAroundMeBar).
  // Lot D (25/09/2026) — mêmes bornes que l'accueil propriétaire (10–500 km,
  // pas de 10) : un gardien en ville veut aussi les annonces à moins de 50 km.
  static const double _kMinRadiusKm = 10.0;
  static const double _kMaxRadiusKm = 500.0;
  static const double _kDefaultRadiusKm = 50.0;

  /// Stub — report post flow. The real implementation opens ReportDialog.
  /// Kept lightweight so the feed still compiles while the report UI is
  /// finalised for the sitter side.
  void _handleReportPost({required String postId}) {
    // TODO: wire ReportDialog.show(context: context, targetType: 'post', targetId: postId)
    AppLogger.logUserAction('Report post pressed', data: {'postId': postId});
  }
}

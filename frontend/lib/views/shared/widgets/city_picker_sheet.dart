// v571 — Feuille « choisir une ville » PARTAGÉE (accueil gardien / promeneur,
// et branchable telle quelle sur l'accueil propriétaire).
//
// Elle remplace l'ancien `showModalBottomSheet` + `CityLocationPicker` qui
// vivait en double dans `sitter_homescreen.dart` (`_showAroundMeCityPicker`) et
// `pet_owner/home/home_screen.dart` (`_showCityPickerSheet`). La LOGIQUE est
// reprise telle quelle :
//   · géocodage Nominatim (mêmes paramètres : q, format=json, addressdetails=1,
//     limit=6, accept-language = langue de l'app), debounce 350 ms, même
//     déduplication ville|pays et même plafond de 5 suggestions ;
//   · « utiliser ma position » = l'ancien bouton `onGetLocation` des deux
//     écrans (owner : `clearSearchCity()` ; sitter : efface l'ancre ville) ;
//   · valeur renvoyée : (ville, lat, lng) comme l'ancien `onLocationSelected`.
//
// Elle est INDÉPENDANTE de tout State : tout passe par des paramètres et la
// valeur de retour du Future, donc les deux accueils peuvent l'appeler.
//
// ⚠️ Dégagement bas : `showModalBottomSheet(useSafeArea: true)` enveloppe la
// feuille dans `SafeArea(bottom: FALSE)` — Flutter ne protège JAMAIS le bas.
// On ajoute donc `appBottomInset(context)` au padding bas, et
// `MediaQuery.viewInsetsOf(context).bottom` pour le clavier.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/utils/bottom_inset.dart';
import 'package:hopetsit/widgets/app_text.dart';

/// Résultat de la feuille.
///
///   · [useMyPosition] = true  → l'appelant doit repartir sur la géolocalisation
///     de l'appareil (owner : `clearSearchCity()` ; sitter : ancre à null) ;
///   · sinon [city] / [lat] / [lng] portent la ville choisie.
class CityPickerResult {
  const CityPickerResult.city({
    required this.city,
    required this.lat,
    required this.lng,
    this.country = '',
  }) : useMyPosition = false;

  const CityPickerResult.myPosition()
      : useMyPosition = true,
        city = '',
        country = '',
        lat = null,
        lng = null;

  final bool useMyPosition;
  final String city;
  final String country;
  final double? lat;
  final double? lng;

  /// Libellé « Ville, Pays » (vide si aucune ville).
  String get label => <String>[city, country]
      .where((String s) => s.trim().isNotEmpty)
      .join(', ');
}

/// Ouvre la feuille et renvoie le choix de l'utilisateur (null s'il ferme).
///
/// [accent] colore l'icône, le champ au focus et la ligne « ma position ».
/// [initialCity] pré-remplit le champ de recherche.
/// [allowMyPosition] masque la ligne « Utiliser ma position » si false.
Future<CityPickerResult?> showCityPickerSheet(
  BuildContext context, {
  required Color accent,
  String initialCity = '',
  bool allowMyPosition = true,
  String? title,
  String? subtitle,
}) {
  return showModalBottomSheet<CityPickerResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext ctx) => _CityPickerSheet(
      accent: accent,
      initialCity: initialCity,
      allowMyPosition: allowMyPosition,
      title: title ?? 'home_change_city_title'.tr,
      subtitle: subtitle ?? 'home_change_city_hint'.tr,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────

class _CityPickerSheet extends StatefulWidget {
  const _CityPickerSheet({
    required this.accent,
    required this.initialCity,
    required this.allowMyPosition,
    required this.title,
    required this.subtitle,
  });

  final Color accent;
  final String initialCity;
  final bool allowMyPosition;
  final String title;
  final String subtitle;

  @override
  State<_CityPickerSheet> createState() => _CityPickerSheetState();
}

/// Clé GetStorage des villes récemment choisies (max 5).
const String _kRecentCitiesKey = 'home571_recent_cities';

class _CityPickerSheetState extends State<_CityPickerSheet> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialCity);
  final FocusNode _focus = FocusNode();

  Timer? _debounce;
  List<_CitySuggestion> _suggestions = const <_CitySuggestion>[];
  List<_CitySuggestion> _recents = const <_CitySuggestion>[];
  bool _loading = false;
  bool _noResult = false;
  String _lastQuery = '';
  bool _suppressNext = false;

  @override
  void initState() {
    super.initState();
    _recents = _readRecents();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ── Villes récentes (GetStorage) ──────────────────────────────────────────

  List<_CitySuggestion> _readRecents() {
    try {
      final dynamic raw = GetStorage().read(_kRecentCitiesKey);
      if (raw is! List) return const <_CitySuggestion>[];
      final List<_CitySuggestion> out = <_CitySuggestion>[];
      for (final dynamic item in raw) {
        if (item is! Map) continue;
        final String city = item['city']?.toString() ?? '';
        if (city.isEmpty) continue;
        out.add(_CitySuggestion(
          city: city,
          country: item['country']?.toString() ?? '',
          lat: (item['lat'] as num?)?.toDouble() ?? 0.0,
          lon: (item['lng'] as num?)?.toDouble() ?? 0.0,
        ));
        if (out.length >= 5) break;
      }
      return out;
    } catch (_) {
      return const <_CitySuggestion>[];
    }
  }

  void _rememberRecent(_CitySuggestion s) {
    try {
      final List<_CitySuggestion> next = <_CitySuggestion>[
        s,
        ..._recents.where((_CitySuggestion r) => r != s),
      ].take(5).toList();
      GetStorage().write(
        _kRecentCitiesKey,
        next
            .map((_CitySuggestion r) => <String, dynamic>{
                  'city': r.city,
                  'country': r.country,
                  'lat': r.lat,
                  'lng': r.lon,
                })
            .toList(),
      );
    } catch (_) {
      /* noop — une ville récente perdue n'est pas une erreur bloquante. */
    }
  }

  // ── Recherche (logique reprise de CityLocationPicker) ─────────────────────

  void _onTextChanged() {
    if (_suppressNext) {
      _suppressNext = false;
      return;
    }
    final String q = _controller.text.trim();
    if (q.length < 2) {
      if (_suggestions.isNotEmpty || _loading || _noResult) {
        setState(() {
          _suggestions = const <_CitySuggestion>[];
          _loading = false;
          _noResult = false;
        });
      } else {
        setState(() {}); // rafraîchit le bouton « effacer ».
      }
      return;
    }
    if (q == _lastQuery) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(q));
    setState(() {}); // bouton « effacer » visible dès la 1re lettre.
  }

  Future<void> _search(String q) async {
    _lastQuery = q;
    if (!mounted) return;
    setState(() {
      _loading = true;
      _noResult = false;
    });
    try {
      // Nominatim — gratuit, sans clé, déjà utilisé par CityLocationPicker.
      final Uri uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeQueryComponent(q)}'
        '&format=json'
        '&addressdetails=1'
        '&limit=6'
        '&accept-language=${Get.locale?.languageCode ?? 'fr'}',
      );
      final http.Response res = await http.get(
        uri,
        headers: const <String, String>{
          'User-Agent': 'HoPetSit/20.0 (contact@hopetsit.com)',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _suggestions = const <_CitySuggestion>[];
        });
        return;
      }
      final List<dynamic> raw = json.decode(res.body) as List<dynamic>;
      final List<_CitySuggestion> out = <_CitySuggestion>[];
      final Set<String> seen = <String>{};
      for (final dynamic item in raw) {
        if (item is! Map) continue;
        final Map<dynamic, dynamic> addr =
            (item['address'] as Map<dynamic, dynamic>?) ??
                const <dynamic, dynamic>{};
        final String city = (addr['city'] ??
                addr['town'] ??
                addr['village'] ??
                addr['municipality'] ??
                addr['hamlet'] ??
                '')
            .toString();
        if (city.isEmpty) continue;
        final String country = (addr['country'] ?? '').toString();
        final String key = '${city.toLowerCase()}|${country.toLowerCase()}';
        if (seen.contains(key)) continue;
        seen.add(key);
        out.add(_CitySuggestion(
          city: city,
          country: country,
          lat: double.tryParse('${item['lat']}') ?? 0.0,
          lon: double.tryParse('${item['lon']}') ?? 0.0,
        ));
        if (out.length >= 5) break;
      }
      if (!mounted) return;
      setState(() {
        _suggestions = out;
        _loading = false;
        _noResult = out.isEmpty;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _suggestions = const <_CitySuggestion>[];
      });
    }
  }

  void _pick(_CitySuggestion s) {
    _rememberRecent(s);
    Navigator.of(context).pop(CityPickerResult.city(
      city: s.city,
      country: s.country,
      lat: s.lat,
      lng: s.lon,
    ));
  }

  void _clear() {
    _suppressNext = true;
    _controller.clear();
    _lastQuery = '';
    setState(() {
      _suggestions = const <_CitySuggestion>[];
      _loading = false;
      _noResult = false;
    });
    _focus.requestFocus();
  }

  // ── Rendu ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final double keyboard = MediaQuery.viewInsetsOf(context).bottom;
    // Hauteur max de la zone de résultats : la feuille ne mange jamais tout
    // l'écran, et le clavier ne la fait pas déborder.
    final double maxList = MediaQuery.of(context).size.height * 0.38;
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        padding: EdgeInsets.fromLTRB(
          20.w,
          10.h,
          20.w,
          // Clavier ouvert : son inset est déjà appliqué par le Padding parent,
          // on n'ajoute pas l'inset système en double.
          16.h + (keyboard > 0 ? 0 : appBottomInset(context)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _handle(context),
            PoppinsText(
              text: widget.title,
              fontSize: 16.sp,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary(context),
              maxLines: 2,
            ),
            SizedBox(height: 3.h),
            InterText(
              text: widget.subtitle,
              fontSize: 12.sp,
              color: AppColors.textSecondary(context),
              maxLines: 2,
            ),
            SizedBox(height: 12.h),
            _searchField(context),
            if (widget.allowMyPosition) ...<Widget>[
              SizedBox(height: 10.h),
              _myPositionRow(context),
            ],
            SizedBox(height: 10.h),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxList),
              child: SingleChildScrollView(
                child: _results(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _handle(BuildContext context) => Center(
        child: Container(
          width: 40.w,
          height: 4.h,
          margin: EdgeInsets.only(bottom: 14.h),
          decoration: BoxDecoration(
            color: AppColors.divider(context),
            borderRadius: BorderRadius.circular(2.r),
          ),
        ),
      );

  Widget _searchField(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    OutlineInputBorder border(Color c, double w) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(16.r),
          borderSide: BorderSide(color: c, width: w),
        );
    final Color line =
        isDark ? AppColors.dividerDark : const Color(0xFFECE2DF);
    return TextField(
      key: const ValueKey<String>('city_picker_field'),
      controller: _controller,
      focusNode: _focus,
      autofocus: true,
      textInputAction: TextInputAction.search,
      cursorColor: widget.accent,
      cursorWidth: 1.6,
      style: TextStyle(
        fontSize: 14.5.sp,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary(context),
      ),
      decoration: InputDecoration(
        isDense: true,
        constraints: BoxConstraints(minHeight: 52.h),
        hintText: 'home571_search_city'.tr,
        hintStyle: TextStyle(
          fontSize: 14.sp,
          fontWeight: FontWeight.w400,
          color: AppColors.textSecondary(context).withValues(alpha: 0.75),
        ),
        prefixIcon: Icon(
          Icons.search_rounded,
          size: 20.sp,
          color: AppColors.textSecondary(context),
        ),
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                key: const ValueKey<String>('city_picker_clear'),
                tooltip: 'common_clear'.tr,
                icon: Icon(
                  Icons.close_rounded,
                  size: 18.sp,
                  color: AppColors.textSecondary(context),
                ),
                onPressed: _clear,
              ),
        filled: true,
        fillColor: isDark ? AppColors.inputFill(context) : Colors.white,
        border: border(line, 1),
        enabledBorder: border(line, 1),
        focusedBorder: border(widget.accent, 1.6),
        contentPadding:
            EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
      ),
    );
  }

  /// Ligne « 📡 Utiliser ma position actuelle », en tête de liste.
  Widget _myPositionRow(BuildContext context) {
    return Material(
      color: widget.accent.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(16.r),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const ValueKey<String>('city_picker_my_position'),
        onTap: () =>
            Navigator.of(context).pop(const CityPickerResult.myPosition()),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
          child: Row(
            children: <Widget>[
              Container(
                width: 32.w,
                height: 32.w,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: widget.accent.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.my_location_rounded,
                  size: 17.sp,
                  color: widget.accent,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: InterText(
                  text: 'home571_use_location'.tr,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: widget.accent,
                  maxLines: 2,
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18.sp,
                color: widget.accent,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _results(BuildContext context) {
    if (_loading) {
      return _stateCard(
        context,
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 16.w,
              height: 16.w,
              child: CircularProgressIndicator(
                strokeWidth: 1.8,
                valueColor: AlwaysStoppedAnimation<Color>(widget.accent),
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: InterText(
                text: 'auth569_searching'.tr,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary(context),
                maxLines: 1,
              ),
            ),
          ],
        ),
      );
    }
    if (_suggestions.isNotEmpty) {
      return _list(context, _suggestions, label: null);
    }
    if (_noResult) {
      return _stateCard(
        context,
        child: Row(
          children: <Widget>[
            Icon(
              Icons.search_off_rounded,
              size: 18.sp,
              color: AppColors.textSecondary(context),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: InterText(
                text: 'auth569_no_city_found'.tr,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary(context),
                maxLines: 2,
              ),
            ),
          ],
        ),
      );
    }
    if (_recents.isNotEmpty) {
      return _list(context, _recents, label: 'home571_recent_cities'.tr);
    }
    return const SizedBox.shrink();
  }

  Widget _stateCard(BuildContext context, {required Widget child}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: AppColors.scaffold(context),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.divider(context), width: 1),
      ),
      child: child,
    );
  }

  Widget _list(
    BuildContext context,
    List<_CitySuggestion> items, {
    required String? label,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (label != null) ...<Widget>[
          Padding(
            padding: EdgeInsets.only(left: 2.w, bottom: 6.h),
            child: InterText(
              text: label,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary(context),
              maxLines: 1,
            ),
          ),
        ],
        for (int i = 0; i < items.length; i++)
          _row(context, items[i], last: i == items.length - 1),
      ],
    );
  }

  Widget _row(BuildContext context, _CitySuggestion s, {required bool last}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14.r),
        onTap: () => _pick(s),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 11.h),
          decoration: BoxDecoration(
            border: last
                ? null
                : Border(
                    bottom: BorderSide(
                      color: AppColors.divider(context).withValues(alpha: 0.6),
                      width: 1,
                    ),
                  ),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 32.w,
                height: 32.w,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: widget.accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(
                  Icons.place_outlined,
                  size: 17.sp,
                  color: widget.accent,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    InterText(
                      text: s.city,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (s.country.isNotEmpty)
                      InterText(
                        text: s.country,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textSecondary(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              Icon(
                Icons.north_west_rounded,
                size: 15.sp,
                color:
                    AppColors.textSecondary(context).withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CitySuggestion {
  const _CitySuggestion({
    required this.city,
    required this.country,
    required this.lat,
    required this.lon,
  });

  final String city;
  final String country;
  final double lat;
  final double lon;

  @override
  bool operator ==(Object other) =>
      other is _CitySuggestion &&
      other.city == city &&
      other.country == country;

  @override
  int get hashCode => Object.hash(city, country);
}

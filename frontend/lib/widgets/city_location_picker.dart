import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/widgets/paw_button_kit.dart';
import 'package:hopetsit/views/auth/location_picker_map_screen.dart';

// ── v610 NEO (Daniel, 04/10 : « on peut écrire n'importe quoi ») ───────────
// La ville se CHOISIT : suggestion de la liste, « Ma position » ou carte.
// Le texte tapé à la main n'est jamais accepté tel quel. On retient, pour
// chaque champ (son TextEditingController), la dernière ville VALIDÉE ; le
// champ est valable seulement si son texte est encore cette ville.
//
// Sources de confiance : un choix dans la liste, la carte, « Ma position »
// (ville détectée), un texte posé par le PROGRAMME (champ sans le focus :
// profil, brouillon, annonce modifiée) — l'utilisateur ne tape qu'avec le
// focus — et la ville déjà présente quand le champ s'affiche la première fois
// (profil existant : on ne bloque pas les comptes déjà inscrits).
final Expando<String> _cityPicked610 = Expando<String>('cityPicked610');

/// Monte à chaque nouvelle ville validée : les `Obx` qui appellent
/// [cityPickedFromList610] se recalculent.
final RxInt cityChoiceVersion610 = 0.obs;

String _norm610(String s) => s.trim().toLowerCase();

void _bump610() {
  final binding = SchedulerBinding.instance;
  if (binding.schedulerPhase == SchedulerPhase.persistentCallbacks) {
    binding.addPostFrameCallback((_) => cityChoiceVersion610.value++);
  } else {
    cityChoiceVersion610.value++;
  }
}

// ── 04/10/2026 (ZOE) — identifiant STABLE du lieu choisi ─────────────────
// La liste OpenStreetMap répond dans la langue de l'app : un Italien choisit
// « Parigi », un Polonais « Paryż ». Le serveur ramène ces noms à « Paris »,
// mais l'appelant peut aussi joindre l'identifiant OSM du lieu (« R7444 »),
// identique dans toutes les langues. Lu par [cityPlaceIdOf610].
final Expando<String> _cityPlaceId610 = Expando<String>('cityPlaceId610');

/// Identifiant OSM (« R7444 », « N123 ») du lieu choisi dans la liste pour le
/// champ [c], seulement si le texte du champ est encore ce lieu ; sinon null.
String? cityPlaceIdOf610(TextEditingController c) {
  final id = _cityPlaceId610[c];
  if (id == null || id.isEmpty) return null;
  return cityPickedFromList610(c) ? id : null;
}

/// La ville [city] (ou le texte actuel) du champ [c] est une ville validée.
void markCityPicked610(TextEditingController c, [String? city]) {
  final v = (city ?? c.text).trim();
  if (v.isEmpty || _cityPicked610[c] == v) return;
  _cityPicked610[c] = v;
  _bump610();
}

/// Le texte du champ [c] est-il une ville choisie (liste, position, carte) ?
/// Lecture RÉACTIVE (à appeler dans un `Obx` sans souci).
bool cityPickedFromList610(TextEditingController c) {
  cityChoiceVersion610.value;
  final t = _norm610(c.text);
  if (t.isEmpty) return false;
  final p = _cityPicked610[c];
  return p != null && _norm610(p) == t;
}

/// v20.0.1 — City input modernized with live autocomplete.
///
/// As the user types (≥2 chars), we debounce 350ms and hit Nominatim
/// (free OpenStreetMap endpoint, already used for PawMap POIs) to
/// propose matching cities. Tapping a suggestion fills the field and
/// calls [onLocationSelected] with lat/lng so the caller can save the
/// real coordinates alongside the city label.
///
/// v569 — RENDU SEULEMENT : requête, debounce, parsing, `onGetLocation`,
/// l'écran carte et le validateur `error_city_required` sont inchangés. Le
/// champ adopte le langage de `CustomTextField` (coins 14, surface claire,
/// bordure fine → marque au focus), les suggestions passent en carte arrondie
/// avec icône de lieu, et un état « aucun résultat » a été ajouté (il manquait
/// : une recherche vide ne montrait rien du tout).
class CityLocationPicker extends StatefulWidget {
  final TextEditingController cityController;
  final VoidCallback onGetLocation;
  final bool isGettingLocation;
  final String detectedCity;
  final Function(String city, double latitude, double longitude)?
  onLocationSelected;

  /// v610 NEO — gros bouton « Utiliser ma position » pleine largeur au-dessus
  /// du champ (en plus de la puce), pour les écrans où la position est le
  /// geste principal (« Publier une demande »).
  final bool prominentAuto;

  const CityLocationPicker({
    super.key,
    required this.cityController,
    required this.onGetLocation,
    required this.isGettingLocation,
    this.detectedCity = '',
    this.onLocationSelected,
    this.prominentAuto = false,
  });

  /// Client HTTP des suggestions (remplacé dans les tests, jamais en prod).
  @visibleForTesting
  static http.Client? httpClientForTests;

  @override
  State<CityLocationPicker> createState() => _CityLocationPickerState();
}

class _CityLocationPickerState extends State<CityLocationPicker> {
  Timer? _debounce;
  List<_CitySuggestion> _suggestions = [];
  bool _loading = false;
  bool _suppressNext = false; // Skip autocomplete once after selecting/clearing
  String _lastQuery = '';
  // v569 — purement visuel : la dernière recherche ABOUTIE n'a rien donné.
  // (Une erreur réseau ne le déclenche pas : on n'affirme pas à tort que la
  // ville n'existe pas.)
  bool _noResult = false;

  final FocusNode _focus = FocusNode(debugLabel: 'city610');

  @override
  void initState() {
    super.initState();
    widget.cityController.addListener(_onCityTextChanged);
    _focus.addListener(_onFocusChanged);
    // v610 — ville déjà là au premier affichage (profil, annonce modifiée) :
    // validée, on ne bloque pas un compte existant. Si le champ a déjà été
    // suivi (étape quittée puis revenue), on garde ce qui était validé.
    final c = widget.cityController;
    if (_cityPicked610[c] == null && c.text.trim().isNotEmpty) {
      markCityPicked610(c);
    }
    _markDetectedIfShown();
  }

  @override
  void didUpdateWidget(covariant CityLocationPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cityController != widget.cityController) {
      oldWidget.cityController.removeListener(_onCityTextChanged);
      widget.cityController.addListener(_onCityTextChanged);
    }
    if (oldWidget.detectedCity != widget.detectedCity) _markDetectedIfShown();
  }

  /// « Ma position » a trouvé une ville et l'a posée dans le champ : validée.
  void _markDetectedIfShown() {
    final d = widget.detectedCity.trim();
    if (d.isNotEmpty &&
        _norm610(d) == _norm610(widget.cityController.text)) {
      markCityPicked610(widget.cityController, d);
    }
  }

  /// En quittant le champ : si le texte tapé est EXACTEMENT une suggestion
  /// affichée (« paris » → Paris), on la prend ; sinon le champ dit
  /// « Choisis ta ville dans la liste ».
  void _onFocusChanged() {
    if (_focus.hasFocus || !mounted) return;
    final t = _norm610(widget.cityController.text);
    if (t.isEmpty || cityPickedFromList610(widget.cityController)) {
      setState(() {});
      return;
    }
    for (final s in _suggestions) {
      if (_norm610(s.city) == t) {
        _pickSuggestion(s);
        return;
      }
    }
    setState(() {});
  }

  @override
  void dispose() {
    widget.cityController.removeListener(_onCityTextChanged);
    _focus.removeListener(_onFocusChanged);
    _focus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onCityTextChanged() {
    // v610 — texte posé par le programme (le champ n'a pas le focus) :
    // profil, brouillon, « Ma position »… c'est une ville validée.
    if (!_focus.hasFocus && widget.cityController.text.trim().isNotEmpty) {
      markCityPicked610(widget.cityController);
    }
    if (_suppressNext) {
      _suppressNext = false;
      return;
    }
    final q = widget.cityController.text.trim();
    if (q.length < 2) {
      if (_suggestions.isNotEmpty || _loading || _noResult) {
        setState(() {
          _suggestions = [];
          _loading = false;
          _noResult = false;
        });
      }
      return;
    }
    if (q == _lastQuery) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(q));
  }

  Future<void> _search(String q) async {
    _lastQuery = q;
    if (!mounted) return;
    setState(() {
      _loading = true;
      _noResult = false;
    });
    try {
      // Nominatim — free, no API key, same service used for PawMap POIs.
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeQueryComponent(q)}'
        '&format=json'
        '&addressdetails=1'
        '&limit=6'
        '&accept-language=${Get.locale?.languageCode ?? 'fr'}',
      );
      final client = CityLocationPicker.httpClientForTests;
      final getter = client == null ? http.get : client.get;
      final res = await getter(
        uri,
        headers: {
          'User-Agent': 'HoPetSit/20.0 (contact@hopetsit.com)',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _suggestions = [];
        });
        return;
      }
      final List<dynamic> raw = json.decode(res.body);
      final List<_CitySuggestion> out = [];
      final Set<String> seen = {};
      for (final item in raw) {
        if (item is! Map) continue;
        final addr = (item['address'] as Map?) ?? const {};
        final city = (addr['city'] ??
                addr['town'] ??
                addr['village'] ??
                addr['municipality'] ??
                addr['hamlet'] ??
                '')
            .toString();
        if (city.isEmpty) continue;
        final country = (addr['country'] ?? '').toString();
        final key = '${city.toLowerCase()}|${country.toLowerCase()}';
        if (seen.contains(key)) continue;
        seen.add(key);
        final osmType = '${item['osm_type'] ?? ''}';
        final osmId = '${item['osm_id'] ?? ''}';
        out.add(_CitySuggestion(
          city: city,
          country: country,
          lat: double.tryParse('${item['lat']}') ?? 0.0,
          lon: double.tryParse('${item['lon']}') ?? 0.0,
          placeId: (osmType.isNotEmpty && osmId.isNotEmpty)
              ? '${osmType[0].toUpperCase()}$osmId'
              : '',
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
        _suggestions = [];
      });
    }
  }

  void _pickSuggestion(_CitySuggestion s) {
    _cityPlaceId610[widget.cityController] = s.placeId;
    markCityPicked610(widget.cityController, s.city);
    _suppressNext = true;
    widget.cityController.text = s.city;
    widget.cityController.selection = TextSelection.fromPosition(
      TextPosition(offset: s.city.length),
    );
    widget.onLocationSelected?.call(s.city, s.lat, s.lon);
    FocusScope.of(context).unfocus();
    setState(() {
      _suggestions = [];
      _lastQuery = s.city;
      _noResult = false;
    });
  }

  /// Puce d'action (localisation automatique / carte) — coins pleins, contour
  /// fin, même langage que les boutons secondaires de l'app.
  Widget _actionChip({
    Key? key,
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    bool busy = false,
  }) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      key: key,
      color: isDark
          ? AppColors.primaryColor.withValues(alpha: 0.16)
          : AppColors.primaryColor.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(99.r),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 11.w, vertical: 7.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99.r),
            border: Border.all(
              color: AppColors.primaryColor.withValues(alpha: 0.30),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy)
                SizedBox(
                  width: 13.w,
                  height: 13.w,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.8,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primaryColor,
                    ),
                  ),
                )
              else
                Icon(icon, color: AppColors.primaryColor, size: 14.sp),
              SizedBox(width: 6.w),
              InterText(
                text: label,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// v610 — champ quitté avec un texte qui n'a pas été choisi : on dit quoi
  /// faire (la liste reste affichée au-dessus si elle existe).
  bool get _needsPick610 =>
      !_focus.hasFocus &&
      widget.cityController.text.trim().isNotEmpty &&
      !cityPickedFromList610(widget.cityController) &&
      !_loading;

  /// v610 — « Utiliser ma position », pleine largeur, un appui (bouton du
  /// kit signature, couleur du rôle).
  Widget _prominentAutoButton() {
    final busy = widget.isGettingLocation;
    return PawButton(
      key: const Key('city610_auto_button'),
      label: busy ? 'location_getting'.tr : 'city610_use_my_position'.tr,
      icon: Icons.my_location_rounded,
      kind: PawButtonKind.secondary,
      loading: busy,
      onTap: busy ? null : widget.onGetLocation,
      compact: true,
    );
  }

  OutlineInputBorder _border(Color color, double width) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.r),
        borderSide: BorderSide(color: color, width: width),
      );

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color line =
        isDark ? AppColors.dividerDark : const Color(0xFFECE2DF);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: InterText(
                text: 'label_city'.tr,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary(context),
                letterSpacing: 0.1,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: 8.w),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Auto-detect button
                _actionChip(
                  icon: Icons.my_location_rounded,
                  key: const Key('city610_auto_chip'),
                  label: widget.isGettingLocation
                      ? 'location_getting'.tr
                      : 'city610_my_position'.tr,
                  busy: widget.isGettingLocation,
                  onTap:
                      widget.isGettingLocation ? null : widget.onGetLocation,
                ),
                SizedBox(width: 8.w),
                // Map picker button
                _actionChip(
                  icon: Icons.map_outlined,
                  label: 'location_map'.tr,
                  onTap: () async {
                    final result = await Get.to(
                      () => const LocationPickerMapScreen(),
                    );
                    if (result != null && result is Map<String, dynamic>) {
                      markCityPicked610(widget.cityController,
                          (result['city'] ?? '').toString());
                      _suppressNext = true;
                      widget.cityController.text = result['city'] ?? '';
                      widget.onLocationSelected?.call(
                        result['city'] ?? '',
                        result['latitude'] ?? 0.0,
                        result['longitude'] ?? 0.0,
                      );
                      setState(() {
                        _suggestions = [];
                        _noResult = false;
                      });
                    }
                  },
                ),
              ],
            ),
          ],
        ),
        SizedBox(height: 7.h),
        if (widget.prominentAuto) ...[
          _prominentAutoButton(),
          SizedBox(height: 10.h),
        ],
        TextFormField(
          key: const Key('city610_field'),
          controller: widget.cityController,
          focusNode: _focus,
          textInputAction: TextInputAction.search,
          // v610 — « Entrée » prend la 1re suggestion (jamais le texte brut).
          onFieldSubmitted: (_) {
            if (_suggestions.isNotEmpty) _pickSuggestion(_suggestions.first);
          },
          cursorColor: AppColors.primaryColor,
          cursorWidth: 1.6,
          decoration: InputDecoration(
            isDense: true,
            constraints: BoxConstraints(minHeight: 52.h),
            hintText: widget.detectedCity.isNotEmpty
                ? 'location_detected'.tr.replaceAll('@city', widget.detectedCity)
                : 'location_enter_city'.tr,
            hintStyle: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w400,
              color: isDark
                  ? AppColors.textSecondaryDark.withValues(alpha: 0.7)
                  : AppColors.grey500Color.withValues(alpha: 0.75),
            ),
            prefixIcon: Icon(
              Icons.location_city_rounded,
              size: 20.sp,
              color: AppColors.textSecondary(context),
            ),
            filled: true,
            fillColor: isDark ? AppColors.inputFill(context) : Colors.white,
            border: _border(line, 1),
            enabledBorder: _border(line, 1),
            focusedBorder: _border(AppColors.primaryColor, 1.6),
            errorBorder: _border(AppColors.errorColor, 1.2),
            focusedErrorBorder: _border(AppColors.errorColor, 1.6),
            errorMaxLines: 2,
            errorStyle: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              color: AppColors.errorColor,
              height: 1.35,
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16.w,
              vertical: 15.h,
            ),
            suffixIcon: _loading
                ? Padding(
                    padding: EdgeInsets.all(14.w),
                    child: SizedBox(
                      width: 16.w,
                      height: 16.h,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.8,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primaryColor,
                        ),
                      ),
                    ),
                  )
                : (widget.detectedCity.isNotEmpty
                    ? Padding(
                        padding: EdgeInsets.only(right: 8.w),
                        child: Icon(
                          Icons.check_circle,
                          color: AppColors.primaryColor,
                          size: 20.sp,
                        ),
                      )
                    : null),
          ),
          style: TextStyle(
            fontSize: 14.5.sp,
            fontWeight: FontWeight.w500,
            // v23.1.333 — Daniel : "en dark mode on ne voit pas le texte des
            // adresses". Le texte saisi était noir codé en dur → invisible sur
            // fond sombre. On utilise la couleur primaire adaptée au thème.
            color: AppColors.textPrimary(context),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'error_city_required'.tr;
            }
            // v610 — une ville tapée sans être choisie n'est pas acceptée.
            if (!cityPickedFromList610(widget.cityController)) {
              return 'city610_pick_from_list'.tr;
            }
            return null;
          },
        ),
        // Autocomplete dropdown — shown below the field when suggestions exist.
        if (_suggestions.isNotEmpty) ...[
          SizedBox(height: 8.h),
          Container(
            decoration: BoxDecoration(
              // v23.1.333 — fond adapté au thème (était blanc fixe) pour que la
              // suggestion reste lisible en dark mode.
              color: AppColors.card(context),
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: line, width: 1),
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadow(0.07),
                  blurRadius: 16,
                  spreadRadius: -2,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: _suggestions.map((s) {
                final last = s == _suggestions.last;
                return InkWell(
                  onTap: () => _pickSuggestion(s),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 11.h,
                    ),
                    decoration: BoxDecoration(
                      border: last
                          ? null
                          : Border(
                              bottom: BorderSide(
                                color: line.withValues(alpha: 0.7),
                                width: 1,
                              ),
                            ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32.w,
                          height: 32.w,
                          decoration: BoxDecoration(
                            color: AppColors.primaryColor
                                .withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          child: Icon(
                            Icons.place_outlined,
                            color: AppColors.primaryColor,
                            size: 17.sp,
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
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
                          color: AppColors.textSecondary(context)
                              .withValues(alpha: 0.6),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ] else if (_loading) ...[
          // v569 — état de chargement explicite : la petite roue dans le
          // champ ne suffisait pas à dire « je cherche ».
          SizedBox(height: 8.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 11.h),
            decoration: BoxDecoration(
              color: AppColors.card(context),
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: line, width: 1),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 16.w,
                  height: 16.w,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.8,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primaryColor,
                    ),
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
          ),
        ] else if (_noResult) ...[
          // v569 — état « aucun résultat » : avant, une recherche vide ne
          // montrait RIEN et l'utilisateur croyait l'app bloquée.
          SizedBox(height: 8.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 11.h),
            decoration: BoxDecoration(
              color: AppColors.card(context),
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: line, width: 1),
            ),
            child: Row(
              children: [
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
          ),
        ],
        if (_needsPick610) ...[
          SizedBox(height: 8.h),
          Container(
            key: const Key('city610_pick_hint'),
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 9.h),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF3A2414) : const Color(0xFFFFF1E0),
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(
                color: isDark ? const Color(0xFF8A4B12) : const Color(0xFFF2B36B),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.touch_app_rounded,
                    size: 16.sp,
                    color: isDark ? const Color(0xFFFFC27A) : const Color(0xFF9A4A00)),
                SizedBox(width: 8.w),
                Expanded(
                  child: InterText(
                    text: 'city610_pick_from_list'.tr,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFFFFE2BF) : const Color(0xFF7A3B00),
                    maxLines: 3,
                  ),
                ),
              ],
            ),
          ),
        ],
        if (widget.detectedCity.isNotEmpty && _suggestions.isEmpty && !_needsPick610) ...[
          SizedBox(height: 8.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 9.h),
            decoration: BoxDecoration(
              color: AppColors.primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(
                color: AppColors.primaryColor.withValues(alpha: 0.24),
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  color: AppColors.primaryColor,
                  size: 16.sp,
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: InterText(
                    text: 'location_detected_message'.tr,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primaryColor,
                    // v21 — bumped from 2 → 4 maxLines + visible overflow so
                    // longer translations (FR/DE/IT especially) aren't cut
                    // mid-sentence with an ellipsis.
                    maxLines: 4,
                    overflow: TextOverflow.visible,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _CitySuggestion {
  final String city;
  final String country;
  final double lat;
  final double lon;
  // 04/10 (ZOE) — « R7444 » : identifiant OpenStreetMap, le même dans toutes
  // les langues ; vide si Nominatim ne l'a pas donné.
  final String placeId;

  const _CitySuggestion({
    required this.city,
    required this.country,
    required this.lat,
    required this.lon,
    this.placeId = '',
  });

  @override
  bool operator ==(Object other) =>
      other is _CitySuggestion &&
      other.city == city &&
      other.country == country;

  @override
  int get hashCode => Object.hash(city, country);
}

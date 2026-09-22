// v23.1.148 — Daniel : "regler adresse auto ds modifier animal". Champ
// d'adresse avec autocomplétion via Nominatim (OpenStreetMap, gratuit,
// déjà utilisé par CityLocationPicker pour la ville). Cible : les
// adresses vétérinaires de la fiche pet (régulier + urgence).
//
// Différence avec CityLocationPicker :
//   - Recherche d'adresse complète (rue + ville), pas seulement la ville
//   - UI plus compacte : pas de bouton "auto-detect" ni "carte"
//   - S'intègre comme un simple TextField pour drop-in replacement.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';

class AddressAutocompleteField extends StatefulWidget {
  const AddressAutocompleteField({
    super.key,
    required this.controller,
    required this.label,
    this.onAddressSelected,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;

  /// Optional callback when a suggestion is picked. Provides the full
  /// display name + lat/lon if the caller wants to save coordinates.
  final void Function(String address, double lat, double lon)? onAddressSelected;

  final int maxLines;

  @override
  State<AddressAutocompleteField> createState() =>
      _AddressAutocompleteFieldState();
}

class _AddressAutocompleteFieldState extends State<AddressAutocompleteField> {
  Timer? _debounce;
  List<_AddressSuggestion> _suggestions = const [];
  bool _loading = false;
  bool _suppressNext = false;
  String _lastQuery = '';
  // v569 — purement visuel : la dernière recherche ABOUTIE n'a rien donné.
  bool _noResult = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _debounce?.cancel();
    super.dispose();
  }

  void _onTextChanged() {
    if (_suppressNext) {
      _suppressNext = false;
      return;
    }
    final q = widget.controller.text.trim();
    if (q.length < 3) {
      if (_suggestions.isNotEmpty || _loading || _noResult) {
        setState(() {
          _suggestions = const [];
          _loading = false;
          _noResult = false;
        });
      }
      return;
    }
    if (q == _lastQuery) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(q));
  }

  Future<void> _search(String q) async {
    _lastQuery = q;
    if (!mounted) return;
    setState(() {
      _loading = true;
      _noResult = false;
    });
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeQueryComponent(q)}'
        '&format=json'
        '&addressdetails=1'
        '&limit=6'
        '&accept-language=${Get.locale?.languageCode ?? 'fr'}',
      );
      final res = await http.get(
        uri,
        headers: {
          'User-Agent': 'HoPetSit/23.1 (contact@hopetsit.com)',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _suggestions = const [];
        });
        return;
      }
      final List<dynamic> raw = json.decode(res.body);
      final List<_AddressSuggestion> out = [];
      for (final item in raw) {
        if (item is! Map) continue;
        final display = (item['display_name'] ?? '').toString();
        if (display.isEmpty) continue;
        out.add(_AddressSuggestion(
          displayName: display,
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
        _suggestions = const [];
      });
    }
  }

  void _pickSuggestion(_AddressSuggestion s) {
    _suppressNext = true;
    widget.controller.text = s.displayName;
    widget.controller.selection = TextSelection.fromPosition(
      TextPosition(offset: s.displayName.length),
    );
    widget.onAddressSelected?.call(s.displayName, s.lat, s.lon);
    FocusScope.of(context).unfocus();
    setState(() {
      _suggestions = const [];
      _lastQuery = s.displayName;
      _noResult = false;
    });
  }

  OutlineInputBorder _border(Color color, double width) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.r),
        borderSide: BorderSide(color: color, width: width),
      );

  @override
  Widget build(BuildContext context) {
    // v569 — RENDU SEULEMENT : contrôleur, debounce, requête Nominatim et
    // `onAddressSelected` inchangés. Le champ adopte le langage de
    // `CustomTextField` (libellé au-dessus 13/600, coins 14, surface claire,
    // bordure fine → marque au focus) et gagne un état « aucun résultat ».
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color line =
        isDark ? AppColors.dividerDark : const Color(0xFFECE2DF);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InterText(
          text: widget.label,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary(context),
          letterSpacing: 0.1,
          maxLines: 2,
        ),
        SizedBox(height: 7.h),
        TextField(
          controller: widget.controller,
          maxLines: widget.maxLines,
          textInputAction: TextInputAction.search,
          cursorColor: AppColors.primaryColor,
          cursorWidth: 1.6,
          style: TextStyle(
            fontSize: 14.5.sp,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary(context),
          ),
          decoration: InputDecoration(
            isDense: true,
            constraints: BoxConstraints(minHeight: 52.h),
            filled: true,
            fillColor: isDark ? AppColors.inputFill(context) : Colors.white,
            contentPadding:
                EdgeInsets.symmetric(horizontal: 16.w, vertical: 15.h),
            prefixIcon: Icon(
              Icons.place_outlined,
              size: 20.sp,
              color: AppColors.textSecondary(context),
            ),
            border: _border(line, 1),
            enabledBorder: _border(line, 1),
            focusedBorder: _border(AppColors.primaryColor, 1.6),
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
                : Icon(
                    Icons.search,
                    size: 20.sp,
                    color: AppColors.textSecondary(context),
                  ),
          ),
        ),
        if (_suggestions.isNotEmpty) ...[
          SizedBox(height: 8.h),
          Container(
            decoration: BoxDecoration(
              color: AppColors.card(context),
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: line, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.07),
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
                            Icons.location_on_outlined,
                            color: AppColors.primaryColor,
                            size: 17.sp,
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: InterText(
                            text: s.displayName,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary(context),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
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
                    text: 'auth569_no_address_found'.tr,
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
      ],
    );
  }
}

class _AddressSuggestion {
  const _AddressSuggestion({
    required this.displayName,
    required this.lat,
    required this.lon,
  });

  final String displayName;
  final double lat;
  final double lon;

  @override
  bool operator ==(Object other) =>
      other is _AddressSuggestion && other.displayName == displayName;

  @override
  int get hashCode => displayName.hashCode;
}

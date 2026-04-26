import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:hopetsit/views/auth/location_picker_map_screen.dart';

/// v20.0.1 — City input modernized with live autocomplete.
///
/// As the user types (≥2 chars), we debounce 350ms and hit Nominatim
/// (free OpenStreetMap endpoint, already used for PawMap POIs) to
/// propose matching cities. Tapping a suggestion fills the field and
/// calls [onLocationSelected] with lat/lng so the caller can save the
/// real coordinates alongside the city label.
class CityLocationPicker extends StatefulWidget {
  final TextEditingController cityController;
  final VoidCallback onGetLocation;
  final bool isGettingLocation;
  final String detectedCity;
  final Function(String city, double latitude, double longitude)?
  onLocationSelected;

  const CityLocationPicker({
    super.key,
    required this.cityController,
    required this.onGetLocation,
    required this.isGettingLocation,
    this.detectedCity = '',
    this.onLocationSelected,
  });

  @override
  State<CityLocationPicker> createState() => _CityLocationPickerState();
}

class _CityLocationPickerState extends State<CityLocationPicker> {
  Timer? _debounce;
  List<_CitySuggestion> _suggestions = [];
  bool _loading = false;
  bool _suppressNext = false; // Skip autocomplete once after selecting/clearing
  String _lastQuery = '';

  @override
  void initState() {
    super.initState();
    widget.cityController.addListener(_onCityTextChanged);
  }

  @override
  void dispose() {
    widget.cityController.removeListener(_onCityTextChanged);
    _debounce?.cancel();
    super.dispose();
  }

  void _onCityTextChanged() {
    if (_suppressNext) {
      _suppressNext = false;
      return;
    }
    final q = widget.cityController.text.trim();
    if (q.length < 2) {
      if (_suggestions.isNotEmpty || _loading) {
        setState(() {
          _suggestions = [];
          _loading = false;
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
    setState(() => _loading = true);
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
      final res = await http.get(
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
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            InterText(
              text: 'label_city'.tr,
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
              color: AppColors.blackColor,
            ),
            Row(
              children: [
                // Auto-detect button
                GestureDetector(
                  onTap: widget.isGettingLocation ? null : widget.onGetLocation,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 6.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.lightGrey,
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: AppColors.primaryColor,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.isGettingLocation)
                          SizedBox(
                            width: 14.w,
                            height: 14.h,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.primaryColor,
                              ),
                            ),
                          )
                        else
                          Icon(
                            Icons.location_on,
                            color: AppColors.primaryColor,
                            size: 14.sp,
                          ),
                        SizedBox(width: 6.w),
                        InterText(
                          text: widget.isGettingLocation
                              ? 'location_getting'.tr
                              : 'location_auto'.tr,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primaryColor,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                // Map picker button
                GestureDetector(
                  onTap: () async {
                    final result = await Get.to(
                      () => const LocationPickerMapScreen(),
                    );
                    if (result != null && result is Map<String, dynamic>) {
                      _suppressNext = true;
                      widget.cityController.text = result['city'] ?? '';
                      widget.onLocationSelected?.call(
                        result['city'] ?? '',
                        result['latitude'] ?? 0.0,
                        result['longitude'] ?? 0.0,
                      );
                      setState(() => _suggestions = []);
                    }
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 6.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.lightGrey,
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: AppColors.primaryColor,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.map,
                          color: AppColors.primaryColor,
                          size: 14.sp,
                        ),
                        SizedBox(width: 6.w),
                        InterText(
                          text: 'location_map'.tr,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primaryColor,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        SizedBox(height: 8.h),
        TextFormField(
          controller: widget.cityController,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: widget.detectedCity.isNotEmpty
                ? 'location_detected'.tr.replaceAll('@city', widget.detectedCity)
                : 'location_enter_city'.tr,
            hintStyle: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w400,
              color: AppColors.greyColor,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24.r),
              borderSide: BorderSide(color: AppColors.grey300Color, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24.r),
              borderSide: BorderSide(color: AppColors.grey300Color, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24.r),
              borderSide: BorderSide(color: AppColors.primaryColor, width: 1.5),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16.w,
              vertical: 12.h,
            ),
            suffixIcon: _loading
                ? Padding(
                    padding: EdgeInsets.all(12.w),
                    child: SizedBox(
                      width: 16.w,
                      height: 16.h,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
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
            fontSize: 14.sp,
            fontWeight: FontWeight.w400,
            color: AppColors.blackColor,
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'error_city_required'.tr;
            }
            return null;
          },
        ),
        // Autocomplete dropdown — shown below the field when suggestions exist.
        if (_suggestions.isNotEmpty) ...[
          SizedBox(height: 6.h),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: AppColors.grey300Color, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: _suggestions.map((s) {
                final last = s == _suggestions.last;
                return InkWell(
                  onTap: () => _pickSuggestion(s),
                  borderRadius: last
                      ? BorderRadius.only(
                          bottomLeft: Radius.circular(16.r),
                          bottomRight: Radius.circular(16.r),
                        )
                      : null,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 14.w,
                      vertical: 12.h,
                    ),
                    decoration: BoxDecoration(
                      border: last
                          ? null
                          : Border(
                              bottom: BorderSide(
                                color: AppColors.grey300Color.withValues(
                                  alpha: 0.5,
                                ),
                                width: 1,
                              ),
                            ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.location_city,
                          color: AppColors.primaryColor,
                          size: 18.sp,
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              InterText(
                                text: s.city,
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w600,
                                color: AppColors.blackColor,
                              ),
                              if (s.country.isNotEmpty)
                                InterText(
                                  text: s.country,
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w400,
                                  color: AppColors.greyColor,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
        if (widget.detectedCity.isNotEmpty && _suggestions.isEmpty) ...[
          SizedBox(height: 8.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: AppColors.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(24.r),
              border: Border.all(
                color: AppColors.primaryColor.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
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
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w400,
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

  const _CitySuggestion({
    required this.city,
    required this.country,
    required this.lat,
    required this.lon,
  });

  @override
  bool operator ==(Object other) =>
      other is _CitySuggestion &&
      other.city == city &&
      other.country == country;

  @override
  int get hashCode => Object.hash(city, country);
}

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hopetsit/services/location_service.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/widgets/app_text.dart';

class LocationPickerMapScreen extends StatefulWidget {
  const LocationPickerMapScreen({super.key});

  @override
  State<LocationPickerMapScreen> createState() =>
      _LocationPickerMapScreenState();
}

class _LocationPickerMapScreenState extends State<LocationPickerMapScreen> {
  late GoogleMapController mapController;
  final LocationService _locationService = LocationService();

  LatLng? selectedLocation;
  String? selectedCity;
  bool isLoadingCity = false;
  LatLng initialLocation = const LatLng(37.7749, -122.4194);

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    try {
      // Try to get user's current location
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
        ),
      );

      setState(() {
        initialLocation = LatLng(position.latitude, position.longitude);
        selectedLocation = initialLocation;
      });

      // Get city for initial location
      await _getCityForLocation(position.latitude, position.longitude);
    } catch (e) {
      debugPrint('Error getting current location: $e');
    }
  }

  Future<void> _getCityForLocation(double latitude, double longitude) async {
    setState(() => isLoadingCity = true);
    try {
      final city = await _locationService.getCityFromCoordinates(
        latitude,
        longitude,
      );
      setState(() {
        selectedCity = city;
        isLoadingCity = false;
      });
    } catch (e) {
      debugPrint('Error getting city: $e');
      setState(() => isLoadingCity = false);
    }
  }

  void _onMapTapped(LatLng location) {
    setState(() {
      selectedLocation = location;
    });
    _getCityForLocation(location.latitude, location.longitude);
  }

  void _confirmLocation() {
    if (selectedLocation != null && selectedCity != null) {
      Get.back(
        result: {
          'city': selectedCity,
          'latitude': selectedLocation!.latitude,
          'longitude': selectedLocation!.longitude,
        },
      );
    } else {
      Get.snackbar(
        'common_error'.tr,
        'location_select_error'.tr,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  void _useCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
        ),
      );

      final location = LatLng(position.latitude, position.longitude);

      mapController.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: location, zoom: 14),
        ),
      );

      setState(() {
        selectedLocation = location;
      });

      await _getCityForLocation(position.latitude, position.longitude);
    } catch (e) {
      debugPrint('Error getting current location: $e');
      Get.snackbar(
        'common_error'.tr,
        'location_get_error'.tr,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.appBar(context),
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Get.back(),
          child: Icon(
            Icons.arrow_back_ios_new,
            color: AppColors.textPrimary(context),
            size: 20.sp,
          ),
        ),
        title: InterText(
          text: 'location_select_title'.tr,
          fontSize: 16.sp,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary(context),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            // Map
            GoogleMap(
              onMapCreated: (GoogleMapController controller) {
                mapController = controller;
              },
              initialCameraPosition: CameraPosition(
                target: initialLocation,
                zoom: 14,
              ),
              onTap: _onMapTapped,
              markers: selectedLocation != null
                  ? {
                      Marker(
                        markerId: const MarkerId('selected'),
                        position: selectedLocation!,
                        infoWindow: InfoWindow(
                          title: selectedCity ?? 'location_selected'.tr,
                        ),
                      ),
                    }
                  : {},
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              compassEnabled: true,
              zoomControlsEnabled: false,
            ),

            // Center pin indicator
            Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: 40.h),
                child: Icon(
                  Icons.location_on,
                  color: AppColors.primaryColor,
                  size: 40.sp,
                  shadows: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom sheet with location details
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.card(context),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(20.r),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                padding: EdgeInsets.all(20.w),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // City display
                    Container(
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        color: AppColors.card(context),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                InterText(
                                  text: 'location_selected_city'.tr,
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w400,
                                  color: AppColors.textSecondary(context),
                                ),
                                SizedBox(height: 4.h),
                                if (isLoadingCity)
                                  SizedBox(
                                    width: 20.w,
                                    height: 20.h,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        AppColors.primaryColor,
                                      ),
                                    ),
                                  )
                                else
                                  InterText(
                                    text: selectedCity ?? 'location_no_city'.tr,
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary(context),
                                  ),
                              ],
                            ),
                          ),
                          if (selectedCity != null)
                            Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 24.sp,
                            ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16.h),

                    // Coordinates
                    if (selectedLocation != null)
                      Container(
                        padding: EdgeInsets.all(12.w),
                        decoration: BoxDecoration(
                          color: AppColors.card(context),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                                  InterText(
                                    text:
                                        'location_latitude'.tr.replaceAll('@value', selectedLocation!.latitude.toStringAsFixed(4)),
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w400,
                                    color: AppColors.textSecondary(context),
                                  ),
                                  SizedBox(height: 4.h),
                                  InterText(
                                    text:
                                        'location_longitude'.tr.replaceAll('@value', selectedLocation!.longitude.toStringAsFixed(4)),
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w400,
                                    color: AppColors.textSecondary(context),
                                  ),
                          ],
                        ),
                      ),
                    SizedBox(height: 16.h),

                    // Buttons
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: _useCurrentLocation,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 16.w,
                                vertical: 12.h,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.inputFill(context),
                                borderRadius: BorderRadius.circular(12.r),
                                border: Border.all(
                                  color: AppColors.primaryColor,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.my_location,
                                    color: AppColors.primaryColor,
                                    size: 16.sp,
                                  ),
                                  SizedBox(width: 8.w),
                                  InterText(
                                    text: 'location_current'.tr,
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.primaryColor,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: GestureDetector(
                            onTap: _confirmLocation,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 16.w,
                                vertical: 12.h,
                              ),
                              decoration: BoxDecoration(
                                color: selectedCity != null
                                    ? AppColors.primaryColor
                                    : AppColors.inputFill(context),
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.check,
                                    color: selectedCity != null
                                        ? Colors.white
                                        : AppColors.textSecondary(context),
                                    size: 16.sp,
                                  ),
                                  SizedBox(width: 8.w),
                                  InterText(
                                    text: 'location_confirm'.tr,
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w500,
                                    color: selectedCity != null
                                        ? Colors.white
                                        : AppColors.textSecondary(context),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    mapController.dispose();
    super.dispose();
  }
}

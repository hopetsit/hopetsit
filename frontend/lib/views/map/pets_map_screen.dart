import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hopetsit/controllers/pets_map_controller.dart';
import 'package:hopetsit/models/sitter_model.dart';
import 'package:hopetsit/utils/app_colors.dart';
import 'package:hopetsit/services/location_service.dart';
import 'package:hopetsit/views/map/widgets/sitter_bottom_sheet.dart';
import 'package:hopetsit/views/service_provider/send_request_screen.dart';
import 'package:hopetsit/views/service_provider/service_provider_detail_screen.dart';
import 'package:hopetsit/widgets/app_text.dart';
import 'package:shimmer/shimmer.dart';

class PetsMapScreen extends StatefulWidget {
  const PetsMapScreen({super.key});

  @override
  State<PetsMapScreen> createState() => _PetsMapScreenState();
}

class _PetsMapScreenState extends State<PetsMapScreen> {
  final PetsMapController controller = Get.put(PetsMapController());
  final Completer<GoogleMapController> _mapCtl = Completer();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.whiteColor,
      body: SafeArea(
        child: Obx(() {
          final userLoc = controller.userLocation.value;
          final sittersWithLocation = controller.sitters
              .where((s) => s.latitude != null && s.longitude != null)
              .toList();

          return Stack(
            children: [
              Positioned.fill(
                child: userLoc == null
                    ? const Center(child: CircularProgressIndicator())
                    : GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: userLoc,
                          zoom: 13,
                        ),
                        myLocationEnabled: true,
                        myLocationButtonEnabled: false,
                        onMapCreated: (mapController) {
                          _mapCtl.complete(mapController);
                          controller.setMapController(mapController);
                        },
                        markers: sittersWithLocation
                            .map(
                              (sitter) => Marker(
                                markerId: MarkerId(sitter.id),
                                position: LatLng(
                                  sitter.latitude!,
                                  sitter.longitude!,
                                ),
                                onTap: () => _onMarkerTapped(sitter),
                              ),
                            )
                            .toSet(),
                      ),
              ),

              // Top bar: back and search
              Positioned(
                top: 12.h,
                left: 12.w,
                right: 12.w,
                child: Row(
                  children: [
                    Container(
                      height: 48.h,
                      width: 48.h,
                      decoration: BoxDecoration(
                        color: AppColors.whiteColor,
                        borderRadius: BorderRadius.circular(12.r),
                        boxShadow: [
                          BoxShadow(color: Colors.black12, blurRadius: 8),
                        ],
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.arrow_back_outlined,
                          color: AppColors.blackColor,
                        ),
                        onPressed: () => Get.back(),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Container(
                        height: 48.h,
                        padding: EdgeInsets.symmetric(horizontal: 12.w),
                        decoration: BoxDecoration(
                          color: AppColors.whiteColor,
                          borderRadius: BorderRadius.circular(12.r),
                          boxShadow: [
                            BoxShadow(color: Colors.black12, blurRadius: 8),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.search, color: AppColors.greyText),
                            SizedBox(width: 8.w),
                            Expanded(
                              child: TextField(
                                decoration: InputDecoration(
                                  hintText: 'map_search_hint'.tr,
                                  border: InputBorder.none,
                                ),
                                readOnly: true,
                                onTap: () => _showSearchDialog(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Offers near me button + distance filter
              Positioned(
                top: 72.h,
                left: 12.w,
                right: 12.w,
                child: Obx(
                  () => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: 44.h,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryColor,
                            foregroundColor: AppColors.whiteColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            elevation: 2,
                          ),
                          onPressed: controller.isLoading.value
                              ? null
                              : () => controller.showOffersNearMe(),
                          icon: const Icon(Icons.place_rounded),
                          label: Text('map_offers_near_me'.tr),
                        ),
                      ),
                      if (controller.offersNearMeEnabled.value) ...[
                        SizedBox(height: 8.h),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12.w,
                            vertical: 8.h,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.whiteColor,
                            borderRadius: BorderRadius.circular(12.r),
                            boxShadow: [
                              BoxShadow(color: Colors.black12, blurRadius: 8),
                            ],
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.tune_rounded,
                                    size: 18.sp,
                                    color: AppColors.grey700Color,
                                  ),
                                  SizedBox(width: 8.w),
                                  Expanded(
                                    child: InterText(
                                      text: 'map_distance_filter_label'.trParams({
                                        'km': controller.selectedRadiusKm.value
                                            .round()
                                            .toString(),
                                      }),
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.blackColor,
                                    ),
                                  ),
                                ],
                              ),
                              Slider(
                                min: 0,
                                max: 500,
                                divisions: 100,
                                value: controller.selectedRadiusKm.value,
                                label: '${controller.selectedRadiusKm.value.round()} km',
                                onChanged: (value) {
                                  controller.selectedRadiusKm.value = value;
                                },
                                onChangeEnd: (value) async {
                                  await controller.loadNearbySitters(
                                    radiusKm: value.round(),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Center to user + refresh FABs (above sitter strip)
              Positioned(
                right: 12.w,
                bottom: 150.h,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FloatingActionButton(
                      heroTag: 'centerUser',
                      backgroundColor: AppColors.whiteColor,
                      onPressed: () async {
                        await controller.centerToUser();
                      },
                      child: Icon(
                        Icons.my_location,
                        color: AppColors.primaryColor,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    FloatingActionButton(
                      heroTag: 'refresh',
                      backgroundColor: AppColors.whiteColor,
                      onPressed: () async {
                        await controller.loadNearbySitters(
                          radiusKm: controller.selectedRadiusKm.value.round(),
                        );
                      },
                      child: Icon(Icons.refresh, color: AppColors.primaryColor),
                    ),
                    SizedBox(height: 8.h),
                  ],
                ),
              ),

              // Bottom carousel of nearby sitters – container with clear background
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.whiteColor,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20.r),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 16,
                          offset: Offset(0, -4),
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 6,
                          offset: Offset(0, -1),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Handle strip
                        Padding(
                          padding: EdgeInsets.only(top: 10.h, bottom: 4.h),
                          child: Container(
                            width: 40.w,
                            height: 4.h,
                            decoration: BoxDecoration(
                              color: AppColors.grey300Color,
                              borderRadius: BorderRadius.circular(2.r),
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.only(
                            left: 16.w,
                            right: 16.w,
                            bottom: 16.h,
                            top: 4.h,
                          ),
                          child: SizedBox(
                            height: 112.h,
                            child: controller.isLoading.value
                                ? _buildSitterCardsShimmer()
                                : controller.sitters.isEmpty
                                ? Center(
                                    child: Text(
                                      'map_no_nearby_sitters'.tr,
                                      style: TextStyle(
                                        color: AppColors.greyText,
                                        fontSize: 14.sp,
                                      ),
                                    ),
                                  )
                                : ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemBuilder: (ctx, index) {
                                      final sitter = controller.sitters[index];
                                      return GestureDetector(
                                        onTap: () => _onMarkerTapped(sitter),
                                        child: Container(
                                          width: 200.w,
                                          padding: EdgeInsets.all(12.w),
                                          decoration: BoxDecoration(
                                            color: AppColors.lightGrey
                                                .withOpacity(0.6),
                                            borderRadius: BorderRadius.circular(
                                              14.r,
                                            ),
                                            border: Border.all(
                                              color: AppColors.grey300Color
                                                  .withOpacity(0.5),
                                              width: 1,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(
                                                  0.06,
                                                ),
                                                blurRadius: 8,
                                                offset: Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            children: [
                                              CircleAvatar(
                                                radius: 28.r,
                                                backgroundColor:
                                                    AppColors.whiteColor,
                                                backgroundImage:
                                                    sitter.avatar.url.isNotEmpty
                                                    ? NetworkImage(
                                                        sitter.avatar.url,
                                                      )
                                                    : null,
                                                child: sitter.avatar.url.isEmpty
                                                    ? Icon(
                                                        Icons.person,
                                                        size: 28.sp,
                                                        color:
                                                            AppColors.greyText,
                                                      )
                                                    : null,
                                              ),
                                              SizedBox(width: 12.w),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                      sitter.name,
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontSize: 14.sp,
                                                        color: AppColors
                                                            .blackColor,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                    SizedBox(height: 4.h),
                                                    Text(
                                                      'map_sitter_services_distance'.trParams({
                                                        'services':
                                                            sitter
                                                                .service
                                                                .isNotEmpty
                                                            ? sitter.service
                                                                  .join(', ')
                                                            : 'label_not_available'
                                                                  .tr,
                                                        'distance':
                                                            sitter.distanceKm !=
                                                                null
                                                            ? sitter.distanceKm!
                                                                  .toStringAsFixed(
                                                                    2,
                                                                  )
                                                            : '—',
                                                      }),
                                                      style: TextStyle(
                                                        color:
                                                            AppColors.greyText,
                                                        fontSize: 12.sp,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                    separatorBuilder: (_, __) =>
                                        SizedBox(width: 12.w),
                                    itemCount: controller.sitters.length,
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildSitterCardsShimmer() {
    return Shimmer.fromColors(
      baseColor: AppColors.grey300Color,
      highlightColor: AppColors.whiteColor,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 3,
        separatorBuilder: (_, __) => SizedBox(width: 12.w),
        itemBuilder: (_, __) => Container(
          width: 200.w,
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: AppColors.lightGrey.withOpacity(0.6),
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(
              color: AppColors.grey300Color.withOpacity(0.5),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 56.r,
                height: 56.r,
                decoration: BoxDecoration(
                  color: AppColors.grey300Color,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      height: 14.h,
                      width: 80.w,
                      decoration: BoxDecoration(
                        color: AppColors.grey300Color,
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Container(
                      height: 12.h,
                      width: 120.w,
                      decoration: BoxDecoration(
                        color: AppColors.grey300Color,
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showSearchDialog() async {
    final TextEditingController _searchCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.whiteColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        title: PoppinsText(
          text: 'map_search_hint'.tr,
          fontSize: 16.sp,
          fontWeight: FontWeight.w600,
          color: AppColors.blackColor,
        ),
        content: TextField(
          controller: _searchCtrl,
          decoration: InputDecoration(
            hintText: 'map_search_hint'.tr,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(color: AppColors.grey300Color),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(color: AppColors.primaryColor, width: 1.5),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 12.w,
              vertical: 10.h,
            ),
          ),
          autofocus: true,
        ),
        actionsPadding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 12.h),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('common_cancel'.tr),
          ),
          TextButton(
            onPressed: () async {
              final query = _searchCtrl.text.trim();
              if (query.isEmpty) {
                Get.snackbar('common_error'.tr, 'map_search_empty'.tr);
                return;
              }

              // Close the input dialog using the dialog's context
              Navigator.of(dialogContext).pop();

              // show loading using the State's (outer) context which stays active
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) =>
                    const Center(child: CircularProgressIndicator()),
              );

              try {
                final pos = await LocationService().getCoordinatesFromCity(
                  query,
                );

                // close loading (use outer context)
                if (mounted) Navigator.of(context).pop();

                if (pos != null) {
                  final mapController = await _mapCtl.future;
                  await mapController.animateCamera(
                    CameraUpdate.newLatLngZoom(
                      LatLng(pos.latitude, pos.longitude),
                      13,
                    ),
                  );
                } else {
                  Get.snackbar(
                    'common_error'.tr,
                    'map_search_not_found'.trParams({'query': query}),
                  );
                }
              } catch (e) {
                // Ensure loading is closed
                if (mounted) Navigator.of(context).pop();
                Get.snackbar('common_error'.tr, 'map_search_failed'.tr);
              }
            },
            child: Text('common_search'.tr),
          ),
        ],
      ),
    );
  }

  Future<void> _onMarkerTapped(SitterModel sitter) async {
    if (sitter.latitude != null && sitter.longitude != null) {
      final mapController = await _mapCtl.future;
      await mapController.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(sitter.latitude!, sitter.longitude!),
          15,
        ),
      );
    }

    Get.bottomSheet(
      sitterBottomSheet(
        sitter,
        onViewProfile: () {
          Get.back();
          Get.to(
            () => ServiceProviderDetailScreen(
              sitterId: sitter.id,
              status: 'available',
            ),
          );
        },
        onSendRequest: () {
          Get.back();
          Get.to(
            () => SendRequestScreen(
              serviceProviderName: sitter.name,
              serviceProviderId: sitter.id,
            ),
          );
        },
      ),
      isScrollControlled: false,
      backgroundColor: Colors.transparent,
    );
  }
}

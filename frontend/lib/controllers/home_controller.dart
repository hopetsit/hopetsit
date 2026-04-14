import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/models/sitter_model.dart';
import 'package:hopetsit/repositories/owner_repository.dart';
import 'package:hopetsit/services/location_service.dart';
import 'package:hopetsit/utils/logger.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';

class HomeController extends GetxController {
  HomeController({OwnerRepository? ownerRepository})
    : _ownerRepository = ownerRepository ?? Get.find<OwnerRepository>();

  final OwnerRepository _ownerRepository;

  // Post state (legacy)
  final RxBool canPost = false.obs;
  final RxBool isLoading = false.obs;
  final TextEditingController postController = TextEditingController();
  final RxList<File> selectedImages = <File>[].obs;

  // Sitters
  final RxList<SitterModel> sitters = <SitterModel>[].obs;
  final RxBool isLoadingSitters = false.obs;

  // FIX #2 — Offers Near Me state
  final RxBool offersNearMeEnabled = false.obs;
  final RxDouble nearMeRadiusKm = 50.0.obs;

  @override
  void onInit() {
    super.onInit();
    postController.addListener(_onTextChanged);
    loadSitters();
  }

  @override
  void onClose() {
    postController.dispose();
    super.onClose();
  }

  void _onTextChanged() {
    canPost.value =
        postController.text.trim().isNotEmpty || selectedImages.isNotEmpty;
  }

  /// Loads all sitters (default, no location filter)
  Future<void> loadSitters() async {
    isLoadingSitters.value = true;
    offersNearMeEnabled.value = false;
    try {
      final sittersList = await _ownerRepository.getSitters();
      sitters.assignAll(sittersList);
    } on ApiException catch (error) {
      AppLogger.logError('Failed to load sitters', error: error.message);
      sitters.clear();
    } catch (error) {
      AppLogger.logError('Failed to load sitters', error: error);
      sitters.clear();
    } finally {
      isLoadingSitters.value = false;
    }
  }

  /// FIX #2 — Toggle "Offers Near Me": uses GPS to filter nearby sitters
  Future<void> toggleOffersNearMe(BuildContext context) async {
    if (offersNearMeEnabled.value) {
      // Turn off → reload all sitters
      await loadSitters();
      return;
    }
    await loadNearbySitters(radiusKm: nearMeRadiusKm.value.round());
  }

  /// FIX #2 — Load sitters filtered by GPS distance radius
  Future<void> loadNearbySitters({required int radiusKm}) async {
    isLoadingSitters.value = true;
    try {
      final locationService = LocationService();
      final position = await locationService.getCurrentLocation();
      if (position == null) {
        CustomSnackbar.showError(
          title: 'common_error'.tr,
          message: 'Could not detect your location. Please enable location services.',
        );
        isLoadingSitters.value = false;
        return;
      }

      final list = await _ownerRepository.getNearbySitters(
        lat: position.latitude,
        lng: position.longitude,
        radiusInMeters: radiusKm * 1000,
      );
      sitters.assignAll(list);
      offersNearMeEnabled.value = true;
      nearMeRadiusKm.value = radiusKm.toDouble();
    } on ApiException catch (error) {
      CustomSnackbar.showError(title: 'common_error'.tr, message: error.message);
    } catch (error) {
      AppLogger.logError('Failed to load nearby sitters', error: error);
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'Could not load nearby sitters. Please try again.',
      );
    } finally {
      isLoadingSitters.value = false;
    }
  }

  /// Blocks a sitter
  Future<void> blockSitter(String sitterId) async {
    try {
      await _ownerRepository.blockSitter(sitterId: sitterId);
      CustomSnackbar.showSuccess(
        title: 'common_success'.tr,
        message: 'snackbar_text_sitter_blocked_successfully',
      );
    } on ApiException catch (error) {
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: error.message,
      );
    } catch (error) {
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'common_error_generic'.tr,
      );
    }
  }
}

import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hopetsit/data/network/api_exception.dart';
import 'package:hopetsit/models/sitter_model.dart';
import 'package:hopetsit/repositories/owner_repository.dart';
import 'package:hopetsit/utils/logger.dart';
import 'package:hopetsit/widgets/custom_snackbar_widget.dart';

class PetsMapController extends GetxController {
  PetsMapController({OwnerRepository? ownerRepository})
    : _ownerRepository = ownerRepository ?? Get.find<OwnerRepository>();

  final OwnerRepository _ownerRepository;

  final RxList<SitterModel> sitters = <SitterModel>[].obs;
  final Rxn<LatLng> userLocation = Rxn<LatLng>();
  final RxBool isLoading = false.obs;
  final RxBool offersNearMeEnabled = false.obs;
  final RxDouble selectedRadiusKm = 50.0.obs;

  GoogleMapController? mapController;

  @override
  void onInit() {
    super.onInit();
    _loadUserLocationOnly();
  }

  Future<void> _loadUserLocationOnly() async {
    try {
      final position = await _determinePosition();
      userLocation.value = LatLng(position.latitude, position.longitude);
    } catch (e) {
      AppLogger.logError('Failed to determine user location', error: e);
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'snackbar_text_could_not_load_nearby_sitters_please_try_again',
      );
    }
  }

  Future<void> loadNearbySitters({int? radiusKm}) async {
    isLoading.value = true;
    sitters.clear();
    try {
      final loc = userLocation.value;
      if (loc == null) {
        await _loadUserLocationOnly();
      }
      final current = userLocation.value;
      if (current == null) {
        throw Exception('Unable to determine user location');
      }

      final int radiusToUseKm = radiusKm ?? selectedRadiusKm.value.round();
      final list = await _ownerRepository.getNearbySitters(
        lat: current.latitude,
        lng: current.longitude,
        radiusInMeters: radiusToUseKm * 1000,
      );
      sitters.assignAll(list);
    } on ApiException catch (e) {
      AppLogger.logError('Failed to load nearby sitters', error: e.message);
      CustomSnackbar.showError(title: 'common_error'.tr, message: e.message);
    } catch (e) {
      AppLogger.logError('Failed to load nearby sitters', error: e);
      CustomSnackbar.showError(
        title: 'common_error'.tr,
        message: 'snackbar_text_could_not_load_nearby_sitters_please_try_again',
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> showOffersNearMe() async {
    offersNearMeEnabled.value = true;
    await loadNearbySitters();
  }

  Future<Position> _determinePosition() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever ||
        permission == LocationPermission.denied) {
      throw Exception('Location permissions are denied');
    }

    return await Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(accuracy: LocationAccuracy.best),
    );
  }

  void setMapController(GoogleMapController controller) {
    mapController = controller;
  }

  Future<void> centerToUser() async {
    final loc = userLocation.value;
    if (loc != null && mapController != null) {
      await mapController!.animateCamera(CameraUpdate.newLatLngZoom(loc, 14));
    }
  }
}

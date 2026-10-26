import 'package:get/get.dart';
import 'package:hopetsit/services/location_service.dart';
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
        // v23.1.147 — fallback : pas de géoloc → on charge tous les sitters
        // pour ne pas avoir un écran vide (cohérent avec home_controller).
        final all = await _ownerRepository.getSitters();
        sitters.assignAll(all);
        return;
      }

      final int radiusToUseKm = radiusKm ?? selectedRadiusKm.value.round();
      final list = await _ownerRepository.getNearbySitters(
        lat: current.latitude,
        lng: current.longitude,
        radiusInMeters: radiusToUseKm * 1000,
      );
      // v23.1.147 — Daniel : "si on met 20 km le paseador disparaît".
      // Si la liste nearby est vide (cas sitter sans coords GPS exclu par
      // MongoDB $near), on fallback sur la liste complète pour garder
      // les sitters visibles.
      if (list.isEmpty) {
        final all = await _ownerRepository.getSitters();
        sitters.assignAll(all);
        return;
      }
      sitters.assignAll(list);
    } on ApiException catch (e) {
      AppLogger.logError('Failed to load nearby sitters', error: e.message);
      // Fallback sur liste complète en cas d'erreur API.
      try {
        final all = await _ownerRepository.getSitters();
        sitters.assignAll(all);
      } catch (_) {
        CustomSnackbar.showError(
          title: 'common_error'.tr,
          message: e.message,
        );
      }
    } catch (e) {
      AppLogger.logError('Failed to load nearby sitters', error: e);
      try {
        final all = await _ownerRepository.getSitters();
        sitters.assignAll(all);
      } catch (_) {
        CustomSnackbar.showError(
          title: 'common_error'.tr,
          message: 'snackbar_text_could_not_load_nearby_sitters_please_try_again',
        );
      }
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
      // 624 — sondes : jamais la fenêtre système (refus simulé).
      if (!LocationService.skipPromptForTests) {
        permission = await Geolocator.requestPermission();
      }
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

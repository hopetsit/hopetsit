// v587 (point 8 de Daniel) — LIEU DU SERVICE : une seule source pour les
// options du formulaire « Publier une annonce » et pour l'affichage (carte
// d'annonce, fiche de réservation, bulle PawMap).
//
//   garde (pet_sitting, house_sitting, day_care, long_stay) : at_owner | at_sitter
//   promenade (dog_walking)                                  : pickup | meeting_point
//   visites (home_visit, drop_in…)                           : at_owner, fixé
//
// Les valeurs sont celles du serveur (`backend/src/utils/serviceLocation587.js`).
import 'package:get/get.dart';
import 'package:hopetsit/widgets/paw_icons.dart';

enum ServiceLocationFamily { sitting, walk, visit }

const Set<String> _visitServices = <String>{
  'home_visit', 'drop_in', 'drop_in_visit', 'pet_visit', 'visit', 'visits',
};

/// Famille d'un type de service (null si aucun service choisi).
ServiceLocationFamily? serviceLocationFamily(String? serviceType) {
  final s = (serviceType ?? '').trim().toLowerCase();
  if (s.isEmpty) return null;
  if (s == 'dog_walking' || s == 'walking') return ServiceLocationFamily.walk;
  if (_visitServices.contains(s)) return ServiceLocationFamily.visit;
  return ServiceLocationFamily.sitting;
}

/// Une option du choix de lieu (valeur serveur + libellé + sous-titre + icône maison).
class ServiceLocationOption {
  const ServiceLocationOption(this.value, this.labelKey, this.subKey, this.icon);
  final String value;
  final String labelKey;
  final String subKey;
  final PawIcon icon;
}

const ServiceLocationOption kLocAtOwner = ServiceLocationOption(
    'at_owner', 'svc587_opt_at_owner', 'svc587_opt_at_owner_sub', PawIcon.home);
const ServiceLocationOption kLocAtSitter = ServiceLocationOption(
    'at_sitter', 'svc587_opt_at_sitter', 'svc587_opt_at_sitter_sub', PawIcon.house);
const ServiceLocationOption kLocBoth = ServiceLocationOption(
    'both', 'svc587_opt_both', '', PawIcon.check);
const ServiceLocationOption kLocPickup = ServiceLocationOption(
    'pickup', 'svc587_opt_pickup', 'svc587_opt_pickup_sub', PawIcon.key);
const ServiceLocationOption kLocMeeting = ServiceLocationOption(
    'meeting_point', 'svc587_opt_meeting', 'svc587_opt_meeting_sub', PawIcon.pin);

/// Options proposées pour ce service. `current` = valeur déjà enregistrée
/// (mode « Modifier ») : l'ancien « Les deux » reste affiché s'il est choisi.
List<ServiceLocationOption> serviceLocationOptions(String? serviceType,
    {String? current}) {
  switch (serviceLocationFamily(serviceType)) {
    case ServiceLocationFamily.walk:
      return const <ServiceLocationOption>[kLocPickup, kLocMeeting];
    case ServiceLocationFamily.visit:
      return const <ServiceLocationOption>[kLocAtOwner];
    case ServiceLocationFamily.sitting:
      return <ServiceLocationOption>[
        kLocAtOwner,
        kLocAtSitter,
        if (current == 'both') kLocBoth,
      ];
    case null:
      return const <ServiceLocationOption>[];
  }
}

/// Titre de la question selon le service.
String serviceLocationTitleKey(String? serviceType) {
  switch (serviceLocationFamily(serviceType)) {
    case ServiceLocationFamily.walk:
      return 'svc587_title_walk';
    case ServiceLocationFamily.visit:
      return 'svc587_title_visit';
    default:
      return 'svc587_title_sitting';
  }
}

/// La valeur va-t-elle avec ce service ?
bool serviceLocationFits(String? serviceType, String? value) {
  final v = (value ?? '').trim();
  if (v.isEmpty) return false;
  return serviceLocationOptions(serviceType, current: v).any((o) => o.value == v);
}

/// Libellé NEUTRE (lu par les deux parties). '' si valeur inconnue/absente.
/// Point de rendez-vous : « Point de rendez-vous · Parc Monceau ».
String serviceLocationDisplay(String? raw, {String? meetingPoint}) {
  switch ((raw ?? '').trim().toLowerCase()) {
    case 'at_owner':
      return 'svc587_show_at_owner'.tr;
    case 'at_sitter':
      return 'svc587_show_at_sitter'.tr;
    case 'both':
      return 'svc587_show_both'.tr;
    case 'pickup':
      return 'svc587_show_pickup'.tr;
    case 'meeting_point':
      final place = (meetingPoint ?? '').trim();
      return place.isEmpty
          ? 'svc587_show_meeting'.tr
          : '${'svc587_show_meeting'.tr} · $place';
    default:
      return '';
  }
}

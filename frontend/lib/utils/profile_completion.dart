// v575 — « le pourcentage ne se met pas à jour », « les boutons ouvrent les
// mêmes » (Daniel, 21/09/2026).
//
// AVANT : le calcul vivait dans le widget `ProfileCompletionCard`, et son
// `switch` d'action envoyait `bio`, `services` et `animaux` sur le MÊME écran
// générique, sans ciblage. Ici : une fonction PURE, testable, qui dit pour
// chaque élément (1) s'il est rempli, (2) quel écran ouvrir, (3) sur quel
// champ se positionner. Le widget ne fait plus que l'affichage.
//
// Règle : le même élément doit être jugé sur le champ que l'écran enregistre
// RÉELLEMENT (c'était la source des « ça refuse » : la ville n'était jamais
// envoyée sans GPS, donc l'élément « Ville » restait rouge à vie).

import 'package:hopetsit/models/profile_model.dart';

/// Écran à ouvrir pour compléter un élément.
enum ProfileFixTarget {
  /// Sélecteur de photo (appareil / galerie), pas l'écran d'édition.
  photo,

  /// Feuille « Mes coordonnées » (téléphone + adresse + ville).
  contactSheet,

  /// Écran « Modifier le profil » du rôle, positionné sur [ProfileFixItem.focusField].
  editProfile,

  /// Écran « Mes animaux » (propriétaire).
  pets,
}

/// Identifiants de champ utilisés par `focusField` sur les 3 écrans d'édition.
/// Toute valeur inconnue est ignorée par l'écran (API rétro-compatible).
class ProfileFocusField {
  static const name = 'name';
  static const bio = 'bio';
  static const languages = 'languages';
  static const services = 'services';
  static const animals = 'animals';
  static const phone = 'phone';
  static const address = 'address';
  static const city = 'city';
}

/// Longueur minimale d'une présentation pour qu'elle « compte ».
/// Affichée à l'utilisateur dans l'aide du champ (clé `about_helper`), pour
/// qu'une bio de 5 caractères n'ait plus l'air d'être refusée sans raison.
const int kProfileBioMinLength = 20;

class ProfileFixItem {
  /// Identifiant stable (utilisé par les tests et les clés de widget).
  final String key;

  /// Clé i18n du libellé.
  final String labelKey;

  final bool done;
  final ProfileFixTarget target;

  /// Champ à mettre en évidence quand [target] est [ProfileFixTarget.editProfile].
  final String? focusField;

  const ProfileFixItem({
    required this.key,
    required this.labelKey,
    required this.done,
    required this.target,
    this.focusField,
  });
}

/// Entrée de la fonction pure : uniquement des valeurs simples, pour que les
/// tests n'aient pas à construire un `ProfileModel` complet.
class ProfileCompletionInput {
  final String name;
  final String firstName;
  final String lastName;
  final String avatarUrl;
  final String mobile;
  final String address;
  final String city;
  final String bio;
  final List<String> services;
  final List<String> acceptedPetTypes;
  final int petsCount;

  const ProfileCompletionInput({
    this.name = '',
    this.firstName = '',
    this.lastName = '',
    this.avatarUrl = '',
    this.mobile = '',
    this.address = '',
    this.city = '',
    this.bio = '',
    this.services = const [],
    this.acceptedPetTypes = const [],
    this.petsCount = 0,
  });

  factory ProfileCompletionInput.fromProfile(ProfileModel p) =>
      ProfileCompletionInput(
        name: p.name,
        firstName: p.firstName,
        lastName: p.lastName,
        avatarUrl: p.avatar.url,
        mobile: p.mobile,
        address: p.address,
        city: p.city ?? '',
        bio: p.bio,
        services: p.service,
        acceptedPetTypes: p.acceptedPetTypes,
        // `stats.petsCount` est absent des profils prestataire : on retombe
        // sur la liste embarquée.
        petsCount: p.stats.petsCount > 0 ? p.stats.petsCount : p.pets.length,
      );
}

/// Prénom + nom d'un profil. Un compte antérieur à la v575 n'a que `name` :
/// on dérive alors 1er mot = prénom, le reste = nom (même règle que
/// `backend/src/utils/personName.js`).
({String firstName, String lastName}) splitPersonName(
  String name, {
  String firstName = '',
  String lastName = '',
}) {
  final f = firstName.trim();
  final l = lastName.trim();
  if (f.isNotEmpty || l.isNotEmpty) return (firstName: f, lastName: l);
  final clean = name.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (clean.isEmpty) return (firstName: '', lastName: '');
  final parts = clean.split(' ');
  if (parts.length == 1) return (firstName: parts.first, lastName: '');
  return (firstName: parts.first, lastName: parts.sublist(1).join(' '));
}

/// « Prénom Nom » sans espace parasite.
String joinPersonName(String firstName, String lastName) =>
    '${firstName.trim()} ${lastName.trim()}'.replaceAll(RegExp(r'\s+'), ' ').trim();

/// Les éléments de complétion du rôle, dans l'ordre d'affichage.
///
/// `role` : 'owner' | 'sitter' | 'walker'. Toute autre valeur est traitée
/// comme un prestataire (comportement historique conservé).
List<ProfileFixItem> profileCompletionItemsFor(
  ProfileCompletionInput p,
  String role,
) {
  final isOwner = role == 'owner';
  final parts = splitPersonName(p.name, firstName: p.firstName, lastName: p.lastName);

  final items = <ProfileFixItem>[
    // v575 — « j'ai que "nom" et pas "nom et prénom" » : l'élément n'est
    // rempli que lorsque les DEUX parties existent.
    ProfileFixItem(
      key: 'name',
      labelKey: 'completion_item_name',
      done: parts.firstName.isNotEmpty && parts.lastName.isNotEmpty,
      target: ProfileFixTarget.editProfile,
      focusField: ProfileFocusField.name,
    ),
    ProfileFixItem(
      key: 'photo',
      labelKey: 'completion_item_photo',
      done: p.avatarUrl.trim().isNotEmpty,
      target: ProfileFixTarget.photo,
    ),
    ProfileFixItem(
      key: 'phone',
      labelKey: 'completion_item_phone',
      done: p.mobile.trim().isNotEmpty,
      target: ProfileFixTarget.contactSheet,
      focusField: ProfileFocusField.phone,
    ),
    ProfileFixItem(
      key: 'address',
      labelKey: 'completion_item_address',
      done: p.address.trim().isNotEmpty,
      target: ProfileFixTarget.contactSheet,
      focusField: ProfileFocusField.address,
    ),
    ProfileFixItem(
      key: 'city',
      labelKey: 'completion_item_city',
      done: p.city.trim().isNotEmpty,
      target: ProfileFixTarget.contactSheet,
      focusField: ProfileFocusField.city,
    ),
    ProfileFixItem(
      key: 'bio',
      labelKey: 'completion_item_bio',
      done: p.bio.trim().length >= kProfileBioMinLength,
      target: ProfileFixTarget.editProfile,
      focusField: ProfileFocusField.bio,
    ),
  ];

  if (isOwner) {
    items.add(ProfileFixItem(
      key: 'pets',
      labelKey: 'completion_item_pets',
      done: p.petsCount > 0,
      target: ProfileFixTarget.pets,
    ));
  } else {
    items.add(ProfileFixItem(
      key: 'services',
      labelKey: 'completion_item_services',
      done: p.services.isNotEmpty,
      target: ProfileFixTarget.editProfile,
      focusField: ProfileFocusField.services,
    ));
    items.add(ProfileFixItem(
      key: 'animals',
      labelKey: 'completion_item_animals',
      done: p.acceptedPetTypes.isNotEmpty,
      target: ProfileFixTarget.editProfile,
      focusField: ProfileFocusField.animals,
    ));
  }
  return items;
}

/// Pourcentage entier, 0 → 100.
int profileCompletionPercentFor(ProfileCompletionInput p, String role) {
  final items = profileCompletionItemsFor(p, role);
  if (items.isEmpty) return 100;
  final done = items.where((i) => i.done).length;
  return ((done / items.length) * 100).round();
}

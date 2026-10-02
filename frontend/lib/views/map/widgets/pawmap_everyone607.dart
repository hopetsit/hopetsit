// v607 (01/10/2026, PAM) — bouton rose « tout le monde » de la PawMap.
//
// Décision 4.4 de Daniel : UN SEUL comportement partout = afficher / masquer
// tous les membres (comme le site, `map/page.tsx`, `showMembers`). Avant le
// 607, l'app dézoomait sur les amis en direct. Un appui masque tous les
// membres (ronds photo, groupes, amis compris), un appui les réaffiche.
// L'état se voit sur le bouton (allumé = membres visibles) et il est retenu
// sur le COMPTE comme les autres réglages de la carte : `pawMap.layers.everyone`
// (route /users/me/map-prefs, lue aussi par le site). Absent = visible.
//
// Ce qui n'est PAS masqué (identique au site) : mon propre rond, les amis
// partagés EN DIRECT, les demandes, les lieux, les signalements, les PawSpots.

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hopetsit/views/map/widgets/paw_rail_button.dart';
import 'package:hopetsit/utils/pawmap_theme.dart';

/// Clé du calque dans `pawMap.layers` (même nom côté serveur et site).
const String kPawEveryoneLayerKey = 'everyone';

/// Lecture tolérante du réglage : absent ou illisible = membres visibles.
bool pawEveryoneFromLayers(Map<String, bool> layers) =>
    layers[kPawEveryoneLayerKey] ?? true;

/// Les membres (ronds photo, groupes, amis compris) sont-ils posés sur la
/// carte ? Bouton rose éteint = jamais, quelles que soient les pastilles de
/// rôle et « Amis ». Utilisé par `_buildMarkers` de la PawMap.
bool pawMembersLayerOn({
  required bool everyone,
  required bool roles,
  required bool friends,
}) =>
    everyone && (roles || friends);

/// Texte du bouton : il dit ce que fera l'appui (comme le site).
String pawEveryoneLabelKey(bool shown) =>
    shown ? 'map_members_hide' : 'map_members_show';

/// Le bouton rose de la barre de droite. Allumé = membres visibles.
class PawEveryoneButton extends StatelessWidget {
  const PawEveryoneButton({
    super.key,
    required this.shown,
    required this.onTap,
  });

  final bool shown;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PawCapsuleButton(
      key: const ValueKey<String>('capsule_everyone'),
      // Éteint = icône barrée : l'état se lit sans toucher le bouton.
      icon: shown ? Icons.groups_rounded : Icons.group_off_rounded,
      label: pawEveryoneLabelKey(shown).tr,
      secondary: true,
      active: shown,
      tint: PawMapTheme.rose,
      onTap: onTap,
    );
  }
}

// v592 — Daniel (26/09) : « quand je me connecte, il y a un mini lag qui
// clignote, qui tremble sur mon profil le temps que ça s'installe ».
//
// Sous l'en-tête, la page Profil changeait de forme pendant le chargement :
// la carte « profil complété à X % » n'existe qu'une fois le profil reçu, et
// en apparaissant elle poussait tout le reste de ~200 px vers le bas (mesuré
// par test/profile592_stable_test.dart).
//
// [ProfileLoadReveal] garde le contenu construit (ses propres chargements
// partent tout de suite) mais invisible tant que le profil n'est pas là, puis
// le fait apparaître d'UN seul fondu, déjà à sa forme finale. Règles :
//   · profil déjà connu (cache de l'appareil) → visible dès la 1re image ;
//   · une fois visible, il ne redevient JAMAIS invisible (rechargements) ;
//   · jamais d'attente sans fin : au bout de [maxWait] (serveur lent, erreur)
//     le contenu s'affiche quand même.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ProfileLoadReveal extends StatefulWidget {
  const ProfileLoadReveal({
    super.key,
    required this.isReady,
    required this.child,
    this.maxWait = const Duration(milliseconds: 1600),
  });

  /// Lu dans un Obx : doit lire au moins un Rx (ex. `profile.value`,
  /// `isLoading.value`).
  final bool Function() isReady;
  final Widget child;
  final Duration maxWait;

  @override
  State<ProfileLoadReveal> createState() => _ProfileLoadRevealState();
}

class _ProfileLoadRevealState extends State<ProfileLoadReveal> {
  /// Posé par la minuterie de secours (serveur lent).
  final RxBool _timedOut = false.obs;

  /// Verrou : une fois visible, toujours visible. Simple booléen (jamais un
  /// Rx modifié pendant le build).
  bool _latched = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.maxWait, () {
      if (mounted) _timedOut.value = true;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final timedOut = _timedOut.value;
      final ready = widget.isReady();
      if (ready || timedOut) {
        _latched = true;
        _timer?.cancel();
      }
      final visible = _latched;
      return IgnorePointer(
        ignoring: !visible,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          child: widget.child,
        ),
      );
    });
  }
}

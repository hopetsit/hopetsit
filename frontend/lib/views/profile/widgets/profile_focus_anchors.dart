// v575 — Daniel : « ça ouvre les mêmes ». Les pastilles « + Téléphone »,
// « + À propos de moi », « + Services »… ouvraient toutes le même écran, sans
// jamais amener au champ concerné.
//
// Ce petit utilitaire donne aux 3 écrans « Modifier le profil » un paramètre
// `focusField` RÉTRO-COMPATIBLE (null = comportement historique) : chaque
// section pose une ancre, et l'écran fait défiler jusqu'à elle — puis donne le
// clavier au champ quand il y en a un.
import 'package:flutter/material.dart';

class ProfileFocusAnchors {
  final Map<String, GlobalKey> _keys = {};
  final Map<String, FocusNode> _nodes = {};

  /// Ancre de défilement d'une section (`ProfileFocusField.*`).
  GlobalKey anchor(String field) =>
      _keys.putIfAbsent(field, () => GlobalKey(debugLabel: 'anchor_$field'));

  /// Nœud de focus d'un champ de saisie (optionnel).
  FocusNode node(String field) =>
      _nodes.putIfAbsent(field, () => FocusNode(debugLabel: 'focus_$field'));

  bool hasNode(String field) => _nodes.containsKey(field);

  /// Fait défiler jusqu'à la section, après la première frame. Sans effet si
  /// `field` est nul, inconnu, ou si l'ancre n'est pas (encore) montée.
  void reveal(String? field, {bool requestFocus = true}) {
    if (field == null || field.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final ctx = _keys[field]?.currentContext;
      if (ctx == null) return;
      try {
        await Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          alignment: 0.1,
        );
      } catch (_) {
        // Pas de Scrollable ancêtre (écran court) : rien à faire.
      }
      if (requestFocus && _nodes.containsKey(field)) {
        _nodes[field]!.requestFocus();
      }
    });
  }

  void dispose() {
    for (final n in _nodes.values) {
      n.dispose();
    }
    _nodes.clear();
    _keys.clear();
  }
}

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

  /// Fait défiler jusqu'à la section et lui donne le focus.
  ///
  /// v575 (trouvé en test réel) : l'écran d'édition affiche d'abord une roue de
  /// chargement (`isFetching`) ; à la première frame l'ancre n'est donc PAS
  /// encore montée et l'ancienne version abandonnait en silence — le bouton
  /// « À propos de moi » ouvrait l'écran sans jamais descendre jusqu'au champ.
  /// On réessaie donc jusqu'à ce que l'ancre existe (4 s maximum).
  void reveal(String? field, {bool requestFocus = true}) {
    if (field == null || field.isEmpty) return;
    _disposed = false;
    _tryReveal(field, requestFocus, 0);
  }

  bool _disposed = false;

  void _tryReveal(String field, bool requestFocus, int attempt) {
    if (_disposed || attempt > 33) return; // 33 × 120 ms ≈ 4 s
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_disposed) return;
      final ctx = _keys[field]?.currentContext;
      if (ctx == null) {
        await Future<void>.delayed(const Duration(milliseconds: 120));
        _tryReveal(field, requestFocus, attempt + 1);
        // Force une frame : sans elle le rappel suivant n'arriverait jamais sur
        // un écran immobile.
        WidgetsBinding.instance.scheduleFrame();
        return;
      }
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
      if (!_disposed && requestFocus && _nodes.containsKey(field)) {
        _nodes[field]!.requestFocus();
      }
    });
  }

  void dispose() {
    _disposed = true;
    for (final n in _nodes.values) {
      n.dispose();
    }
    _nodes.clear();
    _keys.clear();
  }
}

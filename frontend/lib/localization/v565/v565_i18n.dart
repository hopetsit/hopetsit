// v565 — registre des paquets de traduction ajoutés par le build 565.
import 'chat_i18n.dart';
import 'map_i18n.dart';
import 'profile_i18n.dart';
import 'home_i18n.dart';
import 'core_i18n.dart';
import 'friends_i18n.dart';
import 'shop567_i18n.dart';
import 'ui567_i18n.dart';
import 'delete567_i18n.dart';
import 'pawspot567_i18n.dart';

const List<Map<String, Map<String, String>>> v565Packs = <Map<String, Map<String, String>>>[chatI18n, mapI18n, profileI18n, homeI18n, coreI18n, friendsI18n, shop567I18n, ui567I18n, delete567I18n, pawspot567I18n];

/// Fusionne toutes les clés v565 pour une langue (code court : fr, en, es…).
Map<String, String> v565For(String lang) {
  final out = <String, String>{};
  for (final p in v565Packs) {
    out.addAll(p[lang] ?? const <String, String>{});
  }
  return out;
}

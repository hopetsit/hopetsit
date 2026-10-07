// v565 — registre des paquets de traduction ajoutés par le build 565.
import 'live589_i18n.dart';
import 'pawmap589_i18n.dart';
import 'pawmap590_i18n.dart';
import 'pawmap592_i18n.dart';
import 'balade599_i18n.dart';
import 'pawmap601_i18n.dart';
import 'pawmap602_i18n.dart';
import 'notif599_i18n.dart';
import 'chat604_i18n.dart';
import 'pawmap605_i18n.dart';
import 'pawmap607_i18n.dart';
import 'pawpoints607_i18n.dart';
import 'kyc607_i18n.dart';
import 'plush607_i18n.dart'; // 607 (PAM) — mini-peluches
import 'verified609_i18n.dart'; // 609 (PAM) — identité vérifiée sur la carte
import 'profile589_i18n.dart';
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
import 'cards568_i18n.dart';
import 'chatdel569_i18n.dart';
import 'shop569_i18n.dart';
import 'agreement569_i18n.dart';
import 'pay569_i18n.dart';
import 'post569_i18n.dart';
import 'misc569_i18n.dart';
import 'auth569_i18n.dart';
import 'lists569_i18n.dart';
import 'home571_i18n.dart';
import 'ownerhome571_i18n.dart';
import 'bookings571_i18n.dart';
import 'location573_i18n.dart';
import 'profiles573_i18n.dart';
import 'lot3_573_i18n.dart';
import 'profile575_i18n.dart';
import 'fixes575_i18n.dart';
import 'fixes576_i18n.dart';
import 'invoice576_i18n.dart';
import 'neo583_i18n.dart';
import 'lota583_i18n.dart';
import 'lotc584_i18n.dart';
import 'lotd585_i18n.dart';
import 'pawmap584b_i18n.dart';
import 'pawmap585_i18n.dart';
import 'pawmap586_i18n.dart';
import 'pawmap586b_i18n.dart';
import 'pawmap587_i18n.dart';
import 'help587_i18n.dart';
import 'signal587_i18n.dart';
import 'vis587_i18n.dart';
import 'budget587_i18n.dart';
import 'publish587_i18n.dart';
import 'friends588_i18n.dart';
import 'neo600_i18n.dart';
import 'neo610_i18n.dart';
import 'pawmap610_i18n.dart';
import 'alerts610_i18n.dart'; // 610 (ZOE) — signalements, règle B
import 'alerts611_i18n.dart'; // 611 (ZOE) — animal perdu / trouvé gratuit pour tous
import 'pioneer607_i18n.dart';
import 'ranks611_i18n.dart'; // 611 (PAM) — rangs Chiot → Légende
import 'pawmap611_i18n.dart'; // 611 (PAM) — reprise du direct sur ce téléphone
import 'pm613_i18n.dart'; // 613 (PAM) — fête de la peluche + « Rejoindre »

const List<Map<String, Map<String, String>>> v565Packs = <Map<String, Map<String, String>>>[neo600I18n, neo610I18n, pawmap610I18n,chatI18n, mapI18n, profileI18n, homeI18n, coreI18n, friendsI18n, shop567I18n, ui567I18n, delete567I18n, pawspot567I18n, cards568I18n, chatdel569I18n, shop569I18n, agreement569I18n, pay569I18n, post569I18n, misc569I18n, auth569I18n, lists569I18n, home571I18n, ownerhome571I18n, bookings571I18n, location573I18n, profiles573I18n, lot3573I18n, profile575I18n, fixes575I18n, fixes576I18n, invoice576I18n, neo583I18n, lotA583I18n, lotC584I18n, lotD585I18n, pawmap584bI18n, pawmap585I18n, pawmap586I18n, pawmap586bI18n, pawmap587I18n, help587I18n, publish587I18n, signal587I18n, vis587I18n, budget587I18n, friends588I18n, live589I18n, pawmap589I18n, profile589I18n, pawmap590I18n, pawmap592I18n, balade599I18n, notif599I18n, pawmap601I18n, pawmap602I18n, chat604I18n, pawmap605I18n, pawmap607I18n, pioneer607I18n, plush607I18n, pawpoints607I18n, kyc607I18n, verified609I18n, alerts610I18n, alerts611I18n, ranks611I18n, pawmap611I18n, pm613I18n];

/// Fusionne toutes les clés v565 pour une langue (code court : fr, en, es…).
Map<String, String> v565For(String lang) {
  final out = <String, String>{};
  for (final p in v565Packs) {
    out.addAll(p[lang] ?? const <String, String>{});
  }
  return out;
}

---
name: theme-system-and-locale
description: "Dark mode = ThemeMode.system depuis v442 (sélecteur Clair/Sombre/Système) ; langue suit déjà l'appareil"
metadata: 
  node_type: memory
  type: project
  originSessionId: 0a0b2fc1-ddb4-4146-8065-0630729ac1bb
---

**Dark mode (v442)** : `ThemeController` (`controllers/theme_controller.dart`) était FORCÉ en `ThemeMode.light` à cause d'un bug « dark bleeding through » (calendrier dispo + dialogs = texte sombre sur fond sombre). v442 : défaut → `ThemeMode.system` + sélecteur **Clair/Sombre/Système** via `appearance_language_section.dart` sous Modifier le profil (3 rôles). Fixé : `availability_calendar_screen` (TableCalendar headerStyle/calendarStyle explicites) + TimePicker de publish (theme-aware). **Reste à auditer en sombre** : écrans payment/invoice/webview (hardcoded `Colors.white` non exhaustivement traités) → si un écran sombre est illisible, chercher `AppColors.whiteColor`/`Colors.white`/`blackColor` en dur et passer en `AppColors.xxx(context)`.

**Langue (déjà OK avant v442)** : `LocalizationService.getInitialLocale()` (`localization/app_translations.dart`) suit déjà l'appareil au 1er lancement (stored → `Get.deviceLocale` parmi les 6 → en_US). v442 : inscription préremplit langue + indicatif tél depuis `Get.deviceLocale` (region ES → Español + +34) ; sélecteur « Langue de l'app » (6 langues, `LocalizationService.updateLocale`) sous Modifier le profil. Distinct du champ profil « langues parlées ».

**Cloche notif** : aucune des 3 fiches profil (display) n'avait de cloche → ajout `profile_notification_bell.dart` (owner/walker → NotificationsScreen, sitter → SitterNotificationsScreen).

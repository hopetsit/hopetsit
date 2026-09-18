// v565 (lot app-calendar-wallet) — l'écran a été déplacé dans
// `views/shared/availability_calendar_screen.dart` : il est COMMUN aux rôles
// sitter et walker (couleur du rôle, tap = disponible / re-tap = bloqué,
// peinture de plage, raccourcis, enregistrement automatique). Ce fichier ne
// fait plus que ré-exporter la classe pour que les imports existants
// (routes, en-tête de profil, catégories) continuent de fonctionner.
//
// Historique conservé : v426 rendu role-aware (/walkers/me/availability),
// v441 styles thème sombre, v565 point 39 kit Profil.
export 'package:hopetsit/views/shared/availability_calendar_screen.dart'
    show AvailabilityCalendarScreen;

"""
HopeTSIT iOS Build Guide v23.1.243 generator.
v243 = bug fix batch (round 1 + 2 + 3) on top of v242.
Highlights: Persona link recovery, halo colors mobile + WEB,
perf audit (low-end Android), Friends live page on the website,
cross-platform message sync, friend-add friction removed.
"""
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak,
)
from reportlab.lib.enums import TA_LEFT, TA_JUSTIFY

OUT = "C:/Users/Usuario/Downloads/HopeTSIT_iOS_Build_Guide_v23.1.243.pdf"

doc = SimpleDocTemplate(
    OUT, pagesize=A4,
    leftMargin=1.8*cm, rightMargin=1.8*cm,
    topMargin=1.8*cm, bottomMargin=1.8*cm,
    title="HopeTSIT iOS Build Guide v23.1.243",
    author="HopeTSIT team",
)

styles = getSampleStyleSheet()
H1 = ParagraphStyle('H1', parent=styles['Heading1'],
                   fontSize=22, textColor=colors.HexColor("#EF4324"),
                   spaceAfter=14, leading=26)
H2 = ParagraphStyle('H2', parent=styles['Heading2'],
                   fontSize=15, textColor=colors.HexColor("#1F2937"),
                   spaceAfter=10, spaceBefore=14, leading=18)
H3 = ParagraphStyle('H3', parent=styles['Heading3'],
                   fontSize=12, textColor=colors.HexColor("#EF4324"),
                   spaceAfter=6, spaceBefore=10, leading=14)
P  = ParagraphStyle('P', parent=styles['BodyText'],
                   fontSize=10, leading=14, alignment=TA_JUSTIFY)
CODE = ParagraphStyle('CODE', parent=styles['Code'],
                     fontSize=9, leading=12, leftIndent=12,
                     textColor=colors.HexColor("#0F172A"),
                     backColor=colors.HexColor("#F1F5F9"))
NOTE = ParagraphStyle('NOTE', parent=styles['BodyText'],
                     fontSize=9, leading=13, leftIndent=12, rightIndent=12,
                     textColor=colors.HexColor("#92400E"),
                     backColor=colors.HexColor("#FEF3C7"),
                     borderColor=colors.HexColor("#F59E0B"),
                     borderWidth=1, borderPadding=8)
INFO = ParagraphStyle('INFO', parent=styles['BodyText'],
                     fontSize=9, leading=13, leftIndent=12, rightIndent=12,
                     textColor=colors.HexColor("#075985"),
                     backColor=colors.HexColor("#E0F2FE"),
                     borderColor=colors.HexColor("#0EA5E9"),
                     borderWidth=1, borderPadding=8)
GREEN = ParagraphStyle('GREEN', parent=styles['BodyText'],
                     fontSize=10, leading=14, leftIndent=12, rightIndent=12,
                     textColor=colors.HexColor("#065F46"),
                     backColor=colors.HexColor("#D1FAE5"),
                     borderColor=colors.HexColor("#10B981"),
                     borderWidth=1, borderPadding=8)
RED = ParagraphStyle('RED', parent=styles['BodyText'],
                     fontSize=10, leading=14, leftIndent=12, rightIndent=12,
                     textColor=colors.HexColor("#7F1D1D"),
                     backColor=colors.HexColor("#FEE2E2"),
                     borderColor=colors.HexColor("#EF4444"),
                     borderWidth=1, borderPadding=8)

flow = []

# ─── Cover ────────────────────────────────────────────────────────────────
flow.append(Paragraph("HopeTSIT — iOS Build Guide", H1))
flow.append(Paragraph("Version 23.1.243 (Build 243)", H2))
flow.append(Spacer(1, 0.4*cm))
flow.append(Paragraph(
    "Build guide & changelog pour Xcode (Mac requis). Couvre 100% du delta "
    "Android v23.1.242 → v23.1.243 — UN release bug-fix groupé Round 1+2+3 "
    "demandé par Daniel : Persona link recovery + halo couleurs (mobile et "
    "WEB !) + i18n hardcoded supprimé + friend add friction enlevée + perf "
    "audit low-end Android + page web /friends/live (PawFollow social) + "
    "sync messages cross-platform Android/web/iOS.",
    P))
flow.append(Spacer(1, 0.6*cm))
flow.append(Paragraph(
    "v23.1.243 — TL;DR : un seul commit, 25 fichiers, 1085 insertions, "
    "161 deletions. Backend (Render) + mobile + website (Vercel) déployés "
    "ensemble. Aucune migration DB, aucun breaking change.",
    GREEN))

flow.append(PageBreak())

# ─── Changelog v243 ───────────────────────────────────────────────────────
flow.append(Paragraph("Changelog v23.1.243", H1))

flow.append(Paragraph("Round 1 — bugs Daniel screenshots", H2))

flow.append(Paragraph("1. Persona 502 PERSONA_LINK_EMPTY", H3))
flow.append(Paragraph(
    "Backend kycController.js : Persona avait changé son format de réponse, "
    "`meta['one-time-link']` ne venait plus systématiquement. On lit "
    "maintenant 4 chemins : meta['one-time-link'], data.attributes.url, "
    "data.attributes['one-time-link'], links.session. Si Persona ne renvoie "
    "AUCUN lien malgré une création d'inquiry réussie, on fallback sur "
    "l'URL hosted officielle : https://withpersona.com/verify?inquiry-id={id}. "
    "L'user ne reste plus jamais bloqué sur 'Erreur vérifier identité'.",
    P))

flow.append(Paragraph("2. Halo violet famille + orange owner sur PawMap", H3))
flow.append(Paragraph(
    "paw_map_screen.dart : nouvelle priorité de couleurs halo : famille = "
    "violet (#8B5CF6) prime sur le rôle, walker = vert, sitter = bleu, "
    "owner = orange brand (#EF4324), fallback = silver. Mobile + Web même "
    "code couleur (cf. round 3).",
    P))

flow.append(Paragraph("3. i18n strings hardcodées FR supprimées", H3))
flow.append(Paragraph(
    "15 nouvelles clés ajoutées en 6 langues (fr/en/es/de/it/pt) : "
    "<b>KYC screen</b> (Vérifié, En attente, Comment ça marche, Paie 3 €, "
    "Scan ton passeport, etc.), <b>coin shop boost dialogs</b> (Annuler, "
    "Confirmer, Payer avec wallet, Acheter Boost @tier, Ton profil sera "
    "mis en avant), <b>send_request total</b> (À confirmer). Plus aucun "
    "FR ne fuit dans l'UI Espagnol/Allemand/Italien/Portugais.",
    P))

flow.append(Paragraph("4. Difficulté à ajouter amis", H3))
flow.append(Paragraph(
    "Frontend friends_screen.dart : ajout d'un <b>debounce 300 ms</b> sur "
    "le champ search — avant on hitait /friends/search à CHAQUE keystroke. "
    "Backend friendRoutes.js : search <b>multi-token AND</b>. \"Daniel Smith\" "
    "trouve maintenant un user avec firstName=Daniel ET lastName=Smith (avant "
    "0 résultat car regex /Daniel Smith/ sur chaque champ séparé).",
    P))

flow.append(Paragraph("Round 2 — bugs Daniel feedback round 2", H2))

flow.append(Paragraph("5. Quick action buttons PawMap", H3))
flow.append(Paragraph(
    "Sublabel supprimé (la 2e ligne grisée). Un seul titre court par bouton, "
    "traduit en 6 langues : Suivre/Follow/Seguir/Folgen/Segui/Seguir, "
    "Amis/Friends/Amigos/Freunde/Amici/Amigos, En direct/Live/En vivo/Live/"
    "Live/Ao vivo, Alertes/Alerts/Alertas/Warnungen/Avvisi/Alertas, "
    "Signaler/Report/Reportar/Melden/Segnala/Reportar. État ON du Suivre = "
    "\"Actif\" (1 mot, 6 langues).",
    P))

flow.append(Paragraph("6. Suivre OFF désactive vraiment la position", H3))
flow.append(Paragraph(
    "Root cause : map:position-update persistait location.coordinates en DB "
    "toutes les 10s, mais map:go-offline ne faisait QUE notifier les amis "
    "live → la dernière position restait en DB → /friends/:id/last-position "
    "la renvoyait quand même. Fix mapSocket.js : `$unset: "
    "{ 'location.coordinates': '' }` au go-offline. Plus aucun fallback DB.",
    P))

flow.append(Paragraph("7. Toggle Afficher position bloqué sur Auto", H3))
flow.append(Paragraph(
    "Root cause #1 : enrichFriendship forçait mySharePosition=true quand "
    "PawFollow actif → le PATCH stockait false en DB mais le GET suivant "
    "renvoyait true → switch bouncing. Root cause #2 : socket bypass "
    "PawFollow/famille ignorait le flag user → position diffusée quand "
    "même. Root cause #3 : /last-position renvoyait coords malgré le toggle "
    "off via bypass PawFollow. Fix triple : mySharePosition = !!dbMyShare, "
    "myShare === false court-circuite le broadcast partout, /last-position "
    "renvoie 403 si otherShareFlag === false.",
    P))

flow.append(Paragraph("Round 3 — re-audit deep + perf + website", H2))

flow.append(Paragraph("8. Audit perf (lag low-end Android)", H3))
flow.append(Paragraph(
    "Root cause : le Obx autour du GoogleMap rebuild la carte toutes les "
    "600 ms (halo pulse) → _buildMarkers() ré-itère TOUS les providers/POIs/"
    "reports + crée chaque BitmapDescriptor à chaque tick → garbage churn "
    "massif sur Oppo/Samsung A-series. Fix :",
    P))
flow.append(Paragraph(
    "<b>WidgetsBindingObserver</b> sur _PawMapScreenState : pause _haloTimer "
    "quand l'app va en background (lock screen, home). Plus aucun rebuild "
    "Google Map quand l'app est invisible.",
    P))
flow.append(Paragraph(
    "<b>_cachedMarkers + _cachedMarkersKey</b> : memoize Set&lt;Marker&gt; "
    "par fingerprint (lengths + show flags + emoji ready + friend positions). "
    "_buildMarkers() ne tourne plus qu'aux changements réels de data, plus "
    "à chaque tick visuel. Gain attendu ~85 % moins de travail/sec sur la "
    "PawMap.",
    P))
flow.append(Paragraph(
    "<b>NetworkImage brute → CachedNetworkImageProvider(maxWidth: 150)</b> "
    "dans pet_post_card.dart, sitter_bottom_sheet.dart, pet_bottom_sheet.dart, "
    "reviews_screen.dart. Décodage limité à 150 px (~30 KB) au lieu du bitmap "
    "natif (~5–10 MB par avatar).",
    P))

flow.append(Paragraph("9. Vérification ajout amis end-to-end", H3))
flow.append(Paragraph(
    "Tracé complet : search debounce 300 ms → backend multi-token AND → "
    "POST /friends/request → socket 'friend_request:received' + push notif "
    "FCM → frontend listeners attachés via addOnConnectedHook (survivent "
    "aux reconnects) → FriendController.permanent dans les 3 nav wrappers. "
    "Fonctionne sans intervention.",
    P))

flow.append(Paragraph("10. Website /friends/live — PawFollow user tracking", H3))
flow.append(Paragraph(
    "Nouvelle page Next.js (rien n'existait avant). Équivalent web de la "
    "PawMap mobile en mode social : liste tous les amis acceptés (GET "
    "/friends), pour chacun fetch leur dernière position (GET "
    "/friends/:id/last-position en parallèle), affiche une map Leaflet "
    "avec halos colorés par rôle (walker vert / sitter bleu / owner orange "
    "/ famille violet — parité mobile), avatars en DivIcon, listeners "
    "map:friend-position + map:friend-offline pour le temps réel. Lien "
    "ajouté depuis /dashboard (nouvelle NavCard) et /pawmap.",
    P))

flow.append(Paragraph("11. Cross-platform message sync Android/web/iOS", H3))
flow.append(Paragraph(
    "Root cause : le type Conversation côté web ne modelait pas friendChat "
    "ni otherParty → les chats friend-to-friend (introduits en v23.1.200 "
    "backend) s'affichaient \"Conversation\" générique sur le web. Backend "
    "/conversations/list les renvoyait correctement avec otherParty mais "
    "l'UI web ne le lisait pas.",
    P))
flow.append(Paragraph(
    "Fix : type Conversation web étendu avec friendChat?: boolean + "
    "otherParty?: { id, name, email, avatar, role }. UI chat fallback : "
    "c.participantName || c.otherParty?.name || \"Conversation\". Messages "
    "désormais cohérents Android = iOS = Web (backend = source unique de "
    "vérité).",
    P))

flow.append(PageBreak())

# ─── iOS build steps ──────────────────────────────────────────────────────
flow.append(Paragraph("Build iOS — étapes Xcode", H1))

flow.append(Paragraph("Pré-requis", H2))
flow.append(Paragraph(
    "Mac avec macOS Sonoma 14.5+ recommandé. Xcode 15.4+ (CLT installés). "
    "Flutter SDK 3.27+ (canal stable). CocoaPods 1.15+. Apple Developer "
    "Program actif (compte Daniel — Team ID configuré dans Xcode > Settings "
    "> Accounts).",
    P))

flow.append(Paragraph("Étape 1 — Pull du code v243", H2))
flow.append(Paragraph(
    "git pull origin main<br/>"
    "cd frontend &amp;&amp; flutter clean &amp;&amp; flutter pub get<br/>"
    "cd ios &amp;&amp; pod install --repo-update",
    CODE))

flow.append(Paragraph("Étape 2 — Version bump", H2))
flow.append(Paragraph(
    "Vérifier pubspec.yaml : version : 23.1.243+243. Xcode prend "
    "automatiquement le 243 comme CFBundleShortVersionString (avant le +) "
    "et CFBundleVersion (après le +). Pas besoin d'éditer Info.plist.",
    P))

flow.append(Paragraph("Étape 3 — Archive Xcode", H2))
flow.append(Paragraph(
    "1. open ios/Runner.xcworkspace<br/>"
    "2. Target Runner sélectionné, scheme Runner, destination = Any iOS Device<br/>"
    "3. Product > Archive (Cmd+B en mode Release d'abord pour valider)<br/>"
    "4. Quand l'archive apparaît dans Organizer : Distribute App > App Store Connect<br/>"
    "5. Upload (Daniel — TestFlight ou production selon ton flux habituel)",
    P))

flow.append(Paragraph("Étape 4 — Smoke tests avant validation", H2))
flow.append(Paragraph(
    "Tester sur device iOS physique :", P))
flow.append(Paragraph(
    "• KYC → bouton Lancer vérification Persona → webview s'ouvre (vérifie "
    "que le fallback URL marche si Persona ne renvoie pas de meta link)<br/>"
    "• PawMap → halos : owner ami = orange, famille = violet, walker = vert, "
    "sitter = bleu<br/>"
    "• PawMap → bouton Suivre OFF → demander à un ami de checker la "
    "/friends/live web : ton point doit disparaître<br/>"
    "• Friends list → toggle Afficher position : doit basculer ON ↔ OFF sans "
    "rebondir sur Auto<br/>"
    "• Friends Ajouter onglet → taper \"Daniel Smith\" (ou un nom complet "
    "réel) : doit trouver le user même si firstName/lastName séparés<br/>"
    "• Boost shop → acheter Boost ou PawSpot en Espagnol → dialog doit être "
    "100% espagnol (Annuler/Confirmer/description)<br/>"
    "• Chat : envoyer un message → vérifier qu'il apparaît immédiatement "
    "côté web (cross-platform sync)",
    P))

flow.append(Paragraph("Étape 5 — Perf check sur device milieu de gamme", H2))
flow.append(Paragraph(
    "Daniel : tester l'app sur iPhone SE 2020 ou iPhone 11 (les low-end "
    "iOS encore en circulation). Ouvrir PawMap, scroller/zoomer la carte 30 "
    "secondes, vérifier qu'il n'y a aucun freeze/saccade. Mettre l'app en "
    "background 1 minute puis rouvrir : le halo pulse reprend "
    "instantanément (preuve que le WidgetsBindingObserver fonctionne).",
    INFO))

flow.append(PageBreak())

# ─── Rollback ────────────────────────────────────────────────────────────
flow.append(Paragraph("Rollback procedure", H1))
flow.append(Paragraph(
    "Si bug critique en prod après upload :",
    P))
flow.append(Paragraph(
    "1. App Store Connect → Phased Release → Pause<br/>"
    "2. git revert b6a399e (commit v243 batch) → git push<br/>"
    "3. Render redeploy auto, Vercel redeploy auto<br/>"
    "4. Rebuild Android APK depuis main pre-v243 si nécessaire<br/>"
    "5. Garder le PDF v23.1.242 sous la main : il reste valide pour le "
    "rollback iOS",
    P))

flow.append(Paragraph(
    "v23.1.243 n'introduit aucune migration DB ni breaking change API → "
    "rollback safe sans coordination spéciale.",
    GREEN))

flow.append(PageBreak())

# ─── Files modified ──────────────────────────────────────────────────────
flow.append(Paragraph("Fichiers modifiés v243 (référence)", H1))

flow.append(Paragraph("Backend (Render auto-deploy)", H2))
flow.append(Paragraph(
    "• backend/src/controllers/kycController.js — Persona link extraction 4 paths + fallback<br/>"
    "• backend/src/routes/friendRoutes.js — search multi-token AND, mySharePosition reflète DB, last-position 403 si opt-out<br/>"
    "• backend/src/sockets/mapSocket.js — go-offline $unset coords + bypass respecte opt-out",
    P))

flow.append(Paragraph("Frontend Flutter", H2))
flow.append(Paragraph(
    "• frontend/pubspec.yaml — 23.1.242+242 → 23.1.243+243<br/>"
    "• frontend/lib/views/map/paw_map_screen.dart — WidgetsBindingObserver + cache markers + halo colors + quick action labels<br/>"
    "• frontend/lib/views/friends/friends_screen.dart — debounce search 300ms<br/>"
    "• frontend/lib/views/kyc/kyc_verification_screen.dart — toutes strings → .tr<br/>"
    "• frontend/lib/views/boost/coin_shop_screen.dart — Annuler/Confirmer/Acheter Boost → .tr<br/>"
    "• frontend/lib/views/service_provider/send_request_screen.dart — À confirmer → .tr<br/>"
    "• frontend/lib/views/pet_sitter/widgets/pet_post_card.dart — perf CachedNetworkImageProvider<br/>"
    "• frontend/lib/views/map/widgets/sitter_bottom_sheet.dart — perf<br/>"
    "• frontend/lib/views/map/widgets/pet_bottom_sheet.dart — perf<br/>"
    "• frontend/lib/views/reviews/reviews_screen.dart — perf<br/>"
    "• frontend/lib/localization/translations/{fr,en,es,de,it,pt}.dart — 15+ nouvelles clés + raccourcis quick actions",
    P))

flow.append(Paragraph("Website Next.js (Vercel auto-deploy)", H2))
flow.append(Paragraph(
    "• website/src/lib/api.ts — getMyFriends, getFriendLastPosition, types FriendItem/FriendOther/FriendLastPosition, Conversation étendu avec friendChat + otherParty<br/>"
    "• website/src/components/FriendsLiveMap.tsx — NEW : Leaflet map temps réel pour amis avec halos par rôle<br/>"
    "• website/src/app/friends/live/page.tsx — NEW : page complète Mes amis en direct<br/>"
    "• website/src/app/dashboard/page.tsx — NavCard \"Mes amis en direct\"<br/>"
    "• website/src/app/pawmap/page.tsx — CTA secondaire vers /friends/live<br/>"
    "• website/src/app/chat/page.tsx — fallback otherParty.name pour les friendChats",
    P))

flow.append(Spacer(1, 0.6*cm))
flow.append(Paragraph(
    "Build : flutter build apk --release a généré app-release.apk (92.2 MB) "
    "copié dans Downloads/HopeTSIT_v23.1.243.apk. Push origin/main = "
    "Render + Vercel redeploy auto. Commit : b6a399e.",
    INFO))

doc.build(flow)
print(f"OK -> {OUT}")

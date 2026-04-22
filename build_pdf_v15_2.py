"""Generate HopeTSIT Recap v15 PDF."""
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, PageBreak, Table, TableStyle,
)
from reportlab.lib.enums import TA_LEFT, TA_CENTER
from xml.sax.saxutils import escape

OUT = "HopeTSIT_Recap_v15-2.pdf"

styles = getSampleStyleSheet()
title = ParagraphStyle('title', parent=styles['Title'], fontSize=22,
                       textColor=colors.HexColor('#C62828'),
                       spaceAfter=18, alignment=TA_CENTER)
h1 = ParagraphStyle('h1', parent=styles['Heading1'], fontSize=15,
                    textColor=colors.HexColor('#1A237E'), spaceBefore=16,
                    spaceAfter=8)
h2 = ParagraphStyle('h2', parent=styles['Heading2'], fontSize=12,
                    textColor=colors.HexColor('#00695C'), spaceBefore=10,
                    spaceAfter=4)
body = ParagraphStyle('body', parent=styles['BodyText'], fontSize=10,
                      leading=14, spaceAfter=6, alignment=TA_LEFT)
small = ParagraphStyle('small', parent=styles['BodyText'], fontSize=9,
                       leading=12, textColor=colors.grey)
mono = ParagraphStyle('mono', parent=styles['Code'], fontSize=9, leading=12,
                      backColor=colors.HexColor('#F5F5F5'),
                      borderPadding=6, leftIndent=4, rightIndent=4)
ok = ParagraphStyle('ok', parent=body, textColor=colors.HexColor('#2E7D32'))

doc = SimpleDocTemplate(OUT, pagesize=A4,
                        leftMargin=1.8*cm, rightMargin=1.8*cm,
                        topMargin=1.6*cm, bottomMargin=1.6*cm)

story = []

# ===== COVER =====
story.append(Paragraph("HopeTSIT — Récap v15", title))
story.append(Paragraph("PawMap fixée, onglet Promeneurs live, seed OSM en cours", small))
story.append(Spacer(1, 8))
story.append(Paragraph(
    "Session v13 → v15. Les 3 rôles (Owner / Sitter / Walker) sont 100% "
    "fonctionnels. PawMap a été largement corrigée: plus d'erreur GetX, "
    "radius 50 km, traductions multilingues, POIs européens en cours "
    "d'import depuis OSM.", body))

story.append(Spacer(1, 12))
story.append(Paragraph("État actuel (v15)", h1))

state = [
    ["Composant", "Statut"],
    ["Flutter analyze", "0 erreur, 0 warning"],
    ["APK debug build", "HopeTSIT_v15.apk"],
    ["Backend Render", "6+ commits walker/referrals/delete/seed déployés"],
    ["Owner — Signup / Profil / Delete", "OK"],
    ["Owner — Publier demande (geoloc)", "OK (picker ville+GPS câblé)"],
    ["Owner — Onglet Promeneurs (home)", "OK (WalkerCard + nearby)"],
    ["Sitter — Signup / Profil / Delete", "OK (tarif horaire retiré de l'UI)"],
    ["Walker — Signup email / OTP", "OK → direct WalkerNavWrapper"],
    ["Walker — Signup Google (email neuf)", "OK"],
    ["Walker — Signup Google (email orphan)", "OK (fix défensif frontend)"],
    ["Walker — Profil / Modifier / Delete", "OK"],
    ["Walker — Parrainages", "OK (backend walker supporté)"],
    ["Switch de rôle Owner ↔ Sitter ↔ Walker", "OK"],
    ["Logout → relog autre rôle (cache GetX)", "OK (fix force-delete controllers)"],
    ["PawMap — erreur GetX sur ouverture", "OK (fix .toSet sur RxSet)"],
    ["PawMap — radius POIs", "50 km (max backend)"],
    ["PawMap — recherche ville + bouton GPS", "OK"],
    ["PawMap — traductions (6 langues)", "OK"],
    ["PawMap — debounce onCameraIdle", "500 ms"],
    ["PawMap — seed OSM Europe", "EN COURS (import Render)"],
    ["Feed Walker/Sitter publications Owner", "BUG — P0 NON FIXÉ"],
]
t = Table(state, colWidths=[9.5*cm, 7.5*cm])
t.setStyle(TableStyle([
    ('BACKGROUND', (0,0), (-1,0), colors.HexColor('#1A237E')),
    ('TEXTCOLOR', (0,0), (-1,0), colors.white),
    ('FONTNAME', (0,0), (-1,0), 'Helvetica-Bold'),
    ('FONTSIZE', (0,0), (-1,-1), 8.5),
    ('GRID', (0,0), (-1,-1), 0.4, colors.grey),
    ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
    ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, colors.HexColor('#F5F5F5')]),
]))
story.append(t)

story.append(PageBreak())

# ===== PROMPT DE REPRISE =====
story.append(Paragraph("Prompt de reprise (pour nouvelle conversation Claude)", h1))
story.append(Paragraph(
    "Copiez le bloc ci-dessous en début de conversation Claude. "
    "Il donne tout le contexte nécessaire pour reprendre sans erreur.", body))
story.append(Spacer(1, 8))

prompt = """\
Je travaille sur HopeTSIT, app Flutter/GetX de pet-sitting avec 3 roles: Owner, Sitter, Walker.
Backend Node.js sur Render: https://hopetsit-backend.onrender.com (a jour, walker complet).
Frontend: C:\\Users\\Usuario\\Downloads\\HopeTSIT_FINAL_FIXED\\HopeTSIT_FINAL\\frontend
Backend: C:\\Users\\Usuario\\Downloads\\HopeTSIT_FINAL_FIXED\\HopeTSIT_FINAL\\backend

Dernier APK qui fonctionne: v15 (dans Downloads/HopeTSIT_v15.apk).

REGLES CRITIQUES (apprises a la dure):
1. JAMAIS de script Python/sed/regex automatique sur plusieurs fichiers Flutter.
   Toujours Edit tool cible, une modif a la fois.
2. Toujours flutter analyze apres chaque modif, avant de passer a la suite.
3. Jamais toucher a la creation de post cote Owner (elle marche).
4. Backend Render a jour avec walker: signup, edit, delete, referrals, seed.
5. Backup avant grosse modif (xcopy /E /I /H).
6. Diagnostic d'abord, proposer 2-3 options, attendre OK user avant de coder.

Etat au moment de ce prompt (v15):
- flutter analyze: 0 issue
- 3 roles 100% operationnels + switch entre eux OK
- PawMap: Obx propre, radius 50km, traductions 6 langues, debounce
- Seed OSM Europe: script backend/src/scripts/seedOsmEurope.js pour peupler
  vet+shop+dog_park via Overpass API (11 pays). Import en cours cote Render.

Bug P0 toujours a fixer:
Feed Walker/Sitter n'affiche pas les publications Owner (demandes de garde).
- Debug prints [FEED DEBUG] en place dans posts_controller.dart.
- Diagnostic v12: l'app appelle GET /posts (public, sans filtre role).
  Backend a GET /posts/requests qui filtre bien (walker -> dog_walking,
  sitter -> exclut dog_walking) mais l'app ne l'appelle JAMAIS.
- Fix propose: rebrancher PostsController.loadPostsWithoutMedia() sur
  /posts/requests avec requiresAuth: true.

Quand tu corriges un bug:
1. Diagnostic sans code
2. Montrer ce que tu as trouve
3. Proposer options avec recommandations
4. Attendre OK user
5. Appliquer avec Edit tool, une modif a la fois
6. flutter analyze
7. Dire quoi tester
"""

for line in prompt.splitlines():
    story.append(Paragraph(escape(line) if line.strip() else "&nbsp;", mono))

story.append(PageBreak())

# ===== MODIFS v13 -> v15 =====
story.append(Paragraph("Changements v13 → v15 (résumé)", h1))

story.append(Paragraph("1. Signup Google Walker (email orphan)", h2))
story.append(Paragraph(
    "<b>Bug</b> : user avec email deja en BDD comme Sitter qui signup Google "
    "en tant que Walker atterrissait sur pet-sitter.", body))
story.append(Paragraph(
    "<b>Fix frontend</b> (auth_controller.dart Google + Apple) : "
    "si <b>roleToSend==&#39;walker&#39;</b>, force role=walker cote app "
    "meme si backend renvoie sitter.", body))
story.append(Paragraph(
    "<i>Limitation</i> : le doc Sitter reste orphan en BDD. "
    "L&#39;utilisateur devrait utiliser un email neuf, OU on ajoutera un "
    "endpoint de migration dans une version future.", small))

story.append(Paragraph("2. Delete account Walker (2 fixes backend)", h2))
story.append(Paragraph(
    "<b>Bug</b> : Walker → Supprimer compte → 404 User not found.", body))
story.append(Paragraph(
    "<b>Fix 1</b> (userController.js:deleteAccount) : cherche dans Walker "
    "apres Owner/Sitter. Skip cleanup Conversation/Booking/Application "
    "(pas de walkerId dedie).", body))
story.append(Paragraph(
    "<b>Fix 2</b> (userController.js:deleteAccountFromToken) : Model = "
    "Walker si role=walker (l&#39;ancien ternaire fallback sur Owner).",
    body))

story.append(Paragraph("3. Cache GetX persistant apres logout", h2))
story.append(Paragraph(
    "<b>Bug</b> : logout Daniel C (Owner) puis login Aeps Pieces (Walker) "
    "affichait le nom+email de Daniel C sur le profil Walker (accueil "
    "affichait le bon nom).", body))
story.append(Paragraph(
    "<b>Fix</b> (auth_controller.dart:logout) : force-delete de "
    "<b>ProfileController, UserController, SitterProfileController, "
    "HomeController, PostsController</b> au logout. Les controllers se "
    "reinitialisent avec les nouvelles donnees au prochain login.", body))

story.append(Paragraph("4. Onglet Promeneurs live (home Owner)", h2))
story.append(Paragraph(
    "L&#39;onglet etait un placeholder statique. Maintenant : liste "
    "reactive des walkers proches, slider distance partage avec sitters, "
    "WalkerCard (avatar, rating, ville, distance, tarif 60 min, CTA "
    "Demander). Backend <b>GET /walkers</b> existait deja, juste cable "
    "cote frontend.", body))
story.append(Paragraph(
    "Nouveaux fichiers : <b>lib/views/pet_owner/home/widgets/walker_card.dart</b>, "
    "methodes dans <b>home_controller.dart</b> + <b>walker_repository.dart</b>.",
    small))

story.append(Paragraph("5. Tarif horaire Sitter retire", h2))
story.append(Paragraph(
    "Sitters garde minimum 1 jour, donc le champ Tarif horaire ne sert "
    "plus dans Modifier profil. UI retiree (<b>edit_sitter_profile_screen.dart</b>) "
    "et payload backend pousse <b>hourlyRate: null</b> pour ne pas ecraser "
    "les anciennes valeurs.", body))

story.append(Paragraph("6. Publier demande — geoloc cablee", h2))
story.append(Paragraph(
    "L&#39;ecran <b>publish_reservation_request_screen.dart</b> avait un "
    "champ ville brut sans bouton GPS/Carte et 2 cles de traduction non "
    "definies. Remplace par <b>CityLocationPicker</b> (meme widget que "
    "les ecrans EditProfile). Plus de cles manquantes, boutons Auto + "
    "Carte fonctionnels.", body))

story.append(Paragraph("7. PawMap — 4 fixes majeurs", h2))
story.append(Paragraph(
    "<b>a)</b> Erreur GetX &quot;improper use&quot; : "
    "<b>.toSet()</b> sur <b>enabledCategories</b> ligne 656 de "
    "paw_map_screen.dart pour forcer l&#39;abonnement Obx.<br/>"
    "<b>b)</b> Radius POIs : <b>5 km → 50 km</b> "
    "(paw_map_controller.dart, max backend).<br/>"
    "<b>c)</b> Traductions i18n : <b>PoiCategories.label(c)</b> via .tr, "
    "13 nouvelles cles dans les 6 fichiers de traduction "
    "(poi_vet, poi_shop, poi_park ... + map_emergency_*).<br/>"
    "<b>d)</b> Debounce <b>500 ms</b> sur onCameraIdle pour eviter le "
    "spam quand on pan/zoom vite.", body))

story.append(Paragraph("8. Seed OSM Europe", h2))
story.append(Paragraph(
    "Nouveau script <b>backend/src/scripts/seedOsmEurope.js</b> qui "
    "peuple la collection MapPOI en interrogeant <b>Overpass API</b> "
    "(OpenStreetMap, gratuit).", body))
story.append(Paragraph(
    "Categories importees : <b>vet</b> (amenity=veterinary), <b>shop</b> "
    "(shop=pet), <b>park</b> (leisure=dog_park). <br/>"
    "Pays couverts : FR, BE, CH, LU, DE, IT, ES, PT, NL, AT, GB. <br/>"
    "Retry auto 504/502/429, idempotent via osmId, User-Agent require "
    "pour eviter 406 Not Acceptable.", body))

story.append(PageBreak())

# ===== COMMANDES =====
story.append(Paragraph("Commandes utiles", h1))

story.append(Paragraph("Build APK debug + copie Downloads", h2))
story.append(Paragraph(
    "cd C:\\Users\\Usuario\\Downloads\\HopeTSIT_FINAL_FIXED\\HopeTSIT_FINAL\\frontend<br/>"
    "flutter build apk --debug &amp;&amp; copy build\\app\\outputs\\flutter-apk\\app-debug.apk C:\\Users\\Usuario\\Downloads\\HopeTSIT_v15.apk",
    mono))

story.append(Paragraph("Analyse statique", h2))
story.append(Paragraph("flutter analyze", mono))

story.append(Paragraph("Backup complet", h2))
story.append(Paragraph(
    "cd C:\\Users\\Usuario\\Downloads<br/>"
    "xcopy /E /I /H HopeTSIT_FINAL_FIXED HopeTSIT_BACKUP_v15",
    mono))

story.append(Paragraph("Push backend sur Render", h2))
story.append(Paragraph(
    "cd C:\\Users\\Usuario\\Downloads\\HopeTSIT_FINAL_FIXED\\HopeTSIT_FINAL<br/>"
    "git add backend/<br/>"
    "git commit -m &quot;Backend: description&quot;<br/>"
    "git push origin main",
    mono))

story.append(Paragraph("Seed OSM (Render Shell ou local)", h2))
story.append(Paragraph(
    "node src/scripts/seedOsmEurope.js --country ES --dry-run  # test<br/>"
    "node src/scripts/seedOsmEurope.js --country ES            # Spain<br/>"
    "node src/scripts/seedOsmEurope.js                         # tout<br/>"
    "# ~2-3 min par pays, rate-limit 5s entre queries Overpass.",
    mono))

story.append(Paragraph("Installer APK sur telephone (USB + debogage)", h2))
story.append(Paragraph(
    "adb install -r C:\\Users\\Usuario\\Downloads\\HopeTSIT_v15.apk",
    mono))

story.append(Paragraph("Logs de debug [FEED DEBUG]", h2))
story.append(Paragraph(
    "adb logcat -c<br/>"
    "adb logcat | findstr &quot;FEED DEBUG&quot;",
    mono))

story.append(PageBreak())

# ===== RESTE A FAIRE =====
story.append(Paragraph("Ce qui reste à faire", h1))

remaining = [
    ["P", "Tâche", "Où"],
    ["P0", "Feed Walker/Sitter: afficher les publications Owner",
     "PostsController + sitter_homescreen.dart"],
    ["P1", "Finir seed OSM pour les 10 autres pays",
     "Render Shell: node src/scripts/seedOsmEurope.js --country XX"],
    ["P1", "Vérifier upload avatar Walker",
     "Peut ignorer le walker doc (route /users/me/profile-picture)"],
    ["P1", "Cleanup BDD au delete Walker (Convos, Bookings orphelines)",
     "userController.js:deleteAccount"],
    ["P2", "Nettoyer les debugPrint [FEED DEBUG] une fois feed OK",
     "posts_controller.dart"],
    ["P2", "Endpoint backend de migration role (owner/sitter → walker)",
     "authController.js ou nouveau route /users/me/migrate-role"],
    ["P3", "Multi-durees tarifs Walker (30/45/60/90 min)",
     "EditWalkerProfileScreen"],
    ["P3", "Bbox search au lieu de radius pour gros zooms",
     "paw_map_controller.dart + backend query"],
]
t = Table(remaining, colWidths=[1.2*cm, 9*cm, 6.8*cm])
t.setStyle(TableStyle([
    ('BACKGROUND', (0,0), (-1,0), colors.HexColor('#C62828')),
    ('TEXTCOLOR', (0,0), (-1,0), colors.white),
    ('FONTNAME', (0,0), (-1,0), 'Helvetica-Bold'),
    ('FONTSIZE', (0,0), (-1,-1), 8),
    ('GRID', (0,0), (-1,-1), 0.4, colors.grey),
    ('VALIGN', (0,0), (-1,-1), 'TOP'),
    ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, colors.HexColor('#FFEBEE')]),
]))
story.append(t)

story.append(Paragraph("Bug P0 — feed Walker/Sitter", h2))
story.append(Paragraph(
    "<b>Plan du v12 (non applique):</b><br/>"
    "1. Rebrancher PostsController.loadPostsWithoutMedia() sur "
    "<b>GET /posts/requests</b> avec <b>requiresAuth: true</b><br/>"
    "2. Remplacer combinedPosts par reservationRequests dans "
    "sitter_homescreen.dart (ligne 476) et dans le filtre Walker/Sitter<br/>"
    "3. Verifier que le backend filtre bien par role dans getRequestPosts "
    "(lignes 272-303 de postController.js)", body))

story.append(PageBreak())

# ===== REGLES =====
story.append(Paragraph("Règles critiques (à respecter absolument)", h1))

rules = [
    ("JAMAIS de regex automatique multi-fichiers",
     "Les regex trop agressives ont cassé 377 fichiers en début de session. "
     "Toujours Edit tool ciblé, une modif à la fois."),
    ("TOUJOURS flutter analyze avant build",
     "Détection immédiate. Un analyze foiré vaut mieux qu'un build foiré."),
    ("NE PAS toucher à la création côté Owner",
     "Elle marche. Le bug du feed est côté lecture, pas écriture."),
    ("Backend Render à jour",
     "Tous les fix walker (signup, edit, delete, referrals, seed) sont "
     "déployés. Vérifier git log avant de penser qu'un endpoint manque."),
    ("Backup avant grosse modif",
     "xcopy /E /I /H HopeTSIT_FINAL_FIXED HopeTSIT_BACKUP_vXX. "
     "Sauvé la session au moins 3 fois."),
    ("Valider AVANT de coder",
     "Diagnostic → options → OK user → application → analyze → test. "
     "Ne pas inventer des fix sur base d'hypothèses."),
    ("Tester chaque fix avant d'enchaîner",
     "Build APK + test sur téléphone. Les bugs visibles (snackbar, "
     "message à l'écran) sont plus rapides à diagnostiquer que le code."),
]
for title_rule, desc in rules:
    story.append(Paragraph(f"• <b>{title_rule}</b>", body))
    story.append(Paragraph(f"  {desc}", small))
    story.append(Spacer(1, 4))

story.append(Spacer(1, 20))
story.append(Paragraph(
    "Fin du recap v15. Les 3 profils fonctionnent et PawMap est "
    "largement amelioree. Prochain chantier: feed Walker/Sitter (P0).", small))


# ===== SESSION v15 — FIN (polish + admin) =====
story.append(PageBreak())
story.append(Paragraph("Session v15 — polish final + Admin Tarifs", h1))
story.append(Spacer(1, 6))

extras = [
    ("Selecteur de langue (signup + login)",
     "StatefulBuilder dans le dialog pour que la coche verte suive le tap. "
     "Delai 250ms pour la confirmation visuelle. Appliqué dans sign_up_screen "
     "et login_screen."),
    ("Banner 'Passer Premium' PawMap",
     "Ouvre maintenant CoinShopScreen(initialTab: 1) directement sur l'onglet "
     "Premium (avant: atterrissait sur Boost). "
     "Nouveau parametre initialTab (retrocompatible)."),
    ("Descriptif 'Ce que Premium debloque'",
     "Passe de 7 a 6 lignes. 'PawMap complete' retiree (les POIs sont "
     "gratuits). Signalements en tete: '18 types d'alertes temps reel — "
     "dont 7 signalements Premium exclusifs'. Split en 2 lignes pour bien "
     "les valoriser."),
    ("Signalement 'Animal mort' gratuit",
     "deadAnimal ajoute dans ReportTypes.freeTypes. Passe de 3 a 4 gratuits. "
     "Emoji 🪦, couleur gris fonce deja definis."),
    ("Cards Map Boost alignees sur Boost",
     "Prix a droite en rouge, badge 'Meilleure visibilite' sur gold, "
     "fleche > sur la droite, spinner pendant l'achat, prix/jour en petit. "
     "Meme pattern visuel que l'onglet Boost."),
    ("Section 'Comment fonctionne Map Boost ?' refaite",
     "Nouvelles icones distinctes: pin, oeil, courbe stats, recyclage. "
     "Textes raccourcis pour plus de clarte."),
    ("Admin Dashboard — onglet Tarifs (nouveau)",
     "5eme onglet admin_dashboard_screen.dart. Lit GET /admin/pricing, edite "
     "Boost/MapBoost/Premium par devise (EUR/GBP/CHF/USD), sauvegarde PATCH, "
     "bouton Reset avec confirmation. ~200 lignes UI."),
]

for title_rule, desc in extras:
    story.append(Paragraph("• <b>" + title_rule + "</b>", body))
    story.append(Paragraph("  " + desc, small))
    story.append(Spacer(1, 4))

story.append(Spacer(1, 10))
story.append(Paragraph(
    "<b>Backend inchange cette session</b> (seul le script de seed OSM "
    "tourne cote Render, pas de nouveau code backend). Tous les endpoints "
    "utilises par l'admin existaient deja (/admin/pricing, GET+PATCH+reset).",
    small))

story.append(Spacer(1, 12))
story.append(Paragraph("APK: rebuild apres toutes ces modifs", h2))
story.append(Paragraph(
    "cd C:\\Users\\Usuario\\Downloads\\HopeTSIT_FINAL_FIXED\\HopeTSIT_FINAL\\frontend<br/>"
    "flutter analyze  # doit rester a 0<br/>"
    "flutter build apk --debug &amp;&amp; copy build\\app\\outputs\\flutter-apk\\app-debug.apk C:\\Users\\Usuario\\Downloads\\HopeTSIT_v15.apk",
    mono))


# ===== SESSION v15-2 — Suite (switch refresh + total + cards + admin) =====
story.append(PageBreak())
story.append(Paragraph("Session v15-2 — switch refresh, total estime, cards refondues", h1))
story.append(Spacer(1, 6))

extras2 = [
    ("Selecteur de langue signup + login",
     "StatefulBuilder dans le dialog: la coche verte suit le tap avec un "
     "delai 250ms. Fixe aussi dans login_screen.dart."),
    ("Banner 'Passer Premium' PawMap ouvre onglet Premium",
     "CoinShopScreen({initialTab: 1}) au lieu du default 0 (Boost). "
     "Parametre retrocompatible."),
    ("Descriptif 'Ce que Premium debloque' refait",
     "6 lignes au lieu de 7. 'PawMap complete' retiree (POIs gratuits). "
     "Signalements en tete: '18 types d'alertes temps reel - dont 7 "
     "Premium exclusifs'. Animal mort (deadAnimal) passe en gratuit."),
    ("Map Boost cards refondues (copier Boost)",
     "Prix a droite en rouge, badge 'Meilleure visibilite' sur gold, "
     "fleche, spinner pendant l'achat, prix/jour en petit."),
    ("'Comment fonctionne Map Boost ?' icones refaites",
     "pin, oeil, stats, recyclage - plus lisibles que les 4 icones rouges "
     "identiques d'avant."),
    ("Admin Dashboard - 5e onglet Tarifs",
     "admin_dashboard_screen.dart. GET+PATCH+reset /admin/pricing. "
     "Edite Boost + Map Boost + Premium par devise (EUR/GBP/CHF/USD). "
     "Bouton Enregistrer + Reset (confirmation)."),
    ("Fix switch de role - profil qui suit",
     "auth_controller.dart:_refreshDataAfterRoleSwitch() force-delete 5 "
     "controllers (UserController, ProfileController, "
     "SitterProfileController, HomeController, PostsController). Evite "
     "le probleme du profil qui restait vide apres retour en Owner."),
    ("Fix publication - annonce visible immediatement",
     "publish_reservation_request_controller.dart: apres succes API, "
     "appelle _refreshFeedsAfterPublish() qui refresh PostsController + "
     "HomeController. Plus besoin de logout/relog."),
    ("Backend - choose-service accepte tous les services",
     "authController.js:1279 + userController.js:168 - allowedServices = "
     "SITTER_SERVICES (inclut Dog Walking) pour les 3 roles. Owner peut "
     "maintenant cocher Pet Sitting + House Sitting + Dog Walking."),
    ("Walker profile - tarif 30 min ajoute",
     "edit_walker_profile_screen + controller: 2 champs tarif (30 min + "
     "60 min). Sauve 2 WalkRates distincts en une requete."),
    ("Cards home Owner refondues",
     "WalkerCard: 2 pills (30min/1h) + estimation '1 balade 1h' + 'Tarif a "
     "confirmer' + bouton Demander pleine largeur. SitterCard: tarif "
     "horaire retire, seuls jour/semaine/mois restent + total estime."),
    ("SendRequestScreen - section Total estime",
     "Nouveaux params optionnels: sitterDailyRate, walkerHalfHourRate, "
     "walkerHourlyRate, currencyCode. Section gradient rouge avec "
     "calcul live: 'X jours x 40 EUR = 120 EUR' ou '1 balade 30 min x "
     "8 EUR'. Cards passent leurs tarifs."),
]

for title_rule, desc in extras2:
    story.append(Paragraph("* <b>" + title_rule + "</b>", body))
    story.append(Paragraph("  " + desc, small))
    story.append(Spacer(1, 4))

story.append(Spacer(1, 12))
story.append(Paragraph("Backend a pusher avant test complet:", h2))
story.append(Paragraph(
    "cd C:\\Users\\Usuario\\Downloads\\HopeTSIT_FINAL_FIXED\\HopeTSIT_FINAL<br/>"
    "git add backend/src/controllers/authController.js backend/src/controllers/userController.js<br/>"
    "git commit -m &quot;Backend v15-2: choose-service accepts all services, "
    "delete walker fixes&quot;<br/>"
    "git push origin main",
    mono))

story.append(Spacer(1, 10))
story.append(Paragraph(
    "<b>Bugs restants (P0):</b> le feed Walker/Sitter n'affiche toujours pas "
    "les publications Owner. Diagnostic en place via debugPrint [FEED DEBUG]. "
    "Fix pressenti: rebrancher PostsController sur /posts/requests avec "
    "requiresAuth: true.",
    small))

doc.build(story)
print("Generated " + OUT)

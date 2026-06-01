"""
HopeTSIT iOS Build Guide v23.1.196 generator.
Creates a comprehensive PDF guide for building the iOS app from the
current codebase, including all features delivered up to v196.
"""
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak,
)
from reportlab.lib.enums import TA_LEFT, TA_JUSTIFY

OUT = "C:/Users/Usuario/Downloads/HopeTSIT_iOS_Build_Guide_v23.1.197.pdf"

doc = SimpleDocTemplate(
    OUT, pagesize=A4,
    leftMargin=1.8*cm, rightMargin=1.8*cm,
    topMargin=1.8*cm, bottomMargin=1.8*cm,
    title="HopeTSIT iOS Build Guide v23.1.196",
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
                     fontSize=9, leading=12, leftIndent=12,
                     textColor=colors.HexColor("#92400E"),
                     backColor=colors.HexColor("#FEF3C7"))

story = []

# ── Cover ────────────────────────────────────────────────────────────────
story.append(Paragraph("HopeTSIT iOS Build Guide", H1))
story.append(Paragraph("Version 23.1.197 - May 22 2026", H2))
story.append(Spacer(1, 0.4*cm))
story.append(Paragraph(
    "Guide complet pour builder l'app HopeTSIT sur iOS depuis le repo "
    "actuel. Couvre l'installation des dependances, la configuration "
    "Xcode + Apple Developer, les changements v23.1.146 → v23.1.196, "
    "et le checklist final avant submission App Store.",
    P))
story.append(Spacer(1, 0.6*cm))

# ── What's new since v146 ────────────────────────────────────────────────
story.append(Paragraph("1. Nouveautes depuis v146", H2))
story.append(Paragraph(
    "50+ versions cumulees. Highlights par lot :", P))

changes = [
    ("v167-v170", "Bug fixes critiques chat post-paiement walker + suivi"
                  " animal en chat / hors mission."),
    ("v172-v175", "PawFollow Famille (5 membres) + cadre Boost sur "
                  "profil owner + traductions facture toutes langues."),
    ("v176-v179", "Ruban URGENT sur posts boostes + carte chat "
                  "pawfollow_request avec boutons Accept/Refuse + "
                  "5 membres famille (etait 4)."),
    ("v180-v183", "Notifications real-time socket + 30 templates "
                  "i18n + inline Accept/Refuse dans la cloche + "
                  "Friends/Family management UI."),
    ("v184-v187", "Refonte PawMap (4 quick-action cards), Famille & "
                  "Amis 5 tabs, Alertes screen, Signaler grid free/"
                  "premium, Autour de vous card."),
    ("v188-v190", "Card pawfollow_request style mockup, polish PawMap "
                  "(grid, close button, search city, modernize "
                  "buttons), Accident tab removed, emoji map markers."),
    ("v191-v194", "Friend request auto-accept (mutual), bouton "
                  "Effacer message TRES visible, TrackingRequestSheet "
                  "refonte mockup (Detail garde + infos pratiques)."),
    ("v195-v196", "Banner Demandes EN attente toujours visible, "
                  "Effacer conversation entiere, PawFollow Famille "
                  "debloque le chat membres, bouton Effacer VISIBLE "
                  "sur chaque conversation."),
    ("v197", "Sheet 'Detail de la garde' : rows Telephone + Adresse "
             "TOUJOURS visibles (avec placeholder '--' si vide). Avant "
             "elles disparaissaient quand le sitter n'avait pas "
             "renseigne ses coordonnees → Daniel pensait que rien "
             "n'avait ete refait. Maintenant le sheet ressemble "
             "exactement au mockup peu importe les donnees backend."),
]
data = [["Version", "Changement"]] + changes
t = Table(data, colWidths=[3*cm, 13*cm])
t.setStyle(TableStyle([
    ('BACKGROUND', (0,0), (-1,0), colors.HexColor("#EF4324")),
    ('TEXTCOLOR', (0,0), (-1,0), colors.white),
    ('FONTNAME', (0,0), (-1,0), 'Helvetica-Bold'),
    ('FONTSIZE', (0,0), (-1,0), 10),
    ('FONTSIZE', (0,1), (-1,-1), 9),
    ('VALIGN', (0,0), (-1,-1), 'TOP'),
    ('GRID', (0,0), (-1,-1), 0.4, colors.HexColor("#E5E7EB")),
    ('LEFTPADDING', (0,0), (-1,-1), 6),
    ('RIGHTPADDING', (0,0), (-1,-1), 6),
    ('TOPPADDING', (0,0), (-1,-1), 5),
    ('BOTTOMPADDING', (0,0), (-1,-1), 5),
]))
story.append(t)
story.append(PageBreak())

# ── Prerequisites ────────────────────────────────────────────────────────
story.append(Paragraph("2. Prerequis", H2))
prereqs = [
    "Mac avec macOS 14 (Sonoma) ou plus recent",
    "Xcode 15.4+ (depuis l'App Store ou Apple Developer)",
    "Flutter 3.24+ (flutter doctor doit etre vert)",
    "Apple Developer Account actif (apple.com/programs)",
    "CocoaPods 1.15+ (sudo gem install cocoapods)",
    "Acces au repo Git github.com/hopetsit/hopetsit",
]
for x in prereqs:
    story.append(Paragraph(f"&bull; {x}", P))
story.append(Spacer(1, 0.4*cm))

# ── Clone & install ──────────────────────────────────────────────────────
story.append(Paragraph("3. Clone & dependances", H2))
story.append(Paragraph(
    "Depuis un terminal sur le Mac :", P))
story.append(Spacer(1, 0.2*cm))
cmds = """git clone https://github.com/hopetsit/hopetsit.git HopeTSIT
cd HopeTSIT/frontend
flutter pub get
cd ios
pod install
cd ..
flutter doctor"""
for line in cmds.split("\n"):
    story.append(Paragraph(line, CODE))
story.append(Spacer(1, 0.3*cm))
story.append(Paragraph(
    "Si <b>pod install</b> echoue : <i>sudo gem install cocoapods --version 1.15.2</i> "
    "et <i>arch -x86_64 pod install</i> sur Apple Silicon en cas de conflit.", NOTE))
story.append(Spacer(1, 0.4*cm))

# ── Bundle ID + signing ──────────────────────────────────────────────────
story.append(Paragraph("4. Bundle ID & signing Xcode", H2))
story.append(Paragraph(
    "Ouvrir <b>ios/Runner.xcworkspace</b> dans Xcode (pas le .xcodeproj).", P))
story.append(Spacer(1, 0.2*cm))
signing = [
    ("Bundle ID", "com.hopetsit.app (verifier dans Signing & Capabilities)"),
    ("Team", "Selectionner ton Apple Developer Team"),
    ("Signing", "Cocher Automatically manage signing"),
    ("Version", "23.1.196 (string), build 196 (number)"),
    ("Display name", "HopeTSIT"),
]
data2 = [["Champ", "Valeur"]] + signing
t2 = Table(data2, colWidths=[4.5*cm, 11.5*cm])
t2.setStyle(TableStyle([
    ('BACKGROUND', (0,0), (-1,0), colors.HexColor("#1F2937")),
    ('TEXTCOLOR', (0,0), (-1,0), colors.white),
    ('FONTNAME', (0,0), (-1,0), 'Helvetica-Bold'),
    ('FONTSIZE', (0,0), (-1,0), 10),
    ('FONTSIZE', (0,1), (-1,-1), 9),
    ('VALIGN', (0,0), (-1,-1), 'TOP'),
    ('GRID', (0,0), (-1,-1), 0.4, colors.HexColor("#E5E7EB")),
    ('LEFTPADDING', (0,0), (-1,-1), 6),
    ('TOPPADDING', (0,0), (-1,-1), 5),
    ('BOTTOMPADDING', (0,0), (-1,-1), 5),
]))
story.append(t2)
story.append(Spacer(1, 0.4*cm))

# ── Capabilities ─────────────────────────────────────────────────────────
story.append(Paragraph("5. Capabilities a activer", H2))
caps = [
    "Push Notifications (pour FCM + notification.new)",
    "Background Modes : Remote notifications, Background fetch, "
    "Location updates (suivi live PawFollow)",
    "Sign in with Apple (login Apple ID)",
    "Maps (Google Maps + PawMap)",
    "Associated Domains : applinks:hopetsit.com (deep links email)",
]
for c in caps:
    story.append(Paragraph(f"&bull; {c}", P))
story.append(Spacer(1, 0.4*cm))

# ── Info.plist keys ──────────────────────────────────────────────────────
story.append(Paragraph("6. Info.plist - cles requises", H2))
plist_keys = [
    ("NSLocationWhenInUseUsageDescription",
     "HopeTSIT a besoin de votre position pour vous montrer les "
     "parcs, veterinaires et amis proches sur la PawMap."),
    ("NSLocationAlwaysAndWhenInUseUsageDescription",
     "Le partage live de votre balade necessite l'acces a la "
     "position en arriere-plan."),
    ("NSCameraUsageDescription",
     "Photo de profil + signalements PawMap (chien perdu, danger)."),
    ("NSPhotoLibraryUsageDescription",
     "Selection de photos pour le profil et les annonces."),
    ("NSContactsUsageDescription",
     "Inviter des amis depuis votre carnet d'adresses."),
    ("FirebaseAppDelegateProxyEnabled",
     "NO (on gere manuellement les notifs FCM)"),
    ("UIBackgroundModes",
     "remote-notification, fetch, location"),
]
for k, v in plist_keys:
    story.append(Paragraph(f"<b>{k}</b>", P))
    story.append(Paragraph(v, P))
    story.append(Spacer(1, 0.1*cm))
story.append(PageBreak())

# ── Firebase setup ───────────────────────────────────────────────────────
story.append(Paragraph("7. Firebase iOS setup", H2))
fb_steps = [
    "Connexion sur console.firebase.google.com",
    "Selectionner le projet hopetsit-prod",
    "Telecharger GoogleService-Info.plist",
    "Placer dans ios/Runner/ (PAS dans ios/Runner/Assets)",
    "Verifier dans Xcode que le fichier est bien ajoute a la cible Runner",
    "APNs Auth Key : configurer dans Firebase > Project Settings > "
    "Cloud Messaging > Apple app configuration",
]
for i, step in enumerate(fb_steps, 1):
    story.append(Paragraph(f"{i}. {step}", P))
story.append(Spacer(1, 0.4*cm))

# ── Env vars ─────────────────────────────────────────────────────────────
story.append(Paragraph("8. Variables d'environnement (frontend/.env)", H2))
story.append(Paragraph(
    "Le fichier <b>frontend/.env</b> doit contenir :", P))
env_lines = """API_BASE_URL=https://api.hopetsit.com/api/v1
SOCKET_URL=https://api.hopetsit.com
GOOGLE_MAPS_API_KEY=<ta_cle_google_maps_ios>
SENTRY_DSN=<ton_dsn_sentry>
AIRWALLEX_ENV=production"""
for line in env_lines.split("\n"):
    story.append(Paragraph(line, CODE))
story.append(Spacer(1, 0.4*cm))

# ── Build & archive ──────────────────────────────────────────────────────
story.append(Paragraph("9. Build, archive & TestFlight", H2))
build_cmds = """cd frontend
flutter build ios --release
open ios/Runner.xcworkspace"""
for line in build_cmds.split("\n"):
    story.append(Paragraph(line, CODE))
story.append(Spacer(1, 0.2*cm))
story.append(Paragraph(
    "Dans Xcode :", P))
xcode_steps = [
    "Product > Destination : Any iOS Device (arm64)",
    "Product > Archive (attendre ~5-10 min)",
    "Organizer s'ouvre : Distribute App > App Store Connect > Upload",
    "Choisir l'option Automatic signing > Next > Upload",
    "Attendre 30-60 min que TestFlight processe le build",
    "Aller sur App Store Connect > TestFlight > Inviter testeurs internes",
]
for s in xcode_steps:
    story.append(Paragraph(f"&bull; {s}", P))
story.append(Spacer(1, 0.4*cm))

# ── Post-install checklist ───────────────────────────────────────────────
story.append(Paragraph("10. Checklist test post-install (v196)", H2))
checklist = [
    "PawMap : 4 quick-action cards meme hauteur + sub-text lisible",
    "PawMap : carte 'Autour de vous' fermable (bouton X)",
    "PawMap : emoji markers compact (~36px, comparable aux pins natifs)",
    "PawMap : recherche ville depuis loupe AppBar",
    "PawMap : PawFollow + PawSpot pins glassy (fond blanc + halo couleur)",
    "Famille & Amis : 5 tabs (Mes amis / Ajouter / Live / Animaux / Messages)",
    "Famille & Amis : banner orange 'Demandes en attente' visible en haut",
    "Cloche notifs : boutons Accepter/Refuser inline pour friend_request_received",
    "Chat list : bouton 'Effacer' rouge visible sur chaque conversation",
    "Chat conversation : bouton 'Effacer' rouge visible sur chaque message envoye",
    "Chat AppBar : tap Suivre en direct mon animal → ouvre 'Detail de la garde'",
    "Sheet 'Detail de la garde' : pet card + panel Suivi + 3 rows infos + trust",
    "Alertes : 4 tabs (Tous / Perdus / Danger / Autres) - PAS Accident",
    "Signaler : 4 cards Gratuit en haut + 12 cards Premium avec etoile en bas",
    "Profile owner : ruban URGENT sur ses propres posts (Premium/PawFollow active)",
    "Backend : POST /friends/request auto-accepte si l'autre a deja une demande pending",
    "Backend : PawFollow Famille debloque le chat entre membres actifs",
    "Backend : DELETE /conversations/:id supprime conv + messages",
]
for x in checklist:
    story.append(Paragraph(f"&#9633; {x}", P))
story.append(Spacer(1, 0.4*cm))

# ── Known bugs / TODO ────────────────────────────────────────────────────
story.append(Paragraph("11. Known bugs & TODO post-v196", H2))
todos = [
    ("Pawfollow_request card rendering", "Verifier que le message "
     "type='pawfollow_request' s'affiche bien comme une card avec "
     "Accepter/Refuser apres envoi (et non comme texte brut). "
     "Verifier ChatController parsing de 'type' + 'metadata'."),
    ("URGENT ribbon walker side", "Quand walker voit l'annonce d'un "
     "owner Premium, le ruban URGENT devrait apparaitre (regression "
     "v179 fix possible). A reverifier dans pet_post_card.dart."),
    ("Audit boutons map", "Daniel demande un audit complet de "
     "chaque bouton dans PawMap : geoloc, zoom +/-, search city, "
     "X close around-you, 4 quick-action cards, filter chips, "
     "FAB Signaler, layer toggle, marker tap, PawFollow/PawSpot "
     "pins. Tester chacun et confirmer le comportement."),
    ("Friend search par nom", "Endpoint /friends/search?q= : verifier "
     "que le fuzzy match marche bien sur nom + email + accents."),
    ("Notification FCM tokens stales", "Investiguer pourquoi witoulek "
     "ne recoit pas les push notifs (token desactive, app desinstallee). "
     "Backend purge dead tokens deja en place (v50)."),
]
for title, desc in todos:
    story.append(Paragraph(f"<b>{title}</b>", P))
    story.append(Paragraph(desc, P))
    story.append(Spacer(1, 0.15*cm))

story.append(Spacer(1, 0.5*cm))
story.append(Paragraph(
    "<i>Document genere le 22 mai 2026 - v23.1.197 (commit ade2dfa)</i>",
    P))

doc.build(story)
print(f"PDF cree : {OUT}")

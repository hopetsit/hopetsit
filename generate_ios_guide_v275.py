"""HopeTSIT iOS Build Guide v23.1.275 generator."""
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, PageBreak
from reportlab.lib.enums import TA_JUSTIFY

OUT = "C:/Users/Usuario/Downloads/HopeTSIT_iOS_Build_Guide_v23.1.275.pdf"
doc = SimpleDocTemplate(OUT, pagesize=A4, leftMargin=1.8*cm, rightMargin=1.8*cm,
    topMargin=1.8*cm, bottomMargin=1.8*cm, title="HopeTSIT iOS Build Guide v23.1.275", author="HopeTSIT team")
styles = getSampleStyleSheet()
H1 = ParagraphStyle('H1', parent=styles['Heading1'], fontSize=22, textColor=colors.HexColor("#EF4324"), spaceAfter=14, leading=26)
H2 = ParagraphStyle('H2', parent=styles['Heading2'], fontSize=15, textColor=colors.HexColor("#1F2937"), spaceAfter=10, spaceBefore=14, leading=18)
P = ParagraphStyle('P', parent=styles['BodyText'], fontSize=10, leading=14, alignment=TA_JUSTIFY)
CODE = ParagraphStyle('CODE', parent=styles['Code'], fontSize=9, leading=12, leftIndent=12, textColor=colors.HexColor("#0F172A"), backColor=colors.HexColor("#F1F5F9"))
INFO = ParagraphStyle('INFO', parent=styles['BodyText'], fontSize=9, leading=13, leftIndent=12, rightIndent=12, textColor=colors.HexColor("#075985"), backColor=colors.HexColor("#E0F2FE"), borderColor=colors.HexColor("#0EA5E9"), borderWidth=1, borderPadding=8)
GREEN = ParagraphStyle('GREEN', parent=styles['BodyText'], fontSize=10, leading=14, leftIndent=12, rightIndent=12, textColor=colors.HexColor("#065F46"), backColor=colors.HexColor("#D1FAE5"), borderColor=colors.HexColor("#10B981"), borderWidth=1, borderPadding=8)
VIOLET = ParagraphStyle('VIOLET', parent=styles['BodyText'], fontSize=10, leading=14, leftIndent=12, rightIndent=12, textColor=colors.HexColor("#5B21B6"), backColor=colors.HexColor("#EDE9FE"), borderColor=colors.HexColor("#8B5CF6"), borderWidth=1, borderPadding=8)

flow = []
flow.append(Paragraph("HopeTSIT — iOS Build Guide", H1))
flow.append(Paragraph("Version 23.1.275 (Build 275)", H2))
flow.append(Spacer(1, 0.4*cm))
flow.append(Paragraph(
    "Delta v23.1.274 to v23.1.275 : nouveau code couleur du LOGO (4eme orteil "
    "de la patte en violet = famille), halo famille UNIFIE sur la PawMap (un "
    "seul halo violet au lieu de role+anneau), icone bug retiree de Mes amis, "
    "et onglet Famille passe au theme violet.", P))
flow.append(Spacer(1, 0.5*cm))
flow.append(Paragraph(
    "v23.1.275 — Frontend + assets (icones app regenerees Android + iOS) + "
    "logo web (Vercel auto-deploy). Aucune migration DB. APK universal.", GREEN))
flow.append(Paragraph(
    "IMPORTANT iOS : le LOGO de l'app a change (4eme orteil violet). Tout "
    "l'AppIcon.appiconset a deja ete regenere par flutter_launcher_icons et "
    "commite. Au prochain build Xcode, la nouvelle icone violet/famille est "
    "embarquee automatiquement — rien de manuel a faire cote icone.", VIOLET))
flow.append(PageBreak())

flow.append(Paragraph("Changelog v23.1.275", H1))

flow.append(Paragraph("1. Logo — code couleur des roles", H2))
flow.append(Paragraph(
    "La patte du logo a 4 orteils qui suivent desormais le code couleur de "
    "l'app : orteil 1 (gauche) ORANGE #EF4324 = owner ; orteil 2 BLEU #1A73E8 "
    "= sitter ; orteil 3 VERT #008000 = walker ; orteil 4 (droite) VIOLET "
    "#8B5CF6 = FAMILLE (avant : orange). Variantes dark mode en violet clair "
    "#A78BFA. Mis a jour partout : SVG sources android/apple/web, PNG rasters "
    "regeneres (sharp 1024px), Android mipmaps + foregrounds adaptatifs, iOS "
    "AppIcon set (18 tailles), et logo web (logo.svg + favicon.svg).", P))

flow.append(Paragraph("2. Halo famille unifie sur la PawMap", H2))
flow.append(Paragraph(
    "Daniel : 'si l'ami sitter/walker/owner passe a famille alors met un SEUL "
    "halo violet, pas la peine d'emettre 3 halos differents'. Avant : un "
    "membre famille avait 2 cercles empiles (halo de role vert/bleu/orange + "
    "anneau violet exterieur 80m). Maintenant : PRIORITE FAMILLE -> halo "
    "UNIQUE violet (#8B5CF6). Les non-famille gardent leur couleur de role "
    "(walker vert / sitter bleu / owner orange / ami argent).", P))
flow.append(Paragraph(
    "Tous les halos (violet famille ET vert/bleu/orange role) suivent la "
    "personne A LA TRACE pendant la promenade/garde : circleId stable + "
    "centre = position LIVE + recompute a chaque rebuild Obx (signature "
    "coords). Verifie : le halo se deplace a chaque map:friend-position recu.", INFO))

flow.append(Paragraph("3. Mes amis — icone bug retiree", H2))
flow.append(Paragraph(
    "Le bouton diagnostic (loupe bug) en haut a droite de l'ecran Mes amis "
    "servait au debug des demandes d'amis ; il est retire de la barre d'app. "
    "La methode controller.diagnose() reste dans le code si besoin futur.", P))

flow.append(Paragraph("4. Onglet Famille — theme violet", H2))
flow.append(Paragraph(
    "L'onglet Famille utilise desormais le violet famille (#8B5CF6) comme "
    "accent au lieu de la couleur du role : carte 'PawFollow Famille actif' "
    "(titre + compteur X/5 + anneau bouclier + fond violet clair), carte CTA "
    "'Souscris PawFollow Famille', et cartes d'invitation. Coherent avec le "
    "halo famille de la PawMap et le 4eme orteil violet du logo.", P))
flow.append(PageBreak())

flow.append(Paragraph("Build iOS — etapes Xcode", H1))
flow.append(Paragraph("Etape 1 — Pull v275", H2))
flow.append(Paragraph("git pull origin main<br/>cd frontend &amp;&amp; flutter clean &amp;&amp; flutter pub get<br/>cd ios &amp;&amp; pod install --repo-update", CODE))
flow.append(Paragraph("Etape 2 — Verifier la nouvelle icone", H2))
flow.append(Paragraph(
    "open ios/Runner.xcworkspace, selectionner Assets.xcassets > AppIcon : "
    "le 4eme orteil de la patte doit etre VIOLET (les 3 autres orange/bleu/"
    "vert inchanges). Si besoin, Product &gt; Clean Build Folder pour purger "
    "le cache d'icone du simulateur.", P))
flow.append(Paragraph("Etape 3 — Smoke test PawMap", H2))
flow.append(Paragraph(
    "Un membre de ma famille qui partage sa position -> UN SEUL halo violet "
    "(pas de double cercle). Un walker non-famille qui promene mon chien -> "
    "halo VERT qui suit a la trace. Sitter -> bleu, owner -> orange.", P))
flow.append(Paragraph("Etape 4 — Archive Xcode", H2))
flow.append(Paragraph("scheme Runner, Any iOS Device, Product &gt; Archive, Distribute App &gt; App Store Connect (TestFlight d'abord).", P))
flow.append(Spacer(1, 0.5*cm))
flow.append(Paragraph("Build Android : flutter build apk --release -> Downloads/HopeTSIT_v23.1.275.apk.", INFO))

doc.build(flow)
print(f"OK -> {OUT}")

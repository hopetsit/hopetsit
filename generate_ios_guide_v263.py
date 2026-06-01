"""HopeTSIT iOS Build Guide v23.1.263 generator.

v262 = fix signalements (types backend), icônes report recentrées, carte de
confirmation masquée sur anciennes résas, docs légaux sans mention IA.
v263 = PawMap : suivi live "à la trace" (caméra qui suit + tap = zoom max).
"""
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, PageBreak
from reportlab.lib.enums import TA_JUSTIFY

OUT = "C:/Users/Usuario/Downloads/HopeTSIT_iOS_Build_Guide_v23.1.263.pdf"
doc = SimpleDocTemplate(OUT, pagesize=A4, leftMargin=1.8*cm, rightMargin=1.8*cm,
    topMargin=1.8*cm, bottomMargin=1.8*cm, title="HopeTSIT iOS Build Guide v23.1.263", author="HopeTSIT team")
styles = getSampleStyleSheet()
H1 = ParagraphStyle('H1', parent=styles['Heading1'], fontSize=22, textColor=colors.HexColor("#EF4324"), spaceAfter=14, leading=26)
H2 = ParagraphStyle('H2', parent=styles['Heading2'], fontSize=15, textColor=colors.HexColor("#1F2937"), spaceAfter=10, spaceBefore=14, leading=18)
P = ParagraphStyle('P', parent=styles['BodyText'], fontSize=10, leading=14, alignment=TA_JUSTIFY)
CODE = ParagraphStyle('CODE', parent=styles['Code'], fontSize=9, leading=12, leftIndent=12, textColor=colors.HexColor("#0F172A"), backColor=colors.HexColor("#F1F5F9"))
INFO = ParagraphStyle('INFO', parent=styles['BodyText'], fontSize=9, leading=13, leftIndent=12, rightIndent=12, textColor=colors.HexColor("#075985"), backColor=colors.HexColor("#E0F2FE"), borderColor=colors.HexColor("#0EA5E9"), borderWidth=1, borderPadding=8)
GREEN = ParagraphStyle('GREEN', parent=styles['BodyText'], fontSize=10, leading=14, leftIndent=12, rightIndent=12, textColor=colors.HexColor("#065F46"), backColor=colors.HexColor("#D1FAE5"), borderColor=colors.HexColor("#10B981"), borderWidth=1, borderPadding=8)

flow = []
flow.append(Paragraph("HopeTSIT — iOS Build Guide", H1))
flow.append(Paragraph("Version 23.1.263 (Build 263)", H2))
flow.append(Spacer(1, 0.4*cm))
flow.append(Paragraph(
    "Cumul v23.1.261 to v23.1.263. Deux lots : v262 (signalements + icones + "
    "carte de confirmation + docs legaux) et v263 (suivi live PawMap).", P))
flow.append(Spacer(1, 0.5*cm))
flow.append(Paragraph(
    "Le fix des SIGNALEMENTS est backend (deja deploye sur Render). Tout le "
    "reste est frontend, livre dans cet APK / cette archive iOS. Aucune "
    "migration DB. APK universal.", GREEN))
flow.append(PageBreak())

flow.append(Paragraph("Changelog v23.1.262", H1))
flow.append(Paragraph("1. Signalements (backend)", H2))
flow.append(Paragraph(
    "MapReport REPORT_TYPES complete avec 7 types manquants (busy_traffic, "
    "fire_smoke, flood, fallen_tree, chemical, wildlife, no_dogs_zone). Avant, "
    "POST /map-reports renvoyait 400 'Invalid type' pour ces categories, d'ou "
    "'Envio imposible'. FREE_REPORT_TYPES aligne sur le frontend "
    "(aggressive_dog, hazard, water_active, dead_animal).", P))
flow.append(Paragraph("2. Icones report recentrees", H2))
flow.append(Paragraph(
    "report_category_grid : Positioned.fill + hauteur de label fixe (2 lignes "
    "reservees), toutes les icones alignees au meme niveau quelle que soit la "
    "longueur du label.", P))
flow.append(Paragraph("3. Carte de confirmation (anciennes resas)", H2))
flow.append(Paragraph(
    "ServiceConfirmationCard masquee quand confirmationStatus == 'none' "
    "(reservations legacy payees avant la feature). Plus de 'Service pas "
    "encore demarre' sur des services deja termines. Les nouvelles resas "
    "payees (awaiting_start) affichent la carte normalement.", P))
flow.append(Paragraph("4. Documents legaux", H2))
flow.append(Paragraph(
    "terms_of_service + privacy_policy : disclaimers 'redige par IA' retires "
    "(6 langues, en-tetes + textes). References Stripe to Airwallex corrigees "
    "dans la politique de confidentialite (coherence avec les CGU).", P))
flow.append(PageBreak())

flow.append(Paragraph("Changelog v23.1.263", H1))
flow.append(Paragraph("PawMap — suivi live a la trace", H2))
flow.append(Paragraph(
    "Daniel : 'le follow geolocalise mais ne suit pas a la trace'. Deux "
    "causes, toutes deux corrigees (frontend) :", P))
flow.append(Paragraph(
    "<b>a) Marker fige</b> : la cle du cache de markers "
    "(_getMarkersFromCache) n'incluait que friendPositions.LENGTH. Un ami qui "
    "se deplace (meme nombre) ne reinvalidait pas le cache, donc marker fige. "
    "On ajoute une signature des coordonnees (5 decimales ~ 1 m) : le marker "
    "bouge en temps reel a chaque event socket map:friend-position.", P))
flow.append(Paragraph(
    "<b>b) Camera fixe</b> : aucun mecanisme ne suivait l'ami. Ajout d'un mode "
    "SUIVI : worker ever(friendPositions) recentre la camera a chaque nouvelle "
    "position de l'ami suivi ; onTap sur le marker = zoom 18 + demarre le "
    "suivi ; ouverture depuis un chat (focusUserId) = suivi auto + zoom max ; "
    "banniere 'Suivi en direct - nom' + bouton Arreter ; drag manuel coupe le "
    "suivi (flag anti-faux-positif sur nos propres animations + zoom). 3 cles "
    "i18n x 6 langues.", P))
flow.append(Paragraph(
    "Prerequis test : l'autre personne doit PARTAGER sa position en live "
    "(bouton 'Suivre mon animal / ma balade'), sinon le serveur n'a aucune "
    "position a diffuser.", INFO))
flow.append(PageBreak())

flow.append(Paragraph("Build iOS — etapes Xcode", H1))
flow.append(Paragraph("Etape 1 — Pull v263", H2))
flow.append(Paragraph("git pull origin main<br/>cd frontend &amp;&amp; flutter clean &amp;&amp; flutter pub get<br/>cd ios &amp;&amp; pod install --repo-update", CODE))
flow.append(Paragraph("Etape 2 — Smoke test", H2))
flow.append(Paragraph(
    "1) PawMap : taper un ami partageant sa position, zoom au plus pres + la "
    "camera le suit quand il bouge ; banniere 'Suivi en direct' + Arreter. "
    "2) Signalements : creer un signalement 'Trafic dense', publie sans "
    "erreur. 3) Reservations : la carte de confirmation n'apparait plus sur "
    "les anciennes resas terminees.", P))
flow.append(Paragraph("Etape 3 — Archive Xcode", H2))
flow.append(Paragraph("open ios/Runner.xcworkspace, scheme Runner, Any iOS Device, Product &gt; Archive, Distribute App &gt; App Store Connect (TestFlight d'abord).", P))
flow.append(Spacer(1, 0.5*cm))
flow.append(Paragraph("Build Android : flutter build apk --release, puis Downloads/HopeTSIT_v23.1.263.apk.", INFO))

doc.build(flow)
print(f"OK -> {OUT}")

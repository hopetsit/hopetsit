"""HopeTSIT iOS Build Guide v23.1.274 generator."""
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, PageBreak
from reportlab.lib.enums import TA_JUSTIFY

OUT = "C:/Users/Usuario/Downloads/HopeTSIT_iOS_Build_Guide_v23.1.274.pdf"
doc = SimpleDocTemplate(OUT, pagesize=A4, leftMargin=1.8*cm, rightMargin=1.8*cm,
    topMargin=1.8*cm, bottomMargin=1.8*cm, title="HopeTSIT iOS Build Guide v23.1.274", author="HopeTSIT team")
styles = getSampleStyleSheet()
H1 = ParagraphStyle('H1', parent=styles['Heading1'], fontSize=22, textColor=colors.HexColor("#EF4324"), spaceAfter=14, leading=26)
H2 = ParagraphStyle('H2', parent=styles['Heading2'], fontSize=15, textColor=colors.HexColor("#1F2937"), spaceAfter=10, spaceBefore=14, leading=18)
P = ParagraphStyle('P', parent=styles['BodyText'], fontSize=10, leading=14, alignment=TA_JUSTIFY)
CODE = ParagraphStyle('CODE', parent=styles['Code'], fontSize=9, leading=12, leftIndent=12, textColor=colors.HexColor("#0F172A"), backColor=colors.HexColor("#F1F5F9"))
INFO = ParagraphStyle('INFO', parent=styles['BodyText'], fontSize=9, leading=13, leftIndent=12, rightIndent=12, textColor=colors.HexColor("#075985"), backColor=colors.HexColor("#E0F2FE"), borderColor=colors.HexColor("#0EA5E9"), borderWidth=1, borderPadding=8)
GREEN = ParagraphStyle('GREEN', parent=styles['BodyText'], fontSize=10, leading=14, leftIndent=12, rightIndent=12, textColor=colors.HexColor("#065F46"), backColor=colors.HexColor("#D1FAE5"), borderColor=colors.HexColor("#10B981"), borderWidth=1, borderPadding=8)

flow = []
flow.append(Paragraph("HopeTSIT — iOS Build Guide", H1))
flow.append(Paragraph("Version 23.1.274 (Build 274)", H2))
flow.append(Spacer(1, 0.4*cm))
flow.append(Paragraph(
    "Delta v23.1.273 to v23.1.274 : PawMap / PawFollow — anneau 'tracking' "
    "pulsant autour de la personne activement suivie pour montrer sans "
    "ambiguite que le suivi est live et la traque a la trace. Audit complet "
    "des options PawSpot (halos, anneaux role, tiers boost, pins, anneau "
    "famille violet, pulse platine) : tout fonctionne.", P))
flow.append(Spacer(1, 0.5*cm))
flow.append(Paragraph(
    "v23.1.274 — Frontend uniquement. Aucune migration DB. APK universal. "
    "Inclut aussi tous les correctifs backend deja deployes (wallet, Top "
    "loyalty, famille, mails).", GREEN))
flow.append(PageBreak())

flow.append(Paragraph("Changelog v23.1.274", H1))
flow.append(Paragraph("PawFollow : le halo suit la personne a la trace", H2))
flow.append(Paragraph(
    "Daniel : 'le pin halo de paw follow doit suivre la personne quand elle "
    "bouge'. VERIFICATION : le halo des amis etait DEJA centre sur la position "
    "live (pos.latitude/longitude) avec un circleId STABLE "
    "(tag_halo_userId) -> Google Maps deplace le cercle au lieu de le "
    "recreer, et _buildHaloCircles() est recalcule a chaque rebuild Obx "
    "(signature de coordonnees v263 + tick 600ms). Donc le halo suivait "
    "deja l'ami a chaque map:friend-position recu.", P))
flow.append(Paragraph(
    "AJOUT v274 : comme le suivi etait correct mais peu perceptible, on "
    "rajoute un anneau 'tracking' qui RESPIRE (30->70m via _haloPhase) "
    "uniquement autour de la personne activement suivie (_followUserId). "
    "Centre sur sa position LIVE -> il se deplace avec elle. Resultat : la "
    "personne suivie a un anneau vivant et pulsant, le suivi a la trace est "
    "visuellement evident.", P))
flow.append(Paragraph(
    "Prerequis : l'autre personne doit partager sa position ('Me suivre' ON). "
    "Sans son broadcast, il n'y a aucune position a suivre (ni marqueur ni "
    "halo ne bougent).", INFO))
flow.append(Paragraph("Audit PawSpot — toutes les options OK", H2))
flow.append(Paragraph(
    "Verifie une par une : (1) halo perso boost bronze/argent/or/platine ; "
    "(2) anneaux role providers vert walker / bleu sitter ; (3) halos tier "
    "providers boostes pulsants ; (4) pins colores par tier (cuivre/argent/"
    "ambre/orange) + label tier dans l'infoWindow ; (5) halos amis/famille "
    "live + anneau violet famille ; (6) pulse platine anime ; (7) halo bleu "
    "utilisateur. Aucun correctif necessaire, tout est cable.", P))
flow.append(PageBreak())

flow.append(Paragraph("Build iOS — etapes Xcode", H1))
flow.append(Paragraph("Etape 1 — Pull v274", H2))
flow.append(Paragraph("git pull origin main<br/>cd frontend &amp;&amp; flutter clean &amp;&amp; flutter pub get<br/>cd ios &amp;&amp; pod install --repo-update", CODE))
flow.append(Paragraph("Etape 2 — Smoke test", H2))
flow.append(Paragraph(
    "Sur la PawMap : depuis la liste d'amis/famille, tap sur une personne qui "
    "partage sa position -> la camera zoom fort sur elle ET un anneau pulsant "
    "apparait autour de son point. Quand elle se deplace, l'anneau + le "
    "marqueur la suivent a la trace.", P))
flow.append(Paragraph("Etape 3 — Archive Xcode", H2))
flow.append(Paragraph("open ios/Runner.xcworkspace, scheme Runner, Any iOS Device, Product &gt; Archive, Distribute App &gt; App Store Connect (TestFlight d'abord).", P))
flow.append(Spacer(1, 0.5*cm))
flow.append(Paragraph("Build Android : flutter build apk --release -> Downloads/HopeTSIT_v23.1.274.apk.", INFO))

doc.build(flow)
print(f"OK -> {OUT}")

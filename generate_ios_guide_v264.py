"""HopeTSIT iOS Build Guide v23.1.264 generator.

v264 = fix ajout famille (FAMILY_PLAN_REQUIRED) + carte de confirmation de
retour dans les reservations (revert du masquage v262).
"""
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, PageBreak
from reportlab.lib.enums import TA_JUSTIFY

OUT = "C:/Users/Usuario/Downloads/HopeTSIT_iOS_Build_Guide_v23.1.264.pdf"
doc = SimpleDocTemplate(OUT, pagesize=A4, leftMargin=1.8*cm, rightMargin=1.8*cm,
    topMargin=1.8*cm, bottomMargin=1.8*cm, title="HopeTSIT iOS Build Guide v23.1.264", author="HopeTSIT team")
styles = getSampleStyleSheet()
H1 = ParagraphStyle('H1', parent=styles['Heading1'], fontSize=22, textColor=colors.HexColor("#EF4324"), spaceAfter=14, leading=26)
H2 = ParagraphStyle('H2', parent=styles['Heading2'], fontSize=15, textColor=colors.HexColor("#1F2937"), spaceAfter=10, spaceBefore=14, leading=18)
P = ParagraphStyle('P', parent=styles['BodyText'], fontSize=10, leading=14, alignment=TA_JUSTIFY)
CODE = ParagraphStyle('CODE', parent=styles['Code'], fontSize=9, leading=12, leftIndent=12, textColor=colors.HexColor("#0F172A"), backColor=colors.HexColor("#F1F5F9"))
INFO = ParagraphStyle('INFO', parent=styles['BodyText'], fontSize=9, leading=13, leftIndent=12, rightIndent=12, textColor=colors.HexColor("#075985"), backColor=colors.HexColor("#E0F2FE"), borderColor=colors.HexColor("#0EA5E9"), borderWidth=1, borderPadding=8)
GREEN = ParagraphStyle('GREEN', parent=styles['BodyText'], fontSize=10, leading=14, leftIndent=12, rightIndent=12, textColor=colors.HexColor("#065F46"), backColor=colors.HexColor("#D1FAE5"), borderColor=colors.HexColor("#10B981"), borderWidth=1, borderPadding=8)

flow = []
flow.append(Paragraph("HopeTSIT — iOS Build Guide", H1))
flow.append(Paragraph("Version 23.1.264 (Build 264)", H2))
flow.append(Spacer(1, 0.4*cm))
flow.append(Paragraph(
    "Delta v23.1.263 to v23.1.264. Deux corrections : ajout de membre famille "
    "(backend) et carte de confirmation de retour dans les reservations "
    "(frontend).", P))
flow.append(Spacer(1, 0.5*cm))
flow.append(Paragraph(
    "Le fix AJOUT FAMILLE est backend (deja deploye sur Render). La carte de "
    "confirmation est frontend, livree dans cet APK / cette archive iOS. "
    "Aucune migration DB. APK universal.", GREEN))
flow.append(PageBreak())

flow.append(Paragraph("Changelog v23.1.264", H1))
flow.append(Paragraph("1. Ajout membre famille (backend)", H2))
flow.append(Paragraph(
    "Les endpoints /friends/family/invite-member et /family/invite-by-email "
    "filtraient sur userModel: user.model (casse exacte) alors que "
    "GET /family/members (qui affiche 'Famille actif - 2/5') accepte aussi la "
    "variante minuscule via $in. Selon la casse renvoyee par l'auth (ou un "
    "ancien document), l'invite ne trouvait pas la sub PawFollow Famille, d'ou "
    "un 403 FAMILY_PLAN_REQUIRED trompeur. On aligne les deux invites sur la "
    "MEME requete que /family/members ($in [user.model, lowercase]).", P))
flow.append(Paragraph("2. Carte de confirmation (frontend)", H2))
flow.append(Paragraph(
    "Revert du masquage v262. En v262 on cachait la carte quand "
    "confirmationStatus == 'none', mais les reservations payees avant que le "
    "backend ne pose 'awaiting_start' valent 'none', donc le systeme de "
    "confirmation disparaissait des reservations. On revient la-dessus : "
    "'none' est de nouveau traite comme 'awaiting_start' (le prestataire peut "
    "demarrer le service), la carte est visible sur toute reservation payee.", P))
flow.append(Paragraph(
    "Rappel flux : prestataire 'J'ai recupere l'animal' puis 'J'ai rendu "
    "l'animal' ; ensuite owner 'Confirmer' (libere le paiement) ou 'Signaler' "
    "(bloque). Sans action owner, liberation auto a 48h.", INFO))
flow.append(PageBreak())

flow.append(Paragraph("Build iOS — etapes Xcode", H1))
flow.append(Paragraph("Etape 1 — Pull v264", H2))
flow.append(Paragraph("git pull origin main<br/>cd frontend &amp;&amp; flutter clean &amp;&amp; flutter pub get<br/>cd ios &amp;&amp; pod install --repo-update", CODE))
flow.append(Paragraph("Etape 2 — Smoke test", H2))
flow.append(Paragraph(
    "1) Mes amis : avec PawFollow Famille actif, taper Inviter sur un ami, "
    "invitation envoyee sans erreur FAMILY_PLAN_REQUIRED. 2) Reservations : la "
    "carte de confirmation de service est de nouveau visible sous chaque "
    "reservation payee (les 3 profils).", P))
flow.append(Paragraph("Etape 3 — Archive Xcode", H2))
flow.append(Paragraph("open ios/Runner.xcworkspace, scheme Runner, Any iOS Device, Product &gt; Archive, Distribute App &gt; App Store Connect (TestFlight d'abord).", P))
flow.append(Spacer(1, 0.5*cm))
flow.append(Paragraph("Build Android : flutter build apk --release, puis Downloads/HopeTSIT_v23.1.264.apk.", INFO))

doc.build(flow)
print(f"OK -> {OUT}")

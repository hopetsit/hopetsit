"""HopeTSIT iOS Build Guide v23.1.261 generator.

v261 = la carte de confirmation de service est désormais visible DIRECTEMENT
dans la LISTE des réservations (3 profils), pas seulement sur l'écran détail.
"""
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, PageBreak
from reportlab.lib.enums import TA_JUSTIFY

OUT = "C:/Users/Usuario/Downloads/HopeTSIT_iOS_Build_Guide_v23.1.261.pdf"
doc = SimpleDocTemplate(OUT, pagesize=A4, leftMargin=1.8*cm, rightMargin=1.8*cm,
    topMargin=1.8*cm, bottomMargin=1.8*cm, title="HopeTSIT iOS Build Guide v23.1.261", author="HopeTSIT team")
styles = getSampleStyleSheet()
H1 = ParagraphStyle('H1', parent=styles['Heading1'], fontSize=22, textColor=colors.HexColor("#EF4324"), spaceAfter=14, leading=26)
H2 = ParagraphStyle('H2', parent=styles['Heading2'], fontSize=15, textColor=colors.HexColor("#1F2937"), spaceAfter=10, spaceBefore=14, leading=18)
P = ParagraphStyle('P', parent=styles['BodyText'], fontSize=10, leading=14, alignment=TA_JUSTIFY)
CODE = ParagraphStyle('CODE', parent=styles['Code'], fontSize=9, leading=12, leftIndent=12, textColor=colors.HexColor("#0F172A"), backColor=colors.HexColor("#F1F5F9"))
INFO = ParagraphStyle('INFO', parent=styles['BodyText'], fontSize=9, leading=13, leftIndent=12, rightIndent=12, textColor=colors.HexColor("#075985"), backColor=colors.HexColor("#E0F2FE"), borderColor=colors.HexColor("#0EA5E9"), borderWidth=1, borderPadding=8)
GREEN = ParagraphStyle('GREEN', parent=styles['BodyText'], fontSize=10, leading=14, leftIndent=12, rightIndent=12, textColor=colors.HexColor("#065F46"), backColor=colors.HexColor("#D1FAE5"), borderColor=colors.HexColor("#10B981"), borderWidth=1, borderPadding=8)

flow = []
flow.append(Paragraph("HopeTSIT — iOS Build Guide", H1))
flow.append(Paragraph("Version 23.1.261 (Build 261)", H2))
flow.append(Spacer(1, 0.4*cm))
flow.append(Paragraph(
    "Delta v23.1.260 → v23.1.261. La carte de confirmation de service est "
    "maintenant affichée DIRECTEMENT dans la liste des réservations des 3 "
    "profils (avant : seulement sur l'écran détail → \"elle n'apparaît pas\").", P))
flow.append(Spacer(1, 0.5*cm))
flow.append(Paragraph(
    "v23.1.261 — Frontend uniquement (le backend du système de confirmation "
    "est déjà déployé en v259/v260). Aucune migration DB. APK universal.", GREEN))
flow.append(PageBreak())

flow.append(Paragraph("Changelog v23.1.261", H1))
flow.append(Paragraph("Carte de confirmation visible sur la liste", H2))
flow.append(Paragraph(
    "La carte ServiceConfirmationCard est ajoutée sous chaque réservation "
    "PAYÉE dans la LISTE des réservations (owner / sitter / walker), en plus "
    "de l'écran détail. Provider : boutons « J'ai récupéré l'animal » → "
    "« J'ai rendu l'animal ». Owner : « Confirmer / Signaler un problème » "
    "(quand le provider a marqué la fin). Actions branchées sur les repos "
    "(confirm/dispute, start/complete) + reload de la liste. "
    "startService/completeService ajoutés à WalkerRepository.", P))
flow.append(Paragraph("Rappel du flux", H2))
flow.append(Paragraph(
    "1) Provider : « récupéré » → 2) Provider : « rendu » → 3) Owner : "
    "« Confirmer » libère le paiement (ou « Signaler » le bloque). Sans action "
    "owner, auto-release 48h. Ne concerne que les résas payées.", P))
flow.append(PageBreak())

flow.append(Paragraph("Build iOS — étapes Xcode", H1))
flow.append(Paragraph("Étape 1 — Pull v261", H2))
flow.append(Paragraph("git pull origin main<br/>cd frontend &amp;&amp; flutter clean &amp;&amp; flutter pub get<br/>cd ios &amp;&amp; pod install --repo-update", CODE))
flow.append(Paragraph("Étape 2 — Smoke test", H2))
flow.append(Paragraph(
    "Ouvrir l'onglet Réservations (pas besoin d'ouvrir le détail) : sous "
    "chaque résa payée, la carte de confirmation est visible. Provider marque "
    "récupéré/rendu → owner voit Confirmer/Signaler → Confirmer libère le "
    "paiement.", P))
flow.append(Paragraph("Étape 3 — Archive Xcode", H2))
flow.append(Paragraph("open ios/Runner.xcworkspace → scheme Runner, Any iOS Device → Product &gt; Archive → Distribute App &gt; App Store Connect (TestFlight d'abord).", P))
flow.append(Spacer(1, 0.5*cm))
flow.append(Paragraph("Build : flutter build apk --release → Downloads/HopeTSIT_v23.1.261.apk.", INFO))

doc.build(flow)
print(f"OK -> {OUT}")

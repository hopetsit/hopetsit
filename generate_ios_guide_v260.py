"""HopeTSIT iOS Build Guide v23.1.260 generator.

v260 = v258 (bugs) + v259 (système de confirmation de service) + v260 (ami
qui change de rôle reste ami).
"""
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, PageBreak
from reportlab.lib.enums import TA_JUSTIFY

OUT = "C:/Users/Usuario/Downloads/HopeTSIT_iOS_Build_Guide_v23.1.260.pdf"
doc = SimpleDocTemplate(OUT, pagesize=A4, leftMargin=1.8*cm, rightMargin=1.8*cm,
    topMargin=1.8*cm, bottomMargin=1.8*cm, title="HopeTSIT iOS Build Guide v23.1.260", author="HopeTSIT team")
styles = getSampleStyleSheet()
H1 = ParagraphStyle('H1', parent=styles['Heading1'], fontSize=22, textColor=colors.HexColor("#EF4324"), spaceAfter=14, leading=26)
H2 = ParagraphStyle('H2', parent=styles['Heading2'], fontSize=15, textColor=colors.HexColor("#1F2937"), spaceAfter=10, spaceBefore=14, leading=18)
P = ParagraphStyle('P', parent=styles['BodyText'], fontSize=10, leading=14, alignment=TA_JUSTIFY)
CODE = ParagraphStyle('CODE', parent=styles['Code'], fontSize=9, leading=12, leftIndent=12, textColor=colors.HexColor("#0F172A"), backColor=colors.HexColor("#F1F5F9"))
INFO = ParagraphStyle('INFO', parent=styles['BodyText'], fontSize=9, leading=13, leftIndent=12, rightIndent=12, textColor=colors.HexColor("#075985"), backColor=colors.HexColor("#E0F2FE"), borderColor=colors.HexColor("#0EA5E9"), borderWidth=1, borderPadding=8)
GREEN = ParagraphStyle('GREEN', parent=styles['BodyText'], fontSize=10, leading=14, leftIndent=12, rightIndent=12, textColor=colors.HexColor("#065F46"), backColor=colors.HexColor("#D1FAE5"), borderColor=colors.HexColor("#10B981"), borderWidth=1, borderPadding=8)
RED = ParagraphStyle('RED', parent=styles['BodyText'], fontSize=10, leading=14, leftIndent=12, rightIndent=12, textColor=colors.HexColor("#7F1D1D"), backColor=colors.HexColor("#FEE2E2"), borderColor=colors.HexColor("#EF4444"), borderWidth=1, borderPadding=8)

flow = []
flow.append(Paragraph("HopeTSIT — iOS Build Guide", H1))
flow.append(Paragraph("Version 23.1.260 (Build 260)", H2))
flow.append(Spacer(1, 0.4*cm))
flow.append(Paragraph(
    "Delta v23.1.257 → v23.1.260. Contenu majeur : nouveau SYSTÈME DE "
    "CONFIRMATION DE SERVICE (le paiement n'est libéré qu'après confirmation "
    "de l'owner, ou auto 48h), + correctifs temps réel chat / signalements / "
    "badge amis, + un ami qui change de rôle reste dans la liste d'amis.", P))
flow.append(Spacer(1, 0.5*cm))
flow.append(Paragraph(
    "v23.1.260 — Aucune migration DB destructive (champs additifs sur Booking). "
    "Backend (Render) déjà déployé. APK universal. Re-login requis une fois "
    "(token 365j + socket).", GREEN))
flow.append(PageBreak())

flow.append(Paragraph("Changelog v23.1.260", H1))
flow.append(Paragraph("Système de confirmation de service (v259)", H2))
flow.append(Paragraph(
    "Flux : le PROVIDER tape « J'ai récupéré l'animal » (début) puis « J'ai "
    "rendu l'animal » (fin) → l'OWNER reçoit une carte « Confirmer / Signaler "
    "un problème ». Confirmer LIBÈRE le paiement ; signaler le BLOQUE. Sécurité "
    "anti-blocage : auto-release 48h après la fin si l'owner ne répond pas.", P))
flow.append(Paragraph(
    "Backend : Booking.confirmationStatus + dates ; le payout passe de "
    "« libéré au début du service » à « libéré à la confirmation / auto 48h » "
    "via le scheduler existant ; jamais de versement en litige. 4 endpoints "
    "(/service/start|complete|confirm|dispute) + 4 notifications × 6 langues. "
    "Frontend : carte ServiceConfirmationCard sur l'écran réservation des 3 "
    "profils (états + boutons selon rôle) + 21 clés i18n.", P))
flow.append(Paragraph("Correctifs (v258)", H2))
flow.append(Paragraph(
    "• Temps réel chat : re-join de la room de conversation à chaque "
    "(re)connexion → messages + demande de suivi instantanés (plus besoin de "
    "rafraîchir).<br/>"
    "• Signalements PawMap : capture GPS robuste (getLastKnownPosition "
    "fallback) → le clic fonctionne même si le GPS est lent.<br/>"
    "• Badge demandes d'amis : refresh forcé à l'ouverture de la PawMap.", P))
flow.append(Paragraph("Ami qui change de rôle (v260)", H2))
flow.append(Paragraph(
    "switchRole supprimait l'ancien doc → les amitiés/chats amis qui le "
    "référençaient pointaient dans le vide → l'ami disparaissait des listes. "
    "FIX : migration du graphe social (Friendship + Conversation friendChat) "
    "vers le nouveau doc/rôle avant suppression. Un ami qui passe owner↔"
    "walker/sitter RESTE dans la liste d'amis.", P))
flow.append(PageBreak())

flow.append(Paragraph("Build iOS — étapes Xcode", H1))
flow.append(Paragraph("Étape 1 — Pull v260", H2))
flow.append(Paragraph("git pull origin main<br/>cd frontend &amp;&amp; flutter clean &amp;&amp; flutter pub get<br/>cd ios &amp;&amp; pod install --repo-update", CODE))
flow.append(Paragraph("Étape 2 — Smoke tests v260", H2))
flow.append(Paragraph(
    "Après reconnexion :<br/>"
    "• <b>Confirmation</b> : payer une résa → côté provider taper « récupéré » "
    "puis « rendu » → côté owner, carte « Confirmer / Signaler » apparaît → "
    "Confirmer libère le paiement (vérifier le wallet provider).<br/>"
    "• <b>Auto-release</b> : sans confirmation, le paiement se libère 48h après "
    "la fin (scheduler).<br/>"
    "• <b>Chat</b> : messages + demande de suivi instantanés.<br/>"
    "• <b>Signalement</b> : clic sur une icône → création OK.<br/>"
    "• <b>Ami change de rôle</b> : un ami passe owner→walker → il reste dans "
    "ta liste d'amis.", P))
flow.append(Paragraph("Étape 3 — Archive Xcode", H2))
flow.append(Paragraph("open ios/Runner.xcworkspace → scheme Runner, Any iOS Device → Product &gt; Archive → Distribute App &gt; App Store Connect (TestFlight d'abord).", P))
flow.append(PageBreak())

flow.append(Paragraph("Rollback", H1))
flow.append(Paragraph(
    "App Store Connect &gt; Phased Release &gt; Pause + git revert des commits "
    "v258/v259/v260. Render redeploy auto. PDF v23.1.257 reste valide.", P))
flow.append(Paragraph(
    "ATTENTION : le système de confirmation change la LIBÉRATION du paiement "
    "(maintenant après confirmation/48h au lieu du début du service). Revert "
    "= retour au versement au début. Champs Booking additifs (non-breaking).", RED))
flow.append(Spacer(1, 0.5*cm))
flow.append(Paragraph(
    "Build : flutter build apk --release → Downloads/HopeTSIT_v23.1.260.apk. "
    "Push origin/main = Render redeploy auto.", INFO))

doc.build(flow)
print(f"OK -> {OUT}")

"""
HopeTSIT iOS Build Guide v23.1.256 generator.

v256 = batch v256 + v256b (correctifs critiques chat/suivi/annulation) :
  - v256  : "suivre ma balade" s'affiche enfin sur les 3 profils (le côté
            provider ne rechargeait pas le chat après envoi → carte invisible).
            + respondToPawfollowRequest emitChatMessage (accept/refus temps réel).
            + DEMANDES D'AMIS temps réel (friendRoutes utilisait un module
            inexistant + mauvaise room → jamais poussé). + reset clearedFor.
  - v256b : bouton ANNULATION 72h de retour sur les 3 profils (liste) — il
            était gaté >72h + parsing date → caché pour les résas proches.
            Aligné sur l'écran détail : visible pour toute résa payée, dialogue
            adaptatif (gratuit >72h, sinon "fenêtre fermée").
"""
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, PageBreak
from reportlab.lib.enums import TA_JUSTIFY

OUT = "C:/Users/Usuario/Downloads/HopeTSIT_iOS_Build_Guide_v23.1.256.pdf"

doc = SimpleDocTemplate(
    OUT, pagesize=A4,
    leftMargin=1.8*cm, rightMargin=1.8*cm, topMargin=1.8*cm, bottomMargin=1.8*cm,
    title="HopeTSIT iOS Build Guide v23.1.256", author="HopeTSIT team",
)
styles = getSampleStyleSheet()
H1 = ParagraphStyle('H1', parent=styles['Heading1'], fontSize=22,
                    textColor=colors.HexColor("#EF4324"), spaceAfter=14, leading=26)
H2 = ParagraphStyle('H2', parent=styles['Heading2'], fontSize=15,
                    textColor=colors.HexColor("#1F2937"), spaceAfter=10, spaceBefore=14, leading=18)
P = ParagraphStyle('P', parent=styles['BodyText'], fontSize=10, leading=14, alignment=TA_JUSTIFY)
CODE = ParagraphStyle('CODE', parent=styles['Code'], fontSize=9, leading=12, leftIndent=12,
                      textColor=colors.HexColor("#0F172A"), backColor=colors.HexColor("#F1F5F9"))
INFO = ParagraphStyle('INFO', parent=styles['BodyText'], fontSize=9, leading=13, leftIndent=12,
                      rightIndent=12, textColor=colors.HexColor("#075985"),
                      backColor=colors.HexColor("#E0F2FE"), borderColor=colors.HexColor("#0EA5E9"),
                      borderWidth=1, borderPadding=8)
GREEN = ParagraphStyle('GREEN', parent=styles['BodyText'], fontSize=10, leading=14, leftIndent=12,
                       rightIndent=12, textColor=colors.HexColor("#065F46"),
                       backColor=colors.HexColor("#D1FAE5"), borderColor=colors.HexColor("#10B981"),
                       borderWidth=1, borderPadding=8)
RED = ParagraphStyle('RED', parent=styles['BodyText'], fontSize=10, leading=14, leftIndent=12,
                     rightIndent=12, textColor=colors.HexColor("#7F1D1D"),
                     backColor=colors.HexColor("#FEE2E2"), borderColor=colors.HexColor("#EF4444"),
                     borderWidth=1, borderPadding=8)

flow = []
flow.append(Paragraph("HopeTSIT — iOS Build Guide", H1))
flow.append(Paragraph("Version 23.1.256 (Build 256)", H2))
flow.append(Spacer(1, 0.4*cm))
flow.append(Paragraph(
    "Build guide &amp; changelog pour Xcode (Mac requis). Delta v23.1.255 → "
    "v23.1.256 : 3 correctifs critiques issus d'un deep work sur le chat / le "
    "suivi live / l'annulation : (1) la demande \"suivre ma balade\" s'affiche "
    "enfin sur les 3 profils, (2) les demandes d'amis arrivent en temps réel, "
    "(3) le bouton annulation 72h est de retour sur les 3 profils.",
    P))
flow.append(Spacer(1, 0.5*cm))
flow.append(Paragraph(
    "v23.1.256 — TL;DR : aucune migration DB. Backend (Render) déjà déployé. "
    "APK Android universal. Les correctifs backend (demandes d'amis temps réel, "
    "accept/refus suivi, clearedFor) sont actifs après re-login ; les correctifs "
    "frontend (reload provider + bouton 72h) arrivent avec ce build.",
    GREEN))
flow.append(PageBreak())

flow.append(Paragraph("Changelog v23.1.256", H1))

flow.append(Paragraph("Round 1 — Suivi live + demandes d'amis temps réel (v256)", H2))
flow.append(Paragraph(
    "<b>\"Suivre ma balade\" invisible (3 profils) :</b> côté provider "
    "(sitter/walker), le handler _onFollowMeTap NE RECHARGEAIT PAS le chat "
    "après l'envoi → l'expéditeur ne voyait jamais sa propre carte "
    "pawfollow_request (dépendance 100% socket, sans fallback HTTP — alors que "
    "le côté owner recharge). FIX : loadChatMessages() après les 2 branches de "
    "succès → la carte apparaît immédiatement.",
    P))
flow.append(Paragraph(
    "<b>Régressions socket (même bug require('../sockets/io') = module "
    "INEXISTANT → throw avalé → jamais de temps réel) :</b><br/>"
    "- respondToPawfollowRequest : accept/refus jamais diffusé → emitChatMessage.<br/>"
    "- friendRoutes /request + /accept : les DEMANDES D'AMIS n'étaient JAMAIS "
    "poussées en temps réel (module cassé + room `user_&lt;id&gt;` au lieu de "
    "`user:&lt;role&gt;:&lt;id&gt;`). FIX : emitToUser → reçues/acceptées "
    "instantanément.<br/>"
    "- reset clearedFor sur les messages pawfollow (rouvre une conv masquée).",
    P))

flow.append(Paragraph("Round 2 — Bouton annulation 72h de retour (v256b)", H2))
flow.append(Paragraph(
    "Le bouton ne revenait sur AUCUN profil. CAUSE : sur les écrans LISTE "
    "(owner/sitter/walker), le bouton était gaté sur _isWithinSelfCancelWindow "
    "(hoursUntilStart &gt; 72) ET sur le parsing de booking.date → caché pour "
    "toute résa &lt;72h ou si la date ne se parse pas. L'écran DÉTAIL, lui, le "
    "montrait pour toute résa payée. FIX : on aligne les 3 listes sur le détail "
    "— bouton visible dès qu'une résa est payée (non annulée/terminée/remboursée) "
    "; le dialogue _confirmSelfCancel devient adaptatif : annulation gratuite + "
    "refund si &gt;72h, sinon message \"fenêtre d'annulation gratuite fermée\" "
    "(le backend selfCancelWithRefund rejette de toute façon un self-cancel "
    "&lt;72h).",
    P))

flow.append(PageBreak())
flow.append(Paragraph("Build iOS — étapes Xcode", H1))
flow.append(Paragraph("Pré-requis", H2))
flow.append(Paragraph(
    "Mac macOS Sonoma 14.5+. Xcode 15.4+ (CLT). Flutter 3.27+ stable. "
    "CocoaPods 1.15+. Apple Developer Program actif (Team ID dans Xcode).",
    P))
flow.append(Paragraph("Étape 1 — Pull v256", H2))
flow.append(Paragraph(
    "git pull origin main<br/>cd frontend &amp;&amp; flutter clean &amp;&amp; "
    "flutter pub get<br/>cd ios &amp;&amp; pod install --repo-update", CODE))
flow.append(Paragraph("Étape 2 — Smoke tests v256", H2))
flow.append(Paragraph(
    "Après une PREMIÈRE reconnexion :<br/>"
    "• <b>Suivre ma balade</b> (côté walker/sitter) → la carte de demande "
    "s'affiche tout de suite dans le chat, et chez l'owner.<br/>"
    "• <b>Demande d'ami</b> → reçue/acceptée en temps réel sans deco-reco "
    "(+ badge sur le bouton PawMap).<br/>"
    "• <b>Bouton annulation 72h</b> → présent sur owner + sitter + walker pour "
    "toute résa payée ; &gt;72h = annulation gratuite, &lt;72h = message "
    "fenêtre fermée.<br/>"
    "• <b>Envoi adresse/téléphone</b> → s'affiche en direct.",
    P))
flow.append(Paragraph("Étape 3 — Archive Xcode", H2))
flow.append(Paragraph(
    "1. open ios/Runner.xcworkspace<br/>2. scheme Runner, Any iOS Device<br/>"
    "3. Product &gt; Archive<br/>4. Organizer &gt; Distribute App &gt; App "
    "Store Connect<br/>5. Upload (TestFlight d'abord)", P))

flow.append(PageBreak())
flow.append(Paragraph("Rollback", H1))
flow.append(Paragraph(
    "App Store Connect &gt; Phased Release &gt; Pause, puis git revert des "
    "commits v256*. Render redeploy auto. Le PDF v23.1.255 reste valide.", P))
flow.append(Paragraph(
    "ATTENTION : ne pas revert les fix friendRoutes/respondToPawfollow "
    "(emitToUser/emitChatMessage) ni le bouton 72h — ce sont des corrections "
    "de régressions. Aucune migration DB.", RED))

flow.append(PageBreak())
flow.append(Paragraph("Fichiers v256 (référence)", H1))
flow.append(Paragraph("Backend (Render auto-deploy)", H2))
flow.append(Paragraph(
    "- controllers/bookingController.js — respondToPawfollowRequest "
    "emitChatMessage + reset clearedFor sur messages pawfollow<br/>"
    "- routes/friendRoutes.js — emitToUser sur /request et /accept "
    "(demandes d'amis temps réel)",
    P))
flow.append(Paragraph("Frontend Flutter", H2))
flow.append(Paragraph(
    "- pubspec.yaml — 23.1.255+255 → 23.1.256+256<br/>"
    "- views/pet_sitter/chat/sitter_individual_chat_screen.dart — "
    "loadChatMessages après envoi follow-request<br/>"
    "- views/pet_owner/booking/owner_bookings_screen.dart<br/>"
    "- views/pet_sitter/booking/sitter_bookings_screen.dart<br/>"
    "- views/pet_walker/booking/walker_bookings_screen.dart<br/>"
    "  → bouton annulation 72h visible pour toute résa payée + dialogue adaptatif",
    P))
flow.append(Spacer(1, 0.5*cm))
flow.append(Paragraph(
    "Build : flutter build apk --release → app-release.apk (universal) copié "
    "dans Downloads/HopeTSIT_v23.1.256.apk. Push origin/main = Render redeploy auto.",
    INFO))

doc.build(flow)
print(f"OK -> {OUT}")

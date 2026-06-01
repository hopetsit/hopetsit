"""
HopeTSIT iOS Build Guide v23.1.257 generator.

v257 = deep fix #2 du suivi live "suivre ma balade" (la carte ne s'affichait
toujours sur AUCUN profil après v256) :
  - BACKEND requestLiveTrackingByConversation : guards de rôle 403 remplacés
    par une résolution PERMISSIVE (tout participant booking OU friendChat) →
    le message pawfollow_request est toujours créé dans la conversation
    regardée. + persistance GPS (lat/lng) pour le suivi réel.
  - FRONTEND : owner ET walker/sitter envoient TOUJOURS via la conversation
    ouverte (widget.conversationId) au lieu d'un fragile match booking par
    nom → la carte atterrit à coup sûr dans CE chat + reload immédiat.
"""
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, PageBreak
from reportlab.lib.enums import TA_JUSTIFY

OUT = "C:/Users/Usuario/Downloads/HopeTSIT_iOS_Build_Guide_v23.1.257.pdf"

doc = SimpleDocTemplate(
    OUT, pagesize=A4,
    leftMargin=1.8*cm, rightMargin=1.8*cm, topMargin=1.8*cm, bottomMargin=1.8*cm,
    title="HopeTSIT iOS Build Guide v23.1.257", author="HopeTSIT team",
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

flow = []
flow.append(Paragraph("HopeTSIT — iOS Build Guide", H1))
flow.append(Paragraph("Version 23.1.257 (Build 257)", H2))
flow.append(Spacer(1, 0.4*cm))
flow.append(Paragraph(
    "Build guide &amp; changelog pour Xcode (Mac requis). Delta v23.1.256 → "
    "v23.1.257 : deep fix #2 du suivi live — la carte \"suivre ma balade\" "
    "s'affiche enfin sur les 3 profils (le message n'était jamais créé à cause "
    "de guards de rôle trop stricts côté backend + un match booking fragile "
    "côté frontend).",
    P))
flow.append(Spacer(1, 0.5*cm))
flow.append(Paragraph(
    "v23.1.257 — TL;DR : aucune migration DB. Backend (Render) déjà déployé "
    "(endpoint permissif + GPS). APK Android universal. Pré-requis : se "
    "reconnecter une fois (token 365j + socket).",
    GREEN))
flow.append(PageBreak())

flow.append(Paragraph("Changelog v23.1.257", H1))
flow.append(Paragraph("Suivi live \"suivre ma balade\" — deep fix #2", H2))
flow.append(Paragraph(
    "<b>Symptôme :</b> la demande de suivi ne s'affichait dans AUCUN profil, "
    "même après le fix v256 (reload provider).",
    P))
flow.append(Paragraph(
    "<b>Cause racine #1 (backend) :</b> requestLiveTrackingByConversation "
    "(POST /conversations/:id/follow-request) renvoyait 403 dès que les "
    "vérifications de rôle ne correspondaient pas exactement (chats friendChat "
    "sans walkerId/sitterId, ou toute incohérence) → le message "
    "pawfollow_request n'était JAMAIS créé, mais le endpoint pouvait quand "
    "même paraître \"ok\". FIX : résolution PERMISSIVE — on vérifie seulement "
    "que l'appelant est participant de la conversation (booking OU friendChat) "
    "et on déduit le destinataire = l'autre partie. Le message est désormais "
    "toujours créé dans la conversation regardée.",
    P))
flow.append(Paragraph(
    "<b>Cause racine #2 (frontend) :</b> le handler cherchait un booking par "
    "NOM (norm(owner.name)) + paymentStatus=='paid' avant de choisir "
    "l'endpoint — fragile : si le match échouait, la carte atterrissait dans "
    "une autre conversation ou le endpoint 403ait. FIX : owner ET "
    "walker/sitter envoient maintenant TOUJOURS via la conversation OUVERTE "
    "(widget.conversationId), puis rechargent le chat → la carte apparaît "
    "immédiatement dans CE chat, sans dépendre du socket ni d'un match.",
    P))
flow.append(Paragraph(
    "<b>GPS :</b> requestLiveTrackingByConversation persiste désormais la "
    "position (lat/lng) de l'appelant dans son doc Walker/Sitter/Owner → "
    "l'autre partie peut réellement suivre (plus de NO_LOCATION_YET).",
    P))

flow.append(PageBreak())
flow.append(Paragraph("Build iOS — étapes Xcode", H1))
flow.append(Paragraph("Pré-requis", H2))
flow.append(Paragraph(
    "Mac macOS Sonoma 14.5+. Xcode 15.4+ (CLT). Flutter 3.27+ stable. "
    "CocoaPods 1.15+. Apple Developer Program actif.", P))
flow.append(Paragraph("Étape 1 — Pull v257", H2))
flow.append(Paragraph(
    "git pull origin main<br/>cd frontend &amp;&amp; flutter clean &amp;&amp; "
    "flutter pub get<br/>cd ios &amp;&amp; pod install --repo-update", CODE))
flow.append(Paragraph("Étape 2 — Smoke test v257", H2))
flow.append(Paragraph(
    "Après reconnexion : ouvrir un chat (booking OU ami), taper \"suivre ma "
    "balade\" / demander le suivi → la carte de demande s'affiche TOUT DE "
    "SUITE dans le chat (expéditeur) et chez l'autre partie. Tester sur "
    "owner, sitter ET walker. Accepter → le suivi GPS s'ouvre.",
    P))
flow.append(Paragraph("Étape 3 — Archive Xcode", H2))
flow.append(Paragraph(
    "1. open ios/Runner.xcworkspace<br/>2. scheme Runner, Any iOS Device<br/>"
    "3. Product &gt; Archive<br/>4. Organizer &gt; Distribute App &gt; App "
    "Store Connect<br/>5. Upload (TestFlight d'abord)", P))

flow.append(PageBreak())
flow.append(Paragraph("Fichiers v257 (référence)", H1))
flow.append(Paragraph("Backend (Render auto-deploy)", H2))
flow.append(Paragraph(
    "- controllers/bookingController.js — requestLiveTrackingByConversation : "
    "résolution participant permissive (booking + friendChat) + persistance GPS",
    P))
flow.append(Paragraph("Frontend Flutter", H2))
flow.append(Paragraph(
    "- pubspec.yaml — 23.1.256+256 → 23.1.257+257<br/>"
    "- repositories/sitter_repository.dart — requestLiveTrackingByConversation "
    "accepte lat/lng<br/>"
    "- views/pet_sitter/chat/sitter_individual_chat_screen.dart — _onFollowMeTap "
    "toujours via conversation + GPS + reload<br/>"
    "- views/pet_owner/chat/individual_chat_screen.dart — onConfirm toujours via "
    "conversation + reload",
    P))
flow.append(Spacer(1, 0.5*cm))
flow.append(Paragraph(
    "Build : flutter build apk --release → app-release.apk (universal) copié "
    "dans Downloads/HopeTSIT_v23.1.257.apk. Push origin/main = Render redeploy auto.",
    INFO))

doc.build(flow)
print(f"OK -> {OUT}")

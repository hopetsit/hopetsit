"""
HopeTSIT iOS Build Guide v23.1.255 generator.

v255 = batch v255 + v255b + v255c + v255d :
  - v255  : temps réel chat/amis réparé (socket auth) + CONFORT TOTAL (refresh
            token 365j à expiration glissante) + annulation 72h (paymentStatus
            fallback)
  - v255b : demande de suivi live affichée sur les 3 profils (broadcast cassé
            require('sockets/io') → emitChatMessage) + plus de conversation
            ami en doublon (cast ObjectId) + notif au bon destinataire
  - v255c : envoi adresse/téléphone temps réel (emitChatMessage) + badge
            demandes d'amis sur le quick bouton PawMap + i18n ligne pricing
            (prestataire/commission)
  - v255d : messages système de paiement traduits PAR VIEWER (metadata.kind)
            + suppression de conversation NON-destructive (soft-delete
            clearedFor, réapparition au nouveau message)
"""
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, PageBreak,
)
from reportlab.lib.enums import TA_JUSTIFY

OUT = "C:/Users/Usuario/Downloads/HopeTSIT_iOS_Build_Guide_v23.1.255.pdf"

doc = SimpleDocTemplate(
    OUT, pagesize=A4,
    leftMargin=1.8*cm, rightMargin=1.8*cm,
    topMargin=1.8*cm, bottomMargin=1.8*cm,
    title="HopeTSIT iOS Build Guide v23.1.255",
    author="HopeTSIT team",
)

styles = getSampleStyleSheet()
H1 = ParagraphStyle('H1', parent=styles['Heading1'],
                   fontSize=22, textColor=colors.HexColor("#EF4324"),
                   spaceAfter=14, leading=26)
H2 = ParagraphStyle('H2', parent=styles['Heading2'],
                   fontSize=15, textColor=colors.HexColor("#1F2937"),
                   spaceAfter=10, spaceBefore=14, leading=18)
P  = ParagraphStyle('P', parent=styles['BodyText'],
                   fontSize=10, leading=14, alignment=TA_JUSTIFY)
CODE = ParagraphStyle('CODE', parent=styles['Code'],
                     fontSize=9, leading=12, leftIndent=12,
                     textColor=colors.HexColor("#0F172A"),
                     backColor=colors.HexColor("#F1F5F9"))
INFO = ParagraphStyle('INFO', parent=styles['BodyText'],
                     fontSize=9, leading=13, leftIndent=12, rightIndent=12,
                     textColor=colors.HexColor("#075985"),
                     backColor=colors.HexColor("#E0F2FE"),
                     borderColor=colors.HexColor("#0EA5E9"),
                     borderWidth=1, borderPadding=8)
GREEN = ParagraphStyle('GREEN', parent=styles['BodyText'],
                     fontSize=10, leading=14, leftIndent=12, rightIndent=12,
                     textColor=colors.HexColor("#065F46"),
                     backColor=colors.HexColor("#D1FAE5"),
                     borderColor=colors.HexColor("#10B981"),
                     borderWidth=1, borderPadding=8)
RED = ParagraphStyle('RED', parent=styles['BodyText'],
                     fontSize=10, leading=14, leftIndent=12, rightIndent=12,
                     textColor=colors.HexColor("#7F1D1D"),
                     backColor=colors.HexColor("#FEE2E2"),
                     borderColor=colors.HexColor("#EF4444"),
                     borderWidth=1, borderPadding=8)

flow = []

# ─── Cover ────────────────────────────────────────────────────────────────
flow.append(Paragraph("HopeTSIT — iOS Build Guide", H1))
flow.append(Paragraph("Version 23.1.255 (Build 255)", H2))
flow.append(Spacer(1, 0.4*cm))
flow.append(Paragraph(
    "Build guide &amp; changelog pour Xcode (Mac requis). Couvre le delta "
    "v23.1.254 → v23.1.255 — chat/temps réel fiabilisé de bout en bout : "
    "reconnexion socket avec token frais, refresh silencieux (confort total), "
    "demande de suivi + adresse/téléphone qui s'affichent en direct sur les 3 "
    "profils, badge demandes d'amis, messages traduits par lecteur, "
    "suppression de conversation non-destructive, annulation 72h réparée.",
    P))
flow.append(Spacer(1, 0.5*cm))
flow.append(Paragraph(
    "v23.1.255 — TL;DR : aucune migration DB destructive (ajout d'un champ "
    "Conversation.clearedFor non-breaking). Backend (Render) + website "
    "(Vercel) déjà déployés. APK Android universal. Pré-requis utilisateur : "
    "se reconnecter UNE fois pour obtenir le token 365j (le socket temps réel "
    "et tous les fixes s'activent ensuite).",
    GREEN))

flow.append(PageBreak())

# ─── Changelog ───────────────────────────────────────────────────────────
flow.append(Paragraph("Changelog v23.1.255", H1))

flow.append(Paragraph("Round 1 — Temps réel + confort total (v255)", H2))
flow.append(Paragraph(
    "<b>Bug racine temps réel :</b> le socket s'authentifie au JWT au "
    "handshake ; setAuth() capture le token UNE fois. Token expiré → les "
    "reconnexions auto réessaient avec l'ancien token → handshake AUTH_FAILED "
    "en boucle → messages chat / demandes d'amis JAMAIS livrés en direct "
    "jusqu'au re-login.",
    P))
flow.append(Paragraph(
    "<b>Confort total :</b> POST /auth/refresh (token frais 365j à expiration "
    "glissante). L'app le rafraîchit silencieusement au démarrage et au retour "
    "de background, et propage le token au socket (updateAuthToken → reconnecte "
    "si mort). Token de session passé de 30j à 365j (authController, "
    "oneTimeTokenController, userController). Résultat : plus de \"Session "
    "expirée\" pour un user actif + temps réel toujours vivant.",
    P))
flow.append(Paragraph(
    "<b>Annulation 72h :</b> le bouton était gaté sur paymentStatus=='paid' "
    "mais certains chemins backend renvoient un booking payé sans ce champ. "
    "Fallback dans booking_model : status=='paid' OU paidAt présent → 'paid'. "
    "Bouton réaffiché sur owner/sitter/walker.",
    P))

flow.append(Paragraph("Round 2 — Demande de suivi + conv ami (v255b)", H2))
flow.append(Paragraph(
    "<b>Demande de suivi invisible (3 profils) :</b> requestLiveTracking "
    "(/bookings/:id/follow-request) diffusait via require('../sockets/io') — "
    "un module INEXISTANT → throw avalé → carte pawfollow_request créée en DB "
    "mais jamais poussée en temps réel (+ mauvaise room). FIX : emitChatMessage "
    "(room conversation + user-rooms participants). Push notif corrigé : owner "
    "demande → notifie le provider ; provider demande → notifie l'owner.",
    P))
flow.append(Paragraph(
    "<b>Conversation ami en doublon :</b> l'idempotence comparait "
    "participants.userId (ObjectId) à des strings → pas de match → nouvelle "
    "conv créée à chaque tap. FIX : cast ObjectId explicite.",
    P))

flow.append(Paragraph("Round 3 — Adresse/tél + badge amis + i18n (v255c)", H2))
flow.append(Paragraph(
    "- Envoi d'adresse : emitToConversation → emitChatMessage (carte adresse "
    "en direct + badge sur les 3 profils).<br/>"
    "- Envoi de téléphone : AUCUN broadcast n'existait → ajouté.<br/>"
    "- Badge demandes d'amis : pastille rouge avec compteur sur le quick "
    "bouton \"Famille &amp; Amis\" de la PawMap (Obx temps réel).<br/>"
    "- i18n : la ligne d'estimation \"X min · Y prestataire + Z commission\" "
    "était FR hardcodée (affichée en FR partout) → migrée en .trParams, "
    "traduite 6 langues.",
    P))

flow.append(Paragraph("Round 4 — Messages paiement i18n + delete conv (v255d)", H2))
flow.append(Paragraph(
    "<b>Messages système paiement traduits par lecteur :</b> \"Paiement "
    "confirmé\" / \"Discutons du rendez-vous\" avaient un body figé dans la "
    "langue de l'owner en DB (défaut fr) → affichés en français même en UI "
    "espagnole. FIX : metadata.kind côté backend + systemDisplayText côté app "
    "qui rend le texte dans la langue COURANTE de chaque viewer (+ 2 clés × 6 "
    "langues).",
    P))
flow.append(Paragraph(
    "<b>Suppression de conversation non-destructive :</b> AVANT = hard delete "
    "messages + conv pour LES 2 parties → l'autre réécrivait = 404, jamais de "
    "réapparition. MAINTENANT = soft-delete par user (Conversation.clearedFor) "
    ": masque pour moi seulement ; l'autre garde la conv ; tout nouveau message "
    "vide clearedFor → la conversation RÉAPPARAÎT (type WhatsApp). Hard delete "
    "seulement si les 2 l'ont supprimée.",
    P))

flow.append(PageBreak())

# ─── iOS build steps ──────────────────────────────────────────────────────
flow.append(Paragraph("Build iOS — étapes Xcode", H1))

flow.append(Paragraph("Pré-requis", H2))
flow.append(Paragraph(
    "Mac avec macOS Sonoma 14.5+ recommandé. Xcode 15.4+ (CLT installés). "
    "Flutter SDK 3.27+ (canal stable). CocoaPods 1.15+. Apple Developer "
    "Program actif (compte Daniel — Team ID dans Xcode &gt; Settings &gt; "
    "Accounts).",
    P))

flow.append(Paragraph("Étape 1 — Pull du code v255", H2))
flow.append(Paragraph(
    "git pull origin main<br/>"
    "cd frontend &amp;&amp; flutter clean &amp;&amp; flutter pub get<br/>"
    "cd ios &amp;&amp; pod install --repo-update",
    CODE))

flow.append(Paragraph("Étape 2 — Smoke tests v255", H2))
flow.append(Paragraph(
    "Tester sur device iOS physique (après une PREMIÈRE reconnexion) :", P))
flow.append(Paragraph(
    "• <b>Temps réel</b> : recevoir un message chat / une demande d'ami SANS "
    "deco-reco → apparaît instantanément.<br/>"
    "• <b>Session</b> : plus de \"Session expirée\" ; le token se rafraîchit "
    "au lancement et au retour de background.<br/>"
    "• <b>Demande de suivi</b> : envoyer \"suivre mon animal\" → la carte "
    "s'affiche en direct chez l'autre, sur les 3 profils.<br/>"
    "• <b>Adresse / téléphone</b> : le partage s'affiche en direct.<br/>"
    "• <b>Badge amis</b> : pastille rouge sur le bouton \"Famille &amp; Amis\" "
    "de la PawMap quand demande en attente.<br/>"
    "• <b>Langue</b> : messages système paiement + ligne d'estimation dans la "
    "langue de l'app (plus de FR en UI ES).<br/>"
    "• <b>Supprimer une conv</b> : elle disparaît chez toi seulement ; quand "
    "la personne réécrit, elle réapparaît.<br/>"
    "• <b>Annulation 72h</b> : bouton présent sur les résa payées &gt;72h.<br/>"
    "• Écrire à un ami depuis l'onglet Amis → ouvre la conv existante (pas de "
    "doublon).",
    P))

flow.append(Paragraph("Étape 3 — Archive Xcode", H2))
flow.append(Paragraph(
    "1. open ios/Runner.xcworkspace<br/>"
    "2. Target Runner, scheme Runner, destination = Any iOS Device<br/>"
    "3. Product &gt; Archive (Cmd+B en Release d'abord pour valider)<br/>"
    "4. Organizer &gt; Distribute App &gt; App Store Connect<br/>"
    "5. Upload (TestFlight d'abord recommandé)",
    P))

flow.append(PageBreak())

# ─── Rollback ────────────────────────────────────────────────────────────
flow.append(Paragraph("Rollback", H1))
flow.append(Paragraph(
    "Si bug critique en prod : App Store Connect &gt; Phased Release &gt; Pause, "
    "puis git revert des commits v255* selon le scope. Render + Vercel "
    "redeploient auto. Le PDF v23.1.254 (dans Downloads) reste valide.",
    P))
flow.append(Paragraph(
    "<b>ATTENTION rollback :</b> ne PAS revert le token 365j / refresh ni le "
    "soft-delete clearedFor sans raison — revert réintroduit \"Session "
    "expirée\" et la suppression destructive pour les 2 parties. Le champ "
    "Conversation.clearedFor est additif (non-breaking).",
    RED))
flow.append(Paragraph(
    "v23.1.255 : aucune migration DB destructive → rollback safe.",
    GREEN))

flow.append(PageBreak())

# ─── Files ──────────────────────────────────────────────────────────────
flow.append(Paragraph("Fichiers clés v255 (référence)", H1))
flow.append(Paragraph("Backend (Render auto-deploy)", H2))
flow.append(Paragraph(
    "- controllers/authController.js — POST /auth/refresh + JWT 365j<br/>"
    "- controllers/oneTimeTokenController.js, userController.js — JWT 365j<br/>"
    "- routes/authRoutes.js — route /auth/refresh<br/>"
    "- controllers/bookingController.js — emitChatMessage suivi live + notif "
    "destinataire + metadata.kind paiement<br/>"
    "- controllers/conversationController.js — startFriendConversation cast "
    "ObjectId + filtre clearedFor + reset clearedFor sur nouveau message<br/>"
    "- routes/conversationRoutes.js — share-address/phone emitChatMessage + "
    "DELETE soft-delete<br/>"
    "- models/Conversation.js — champ clearedFor",
    P))
flow.append(Paragraph("Frontend Flutter", H2))
flow.append(Paragraph(
    "- pubspec.yaml — 23.1.254+254 → 23.1.255+255<br/>"
    "- services/socket_service.dart — updateAuthToken (reconnect token frais)<br/>"
    "- controllers/auth_controller.dart — refreshToken() + onInit/resume<br/>"
    "- controllers/notifications_controller.dart — refresh au resume<br/>"
    "- repositories/auth_repository.dart, data/network/api_endpoints.dart — refresh<br/>"
    "- models/booking_model.dart — paymentStatus fallback (72h)<br/>"
    "- views/map/paw_map_screen.dart — badge demandes d'amis<br/>"
    "- views/service_provider/send_request_screen.dart — i18n breakdown<br/>"
    "- controllers/chat_controller.dart, sitter_chat_controller.dart — "
    "systemDisplayText<br/>"
    "- views/.../chat/*individual_chat_screen.dart — systemDisplayText<br/>"
    "- localization/translations/*.dart — clés breakdown + chat_system × 6 langues",
    P))

flow.append(Spacer(1, 0.5*cm))
flow.append(Paragraph(
    "Build : flutter build apk --release → app-release.apk (universal) copié "
    "dans Downloads/HopeTSIT_v23.1.255.apk. Push origin/main = Render + Vercel "
    "redeploy auto.",
    INFO))

doc.build(flow)
print(f"OK -> {OUT}")

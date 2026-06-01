"""
HopeTSIT iOS Build Guide v23.1.254 generator.

v254 = batch v250 + v251 + v252 + v253 + v254 + v254b :
  - v250 : full perf audit, app fluide tous Android (sans toucher design/techno)
  - v251 : verified badge = KYC only, sandbox banner hide robuste, slider
    "pres de chez moi" fluide, famille tab ajout membre, "autour de vous" fix
  - v252 : audit money flow (wallet credite + payout double-pay FIX),
    revision traductions 6 langues, audit crash, admin page, country picker,
    PawMap ouvre sur position user, design profils harmonise
  - v253 : pages publications modernisees, badges boost meme design 3 profils
  - v254 : audit notifications (8 templates manquants -> notif droppees FIX),
    boutons email {{emailLink}} (bug accolade simple FIX), deep links amis
  - v254b : traductions notifs selon langue (7 cles argent es/de/it/pt),
    bouton email live_tracking de/it/pt, accents italiens
"""
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, PageBreak,
)
from reportlab.lib.enums import TA_JUSTIFY

OUT = "C:/Users/Usuario/Downloads/HopeTSIT_iOS_Build_Guide_v23.1.254.pdf"

doc = SimpleDocTemplate(
    OUT, pagesize=A4,
    leftMargin=1.8*cm, rightMargin=1.8*cm,
    topMargin=1.8*cm, bottomMargin=1.8*cm,
    title="HopeTSIT iOS Build Guide v23.1.254",
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
flow.append(Paragraph("Version 23.1.254 (Build 254)", H2))
flow.append(Spacer(1, 0.4*cm))
flow.append(Paragraph(
    "Build guide &amp; changelog pour Xcode (Mac requis). Couvre le delta "
    "v23.1.249 → v23.1.254 — 6 rounds : audit perf tous Android, badge "
    "verifie KYC only, audit complet du flux d'argent (wallet + payout "
    "double-pay FIX), revision traductions, audit crash, design profils + "
    "publications harmonises, audit complet des notifications (8 templates "
    "manquants reparees) et des boutons email/push, parite des traductions "
    "selon la langue.",
    P))
flow.append(Spacer(1, 0.5*cm))
flow.append(Paragraph(
    "v23.1.254 — TL;DR : aucune migration DB destructive, aucun breaking "
    "change API. Backend (Render) + website (Vercel) deja deployes en prod. "
    "APK Android universal. Ce delta corrige 2 bugs ARGENT critiques "
    "(wallet jamais credite, double-payout) et 8 types de notifs qui "
    "etaient silencieusement perdues.",
    GREEN))

flow.append(PageBreak())

# ─── Changelog ───────────────────────────────────────────────────────────
flow.append(Paragraph("Changelog v23.1.254", H1))

flow.append(Paragraph("Round 1 — Audit perf, app fluide tous Android (v250)", H2))
flow.append(Paragraph(
    "Optimisations chirurgicales SANS toucher au design ni a la techno : "
    "const widgets, RepaintBoundary cibles, debounce sliders/recherche, "
    "reduction des rebuilds Obx, listes lazy. Objectif : fluidite sur les "
    "modeles Android bas/milieu de gamme.",
    P))

flow.append(Paragraph("Round 2 — Badge verifie + perf accueil + famille (v251)", H2))
flow.append(Paragraph(
    "- Badge \"Verifie\" : affiche UNIQUEMENT si KYC Persona "
    "(kycStatus==='verified'). Avant, le flag legacy le mettait sur TOUS "
    "les profils. Backend identityVerified recalcule, frontend retire le "
    "|| verified.<br/>"
    "- Banniere Persona Sandbox masquee de maniere robuste.<br/>"
    "- Slider \"Pres de chez moi\" de l'accueil : ne rame plus (debounce + "
    "rebuild cible).<br/>"
    "- Onglet Famille : bouton ajouter un membre + choix depuis liste "
    "amis/famille.<br/>"
    "- Carte \"Autour de vous\" ne reapparait plus en revenant sur la map.",
    P))

flow.append(Paragraph("Round 3 — Audit ARGENT + crash + design profils (v252)", H2))
flow.append(Paragraph(
    "<b>Bug ARGENT critique #1 — wallet jamais credite.</b> creditWallet "
    "etait appele avec le parametre <i>role:</i> au lieu de <i>userRole:</i> "
    "-&gt; throw 'invalid args' silencieusement avale -&gt; le solde walker/"
    "sitter restait a 0 EUR apres une mission payee. Corrige sur 3 sites "
    "dans bookingController.js.",
    P))
flow.append(Paragraph(
    "<b>Bug ARGENT critique #2 — double-payout possible.</b> Le statut "
    "WalletTransaction 'processing' n'etait pas dans l'enum -&gt; "
    "claimed.save() ValidationError -&gt; rollback a 'pending' APRES que "
    "le virement Airwallex etait deja parti -&gt; re-claim au tick suivant "
    "= double versement. Corrige en ajoutant 'processing' (et "
    "'debit_purchase') a l'enum WalletTransaction.",
    P))
flow.append(Paragraph(
    "- Revision complete des traductions 6 langues.<br/>"
    "- Audit crash : null derefs, casts non gardes, late init (post_model, "
    "notif firstWhere, int.parse).<br/>"
    "- Audit page admin navigateur (admin_dashboard.html).<br/>"
    "- Country picker : ne reste plus bloque sur Pakistan (fallback "
    "Get.deviceLocale countryCode ?? 'FR').<br/>"
    "- PawMap ouvre sur la position de l'user (getLastKnownPosition instant "
    "+ accuracy.medium + timeLimit 6s) au lieu de Paris.<br/>"
    "- Design des pages profil harmonise (walker = owner/sitter : chip "
    "couleur 38px, titres Poppins, sous-titres, chevrons).",
    P))

flow.append(Paragraph("Round 4 — Publications + badges boost (v253)", H2))
flow.append(Paragraph(
    "- Pages publications modernisees (plus jolies, pro, empty states "
    "soignes, PetPostCard partagee).<br/>"
    "- Widget partage BoostBadge (flamme orange-&gt;rouge + 🔥) et "
    "TopProviderBadge (gold premium) -&gt; meme design sur les 3 profils "
    "(sitter_card, walker_card, service_provider_card).",
    P))

flow.append(Paragraph("Round 5 — Audit notifications + boutons (v254)", H2))
flow.append(Paragraph(
    "<b>Bug critique — 8 types de notif silencieusement PERDUS.</b> Le "
    "notificationSender abandonne avant de persister/pousser si le template "
    "n'existe pas (pickTemplate -&gt; null). 8 types etaient EMIS sans "
    "template : l'user ne recevait JAMAIS kyc_verified, kyc_rejected, "
    "kyc_payment_succeeded, map_boost_activated, subscription_activated, "
    "profile_boost_activated, chat_addon_activated, "
    "application_rejected_other_accepted. Templates ajoutes dans les 6 "
    "langues. Cross-check : 43/43 types emis ont desormais un template.",
    P))
flow.append(Paragraph(
    "<b>Bug boutons email.</b> friend_request_received + "
    "live_tracking_request_received utilisaient {emailLink} (accolade "
    "simple = litteral, bouton casse) au lieu de {{emailLink}} : le moteur "
    "i18nTemplate ne substitue que {{...}}. Corrige sur toutes les langues.",
    P))
flow.append(Paragraph(
    "- emailLinkBuilder : routage des 8 nouveaux types vers les bonnes "
    "pages (kyc-&gt;/profile, boosts-&gt;/paw-spot, "
    "subscription-&gt;/subscription, chat_addon-&gt;/chat, "
    "amis/famille/live-&gt;/friends/live).<br/>"
    "- deep_link_service.dart : nouveau cas friends/amis/family/live -&gt; "
    "FriendsScreen.<br/>"
    "- notifications_screen.dart : tap sur notif amis/famille/suivi-live "
    "(avant no-op) -&gt; ouvre FriendsScreen (demandes actionnables).<br/>"
    "- website [...slug] : fallback desktop /friends -&gt; /friends/live.",
    P))

flow.append(Paragraph("Round 6 — Traductions notifs selon langue (v254b)", H2))
flow.append(Paragraph(
    "fr/en avaient 47 cles, es/de/it/pt seulement 40. Les 7 notifs d'ARGENT "
    "(wallet_credited, payout_initiated/completed/failed, "
    "withdrawal_initiated/completed/failed) tombaient sur le fallback "
    "FRANCAIS pour es/de/it/pt. Traduites proprement (variables "
    "{{amount}}/{{currency}}/{{reason}} preservees). Parite : 47 cles x 6 "
    "langues. Aussi : bouton email manquant ajoute a "
    "live_tracking_request_received (de/it/pt) + accents italiens corriges.",
    P))

flow.append(PageBreak())

# ─── iOS build steps ──────────────────────────────────────────────────────
flow.append(Paragraph("Build iOS — etapes Xcode", H1))

flow.append(Paragraph("Pre-requis", H2))
flow.append(Paragraph(
    "Mac avec macOS Sonoma 14.5+ recommande. Xcode 15.4+ (CLT installes). "
    "Flutter SDK 3.27+ (canal stable). CocoaPods 1.15+. Apple Developer "
    "Program actif (compte Daniel — Team ID configure dans Xcode &gt; "
    "Settings &gt; Accounts).",
    P))

flow.append(Paragraph("Etape 1 — Pull du code v254", H2))
flow.append(Paragraph(
    "git pull origin main<br/>"
    "cd frontend &amp;&amp; flutter clean &amp;&amp; flutter pub get<br/>"
    "cd ios &amp;&amp; pod install --repo-update",
    CODE))

flow.append(Paragraph("Etape 2 — Smoke tests v254", H2))
flow.append(Paragraph(
    "Tester sur device iOS physique :", P))
flow.append(Paragraph(
    "• <b>Argent</b> : payer une mission -&gt; le walker/sitter voit son "
    "solde wallet credite (plus 0 EUR). Lancer un retrait/payout -&gt; "
    "statut passe bien a 'processing' puis 'completed', sans double "
    "versement.<br/>"
    "• <b>Notifications</b> : valider un KYC -&gt; notif \"Identite "
    "verifiee\" recue (push + in-app + email). Acheter un boost/abonnement "
    "-&gt; notif de confirmation recue.<br/>"
    "• <b>Boutons email</b> : ouvrir un email (demande d'ami, suivi live) "
    "-&gt; le bouton ouvre l'app (FriendsScreen) ou /friends/live sur le "
    "web. Plus de bouton casse pointant vers le texte {emailLink}.<br/>"
    "• <b>Tap notif</b> : taper une notif amis/famille/suivi -&gt; ouvre "
    "l'ecran Amis (avant : rien).<br/>"
    "• <b>Langue</b> : changer la langue de l'app (es/de/it/pt) -&gt; les "
    "notifs d'argent s'affichent dans la bonne langue (plus de francais).<br/>"
    "• <b>Badge verifie</b> : visible uniquement sur les profils KYC "
    "verifies.<br/>"
    "• <b>PawMap</b> : s'ouvre sur ta position, pas Paris.",
    P))

flow.append(Paragraph("Etape 3 — Archive Xcode", H2))
flow.append(Paragraph(
    "1. open ios/Runner.xcworkspace<br/>"
    "2. Target Runner selectionne, scheme Runner, destination = Any iOS Device<br/>"
    "3. Product &gt; Archive (Cmd+B en mode Release d'abord pour valider)<br/>"
    "4. Organizer &gt; Distribute App &gt; App Store Connect<br/>"
    "5. Upload (TestFlight d'abord recommande)",
    P))

flow.append(PageBreak())

# ─── Rollback ────────────────────────────────────────────────────────────
flow.append(Paragraph("Rollback procedure", H1))
flow.append(Paragraph(
    "Si bug critique en prod :<br/>"
    "1. App Store Connect &gt; Phased Release &gt; Pause<br/>"
    "2. git revert du commit de version bump puis revert des commits selon "
    "le scope (b7fc2b8 traductions notifs, e177126 audit notifs/boutons, "
    "+ commits v250-v253 selon besoin)<br/>"
    "3. Render redeploy auto, Vercel redeploy auto<br/>"
    "4. Le PDF v23.1.249 (deja dans Downloads) reste valide pour fallback iOS",
    P))
flow.append(Paragraph(
    "<b>ATTENTION rollback ARGENT.</b> Les fixes wallet (userRole) et "
    "payout (enum 'processing') sont des corrections de bugs : revert "
    "REINTRODUIT le solde a 0 et le risque de double-payout. Ne PAS "
    "rollback ces deux-la sauf regression prouvee ailleurs.",
    RED))
flow.append(Paragraph(
    "v23.1.254 n'introduit aucune migration DB destructive ni breaking "
    "change API → rollback du reste safe sans coordination speciale.",
    GREEN))

flow.append(PageBreak())

# ─── Files modified ──────────────────────────────────────────────────────
flow.append(Paragraph("Fichiers cles v250→v254 (reference)", H1))

flow.append(Paragraph("Backend (Render auto-deploy)", H2))
flow.append(Paragraph(
    "- backend/src/controllers/bookingController.js — creditWallet "
    "role-&gt;userRole (x3) [FIX argent]<br/>"
    "- backend/src/models/WalletTransaction.js — enum +processing "
    "+debit_purchase [FIX double-payout]<br/>"
    "- backend/src/utils/sanitize.js — identityVerified = KYC only<br/>"
    "- backend/src/utils/emailLinkBuilder.js — routage 8 types + friends<br/>"
    "- backend/src/locales/{fr,en,es,de,it,pt}/notifications.json — "
    "+8 templates manquants, fix {{emailLink}}, +7 cles argent es/de/it/pt, "
    "parite 47 cles x 6 langues",
    P))

flow.append(Paragraph("Frontend Flutter", H2))
flow.append(Paragraph(
    "- frontend/pubspec.yaml — 23.1.249+249 → 23.1.254+254<br/>"
    "- frontend/lib/services/deep_link_service.dart — cas friends/family/"
    "live -&gt; FriendsScreen<br/>"
    "- frontend/lib/views/notifications/notifications_screen.dart — tap "
    "notif amis/famille/suivi -&gt; FriendsScreen<br/>"
    "- frontend/lib/services/location_service.dart — getLastKnownPosition "
    "fallback (PawMap position)<br/>"
    "- frontend/lib/widgets/boost_badge.dart (NEW) — BoostBadge + "
    "TopProviderBadge partages<br/>"
    "- frontend/lib/views/pet_walker/profile/walker_profile_screen.dart — "
    "design harmonise<br/>"
    "- frontend/lib/localization/translations/*.dart — revision 6 langues",
    P))

flow.append(Paragraph("Website Next.js (Vercel auto-deploy)", H2))
flow.append(Paragraph(
    "- website/src/app/[...slug]/page.tsx — fallback friends -&gt; "
    "/friends/live",
    P))

flow.append(Spacer(1, 0.6*cm))
flow.append(Paragraph(
    "Build : flutter build apk --release a genere app-release.apk "
    "(universal, toutes ABI) copie dans Downloads/HopeTSIT_v23.1.254.apk. "
    "Push origin/main = Render + Vercel redeploy auto. HEAD : b7fc2b8 "
    "(avant version bump).",
    INFO))

doc.build(flow)
print(f"OK -> {OUT}")

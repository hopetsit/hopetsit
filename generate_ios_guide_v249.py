"""
HopeTSIT iOS Build Guide v23.1.249 generator.

v249 = batch v246 + v247 + v248 + v248b + v249 (5 rounds) :
  - Website /friends/live deep upgrade : tiles cliquables, family section,
    halo violet famille, follow-all, badge pending (v246+v248)
  - Persona sandbox banner hide + verified badge KYC pretty (v247)
  - Website /chat : delete + new conv button avec friend picker modal
    (v248+v248b)
  - Mobile : quick action police 10.5sp+FittedBox, halo violet famille
    robust, photo profil dans marker avec ring role+violet (v248+v249)
  - Backend : KYC poll fallback, fetchUserMini avatar URL,
    /family/members case-insensitive + family circle expanded (v247+v249)
"""
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, PageBreak,
)
from reportlab.lib.enums import TA_JUSTIFY

OUT = "C:/Users/Usuario/Downloads/HopeTSIT_iOS_Build_Guide_v23.1.249.pdf"

doc = SimpleDocTemplate(
    OUT, pagesize=A4,
    leftMargin=1.8*cm, rightMargin=1.8*cm,
    topMargin=1.8*cm, bottomMargin=1.8*cm,
    title="HopeTSIT iOS Build Guide v23.1.249",
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

flow = []

# ─── Cover ────────────────────────────────────────────────────────────────
flow.append(Paragraph("HopeTSIT — iOS Build Guide", H1))
flow.append(Paragraph("Version 23.1.249 (Build 249)", H2))
flow.append(Spacer(1, 0.4*cm))
flow.append(Paragraph(
    "Build guide & changelog pour Xcode (Mac requis). Couvre le delta "
    "v23.1.245 → v23.1.249 — 5 rounds successifs : refonte deep "
    "/friends/live website (family section, follow-all, tiles cliquables), "
    "Persona sandbox hide + KYC badge premium, page /chat web avec delete "
    "+ new conv modal friend picker, quick action police mobile, halo "
    "violet famille robuste, photo profil dans markers Google Map mobile.",
    P))
flow.append(Spacer(1, 0.5*cm))
flow.append(Paragraph(
    "v23.1.249 — TL;DR : aucune migration DB, aucun breaking change API. "
    "Backend + website (Vercel) déjà déployés en prod. APK Android "
    "92.4 MB universal. Le PDF v23.1.245 (toujours valide pour rollback) "
    "est dans /Downloads aussi.",
    GREEN))

flow.append(PageBreak())

# ─── Changelog ───────────────────────────────────────────────────────────
flow.append(Paragraph("Changelog v23.1.249", H1))

flow.append(Paragraph("Round 1 — Website /friends/live deep upgrade (v246)", H2))
flow.append(Paragraph(
    "Refonte complete : tiles cliquables -&gt; flyTo + open popup, "
    "section Famille separee + halo violet, getMyFamily() API helper, "
    "synthetic FriendItems pour family members hors-friend-list. Liens "
    "depuis /dashboard et /pawmap.",
    P))

flow.append(Paragraph("Round 2 — Persona sandbox banner + badge KYC pretty (v247)", H2))
flow.append(Paragraph(
    "Bouton Persona ouvre OK mais bannière orange Sandbox visible -&gt; "
    "JS injection apres chaque page load qui hide tout element contenant "
    "le texte \"Sandbox environment\" (best-effort, robust).",
    P))
flow.append(Paragraph(
    "Backend KYC poll fallback : si webhook Persona pas fire ou signature "
    "mismatch, /kyc/status appelle persona.getInquiry() en synchrone pour "
    "verifier l'etat reel et flip kycStatus = 'verified' direct. Throttle "
    "30s par user pour eviter de hammer l'API. Notif push declenchee.",
    P))
flow.append(Paragraph(
    "Widget VerifiedBadge embellies : gradient bleu Material 800-&gt;600, "
    "ombre 30% opacity, icone verified_rounded blanche, texte i18n via "
    "kyc_badge_verified + tooltip kyc_badge_verified_tooltip. Wrapper "
    "MyKycVerifiedBadge reactive (lit /users/me/benefits + listen tick "
    "worker ActiveBenefitsRow). Ajoute a cote du role pill dans sitter + "
    "walker profile screens.",
    P))

flow.append(Paragraph("Round 3 — Website /chat delete + new conv (v248+v248b)", H2))
flow.append(Paragraph(
    "FAB-like bouton orange \"Nouvelle conversation\" en haut a droite "
    "qui ouvre une modale plein ecran de selection d'ami. Tap un ami -&gt; "
    "startFriendConversation() API helper (POST /conversations/friend) -&gt; "
    "openConversation auto. Bouton trash SVG par tile pour delete (window."
    "confirm + DELETE /conversations/:id existant). Empty state friendly "
    "i18n. Cle chat_new_conversation_btn ajoutee aux 6 langues website "
    "(elle existait en mobile mais pas en site).",
    P))

flow.append(Paragraph("Round 4 — Mobile quick action police + halo famille (v248)", H2))
flow.append(Paragraph(
    "Daniel : police trop grande sur certains tels low-end -&gt; cercle "
    "icone 38-&gt;34px, padding 12v/6h -&gt;10v/4h, label 12sp-&gt;10.5sp + "
    "FittedBox.scaleDown anti-overflow sur traductions longues (allemand "
    "Warnungen, italien Avvisi).",
    P))
flow.append(Paragraph(
    "Halo violet famille app : robustesse familyMemberIds (id ET userId "
    "fallback, trim + lowercase), normalisation symetrique pos.userId, Obx "
    "GoogleMap declare familyMembers.length comme dependance reactive "
    "explicite (avant : il fallait attendre le tick halo 600ms).",
    P))

flow.append(Paragraph("Round 5 — Backend famille + photo halo mobile (v249)", H2))
flow.append(Paragraph(
    "Daniel : \"ps famille nest tjr pas rajouter ds le site web\". Backend "
    "/friends/family/members refondu :",
    P))
flow.append(Paragraph(
    "- Query case-insensitive sur userModel (cherche 'Owner' ET 'owner') "
    "-&gt; matche les subs avec format mixed-case<br/>"
    "- Couvre maintenant les 2 cas : je suis TITULAIRE de la sub (existant) "
    "OU je suis MEMBRE de la sub d'un autre (nouveau).<br/>"
    "- Aggregation Map<id, entry> pour dedup, retourne la famille étendue "
    "(titulaire + autres membres + moi-meme exclus).<br/>"
    "- hasActiveFamilyPlan plus permissif (true si titulaire OR membre).<br/>"
    "- remainingSlots ne compte que MA sub (si j'en ai une).",
    P))
flow.append(Paragraph(
    "<b>Photo profil dans marker mobile</b> — parite design website :",
    P))
flow.append(Paragraph(
    "Nouveau service FriendMarkerService :<br/>"
    "- getOrPlaceholder(userId, avatarUrl, role, isFamily) synchrone : "
    "retourne le bitmap cache ou un placeholder defaultMarkerWithHue<br/>"
    "- Build async non-bloquant : download bytes via http (timeout 5s), "
    "ui.PictureRecorder + Canvas 120x120<br/>"
    "- Layer 1 : ring violet pleine taille si famille<br/>"
    "- Layer 2 : disque couleur role (vert walker / bleu sitter / orange "
    "owner / silver fallback), inset 10px si famille<br/>"
    "- Layer 3 : bordure blanche fine separant photo et fond<br/>"
    "- Layer 4 : photo clip circulaire ou fallback emoji 👤<br/>"
    "- Export PNG -&gt; BitmapDescriptor.fromBytes()<br/>"
    "- Cache key partage entre PawMap re-openings<br/>"
    "- RxInt rev trigger Obx rebuild quand bitmap pret<br/>"
    "- Marker anchor (0.5, 0.5) car bitmap carre",
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

flow.append(Paragraph("Etape 1 — Pull du code v249", H2))
flow.append(Paragraph(
    "git pull origin main<br/>"
    "cd frontend &amp;&amp; flutter clean &amp;&amp; flutter pub get<br/>"
    "cd ios &amp;&amp; pod install --repo-update",
    CODE))

flow.append(Paragraph("Etape 2 — Smoke tests v249", H2))
flow.append(Paragraph(
    "Tester sur device iOS physique :", P))
flow.append(Paragraph(
    "• PawMap : tes amis et famille apparaissent maintenant avec leur "
    "<b>photo de profil</b> dans un cercle avec bordure couleur role "
    "(walker vert, sitter bleu, owner orange). Les membres famille ont "
    "en plus un <b>anneau exterieur violet</b>.<br/>"
    "• Quick action buttons : police plus petite (10.5sp), tous les "
    "labels lisibles dans les 6 langues sans overflow.<br/>"
    "• KYC verifie : badge bleu gradient \"Vérifié\" visible a cote de la "
    "role pill dans Profil sitter/walker. Status change instantanement "
    "apres validation Persona (poll fallback backend).<br/>"
    "• Webview Persona : banniere orange Sandbox masquee.",
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
    "2. git revert af8c73a (version bump) puis revert des commits selon "
    "le scope du rollback (a700682 mobile photo, ea55af3 backend famille, "
    "6c0496f modal friend, 3732af9 chat batch)<br/>"
    "3. Render redeploy auto, Vercel redeploy auto<br/>"
    "4. Le PDF v23.1.245 (deja dans Downloads) reste valide pour fallback iOS",
    P))

flow.append(Paragraph(
    "v23.1.249 n'introduit aucune migration DB ni breaking change API → "
    "rollback safe sans coordination speciale.",
    GREEN))

flow.append(PageBreak())

# ─── Files modified ──────────────────────────────────────────────────────
flow.append(Paragraph("Fichiers modifies v249 (reference)", H1))

flow.append(Paragraph("Backend (Render auto-deploy)", H2))
flow.append(Paragraph(
    "- backend/src/controllers/kycController.js — KYC poll Persona fallback<br/>"
    "- backend/src/routes/friendRoutes.js — fetchUserMini avatar URL flat, "
    "family/members case-insensitive + family circle expanded",
    P))

flow.append(Paragraph("Frontend Flutter", H2))
flow.append(Paragraph(
    "- frontend/pubspec.yaml — 23.1.245+245 → 23.1.249+249<br/>"
    "- frontend/lib/services/friend_marker_service.dart (NEW) — bitmap "
    "marker avec photo + ring role + ring famille<br/>"
    "- frontend/lib/views/map/paw_map_screen.dart — integration service "
    "+ quick action police 10.5sp + halo famille robuste<br/>"
    "- frontend/lib/widgets/verified_badge.dart — refonte gradient<br/>"
    "- frontend/lib/widgets/my_kyc_verified_badge.dart (NEW) — wrapper "
    "reactive auto-refresh<br/>"
    "- frontend/lib/views/pet_sitter/profile/sitter_profile_screen.dart — "
    "badge KYC a cote role pill<br/>"
    "- frontend/lib/views/pet_walker/profile/walker_profile_screen.dart — id<br/>"
    "- frontend/lib/views/kyc/kyc_verification_screen.dart — Persona "
    "sandbox banner JS hide + notifyChanged() trigger<br/>"
    "- frontend/lib/views/friends/friends_screen.dart — auto badge retire, "
    "i18n dialog<br/>"
    "- frontend/lib/views/pet_owner/chat/chat_screen.dart + "
    "pet_sitter/chat/sitter_chat_screen.dart — FAB Nouvelle conversation<br/>"
    "- frontend/lib/localization/translations/*.dart — +30 cles x 6 langues "
    "= 180 traductions sur tous les rounds",
    P))

flow.append(Paragraph("Website Next.js (Vercel auto-deploy)", H2))
flow.append(Paragraph(
    "- website/src/app/friends/live/page.tsx — refonte deep + family "
    "section + follow-all + pending badge<br/>"
    "- website/src/components/FriendsLiveMap.tsx — selectedUserId, "
    "fitAllNonce, ring violet famille, openPopup<br/>"
    "- website/src/app/chat/page.tsx — header CTA + modal friend picker + "
    "trash button per tile + i18n<br/>"
    "- website/src/lib/api.ts — getMyFamily, getFriendLastPosition, "
    "startFriendConversation, deleteConversation + types<br/>"
    "- website/src/lib/i18n/translations.ts — +20 cles x 6 langues<br/>"
    "- website/src/app/pawmap/page.tsx — CTA secondaire vers /friends/live<br/>"
    "- website/src/app/dashboard/page.tsx — NavCard \"Mes amis en direct\"",
    P))

flow.append(Spacer(1, 0.6*cm))
flow.append(Paragraph(
    "Build : flutter build apk --release a genere app-release.apk "
    "(~92.4 MB) copie dans Downloads/HopeTSIT_v23.1.249.apk. Push origin/main "
    "= Render + Vercel redeploy auto. HEAD : af8c73a.",
    INFO))

doc.build(flow)
print(f"OK -> {OUT}")

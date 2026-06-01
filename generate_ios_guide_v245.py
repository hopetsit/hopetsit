"""
HopeTSIT iOS Build Guide v23.1.245 generator.

v245 = batch v244 + v244b + v244c + v244d :
  - Persona webview camera access (v244)
  - Mes amis tab : auto badge supprime, photos profil, msg icon, tab
    Messages supprime, i18n deep audit (v244b)
  - FAB "Nouvelle conversation" sur chat list, 6 langues (v244c)
  - Halo famille outline violet (option Daniel : couleur role + ring
    violet) + Vercel build TS fix (v244d)
"""
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, PageBreak,
)
from reportlab.lib.enums import TA_JUSTIFY

OUT = "C:/Users/Usuario/Downloads/HopeTSIT_iOS_Build_Guide_v23.1.245.pdf"

doc = SimpleDocTemplate(
    OUT, pagesize=A4,
    leftMargin=1.8*cm, rightMargin=1.8*cm,
    topMargin=1.8*cm, bottomMargin=1.8*cm,
    title="HopeTSIT iOS Build Guide v23.1.245",
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
flow.append(Paragraph("Version 23.1.245 (Build 245)", H2))
flow.append(Spacer(1, 0.4*cm))
flow.append(Paragraph(
    "Build guide & changelog pour Xcode (Mac requis). Couvre le delta "
    "v23.1.244 → v23.1.245 — 4 rounds de bug fix successifs : KYC "
    "Persona camera, refonte onglet Mes amis (auto badge, photos, "
    "Messages tab supprime), FAB Nouvelle conversation sur Chat, halo "
    "famille avec contour violet, i18n deep audit, fix Vercel.",
    P))
flow.append(Spacer(1, 0.5*cm))
flow.append(Paragraph(
    "v23.1.245 — TL;DR : aucune migration DB, aucun breaking change. "
    "Backend + website (Vercel) deja deployes en prod. APK Android "
    "92+ MB universal. Le PDF v23.1.244 (toujours valide pour rollback) "
    "est dans /Downloads aussi.",
    GREEN))

flow.append(PageBreak())

# ─── Changelog v245 ───────────────────────────────────────────────────────
flow.append(Paragraph("Changelog v23.1.245", H1))

flow.append(Paragraph("Round 1 — Persona webview camera (v244)", H2))
flow.append(Paragraph(
    "Daniel screenshot : Persona ouvert OK (le fallback URL v243 marche), "
    "mais bloque a l'etape camera \"Impossible d'acceder a la camera\".",
    P))
flow.append(Paragraph(
    "<b>Root causes triple</b> :<br/>"
    "1. AndroidManifest.xml manquait RECORD_AUDIO — Persona demande le "
    "micro pour le liveness check<br/>"
    "2. WebView Android refuse getUserMedia par defaut (pas de "
    "PermissionRequest handler)<br/>"
    "3. iOS WKWebView bloque inline media playback par defaut",
    P))
flow.append(Paragraph(
    "<b>Fix</b> :<br/>"
    "- AndroidManifest : ajout permission RECORD_AUDIO<br/>"
    "- _onStartVerification : pre-request CAMERA + MICROPHONE via "
    "permission_handler avec messages i18n friendly si refus/refus "
    "permanent (openAppSettings)<br/>"
    "- _PersonaWebViewScreen : platform-specific creation params — "
    "WKWebKit allowsInlineMediaPlayback=true + mediaTypesRequiringUserAction "
    "vide sur iOS ; AndroidWebViewController.setOnPlatformPermissionRequest "
    "grant tout (camera + audio) sur Android<br/>"
    "- mediaPlaybackRequiresUserGesture=false sur Android pour que "
    "Persona auto-start la camera<br/>"
    "- 4 cles i18n (kyc_perm_blocked_title/_msg + kyc_perm_camera_title/_msg) "
    "x 6 langues",
    P))

flow.append(Paragraph("Round 2 — Mes amis tab refonte (v244b)", H2))

flow.append(Paragraph("Toggle Auto bloque", H3))
flow.append(Paragraph(
    "Daniel : la switch \"Partager position\" semblait verrouillee meme "
    "apres le fix v243 round 2 (backend OK). Cause UI : le badge \"Auto\" "
    "sous la switch faisait croire au user qu'elle etait read-only. "
    "Fix : suppression du badge Auto. Label uniforme \"Partager\" "
    "toujours visible sous la switch.",
    P))

flow.append(Paragraph("Photos profil manquantes", H3))
flow.append(Paragraph(
    "Daniel : les amis dans la liste apparaissent avec placeholder gris "
    "au lieu de leurs vraies photos. Root cause backend : fetchUserMini "
    "renvoyait <code>avatar: u.profilePicture || u.avatar</code> mais "
    "<code>u.avatar</code> est un objet <code>{url, publicId}</code> "
    "(Cloudinary), pas une string URL. Le cast frontend "
    "<code>(j['avatar'] as String?)</code> echouait silencieusement. "
    "Fix : helper <code>_avatarUrl({url, publicId}) -&gt; string</code> "
    "applique dans fetchUserMini. Photos visibles immediatement apres "
    "redeploy Render (sans rebuild APK).",
    P))

flow.append(Paragraph("Onglet Messages supprime", H3))
flow.append(Paragraph(
    "Daniel : \"longlet a droite message efface le y sert pas\". Le tab "
    "doublonnait l'onglet Chat principal du bottom nav. Suppression : "
    "DefaultTabController length 5→4, le 5e Tab + _MessagesTab retire.",
    P))

flow.append(Paragraph("Icone message → chat 1-to-1", H3))
flow.append(Paragraph(
    "Code deja cable depuis v23.1.200 (_openFriendChatRoleAware → "
    "startFriendChat → /conversations/friend). Le fix avatar (point 2) "
    "resout la chaine en cascade : contactImage est maintenant une vraie "
    "URL string -&gt; le chat screen n'echoue plus a charger l'avatar. "
    "Logs debug ajoutes dans startFriendChat pour diagnostic futur.",
    P))

flow.append(Paragraph("i18n deep audit", H3))
flow.append(Paragraph(
    "Daniel : \"verifie bien les traductions deep\". Audit :<br/>"
    "- 0 cles manquantes entre fr/en/es/de/it/pt (parite 100%)<br/>"
    "- 6 cles orphelines (live_track_perm_denied, verified, etc.) creees<br/>"
    "- Top offenders fixes : owner_booking_detail_screen.dart "
    "_bookingStatusLabel + _paymentStatusLabel (10 strings En attente / "
    "Acceptee / Payee / etc. visibles a chaque consultation reservation), "
    "walk_tracking_screen.dart (5 strings UI), friends_screen.dart dialog "
    "ajout + empty state (6 strings)<br/>"
    "- Total : +21 cles x 6 langues = 126 traductions ajoutees",
    P))

flow.append(Paragraph("Round 3 — FAB Nouvelle conversation (v244c)", H2))
flow.append(Paragraph(
    "Daniel : \"dans chat rajote en bas a droite un bouton nouvelle "
    "conversation ou new chat et fais bien attention qui sois traduit "
    "dans tte les langue\".",
    P))
flow.append(Paragraph(
    "FloatingActionButton.extended ajoute sur chat_screen.dart (owner) "
    "+ sitter_chat_screen.dart (sitter/walker). Orange brand, icone "
    "chat_rounded + label texte. Tap -&gt; ouvre FriendsScreen onglet "
    "Mes amis -&gt; user tap 💬 a cote d'un ami -&gt; startFriendChat "
    "lance la conv. Cle <code>chat_new_conversation_btn</code> en "
    "6 langues (Nouvelle conversation / New chat / Nueva conversacion / "
    "Neuer Chat / Nuova conversazione / Nova conversa).",
    P))

flow.append(Paragraph("Round 4 — Halo famille + Vercel fix (v244d)", H2))

flow.append(Paragraph("Halo walker famille", H3))
flow.append(Paragraph(
    "Daniel : \"jai ajouter un walker a ma famille son halo ne cest pas "
    "changer en couleur violet ou laisse le halo vert et surligne le de "
    "violet se serai encore mieux\".",
    P))
flow.append(Paragraph(
    "<b>Root cause</b> : PawMap n'appelait jamais <code>loadFamily()</code> "
    "au mount -&gt; <code>familyMembers</code> vide -&gt; isFamily=false "
    "pour le walker -&gt; priorite violet jamais appliquee.",
    P))
flow.append(Paragraph(
    "<b>Choix design Daniel</b> (option preferee) : conserve la couleur "
    "du role (walker vert / sitter bleu / owner orange) + ajoute un cercle "
    "exterieur outline violet (rayon 80m vs 60m, stroke 3px, pas de fill). "
    "Le code couleur metier reste lisible et le statut famille est "
    "signale en plus.",
    P))
flow.append(Paragraph(
    "<b>Fix supplementaire</b> : <code>_friendController.loadFamily()</code> "
    "force dans initState de PawMap. Plus besoin d'avoir ouvert l'onglet "
    "Famille avant pour que ca marche.",
    P))

flow.append(Paragraph("Vercel build TS error", H3))
flow.append(Paragraph(
    "<code>website/src/app/friends/live/page.tsx:95</code> failed to "
    "compile. Type predicate <code>(p): p is FriendLivePosition</code> "
    "refusait parce que <code>satisfies FriendLivePosition</code> ne "
    "widen pas : l'inference gardait <code>role: \"walker\"|\"sitter\"|"
    "\"owner\"</code> (narrow) alors que FriendLivePosition accepte aussi "
    "\"family\". Fix : annotation explicite "
    "<code>Promise&lt;FriendLivePosition | null&gt;</code> sur l'async, "
    "annotation typee sur posResults, suppression du satisfies. "
    "Vercel build OK.",
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

flow.append(Paragraph("Etape 1 — Pull du code v245", H2))
flow.append(Paragraph(
    "git pull origin main<br/>"
    "cd frontend &amp;&amp; flutter clean &amp;&amp; flutter pub get<br/>"
    "cd ios &amp;&amp; pod install --repo-update",
    CODE))

flow.append(Paragraph("Etape 2 — Verification Info.plist", H2))
flow.append(Paragraph(
    "Verifier que NSCameraUsageDescription et NSMicrophoneUsageDescription "
    "sont presents dans ios/Runner/Info.plist (deja en place historiquement, "
    "rien a faire normalement). Sinon ajouter :",
    P))
flow.append(Paragraph(
    "&lt;key&gt;NSCameraUsageDescription&lt;/key&gt;<br/>"
    "&lt;string&gt;HopeTSIT a besoin de la camera pour la verification "
    "d'identite Persona (scan ID + selfie).&lt;/string&gt;<br/>"
    "&lt;key&gt;NSMicrophoneUsageDescription&lt;/key&gt;<br/>"
    "&lt;string&gt;HopeTSIT a besoin du microphone pour le liveness check "
    "Persona.&lt;/string&gt;",
    CODE))

flow.append(Paragraph("Etape 3 — Archive Xcode", H2))
flow.append(Paragraph(
    "1. open ios/Runner.xcworkspace<br/>"
    "2. Target Runner selectionne, scheme Runner, destination = Any iOS Device<br/>"
    "3. Product &gt; Archive (Cmd+B en mode Release d'abord pour valider)<br/>"
    "4. Organizer &gt; Distribute App &gt; App Store Connect<br/>"
    "5. Upload (TestFlight d'abord recommande pour smoke tests)",
    P))

flow.append(Paragraph("Etape 4 — Smoke tests v245", H2))
flow.append(Paragraph(
    "Tester sur device iOS physique apres TestFlight install :", P))
flow.append(Paragraph(
    "• KYC Persona : bouton Lancer verification → dialog camera+micro "
    "natif iOS s'affiche → accepte → webview Persona ouvre → reach scan "
    "ID → la camera s'allume (pas \"Impossible d'acceder\" comme avant)<br/>"
    "• Mes amis : tile d'un ami affiche sa vraie photo (pas Person grise). "
    "Toggle Partager position bascule ON↔OFF (plus de badge Auto qui "
    "embrouille). Onglet Messages disparu (4 tabs au lieu de 5). Tap 💬 "
    "ouvre conv 1-to-1.<br/>"
    "• Chat list : FAB orange \"Nouvelle conversation\" visible bottom-right. "
    "Tap → FriendsScreen. Langue Espagnol → \"Nueva conversación\".<br/>"
    "• PawMap : un walker famille -&gt; halo vert (role) + anneau exterieur "
    "violet visible. Walker non-famille -&gt; juste halo vert.<br/>"
    "• Booking detail : badge statut traduit correctement en ES/DE (avant "
    "c'etait \"En attente\" en dur en FR).<br/>"
    "• Walk tracking sitter : bouton \"Demarrer la balade\" / \"Terminer\" "
    "traduit selon langue.",
    P))

flow.append(Paragraph("Etape 5 — Perf check iPhone milieu de gamme", H2))
flow.append(Paragraph(
    "Tester sur iPhone SE 2020 ou iPhone 11. Ouvrir PawMap, scroller/zoomer "
    "30s, vérifier zero freeze. Background 1 min puis foreground : halo "
    "pulse reprend instantanement (preuve WidgetsBindingObserver v243 round 3).",
    INFO))

flow.append(PageBreak())

# ─── Rollback ────────────────────────────────────────────────────────────
flow.append(Paragraph("Rollback procedure", H1))
flow.append(Paragraph(
    "Si bug critique en prod :<br/>"
    "1. App Store Connect &gt; Phased Release &gt; Pause<br/>"
    "2. git revert 5df374e (version bump) puis revert des commits "
    "v244-d8ca195 / v244c-e424c51 / v244b-4d48806 / v244-3080fed selon "
    "le scope du rollback<br/>"
    "3. Render redeploy auto, Vercel redeploy auto<br/>"
    "4. Rebuild Android APK depuis main pre-v245 si necessaire<br/>"
    "5. Le PDF v23.1.244 (deja livre dans Downloads) reste valide pour "
    "fallback iOS",
    P))

flow.append(Paragraph(
    "v23.1.245 n'introduit aucune migration DB ni breaking change API → "
    "rollback safe sans coordination speciale.",
    GREEN))

flow.append(PageBreak())

# ─── Files modified ──────────────────────────────────────────────────────
flow.append(Paragraph("Fichiers modifies v245 (reference)", H1))

flow.append(Paragraph("Backend (Render auto-deploy)", H2))
flow.append(Paragraph(
    "- backend/src/routes/friendRoutes.js — fetchUserMini _avatarUrl pour "
    "aplatir l'objet Cloudinary vers string URL<br/>"
    "(Tout le reste backend etait deja en v244 deploye sur Render.)",
    P))

flow.append(Paragraph("Frontend Flutter", H2))
flow.append(Paragraph(
    "- frontend/pubspec.yaml — 23.1.244+244 → 23.1.245+245<br/>"
    "- frontend/android/app/src/main/AndroidManifest.xml — RECORD_AUDIO<br/>"
    "- frontend/lib/views/kyc/kyc_verification_screen.dart — Persona "
    "permission flow + webview camera/mic grant<br/>"
    "- frontend/lib/views/friends/friends_screen.dart — Messages tab "
    "supprime, badge Auto retire, dialog +ami i18n, empty state i18n<br/>"
    "- frontend/lib/controllers/friend_controller.dart — startFriendChat "
    "debug logs<br/>"
    "- frontend/lib/views/pet_owner/chat/chat_screen.dart — FAB Nouvelle "
    "conversation<br/>"
    "- frontend/lib/views/pet_sitter/chat/sitter_chat_screen.dart — meme FAB<br/>"
    "- frontend/lib/views/map/paw_map_screen.dart — halo famille outline "
    "violet + loadFamily au mount<br/>"
    "- frontend/lib/views/pet_owner/booking-application/owner_booking_detail_screen.dart — "
    "i18n booking_status_* + payment_status_*<br/>"
    "- frontend/lib/views/pet_sitter/walk/walk_tracking_screen.dart — "
    "i18n walk_*<br/>"
    "- frontend/lib/localization/translations/{fr,en,es,de,it,pt}.dart — "
    "+ 36 cles x 6 langues = 216 traductions",
    P))

flow.append(Paragraph("Website Next.js (Vercel auto-deploy)", H2))
flow.append(Paragraph(
    "- website/src/app/friends/live/page.tsx — fix TS narrow inference "
    "(annotation Promise&lt;FriendLivePosition | null&gt; explicite, "
    "suppression satisfies)",
    P))

flow.append(Spacer(1, 0.6*cm))
flow.append(Paragraph(
    "Build : flutter build apk --release a genere app-release.apk "
    "(~92 MB) copie dans Downloads/HopeTSIT_v23.1.245.apk. Push origin/main "
    "= Render + Vercel redeploy auto. HEAD : 5df374e.",
    INFO))

doc.build(flow)
print(f"OK -> {OUT}")

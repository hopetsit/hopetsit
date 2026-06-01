"""
HopeTSIT iOS Build Guide v23.1.240 generator.
Creates a comprehensive PDF guide for building the iOS app from the
current codebase, including all features delivered from v23.1.222 to
v23.1.240 (19 versions, frontend + minor backend).
"""
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak,
)
from reportlab.lib.enums import TA_LEFT, TA_JUSTIFY

OUT = "C:/Users/Usuario/Downloads/HopeTSIT_iOS_Build_Guide_v23.1.240.pdf"

doc = SimpleDocTemplate(
    OUT, pagesize=A4,
    leftMargin=1.8*cm, rightMargin=1.8*cm,
    topMargin=1.8*cm, bottomMargin=1.8*cm,
    title="HopeTSIT iOS Build Guide v23.1.240",
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
NOTE = ParagraphStyle('NOTE', parent=styles['BodyText'],
                     fontSize=9, leading=13, leftIndent=12, rightIndent=12,
                     textColor=colors.HexColor("#92400E"),
                     backColor=colors.HexColor("#FEF3C7"),
                     borderColor=colors.HexColor("#F59E0B"),
                     borderWidth=1, borderPadding=8)
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
                     fontSize=9, leading=13, leftIndent=12, rightIndent=12,
                     textColor=colors.HexColor("#991B1B"),
                     backColor=colors.HexColor("#FEE2E2"),
                     borderColor=colors.HexColor("#DC2626"),
                     borderWidth=1, borderPadding=8)

story = []

# ─────────────────────────────────────────────────────────────────────────
# COVER
# ─────────────────────────────────────────────────────────────────────────
story.append(Paragraph("HopeTSIT iOS Build Guide", H1))
story.append(Paragraph("Version 23.1.240 - May 27 2026", H2))
story.append(Spacer(1, 0.4*cm))

story.append(Paragraph(
    "<b>IMPORTANT — Le backend est deja deploye en production.</b><br/>"
    "Tout le backend (Render, MongoDB Atlas) est deja a jour avec la "
    "v23.1.240 (push git effectue le 27 mai 2026). L'API tourne sur "
    "https://hopetsit-backend.onrender.com et est immediatement consommable "
    "par l'app iOS sans aucune modification serveur.<br/><br/>"
    "Ce guide couvre UNIQUEMENT le build iOS de l'app Flutter. Aucune "
    "action requise cote backend / Render / DB. L'app iOS pointe sur la "
    "meme API que l'Android v23.1.240 (deja en prod, APK signe et "
    "fonctionnel).",
    GREEN))
story.append(Spacer(1, 0.5*cm))

story.append(Paragraph(
    "Guide complet pour builder l'app HopeTSIT sur iOS depuis le repo "
    "actuel. Couvre l'installation des dependances, la configuration "
    "Xcode + Apple Developer, les changements v23.1.222 -> v23.1.240 "
    "(19 versions cumulees), et le checklist final avant submission "
    "App Store Connect.", P))
story.append(Spacer(1, 0.4*cm))

# ─────────────────────────────────────────────────────────────────────────
# 1. NOUVEAUTES v222 -> v240
# ─────────────────────────────────────────────────────────────────────────
story.append(Paragraph("1. Nouveautes depuis v222 (19 versions)", H2))
story.append(Paragraph(
    "Highlights par lot — tout le code est dans le repo, pret a builder :", P))

changes = [
    ("v225",
        "Refactor majeur Friends + PawMap : FriendsScreen passe de 7 a 5 "
        "tabs (Amis / Demandes / Ajouter / Famille / Messages). Nouvelle "
        "PeopleLiveScreen autonome (la carte PawMap garde son quick-action "
        "vers cette page). Halo couleur sur la PawMap : vert pour walker / "
        "bleu pour sitter quand on les suit pendant une garde."),
    ("v226",
        "PawFollow auto-unlock du partage de position : si l'user a un "
        "PawFollow actif (perso ou Famille), le toggle 'Partager ma "
        "position' s'active automatiquement -> il apparait dans la liste "
        "'Personnes en live' de ses proches sans action manuelle. Redesign "
        "complet de la Famille tab (mockup Daniel) : hero card + cards "
        "inline 'Inviter par nom' / 'Inviter par email'."),
    ("v227",
        "Fix chat 403 : requirePaidBooking utilise maintenant aussi "
        "hasActivePawFollow comme bypass. Badge unread count sur l'icone "
        "Chat du bottom nav. Sitter visible cote Owner home meme si pas "
        "encore de geoloc partagee (visibility ultra-permissive). Home "
        "scrollable sur 3 profils via SingleChildScrollView."),
    ("v228",
        "Audit chat 403 deep + 5-level bypass align (middleware + service "
        "+ controller). Socket reconnect on app resume (lifecycle observer "
        "+ reconnectIfNeeded). Persona 409 Conflict v1 fix : retry "
        "findByReferenceId quand createInquiry renvoie 409."),
    ("v229",
        "Endpoint diagnostic /diagnostic/chat-access/:convId qui retourne "
        "JSON exhaustif sur POURQUOI un user est bloque (chaque step du "
        "bypass + verdict final). /version + /healthz pour verifier le "
        "deploy state. REVERT v229 shrinkWrap car perf low-end (Oppo)."),
    ("v230",
        "Revert NestedScrollView complet -> Column + Expanded(ListView) "
        "standard pour preserver lazy build (perf low-end devices). "
        "Trade-off : top de la home reste fixe pendant le scroll de la "
        "liste."),
    ("v231-v236",
        "Perf low-end Android (Daniel 'lag sur Oppo'): cap imageCache "
        "100MB->50MB. blurRadius 10->3 sur cardShadow (GPU 11x moins). "
        "memCacheWidth restants sur 28 CachedNetworkImage. cacheExtent 80 "
        "ListView. ClampingScrollPhysics global via _PerfScrollBehavior. "
        "Halo PawSpot Platinum : timer 200ms->600ms (5x moins CPU)."),
    ("v237",
        "Fix chat send message broken (chatAccessService bypass aligne). "
        "Quick actions Me suivre + Suivre ma famille (PawMap header). "
        "Follow animal message tap : LiveWalkMapScreen accepte fallback "
        "Lat/Lng + resolveFresh via /provider-location."),
    ("v238",
        "Fix chat 'Access denied for this conversation' (friendChat) cote "
        "getConversationMessages controller (manquait participants[] "
        "support + staff bypass + JWT instead of query params). GPS stream "
        "broadcast continu pendant que l'user bouge (avant : position "
        "freeze au moment du toggle)."),
    ("v239",
        "Personnes en live position v2 (3eme tentative) : tap sur un ami "
        "appelle /friends/:id/last-position pour avoir la position fresh "
        "DB au lieu du metadata stale. /conversations/:id/peer-position "
        "ajoute pour le 'Voir la carte' du chat. CityMatch fix v1 mais "
        "incomplet (distance restait 0 fake)."),
    ("v240",
        "<b>BATCH MAJEUR (cette release, 15 bugs corriges).</b> Voir la "
        "section 2 ci-dessous pour le detail complet."),
]

for ver, body in changes:
    story.append(Paragraph(f"<b>{ver}</b> — {body}", P))
    story.append(Spacer(1, 0.18*cm))

story.append(Spacer(1, 0.3*cm))

# ─────────────────────────────────────────────────────────────────────────
# 2. v240 DEEP DIVE
# ─────────────────────────────────────────────────────────────────────────
story.append(Paragraph("2. v240 detail (15 bugs corriges)", H2))
story.append(Paragraph(
    "Le batch v240 corrige 15 bugs identifies par Daniel dans cette "
    "session. Repartition mobile + backend + site web + admin dashboard :",
    P))

v240_items = [
    ("Carte 'Partage de position en attente'",
        "Sitter/walker requester pending : header dedie via nouvelle cle "
        "i18n 'pawfollow_share_position_pending' (6 langues)."),
    ("'Partager mon adresse pour RDV' (3 profils)",
        "Nouveau type Message 'address_share'. Endpoint POST "
        "/conversations/:id/share-address (owner/sitter/walker). Widget "
        "AddressShareCard stylé orange + bouton 'Itineraire' (deep-link "
        "Google Maps via url_launcher). Icone home dans AppBar des 2 chat "
        "screens (individual + sitter_individual)."),
    ("'Voir la carte' chat -> PawMap halo vert/bleu",
        "PawMapScreen accepte focusUserId/Role/Name. Injection synthetique "
        "FriendPosition dans LiveMapService -> halo couleur instantane. "
        "<b>FIX CRITIQUE :</b> _bootstrap() respecte initialLat/Lng (avant : "
        "ecrasait silencieusement avec position user)."),
    ("Personnes en live position correcte",
        "Tap sur un ami passe maintenant focusUserId/Role/Name -> halo "
        "violet (Owner) / vert (Walker) / bleu (Sitter). Position fresh "
        "via /friends/:id/last-position en fallback de socket."),
    ("'Me suivre' broadcast (root cause trouvee)",
        "LiveMapService.attach() etait UNIQUEMENT appele dans PawMapScreen "
        "init -> map:identify jamais emis si user n'ouvrait pas la map -> "
        "backend rejetait silencieusement les map:position-update. Fix : "
        "register le service au boot via SocketService.addOnConnectedHook "
        "dans les 3 nav wrappers."),
    ("Bug 403 'Effacer' conversation/message friendChat",
        "DELETE /conversations/:id et DELETE /:id/messages/:messageId "
        "supportent maintenant les conversations friendChat (lookup dans "
        "participants[] en plus de ownerId/sitterId/walkerId)."),
    ("Slider 'Pres de chez moi' deep fix",
        "Daniel : 'barre 0 = profile 0-50km'. Min 50km enforced sur 4 "
        "sliders (owner inline + modal, sitter inline + modal, "
        "reservation_request_filter_dialog). Backend cityMatch : Haversine "
        "reel (avant distance=0 fake -> affichait 'À 0.0 km' pour sitters "
        "a 200km). Walker controller expose enfin distance + "
        "distanceInMeters (parite sitter)."),
    ("Persona KYC 409 deep fix",
        "v228 corrigeait le 409 sur createInquiry mais PAS sur "
        "generateOneTimeLink. Fix v240 : getInquiry() check status terminal "
        "(completed/declined/expired) avant generateOneTimeLink. 409 "
        "recovery automatique : drop stored inquiryId + recreer + retry "
        "une fois."),
    ("App 'se ferme' en background (ROOT CAUSE)",
        "splash_screen.dart lisait le JWT UNIQUEMENT depuis GetStorage "
        "(legacy). v23.1 part 125 avait migre vers SecureTokenStore "
        "(Keystore Android). OS Samsung/Oppo tue le process -> cold restart "
        "-> splash trouvait null -> Onboarding -> user pensait que l'app "
        "se fermait. Fix : lecture en cascade SecureTokenStore + fallback "
        "GetStorage. Splash 2000ms -> 800ms."),
    ("Crash ecran noir post-paiement chat",
        "Get.delete<ChatController>(force) etait synchrone AVANT Get.offAll "
        "-> race condition Obx sur controller dispose. Fix : Get.delete "
        "differe via addPostFrameCallback, Get.offAll -> Get.off (plus "
        "chirurgical). sendMessage : try/catch autour _mapToChatMessage "
        "(garde optimistic message si parsing fail)."),
    ("Home owner scrollable (Slivers)",
        "Refactor body Scaffold de Column[fixed top + Expanded(ListView)] "
        "vers CustomScrollView(slivers). HomeQuickActionBar, "
        "ExpandablePostInput, SegmentedControl, DistanceSlider en "
        "SliverToBoxAdapter. Tabs retournent maintenant des Slivers "
        "(SliverList.builder lazy / SliverFillRemaining). Perf preservee "
        "(pas de regression v229)."),
    ("HD avatars sitter/walker card",
        "Avatars sans memCacheWidth -> decodage a la resolution originale "
        "(3000px+ pour photos haute qualite) = ~36MB RAM/image. Fix : "
        "CachedNetworkImageProvider(url, maxWidth: 180). 52dp x 3 DPR + "
        "buffer = HD preservee, memoire / 250x sur les originaux 4K."),
    ("i18n audit deep",
        "ES/DE/IT/PT manquaient les MEMES 118 cles (presentes FR/EN). "
        "Categories : alerts, family, friends, pawfollow_card, "
        "pawmap_quick_*, report categories, tracking_sheet. + 9 strings "
        "FR hardcoded dans friends_screen.dart + chat_access_upsell_helper "
        ".dart. Total : 472 traductions + 9 fixes."),
    ("Site web + admin dashboard v240",
        "Homepage Next.js : nouvelle section 'What's new v240' avec 4 "
        "feature cards (PawFollow Famille / PawSpot / Live position / "
        "Verified ID). FAQ etendue de 5 a 7 entrees. 72 traductions x 6 "
        "langues. Admin dashboard : title bumped + badge v240 + bandeau "
        "'Nouveautes v240' sur Tableau de bord + legende chat moderation."),
    ("Web walk/[bookingId] centrage corrige",
        "Meme bug que mobile : carte centree sur Paris jusqu'au premier "
        "event socket. Fix : nouveau helper getProviderLocation() qui hit "
        "/bookings/:id/provider-location au load. WalkLiveMap accepte "
        "walkerRole pour halo couleur (parite mobile : vert walker / bleu "
        "sitter). Circle halo Leaflet + makeProviderIcon dynamique."),
]

for title, body in v240_items:
    story.append(Paragraph(f"<b>{title}</b>", H3))
    story.append(Paragraph(body, P))
    story.append(Spacer(1, 0.1*cm))

story.append(PageBreak())

# ─────────────────────────────────────────────────────────────────────────
# 3. PREREQUIS iOS
# ─────────────────────────────────────────────────────────────────────────
story.append(Paragraph("3. Prerequis machine", H2))

prereq_data = [
    ["Element", "Version requise", "Verification"],
    ["macOS", "Sonoma 14.5+ ou Sequoia 15+", "About This Mac"],
    ["Xcode", "16.0 ou plus recent", "xcodebuild -version"],
    ["CocoaPods", "1.15+", "pod --version"],
    ["Flutter SDK", "3.27.1 (channel stable)", "flutter --version"],
    ["Dart SDK", ">=3.9.2 (inclus avec Flutter)", "dart --version"],
    ["Apple Developer", "Compte payant ($99/an)", "developer.apple.com"],
    ["Ruby (CocoaPods)", "3.0+ via rbenv ou system", "ruby --version"],
]
tab = Table(prereq_data, colWidths=[4*cm, 6*cm, 5*cm])
tab.setStyle(TableStyle([
    ('BACKGROUND', (0,0), (-1,0), colors.HexColor("#EF4324")),
    ('TEXTCOLOR', (0,0), (-1,0), colors.white),
    ('FONTNAME', (0,0), (-1,0), 'Helvetica-Bold'),
    ('FONTSIZE', (0,0), (-1,-1), 9),
    ('ROWBACKGROUNDS', (0,1), (-1,-1),
        [colors.HexColor("#FFF7ED"), colors.white]),
    ('GRID', (0,0), (-1,-1), 0.5, colors.HexColor("#FED7AA")),
    ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
    ('LEFTPADDING', (0,0), (-1,-1), 6),
    ('RIGHTPADDING', (0,0), (-1,-1), 6),
    ('TOPPADDING', (0,0), (-1,-1), 5),
    ('BOTTOMPADDING', (0,0), (-1,-1), 5),
]))
story.append(tab)
story.append(Spacer(1, 0.4*cm))

# ─────────────────────────────────────────────────────────────────────────
# 4. ETAPES DE BUILD
# ─────────────────────────────────────────────────────────────────────────
story.append(Paragraph("4. Etapes de build iOS", H2))

story.append(Paragraph("4.1 Cloner le repo et installer les dependances", H3))
story.append(Paragraph(
    "Le projet est sur GitHub (repo prive HopeTSIT/hopetsit). Cloner "
    "puis installer les dependances Flutter + CocoaPods :", P))
story.append(Paragraph(
    "git clone https://github.com/hopetsit/hopetsit.git<br/>"
    "cd hopetsit/frontend<br/>"
    "flutter pub get<br/>"
    "cd ios && pod install --repo-update && cd ..",
    CODE))
story.append(Spacer(1, 0.2*cm))

story.append(Paragraph("4.2 Verifier la version pubspec.yaml", H3))
story.append(Paragraph(
    "Le fichier frontend/pubspec.yaml doit afficher : "
    "<b>version: 23.1.240+240</b>. Le + suivi du build number est "
    "obligatoire pour l'App Store : il doit etre strictement superieur a "
    "celui du build precedent uploade sur App Store Connect.",
    P))
story.append(Paragraph(
    "grep version frontend/pubspec.yaml<br/>"
    "# version: 23.1.240+240",
    CODE))
story.append(Spacer(1, 0.2*cm))

story.append(Paragraph("4.3 Ouvrir Xcode workspace", H3))
story.append(Paragraph(
    "<b>Important :</b> utiliser le .xcworkspace, pas .xcodeproj "
    "(CocoaPods needs the workspace).", P))
story.append(Paragraph(
    "open ios/Runner.xcworkspace",
    CODE))
story.append(Spacer(1, 0.2*cm))

story.append(Paragraph("4.4 Configurer Signing & Capabilities", H3))
story.append(Paragraph(
    "Dans Xcode, selectionner la cible Runner > Signing & Capabilities :", P))
story.append(Paragraph(
    "&bull; <b>Team</b> : selectionner ton Apple Developer team<br/>"
    "&bull; <b>Bundle Identifier</b> : <i>com.hopetsit.app</i> (doit "
    "matcher l'App ID cree sur developer.apple.com)<br/>"
    "&bull; <b>Automatically manage signing</b> : ON (Xcode genere les "
    "certificats + profile provisioning)<br/>"
    "&bull; <b>Capabilities requises :</b> Push Notifications, Background "
    "Modes (Location updates, Remote notifications), Sign in with Apple, "
    "Associated Domains (applinks:hopetsit.com, applinks:www.hopetsit.com, "
    "applinks:app.hopetsit.com)",
    P))
story.append(Spacer(1, 0.2*cm))

story.append(Paragraph("4.5 Verifier Info.plist", H3))
story.append(Paragraph(
    "Permissions iOS qui doivent etre presentes dans ios/Runner/"
    "Info.plist (avec justification claire pour le review App Store) :", P))
permissions = [
    ("NSLocationWhenInUseUsageDescription",
        "PawMap (vétérinaires / parcs) + suivi GPS pendant les balades."),
    ("NSLocationAlwaysAndWhenInUseUsageDescription",
        "Permet aux walkers/sitters de partager leur position en arriere-"
        "plan pendant une balade (sinon owner ne voit rien quand l'app "
        "passe en background)."),
    ("NSCameraUsageDescription",
        "Photo profile + photos animaux + photos signalements (chien "
        "perdu, danger, etc.)."),
    ("NSPhotoLibraryUsageDescription",
        "Selection de photos depuis la galerie pour profile / animaux / "
        "annonces."),
    ("NSMicrophoneUsageDescription",
        "Notes audio futures (champ optionnel pour v25, deja declare pour "
        "eviter un rerelease)."),
    ("UIBackgroundModes",
        "[location, remote-notification, fetch] — fondamentaux pour le "
        "live tracking + push FCM + sync invoices."),
]
for k, desc in permissions:
    story.append(Paragraph(f"<b>{k}</b><br/>{desc}", P))
    story.append(Spacer(1, 0.12*cm))

story.append(Spacer(1, 0.2*cm))

story.append(Paragraph("4.6 Configurer Firebase iOS", H3))
story.append(Paragraph(
    "Le fichier ios/Runner/GoogleService-Info.plist doit etre present "
    "(c'est le fichier de config Firebase qui contient les cles iOS APNS "
    "+ FCM sender id). Si absent :", P))
story.append(Paragraph(
    "1. Firebase Console > Projet HopeTSIT > Project Settings > Your apps<br/>"
    "2. Cliquer sur l'app iOS (com.hopetsit.app)<br/>"
    "3. Telecharger GoogleService-Info.plist<br/>"
    "4. Glisser-deposer dans Xcode dans le dossier Runner (cocher 'Copy "
    "items if needed', cible Runner)",
    P))
story.append(Spacer(1, 0.2*cm))

story.append(Paragraph("4.7 Build de test sur simulateur", H3))
story.append(Paragraph(
    "Avant l'archive release, valider que ca compile :", P))
story.append(Paragraph(
    "flutter build ios --simulator --no-codesign<br/>"
    "# OU dans Xcode : Product > Build (Cmd+B)",
    CODE))
story.append(Spacer(1, 0.2*cm))

story.append(Paragraph("4.8 Archive release pour App Store", H3))
story.append(Paragraph(
    "Dans Xcode :", P))
story.append(Paragraph(
    "1. Selectionner <b>Any iOS Device (arm64)</b> dans le run destination<br/>"
    "2. Menu Product > Archive (compile ~10 min sur M1)<br/>"
    "3. Organizer s'ouvre une fois l'archive prete<br/>"
    "4. Cliquer <b>Distribute App</b> > App Store Connect > Upload<br/>"
    "5. Cocher 'Upload your app's symbols' (pour Crashlytics)<br/>"
    "6. Laisser 'Automatic signing' si Apple Developer est OK<br/>"
    "7. Attendre l'upload (~5 min) puis le processing App Store Connect "
    "(~15-30 min)",
    P))
story.append(Spacer(1, 0.2*cm))

story.append(PageBreak())

# ─────────────────────────────────────────────────────────────────────────
# 5. CHECKLIST APP STORE CONNECT
# ─────────────────────────────────────────────────────────────────────────
story.append(Paragraph("5. Checklist App Store Connect (post-upload)", H2))

checklist = [
    "TestFlight build apparait dans App Store Connect > TestFlight (15-30 min apres upload)",
    "Inviter 1-2 testeurs internes pour valider que l'app demarre et se logue",
    "Compliance : exporter le JWT secret HSM ? Non, l'app ne fait que CONSOMMER, OK",
    "App Privacy : 'Data Used to Track You = None' (declarer email + geoloc en lien avec compte, pas tracking marketing)",
    "Age Rating : 4+ (aucun contenu sensible — animaux uniquement)",
    "Screenshots : 6.7\" (iPhone 15 Pro Max) + 6.5\" (iPhone 11 Pro Max) + 5.5\" (iPhone 8 Plus). 3 minimum, 10 max",
    "App Preview video : optionnel mais recommande (30s max)",
    "Categories : Lifestyle (primaire), Travel (secondaire)",
    "Promotional Text (170 chars) : 'Trouvez un pet-sitter ou promeneur de confiance dans toute l'Europe. Paiement secu, identite verifiee, suivi GPS pendant les gardes.'",
    "Description complete (4000 chars max) — voir bloc dedie ci-dessous",
    "Keywords (100 chars) : 'pet sitting,dog walking,gardiennage animal,promeneur chien,vétérinaire'",
    "Support URL : https://hopetsit.com/contact",
    "Marketing URL : https://hopetsit.com",
    "Privacy Policy URL : https://hopetsit.com/privacy",
    "What's New in This Version : voir bloc ci-dessous (release notes v240)",
    "Submit for Review : valider toutes les sections et cliquer 'Submit'. Review Apple ~24-72h.",
]
for i, item in enumerate(checklist, 1):
    story.append(Paragraph(f"&#9744; <b>{i}.</b> {item}", P))
    story.append(Spacer(1, 0.08*cm))

story.append(Spacer(1, 0.3*cm))

# ─────────────────────────────────────────────────────────────────────────
# 6. RELEASE NOTES v240
# ─────────────────────────────────────────────────────────────────────────
story.append(Paragraph("6. Release Notes v240 (a copier-coller App Store)", H2))
story.append(Paragraph(
    "<b>What's New in v23.1.240</b><br/><br/>"
    "Nouveautes :<br/>"
    "&bull; Partage d'adresse pour rendez-vous directement dans le chat "
    "(3 profils)<br/>"
    "&bull; 'Voir la carte' du chat ouvre maintenant la PawMap avec halo "
    "couleur (vert pour promeneurs, bleu pour sitters)<br/>"
    "&bull; Slider 'Pres de chez moi' redessine : minimum 50 km, distances "
    "calculees plus precisement<br/>"
    "&bull; Personnes en live : tap sur un proche affiche sa position "
    "exacte sur la carte avec halo de son metier<br/>"
    "<br/>"
    "Corrections :<br/>"
    "&bull; L'app reste connectee apres avoir ete mise en arriere-plan "
    "(plus besoin de se reconnecter)<br/>"
    "&bull; Le chat post-paiement ne crash plus en ecran noir<br/>"
    "&bull; Verification d'identite Persona resoud les conflits 409 "
    "automatiquement<br/>"
    "&bull; Effacer une conversation ou un message dans un chat ami "
    "fonctionne enfin<br/>"
    "&bull; Avatars HD sur les cartes sitters et walkers<br/>"
    "&bull; 472 nouvelles traductions ES/DE/IT/PT<br/>",
    P))
story.append(Spacer(1, 0.3*cm))

# ─────────────────────────────────────────────────────────────────────────
# 7. PIEGES CONNUS
# ─────────────────────────────────────────────────────────────────────────
story.append(Paragraph("7. Pieges connus + workarounds", H2))

pitfalls = [
    ("Pod install qui bloque",
        "Si CocoaPods telecharge tres lentement, ouvrir un terminal "
        "separe : <i>pod repo update</i>. Sur M1/M2 : verifier que Xcode "
        "est Rosetta-compatible pour les anciens pods."),
    ("Code signing failed : 'No profiles for com.hopetsit.app'",
        "Aller dans Xcode > Preferences > Accounts > Manage Certificates, "
        "verifier qu'un Apple Distribution cert est present. Sinon "
        "cliquer + et generer."),
    ("'Module not found' apres flutter pub get",
        "Tous les Pods doivent se sync avec les changements pubspec. "
        "<i>cd ios && pod install --repo-update --verbose</i>. Si encore "
        "casse, <i>rm -rf Pods Podfile.lock && pod install</i>."),
    ("Push notifications ne marchent pas en release",
        "Verifier que le APNS cert (production) est uploade dans Firebase "
        "Console > Project Settings > Cloud Messaging > APNs Authentication "
        "Key. La cle .p8 + Key ID + Team ID doivent etre presents."),
    ("Deep links applinks://hopetsit.com ne s'ouvrent pas",
        "Le fichier /.well-known/apple-app-site-association doit etre "
        "deploye sur hopetsit.com avec le bon team ID + bundle. Si Daniel "
        "n'a pas encore deploye, l'app ouvre quand meme via le scheme "
        "hopetsit:// (intent fallback)."),
    ("Build size > 200 MB",
        "C'est normal pour Flutter sur iOS (assets + 2 architectures). "
        "App Store accepte jusqu'a 4 GB, mais 4 G download cellulaire "
        "limite a 200 MB. Si > 200 MB, retirer des assets inutilises ou "
        "utiliser le download deferred."),
    ("Persona webview ne charge pas en release",
        "Verifier que NSAppTransportSecurity dans Info.plist autorise "
        "withpersona.com (CCelui-ci doit avoir TLS 1.3, c'est OK par "
        "defaut)."),
]
for title, body in pitfalls:
    story.append(Paragraph(f"<b>{title}</b>", H3))
    story.append(Paragraph(body, NOTE))
    story.append(Spacer(1, 0.12*cm))

story.append(Spacer(1, 0.3*cm))

# ─────────────────────────────────────────────────────────────────────────
# 8. CONFIG BACKEND (pour info)
# ─────────────────────────────────────────────────────────────────────────
story.append(Paragraph("8. Backend Render — etat actuel (pour info uniquement)", H2))
story.append(Paragraph(
    "L'app iOS ne necessite aucune action backend. Pour info, voici les "
    "env vars Render qui doivent etre configurees (deja faites pour la "
    "v240) :", P))
story.append(Paragraph(
    "&bull; <b>MONGO_URI</b> : connection string Atlas (deja set)<br/>"
    "&bull; <b>JWT_SECRET</b> : signe les tokens 30 jours<br/>"
    "&bull; <b>FCM_SERVER_KEY</b> + <b>FCM_SENDER_ID</b> : push backend<br/>"
    "&bull; <b>AIRWALLEX_API_KEY</b> + <b>AIRWALLEX_CLIENT_ID</b> + "
    "<b>AIRWALLEX_WEBHOOK_SECRET</b> : paiements<br/>"
    "&bull; <b>PERSONA_API_KEY</b> + <b>PERSONA_TEMPLATE_ID</b> + "
    "<b>PERSONA_WEBHOOK_SECRET</b> : KYC sitters/walkers<br/>"
    "&bull; <b>SENDGRID_API_KEY</b> : emails transactionnels<br/>"
    "&bull; <b>CLOUDINARY_*</b> : upload photos<br/>"
    "&bull; <b>STAFF_EMAILS</b> : bypass chat 403 (dadaciao84@gmail.com "
    "deja hardcoded comme fallback)",
    P))
story.append(Spacer(1, 0.4*cm))

story.append(Paragraph(
    "<b>Verifier le deploy backend :</b><br/>"
    "https://hopetsit-backend.onrender.com/healthz devrait renvoyer "
    "{ status: 'ok' }<br/>"
    "https://hopetsit-backend.onrender.com/version devrait renvoyer la "
    "version backend deployee (v23.1.240).",
    INFO))
story.append(Spacer(1, 0.3*cm))

# ─────────────────────────────────────────────────────────────────────────
# 9. FOOTER
# ─────────────────────────────────────────────────────────────────────────
story.append(Spacer(1, 0.6*cm))
story.append(Paragraph(
    "<i>Document genere automatiquement le 27 mai 2026 par le script "
    "generate_ios_guide_v240.py. Pour toute question, contacter Daniel "
    "(dadaciao84@gmail.com).</i>",
    ParagraphStyle('FOOTER', parent=styles['BodyText'],
                  fontSize=8, textColor=colors.HexColor("#6B7280"),
                  alignment=TA_LEFT)))

# ─────────────────────────────────────────────────────────────────────────
# BUILD
# ─────────────────────────────────────────────────────────────────────────
doc.build(story)
print(f"PDF generated : {OUT}")

from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer
from reportlab.lib.enums import TA_JUSTIFY

OUT = "C:/Users/Usuario/Downloads/HoPetSit_iOS_Build_Guide_v23.1.450.pdf"
doc = SimpleDocTemplate(OUT, pagesize=A4, leftMargin=1.8*cm, rightMargin=1.8*cm,
                        topMargin=1.8*cm, bottomMargin=1.8*cm, title="HoPetSit iOS v450")
s = getSampleStyleSheet()
H1 = ParagraphStyle("H1", parent=s["Heading1"], fontSize=20, textColor=colors.HexColor("#EF4324"), spaceAfter=12)
H2 = ParagraphStyle("H2", parent=s["Heading2"], fontSize=14, spaceBefore=12, spaceAfter=6)
P = ParagraphStyle("P", parent=s["BodyText"], fontSize=10, leading=14, alignment=TA_JUSTIFY)
B = ParagraphStyle("B", parent=P, leftIndent=12, spaceAfter=3)
C = ParagraphStyle("C", parent=s["Code"], fontSize=9, leading=12, leftIndent=10, backColor=colors.HexColor("#F1F5F9"))
WARN = ParagraphStyle("WARN", parent=P, textColor=colors.HexColor("#B45309"), backColor=colors.HexColor("#FEF3C7"), borderPadding=6, spaceBefore=4, spaceAfter=6)

f = []
f.append(Paragraph("HoPetSit - iOS Build Guide v23.1.450 (Build 450)", H1))
f.append(Paragraph("Backend + site web + admin sont DEJA en ligne (push automatique sur origin/main). Ce guide ne concerne QUE le build iOS sur ton Mac.", P))

f.append(Paragraph("1. Ce qui a change cote app (v450)", H2))
f.append(Paragraph("- THEME PAR ROLE : fini le jaune global. Le fond des pages est teinte selon le role, depuis l'inscription jusqu'a toute l'app : proprietaire = orange pale, pet-sitter = bleu pale, promeneur = vert pale.", B))
f.append(Paragraph("- Boutons profil en pale : proprietaire \"Modifier mon animal\" orange pale ; pet-sitter Calendrier + Mon portefeuille bleu pale ; promeneur deja vert pale.", B))
f.append(Paragraph("- Chat \"Partager mon numero\" sur les 3 profils (avant : pet-sitter seulement) : carte stylee avec boutons Appeler + Copier, et une confirmation avant l'envoi.", B))
f.append(Paragraph("- Boutons des emails : tous ouvrent l'app si elle est installee, sinon redirigent vers la page de telechargement (/download). Plus jamais de page vide ou ancienne. Si non connecte : l'app s'ouvre, affiche le login, puis l'accueil.", B))
f.append(Paragraph("- PawMap : un clic sur ON sans abonnement ouvre une popup \"Abonnement requis\" (Voir les offres / Plus tard) au lieu d'activer le bouton. Un petit (i) rappelle que le bouton ON/OFF agit uniquement sur l'affichage de la carte - l'abonnement reste actif meme s'il est desactive.", B))

f.append(Paragraph("2. iOS - lien canonique des emails (a verifier)", H2))
f.append(Paragraph("Les emails pointent desormais vers https://hopetsit.com/open. Pour que l'app s'ouvre quand elle est installee, l'entitlement Associated Domains doit contenir applinks:hopetsit.com (deja le cas). La page web /open redirige vers /download si l'app est absente. Cote AASA (apple-app-site-association), les chemins /open et /app ont ete ajoutes (deploye avec le site).", P))

f.append(Paragraph("3. iOS - point a verifier dans CETTE copie", H2))
f.append(Paragraph("Le fichier ios/Runner/Info.plist de cette archive peut etre tronque (artefact de zip). AVANT de builder, verifie qu'il se termine bien par </dict></plist> et contient UIBackgroundModes (remote-notification + location) + NSLocationWhenInUseUsageDescription. Sinon recupere la version complete depuis origin/main.", WARN))

f.append(Paragraph("4. Capabilities Xcode (une fois)", H2))
f.append(Paragraph("Runner -> Signing & Capabilities : Background Modes (Location updates + Remote notifications), Push Notifications, Associated Domains (applinks:hopetsit.com).", P))

f.append(Paragraph("5. APNs - rappel (sinon AUCUN push iPhone)", H2))
f.append(Paragraph("Firebase Console -> Project settings -> Cloud Messaging -> Apple app configuration -> uploader la cle APNs .p8 (+ Key ID + Team ID). Sans elle, push iPhone muet (Android OK).", C))

f.append(Paragraph("6. Build iOS (sur le Mac)", H2))
f.append(Paragraph("git pull origin main", C))
f.append(Paragraph("cd frontend && flutter clean && flutter pub get", C))
f.append(Paragraph("cd ios && pod install --repo-update", C))
f.append(Paragraph("Ouvrir Runner.xcworkspace dans Xcode -> Product -> Archive -> Distribute (TestFlight / App Store).", C))
f.append(Paragraph("Version : 23.1.450 (build 450). Incremente le build number dans Xcode si TestFlight refuse un doublon.", P))

f.append(Spacer(1, 0.2*cm))
f.append(Paragraph("7. Android (pour memoire)", H2))
f.append(Paragraph("APK v450 construit et copie dans Downloads : HoPetSit_v23.1.450.apk. AAB Play Store : build/app/outputs/bundle/release/app-release.aab.", P))

doc.build(f)
print("OK", OUT)

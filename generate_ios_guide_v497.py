from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer
from reportlab.lib.enums import TA_JUSTIFY

OUT = "C:/Users/Usuario/Downloads/HoPetSit_iOS_Build_Guide_v23.1.497.pdf"
doc = SimpleDocTemplate(OUT, pagesize=A4, leftMargin=1.8*cm, rightMargin=1.8*cm,
                        topMargin=1.8*cm, bottomMargin=1.8*cm, title="HoPetSit iOS v497")
s = getSampleStyleSheet()
H1 = ParagraphStyle("H1", parent=s["Heading1"], fontSize=20, textColor=colors.HexColor("#EF4324"), spaceAfter=12)
H2 = ParagraphStyle("H2", parent=s["Heading2"], fontSize=14, spaceBefore=12, spaceAfter=6)
P = ParagraphStyle("P", parent=s["BodyText"], fontSize=10, leading=14, alignment=TA_JUSTIFY)
B = ParagraphStyle("B", parent=P, leftIndent=12, spaceAfter=3)
C = ParagraphStyle("C", parent=s["Code"], fontSize=9, leading=12, leftIndent=10, backColor=colors.HexColor("#F1F5F9"))
WARN = ParagraphStyle("WARN", parent=P, textColor=colors.HexColor("#B45309"), backColor=colors.HexColor("#FEF3C7"), borderPadding=6, spaceBefore=4, spaceAfter=6)

f = []
f.append(Paragraph("HoPetSit - iOS Build Guide v23.1.497 (Build 497)", H1))
f.append(Paragraph("Backend + site web + admin sont DEJA en ligne (push automatique sur origin/main -> Render + Vercel). Ce guide ne concerne QUE le build iOS sur ton Mac. La plupart des changements recents sont BACKEND/WEB (deja en ligne) ; cote app, il faut rebuilder pour livrer les correctifs ci-dessous.", P))

f.append(Paragraph("1. Ce qui a change cote APP depuis la v487", H2))
f.append(Paragraph("- INSCRIPTION : recherche de ville avec autocomplete (on tape 'Paris' -> suggestions) + bouton 'Detecter ma position' remis en evidence (3 roles). Photo de profil mise en avant a l'etape 1 et bien synchronisee vers le profil apres l'inscription.", B))
f.append(Paragraph("- PAWMAP (petite carte) : 4 boutons gauche compactes et remontes (Voir spots / Tag spot / Voir signaux / Signaler) - 'Signaler' n'est plus masque par le menu. Bulle du rayon (km) passee du marron au ROSE.", B))
f.append(Paragraph("- PAWMAP - MEMBRES PROCHES en ROSE (tous roles) : un membre abonne (PawSpot/PawPremium/staff) voit les autres membres abonnes proches sous forme de badge ROSE (patte blanche, couronne doree si Premium, point vert/gris en ligne). Avant : reserve au proprietaire qui voyait les prestataires.", B))
f.append(Paragraph("- NOTIFICATIONS + EMAILS dans la langue de l'utilisateur : la langue UI est poussee au backend des le login ; de plus, les notifications sont RE-TRADUITES a la lecture dans la langue courante. Fini les notifs en FR pour un utilisateur espagnol.", B))
f.append(Paragraph("- PREMIUM STAFF : badge + couronne premium desormais visibles quel que soit le role (le flag staff est propage sur les 3 fiches de role et lu de maniere croisee). Apparait aussi dans 'En direct'.", B))
f.append(Paragraph("- DEMANDE D'AMI : notification in-app (cloche) + bandeau d'accueil (3 roles) + push + email, dans les 6 langues.", B))
f.append(Paragraph("- BUG EMAIL 'ECRAN NOIR' corrige : le bouton 'Voir la demande' d'un email n'ouvre plus un ecran noir si l'utilisateur n'est pas connecte (garde de session ; sinon onboarding). Les liens email pointent sur le lien canonique /open (ouvre l'app si installee, sinon /download).", B))
f.append(Paragraph("- PAWFOLLOW : ligne 'Bouton suivre en direct (on/off) : tu me suis, je te suis' ajoutee dans l'onglet PawFollow. Nom d'expediteur des emails force a 'HoPetSit'.", B))
f.append(Paragraph("- Tout reste traduit (6 langues : FR/EN/ES/DE/IT/PT) selon la langue du telephone.", B))

f.append(Paragraph("2. iOS - point a verifier dans CETTE copie", H2))
f.append(Paragraph("Le fichier ios/Runner/Info.plist de cette archive peut etre tronque (artefact de zip). AVANT de builder, verifie qu'il se termine bien par </dict></plist> et contient UIBackgroundModes (remote-notification + location) + NSLocationWhenInUseUsageDescription. Sinon recupere la version complete depuis origin/main (git pull).", WARN))

f.append(Paragraph("3. Capabilities Xcode (une fois)", H2))
f.append(Paragraph("Runner -> Signing & Capabilities : Background Modes (Location updates + Remote notifications), Push Notifications, Associated Domains (applinks:hopetsit.com).", P))

f.append(Paragraph("4. APNs - rappel (sinon AUCUN push iPhone)", H2))
f.append(Paragraph("Firebase Console -> Project settings -> Cloud Messaging -> Apple app configuration -> uploader la cle APNs .p8 (+ Key ID + Team ID). Sans elle, push iPhone muet (Android OK).", C))

f.append(Paragraph("5. Build iOS (sur le Mac)", H2))
f.append(Paragraph("git pull origin main", C))
f.append(Paragraph("cd frontend && flutter clean && flutter pub get", C))
f.append(Paragraph("cd ios && pod install --repo-update", C))
f.append(Paragraph("Ouvrir Runner.xcworkspace dans Xcode -> Product -> Archive -> Distribute (TestFlight / App Store).", C))
f.append(Paragraph("Version : 23.1.497 (build 497). Incremente le build number dans Xcode si TestFlight refuse un doublon.", P))

f.append(Spacer(1, 0.2*cm))
f.append(Paragraph("6. Android (pour memoire)", H2))
f.append(Paragraph("APK v497 construit et copie dans Downloads : HoPetSit_v23.1.497.apk. AAB Play Store : relancer 'flutter build appbundle --release' dans frontend/ si besoin (build/app/outputs/bundle/release/app-release.aab).", P))

doc.build(f)
print("OK", OUT)

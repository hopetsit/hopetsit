from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer
from reportlab.lib.enums import TA_JUSTIFY

OUT = "C:/Users/Usuario/Downloads/HoPetSit_iOS_Build_Guide_v23.1.448.pdf"
doc = SimpleDocTemplate(OUT, pagesize=A4, leftMargin=1.8*cm, rightMargin=1.8*cm,
                        topMargin=1.8*cm, bottomMargin=1.8*cm, title="HoPetSit iOS v448")
s = getSampleStyleSheet()
H1 = ParagraphStyle("H1", parent=s["Heading1"], fontSize=20, textColor=colors.HexColor("#EF4324"), spaceAfter=12)
H2 = ParagraphStyle("H2", parent=s["Heading2"], fontSize=14, spaceBefore=12, spaceAfter=6)
P = ParagraphStyle("P", parent=s["BodyText"], fontSize=10, leading=14, alignment=TA_JUSTIFY)
B = ParagraphStyle("B", parent=P, leftIndent=12, spaceAfter=3)
C = ParagraphStyle("C", parent=s["Code"], fontSize=9, leading=12, leftIndent=10, backColor=colors.HexColor("#F1F5F9"))
WARN = ParagraphStyle("WARN", parent=P, textColor=colors.HexColor("#B45309"), backColor=colors.HexColor("#FEF3C7"), borderPadding=6, spaceBefore=4, spaceAfter=6)

f = []
f.append(Paragraph("HoPetSit - iOS Build Guide v23.1.448 (Build 448)", H1))
f.append(Paragraph("Backend + site + admin sont DEJA en ligne (push automatique sur origin/main). Ce guide ne concerne QUE le build iOS sur ton Mac.", P))

f.append(Paragraph("1. Ce qui a change cote app (v448)", H2))
f.append(Paragraph("- AUDIT MESSAGERIE/NOTIFICATIONS en profondeur : badge chat qui affichait 5 au lieu de 0 (double-comptage sitter/walker), badge qui ne s'effacait pas / revenait apres reconnexion, cloche qui sur-comptait, et bandeau d'accueil ou \"accepter/refuser\" ne marchait qu'une fois par session. Tout corrige.", B))
f.append(Paragraph("- EMAIL : la regle \"email seulement si l'utilisateur est hors ligne\" est desormais implementee (presence via socket). Un message ne declenche plus d'email si le destinataire est dans l'app.", B))
f.append(Paragraph("- PUSH ANDROID : canal de notification par defaut declare dans le manifest -> les pushes recus app fermee/arriere-plan affichent enfin une vraie banniere (heads-up).", B))
f.append(Paragraph("- PAIEMENT : fini les notifications \"Paiement recu\" en double (garde anti-doublon cote webhook Airwallex).", B))
f.append(Paragraph("- CONNEXION GOOGLE/APPLE : annuler le selecteur (code 16 / canceled) n'affiche plus de pop-up rouge d'erreur. Les pop-ups montrent un message propre traduit, jamais l'exception technique brute.", B))
f.append(Paragraph("- THEME : tous les fonds gris clair de l'app passent en JAUNE clair (page + champs), cartes blanches conservees.", B))
f.append(Paragraph("- PawMap : les signalements premium s'affichent de nouveau (le compte staff est reconnu comme premium cote serveur).", B))

f.append(Paragraph("2. iOS - point a verifier dans CETTE copie", H2))
f.append(Paragraph("Le fichier ios/Runner/Info.plist de cette archive \"FINAL_FIXED\" peut etre tronque (artefact de zip). AVANT de builder, ouvre-le sur le Mac et verifie qu'il se termine bien par </dict></plist> et contient UIBackgroundModes (remote-notification + location) et NSLocationWhenInUseUsageDescription. Si tronque, recupere la version complete depuis le repo git (origin/main) : c'est la source de verite.", WARN))

f.append(Paragraph("3. Capabilities Xcode a verifier (une fois)", H2))
f.append(Paragraph("Xcode -> Runner -> Signing & Capabilities :", P))
f.append(Paragraph("- Background Modes : cocher \"Location updates\" ET \"Remote notifications\".", B))
f.append(Paragraph("- Push Notifications : presente (pour les notifs).", B))
f.append(Paragraph("- Associated Domains : applinks:hopetsit.com.", B))

f.append(Paragraph("4. APNs - rappel (sinon AUCUN push iPhone)", H2))
f.append(Paragraph("L'entitlement aps-environment est en place (depuis v413). Etape HORS-CODE a faire UNE fois cote Daniel :", P))
f.append(Paragraph("Firebase Console -> Project settings -> Cloud Messaging -> Apple app configuration -> uploader la cle APNs .p8 (+ Key ID + Team ID). Sans elle, Firebase ne peut pas atteindre APNs => push iPhone muet alors qu'Android marche.", C))

f.append(Paragraph("5. Build iOS (sur le Mac)", H2))
f.append(Paragraph("git pull origin main", C))
f.append(Paragraph("cd frontend && flutter clean && flutter pub get", C))
f.append(Paragraph("cd ios && pod install --repo-update", C))
f.append(Paragraph("Ouvrir Runner.xcworkspace dans Xcode -> Product -> Archive -> Distribute (TestFlight / App Store).", C))
f.append(Paragraph("Version : 23.1.448 (build 448). Incremente le build number dans Xcode si TestFlight refuse un doublon.", P))

f.append(Paragraph("6. Nettoyage base de donnees (optionnel, cote serveur)", H2))
f.append(Paragraph("Un script de diagnostic/nettoyage a ete ajoute : backend/scripts/audit_messaging_cleanup.js. Lance d'abord en lecture seule (node scripts/audit_messaging_cleanup.js) puis avec --fix pour appliquer (compteurs non-lus negatifs, signalements (0,0), notifications en doublon). Necessite la variable MONGO_URI.", P))

f.append(Spacer(1, 0.2*cm))
f.append(Paragraph("7. Android (pour memoire)", H2))
f.append(Paragraph("APK v448 construit et copie dans Downloads : HoPetSit_v23.1.448.apk. AAB Play Store : build/app/outputs/bundle/release/app-release.aab.", P))

doc.build(f)
print("OK", OUT)

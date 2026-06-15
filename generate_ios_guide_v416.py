from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer
from reportlab.lib.enums import TA_JUSTIFY

OUT = "C:/Users/Usuario/Downloads/HoPetSit_iOS_Build_Guide_v23.1.416.pdf"
doc = SimpleDocTemplate(OUT, pagesize=A4, leftMargin=1.8*cm, rightMargin=1.8*cm,
                        topMargin=1.8*cm, bottomMargin=1.8*cm, title="HoPetSit iOS v416")
s = getSampleStyleSheet()
H1 = ParagraphStyle("H1", parent=s["Heading1"], fontSize=20, textColor=colors.HexColor("#EF4324"), spaceAfter=12)
H2 = ParagraphStyle("H2", parent=s["Heading2"], fontSize=14, spaceBefore=12, spaceAfter=6)
P = ParagraphStyle("P", parent=s["BodyText"], fontSize=10, leading=14, alignment=TA_JUSTIFY)
B = ParagraphStyle("B", parent=P, leftIndent=12, spaceAfter=3)
C = ParagraphStyle("C", parent=s["Code"], fontSize=9, leading=12, leftIndent=10, backColor=colors.HexColor("#F1F5F9"))
WARN = ParagraphStyle("WARN", parent=P, textColor=colors.HexColor("#B45309"), backColor=colors.HexColor("#FEF3C7"), borderPadding=6, spaceBefore=4, spaceAfter=6)

f = []
f.append(Paragraph("HoPetSit - iOS Build Guide v23.1.416 (Build 416)", H1))
f.append(Paragraph("Nouveautes depuis v415 : suivi en direct qui survit a l'arriere-plan (et au swipe-kill cote Android), + rappels APNs toujours valables. Le backend et le site sont deja en ligne (push automatique) ; ce guide ne concerne QUE le build iOS sur ton Mac.", P))

f.append(Paragraph("1. Ce qui a change cote app (v416)", H2))
f.append(Paragraph("- Suivi en direct (PawFollow) : ne s'arrete plus quand on quitte l'ecran PawMap ou quand l'app passe en arriere-plan. Un service de localisation tourne en tache de fond avec une notification persistante.", B))
f.append(Paragraph("- iOS : AppleSettings.allowBackgroundLocationUpdates active + indicateur bleu de localisation. Necessite UIBackgroundModes>location (DEJA dans Info.plist).", B))
f.append(Paragraph("- PawMap : page Mon cercle en VIOLET, logo PawMap, 4 nouveaux signalements (veto ouvert gratuit, laisse obligatoire, sol brulant, zone a tiques).", B))
f.append(Paragraph("- PawPoints : feuille de recompenses dans l'app (echange de points) + page web ; recompenses editables depuis l'admin sans rebuild.", B))

f.append(Paragraph("2. Limite Apple a CONNAITRE (suivi en direct + app fermee de force)", H2))
f.append(Paragraph("Sur ANDROID, le suivi survit meme si l'utilisateur \"swipe\" l'app (foreground service dans un isolate separe, START_STICKY).", P))
f.append(Paragraph("Sur iOS, Apple INTERDIT a une app d'executer du code en continu apres un force-quit (l'utilisateur ferme l'app par le multitache). C'est une regle systeme, pas un bug. Le suivi iOS fonctionne donc : (a) app ouverte, (b) app en arriere-plan / ecran verrouille (grace a allowBackgroundLocationUpdates). Apres un force-quit, iOS ne peut relancer l'app que sur changement significatif de position (precision ~500 m), pas en continu. A communiquer aux utilisateurs iPhone : pour un suivi fluide, garder l'app ouverte ou en arriere-plan, ne pas la \"tuer\".", WARN))

f.append(Paragraph("3. Capabilities Xcode a verifier (une fois)", H2))
f.append(Paragraph("Xcode -> Runner -> Signing & Capabilities :", P))
f.append(Paragraph("- Background Modes : cocher \"Location updates\" ET \"Remote notifications\" (deja dans Info.plist, mais la capability doit etre cochee pour la signature).", B))
f.append(Paragraph("- Push Notifications : doit etre presente (pour les notifs).", B))
f.append(Paragraph("- Associated Domains : applinks:hopetsit.com (deja en place).", B))

f.append(Paragraph("4. APNs - rappel (sinon AUCUN push iPhone)", H2))
f.append(Paragraph("L'entitlement aps-environment est en place (fixe v413). Il reste l'etape HORS-CODE, a faire UNE fois cote Daniel :", P))
f.append(Paragraph("Firebase Console -> Project settings -> Cloud Messaging -> Apple app configuration -> uploader la cle APNs .p8 (+ Key ID + Team ID). Sans elle, Firebase ne peut pas atteindre APNs => push iPhone muet alors qu'Android marche.", C))

f.append(Paragraph("5. Build iOS (sur le Mac)", H2))
f.append(Paragraph("git pull origin main", C))
f.append(Paragraph("cd frontend && flutter clean && flutter pub get", C))
f.append(Paragraph("cd ios && pod install --repo-update", C))
f.append(Paragraph("Ouvrir Runner.xcworkspace dans Xcode -> Product -> Archive -> Distribute (TestFlight / App Store).", C))
f.append(Paragraph("Version : 23.1.416 (build 416). Pense a incrementer le build number dans Xcode si TestFlight refuse un doublon.", P))

f.append(Spacer(1, 0.2*cm))
f.append(Paragraph("6. Android (pour memoire)", H2))
f.append(Paragraph("APK v416 deja construit et copie dans Downloads : HoPetSit_v23.1.416.apk (95 Mo). AAB Play Store : build/app/outputs/bundle/release/app-release.aab (67 Mo). Permissions FOREGROUND_SERVICE_LOCATION + ACCESS_BACKGROUND_LOCATION deja declarees.", P))

doc.build(f)
print("OK", OUT)

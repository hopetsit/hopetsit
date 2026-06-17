from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer
from reportlab.lib.enums import TA_JUSTIFY

OUT = "C:/Users/Usuario/Downloads/HoPetSit_iOS_Build_Guide_v23.1.449.pdf"
doc = SimpleDocTemplate(OUT, pagesize=A4, leftMargin=1.8*cm, rightMargin=1.8*cm,
                        topMargin=1.8*cm, bottomMargin=1.8*cm, title="HoPetSit iOS v449")
s = getSampleStyleSheet()
H1 = ParagraphStyle("H1", parent=s["Heading1"], fontSize=20, textColor=colors.HexColor("#EF4324"), spaceAfter=12)
H2 = ParagraphStyle("H2", parent=s["Heading2"], fontSize=14, spaceBefore=12, spaceAfter=6)
P = ParagraphStyle("P", parent=s["BodyText"], fontSize=10, leading=14, alignment=TA_JUSTIFY)
B = ParagraphStyle("B", parent=P, leftIndent=12, spaceAfter=3)
C = ParagraphStyle("C", parent=s["Code"], fontSize=9, leading=12, leftIndent=10, backColor=colors.HexColor("#F1F5F9"))
WARN = ParagraphStyle("WARN", parent=P, textColor=colors.HexColor("#B45309"), backColor=colors.HexColor("#FEF3C7"), borderPadding=6, spaceBefore=4, spaceAfter=6)

f = []
f.append(Paragraph("HoPetSit - iOS Build Guide v23.1.449 (Build 449)", H1))
f.append(Paragraph("Backend + site web + admin sont DEJA en ligne (push automatique sur origin/main). Ce guide ne concerne QUE le build iOS sur ton Mac.", P))

f.append(Paragraph("1. Ce qui a change cote app (v449)", H2))
f.append(Paragraph("- Badge VERIFIE : vert + un peu plus gros, et UNIQUEMENT sur les profils ayant paye la verification KYC (3 euros).", B))
f.append(Paragraph("- Modifier une annonce apres publication = formulaire COMPLET avec les PHOTOS (ajout de nouvelles photos via POST /posts/:id/media).", B))
f.append(Paragraph("- Pages d'inscription (owner/sitter/walker) plus lisibles : l'en-tete se replie quand le clavier s'ouvre, tous les champs sont visibles.", B))
f.append(Paragraph("- Photo de profil synchronisee (accueil / Mon profil / inscription) ; poids & taille de l'animal visibles cote prestataire ; temps de reponse pris en compte aussi a l'inscription Google/Apple.", B))
f.append(Paragraph("- Annonce : fleche retiree a cote des photos, heure en noir ; reservation : bouton Details repare, annulation avant 72h debloquee.", B))
f.append(Paragraph("- PawMap : Paw Premium allume/eteint PawFollow + PawSpot ensemble ; halos POI retires ; marqueur sans photo = emoji chien ; viseur express pour placer un signalement.", B))
f.append(Paragraph("- Notification 72h avant le debut du service (1re confirmation prestataire) ; audit messagerie/badges/notifs ; connexion Google/Apple : l'annulation n'affiche plus d'erreur ; theme jaune clair global.", B))
f.append(Paragraph("- ADMIN : traductions completes FR / EN / ES. SITE WEB : paiement d'une reservation + calendrier de disponibilite prestataire.", B))

f.append(Paragraph("2. iOS - point a verifier dans CETTE copie", H2))
f.append(Paragraph("Le fichier ios/Runner/Info.plist de cette archive peut etre tronque (artefact de zip). AVANT de builder, verifie qu'il se termine bien par </dict></plist> et contient UIBackgroundModes (remote-notification + location) + NSLocationWhenInUseUsageDescription. Sinon recupere la version complete depuis origin/main.", WARN))

f.append(Paragraph("3. Capabilities Xcode (une fois)", H2))
f.append(Paragraph("Runner -> Signing & Capabilities : Background Modes (Location updates + Remote notifications), Push Notifications, Associated Domains (applinks:hopetsit.com).", P))

f.append(Paragraph("4. APNs - rappel (sinon AUCUN push iPhone)", H2))
f.append(Paragraph("Firebase Console -> Project settings -> Cloud Messaging -> Apple app configuration -> uploader la cle APNs .p8 (+ Key ID + Team ID). Sans elle, push iPhone muet (Android OK).", C))

f.append(Paragraph("5. Build iOS (sur le Mac)", H2))
f.append(Paragraph("git pull origin main", C))
f.append(Paragraph("cd frontend && flutter clean && flutter pub get", C))
f.append(Paragraph("cd ios && pod install --repo-update", C))
f.append(Paragraph("Ouvrir Runner.xcworkspace dans Xcode -> Product -> Archive -> Distribute (TestFlight / App Store).", C))
f.append(Paragraph("Version : 23.1.449 (build 449). Incremente le build number dans Xcode si TestFlight refuse un doublon.", P))

f.append(Spacer(1, 0.2*cm))
f.append(Paragraph("6. Android (pour memoire)", H2))
f.append(Paragraph("APK v449 construit et copie dans Downloads : HoPetSit_v23.1.449.apk. AAB Play Store : build/app/outputs/bundle/release/app-release.aab.", P))

doc.build(f)
print("OK", OUT)

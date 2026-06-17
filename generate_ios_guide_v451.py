from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer
from reportlab.lib.enums import TA_JUSTIFY

OUT = "C:/Users/Usuario/Downloads/HoPetSit_iOS_Build_Guide_v23.1.451.pdf"
doc = SimpleDocTemplate(OUT, pagesize=A4, leftMargin=1.8*cm, rightMargin=1.8*cm,
                        topMargin=1.8*cm, bottomMargin=1.8*cm, title="HoPetSit iOS v451")
s = getSampleStyleSheet()
H1 = ParagraphStyle("H1", parent=s["Heading1"], fontSize=20, textColor=colors.HexColor("#EF4324"), spaceAfter=12)
H2 = ParagraphStyle("H2", parent=s["Heading2"], fontSize=14, spaceBefore=12, spaceAfter=6)
P = ParagraphStyle("P", parent=s["BodyText"], fontSize=10, leading=14, alignment=TA_JUSTIFY)
B = ParagraphStyle("B", parent=P, leftIndent=12, spaceAfter=3)
C = ParagraphStyle("C", parent=s["Code"], fontSize=9, leading=12, leftIndent=10, backColor=colors.HexColor("#F1F5F9"))
WARN = ParagraphStyle("WARN", parent=P, textColor=colors.HexColor("#B45309"), backColor=colors.HexColor("#FEF3C7"), borderPadding=6, spaceBefore=4, spaceAfter=6)

f = []
f.append(Paragraph("HoPetSit - iOS Build Guide v23.1.451 (Build 451)", H1))
f.append(Paragraph("Backend + site web + admin sont DEJA en ligne (push automatique sur origin/main). Ce guide ne concerne QUE le build iOS sur ton Mac.", P))

f.append(Paragraph("1. Ce qui a change cote app (v451)", H2))
f.append(Paragraph("- PawSpot : fin de la sur-censure. Des mots normaux (espagnol surtout) etaient masques en *** a tort ; le filtre ne censure plus que les mots entiers reellement grossiers.", B))
f.append(Paragraph("- Age de l'animal : ne s'affichait pas / ne se mettait pas a jour (« 0m ans »). L'age saisi (en annees) est desormais sauvegarde et affiche proprement, localise (ans / mois) sans unite en double.", B))
f.append(Paragraph("- PawMap : un ami Paw Premium s'affiche bien en Premium (couronne) meme quand son abonnement est sur un autre de ses profils (compte multi-roles).", B))
f.append(Paragraph("- PawMap : la banniere « Tu es en direct » est a mi-largeur avec un bouton « Agrandir la carte ». En mode agrandi, la carte prend tout l'ecran avec juste le bouton suivre-en-direct + un bouton reduire (pratique en marchant ou en voiture).", B))
f.append(Paragraph("- Comptes supprimes : disparaissent maintenant des amis ET de la famille (auto-nettoyage). Les PawSpots crees par un compte supprime RESTENT visibles pour les autres (regle voulue).", B))
f.append(Paragraph("- Traductions : audit complet des 6 langues + correction de chaines non traduites et de textes affiches en dur.", B))

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
f.append(Paragraph("Version : 23.1.451 (build 451). Incremente le build number dans Xcode si TestFlight refuse un doublon.", P))

f.append(Spacer(1, 0.2*cm))
f.append(Paragraph("6. Android (pour memoire)", H2))
f.append(Paragraph("APK v451 construit et copie dans Downloads : HoPetSit_v23.1.451.apk. AAB Play Store : build/app/outputs/bundle/release/app-release.aab.", P))

doc.build(f)
print("OK", OUT)

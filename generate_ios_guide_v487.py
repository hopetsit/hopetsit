from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer
from reportlab.lib.enums import TA_JUSTIFY

OUT = "C:/Users/Usuario/Downloads/HoPetSit_iOS_Build_Guide_v23.1.487.pdf"
doc = SimpleDocTemplate(OUT, pagesize=A4, leftMargin=1.8*cm, rightMargin=1.8*cm,
                        topMargin=1.8*cm, bottomMargin=1.8*cm, title="HoPetSit iOS v487")
s = getSampleStyleSheet()
H1 = ParagraphStyle("H1", parent=s["Heading1"], fontSize=20, textColor=colors.HexColor("#EF4324"), spaceAfter=12)
H2 = ParagraphStyle("H2", parent=s["Heading2"], fontSize=14, spaceBefore=12, spaceAfter=6)
P = ParagraphStyle("P", parent=s["BodyText"], fontSize=10, leading=14, alignment=TA_JUSTIFY)
B = ParagraphStyle("B", parent=P, leftIndent=12, spaceAfter=3)
C = ParagraphStyle("C", parent=s["Code"], fontSize=9, leading=12, leftIndent=10, backColor=colors.HexColor("#F1F5F9"))
WARN = ParagraphStyle("WARN", parent=P, textColor=colors.HexColor("#B45309"), backColor=colors.HexColor("#FEF3C7"), borderPadding=6, spaceBefore=4, spaceAfter=6)

f = []
f.append(Paragraph("HoPetSit - iOS Build Guide v23.1.487 (Build 487)", H1))
f.append(Paragraph("Backend + site web + admin sont DEJA en ligne (push automatique sur origin/main -> Render + Vercel). Ce guide ne concerne QUE le build iOS sur ton Mac.", P))

f.append(Paragraph("1. Ce qui a change cote app depuis la v453", H2))
f.append(Paragraph("- ECRAN D'ACCUEIL (gros bug corrige) : la grille des 4 services + les boutons (S'inscrire / Continuer avec Google / Apple sur iOS / Se connecter) ne s'affichaient plus en version release. Cause racine : une grille avec alignement 'stretch' + cartes extensibles dans une zone defilante plantait silencieusement le rendu en release. Corrige. L'accueil suit maintenant la maquette : fond ORANGE plein, logo, grille 2x2 (Pet-sitting / PawMap / PawFollow / PawSpot), bouton S'inscrire BLANC, Google/Apple, lien Se connecter.", B))
f.append(Paragraph("- EN-TETES DE PROFIL (3 roles) : refonte selon maquette. Degrade de la couleur du role (orange proprietaire / vert promeneur / bleu gardien), cloche en jaune dore (#FFCB2E), photo ~84px + anneau + bouton camera, nom 26-30px, pastille de statut. Promeneur & Gardien : 2 cadres stats 'jours actifs' (calcule depuis la date d'inscription) + 'note' (moyenne reelle des avis). La photo et le texte sont centres comme sur le profil proprietaire.", B))
f.append(Paragraph("- ECRAN DE CONVERSATION (3 roles) : vraies bulles - recu = bulle blanche a gauche (avatar + nom), envoye = bulle coloree a droite (couleur du role), sans avatar a droite. Traduire / Effacer / suivi en direct / partage adresse-numero conserves.", B))
f.append(Paragraph("- INSCRIPTION (3 roles x 5 etapes) : bouton d'action en degrade de la couleur du role, en-tete compact, stepper 1->5 avec coches. Champs/validations/navigation inchanges.", B))
f.append(Paragraph("- CONNEXION : bandeau de marque arronди en degrade orange (logo + 'Bon retour'). Page Messages : cartes de conversation redessinees. Theme sombre gere partout (suit le systeme).", B))
f.append(Paragraph("- Tout est traduit (6 langues : FR/EN/ES/DE/IT/PT) selon la langue du telephone, repli anglais.", B))

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
f.append(Paragraph("Version : 23.1.487 (build 487). Incremente le build number dans Xcode si TestFlight refuse un doublon.", P))

f.append(Spacer(1, 0.2*cm))
f.append(Paragraph("6. Android (pour memoire)", H2))
f.append(Paragraph("APK v487 construit et copie dans Downloads : HoPetSit_v23.1.487.apk. AAB Play Store : build/app/outputs/bundle/release/app-release.aab (relancer 'flutter build appbundle --release' si besoin).", P))

doc.build(f)
print("OK", OUT)

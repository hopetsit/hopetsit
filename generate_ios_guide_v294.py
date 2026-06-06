from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer
from reportlab.lib.enums import TA_JUSTIFY
OUT="C:/Users/Usuario/Downloads/HopeTSIT_iOS_Build_Guide_v23.1.294.pdf"
doc=SimpleDocTemplate(OUT,pagesize=A4,leftMargin=1.8*cm,rightMargin=1.8*cm,topMargin=1.8*cm,bottomMargin=1.8*cm,title="HopeTSIT iOS v294")
s=getSampleStyleSheet()
H1=ParagraphStyle("H1",parent=s["Heading1"],fontSize=20,textColor=colors.HexColor("#EF4324"),spaceAfter=12)
H2=ParagraphStyle("H2",parent=s["Heading2"],fontSize=14,spaceBefore=12,spaceAfter=8)
P=ParagraphStyle("P",parent=s["BodyText"],fontSize=10,leading=14,alignment=TA_JUSTIFY)
C=ParagraphStyle("C",parent=s["Code"],fontSize=9,leading=12,leftIndent=10,backColor=colors.HexColor("#F1F5F9"))
f=[]
f.append(Paragraph("HopeTSIT - iOS Build Guide v23.1.294 (Build 294)",H1))
f.append(Paragraph("Deep work partie 2 : Me suivre en arriere-plan + bouton signaler avis.",P))
f.append(Paragraph("1. Me suivre a la trace : flux GPS avec foreground service Android (AndroidSettings.foregroundNotificationConfig, notif persistante) -> survit en arriere-plan ; la camera PawMap suit ma position live ; arret auto apres 2h ou 30 min immobile. iOS : background location mode requis (Info.plist UIBackgroundModes=location, NSLocationAlwaysAndWhenInUseUsageDescription).",P))
f.append(Paragraph("2. Bouton Signaler (drapeau) sur chaque avis (ecran Mes avis) -> POST /reviews/:id/report. Le backend email admin des le 1er signalement (avec le commentaire) + onglet Signales dans admin.",P))
f.append(Paragraph("IMPORTANT iOS : pour le foreground/background location, verifier dans Info.plist : NSLocationWhenInUseUsageDescription, NSLocationAlwaysAndWhenInUseUsageDescription, et UIBackgroundModes inclut location.",C))
f.append(Paragraph("RESTE v295 : avis cliquable profil walker, notifs ami/famille dans le bandeau temps-reel.",P))
f.append(Spacer(1,0.3*cm))
f.append(Paragraph("Build iOS",H2))
f.append(Paragraph("git pull origin main / cd frontend / flutter clean / flutter pub get / cd ios / pod install --repo-update / Xcode Archive.",C))
f.append(Paragraph("Android: flutter build apk --release -> Downloads/HopeTSit_v294.apk",P))
doc.build(f)
print("OK",OUT)

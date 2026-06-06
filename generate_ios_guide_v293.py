from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer
from reportlab.lib.enums import TA_JUSTIFY
OUT="C:/Users/Usuario/Downloads/HopeTSIT_iOS_Build_Guide_v23.1.293.pdf"
doc=SimpleDocTemplate(OUT,pagesize=A4,leftMargin=1.8*cm,rightMargin=1.8*cm,topMargin=1.8*cm,bottomMargin=1.8*cm,title="HopeTSIT iOS v293")
s=getSampleStyleSheet()
H1=ParagraphStyle("H1",parent=s["Heading1"],fontSize=20,textColor=colors.HexColor("#EF4324"),spaceAfter=12)
H2=ParagraphStyle("H2",parent=s["Heading2"],fontSize=14,spaceBefore=12,spaceAfter=8)
P=ParagraphStyle("P",parent=s["BodyText"],fontSize=10,leading=14,alignment=TA_JUSTIFY)
C=ParagraphStyle("C",parent=s["Code"],fontSize=9,leading=12,leftIndent=10,backColor=colors.HexColor("#F1F5F9"))
f=[]
f.append(Paragraph("HopeTSIT - iOS Build Guide v23.1.293 (Build 293)",H1))
f.append(Paragraph("Lot deep work partie 1/2. Frontend (categories report) + backend (notifs, self-send) + site.",P))
f.append(Paragraph("1. 2 signalements GRATUITS : food (nourriture rue) + trash (detritus). Backend REPORT_TYPES+FREE, app ReportTypes+grille+i18n 6 langues+emoji, site union.",P))
f.append(Paragraph("2. Notifs traduites : resolveLocale mappe les noms complets de langue (German/Portugues...) vers le code locale au lieu de slice(0,2) -> plus de fallback FR.",P))
f.append(Paragraph("3. Demande de suivi : garde-fou destinataire != emetteur (plus de self-send).",P))
f.append(Paragraph("RESTE v294 : Me suivre arriere-plan (foreground service) + camera a la trace, avis cliquable walker, bouton Signaler avis, notifs ami/famille dans le bandeau.",P))
f.append(Spacer(1,0.4*cm))
f.append(Paragraph("Build iOS",H2))
f.append(Paragraph("git pull origin main / cd frontend / flutter clean / flutter pub get / cd ios / pod install --repo-update / Xcode Archive.",C))
f.append(Paragraph("Android: flutter build apk --release -> Downloads/HopeTSit_v293.apk",P))
doc.build(f)
print("OK",OUT)

from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer
from reportlab.lib.enums import TA_JUSTIFY
OUT="C:/Users/Usuario/Downloads/HopeTSIT_iOS_Build_Guide_v23.1.313.pdf"
doc=SimpleDocTemplate(OUT,pagesize=A4,leftMargin=1.8*cm,rightMargin=1.8*cm,topMargin=1.8*cm,bottomMargin=1.8*cm,title="HopeTSIT iOS v313")
s=getSampleStyleSheet()
H1=ParagraphStyle("H1",parent=s["Heading1"],fontSize=20,textColor=colors.HexColor("#EF4324"),spaceAfter=12)
H2=ParagraphStyle("H2",parent=s["Heading2"],fontSize=14,spaceBefore=12,spaceAfter=8)
P=ParagraphStyle("P",parent=s["BodyText"],fontSize=10,leading=14,alignment=TA_JUSTIFY)
C=ParagraphStyle("C",parent=s["Code"],fontSize=9,leading=12,leftIndent=10,backColor=colors.HexColor("#F1F5F9"))
f=[]
f.append(Paragraph("HopeTSIT - iOS Build Guide v23.1.313 (Build 313)",H1))
f.append(Paragraph("APK identique a v302 cote app (aucun changement Dart). Tout le travail v303-v313 etait BACKEND + page admin, deja deploye via Render.",P))
f.append(Paragraph("Recap backend deja en ligne (pas besoin diOS) :",P))
f.append(Paragraph("- Paiements live Airwallex repares de bout en bout : cle admin, endpoint transfers/create, schema (source_currency + version 2024-09-27). Retraits societe ET virements prestataires fonctionnent.",P))
f.append(Paragraph("- Bouton admin Re-synchroniser les paiements (recupere les transactions non synchronisees par le webhook).",P))
f.append(Paragraph("- Tableau de bord admin : cartes Commission 20%, Boutique benefice, A reverser aux prestataires (wallets), Abonnements + repartition par plan.",P))
f.append(Paragraph("- Commission Top Sitter/Walker = 15%.",P))
f.append(Spacer(1,0.3*cm))
f.append(Paragraph("Build iOS (inchange depuis v302)",H2))
f.append(Paragraph("git pull origin main / cd frontend / flutter clean / flutter pub get / cd ios / pod install --repo-update / Xcode Archive.",C))
f.append(Paragraph("Android : flutter build apk --release -> Downloads/HopeTSit_v313.apk",P))
doc.build(f)
print("OK",OUT)

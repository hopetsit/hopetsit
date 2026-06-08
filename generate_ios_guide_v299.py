from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer
from reportlab.lib.enums import TA_JUSTIFY
OUT="C:/Users/Usuario/Downloads/HopeTSIT_iOS_Build_Guide_v23.1.299.pdf"
doc=SimpleDocTemplate(OUT,pagesize=A4,leftMargin=1.8*cm,rightMargin=1.8*cm,topMargin=1.8*cm,bottomMargin=1.8*cm,title="HopeTSIT iOS v299")
s=getSampleStyleSheet()
H1=ParagraphStyle("H1",parent=s["Heading1"],fontSize=20,textColor=colors.HexColor("#EF4324"),spaceAfter=12)
H2=ParagraphStyle("H2",parent=s["Heading2"],fontSize=14,spaceBefore=12,spaceAfter=8)
P=ParagraphStyle("P",parent=s["BodyText"],fontSize=10,leading=14,alignment=TA_JUSTIFY)
C=ParagraphStyle("C",parent=s["Code"],fontSize=9,leading=12,leftIndent=10,backColor=colors.HexColor("#F1F5F9"))
f=[]
f.append(Paragraph("HopeTSIT - iOS Build Guide v23.1.299 (Build 299)",H1))
f.append(Paragraph("Profils epures + fix traduction badges service.",P))
f.append(Paragraph("1. Email retire de len-tete des profils owner, sitter ET walker (les 3 laffichaient). Hero = photo + nom + badges, sans email.",P))
f.append(Paragraph("2. Traduction PT corrigee : house sitting affichait Sentado em casa (contresens = assis a la maison) -> Cuidado da casa, aux 2 endroits (badge profil + publication demande).",P))
f.append(Paragraph("3. Filet de securite : un service inconnu safiche prettifie (House Sitting) au lieu de brut (house_sitting).",P))
f.append(Paragraph("Rappel contexte recent (deja deploye backend) : v297 Mon cercle compte famille+amis ; v298 admin remboursement Airwallex reel + annuler paiement.",P))
f.append(Spacer(1,0.3*cm))
f.append(Paragraph("Build iOS",H2))
f.append(Paragraph("git pull origin main / cd frontend / flutter clean / flutter pub get / cd ios / pod install --repo-update / Xcode Archive.",C))
f.append(Paragraph("Android: flutter build apk --release -> Downloads/HopeTSit_v299.apk",P))
doc.build(f)
print("OK",OUT)

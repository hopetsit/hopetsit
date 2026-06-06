from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer
from reportlab.lib.enums import TA_JUSTIFY
OUT="C:/Users/Usuario/Downloads/HopeTSIT_iOS_Build_Guide_v23.1.297.pdf"
doc=SimpleDocTemplate(OUT,pagesize=A4,leftMargin=1.8*cm,rightMargin=1.8*cm,topMargin=1.8*cm,bottomMargin=1.8*cm,title="HopeTSIT iOS v297")
s=getSampleStyleSheet()
H1=ParagraphStyle("H1",parent=s["Heading1"],fontSize=20,textColor=colors.HexColor("#EF4324"),spaceAfter=12)
H2=ParagraphStyle("H2",parent=s["Heading2"],fontSize=14,spaceBefore=12,spaceAfter=8)
P=ParagraphStyle("P",parent=s["BodyText"],fontSize=10,leading=14,alignment=TA_JUSTIFY)
C=ParagraphStyle("C",parent=s["Code"],fontSize=9,leading=12,leftIndent=10,backColor=colors.HexColor("#F1F5F9"))
f=[]
f.append(Paragraph("HopeTSIT - iOS Build Guide v23.1.297 (Build 297)",H1))
f.append(Paragraph("Fix Mon cercle : compte famille ET amis en direct.",P))
f.append(Paragraph("PROBLEME : le badge Mon cercle (PawMap) affichait 2 alors que 5 amis/famille etaient en direct.",P))
f.append(Paragraph("CAUSE : le fanout position (mapSocket.listPositionListeners) ne se basait QUE sur les amitiees acceptees (Friendship). Un co-membre famille qui nest pas aussi un ami ne recevait jamais la position des autres (et inversement), donc le compteur (= friendPositions.length) lignorait.",P))
f.append(Paragraph("FIX backend : UserSubscription.listFamilyMembers(userId) liste les co-membres famille actifs ; mapSocket les fusionne avec les amis (partage auto, perk paye famille). DEJA deploye via push Render -> le compteur monte SANS reinstaller lapp.",P))
f.append(Paragraph("FIX app : le rendu marqueur dessine aussi le pin des membres famille qui ne sont pas des amis (sinon ils comptaient sans pin).",P))
f.append(Spacer(1,0.3*cm))
f.append(Paragraph("Build iOS",H2))
f.append(Paragraph("git pull origin main / cd frontend / flutter clean / flutter pub get / cd ios / pod install --repo-update / Xcode Archive.",C))
f.append(Paragraph("Android: flutter build apk --release -> Downloads/HopeTSit_v297.apk",P))
doc.build(f)
print("OK",OUT)

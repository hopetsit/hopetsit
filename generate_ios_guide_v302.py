from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer
from reportlab.lib.enums import TA_JUSTIFY
OUT="C:/Users/Usuario/Downloads/HopeTSIT_iOS_Build_Guide_v23.1.302.pdf"
doc=SimpleDocTemplate(OUT,pagesize=A4,leftMargin=1.8*cm,rightMargin=1.8*cm,topMargin=1.8*cm,bottomMargin=1.8*cm,title="HopeTSIT iOS v302")
s=getSampleStyleSheet()
H1=ParagraphStyle("H1",parent=s["Heading1"],fontSize=20,textColor=colors.HexColor("#EF4324"),spaceAfter=12)
H2=ParagraphStyle("H2",parent=s["Heading2"],fontSize=14,spaceBefore=12,spaceAfter=8)
P=ParagraphStyle("P",parent=s["BodyText"],fontSize=10,leading=14,alignment=TA_JUSTIFY)
C=ParagraphStyle("C",parent=s["Code"],fontSize=9,leading=12,leftIndent=10,backColor=colors.HexColor("#F1F5F9"))
f=[]
f.append(Paragraph("HopeTSIT - iOS Build Guide v23.1.302 (Build 302)",H1))
f.append(Paragraph("Cet APK embarque les changements app v300 + v301. Le backend v302 (commission Top 15%) est deja deploye via Render.",P))
f.append(Paragraph("APP (v300) : 1) emojis report TOUS types (pipi/nourriture/poubelle... affichaient un halo jaune au lieu de lemoji) ; 2) halo orange (owner) anime aussi sur Android ; 3) bouton retour reste sur la carte+menu au lieu de revenir a amis-en-direct ; 4) reconnexion socket re-emet la position immediatement.",P))
f.append(Paragraph("APP (v301) : badges message ne reviennent plus apres reconnexion (conversation marquee lue cote serveur : socket + HTTP POST /conversations/:id/read).",P))
f.append(Paragraph("BACKEND (v302, deja en ligne, pas besoin diOS) : commission Top Sitter/Walker = 15% au lieu de 20% (calcul booking). Audit paiement : 20% petsitting + 100% boutique confirmes corrects.",P))
f.append(Spacer(1,0.3*cm))
f.append(Paragraph("Build iOS",H2))
f.append(Paragraph("git pull origin main / cd frontend / flutter clean / flutter pub get / cd ios / pod install --repo-update / Xcode Archive.",C))
f.append(Paragraph("Android : flutter build apk --release -> Downloads/HopeTSit_v302.apk",P))
doc.build(f)
print("OK",OUT)

from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer
from reportlab.lib.enums import TA_JUSTIFY
OUT="C:/Users/Usuario/Downloads/HopeTSIT_iOS_Build_Guide_v23.1.295.pdf"
doc=SimpleDocTemplate(OUT,pagesize=A4,leftMargin=1.8*cm,rightMargin=1.8*cm,topMargin=1.8*cm,bottomMargin=1.8*cm,title="HopeTSIT iOS v295")
s=getSampleStyleSheet()
H1=ParagraphStyle("H1",parent=s["Heading1"],fontSize=20,textColor=colors.HexColor("#EF4324"),spaceAfter=12)
H2=ParagraphStyle("H2",parent=s["Heading2"],fontSize=14,spaceBefore=12,spaceAfter=8)
P=ParagraphStyle("P",parent=s["BodyText"],fontSize=10,leading=14,alignment=TA_JUSTIFY)
C=ParagraphStyle("C",parent=s["Code"],fontSize=9,leading=12,leftIndent=10,backColor=colors.HexColor("#F1F5F9"))
f=[]
f.append(Paragraph("HopeTSIT - iOS Build Guide v23.1.295 (Build 295)",H1))
f.append(Paragraph("Couleurs owner + anti-spam + Top Sitter/Walker.",P))
f.append(Paragraph("1. Owner = ORANGE partout (badge liste amis Amis+Famille, people_live, pin map). Avant violet/rose, confondu avec Famille (violet). Famille reste violet, walker vert, sitter bleu.",P))
f.append(Paragraph("2. Anti-spam (backend, deja deploye): signaler un avis = 1 fois/user (reportedBy), admin email 1 fois. Demande ami pending <7j = idempotente (pas de notif repetee). Services/bookings deja dedupliques.",P))
f.append(Paragraph("3. Top Sitter/Walker: les cartes se rechargent au retour au premier plan (etaient stale apres une prestation). Backend recompute deja correct (confirmService -> onBookingCompleted -> recompute sitter ET walker).",P))
f.append(Paragraph("RESTE: avis cliquable profil walker, notifs ami/famille dans le bandeau temps-reel.",P))
f.append(Spacer(1,0.3*cm))
f.append(Paragraph("Build iOS",H2))
f.append(Paragraph("git pull origin main / cd frontend / flutter clean / flutter pub get / cd ios / pod install --repo-update / Xcode Archive.",C))
f.append(Paragraph("Android: flutter build apk --release -> Downloads/HopeTSit_v295.apk",P))
doc.build(f)
print("OK",OUT)

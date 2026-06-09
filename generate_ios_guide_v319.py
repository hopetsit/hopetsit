from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer
from reportlab.lib.enums import TA_JUSTIFY
OUT="C:/Users/Usuario/Downloads/HopeTSIT_iOS_Build_Guide_v23.1.319.pdf"
doc=SimpleDocTemplate(OUT,pagesize=A4,leftMargin=1.8*cm,rightMargin=1.8*cm,topMargin=1.8*cm,bottomMargin=1.8*cm,title="HopeTSIT iOS v319")
s=getSampleStyleSheet()
H1=ParagraphStyle("H1",parent=s["Heading1"],fontSize=20,textColor=colors.HexColor("#EF4324"),spaceAfter=12)
H2=ParagraphStyle("H2",parent=s["Heading2"],fontSize=13,spaceBefore=12,spaceAfter=6)
P=ParagraphStyle("P",parent=s["BodyText"],fontSize=10,leading=14,alignment=TA_JUSTIFY)
C=ParagraphStyle("C",parent=s["Code"],fontSize=9,leading=12,leftIndent=10,backColor=colors.HexColor("#F1F5F9"))
f=[]
f.append(Paragraph("HoPetSit - iOS Build Guide v23.1.319 (Build 319)",H1))
f.append(Paragraph("APK Android : Downloads/HopeTSit_v319.apk. Cumule tous les changements APP v316->v319.",P))
f.append(Paragraph("Changements APP inclus :",H2))
f.append(Paragraph("- v316 : feuille de retrait au-dessus de la barre systeme + zoom PawMap plus fluide.",P))
f.append(Paragraph("- v317 : badge chat ne se compte plus en double + marque HoPetSit dans les traductions.",P))
f.append(Paragraph("- v318 : parrainage masque pour sitter/walker + un seul bandeau ami/famille.",P))
f.append(Paragraph("- v319 : routage des notifications repare (~30 types etaient des boutons morts ; tap push ouvre desormais lecran Notifications) + routage wallet/boutique.",P))
f.append(Spacer(1,0.3*cm))
f.append(Paragraph("Backend deja en ligne (pas besoin iOS) - v320->v322 :",H2))
f.append(Paragraph("- v320 : PawFamily dans la compta boutique + marque HoPetSit backend (emails/factures).",P))
f.append(Paragraph("- v321 : index MongoDB critiques (paiement/webhook) + idempotence des webhooks.",P))
f.append(Paragraph("- v322 : throttle self-heal + adaptateur Redis sockets (multi-instance, sactive avec REDIS_URL).",P))
f.append(Paragraph("- Modaration auto multilingue (gros mots/menaces) sur chat, avis, posts, signalements, bios.",P))
f.append(Spacer(1,0.3*cm))
f.append(Paragraph("Build iOS",H2))
f.append(Paragraph("git pull origin main / cd frontend / flutter clean / flutter pub get / cd ios / pod install --repo-update / Xcode Archive.",C))
doc.build(f)
print("OK",OUT)

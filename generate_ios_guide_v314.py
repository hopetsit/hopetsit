from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer
from reportlab.lib.enums import TA_JUSTIFY
OUT="C:/Users/Usuario/Downloads/HopeTSIT_iOS_Build_Guide_v23.1.314.pdf"
doc=SimpleDocTemplate(OUT,pagesize=A4,leftMargin=1.8*cm,rightMargin=1.8*cm,topMargin=1.8*cm,bottomMargin=1.8*cm,title="HopeTSIT iOS v314")
s=getSampleStyleSheet()
H1=ParagraphStyle("H1",parent=s["Heading1"],fontSize=20,textColor=colors.HexColor("#EF4324"),spaceAfter=12)
H2=ParagraphStyle("H2",parent=s["Heading2"],fontSize=14,spaceBefore=12,spaceAfter=8)
P=ParagraphStyle("P",parent=s["BodyText"],fontSize=10,leading=14,alignment=TA_JUSTIFY)
C=ParagraphStyle("C",parent=s["Code"],fontSize=9,leading=12,leftIndent=10,backColor=colors.HexColor("#F1F5F9"))
f=[]
f.append(Paragraph("HopeTSIT - iOS Build Guide v23.1.314 (Build 314)",H1))
f.append(Paragraph("FIX dark mode : texte invisible (blanc sur blanc) sur les champs de retrait wallet et IBAN.",P))
f.append(Paragraph("APP (v314) : champ Montant a retirer (wallet) + champs IBAN (titulaire/IBAN/BIC) -> couleur de texte forcee/theme-aware -> lisible en clair ET en sombre. Avant : texte blanc invisible en dark, do erreur minimum 5 EUR car le montant ne se voyait pas.",P))
f.append(Paragraph("BACKEND deja en ligne (pas besoin iOS) - v315 : FIX RACINE du payout prestataire. createBeneficiary envoyait type ET entity_type en double -> Airwallex rejetait -> beneficiaire jamais cree -> retrait bloque. Corrige (entity_type seul). Les prestataires doivent RE-SAUVEGARDER leur IBAN une fois.",P))
f.append(Spacer(1,0.3*cm))
f.append(Paragraph("Build iOS",H2))
f.append(Paragraph("git pull origin main / cd frontend / flutter clean / flutter pub get / cd ios / pod install --repo-update / Xcode Archive.",C))
f.append(Paragraph("Android : flutter build apk --release -> Downloads/HopeTSit_v314.apk",P))
doc.build(f)
print("OK",OUT)

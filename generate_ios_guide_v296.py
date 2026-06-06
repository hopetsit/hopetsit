from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer
from reportlab.lib.enums import TA_JUSTIFY
OUT="C:/Users/Usuario/Downloads/HopeTSIT_iOS_Build_Guide_v23.1.296.pdf"
doc=SimpleDocTemplate(OUT,pagesize=A4,leftMargin=1.8*cm,rightMargin=1.8*cm,topMargin=1.8*cm,bottomMargin=1.8*cm,title="HopeTSIT iOS v296")
s=getSampleStyleSheet()
H1=ParagraphStyle("H1",parent=s["Heading1"],fontSize=20,textColor=colors.HexColor("#EF4324"),spaceAfter=12)
H2=ParagraphStyle("H2",parent=s["Heading2"],fontSize=14,spaceBefore=12,spaceAfter=8)
P=ParagraphStyle("P",parent=s["BodyText"],fontSize=10,leading=14,alignment=TA_JUSTIFY)
C=ParagraphStyle("C",parent=s["Code"],fontSize=9,leading=12,leftIndent=10,backColor=colors.HexColor("#F1F5F9"))
f=[]
f.append(Paragraph("HopeTSIT - iOS Build Guide v23.1.296 (Build 296)",H1))
f.append(Paragraph("2 derniers points + fix Top Sitter + iOS background GPS.",P))
f.append(Paragraph("1. FIX Top Sitter (backend): getSitterProfile ne renvoyait jamais completedServicesCount/averageRating/isTopSitter (objet construit a la main) -> carte bloquee a 0/20. Ajoutes + self-heal recompute a la lecture. Walker: self-heal aussi. Deja deploye via push.",P))
f.append(Paragraph("2. iOS UIBackgroundModes=location ajoute (sinon Me suivre coupe le GPS en arriere-plan). Pris au prochain build Xcode.",P))
f.append(Paragraph("3. #3 Avis cliquable profil walker: tuile Mes avis -> recupere les avis (GET /reviews) -> ouvre MyReviewsScreen (avec bouton signaler).",P))
f.append(Paragraph("4. #6 Notifs ami/famille dans le bandeau in-app temps reel (toast). Les paiements ne sont PAS touches (pas de bandeau, volontaire). Titre/corps deja localises backend.",P))
f.append(Spacer(1,0.3*cm))
f.append(Paragraph("Build iOS",H2))
f.append(Paragraph("git pull origin main / cd frontend / flutter clean / flutter pub get / cd ios / pod install --repo-update / Xcode Archive. Verifier que UIBackgroundModes=location est bien dans Info.plist.",C))
f.append(Paragraph("Android: flutter build apk --release -> Downloads/HopeTSit_v296.apk",P))
doc.build(f)
print("OK",OUT)

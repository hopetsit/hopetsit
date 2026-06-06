"""HopeTSIT iOS Build Guide v23.1.292 generator."""
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, PageBreak
from reportlab.lib.enums import TA_JUSTIFY

OUT = "C:/Users/Usuario/Downloads/HopeTSIT_iOS_Build_Guide_v23.1.292.pdf"
doc = SimpleDocTemplate(OUT, pagesize=A4, leftMargin=1.8*cm, rightMargin=1.8*cm,
    topMargin=1.8*cm, bottomMargin=1.8*cm, title="HopeTSIT iOS Build Guide v23.1.292", author="HopeTSIT team")
styles = getSampleStyleSheet()
H1 = ParagraphStyle('H1', parent=styles['Heading1'], fontSize=22, textColor=colors.HexColor("#EF4324"), spaceAfter=14, leading=26)
H2 = ParagraphStyle('H2', parent=styles['Heading2'], fontSize=15, textColor=colors.HexColor("#1F2937"), spaceAfter=10, spaceBefore=14, leading=18)
P = ParagraphStyle('P', parent=styles['BodyText'], fontSize=10, leading=14, alignment=TA_JUSTIFY)
CODE = ParagraphStyle('CODE', parent=styles['Code'], fontSize=9, leading=12, leftIndent=12, textColor=colors.HexColor("#0F172A"), backColor=colors.HexColor("#F1F5F9"))
INFO = ParagraphStyle('INFO', parent=styles['BodyText'], fontSize=9, leading=13, leftIndent=12, rightIndent=12, textColor=colors.HexColor("#075985"), backColor=colors.HexColor("#E0F2FE"), borderColor=colors.HexColor("#0EA5E9"), borderWidth=1, borderPadding=8)
GREEN = ParagraphStyle('GREEN', parent=styles['BodyText'], fontSize=10, leading=14, leftIndent=12, rightIndent=12, textColor=colors.HexColor("#065F46"), backColor=colors.HexColor("#D1FAE5"), borderColor=colors.HexColor("#10B981"), borderWidth=1, borderPadding=8)
RED = ParagraphStyle('RED', parent=styles['BodyText'], fontSize=10, leading=14, leftIndent=12, rightIndent=12, textColor=colors.HexColor("#7F1D1D"), backColor=colors.HexColor("#FEE2E2"), borderColor=colors.HexColor("#EF4444"), borderWidth=1, borderPadding=8)

flow = []
flow.append(Paragraph("HopeTSIT &mdash; iOS Build Guide", H1))
flow.append(Paragraph("Version 23.1.292 (Build 292)", H2))
flow.append(Spacer(1, 0.4*cm))
flow.append(Paragraph(
    "Round 'deep work' sur les avis : la vraie note/avis s'affiche sur le profil "
    "prestataire, l'onglet Avis devient cliquable (liste de tous les "
    "commentaires recus), l'owner voit l'etat 'deja note' (modifier/supprimer), "
    "et 'Noter' n'ouvre plus la page paiement.", P))
flow.append(Spacer(1, 0.5*cm))
flow.append(Paragraph(
    "v23.1.292 &mdash; Frontend uniquement (ProfileModel, profil sitter, ecran "
    "Mes avis, carte de note owner). APK universal. Aucun changement backend "
    "dans ce build.", GREEN))
flow.append(Spacer(1, 0.4*cm))
flow.append(Paragraph(
    "IMPORTANT : les avis walker, le getMyReview (deja note) et le recompute "
    "Top Sitter/Walker dependent du BACKEND v290 deploye sur Render. Si "
    "l'auto-deploy est coupe, faire Manual Deploy et verifier /__build = v290.", RED))
flow.append(PageBreak())

flow.append(Paragraph("Changelog v23.1.292", H1))

flow.append(Paragraph("1. Note & Avis figes a 0.0 / 0 (RACINE)", H2))
flow.append(Paragraph(
    "Sur le profil sitter, la Note et le nombre d'Avis etaient CODES EN DUR "
    "('0.0' et '0') et n'avaient jamais lu les vraies donnees. ProfileModel ne "
    "parsait meme pas rating / reviewsCount / reviews. Corrige : ProfileModel "
    "parse rating, reviewsCount, reviews, averageRating, completedServicesCount, "
    "isTopSitter (deja renvoyes par le profil public) ; l'ecran affiche la vraie "
    "note et le vrai nombre d'avis.", P))

flow.append(Paragraph("2. Avis cliquable -> liste des commentaires", H2))
flow.append(Paragraph(
    "La stat 'Avis' du profil est maintenant cliquable et ouvre un nouvel ecran "
    "'Mes avis' : note moyenne + nombre, puis la liste de chaque avis recu "
    "(avatar, nom, etoiles, commentaire).", INFO))

flow.append(Paragraph("3. 'Noter' n'ouvre plus la page paiement", H2))
flow.append(Paragraph(
    "Toute la carte de reservation est un GestureDetector qui ouvre la page "
    "accord/paiement. Les taps sur la zone note remontaient a la carte. La carte "
    "de note absorbe desormais tous les taps (HitTestBehavior.opaque) -> 'Noter' "
    "ouvre toujours l'avis.", P))

flow.append(Paragraph("4. Owner : etat 'deja note' + modifier/supprimer", H2))
flow.append(Paragraph(
    "La carte de note verifie au montage si l'owner a deja note (getMyReview). Si "
    "oui : '✓ Deja note · Modifier' (etoiles pleines) -> taper ouvre l'ecran en "
    "mode edition/suppression. Sinon : invitation a noter. Se rafraichit au "
    "retour. (Necessite le backend v290 deploye.)", INFO))

flow.append(Paragraph("5. Top Sitter / Top Walker", H2))
flow.append(Paragraph(
    "La carte lit deja les vraies valeurs (completedServicesCount, "
    "averageRating) — pas de hardcode. Elle se met a jour une fois le recompute "
    "execute (confirmation de service ou avis cree) ET le profil rafraichi. "
    "Depend du deploiement backend.", P))
flow.append(PageBreak())

flow.append(Paragraph("Build iOS &mdash; etapes Xcode", H1))
flow.append(Paragraph("Etape 1 &mdash; Pull v292", H2))
flow.append(Paragraph("git pull origin main<br/>cd frontend &amp;&amp; flutter clean &amp;&amp; flutter pub get<br/>cd ios &amp;&amp; pod install --repo-update", CODE))
flow.append(Paragraph("Etape 2 &mdash; Smoke test (apres Manual Deploy backend)", H2))
flow.append(Paragraph(
    "Owner note un service confirme -> profil sitter : Note + Avis se mettent a "
    "jour. Taper 'Avis' -> liste des commentaires. Owner revient : carte '✓ Deja "
    "note · Modifier' -> modifier/supprimer. Taper 'Noter' n'ouvre jamais le "
    "paiement.", P))
flow.append(Paragraph("Etape 3 &mdash; Archive Xcode", H2))
flow.append(Paragraph("scheme Runner, Any iOS Device, Product &gt; Archive, Distribute App &gt; App Store Connect (TestFlight d'abord).", P))
flow.append(Spacer(1, 0.5*cm))
flow.append(Paragraph("Build Android : flutter build apk --release -&gt; Downloads/HopeTSit_v292.apk.", INFO))

doc.build(flow)
print(f"OK -> {OUT}")

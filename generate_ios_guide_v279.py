"""HopeTSIT iOS Build Guide v23.1.279 generator."""
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, PageBreak
from reportlab.lib.enums import TA_JUSTIFY

OUT = "C:/Users/Usuario/Downloads/HopeTSIT_iOS_Build_Guide_v23.1.279.pdf"
doc = SimpleDocTemplate(OUT, pagesize=A4, leftMargin=1.8*cm, rightMargin=1.8*cm,
    topMargin=1.8*cm, bottomMargin=1.8*cm, title="HopeTSIT iOS Build Guide v23.1.279", author="HopeTSIT team")
styles = getSampleStyleSheet()
H1 = ParagraphStyle('H1', parent=styles['Heading1'], fontSize=22, textColor=colors.HexColor("#EF4324"), spaceAfter=14, leading=26)
H2 = ParagraphStyle('H2', parent=styles['Heading2'], fontSize=15, textColor=colors.HexColor("#1F2937"), spaceAfter=10, spaceBefore=14, leading=18)
P = ParagraphStyle('P', parent=styles['BodyText'], fontSize=10, leading=14, alignment=TA_JUSTIFY)
CODE = ParagraphStyle('CODE', parent=styles['Code'], fontSize=9, leading=12, leftIndent=12, textColor=colors.HexColor("#0F172A"), backColor=colors.HexColor("#F1F5F9"))
INFO = ParagraphStyle('INFO', parent=styles['BodyText'], fontSize=9, leading=13, leftIndent=12, rightIndent=12, textColor=colors.HexColor("#075985"), backColor=colors.HexColor("#E0F2FE"), borderColor=colors.HexColor("#0EA5E9"), borderWidth=1, borderPadding=8)
GREEN = ParagraphStyle('GREEN', parent=styles['BodyText'], fontSize=10, leading=14, leftIndent=12, rightIndent=12, textColor=colors.HexColor("#065F46"), backColor=colors.HexColor("#D1FAE5"), borderColor=colors.HexColor("#10B981"), borderWidth=1, borderPadding=8)

flow = []
flow.append(Paragraph("HopeTSIT — iOS Build Guide", H1))
flow.append(Paragraph("Version 23.1.279 (Build 279)", H2))
flow.append(Spacer(1, 0.4*cm))
flow.append(Paragraph(
    "Delta v23.1.278 to v23.1.279 : retrait membre famille reparé (cause racine "
    "casse userModel), bouton PawMap 'Mon cercle', banniere boutique PawFollow/"
    "Family INDEPENDANTE, badge PawFollow fallback. Cote web/admin : prix "
    "PawFamily dans l'admin, satellite repositionne, page d'accueil (carte "
    "Sophie traduite + section 4 facons + PawFamily violet), traduction admin "
    "EN/ES reparée.", P))
flow.append(Spacer(1, 0.5*cm))
flow.append(Paragraph(
    "v23.1.279 — Frontend + backend (family DELETE, pricing deep-merge) + site "
    "web + admin. APK universal. Les changements backend ne s'activent qu'apres "
    "le deploiement Render (au push). Aucune migration DB.", GREEN))
flow.append(PageBreak())

flow.append(Paragraph("Changelog v23.1.279", H1))

flow.append(Paragraph("1. Retrait membre famille — RACINE", H2))
flow.append(Paragraph(
    "Le DELETE /friends/family/member était CASE-SENSITIVE sur userModel "
    "(cherchait 'Owner') alors que le sub Famille est stocké en 'owner' "
    "(lowercase) — comme l'était deja le GET. La query ne trouvait pas le sub "
    "→ 404 → retrait raté silencieux → le membre restait famille (halo violet). "
    "Fix : meme tolerance de casse ($in [Owner, owner]) + plan FR/EN. Une fois "
    "deployé : retrait OK + couleur/role revient sur la PawMap.", P))

flow.append(Paragraph("2. PawMap 'Mon cercle' + banniere independante", H2))
flow.append(Paragraph(
    "Le quick button 'Amis' (qui affiche amis ET famille) est renomme 'Mon "
    "cercle' (6 langues). La banniere boutique lit desormais /me/benefits pour "
    "des signaux PawFollow et Family INDEPENDANTS (les 2 moities peuvent etre "
    "actives en meme temps, avec leurs jours). Badge profil PawFollow : "
    "fallback isPremium tant que le backend (pawFollowActive) n'est pas deploye.", INFO))

flow.append(Paragraph("3. Web + Admin", H2))
flow.append(Paragraph(
    "Admin : prix PawFamily affiche (deep-merge pricing) + traduction EN/ES "
    "reparée (setAdminLang implemente). Site : satellite descendu (bas-droite), "
    "page d'accueil carte Sophie traduite + section '4 facons d'utiliser "
    "HopeTSIT' avec carte PawFamily violette.", P))
flow.append(PageBreak())

flow.append(Paragraph("Build iOS — etapes Xcode", H1))
flow.append(Paragraph("Etape 1 — Pull v279", H2))
flow.append(Paragraph("git pull origin main<br/>cd frontend &amp;&amp; flutter clean &amp;&amp; flutter pub get<br/>cd ios &amp;&amp; pod install --repo-update", CODE))
flow.append(Paragraph("Etape 2 — Smoke test (apres deploiement Render)", H2))
flow.append(Paragraph(
    "Famille : retirer un membre -> il disparait + sa couleur revient au role. "
    "PawMap : le quick button affiche 'Mon cercle'. Boutique : PawFollow ET "
    "Family peuvent etre actifs ensemble ; badge profil PawFollow dore visible. "
    "Admin (navigateur) : changer la langue EN/ES traduit la page ; le prix "
    "PawFamily (9,99) est present.", P))
flow.append(Paragraph("Etape 3 — Archive Xcode", H2))
flow.append(Paragraph("scheme Runner, Any iOS Device, Product &gt; Archive, Distribute App &gt; App Store Connect (TestFlight d'abord).", P))
flow.append(Spacer(1, 0.5*cm))
flow.append(Paragraph("Build Android : flutter build apk --release -> Downloads/HopeTSIT_v23.1.279.apk.", INFO))

doc.build(flow)
print(f"OK -> {OUT}")

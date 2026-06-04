"""HopeTSIT iOS Build Guide v23.1.283 generator."""
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, PageBreak
from reportlab.lib.enums import TA_JUSTIFY

OUT = "C:/Users/Usuario/Downloads/HopeTSIT_iOS_Build_Guide_v23.1.283.pdf"
doc = SimpleDocTemplate(OUT, pagesize=A4, leftMargin=1.8*cm, rightMargin=1.8*cm,
    topMargin=1.8*cm, bottomMargin=1.8*cm, title="HopeTSIT iOS Build Guide v23.1.283", author="HopeTSIT team")
styles = getSampleStyleSheet()
H1 = ParagraphStyle('H1', parent=styles['Heading1'], fontSize=22, textColor=colors.HexColor("#EF4324"), spaceAfter=14, leading=26)
H2 = ParagraphStyle('H2', parent=styles['Heading2'], fontSize=15, textColor=colors.HexColor("#1F2937"), spaceAfter=10, spaceBefore=14, leading=18)
P = ParagraphStyle('P', parent=styles['BodyText'], fontSize=10, leading=14, alignment=TA_JUSTIFY)
CODE = ParagraphStyle('CODE', parent=styles['Code'], fontSize=9, leading=12, leftIndent=12, textColor=colors.HexColor("#0F172A"), backColor=colors.HexColor("#F1F5F9"))
INFO = ParagraphStyle('INFO', parent=styles['BodyText'], fontSize=9, leading=13, leftIndent=12, rightIndent=12, textColor=colors.HexColor("#075985"), backColor=colors.HexColor("#E0F2FE"), borderColor=colors.HexColor("#0EA5E9"), borderWidth=1, borderPadding=8)
GREEN = ParagraphStyle('GREEN', parent=styles['BodyText'], fontSize=10, leading=14, leftIndent=12, rightIndent=12, textColor=colors.HexColor("#065F46"), backColor=colors.HexColor("#D1FAE5"), borderColor=colors.HexColor("#10B981"), borderWidth=1, borderPadding=8)

flow = []
flow.append(Paragraph("HopeTSIT &mdash; iOS Build Guide", H1))
flow.append(Paragraph("Version 23.1.283 (Build 283)", H2))
flow.append(Spacer(1, 0.4*cm))
flow.append(Paragraph(
    "Delta v23.1.282 to v23.1.283 : DECOUPLAGE du plan PawFamily et de l'abo "
    "PawFollow individuel (timers independants) → prendre l'un ne desactive "
    "plus l'autre, et un mois individuel = 30 jours (plus d'empilage). Plus : "
    "les badges du profil ne debordent plus (FittedBox).", P))
flow.append(Spacer(1, 0.5*cm))
flow.append(Paragraph(
    "v23.1.283 &mdash; CHANGEMENT BACKEND IMPORTANT (abonnements). Nouveau champ "
    "familyExpiry + migration auto des anciennes subs famille. APK universal. "
    "S'active apres deploiement Render. Aucune migration DB manuelle (migration "
    "a l'ecriture).", GREEN))
flow.append(PageBreak())

flow.append(Paragraph("Changelog v23.1.283", H1))

flow.append(Paragraph("1. PawFollow vs PawFamily &mdash; RACINE", H2))
flow.append(Paragraph(
    "Symptome : prendre PawFollow ou PawFamily desactivait l'autre, et un mois "
    "affichait 300 j au lieu de 30. CAUSE : l'abo individuel et le plan Famille "
    "partageaient UN SEUL champ plan + currentPeriodEnd → ecrasement mutuel + "
    "empilage des jours sur le meme compteur. FIX : la Famille a desormais son "
    "PROPRE timer familyExpiry, independant de l'individuel.", P))
flow.append(Paragraph(
    "Nouveaux helpers : familyActiveMatch (requete tolerante familyExpiry OU "
    "ancien plan='famille'), migrateLegacyFamily (deplace a l'ecriture une "
    "ancienne sub famille vers familyExpiry et libere le slot individuel). "
    "hasActivePawFollow / isInSameFamily / /me/benefits / mapReports premium "
    "rendus familyExpiry-aware (retro-compat totale, aucune perte de premium "
    "pour les titulaires famille).", INFO))
flow.append(Paragraph(
    "Resultat : prendre PawFollow n'affecte plus la Famille et vice-versa ; les "
    "2 badges coexistent ; un mois individuel sur un slot vide = exactement "
    "30 j (la migration sort d'abord la famille du compteur individuel).", P))

flow.append(Paragraph("2. Badges du profil qui debordaient", H2))
flow.append(Paragraph(
    "Les cellules demi-largeur etaient trop etroites pour 'Famille . 1290 j'. "
    "Chaque pilule est maintenant dans un FittedBox(scaleDown) → elle se reduit "
    "pour TOUJOURS tenir dans sa colonne, sans rogner le texte ni deborder.", P))
flow.append(PageBreak())

flow.append(Paragraph("Build iOS &mdash; etapes Xcode", H1))
flow.append(Paragraph("Etape 1 &mdash; Pull v283", H2))
flow.append(Paragraph("git pull origin main<br/>cd frontend &amp;&amp; flutter clean &amp;&amp; flutter pub get<br/>cd ios &amp;&amp; pod install --repo-update", CODE))
flow.append(Paragraph("Etape 2 &mdash; Smoke test (apres deploiement Render)", H2))
flow.append(Paragraph(
    "Abonnements : prendre PawFollow Mensuel → badge PawFollow ~30 j, la Famille "
    "reste active. Prendre PawFamily → badge Famille, le PawFollow reste actif. "
    "Les DEUX peuvent etre actifs ensemble. Profil (3 roles) : les badges "
    "s'affichent ranges 2 par ligne SANS deborder, meme avec de grands nombres "
    "de jours.", P))
flow.append(Paragraph("Etape 3 &mdash; Archive Xcode", H2))
flow.append(Paragraph("scheme Runner, Any iOS Device, Product &gt; Archive, Distribute App &gt; App Store Connect (TestFlight d'abord).", P))
flow.append(Spacer(1, 0.5*cm))
flow.append(Paragraph("Build Android : flutter build apk --release -&gt; Downloads/HopeTSIT_v23.1.283.apk.", INFO))

doc.build(flow)
print(f"OK -> {OUT}")

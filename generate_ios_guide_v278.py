"""HopeTSIT iOS Build Guide v23.1.278 generator."""
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, PageBreak
from reportlab.lib.enums import TA_JUSTIFY

OUT = "C:/Users/Usuario/Downloads/HopeTSIT_iOS_Build_Guide_v23.1.278.pdf"
doc = SimpleDocTemplate(OUT, pagesize=A4, leftMargin=1.8*cm, rightMargin=1.8*cm,
    topMargin=1.8*cm, bottomMargin=1.8*cm, title="HopeTSIT iOS Build Guide v23.1.278", author="HopeTSIT team")
styles = getSampleStyleSheet()
H1 = ParagraphStyle('H1', parent=styles['Heading1'], fontSize=22, textColor=colors.HexColor("#EF4324"), spaceAfter=14, leading=26)
H2 = ParagraphStyle('H2', parent=styles['Heading2'], fontSize=15, textColor=colors.HexColor("#1F2937"), spaceAfter=10, spaceBefore=14, leading=18)
P = ParagraphStyle('P', parent=styles['BodyText'], fontSize=10, leading=14, alignment=TA_JUSTIFY)
CODE = ParagraphStyle('CODE', parent=styles['Code'], fontSize=9, leading=12, leftIndent=12, textColor=colors.HexColor("#0F172A"), backColor=colors.HexColor("#F1F5F9"))
INFO = ParagraphStyle('INFO', parent=styles['BodyText'], fontSize=9, leading=13, leftIndent=12, rightIndent=12, textColor=colors.HexColor("#075985"), backColor=colors.HexColor("#E0F2FE"), borderColor=colors.HexColor("#0EA5E9"), borderWidth=1, borderPadding=8)
GREEN = ParagraphStyle('GREEN', parent=styles['BodyText'], fontSize=10, leading=14, leftIndent=12, rightIndent=12, textColor=colors.HexColor("#065F46"), backColor=colors.HexColor("#D1FAE5"), borderColor=colors.HexColor("#10B981"), borderWidth=1, borderPadding=8)

flow = []
flow.append(Paragraph("HopeTSIT — iOS Build Guide", H1))
flow.append(Paragraph("Version 23.1.278 (Build 278)", H2))
flow.append(Spacer(1, 0.4*cm))
flow.append(Paragraph(
    "Delta v23.1.277 to v23.1.278 : page boutique PawFollow reparee + scindee "
    "(Suis ton animal / PawFamily violet), badge PawFollow retabli, libelles "
    "roles traduits + Famille, retrait membre famille qui reprend la couleur, "
    "filtre 'Mon cercle', barre PawMap lisible en dark, chat Traduire reparti, "
    "et cote web : pricing famille separe/violet + cartes zoom/satellite.", P))
flow.append(Spacer(1, 0.5*cm))
flow.append(Paragraph(
    "v23.1.278 — Frontend + backend (/me/benefits pawFollowActive, translate "
    "MyMemory) + site web + admin. APK universal. Les changements backend ne "
    "s'activent qu'apres le deploiement Render (au push). Aucune migration DB.", GREEN))
flow.append(PageBreak())

flow.append(Paragraph("Changelog v23.1.278", H1))

flow.append(Paragraph("1. Boutique — page PawFollow reparee + scindee", H2))
flow.append(Paragraph(
    "La page PawFollow avait disparu (un Row CrossAxisAlignment.stretch dans un "
    "scroll -> hauteur non bornee -> erreur layout masquant les forfaits). Fix "
    "IntrinsicHeight. Reorganisee en 2 sections sur la meme page : 'Suis ton "
    "animal' (Mensuel + Annuel) et 'PawFamily' (titre VIOLET, forfait Famille).", P))

flow.append(Paragraph("2. Badge profil PawFollow + Family", H2))
flow.append(Paragraph(
    "Le backend /users/me/benefits expose desormais pawFollowActive (premium "
    "individuel/staff) distinct de familyActive -> le badge dore PawFollow "
    "s'affiche EN PLUS du badge violet Family quand les deux sont actifs.", P))

flow.append(Paragraph("3. Mes amis — roles + retrait famille", H2))
flow.append(Paragraph(
    "Libelles de role TRADUITS (Promeneur / Petsitter / Proprietaire), et "
    "'Famille' quand l'ami est violet. Quand on retire un membre de la famille, "
    "la tuile reprend immediatement la couleur du role (l'Obx depend maintenant "
    "de familyMembers.length).", P))

flow.append(Paragraph("4. PawMap — 'Mon cercle' + dark mode", H2))
flow.append(Paragraph(
    "Le filtre 'Amis' (amis + famille) est renomme 'Mon cercle' (6 langues). La "
    "barre de filtres est fixee en surface claire (blanc + texte sombre + ombre) "
    "car la GoogleMap reste toujours claire -> lisible en dark mode.", INFO))

flow.append(Paragraph("5. Chat Traduire repare", H2))
flow.append(Paragraph(
    "Le bouton Traduire ne marchait pas : le backend filtrait les traductions "
    "MyMemory avec match < 0.5 (rejetait des trads valides). Filtre retire + "
    "timeouts 6s sur les fetch -> la traduction fonctionne (auto-detect source).", P))

flow.append(Paragraph("6. Web + Admin", H2))
flow.append(Paragraph(
    "Site : pricing PawFollow scinde (Suis ton animal / PawFamily violet) ; "
    "PawMap (/map et /friends/live) avec zoom +/- , vue Satellite (Esri) et "
    "maxZoom 19 (zoom rue). Admin : editeur de tarifs scinde PawFollow / "
    "PawFamily + filtre/label/couleur Famille dans l'activite boutique.", P))
flow.append(PageBreak())

flow.append(Paragraph("Build iOS — etapes Xcode", H1))
flow.append(Paragraph("Etape 1 — Pull v278", H2))
flow.append(Paragraph("git pull origin main<br/>cd frontend &amp;&amp; flutter clean &amp;&amp; flutter pub get<br/>cd ios &amp;&amp; pod install --repo-update", CODE))
flow.append(Paragraph("Etape 2 — Smoke test", H2))
flow.append(Paragraph(
    "Boutique > onglet PawFollow : 2 sections visibles (Suis ton animal / "
    "PawFamily violet). Profil : badge PawFollow dore + Family violet. Mes amis : "
    "roles traduits ; retirer un membre famille -> couleur du role revient. Chat : "
    "bouton Traduire traduit vraiment. PawMap : filtre 'Mon cercle', barre lisible "
    "en dark mode.", P))
flow.append(Paragraph("Etape 3 — Archive Xcode", H2))
flow.append(Paragraph("scheme Runner, Any iOS Device, Product &gt; Archive, Distribute App &gt; App Store Connect (TestFlight d'abord).", P))
flow.append(Spacer(1, 0.5*cm))
flow.append(Paragraph("Build Android : flutter build apk --release -> Downloads/HopeTSIT_v23.1.278.apk.", INFO))

doc.build(flow)
print(f"OK -> {OUT}")

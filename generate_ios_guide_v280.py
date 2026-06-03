"""HopeTSIT iOS Build Guide v23.1.280 generator."""
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, PageBreak
from reportlab.lib.enums import TA_JUSTIFY

OUT = "C:/Users/Usuario/Downloads/HopeTSIT_iOS_Build_Guide_v23.1.280.pdf"
doc = SimpleDocTemplate(OUT, pagesize=A4, leftMargin=1.8*cm, rightMargin=1.8*cm,
    topMargin=1.8*cm, bottomMargin=1.8*cm, title="HopeTSIT iOS Build Guide v23.1.280", author="HopeTSIT team")
styles = getSampleStyleSheet()
H1 = ParagraphStyle('H1', parent=styles['Heading1'], fontSize=22, textColor=colors.HexColor("#EF4324"), spaceAfter=14, leading=26)
H2 = ParagraphStyle('H2', parent=styles['Heading2'], fontSize=15, textColor=colors.HexColor("#1F2937"), spaceAfter=10, spaceBefore=14, leading=18)
P = ParagraphStyle('P', parent=styles['BodyText'], fontSize=10, leading=14, alignment=TA_JUSTIFY)
CODE = ParagraphStyle('CODE', parent=styles['Code'], fontSize=9, leading=12, leftIndent=12, textColor=colors.HexColor("#0F172A"), backColor=colors.HexColor("#F1F5F9"))
INFO = ParagraphStyle('INFO', parent=styles['BodyText'], fontSize=9, leading=13, leftIndent=12, rightIndent=12, textColor=colors.HexColor("#075985"), backColor=colors.HexColor("#E0F2FE"), borderColor=colors.HexColor("#0EA5E9"), borderWidth=1, borderPadding=8)
GREEN = ParagraphStyle('GREEN', parent=styles['BodyText'], fontSize=10, leading=14, leftIndent=12, rightIndent=12, textColor=colors.HexColor("#065F46"), backColor=colors.HexColor("#D1FAE5"), borderColor=colors.HexColor("#10B981"), borderWidth=1, borderPadding=8)

flow = []
flow.append(Paragraph("HopeTSIT &mdash; iOS Build Guide", H1))
flow.append(Paragraph("Version 23.1.280 (Build 280)", H2))
flow.append(Spacer(1, 0.4*cm))
flow.append(Paragraph(
    "Delta v23.1.279 to v23.1.280 : design des cartes amis aligne sur le site "
    "web (badge role couleur metier + badge FAMILLE violet + badge PawSpot) et "
    "anneau d'avatar dore/bleu selon l'option PawSpot. Applique sur l'onglet "
    "'Mes amis' ET l'onglet 'Famille'. Badges d'en-tete du profil reorganises "
    "(propre) : labels traduits dans les 6 langues, suffixe jours localise, plus "
    "de double badge PawFollow+Famille pour un titulaire famille. Cote web : "
    "anneau dore/bleu + badge PawSpot dans 'Suivre mes amis'.", P))
flow.append(Spacer(1, 0.5*cm))
flow.append(Paragraph(
    "v23.1.280 &mdash; Frontend + backend (pawSpotTier expose dans "
    "fetchUserMini / diagnose / family-members) + site web + i18n. APK "
    "universal. Les changements backend ne s'activent qu'apres le deploiement "
    "Render (au push). Aucune migration DB.", GREEN))
flow.append(PageBreak())

flow.append(Paragraph("Changelog v23.1.280", H1))

flow.append(Paragraph("1. Cartes amis &mdash; design web + anneau PawSpot", H2))
flow.append(Paragraph(
    "L'onglet 'Mes amis' (_FriendTile) et l'onglet 'Famille' (_FamilyMemberTile) "
    "affichent desormais le meme langage visuel que les cartes du site : un badge "
    "ROLE colore (couleur metier traduite : Promeneur vert / Petsitter bleu / "
    "Proprietaire violet), un badge FAMILLE violet EN PLUS si l'ami est membre de "
    "ma famille, et un badge PawSpot si l'option est active. Les badges sont dans "
    "un Wrap pour ne jamais deborder.", P))
flow.append(Paragraph(
    "Anneau d'avatar : dore (#F59E0B) pour Gold/Platinum, bleu (#3B82F6) pour "
    "Silver/Bronze, sinon violet famille (#8B5CF6), sinon couleur du role. "
    "Le PawSpot est prioritaire sur le violet famille.", INFO))

flow.append(Paragraph("2. Badges d'en-tete du profil &mdash; propre + i18n", H2))
flow.append(Paragraph(
    "active_benefits_row : les labels des badges (PawFollow, Famille, Boost, "
    "PawSpot) sont traduits dans les 6 langues et le suffixe jours est localise "
    "(' . 5 j' / ' . 5 d' / ' . 5 T.'). Fix important : un titulaire Famille "
    "n'affiche plus DEUX badges (PawFollow + Famille) en mode fallback "
    "(isPremium=true) &mdash; on soustrait familyActive pour un seul badge "
    "propre. Couleur PawFollow alignee en dore (#F59E0B).", P))

flow.append(Paragraph("3. Backend &mdash; pawSpotTier expose partout", H2))
flow.append(Paragraph(
    "fetchUserMini calcule le tier PawSpot ACTIF (mapBoostTier si mapBoostExpiry "
    "> now) et le renvoie. Il est donc disponible dans /friends "
    "(enrichFriendship), /friends/diagnose (otherPawSpotTier) et "
    "/friends/family/members. Le frontend (app + web) dessine l'anneau a partir "
    "de ce tier.", P))

flow.append(Paragraph("4. Site web &mdash; Suivre mes amis", H2))
flow.append(Paragraph(
    "friends/live : anneau d'avatar dore/bleu (helper pawSpotRingColor, "
    "identique au switch Dart) + badge PawSpot dans TOUTES les sections "
    "(Famille, Amis, Pet-sitters, Promeneurs). Cle i18n "
    "friends_live_badge_pawspot ajoutee dans les 6 langues. FriendOther type "
    "etendu avec pawSpotTier.", INFO))
flow.append(PageBreak())

flow.append(Paragraph("Build iOS &mdash; etapes Xcode", H1))
flow.append(Paragraph("Etape 1 &mdash; Pull v280", H2))
flow.append(Paragraph("git pull origin main<br/>cd frontend &amp;&amp; flutter clean &amp;&amp; flutter pub get<br/>cd ios &amp;&amp; pod install --repo-update", CODE))
flow.append(Paragraph("Etape 2 &mdash; Smoke test (apres deploiement Render)", H2))
flow.append(Paragraph(
    "Mes amis : chaque carte montre le badge role (couleur metier) + FAMILLE si "
    "famille ; un ami avec PawSpot a un anneau dore/bleu et un badge PawSpot. "
    "Onglet Famille : meme design. Profil (3 roles) : un titulaire famille n'a "
    "qu'UN badge Famille violet (pas de PawFollow en double) ; labels traduits "
    "selon la langue. Site web 'Suivre mes amis' : anneau + badge PawSpot "
    "visibles.", P))
flow.append(Paragraph("Etape 3 &mdash; Archive Xcode", H2))
flow.append(Paragraph("scheme Runner, Any iOS Device, Product &gt; Archive, Distribute App &gt; App Store Connect (TestFlight d'abord).", P))
flow.append(Spacer(1, 0.5*cm))
flow.append(Paragraph("Build Android : flutter build apk --release -&gt; Downloads/HopeTSIT_v23.1.280.apk.", INFO))

doc.build(flow)
print(f"OK -> {OUT}")

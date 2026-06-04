"""HopeTSIT iOS Build Guide v23.1.281 generator."""
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, PageBreak
from reportlab.lib.enums import TA_JUSTIFY

OUT = "C:/Users/Usuario/Downloads/HopeTSIT_iOS_Build_Guide_v23.1.281.pdf"
doc = SimpleDocTemplate(OUT, pagesize=A4, leftMargin=1.8*cm, rightMargin=1.8*cm,
    topMargin=1.8*cm, bottomMargin=1.8*cm, title="HopeTSIT iOS Build Guide v23.1.281", author="HopeTSIT team")
styles = getSampleStyleSheet()
H1 = ParagraphStyle('H1', parent=styles['Heading1'], fontSize=22, textColor=colors.HexColor("#EF4324"), spaceAfter=14, leading=26)
H2 = ParagraphStyle('H2', parent=styles['Heading2'], fontSize=15, textColor=colors.HexColor("#1F2937"), spaceAfter=10, spaceBefore=14, leading=18)
P = ParagraphStyle('P', parent=styles['BodyText'], fontSize=10, leading=14, alignment=TA_JUSTIFY)
CODE = ParagraphStyle('CODE', parent=styles['Code'], fontSize=9, leading=12, leftIndent=12, textColor=colors.HexColor("#0F172A"), backColor=colors.HexColor("#F1F5F9"))
INFO = ParagraphStyle('INFO', parent=styles['BodyText'], fontSize=9, leading=13, leftIndent=12, rightIndent=12, textColor=colors.HexColor("#075985"), backColor=colors.HexColor("#E0F2FE"), borderColor=colors.HexColor("#0EA5E9"), borderWidth=1, borderPadding=8)
GREEN = ParagraphStyle('GREEN', parent=styles['BodyText'], fontSize=10, leading=14, leftIndent=12, rightIndent=12, textColor=colors.HexColor("#065F46"), backColor=colors.HexColor("#D1FAE5"), borderColor=colors.HexColor("#10B981"), borderWidth=1, borderPadding=8)

flow = []
flow.append(Paragraph("HopeTSIT &mdash; iOS Build Guide", H1))
flow.append(Paragraph("Version 23.1.281 (Build 281)", H2))
flow.append(Spacer(1, 0.4*cm))
flow.append(Paragraph(
    "Delta v23.1.280 to v23.1.281 : correction de l'ajout/retrait de membre "
    "famille (titulaire vs membre), badges du profil rangés 2 par ligne, anneau "
    "PawSpot affiché aussi pour le tier de base, et barre zoom +/- de la PawMap "
    "lisible en mode sombre.", P))
flow.append(Spacer(1, 0.5*cm))
flow.append(Paragraph(
    "v23.1.281 &mdash; Frontend + backend (résolveur famille robuste + isHolder "
    "+ PawSpot bronze). APK universal. Les changements backend ne s'activent "
    "qu'apres le deploiement Render (au push). Aucune migration DB.", GREEN))
flow.append(PageBreak())

flow.append(Paragraph("Changelog v23.1.281", H1))

flow.append(Paragraph("1. Ajout/retrait membre famille &mdash; RACINE", H2))
flow.append(Paragraph(
    "Symptome : 'Abonnement PawFollow Famille requis' a l'ajout, et retrait "
    "impossible, alors que la carte 'Famille active 2/5' s'affiche. CAUSE : la "
    "carte s'affiche que l'on soit TITULAIRE ou MEMBRE d'une famille ; l'app "
    "montrait toujours l'UI titulaire ('Inviter un membre') qui echoue forcement "
    "si on n'est pas le titulaire. Le retrait echouait aussi (query stricte sur "
    "userId, sans self-heal).", P))
flow.append(Paragraph(
    "Fix : resolveOwnFamilySub gagne un RECOURS PAR E-MAIL (retrouve la sub "
    "Famille meme rattachee a un autre de tes roles au meme e-mail) + log "
    "diagnostic. Le DELETE est unifie sur ce resolveur. Le GET /family/members "
    "renvoie isHolder + holder (calcule avec le meme resolveur) → l'app affiche "
    "l'UI titulaire (avec ajout qui marche) OU une banniere 'Tu es membre de la "
    "famille de X' (bouton retirer masque).", INFO))

flow.append(Paragraph("2. Badges du profil &mdash; 2 par ligne", H2))
flow.append(Paragraph(
    "active_benefits_row : les badges (PawFollow / Famille / Boost / PawSpot) "
    "sont ranges en grille 2 colonnes (2 par ligne) au lieu d'un Wrap qui "
    "empilait selon la largeur. Identique sur les 3 profils owner/sitter/walker.", P))

flow.append(Paragraph("3. Anneau PawSpot 'normal'", H2))
flow.append(Paragraph(
    "Un PawSpot de base a mapBoostExpiry actif MAIS mapBoostTier=null → "
    "pawSpotTier devenait null → aucun anneau (seule la couleur du role "
    "s'affichait). Fix : des que le boost est ACTIF on retombe sur 'bronze' → il "
    "y a TOUJOURS un anneau (bleu bronze/silver, dore gold/platinum). Vaut pour "
    "l'app ET les cartes du site web (meme champ pawSpotTier).", P))

flow.append(Paragraph("4. Barre zoom +/- en mode sombre", H2))
flow.append(Paragraph(
    "La pilule des controles carte est blanche (lisible sur la carte claire) "
    "mais les icones suivaient le theme (textPrimary) → blanches en dark mode → "
    "barre invisible. Fix : icones en ton FIXE fonce #1F2937 (lisible en clair "
    "et sombre).", INFO))
flow.append(PageBreak())

flow.append(Paragraph("Build iOS &mdash; etapes Xcode", H1))
flow.append(Paragraph("Etape 1 &mdash; Pull v281", H2))
flow.append(Paragraph("git pull origin main<br/>cd frontend &amp;&amp; flutter clean &amp;&amp; flutter pub get<br/>cd ios &amp;&amp; pod install --repo-update", CODE))
flow.append(Paragraph("Etape 2 &mdash; Smoke test (apres deploiement Render)", H2))
flow.append(Paragraph(
    "Famille : si titulaire → 'Inviter un membre' fonctionne (meme si la sub "
    "etait sur un autre de tes roles) ; si membre → banniere 'Tu es membre de la "
    "famille de X'. Profil (3 roles) : badges ranges 2 par ligne. PawSpot : un "
    "ami avec PawSpot de base a un anneau bleu (pas seulement la couleur du "
    "role). PawMap en mode sombre : la barre +/- et les boutons satellite/amis "
    "sont visibles (icones foncees sur pilule blanche).", P))
flow.append(Paragraph("Etape 3 &mdash; Archive Xcode", H2))
flow.append(Paragraph("scheme Runner, Any iOS Device, Product &gt; Archive, Distribute App &gt; App Store Connect (TestFlight d'abord).", P))
flow.append(Spacer(1, 0.5*cm))
flow.append(Paragraph("Build Android : flutter build apk --release -&gt; Downloads/HopeTSIT_v23.1.281.apk.", INFO))

doc.build(flow)
print(f"OK -> {OUT}")

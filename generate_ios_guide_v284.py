"""HopeTSIT iOS Build Guide v23.1.284 generator."""
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, PageBreak
from reportlab.lib.enums import TA_JUSTIFY

OUT = "C:/Users/Usuario/Downloads/HopeTSIT_iOS_Build_Guide_v23.1.284.pdf"
doc = SimpleDocTemplate(OUT, pagesize=A4, leftMargin=1.8*cm, rightMargin=1.8*cm,
    topMargin=1.8*cm, bottomMargin=1.8*cm, title="HopeTSIT iOS Build Guide v23.1.284", author="HopeTSIT team")
styles = getSampleStyleSheet()
H1 = ParagraphStyle('H1', parent=styles['Heading1'], fontSize=22, textColor=colors.HexColor("#EF4324"), spaceAfter=14, leading=26)
H2 = ParagraphStyle('H2', parent=styles['Heading2'], fontSize=15, textColor=colors.HexColor("#1F2937"), spaceAfter=10, spaceBefore=14, leading=18)
P = ParagraphStyle('P', parent=styles['BodyText'], fontSize=10, leading=14, alignment=TA_JUSTIFY)
CODE = ParagraphStyle('CODE', parent=styles['Code'], fontSize=9, leading=12, leftIndent=12, textColor=colors.HexColor("#0F172A"), backColor=colors.HexColor("#F1F5F9"))
INFO = ParagraphStyle('INFO', parent=styles['BodyText'], fontSize=9, leading=13, leftIndent=12, rightIndent=12, textColor=colors.HexColor("#075985"), backColor=colors.HexColor("#E0F2FE"), borderColor=colors.HexColor("#0EA5E9"), borderWidth=1, borderPadding=8)
GREEN = ParagraphStyle('GREEN', parent=styles['BodyText'], fontSize=10, leading=14, leftIndent=12, rightIndent=12, textColor=colors.HexColor("#065F46"), backColor=colors.HexColor("#D1FAE5"), borderColor=colors.HexColor("#10B981"), borderWidth=1, borderPadding=8)

flow = []
flow.append(Paragraph("HopeTSIT &mdash; iOS Build Guide", H1))
flow.append(Paragraph("Version 23.1.284 (Build 284)", H2))
flow.append(Spacer(1, 0.4*cm))
flow.append(Paragraph(
    "Delta v23.1.283 to v23.1.284 : détection famille robuste (par DATE, plus "
    "de re-achat pour débloquer l'invitation), rafraîchissement des jours après "
    "achat (bouton boutique + badge profil), et SUIVI (follow) d'un ami sur la "
    "PawMap du site web (comme sur le téléphone).", P))
flow.append(Spacer(1, 0.5*cm))
flow.append(Paragraph(
    "v23.1.284 &mdash; Backend (détection famille par date + migration à la "
    "lecture) + app (refresh jours) + site web (follow). APK universal. Backend "
    "actif apres deploiement Render. Aucune migration DB manuelle.", GREEN))
flow.append(PageBreak())

flow.append(Paragraph("Changelog v23.1.284", H1))

flow.append(Paragraph("1. Famille — re-achat inutile (RACINE)", H2))
flow.append(Paragraph(
    "Symptome : plan famille actif mais il fallait RE-acheter pour debloquer "
    "'ajouter par nom/email'. CAUSE : la detection 'famille active' exigeait "
    "status:'active', or ce champ peut etre perime (past_due/canceled alors que "
    "la periode payee court encore). FIX : detection par DATE seule "
    "(currentPeriodEnd/familyExpiry futur = actif). familyActiveMatch, "
    "hasActivePawFollow et /me/benefits passes en date. resolveOwnFamilySub "
    "migre les anciennes subs famille A LA LECTURE et les re-rattache au role "
    "courant → boutique et onglet Famille coherents.", P))

flow.append(Paragraph("2. Les jours ne se rajoutent pas", H2))
flow.append(Paragraph(
    "La carte statut de la boutique ne chargeait /me/benefits qu'au initState, "
    "jamais apres un achat → jours figes. FIX : re-fetch /me/benefits + "
    "notification du badge profil apres achat, et ecoute du tick de "
    "rafraichissement (achat depuis n'importe ou). Le backend prolongeait deja "
    "correctement la duree (v283) ; c'etait l'affichage.", INFO))

flow.append(Paragraph("3. PawMap site web — synchro + follow", H2))
flow.append(Paragraph(
    "La synchro temps reel existait deja (socket map:friend-position). Ajout du "
    "SUIVI : cliquer un ami → la camera le traque en continu (zoom rapproche, "
    "recentrage a chaque nouvelle position live), banniere 'Suivi en direct — "
    "[Nom]' + bouton Arreter, et arret du suivi si on deplace la carte a la main "
    "(parite app). Traduit en 6 langues.", P))
flow.append(PageBreak())

flow.append(Paragraph("Build iOS &mdash; etapes Xcode", H1))
flow.append(Paragraph("Etape 1 &mdash; Pull v284", H2))
flow.append(Paragraph("git pull origin main<br/>cd frontend &amp;&amp; flutter clean &amp;&amp; flutter pub get<br/>cd ios &amp;&amp; pod install --repo-update", CODE))
flow.append(Paragraph("Etape 2 &mdash; Smoke test (apres deploiement Render)", H2))
flow.append(Paragraph(
    "Famille : ouvrir l'onglet Famille → 'ajouter par nom/email' debloque SANS "
    "re-acheter. Jours : prendre un mois → les jours augmentent tout de suite "
    "dans le bouton boutique ET le badge profil. Site web PawMap : cliquer un "
    "ami en ligne → la carte le suit en direct + banniere 'Suivi en direct' avec "
    "Arreter ; deplacer la carte a la main arrete le suivi.", P))
flow.append(Paragraph("Etape 3 &mdash; Archive Xcode", H2))
flow.append(Paragraph("scheme Runner, Any iOS Device, Product &gt; Archive, Distribute App &gt; App Store Connect (TestFlight d'abord).", P))
flow.append(Spacer(1, 0.5*cm))
flow.append(Paragraph("Build Android : flutter build apk --release -&gt; Downloads/HopeTSIT_v23.1.284.apk.", INFO))

doc.build(flow)
print(f"OK -> {OUT}")

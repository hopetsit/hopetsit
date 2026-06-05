"""HopeTSIT iOS Build Guide v23.1.287 generator."""
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, PageBreak
from reportlab.lib.enums import TA_JUSTIFY

OUT = "C:/Users/Usuario/Downloads/HopeTSIT_iOS_Build_Guide_v23.1.287.pdf"
doc = SimpleDocTemplate(OUT, pagesize=A4, leftMargin=1.8*cm, rightMargin=1.8*cm,
    topMargin=1.8*cm, bottomMargin=1.8*cm, title="HopeTSIT iOS Build Guide v23.1.287", author="HopeTSIT team")
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
flow.append(Paragraph("Version 23.1.287 (Build 287)", H2))
flow.append(Spacer(1, 0.4*cm))
flow.append(Paragraph(
    "App : bouton 'Rien' dans le filtre de la PawMap (cache TOUS les lieux, "
    "l'oppose de 'Tous'). Plus un hotfix critique du dashboard admin : une "
    "regression de mise en page (balise mal fermee) cassait toutes les pages "
    "apres la section Comptabilite, et le solde des portefeuilles s'affichait a "
    "0 par ligne.", P))
flow.append(Spacer(1, 0.5*cm))
flow.append(Paragraph(
    "v23.1.287 &mdash; Frontend (bouton Rien PawMap) + backend "
    "(alias solde portefeuilles) + admin_dashboard.html (fix structure HTML). "
    "APK universal. Backend/admin actifs apres deploiement Render. Aucune "
    "migration DB.", GREEN))
flow.append(PageBreak())

flow.append(Paragraph("Changelog v23.1.287", H1))

flow.append(Paragraph("1. PawMap &mdash; bouton 'Rien'", H2))
flow.append(Paragraph(
    "Le filtre de lieux avait deja 'Tous' (tout afficher). On ajoute 'Rien' : "
    "un appui cache TOUS les POI d'un coup (la couche POI est desactivee via "
    "_showPois=false). Le bouton actif est surligne. Cocher une categorie dans "
    "la checklist reactive la couche. 'Rien' est aussi dispo dans les actions "
    "de la checklist. Traduit en 6 langues (Rien / None / Nada / Keine / "
    "Niente / Nenhum).", P))

flow.append(Paragraph("2. Dashboard admin &mdash; HOTFIX mise en page (RACINE)", H2))
flow.append(Paragraph(
    "Symptome (capture Daniel) : 'page admin plein d'erreur', 'pages plus en "
    "plein page mais a droite', annonces et services 'pas a jour'. CAUSE : dans "
    "la section Comptabilite ajoutee en v286, un &lt;p&gt; etait ferme par "
    "&lt;/div&gt; au lieu de &lt;/p&gt;. Le &lt;/div&gt; en trop fermait un "
    "conteneur parent to TOUTES les pages situees apres dans le HTML "
    "(annonces, services, boutique, pricing, pawmap, bugs) se retrouvaient HORS "
    "de la zone de contenu to decalees a droite / superposees / en erreur. "
    "FIX : &lt;/div&gt; to &lt;/p&gt;. HTML re-equilibre (div 657/657, p 27/27).", P))
flow.append(Paragraph(
    "Consequence directe : annonces et services etaient APRES la section cassee "
    "dans le HTML to leur affichage (dont la description des annonces) revient "
    "automatiquement. CGU et Confidentialite sont AVANT la zone cassee to elles "
    "n'etaient pas touchees par ce bug ; leurs endpoints existent et sont "
    "corrects.", INFO))

flow.append(Paragraph("3. Dashboard admin &mdash; solde portefeuilles", H2))
flow.append(Paragraph(
    "Symptome : le total affichait 21 EUR mais chaque ligne 0 EUR. CAUSE : le "
    "dashboard lisait w.balance / w.currency, or la base expose walletBalance / "
    "walletCurrency. FIX : la route /admin/wallets renvoie maintenant les alias "
    "balance / currency to chaque ligne affiche le bon solde.", P))
flow.append(PageBreak())

flow.append(Paragraph("Build iOS &mdash; etapes Xcode", H1))
flow.append(Paragraph("Etape 1 &mdash; Pull v287", H2))
flow.append(Paragraph("git pull origin main<br/>cd frontend &amp;&amp; flutter clean &amp;&amp; flutter pub get<br/>cd ios &amp;&amp; pod install --repo-update", CODE))
flow.append(Paragraph("Etape 2 &mdash; Smoke test (apres deploiement Render)", H2))
flow.append(Paragraph(
    "PawMap : appuyer sur 'Rien' to tous les lieux disparaissent ; 'Tous' to "
    "tout revient ; cocher une categorie to la couche se reactive. Dashboard "
    "admin (rafraichir la page apres deploiement Render) : plus aucune page "
    "decalee a droite, la description des annonces s'affiche, la page services "
    "s'affiche, et le portefeuille montre le bon solde par ligne.", P))
flow.append(Paragraph("Etape 3 &mdash; Archive Xcode", H2))
flow.append(Paragraph("scheme Runner, Any iOS Device, Product &gt; Archive, Distribute App &gt; App Store Connect (TestFlight d'abord).", P))
flow.append(Spacer(1, 0.5*cm))
flow.append(Paragraph("Build Android : flutter build apk --release -&gt; Downloads/HopeTSit_v287.apk.", INFO))

doc.build(flow)
print(f"OK -> {OUT}")

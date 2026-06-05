"""HopeTSIT iOS Build Guide v23.1.286 generator."""
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, PageBreak
from reportlab.lib.enums import TA_JUSTIFY

OUT = "C:/Users/Usuario/Downloads/HopeTSIT_iOS_Build_Guide_v23.1.286.pdf"
doc = SimpleDocTemplate(OUT, pagesize=A4, leftMargin=1.8*cm, rightMargin=1.8*cm,
    topMargin=1.8*cm, bottomMargin=1.8*cm, title="HopeTSIT iOS Build Guide v23.1.286", author="HopeTSIT team")
styles = getSampleStyleSheet()
H1 = ParagraphStyle('H1', parent=styles['Heading1'], fontSize=22, textColor=colors.HexColor("#EF4324"), spaceAfter=14, leading=26)
H2 = ParagraphStyle('H2', parent=styles['Heading2'], fontSize=15, textColor=colors.HexColor("#1F2937"), spaceAfter=10, spaceBefore=14, leading=18)
P = ParagraphStyle('P', parent=styles['BodyText'], fontSize=10, leading=14, alignment=TA_JUSTIFY)
CODE = ParagraphStyle('CODE', parent=styles['Code'], fontSize=9, leading=12, leftIndent=12, textColor=colors.HexColor("#0F172A"), backColor=colors.HexColor("#F1F5F9"))
INFO = ParagraphStyle('INFO', parent=styles['BodyText'], fontSize=9, leading=13, leftIndent=12, rightIndent=12, textColor=colors.HexColor("#075985"), backColor=colors.HexColor("#E0F2FE"), borderColor=colors.HexColor("#0EA5E9"), borderWidth=1, borderPadding=8)
GREEN = ParagraphStyle('GREEN', parent=styles['BodyText'], fontSize=10, leading=14, leftIndent=12, rightIndent=12, textColor=colors.HexColor("#065F46"), backColor=colors.HexColor("#D1FAE5"), borderColor=colors.HexColor("#10B981"), borderWidth=1, borderPadding=8)

flow = []
flow.append(Paragraph("HopeTSIT &mdash; iOS Build Guide", H1))
flow.append(Paragraph("Version 23.1.286 (Build 286)", H2))
flow.append(Spacer(1, 0.4*cm))
flow.append(Paragraph(
    "Lot groupe v285 + v286 : menu de filtres PawMap (checklist 2 colonnes), "
    "texte Signaler PawPass to PawFamily, deep-links des mails de notification "
    "reparees (un mail message ouvre enfin les Messages), et refonte du "
    "dashboard admin (titre HoPetSit, i18n EN/ES du menu, section Comptabilite, "
    "noms dans le chat).", P))
flow.append(Spacer(1, 0.5*cm))
flow.append(Paragraph(
    "v23.1.286 &mdash; Frontend (deep-links, menu PawMap) + backend "
    "(admin conversations noms) + admin_dashboard.html. APK universal. Backend/"
    "admin actifs apres deploiement Render. Aucune migration DB.", GREEN))
flow.append(PageBreak())

flow.append(Paragraph("Changelog v23.1.286", H1))

flow.append(Paragraph("1. Deep-links des mails &mdash; RACINE", H2))
flow.append(Paragraph(
    "Symptome : un mail 'message' ouvrait la page Signaler. CAUSE : "
    "deep_link_service routait vers des routes nommees NON enregistrees "
    "(Get.toNamed('/chat'...)) to echec silencieux to l'app restait sur "
    "l'onglet par defaut (PawMap + bouton Signaler). FIX : on pousse le VRAI "
    "ecran selon le role (chat/reservations/notifications/profil/boutique), "
    "comme le faisait deja /friends. Tap cloche : walker utilise desormais "
    "l'ecran chat prestataire.", P))

flow.append(Paragraph("2. Menu de filtres PawMap + Signaler", H2))
flow.append(Paragraph(
    "Le filtre categories POI passe des puces horizontales a une checklist 2 "
    "colonnes repliable ('Lieux (N/10)' + 'Tous'). Page Signaler : 'PawFollow / "
    "PawPass' devient 'PawFollow / PawFamily' (6 langues).", INFO))

flow.append(Paragraph("3. Dashboard admin (navigateur)", H2))
flow.append(Paragraph(
    "Titre en haut a gauche : HoPetSit. Section 'Fonctionnalites v240 livrees' "
    "supprimee. i18n EN/ES : tout le menu de gauche (sections + 25 entrees) est "
    "maintenant traduit (avant : seul l'ecran login l'etait). Nouvelle section "
    "Comptabilite (Mon bilan) : MES benefices HoPetSit uniquement (commissions "
    "reservations + revenus boutique), export CSV pour le comptable. Chat : le "
    "backend resout les NOMS des participants to la liste affiche "
    "'Proprietaire vs Prestataire' au lieu d'un ID.", P))
flow.append(Paragraph(
    "Diagnostic 'pas a jour' : showPage() recharge chaque section au clic et "
    "tous les endpoints /admin/* existent et sont montes to les sections se "
    "rafraichissent bien. Si un chiffre precis est faux, c'est une agregation "
    "backend a corriger ponctuellement (preciser la section + la valeur).", INFO))
flow.append(PageBreak())

flow.append(Paragraph("Build iOS &mdash; etapes Xcode", H1))
flow.append(Paragraph("Etape 1 &mdash; Pull v286", H2))
flow.append(Paragraph("git pull origin main<br/>cd frontend &amp;&amp; flutter clean &amp;&amp; flutter pub get<br/>cd ios &amp;&amp; pod install --repo-update", CODE))
flow.append(Paragraph("Etape 2 &mdash; Smoke test (apres deploiement Render)", H2))
flow.append(Paragraph(
    "Mail 'message' to clic to ouvre les Messages (plus la page Signaler). "
    "PawMap : bouton 'Lieux (N/10)' ouvre la checklist 2 colonnes. Dashboard "
    "admin : titre HoPetSit, changer la langue EN/ES traduit le menu, section "
    "Comptabilite affiche commissions + boutique + export CSV, le chat affiche "
    "les noms.", P))
flow.append(Paragraph("Etape 3 &mdash; Archive Xcode", H2))
flow.append(Paragraph("scheme Runner, Any iOS Device, Product &gt; Archive, Distribute App &gt; App Store Connect (TestFlight d'abord).", P))
flow.append(Spacer(1, 0.5*cm))
flow.append(Paragraph("Build Android : flutter build apk --release -&gt; Downloads/HopeTSIT_v23.1.286.apk.", INFO))

doc.build(flow)
print(f"OK -> {OUT}")

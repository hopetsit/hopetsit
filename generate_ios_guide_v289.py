"""HopeTSIT iOS Build Guide v23.1.289 generator."""
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, PageBreak
from reportlab.lib.enums import TA_JUSTIFY

OUT = "C:/Users/Usuario/Downloads/HopeTSIT_iOS_Build_Guide_v23.1.289.pdf"
doc = SimpleDocTemplate(OUT, pagesize=A4, leftMargin=1.8*cm, rightMargin=1.8*cm,
    topMargin=1.8*cm, bottomMargin=1.8*cm, title="HopeTSIT iOS Build Guide v23.1.289", author="HopeTSIT team")
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
flow.append(Paragraph("Version 23.1.289 (Build 289)", H2))
flow.append(Spacer(1, 0.4*cm))
flow.append(Paragraph(
    "App : retrait du bouton 'Rien' du filtre de lieux PawMap (inutile, le "
    "toggle 'Lieux' masque deja tous les POI). Backend : auto-suppression des "
    "annonces 48h apres la fin du service, plus reparation de l'auto-fermeture "
    "qui ne fonctionnait pas, plus les correctifs admin v288 (annonces "
    "body+notes, CGV/Confidentialite pre-remplies, libelles services).", P))
flow.append(Spacer(1, 0.5*cm))
flow.append(Paragraph(
    "v23.1.289 &mdash; Frontend (PawMap) + backend (schema Post, scheduler "
    "nettoyage annonces, feeds, routes admin). APK universal. Backend/admin "
    "actifs apres deploiement Render. Aucune migration DB (changements "
    "additifs).", GREEN))
flow.append(PageBreak())

flow.append(Paragraph("Changelog v23.1.289", H1))

flow.append(Paragraph("1. PawMap &mdash; retrait du bouton 'Rien'", H2))
flow.append(Paragraph(
    "Le bouton 'Rien' (ajoute en v287) est retire de la barre de filtre ET des "
    "actions de la checklist. Pour masquer tous les lieux d'un coup, le toggle "
    "'Lieux' (rangee de couches, juste en dessous) fait deja exactement cela. "
    "_showPois reste pilote par ce toggle maitre.", P))

flow.append(Paragraph("2. Annonces &mdash; auto-suppression 48h (RACINE)", H2))
flow.append(Paragraph(
    "Symptome : les annonces de services termines ne s'effacaient jamais. "
    "CAUSE : le schema Post n'avait PAS les champs status / closedAt / "
    "closedReason. Or completeBooking() faisait $set sur ces champs ; Mongoose "
    "en strict mode SUPPRIME silencieusement les champs hors-schema, donc "
    "l'annonce n'etait jamais fermee et rien n'etait supprime. La feature "
    "existait (part 68) mais etait cassee depuis le debut.", P))
flow.append(Paragraph(
    "FIX : champs ajoutes au schema to la fin de service ferme l'annonce + pose "
    "closedAt. Nouveau postCleanupScheduler (toutes les heures) qui SUPPRIME "
    "definitivement l'annonce 48h apres closedAt (ou endDate passee de +48h "
    "pour les demandes perimees) et nettoie les Applications orphelines. Les "
    "feeds excluent desormais aussi les annonces 'closed'.", INFO))

flow.append(Paragraph("3. Admin v288 (rappel, deja deploye)", H2))
flow.append(Paragraph(
    "Annonces : affichage du texte (body + notes du proprietaire) au lieu de "
    "'(pas de texte)'. CGV + Confidentialite : pre-remplies avec le vrai texte "
    "legal (backend/legal/*.md) quand la base est vide. Services : libelle "
    "par defaut affiche par langue. Solde portefeuilles corrige. Layout admin "
    "repare.", P))
flow.append(PageBreak())

flow.append(Paragraph("Build iOS &mdash; etapes Xcode", H1))
flow.append(Paragraph("Etape 1 &mdash; Pull v288", H2))
flow.append(Paragraph("git pull origin main<br/>cd frontend &amp;&amp; flutter clean &amp;&amp; flutter pub get<br/>cd ios &amp;&amp; pod install --repo-update", CODE))
flow.append(Paragraph("Etape 2 &mdash; Smoke test (apres deploiement Render)", H2))
flow.append(Paragraph(
    "PawMap : le filtre de lieux n'a plus de bouton 'Rien' ; le toggle 'Lieux' "
    "masque/affiche tous les POI. Annonces : marquer un service comme termine "
    "to l'annonce disparait des feeds, puis est supprimee ~48h plus tard (le "
    "scheduler tourne toutes les heures). Dashboard admin : badge v288.", P))
flow.append(Paragraph("Etape 3 &mdash; Archive Xcode", H2))
flow.append(Paragraph("scheme Runner, Any iOS Device, Product &gt; Archive, Distribute App &gt; App Store Connect (TestFlight d'abord).", P))
flow.append(Spacer(1, 0.5*cm))
flow.append(Paragraph("Build Android : flutter build apk --release -&gt; Downloads/HopeTSit_v289.apk.", INFO))

doc.build(flow)
print(f"OK -> {OUT}")

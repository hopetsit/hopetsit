"""HopeTSIT iOS Build Guide v23.1.291 generator."""
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, PageBreak
from reportlab.lib.enums import TA_JUSTIFY

OUT = "C:/Users/Usuario/Downloads/HopeTSIT_iOS_Build_Guide_v23.1.291.pdf"
doc = SimpleDocTemplate(OUT, pagesize=A4, leftMargin=1.8*cm, rightMargin=1.8*cm,
    topMargin=1.8*cm, bottomMargin=1.8*cm, title="HopeTSIT iOS Build Guide v23.1.291", author="HopeTSIT team")
styles = getSampleStyleSheet()
H1 = ParagraphStyle('H1', parent=styles['Heading1'], fontSize=22, textColor=colors.HexColor("#EF4324"), spaceAfter=14, leading=26)
H2 = ParagraphStyle('H2', parent=styles['Heading2'], fontSize=15, textColor=colors.HexColor("#1F2937"), spaceAfter=10, spaceBefore=14, leading=18)
P = ParagraphStyle('P', parent=styles['BodyText'], fontSize=10, leading=14, alignment=TA_JUSTIFY)
CODE = ParagraphStyle('CODE', parent=styles['Code'], fontSize=9, leading=12, leftIndent=12, textColor=colors.HexColor("#0F172A"), backColor=colors.HexColor("#F1F5F9"))
INFO = ParagraphStyle('INFO', parent=styles['BodyText'], fontSize=9, leading=13, leftIndent=12, rightIndent=12, textColor=colors.HexColor("#075985"), backColor=colors.HexColor("#E0F2FE"), borderColor=colors.HexColor("#0EA5E9"), borderWidth=1, borderPadding=8)
GREEN = ParagraphStyle('GREEN', parent=styles['BodyText'], fontSize=10, leading=14, leftIndent=12, rightIndent=12, textColor=colors.HexColor("#065F46"), backColor=colors.HexColor("#D1FAE5"), borderColor=colors.HexColor("#10B981"), borderWidth=1, borderPadding=8)

flow = []
flow.append(Paragraph("HopeTSIT &mdash; iOS Build Guide", H1))
flow.append(Paragraph("Version 23.1.291 (Build 291)", H2))
flow.append(Spacer(1, 0.4*cm))
flow.append(Paragraph(
    "Note inline directement sur la carte de reservation de l'owner (maquette "
    "Daniel) : sous 'Suivi du service' une carte 'Comment s'est passe le "
    "service ?' avec 5 etoiles tappables + lien 'Noter le prestataire'. App "
    "uniquement (aucun changement backend).", P))
flow.append(Spacer(1, 0.5*cm))
flow.append(Paragraph(
    "v23.1.291 &mdash; Frontend uniquement (owner_bookings_screen, "
    "reviews_screen, i18n). APK universal. Aucune migration ni redeploiement "
    "backend.", GREEN))
flow.append(PageBreak())

flow.append(Paragraph("Changelog v23.1.291", H1))

flow.append(Paragraph("1. Note inline sur la carte owner (RACINE)", H2))
flow.append(Paragraph(
    "La maquette de Daniel montrait une note DIRECTEMENT sur la carte (pas un "
    "bouton sur un autre ecran). En v290 le bouton 'Laisser un avis' avait ete "
    "ajoute dans bookings_history_screen.dart, mais l'owner voit en realite "
    "owner_bookings_screen.dart (le 'Mes reservations' avec la carte 'Suivi du "
    "service') : mauvais fichier. Corrige.", P))
flow.append(Paragraph(
    "owner_bookings_screen.dart : nouvelle carte _buildReviewPrompt rendue juste "
    "sous ServiceConfirmationCard quand confirmationStatus=='confirmed' ou "
    "status termine. Affiche 'Comment s'est passe le service ?' + 5 etoiles "
    "tappables + lien 'Noter le prestataire'. Taper une etoile ouvre l'ecran "
    "d'avis avec cette note pre-selectionnee ; le lien l'ouvre vierge. Detecte "
    "sitter vs walker selon serviceType. Si deja note to ecran en mode edition "
    "(Modifier / Supprimer).", INFO))

flow.append(Paragraph("2. ReviewsScreen : parametre initialRating", H2))
flow.append(Paragraph(
    "Nouveau parametre optionnel initialRating, applique au montage si on n'est "
    "pas deja en edition d'un avis existant. 2 cles i18n x 6 langues "
    "(review_prompt_title, review_prompt_cta).", P))
flow.append(PageBreak())

flow.append(Paragraph("Build iOS &mdash; etapes Xcode", H1))
flow.append(Paragraph("Etape 1 &mdash; Pull v291", H2))
flow.append(Paragraph("git pull origin main<br/>cd frontend &amp;&amp; flutter clean &amp;&amp; flutter pub get<br/>cd ios &amp;&amp; pod install --repo-update", CODE))
flow.append(Paragraph("Etape 2 &mdash; Smoke test", H2))
flow.append(Paragraph(
    "Owner : ouvrir 'Mes reservations' sur une resa payee + service confirme to "
    "sous 'Suivi du service' la carte de note apparait. Taper une etoile to "
    "l'ecran d'avis s'ouvre avec la note. Envoyer to la note remonte sur le "
    "profil du prestataire. Re-ouvrir to mode edition (Modifier / Supprimer).", P))
flow.append(Paragraph("Etape 3 &mdash; Archive Xcode", H2))
flow.append(Paragraph("scheme Runner, Any iOS Device, Product &gt; Archive, Distribute App &gt; App Store Connect (TestFlight d'abord).", P))
flow.append(Spacer(1, 0.5*cm))
flow.append(Paragraph("Build Android : flutter build apk --release -&gt; Downloads/HopeTSit_v291.apk.", INFO))

doc.build(flow)
print(f"OK -> {OUT}")

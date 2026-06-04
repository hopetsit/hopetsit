"""HopeTSIT iOS Build Guide v23.1.282 generator."""
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, PageBreak
from reportlab.lib.enums import TA_JUSTIFY

OUT = "C:/Users/Usuario/Downloads/HopeTSIT_iOS_Build_Guide_v23.1.282.pdf"
doc = SimpleDocTemplate(OUT, pagesize=A4, leftMargin=1.8*cm, rightMargin=1.8*cm,
    topMargin=1.8*cm, bottomMargin=1.8*cm, title="HopeTSIT iOS Build Guide v23.1.282", author="HopeTSIT team")
styles = getSampleStyleSheet()
H1 = ParagraphStyle('H1', parent=styles['Heading1'], fontSize=22, textColor=colors.HexColor("#EF4324"), spaceAfter=14, leading=26)
H2 = ParagraphStyle('H2', parent=styles['Heading2'], fontSize=15, textColor=colors.HexColor("#1F2937"), spaceAfter=10, spaceBefore=14, leading=18)
P = ParagraphStyle('P', parent=styles['BodyText'], fontSize=10, leading=14, alignment=TA_JUSTIFY)
CODE = ParagraphStyle('CODE', parent=styles['Code'], fontSize=9, leading=12, leftIndent=12, textColor=colors.HexColor("#0F172A"), backColor=colors.HexColor("#F1F5F9"))
INFO = ParagraphStyle('INFO', parent=styles['BodyText'], fontSize=9, leading=13, leftIndent=12, rightIndent=12, textColor=colors.HexColor("#075985"), backColor=colors.HexColor("#E0F2FE"), borderColor=colors.HexColor("#0EA5E9"), borderWidth=1, borderPadding=8)
GREEN = ParagraphStyle('GREEN', parent=styles['BodyText'], fontSize=10, leading=14, leftIndent=12, rightIndent=12, textColor=colors.HexColor("#065F46"), backColor=colors.HexColor("#D1FAE5"), borderColor=colors.HexColor("#10B981"), borderWidth=1, borderPadding=8)

flow = []
flow.append(Paragraph("HopeTSIT &mdash; iOS Build Guide", H1))
flow.append(Paragraph("Version 23.1.282 (Build 282)", H2))
flow.append(Spacer(1, 0.4*cm))
flow.append(Paragraph(
    "Delta v23.1.281 to v23.1.282 : correction des badges premium qui avaient "
    "disparu du header de profil (regression v281), et ajout d'un bouton "
    "'Quitter la famille' pour les membres (qui ne peuvent pas gerer la famille "
    "d'un autre titulaire).", P))
flow.append(Spacer(1, 0.5*cm))
flow.append(Paragraph(
    "v23.1.282 &mdash; Frontend (layout badges robuste, bouton quitter) + "
    "backend (route POST /friends/family/leave). APK universal. Backend actif "
    "apres deploiement Render. Aucune migration DB.", GREEN))
flow.append(PageBreak())

flow.append(Paragraph("Changelog v23.1.282", H1))

flow.append(Paragraph("1. Badges premium disparus &mdash; RACINE", H2))
flow.append(Paragraph(
    "Regression v281 : la grille '2 colonnes' (Column -> Row avec Expanded + "
    "CrossAxisAlignment.stretch) cassait la mise en page dans le header du "
    "profil (largeur lache) → TOUT le sous-arbre des badges disparaissait, "
    "alors que les donnees /me/benefits etaient bonnes (la boutique affichait "
    "bien Family actif). Fix : layout robuste LayoutBuilder + Wrap de cellules "
    "a demi-largeur → on garde le '2 par ligne' SANS aucun risque de crash de "
    "layout. Repare sur les 3 profils owner/sitter/walker.", P))

flow.append(Paragraph("2. Famille bloquee &mdash; membre vs titulaire", H2))
flow.append(Paragraph(
    "Le compte etait MEMBRE de la famille d'un autre compte (cardellihermanos) "
    "→ il ne peut pas ajouter/retirer (reserve au titulaire). L'app l'affichait "
    "deja correctement ('Tu es membre de la famille de X'). On ajoute une "
    "SORTIE : bouton 'Quitter la famille' (+ route POST /friends/family/leave) "
    "→ le membre se retire lui-meme et redevient libre de creer/gerer sa propre "
    "famille (acheter PawFamily pour devenir titulaire).", INFO))

flow.append(Paragraph("3. 'Les deux abonnements'", H2))
flow.append(Paragraph(
    "Pas de vrai conflit : un plan Famille remplace le plan PawFollow individuel "
    "(une seule sub par couple userId/role ; le plan Famille inclut deja "
    "PawFollow pour le titulaire). L'appartenance famille est un mecanisme "
    "separe. Le 'bug' visible etait les badges disparus (corrige au point 1) ; "
    "PawFollow individuel + appartenance famille affichent desormais les 2 "
    "badges cote a cote.", P))
flow.append(PageBreak())

flow.append(Paragraph("Build iOS &mdash; etapes Xcode", H1))
flow.append(Paragraph("Etape 1 &mdash; Pull v282", H2))
flow.append(Paragraph("git pull origin main<br/>cd frontend &amp;&amp; flutter clean &amp;&amp; flutter pub get<br/>cd ios &amp;&amp; pod install --repo-update", CODE))
flow.append(Paragraph("Etape 2 &mdash; Smoke test (apres deploiement Render)", H2))
flow.append(Paragraph(
    "Profil (3 roles) : les badges premium (PawFollow / Famille / Boost / "
    "PawSpot) reapparaissent, ranges 2 par ligne. Onglet Famille en tant que "
    "membre : la banniere 'Tu es membre de la famille de X' affiche un bouton "
    "'Quitter la famille' qui fonctionne (apres avoir quitte, on peut devenir "
    "son propre titulaire). PawFollow individuel + membre famille : 2 badges "
    "affiches ensemble.", P))
flow.append(Paragraph("Etape 3 &mdash; Archive Xcode", H2))
flow.append(Paragraph("scheme Runner, Any iOS Device, Product &gt; Archive, Distribute App &gt; App Store Connect (TestFlight d'abord).", P))
flow.append(Spacer(1, 0.5*cm))
flow.append(Paragraph("Build Android : flutter build apk --release -&gt; Downloads/HopeTSIT_v23.1.282.apk.", INFO))

doc.build(flow)
print(f"OK -> {OUT}")

"""HopeTSIT iOS Build Guide v23.1.277 generator."""
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, PageBreak
from reportlab.lib.enums import TA_JUSTIFY

OUT = "C:/Users/Usuario/Downloads/HopeTSIT_iOS_Build_Guide_v23.1.277.pdf"
doc = SimpleDocTemplate(OUT, pagesize=A4, leftMargin=1.8*cm, rightMargin=1.8*cm,
    topMargin=1.8*cm, bottomMargin=1.8*cm, title="HopeTSIT iOS Build Guide v23.1.277", author="HopeTSIT team")
styles = getSampleStyleSheet()
H1 = ParagraphStyle('H1', parent=styles['Heading1'], fontSize=22, textColor=colors.HexColor("#EF4324"), spaceAfter=14, leading=26)
H2 = ParagraphStyle('H2', parent=styles['Heading2'], fontSize=15, textColor=colors.HexColor("#1F2937"), spaceAfter=10, spaceBefore=14, leading=18)
P = ParagraphStyle('P', parent=styles['BodyText'], fontSize=10, leading=14, alignment=TA_JUSTIFY)
CODE = ParagraphStyle('CODE', parent=styles['Code'], fontSize=9, leading=12, leftIndent=12, textColor=colors.HexColor("#0F172A"), backColor=colors.HexColor("#F1F5F9"))
INFO = ParagraphStyle('INFO', parent=styles['BodyText'], fontSize=9, leading=13, leftIndent=12, rightIndent=12, textColor=colors.HexColor("#075985"), backColor=colors.HexColor("#E0F2FE"), borderColor=colors.HexColor("#0EA5E9"), borderWidth=1, borderPadding=8)
GREEN = ParagraphStyle('GREEN', parent=styles['BodyText'], fontSize=10, leading=14, leftIndent=12, rightIndent=12, textColor=colors.HexColor("#065F46"), backColor=colors.HexColor("#D1FAE5"), borderColor=colors.HexColor("#10B981"), borderWidth=1, borderPadding=8)

flow = []
flow.append(Paragraph("HopeTSIT — iOS Build Guide", H1))
flow.append(Paragraph("Version 23.1.277 (Build 277)", H2))
flow.append(Spacer(1, 0.4*cm))
flow.append(Paragraph(
    "Delta v23.1.276 to v23.1.277 : correctif RACINE du chat (faux 'Message "
    "supprime' + desync app/web), halos PawMap unifies, recompute Top "
    "sitter/walker a l'auto-release 48h, dark mode lisible (barre recherche "
    "PawMap + cartes message adresse/position + boutique), bannière + badges "
    "PawFollow/Family, et categories amis par role sur le site.", P))
flow.append(Spacer(1, 0.5*cm))
flow.append(Paragraph(
    "v23.1.277 — Frontend + backend (wallet/Top recompute, /me/benefits "
    "famille) + site web. APK universal. Les changements backend ne "
    "s'activent qu'apres le deploiement Render (au push). Aucune migration DB.", GREEN))
flow.append(PageBreak())

flow.append(Paragraph("Changelog v23.1.277", H1))

flow.append(Paragraph("1. Chat — faux 'Message supprime' + desync (RACINE)", H2))
flow.append(Paragraph(
    "Le payload message:new (socket) ET la reponse REST d'envoi nichent le "
    "message sous `sentMessage` (chat ami/famille) ou `message` (chat "
    "booking). L'app ne lisait que `message` -> body vide pour les amis -> "
    "l'heuristique v272 le marquait 'supprime'. Le site lisait le message a "
    "plat -> id/body undefined -> desync. FIX : on DEBALLE l'enveloppe cote "
    "app (owner + sitter/walker), backend canonique (message+sentMessage), et "
    "le site deballe aussi. isDeleted = explicite uniquement + filtre des "
    "artefacts vides. Couvre owner + sitter + walker + web.", P))

flow.append(Paragraph("2. PawMap — halos unifies", H2))
flow.append(Paragraph(
    "Un `return` owner-only empechait l'affichage des halos AMIS pour les "
    "sitter/walker : corrige (boucle provider sous `if`). + DEDUP : une "
    "personne a la fois ami live ET provider PawSpot n'a plus 2-3 halos/pins "
    "empiles -> un seul halo ami unifie. Dark mode : texte de la barre de "
    "recherche fixe en sombre (la GoogleMap reste toujours claire).", P))

flow.append(Paragraph("3. Wallet + Top sitter/walker", H2))
flow.append(Paragraph(
    "Le scheduler auto-release 48h creditait le wallet mais NE recalculait "
    "jamais le statut Top. FIX : il appelle desormais recomputeSitterStatus / "
    "recomputeWalkerStatus -> completedServicesCount + isTopSitter/Walker se "
    "mettent a jour. Rappel : l'argent est retenu jusqu'a confirmation owner "
    "OU 48h (feature de confirmation). Badge Top = 20 services confirmes + "
    "note > 4.5.", INFO))

flow.append(Paragraph("4. Boutique + badges", H2))
flow.append(Paragraph(
    "Banniere active scindee PawFollow (dore) | Family (violet) avec jours ; "
    "carte plan Famille en violet (titre + prix) ; mensuel/annuel accents "
    "distincts ; cartes des 3 onglets en fond adaptatif (dark mode lisible). "
    "Badges profil : Premium -> PawFollow.Xj + nouveau Family.Xj (backend "
    "/me/benefits expose pawFollowExpiry + familyActive + familyExpiry). "
    "Forfaits verifies : mensuel 30j / annuel 365j / famille 30j, OK.", P))

flow.append(Paragraph("5. Dark mode cartes message + site", H2))
flow.append(Paragraph(
    "Cartes 'Adresse pour RDV' et 'Partage de position' : fonds adaptatifs "
    "(texte blanc en dark n'est plus invisible). Site /friends/live : amis "
    "separes par role -> Amis / Pet-sitters / Promeneurs.", P))
flow.append(PageBreak())

flow.append(Paragraph("Build iOS — etapes Xcode", H1))
flow.append(Paragraph("Etape 1 — Pull v277", H2))
flow.append(Paragraph("git pull origin main<br/>cd frontend &amp;&amp; flutter clean &amp;&amp; flutter pub get<br/>cd ios &amp;&amp; pod install --repo-update", CODE))
flow.append(Paragraph("Etape 2 — Smoke test chat (le plus important)", H2))
flow.append(Paragraph(
    "Sur les 3 profils + le site : ecrire un message dans un chat AMI/FAMILLE "
    "-> il s'affiche correctement (plus de 'Message supprime'). Supprimer un "
    "message -> placeholder 'Message supprime' correct. App <-> site "
    "synchronises.", P))
flow.append(Paragraph("Etape 3 — Smoke test PawMap + dark mode", H2))
flow.append(Paragraph(
    "PawMap : un ami qui est aussi provider PawSpot -> un seul halo unifie "
    "(pas de double). Dark mode systeme ON : barre de recherche PawMap "
    "lisible, cartes message lisibles, boutique lisible sur les 3 onglets.", P))
flow.append(Paragraph("Etape 4 — Archive Xcode", H2))
flow.append(Paragraph("scheme Runner, Any iOS Device, Product &gt; Archive, Distribute App &gt; App Store Connect (TestFlight d'abord).", P))
flow.append(Spacer(1, 0.5*cm))
flow.append(Paragraph("Build Android : flutter build apk --release -> Downloads/HopeTSIT_v23.1.277.apk.", INFO))

doc.build(flow)
print(f"OK -> {OUT}")

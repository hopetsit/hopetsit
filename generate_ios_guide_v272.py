"""HopeTSIT iOS Build Guide v23.1.272 generator."""
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, PageBreak
from reportlab.lib.enums import TA_JUSTIFY

OUT = "C:/Users/Usuario/Downloads/HopeTSIT_iOS_Build_Guide_v23.1.272.pdf"
doc = SimpleDocTemplate(OUT, pagesize=A4, leftMargin=1.8*cm, rightMargin=1.8*cm,
    topMargin=1.8*cm, bottomMargin=1.8*cm, title="HopeTSIT iOS Build Guide v23.1.272", author="HopeTSIT team")
styles = getSampleStyleSheet()
H1 = ParagraphStyle('H1', parent=styles['Heading1'], fontSize=22, textColor=colors.HexColor("#EF4324"), spaceAfter=14, leading=26)
H2 = ParagraphStyle('H2', parent=styles['Heading2'], fontSize=15, textColor=colors.HexColor("#1F2937"), spaceAfter=10, spaceBefore=14, leading=18)
P = ParagraphStyle('P', parent=styles['BodyText'], fontSize=10, leading=14, alignment=TA_JUSTIFY)
CODE = ParagraphStyle('CODE', parent=styles['Code'], fontSize=9, leading=12, leftIndent=12, textColor=colors.HexColor("#0F172A"), backColor=colors.HexColor("#F1F5F9"))
INFO = ParagraphStyle('INFO', parent=styles['BodyText'], fontSize=9, leading=13, leftIndent=12, rightIndent=12, textColor=colors.HexColor("#075985"), backColor=colors.HexColor("#E0F2FE"), borderColor=colors.HexColor("#0EA5E9"), borderWidth=1, borderPadding=8)
GREEN = ParagraphStyle('GREEN', parent=styles['BodyText'], fontSize=10, leading=14, leftIndent=12, rightIndent=12, textColor=colors.HexColor("#065F46"), backColor=colors.HexColor("#D1FAE5"), borderColor=colors.HexColor("#10B981"), borderWidth=1, borderPadding=8)

flow = []
flow.append(Paragraph("HopeTSIT — iOS Build Guide", H1))
flow.append(Paragraph("Version 23.1.272 (Build 272)", H2))
flow.append(Spacer(1, 0.4*cm))
flow.append(Paragraph(
    "Delta v23.1.271 to v23.1.272 : chat — plus de bulle vide quand l'autre "
    "personne supprime son message (placeholder 'Message supprime'). Couvre les "
    "3 profils (owner + sitter + walker, ce dernier reutilisant le controleur "
    "et l'ecran du sitter).", P))
flow.append(Spacer(1, 0.5*cm))
flow.append(Paragraph(
    "v23.1.272 — Frontend uniquement. Aucune migration DB. APK universal. "
    "Inclut aussi tous les correctifs backend deja deployes (wallet, Top "
    "loyalty, famille, mails).", GREEN))
flow.append(PageBreak())

flow.append(Paragraph("Changelog v23.1.272", H1))
flow.append(Paragraph("Chat : bulle vide quand l'autre supprime", H2))
flow.append(Paragraph(
    "Daniel : 'quand Daniel ecrit, ca met un witoulek vide en dessous alors "
    "qu'il n'a pas repondu'. CAUSE : quand l'autre personne SUPPRIME un message "
    "qu'elle avait envoye, le serveur redacte le corps mais ne renvoie pas "
    "toujours le flag isDeleted/deletedAt au rechargement -> message au corps "
    "vide + isDeleted=false -> ni 'Message supprime' ni texte -> bulle fantome "
    "VIDE (avatar + nom + heure).", P))
flow.append(Paragraph(
    "FIX : dans _mapToChatMessage (ChatController owner) et _mapToSitterChatMessage "
    "(SitterChatController, partage par sitter ET walker), un message TEXTE au "
    "corps vide ET sans piece jointe est traite comme supprime -> affiche le "
    "placeholder 'Message supprime' au lieu d'une bulle vide. Les 2 ecrans de "
    "chat (owner + sitter/walker) affichent deja ce placeholder pour isDeleted.", P))
flow.append(Paragraph(
    "Couverture 3 profils : l'app n'a que 2 controleurs de chat ; le walker "
    "reutilise SitterChatController + SitterChatScreen. Les 2 controleurs sont "
    "corriges -> owner + sitter + walker couverts.", INFO))
flow.append(PageBreak())

flow.append(Paragraph("Build iOS — etapes Xcode", H1))
flow.append(Paragraph("Etape 1 — Pull v272", H2))
flow.append(Paragraph("git pull origin main<br/>cd frontend &amp;&amp; flutter clean &amp;&amp; flutter pub get<br/>cd ios &amp;&amp; pod install --repo-update", CODE))
flow.append(Paragraph("Etape 2 — Smoke test", H2))
flow.append(Paragraph(
    "Sur les 3 profils : l'autre personne envoie un message puis le supprime -> "
    "cote moi, j'obtiens 'Message supprime' (et non une bulle vide), y compris "
    "apres rechargement du chat.", P))
flow.append(Paragraph("Etape 3 — Archive Xcode", H2))
flow.append(Paragraph("open ios/Runner.xcworkspace, scheme Runner, Any iOS Device, Product &gt; Archive, Distribute App &gt; App Store Connect (TestFlight d'abord).", P))
flow.append(Spacer(1, 0.5*cm))
flow.append(Paragraph("Build Android : flutter build apk --release -> Downloads/HopeTSIT_v23.1.272.apk.", INFO))

doc.build(flow)
print(f"OK -> {OUT}")

"""HopeTSIT iOS Build Guide v23.1.271 generator.

Cumul v23.1.269 -> v23.1.271.
"""
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, PageBreak
from reportlab.lib.enums import TA_JUSTIFY

OUT = "C:/Users/Usuario/Downloads/HopeTSIT_iOS_Build_Guide_v23.1.271.pdf"
doc = SimpleDocTemplate(OUT, pagesize=A4, leftMargin=1.8*cm, rightMargin=1.8*cm,
    topMargin=1.8*cm, bottomMargin=1.8*cm, title="HopeTSIT iOS Build Guide v23.1.271", author="HopeTSIT team")
styles = getSampleStyleSheet()
H1 = ParagraphStyle('H1', parent=styles['Heading1'], fontSize=22, textColor=colors.HexColor("#EF4324"), spaceAfter=14, leading=26)
H2 = ParagraphStyle('H2', parent=styles['Heading2'], fontSize=15, textColor=colors.HexColor("#1F2937"), spaceAfter=10, spaceBefore=14, leading=18)
P = ParagraphStyle('P', parent=styles['BodyText'], fontSize=10, leading=14, alignment=TA_JUSTIFY)
CODE = ParagraphStyle('CODE', parent=styles['Code'], fontSize=9, leading=12, leftIndent=12, textColor=colors.HexColor("#0F172A"), backColor=colors.HexColor("#F1F5F9"))
INFO = ParagraphStyle('INFO', parent=styles['BodyText'], fontSize=9, leading=13, leftIndent=12, rightIndent=12, textColor=colors.HexColor("#075985"), backColor=colors.HexColor("#E0F2FE"), borderColor=colors.HexColor("#0EA5E9"), borderWidth=1, borderPadding=8)
GREEN = ParagraphStyle('GREEN', parent=styles['BodyText'], fontSize=10, leading=14, leftIndent=12, rightIndent=12, textColor=colors.HexColor("#065F46"), backColor=colors.HexColor("#D1FAE5"), borderColor=colors.HexColor("#10B981"), borderWidth=1, borderPadding=8)

flow = []
flow.append(Paragraph("HopeTSIT — iOS Build Guide", H1))
flow.append(Paragraph("Version 23.1.271 (Build 271)", H2))
flow.append(Spacer(1, 0.4*cm))
flow.append(Paragraph(
    "Cumul v23.1.269 to v23.1.271 : cartes quick-actions (v269), wallet 0€ + "
    "chat doublon + suivi zoom + badge resa + web Top/admin (v270), Top "
    "owner/sitter/walker comptabilise (v271).", P))
flow.append(Spacer(1, 0.5*cm))
flow.append(Paragraph(
    "Beaucoup de correctifs sont BACKEND (deja deployes sur Render : wallet, "
    "mails, famille, Top loyalty) + le SITE sur Vercel. Cet APK / archive iOS "
    "porte la partie FRONTEND. Aucune migration DB. APK universal.", GREEN))
flow.append(PageBreak())

flow.append(Paragraph("Changelog v269 - v271", H1))

flow.append(Paragraph("v269 — cartes quick-actions", H2))
flow.append(Paragraph(
    "Profil owner : les 3 cartes (Modifier animaux / Historique / Boutique) ont "
    "desormais la MEME hauteur (IntrinsicHeight) — avant, 'Boutique' (1 ligne) "
    "etait plus courte que les 2 autres (2 lignes).", P))

flow.append(Paragraph("v270 — wallet, chat, suivi, badge, web/admin", H2))
flow.append(Paragraph(
    "WALLET 0€ : le payout ne creditait le wallet que via Airwallex-beneficiaire ; "
    "les branches stripe-defaut / IBAN-fallback / held creditent maintenant le "
    "wallet (modele part 83) + dedup honore withdrawable. CHAT DOUBLON : on "
    "n'ajoute plus l'echo socket de son propre message (course tempId/_id). "
    "SUIVI : zoom fort (_followZoom) a l'ouverture ET a chaque position. BADGE "
    "RESA : events service_* rechargent les reservations (temps reel). WEB : "
    "badge Top = merite (isTopSitter/isTopWalker), Boost separe. ADMIN : "
    "paiements recents lisaient un champ inexistant -> pricing.totalPrice.", P))

flow.append(Paragraph("v271 — Top owner/sitter/walker comptabilise", H2))
flow.append(Paragraph(
    "Le statut Top ne comptait que les bookings status='completed' (ancien flux). "
    "Le nouveau flux de confirmation ne le posait jamais -> compteur a 0. Les 4 "
    "compteurs loyalty comptent desormais aussi confirmationStatus='confirmed' ; "
    "confirmService declenche le recompute Top + Premium owner ; le scheduler 48h "
    "auto-confirme. Backend (deja deploye).", P))
flow.append(Paragraph(
    "A verifier : confirmer un service -> le compteur Top sitter inclut tous les "
    "services confirmes. Le wallet est credite au reglement (nouveaux services). "
    "Restant (tache #69) : commission Top 20%->15% (annoncee, pas encore codee), "
    "badge demande FAMILLE temps reel.", INFO))
flow.append(PageBreak())

flow.append(Paragraph("Build iOS — etapes Xcode", H1))
flow.append(Paragraph("Etape 1 — Pull v271", H2))
flow.append(Paragraph("git pull origin main<br/>cd frontend &amp;&amp; flutter clean &amp;&amp; flutter pub get<br/>cd ios &amp;&amp; pod install --repo-update", CODE))
flow.append(Paragraph("Etape 2 — Smoke test", H2))
flow.append(Paragraph(
    "1) Chat : pas de doublon a l'envoi. 2) Suivi : taper un ami -> zoom serre + "
    "camera collee. 3) Reservations : badge vert temps reel sur action service. "
    "4) Profil owner : 3 cartes meme taille. 5) Apres un service confirme : "
    "wallet credite + compteur Top qui progresse.", P))
flow.append(Paragraph("Etape 3 — Archive Xcode", H2))
flow.append(Paragraph("open ios/Runner.xcworkspace, scheme Runner, Any iOS Device, Product &gt; Archive, Distribute App &gt; App Store Connect (TestFlight d'abord).", P))
flow.append(Spacer(1, 0.5*cm))
flow.append(Paragraph("Build Android : flutter build apk --release -> Downloads/HopeTSIT_v23.1.271.apk.", INFO))

doc.build(flow)
print(f"OK -> {OUT}")

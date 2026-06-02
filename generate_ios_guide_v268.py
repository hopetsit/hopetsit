"""HopeTSIT iOS Build Guide v23.1.268 generator.

Cumul v23.1.265 -> v23.1.268.
"""
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, PageBreak
from reportlab.lib.enums import TA_JUSTIFY

OUT = "C:/Users/Usuario/Downloads/HopeTSIT_iOS_Build_Guide_v23.1.268.pdf"
doc = SimpleDocTemplate(OUT, pagesize=A4, leftMargin=1.8*cm, rightMargin=1.8*cm,
    topMargin=1.8*cm, bottomMargin=1.8*cm, title="HopeTSIT iOS Build Guide v23.1.268", author="HopeTSIT team")
styles = getSampleStyleSheet()
H1 = ParagraphStyle('H1', parent=styles['Heading1'], fontSize=22, textColor=colors.HexColor("#EF4324"), spaceAfter=14, leading=26)
H2 = ParagraphStyle('H2', parent=styles['Heading2'], fontSize=15, textColor=colors.HexColor("#1F2937"), spaceAfter=10, spaceBefore=14, leading=18)
P = ParagraphStyle('P', parent=styles['BodyText'], fontSize=10, leading=14, alignment=TA_JUSTIFY)
CODE = ParagraphStyle('CODE', parent=styles['Code'], fontSize=9, leading=12, leftIndent=12, textColor=colors.HexColor("#0F172A"), backColor=colors.HexColor("#F1F5F9"))
INFO = ParagraphStyle('INFO', parent=styles['BodyText'], fontSize=9, leading=13, leftIndent=12, rightIndent=12, textColor=colors.HexColor("#075985"), backColor=colors.HexColor("#E0F2FE"), borderColor=colors.HexColor("#0EA5E9"), borderWidth=1, borderPadding=8)
GREEN = ParagraphStyle('GREEN', parent=styles['BodyText'], fontSize=10, leading=14, leftIndent=12, rightIndent=12, textColor=colors.HexColor("#065F46"), backColor=colors.HexColor("#D1FAE5"), borderColor=colors.HexColor("#10B981"), borderWidth=1, borderPadding=8)

flow = []
flow.append(Paragraph("HopeTSIT — iOS Build Guide", H1))
flow.append(Paragraph("Version 23.1.268 (Build 268)", H2))
flow.append(Spacer(1, 0.4*cm))
flow.append(Paragraph(
    "Cumul v23.1.265 to v23.1.268 : confirmation 1 bouton + refresh resa 30s, "
    "famille (sub migration + self-heal) + tap membre -> PawMap + satellite + "
    "badge confirmation, photos profil amis + membres en violet, chat sans "
    "doublons, mails moins lents, site web (SEO + redirects + coherence).", P))
flow.append(Spacer(1, 0.5*cm))
flow.append(Paragraph(
    "Plusieurs correctifs sont BACKEND (deja deployes sur Render : famille, "
    "mails, photos /diagnose) et le SITE est sur Vercel. Cet APK / archive iOS "
    "porte la partie FRONTEND. Aucune migration DB. APK universal.", GREEN))
flow.append(PageBreak())

flow.append(Paragraph("Changelog v265 - v268", H1))

flow.append(Paragraph("v265 — confirmation + refresh resa", H2))
flow.append(Paragraph(
    "ServiceConfirmationCard : seul le bouton tape tourne (avant les 2 boutons "
    "owner tournaient ensemble). Les 3 ecrans Reservations se rafraichissent "
    "toutes les 30s en silence (mode silent sur les 3 controleurs).", P))

flow.append(Paragraph("v266 — famille + PawMap", H2))
flow.append(Paragraph(
    "FAMILY_PLAN_REQUIRED : switchRole migre desormais l'abonnement (avant : "
    "amities/chats migres mais pas la sub -> abo orphelin). Les invites "
    "utilisent resolveOwnFamilySub (lookup robuste + SELF-HEAL qui repare l'abo "
    "orphelin via email/oldId). Tap sur un membre famille -> ouvre la PawMap "
    "centree + suivi (le tile n'avait aucun onTap). PawMap : bouton satellite + "
    "bouton 'voir tous mes amis'. Badge vert 'action requise' sur l'onglet "
    "Reservations.", P))

flow.append(Paragraph("v267 — photos + violet", H2))
flow.append(Paragraph(
    "Photos profil amis : la liste Mes amis lit /diagnose qui ne renvoyait pas "
    "l'avatar -> placeholder gris. Backend renvoie otherAvatar, frontend "
    "l'affiche. Invite famille : re-point self-heal collision-safe (fusion si "
    "conflit d'index). Membres famille en VIOLET dans la liste (et avatar "
    "cercle violet dans l'onglet Famille).", P))

flow.append(Paragraph("v268 — chat + mails + site web", H2))
flow.append(Paragraph(
    "Chat doublons : la liste de chat deduplique par contact (otherParty.id), "
    "gardant le fil le plus recent -> une seule conversation par personne "
    "(ChatController + SitterChatController). Mails : pool SMTP active "
    "(connexions reutilisees) + timeouts -> envoi plus rapide. Site web : "
    "sitemap.ts + robots.ts + JSON-LD ; redirects FR->EN (404 evites) ; famille "
    "'jusqu'a 4' -> '5' (6 langues) ; version APK affichee mise a jour.", P))
flow.append(Paragraph(
    "Note mails : gain maximal en passant Gmail SMTP -> fournisseur "
    "transactionnel (SendGrid/Mailgun/SES) via les variables SMTP_* sur Render. "
    "Note chat : le backend garde 2 fils (reservation gate paiement / amis gate "
    "amitie) ; la dedup est cote affichage.", INFO))
flow.append(PageBreak())

flow.append(Paragraph("Build iOS — etapes Xcode", H1))
flow.append(Paragraph("Etape 1 — Pull v268", H2))
flow.append(Paragraph("git pull origin main<br/>cd frontend &amp;&amp; flutter clean &amp;&amp; flutter pub get<br/>cd ios &amp;&amp; pod install --repo-update", CODE))
flow.append(Paragraph("Etape 2 — Smoke test", H2))
flow.append(Paragraph(
    "1) Chat : une seule conversation par personne (plus de doublon). "
    "2) Mes amis : photos affichees + membres famille en violet ; Inviter "
    "fonctionne. 3) Taper un membre famille -> PawMap centree + suivi. "
    "4) PawMap : boutons satellite + voir tous mes amis. 5) Reservations : "
    "badge vert quand une action est requise.", P))
flow.append(Paragraph("Etape 3 — Archive Xcode", H2))
flow.append(Paragraph("open ios/Runner.xcworkspace, scheme Runner, Any iOS Device, Product &gt; Archive, Distribute App &gt; App Store Connect (TestFlight d'abord).", P))
flow.append(Spacer(1, 0.5*cm))
flow.append(Paragraph("Build Android : flutter build apk --release -> Downloads/HopeTSIT_v23.1.268.apk.", INFO))

doc.build(flow)
print(f"OK -> {OUT}")

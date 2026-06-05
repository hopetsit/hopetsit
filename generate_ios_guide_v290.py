"""HopeTSIT iOS Build Guide v23.1.290 generator."""
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, PageBreak
from reportlab.lib.enums import TA_JUSTIFY

OUT = "C:/Users/Usuario/Downloads/HopeTSIT_iOS_Build_Guide_v23.1.290.pdf"
doc = SimpleDocTemplate(OUT, pagesize=A4, leftMargin=1.8*cm, rightMargin=1.8*cm,
    topMargin=1.8*cm, bottomMargin=1.8*cm, title="HopeTSIT iOS Build Guide v23.1.290", author="HopeTSIT team")
styles = getSampleStyleSheet()
H1 = ParagraphStyle('H1', parent=styles['Heading1'], fontSize=22, textColor=colors.HexColor("#EF4324"), spaceAfter=14, leading=26)
H2 = ParagraphStyle('H2', parent=styles['Heading2'], fontSize=15, textColor=colors.HexColor("#1F2937"), spaceAfter=10, spaceBefore=14, leading=18)
P = ParagraphStyle('P', parent=styles['BodyText'], fontSize=10, leading=14, alignment=TA_JUSTIFY)
CODE = ParagraphStyle('CODE', parent=styles['Code'], fontSize=9, leading=12, leftIndent=12, textColor=colors.HexColor("#0F172A"), backColor=colors.HexColor("#F1F5F9"))
INFO = ParagraphStyle('INFO', parent=styles['BodyText'], fontSize=9, leading=13, leftIndent=12, rightIndent=12, textColor=colors.HexColor("#075985"), backColor=colors.HexColor("#E0F2FE"), borderColor=colors.HexColor("#0EA5E9"), borderWidth=1, borderPadding=8)
GREEN = ParagraphStyle('GREEN', parent=styles['BodyText'], fontSize=10, leading=14, leftIndent=12, rightIndent=12, textColor=colors.HexColor("#065F46"), backColor=colors.HexColor("#D1FAE5"), borderColor=colors.HexColor("#10B981"), borderWidth=1, borderPadding=8)

flow = []
flow.append(Paragraph("HopeTSIT &mdash; iOS Build Guide", H1))
flow.append(Paragraph("Version 23.1.290 (Build 290)", H2))
flow.append(Spacer(1, 0.4*cm))
flow.append(Paragraph(
    "Systeme d'avis complete : l'owner note sitter OU walker apres le service, "
    "les avis (note + commentaire) sont visibles par tous sur le detail sitter "
    "ET walker, et l'owner peut modifier/supprimer son avis. La moderation des "
    "avis est branchee cote admin. Plus un fix des badges profil qui "
    "debordaient du header.", P))
flow.append(Spacer(1, 0.5*cm))
flow.append(Paragraph(
    "v23.1.290 &mdash; Backend (Review, reviewController, reviewRoutes, walker/"
    "sitter controllers) + Frontend (ecrans avis, detail walker, profils). APK "
    "universal. Backend actif apres deploiement Render. Aucune migration DB "
    "(changements additifs).", GREEN))
flow.append(PageBreak())

flow.append(Paragraph("Changelog v23.1.290", H1))

flow.append(Paragraph("1. Avis &mdash; support walker (etait casse)", H2))
flow.append(Paragraph(
    "Le modele Review n'acceptait que ['Owner','Sitter'] : noter un walker "
    "levait une erreur de validation Mongoose et l'avis n'etait jamais sauve. "
    "Ajout de 'Walker' aux 2 enums, et la moyenne est desormais recalculee pour "
    "sitter ET walker.", P))

flow.append(Paragraph("2. Avis visibles par tous", H2))
flow.append(Paragraph(
    "getWalkerProfile renvoie maintenant le tableau reviews (meme format que le "
    "detail sitter) : une section 'Avis' s'affiche sur le profil walker. "
    "Le detail sitter renvoyait deja les avis ; on a ajoute le filtre hidden "
    "(coherence : un avis masque par l'admin disparait aussi du profil sitter, "
    "comme deja pour walker et la liste publique).", INFO))

flow.append(Paragraph("3. Bouton 'Laisser un avis' debloque + edit/delete", H2))
flow.append(Paragraph(
    "Le bouton n'apparaissait que si status=='completed'. Or le flux de "
    "confirmation (v259) met confirmationStatus=='confirmed' en laissant "
    "status=='paid' : le bouton n'apparaissait JAMAIS. Il s'affiche desormais "
    "aussi quand le service est confirme. Nouveaux endpoints GET /reviews/mine, "
    "PUT /reviews/:id, DELETE /reviews/:id : l'ecran d'avis se pre-remplit si "
    "un avis existe, avec 'Modifier' et 'Supprimer mon avis'. 7 cles i18n x 6 "
    "langues.", P))

flow.append(Paragraph("4. Moderation admin (verifiee)", H2))
flow.append(Paragraph(
    "Page Avis du dashboard : filtres Tous / Signales / Masques, actions Hide / "
    "Restore / Supprimer, branchees sur /admin/reviews (GET), /hide et /restore "
    "(PATCH) + DELETE. Masquer un avis le retire des profils sitter ET walker "
    "et de la liste publique.", P))

flow.append(Paragraph("5. Fix badges profil qui debordaient", H2))
flow.append(Paragraph(
    "Headers owner/sitter/walker : height fixe 200.h remplace par "
    "constraints: BoxConstraints(minHeight: 200.h) : le header degrade s'etend "
    "quand 4 badges (PawFollow + Famille + Boost + PawSpot) passent sur 2 "
    "lignes au lieu de deborder dessous.", INFO))
flow.append(PageBreak())

flow.append(Paragraph("Build iOS &mdash; etapes Xcode", H1))
flow.append(Paragraph("Etape 1 &mdash; Pull v290", H2))
flow.append(Paragraph("git pull origin main<br/>cd frontend &amp;&amp; flutter clean &amp;&amp; flutter pub get<br/>cd ios &amp;&amp; pod install --repo-update", CODE))
flow.append(Paragraph("Etape 2 &mdash; Smoke test (apres deploiement Render)", H2))
flow.append(Paragraph(
    "Owner : apres un service confirme, onglet Reservations : bouton 'Laisser "
    "un avis' visible : noter (1-5 etoiles + commentaire). Re-ouvrir : ecran "
    "pre-rempli, 'Modifier' / 'Supprimer mon avis'. Ouvrir un profil sitter ET "
    "un profil walker : la section 'Avis' montre les notes/commentaires. "
    "Profils : avec 4 badges actifs, le header ne deborde plus. Admin : page "
    "Avis : Hide un avis : il disparait du profil.", P))
flow.append(Paragraph("Etape 3 &mdash; Archive Xcode", H2))
flow.append(Paragraph("scheme Runner, Any iOS Device, Product &gt; Archive, Distribute App &gt; App Store Connect (TestFlight d'abord).", P))
flow.append(Spacer(1, 0.5*cm))
flow.append(Paragraph("Build Android : flutter build apk --release -&gt; Downloads/HopeTSit_v290.apk.", INFO))

doc.build(flow)
print(f"OK -> {OUT}")

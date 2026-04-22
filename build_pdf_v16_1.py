"""Generate HopeTSIT Recap v16-1 PDF — focused patch on top of v16."""
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, PageBreak, Table, TableStyle,
)
from reportlab.lib.enums import TA_LEFT, TA_CENTER

OUT = "HopeTSIT_Recap_v16-1.pdf"

styles = getSampleStyleSheet()
title = ParagraphStyle('title', parent=styles['Title'], fontSize=22,
                       textColor=colors.HexColor('#C62828'),
                       spaceAfter=18, alignment=TA_CENTER)
h1 = ParagraphStyle('h1', parent=styles['Heading1'], fontSize=15,
                    textColor=colors.HexColor('#1A237E'), spaceBefore=16,
                    spaceAfter=8)
h2 = ParagraphStyle('h2', parent=styles['Heading2'], fontSize=12,
                    textColor=colors.HexColor('#00695C'), spaceBefore=10,
                    spaceAfter=4)
body = ParagraphStyle('body', parent=styles['BodyText'], fontSize=10,
                      leading=14, spaceAfter=6, alignment=TA_LEFT)
small = ParagraphStyle('small', parent=styles['BodyText'], fontSize=9,
                       leading=12, textColor=colors.grey)
mono = ParagraphStyle('mono', parent=styles['Code'], fontSize=9, leading=12,
                      backColor=colors.HexColor('#F5F5F5'),
                      borderPadding=6, leftIndent=4, rightIndent=4)

doc = SimpleDocTemplate(OUT, pagesize=A4,
                        leftMargin=1.8*cm, rightMargin=1.8*cm,
                        topMargin=1.6*cm, bottomMargin=1.6*cm)
story = []

story.append(Paragraph("HopeTSIT — Récap v16.1", title))
story.append(Paragraph("Patch Owner↔Walker direct booking + walker base price resolution", small))
story.append(Spacer(1, 10))
story.append(Paragraph(
    "Mini-session sur deux bugs visibles à l'usage de l'APK v15-6 :", body))
story.append(Paragraph(
    "1. Côté Owner, quand on tape \"Envoyer la demande\" sur un Walker, "
    "l'app affichait \"Veuillez d'abord définir votre tarif horaire dans le profil\" "
    "alors que le Walker avait bien un tarif configuré.", body))
story.append(Paragraph(
    "2. Côté Walker, quand on tentait de candidater à une annonce Owner, "
    "la même erreur s'affichait.", body))

story.append(Paragraph("Cause racine (un seul bug)", h1))
story.append(Paragraph(
    "Tout le code (frontend + backend) supposait que le prestataire est "
    "toujours un Sitter avec <code>hourlyRate</code>. Or les Walkers utilisent "
    "un <code>walkRates</code> array (durationMinutes → basePrice). Partout où "
    "on calculait un basePrice, la lecture se faisait sur un Sitter inexistant.", body))

story.append(Paragraph("Fixes appliqués (6 fichiers)", h1))

state = [
    ["Fichier", "Changement"],
    ["frontend/lib/controllers/send_request_controller.dart",
     "Import WalkerRepository. Si role='walker', fetch walker via getWalkerProfile. "
     "Nouveau _resolveBasePrice() qui dérive hourly depuis walkRates (60 min, ou "
     "30 min × 2, ou 90 min × 2/3, ou 120 min / 2). Retry walker si basePrice=0. "
     "Passe providerRole au createBooking."],
    ["frontend/lib/views/pet_sitter/home/sitter_homescreen.dart",
     "_resolveSitterBasePrice → _resolveProviderBasePrice. Détecte le rôle "
     "du user connecté via AuthController.userRole. Si walker, fetch son "
     "profil walker et dérive hourly depuis walkRates. Sitter path inchangé "
     "+ ajout fallback daily/weekly/monthly."],
    ["frontend/lib/repositories/owner_repository.dart",
     "createBooking accepte providerRole ('sitter' | 'walker'). Envoie "
     "?walkerId=... ou ?sitterId=... selon le rôle. Rétrocompat par défaut "
     "('sitter') pour les callers existants."],
    ["backend/src/models/Booking.js",
     "sitterId devient optional, walkerId ajouté optional. Pre-save "
     "validator: exactement un des deux doit être rempli. Index miroir "
     "{ownerId,walkerId,status,requestFingerprint}. Pas de migration "
     "nécessaire (bookings existants gardent sitterId)."],
    ["backend/src/controllers/bookingController.js (createBooking)",
     "Accepte req.query.walkerId en plus de sitterId. Si walker, fetch "
     "Walker, dérive hourly depuis walkRates, construit un shim sitter-like "
     "pour que le reste du pipeline pricing tourne sans if/else. "
     "Booking.create écrit dans le bon champ selon providerType."],
]
t = Table(state, colWidths=[6*cm, 11*cm])
t.setStyle(TableStyle([
    ('BACKGROUND', (0,0), (-1,0), colors.HexColor('#1A237E')),
    ('TEXTCOLOR', (0,0), (-1,0), colors.white),
    ('FONTNAME', (0,0), (-1,0), 'Helvetica-Bold'),
    ('FONTSIZE', (0,0), (-1,-1), 8.5),
    ('GRID', (0,0), (-1,-1), 0.4, colors.grey),
    ('VALIGN', (0,0), (-1,-1), 'TOP'),
    ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, colors.HexColor('#F5F5F5')]),
]))
story.append(t)

story.append(PageBreak())

story.append(Paragraph("Limitation restante (pour v17)", h1))
story.append(Paragraph(
    "<b>La création de booking Owner → Walker fonctionne</b> : la demande "
    "part, Render accepte, le Booking est persisté avec walkerId dans Mongo.", body))
story.append(Paragraph(
    "<b>Le cycle complet n'est PAS terminé</b> : les endpoints de lecture/update "
    "(listMyBookings côté Walker, accept/reject, agreed, paiement Stripe/PayPal, "
    "conversation) font des requêtes du type <code>Booking.find({ sitterId: ... })</code> "
    "qui ne trouveront pas les bookings walkerId. Résultat : le Walker qui reçoit "
    "une demande ne la verra pas dans ses Réservations tant qu'on n'adapte pas "
    "ces endpoints.", body))
story.append(Paragraph(
    "<b>TODO v17</b> : passer au peigne fin bookingController.js pour chaque query "
    "Booking.find/findOne/updateOne et l'adapter au pattern \"<code>providerId "
    "query that matches either sitterId or walkerId depending on who's calling</code>\". "
    "Probablement 15-20 endpoints. Plus le notificationService qui doit savoir "
    "notifier le Walker quand il reçoit une demande. Prévoir 2-3h.", body))

story.append(Paragraph("Commandes", h1))
story.append(Paragraph(
    "<pre>cd C:\\Users\\Usuario\\Downloads\\HopeTSIT_FINAL_FIXED\\HopeTSIT_FINAL\n"
    "git add backend/ frontend/\n"
    "git commit -m \"v16.1: Owner-Walker direct booking + walker base price\"\n"
    "git push origin main\n"
    "\n"
    "cd frontend\n"
    "flutter analyze\n"
    "flutter build apk --debug\n"
    "copy build\\app\\outputs\\flutter-apk\\app-debug.apk C:\\Users\\Usuario\\Downloads\\HopeTSIT_v16-1.apk</pre>", mono))

story.append(Paragraph("Tests à valider", h1))
story.append(Paragraph(
    "1. Owner → Sitter (flow existant) : toujours OK.<br/>"
    "2. Owner → Walker \"Envoyer la demande\" : plus d'erreur \"tarif horaire\". "
    "La demande est créée en BDD avec walkerId.<br/>"
    "3. Walker candidate annonce Owner : plus d'erreur, soumet la candidature.<br/>"
    "4. Walker qui reçoit une demande directe d'Owner : <b>ne verra pas encore la demande</b> "
    "dans ses Réservations (TODO v17).", body))

doc.build(story)
print(f"OK: {OUT}")

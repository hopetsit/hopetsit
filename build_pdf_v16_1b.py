"""Generate HopeTSIT Recap v16-1b PDF — full session summary before bed."""
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, PageBreak, Table, TableStyle,
)
from reportlab.lib.enums import TA_LEFT, TA_CENTER

OUT = "HopeTSIT_Recap_v16-1b.pdf"

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
mono = ParagraphStyle('mono', parent=styles['Code'], fontSize=9, leading=13,
                      backColor=colors.HexColor('#F5F5F5'),
                      borderPadding=6, leftIndent=4, rightIndent=4)

doc = SimpleDocTemplate(OUT, pagesize=A4,
                        leftMargin=1.8*cm, rightMargin=1.8*cm,
                        topMargin=1.6*cm, bottomMargin=1.6*cm)
story = []

# ========================================================================
# COVER
# ========================================================================
story.append(Paragraph("HopeTSIT — Récap v16.1b", title))
story.append(Paragraph("Fin de session du 19/04/2026 — à rouvrir demain", small))
story.append(Spacer(1, 10))
story.append(Paragraph(
    "Mini-session étendue pour terminer la refonte Owner↔Walker "
    "direct booking. Le gros chantier v16.1 (frontend + backend) est "
    "commité et poussé, mais un oubli dans le DI GetX a introduit un crash "
    "\"WalkerRepository not found\" dès que l'Owner ouvre la page Envoyer "
    "une demande. Le hotfix est prêt mais <b>pas encore rebuild</b> — Daniel "
    "va faire ça demain matin. Le récap liste aussi les bugs restants "
    "visibles à l'APK v15-6.", body))

# ========================================================================
# ETAT ACTUEL
# ========================================================================
story.append(Paragraph("État actuel", h1))

state = [
    ["Composant", "Statut"],
    ["Backend Render (prod)",
     "v16.1 DÉPLOYÉ (commit 1337e59). Accepte ?walkerId, Booking model "
     "avec walkerId optionnel + validator."],
    ["Frontend code source (Flutter)",
     "v16.1 + hotfix DI appliqués LOCALEMENT. Hotfix = Get.put(WalkerRepository())."],
    ["Frontend git state",
     "Hotfix PAS ENCORE COMMIT ni PUSH. 1 fichier modifié: "
     "lib/helper/dependency_injection.dart."],
    ["APK sur le téléphone Daniel",
     "v15-6 (pré-v16.1). Ne crashe pas car sans les appels Get.find<WalkerRepository>()."],
    ["APK v16.1b à builder demain",
     "Une fois le hotfix pushé, rebuild + install via commandes du bas."],
    ["Admin web", "OK (CGU/Privacy seedés, Map Boost tier labels affichés)."],
    ["flutter analyze",
     "Non vérifié après le hotfix (mais hotfix = 3 lignes ajoutées, peu "
     "de risque). À faire avant build."],
]
t = Table(state, colWidths=[5.5*cm, 11.5*cm])
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

# ========================================================================
# CE QUI A ETE FAIT AUJOURD'HUI
# ========================================================================
story.append(Paragraph("Ce qui a été fait dans cette session", h1))

story.append(Paragraph("1. Refonte Owner↔Walker direct booking (v16.1)", h2))
story.append(Paragraph(
    "<b>Objectif:</b> Owner doit pouvoir envoyer une demande à un Walker "
    "directement (comme il le fait déjà pour un Sitter), et Walker doit "
    "pouvoir candidater aux annonces Owner. Les 2 flux échouaient avec "
    "\"Veuillez d'abord définir votre tarif horaire\" alors que les "
    "tarifs étaient configurés.", body))
story.append(Paragraph(
    "<b>Cause racine:</b> tout le code (frontend + backend) supposait "
    "provider = Sitter avec hourlyRate. Or Walker utilise walkRates array "
    "(durationMinutes → basePrice).", body))
story.append(Paragraph("<b>Fichiers modifiés:</b>", body))
files_changed = [
    ["Fichier", "Changement"],
    ["backend/src/models/Booking.js",
     "sitterId optional, walkerId ajouté, pre-save validator XOR, "
     "index miroir."],
    ["backend/src/controllers/bookingController.js (createBooking)",
     "Accepte ?walkerId query. Si walker, fetch Walker + dérive hourly "
     "depuis walkRates, construit shim sitter-like. Booking.create écrit "
     "sitterId OU walkerId selon providerType."],
    ["frontend/lib/controllers/send_request_controller.dart",
     "Import WalkerRepository + WalkerModel. _walker Rxn. _loadSitterDetails "
     "branche sur role. _resolveBasePrice() unifié. Retry walker si fail. "
     "Passe providerRole au createBooking."],
    ["frontend/lib/views/pet_sitter/home/sitter_homescreen.dart",
     "_resolveSitterBasePrice → _resolveProviderBasePrice. Détecte walker "
     "via AuthController.userRole. Fetch walkRates si walker. Fallback "
     "daily/weekly/monthly ajouté côté sitter."],
    ["frontend/lib/repositories/owner_repository.dart",
     "createBooking param providerRole ('sitter'|'walker'). Envoie "
     "?walkerId ou ?sitterId selon le rôle. Rétrocompat défaut 'sitter'."],
]
t = Table(files_changed, colWidths=[7*cm, 10*cm])
t.setStyle(TableStyle([
    ('BACKGROUND', (0,0), (-1,0), colors.HexColor('#00695C')),
    ('TEXTCOLOR', (0,0), (-1,0), colors.white),
    ('FONTNAME', (0,0), (-1,0), 'Helvetica-Bold'),
    ('FONTSIZE', (0,0), (-1,-1), 8.5),
    ('GRID', (0,0), (-1,-1), 0.4, colors.grey),
    ('VALIGN', (0,0), (-1,-1), 'TOP'),
    ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, colors.HexColor('#F5F5F5')]),
]))
story.append(t)

story.append(Spacer(1, 8))

story.append(Paragraph("2. Hotfix DI — WalkerRepository registered (v16.1b)", h2))
story.append(Paragraph(
    "<b>Bug introduit par le v16.1:</b> SendRequestController + "
    "sitter_homescreen font Get.find&lt;WalkerRepository&gt;() sans qu'il "
    "soit enregistré dans le DI GetX. Résultat: crash rouge \"WalkerRepository "
    "not found\" dès qu'on ouvre la page Envoyer une demande, même pour "
    "un Sitter. L'erreur est catchée plus loin en \"Impossible d'envoyer "
    "la demande\" côté Owner, et en message orange côté Walker/Sitter "
    "candidat.", body))
story.append(Paragraph(
    "<b>Fix:</b> dans lib/helper/dependency_injection.dart, ajout du bloc "
    "Get.put&lt;WalkerRepository&gt;(WalkerRepository(Get.find&lt;ApiClient&gt;()), "
    "permanent: true) entre SitterRepository et ChatRepository. 3 lignes.", body))

story.append(PageBreak())

# ========================================================================
# COMMANDES A LANCER DEMAIN
# ========================================================================
story.append(Paragraph("Commandes à lancer demain matin", h1))

story.append(Paragraph("1. Push hotfix + rebuild APK", h2))
story.append(Paragraph(
    "<pre>cd C:\\Users\\Usuario\\Downloads\\HopeTSIT_FINAL_FIXED\\HopeTSIT_FINAL\n"
    "git add frontend/lib/helper/dependency_injection.dart\n"
    "git commit -m \"Hotfix v16.1: register WalkerRepository in DI\"\n"
    "git push origin main\n"
    "\n"
    "cd frontend\n"
    "flutter analyze\n"
    "flutter build apk --debug\n"
    "copy build\\app\\outputs\\flutter-apk\\app-debug.apk C:\\Users\\Usuario\\Downloads\\HopeTSIT_v16-1b.apk</pre>", mono))

story.append(Paragraph("2. Installer + tester", h2))
story.append(Paragraph(
    "Installe HopeTSIT_v16-1b.apk sur le téléphone (via gestionnaire de "
    "fichiers, pas besoin d'adb). Teste dans cet ordre:", body))
tests = [
    "Owner → tap \"Envoyer une demande\" sur un Sitter → plus d'écran rouge (fix DI)",
    "Owner → tap \"Envoyer une demande\" sur Aeps Pieces (Walker) → plus d'écran rouge + demande partie au backend",
    "Login Walker → voir ses annonces Owner dans le feed → tap \"Envoyer la demande\" pour candidater → plus de message orange",
    "Login Sitter → voir ses annonces Owner → candidater → OK",
    "Dos-fishers (rétro-compat): Owner → Sitter qui avait dailyRate seulement → plus d'erreur hourlyRate",
]
for t_ in tests:
    story.append(Paragraph(f"&#9744; {t_}", body))

story.append(PageBreak())

# ========================================================================
# BUGS RESTANTS
# ========================================================================
story.append(Paragraph("Bugs restants à traiter demain (si tests ci-dessus passent)", h1))

restants = [
    ["P", "Bug", "Où regarder"],
    ["P1", "Doublons de posts dans le feed Walker (même annonce Owner apparaît 2 fois)",
     "sitter_homescreen.dart ligne ~476: combinedPosts = [...reservationRequests, ...posts]. "
     "Le dedup par post.id marche mais peut-être que le même post arrive avec un id "
     "différent (stringification). À vérifier."],
    ["P1", "Profil Walker ne sauvegarde pas email/phone après logout/switch de rôle",
     "Probablement un controller walker pas dans la liste des force-delete au logout. "
     "Check auth_controller.dart:logout() et _refreshDataAfterRoleSwitch(). Ajouter "
     "WalkerProfileController et UserController dans la liste force-delete si manquant."],
    ["P2", "Cycle complet Owner→Walker booking (accept/reject/paiement/conversation)",
     "~15-20 endpoints dans bookingController.js qui font Booking.find({sitterId:...}). "
     "Adapter chacun au pattern \"providerId matches sitterId OR walkerId\". Prévoir 2-3h."],
    ["P2", "Notifications in-app + push + email quand booking créée",
     "bookingController.createBooking + services/notificationSender. L'infra existe, "
     "reste à ajouter un sendNotification() après Booking.create."],
    ["P3", "Traduction FR admin HTML",
     "admin_dashboard.html ~120 labels à traduire."],
    ["P3", "Filtre Shop Activity (admin) — tiers Map Boost distincts",
     "admin_dashboard.html lignes 528-536."],
    ["P3", "Nettoyer [FEED DEBUG] maintenant que feed marche",
     "posts_controller.dart."],
]
t = Table(restants, colWidths=[1.2*cm, 7.5*cm, 8.3*cm])
t.setStyle(TableStyle([
    ('BACKGROUND', (0,0), (-1,0), colors.HexColor('#C62828')),
    ('TEXTCOLOR', (0,0), (-1,0), colors.white),
    ('FONTNAME', (0,0), (-1,0), 'Helvetica-Bold'),
    ('FONTSIZE', (0,0), (-1,-1), 8.5),
    ('GRID', (0,0), (-1,-1), 0.4, colors.grey),
    ('VALIGN', (0,0), (-1,-1), 'TOP'),
    ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, colors.HexColor('#FDECEA')]),
]))
story.append(t)

# ========================================================================
# PROMPT DE REPRISE
# ========================================================================
story.append(PageBreak())
story.append(Paragraph("Prompt de reprise pour nouvelle conversation Claude", h1))
story.append(Paragraph(
    "Si la conversation devient longue, ouvre une nouvelle session Claude "
    "et colle ce bloc pour reprendre le contexte:", body))
story.append(Spacer(1, 8))

prompt = """\
Je travaille sur HopeTSIT, app Flutter/GetX de pet-sitting avec 3 roles:
Owner, Sitter, Walker.
Backend Node.js sur Render: https://hopetsit-backend.onrender.com (v16.1 deploye).
Frontend: C:\\Users\\Usuario\\Downloads\\HopeTSIT_FINAL_FIXED\\HopeTSIT_FINAL\\frontend
Backend:  C:\\Users\\Usuario\\Downloads\\HopeTSIT_FINAL_FIXED\\HopeTSIT_FINAL\\backend
Admin HTML: C:\\Users\\Usuario\\Downloads\\HopeTSIT_FINAL_FIXED\\HopeTSIT_FINAL\\admin_dashboard.html
APK v15-6 deploye sur telephone; APK v16-1b a rebuilder demain apres hotfix DI.

Etat au moment du prompt (19/04/2026 soir):
- v16.1 backend + frontend code pousse (commit 1337e59 + commit c4c4ed2 pour v15-6).
- 1 hotfix local pas encore push: dependency_injection.dart ajoute Get.put<WalkerRepository>
  pour corriger crash "WalkerRepository not found" quand Owner ouvre page Envoyer demande.
- Tests attendus demain: Owner -> Sitter/Walker + Walker candidate annonce Owner.

REGLES CRITIQUES (respectes dans toutes les sessions precedentes):
1. JAMAIS de regex automatique multi-fichiers.
2. Toujours flutter analyze apres chaque modif.
3. Jamais toucher a la creation de post cote Owner (elle marche).
4. Backup avant grosse modif: xcopy /E /I /H HopeTSIT_FINAL_FIXED HopeTSIT_BACKUP_vXX.
5. Diagnostic d'abord, proposer 2-3 options, attendre OK user avant de coder.
6. Aller doucement, demander avant chaque etape importante.

Bugs restants connus a traiter:
P1. Doublons posts feed Walker (sitter_homescreen.dart:476).
P1. Profil Walker ne sauve pas email/phone apres logout/switch
    (auth_controller.dart:logout / _refreshDataAfterRoleSwitch).
P2. Cycle complet Owner->Walker booking (accept/reject/paiement) -
    ~15-20 endpoints bookingController a adapter au pattern
    Booking.find({$or:[{sitterId:id},{walkerId:id}]}).
P2. Notifications in-app+push+email quand booking creee.
P3. Traduction FR admin_dashboard.html.
P3. Filtre Shop Activity admin.

Quand tu corriges un bug:
1. Diagnostic sans code (lecture seule).
2. Montrer ce que tu as trouve.
3. Proposer 2-3 options avec recommandation.
4. Attendre OK user.
5. Appliquer avec Edit tool, une modif a la fois.
6. flutter analyze (si frontend).
7. Dire quoi tester.
"""
story.append(Paragraph("<pre>" + prompt.replace("<", "&lt;").replace(">", "&gt;") + "</pre>", mono))

story.append(Spacer(1, 12))
story.append(Paragraph(
    "<i>Fin de session du 19/04/2026. Daniel va se coucher, le backend est "
    "live, le hotfix frontend est prêt à pusher. À demain.</i>", small))

doc.build(story)
print(f"OK: {OUT}")

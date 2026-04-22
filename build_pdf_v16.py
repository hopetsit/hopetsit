"""Generate HopeTSIT Recap v16 PDF."""
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, PageBreak, Table, TableStyle,
)
from reportlab.lib.enums import TA_LEFT, TA_CENTER

OUT = "HopeTSIT_Recap_v16.pdf"

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
ok = ParagraphStyle('ok', parent=body, textColor=colors.HexColor('#2E7D32'))

doc = SimpleDocTemplate(OUT, pagesize=A4,
                        leftMargin=1.8*cm, rightMargin=1.8*cm,
                        topMargin=1.6*cm, bottomMargin=1.6*cm)

story = []

# ===== COVER =====
story.append(Paragraph("HopeTSIT — Récap v16", title))
story.append(Paragraph("Feed Sitter/Walker P0 fixé, Map Boost refondu, admin tour de contrôle OK", small))
story.append(Spacer(1, 8))
story.append(Paragraph(
    "Session v15 → v16. Gros nettoyage : la refonte UI Pet-sitter/Walker a "
    "été terminée (SitterCard neuf, SendRequest role-based, durées "
    "30/60/90/120, couleurs bleu sitter / vert walker). Map Boost a été "
    "visuellement distingué de Boost (pins animés, tiers Découverte / "
    "Visible / Pin Doré / Map Premium). Le <b>bug P0 du feed "
    "Sitter/Walker</b> qui traînait depuis v12 est enfin corrigé (backend "
    "require auth + frontend sur /posts/requests). L'admin HTML affiche "
    "maintenant les CGU et Privacy dans les 6 langues grâce au script de "
    "seed. Dernier bug non-résolu : Owner → Walker direct booking (demande "
    "refonte du Booking model).", body))

story.append(Spacer(1, 12))
story.append(Paragraph("État actuel (v16)", h1))

state = [
    ["Composant", "Statut"],
    ["Flutter analyze", "0 erreur, 0 warning"],
    ["APK debug build", "HopeTSIT_v15-6.apk (v16 inclut les fixes v15-3 → v15-6)"],
    ["Backend Render", "Commits v16 déployés (feed P0, rates flexibles, walker legacy)"],
    ["Admin web dashboard", "CGU + Privacy seed OK, Map Boost tiers humains"],
    ["Owner — Publier demande", "OK (geoloc câblée depuis v15)"],
    ["Owner — Onglet Pet-sitters (SitterCard)", "OK (carte compacte bleue, pills Jour/Sem/Mois)"],
    ["Owner — Onglet Promeneurs (WalkerCard)", "OK (walker legacy status pris en compte)"],
    ["Owner → Sitter (Envoyer demande)", "OK (hourlyRate flexible côté backend)"],
    ["Owner → Walker direct (Envoyer demande)", "BUG — refonte Booking model requise"],
    ["Owner — Page demande (SendRequestScreen)", "OK (role color, durées 30/60/90/120, walker simplifié)"],
    ["Sitter — Feed annonces Owner", "OK (P0 v12 fixé — /posts/requests auth)"],
    ["Walker — Feed annonces Owner", "OK (P0 v12 fixé — filter dog_walking côté backend)"],
    ["Sitter/Walker — Candidater annonce Owner", "À tester (flux Applications existant)"],
    ["Map Boost — cards", "OK (pins animés bleu/or, titres Découverte/Visible/…)"],
    ["Map Boost — fallback packages", "OK (1.99 / 4.99 / 8.99 / 14.99 €)"],
    ["PawMap — CTA Booster mon pin", "OK (banner bleu à côté de Passer Premium)"],
    ["Premium — Tuile 1 boost map offert", "OK (cliquable, bascule sur tab Map Boost)"],
    ["Signalement PawMap", "OK (section Gratuits + grille Premium 3 colonnes sur 1 page)"],
    ["Admin — Terms & Privacy Policy", "OK (6 langues seedées depuis legal/)"],
    ["Admin — Pricing Map Boost tiers", "OK (📍 Découverte / 🔆 Visible / ✨ Pin Doré / 🗺️ Map Premium)"],
    ["i18n — messages validation SendRequest", "OK (6 langues: fr/en/de/es/it/pt)"],
    ["Notifications in-app / push / email (booking)", "À BRANCHER — controller/sender existent déjà"],
]
t = Table(state, colWidths=[9.5*cm, 7.5*cm])
t.setStyle(TableStyle([
    ('BACKGROUND', (0,0), (-1,0), colors.HexColor('#1A237E')),
    ('TEXTCOLOR', (0,0), (-1,0), colors.white),
    ('FONTNAME', (0,0), (-1,0), 'Helvetica-Bold'),
    ('FONTSIZE', (0,0), (-1,-1), 8.5),
    ('GRID', (0,0), (-1,-1), 0.4, colors.grey),
    ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
    ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, colors.HexColor('#F5F5F5')]),
]))
story.append(t)

story.append(PageBreak())

# ===== PROMPT DE REPRISE =====
story.append(Paragraph("Prompt de reprise (pour nouvelle conversation Claude)", h1))
story.append(Paragraph(
    "Copiez le bloc ci-dessous en début de conversation Claude. "
    "Il donne tout le contexte nécessaire pour reprendre sans erreur.", body))
story.append(Spacer(1, 8))

prompt = """\
Je travaille sur HopeTSIT, app Flutter/GetX de pet-sitting avec 3 roles: Owner, Sitter, Walker.
Backend Node.js sur Render: https://hopetsit-backend.onrender.com (a jour v16).
Frontend: C:\\Users\\Usuario\\Downloads\\HopeTSIT_FINAL_FIXED\\HopeTSIT_FINAL\\frontend
Backend:  C:\\Users\\Usuario\\Downloads\\HopeTSIT_FINAL_FIXED\\HopeTSIT_FINAL\\backend
Admin HTML: C:\\Users\\Usuario\\Downloads\\HopeTSIT_FINAL_FIXED\\HopeTSIT_FINAL\\admin_dashboard.html
Dernier APK qui fonctionne: HopeTSIT_v15-6.apk (Downloads).

REGLES CRITIQUES (apprises a la dure):
1. JAMAIS de script Python/sed/regex automatique sur plusieurs fichiers Flutter.
   Toujours Edit tool cible, une modif a la fois.
2. Toujours flutter analyze apres chaque modif, avant de passer a la suite.
3. Jamais toucher a la creation de post cote Owner (elle marche).
4. Backend Render a jour jusqu'a v16 (feed P0, rates flexibles, walker legacy).
5. Backup avant grosse modif (xcopy /E /I /H HopeTSIT_FINAL_FIXED HopeTSIT_BACKUP_vXX).
6. Diagnostic d'abord, proposer 2-3 options, attendre OK user avant de coder.
7. Aller doucement. Demander avant chaque etape importante.

Etat au moment de ce prompt (v16):
- flutter analyze: 0 issue
- 3 roles 100% operationnels + switch entre eux OK
- Feed Sitter/Walker des annonces Owner: FIXE (backend requireAuth + frontend /posts/requests)
- Map Boost refondu: pins animes + titres Decouverte/Visible/Pin Dore/Map Premium
- SitterCard neuf (bleu compact) remplace l'ancienne ServiceProviderCard sur home
- SendRequestScreen role-based: chips services selon walker vs sitter, couleur bleu/vert
- Admin HTML: CGU + Privacy en 6 langues seedees, Map Boost tiers humains
- hourlyRate derive automatiquement de dailyRate/weeklyRate/monthlyRate cote backend

Bug PRINCIPAL a traiter a la prochaine session (refonte):
1. Owner -> Walker direct booking: le Booking model a sitterId:ref:'Sitter' required.
   Pour supporter les walkers il faut ajouter walkerId OU rendre sitterId polymorphe
   (refPath). Migration Mongo des bookings existants + adaptation de ~30 endpoints
   partout dans bookingController. Prevoir session dediee 2-3h.

Bugs P2/P3 (moins urgents):
2. Notifications in-app + push + email quand Owner envoie une demande a un Sitter/Walker.
   Services backend (notificationService, notificationSender) existent, reste a ajouter
   un sendNotification() apres le create Booking.
3. Traduire l'admin HTML en francais (actuellement tout en anglais).
4. Filtre Shop Activity (bronze/silver/gold/platinum): ajouter Map Boost equivalents.
5. Verifier que Sitter/Walker peut candidater a une annonce Owner via /applications.

Quand tu corriges un bug:
1. Diagnostic sans code
2. Montrer ce que tu as trouve
3. Proposer options avec recommandations
4. Attendre OK user
5. Appliquer avec Edit tool, une modif a la fois
6. flutter analyze (si frontend touche)
7. Dire quoi tester
"""
story.append(Paragraph("<pre>" + prompt.replace("<", "&lt;").replace(">", "&gt;") + "</pre>", mono))

story.append(PageBreak())

# ===== CHANGEMENTS v15 -> v16 =====
story.append(Paragraph("Changements v15 → v16 (résumé)", h1))

# --- 1. SitterCard + SendRequest role-based ---
story.append(Paragraph("1. SitterCard + SendRequest role-based (v15-3)", h2))
story.append(Paragraph(
    "<b>Problème:</b> côté Owner, l'onglet Pet-sitters utilisait l'ancienne "
    "ServiceProviderCard (avatar 100px, cadenas ****, design lourd). "
    "L'onglet Promeneurs utilisait une WalkerCard compacte. Incohérence visuelle. "
    "De plus, SendRequestScreen affichait tous les services (long_stay, dog_walking, "
    "overnight_stay, home_visit) indépendamment du rôle du prestataire.", body))
story.append(Paragraph(
    "<b>Fix:</b> nouveau widget <code>SitterCard</code> calqué sur WalkerCard "
    "(avatar 26.r, rating + ville + distance, pills Jour/Semaine/Mois, estimation "
    "total, CTA bleu). SendRequestScreen accepte maintenant un paramètre "
    "<code>serviceProviderRole</code> ('walker' ou 'sitter') : walker voit uniquement "
    "Promenade (auto-sélectionné), sitter voit Garderie + Garde multi-jours. "
    "Page walker simplifiée (1 date + 1 heure au lieu de Début/Fin). "
    "Couleurs selon rôle: bleu (#1A73E8) pour sitter, vert (#008000) pour walker.", body))
story.append(Paragraph(
    "<b>Fichiers:</b> lib/views/pet_owner/home/widgets/sitter_card.dart (nouveau), "
    "lib/controllers/send_request_controller.dart, "
    "lib/views/service_provider/send_request_screen.dart, "
    "lib/views/pet_owner/home/home_screen.dart.", small))

# --- 2. i18n + dailyRate fallback + estimation 90/120 ---
story.append(Paragraph("2. i18n validation + dailyRate fallback + estimation (v15-3)", h2))
story.append(Paragraph(
    "<b>Problème:</b> messages de validation en anglais dur (\"Please fill: Description\"), "
    "erreur \"Sitter must set hourlyRate\" alors que le sitter a un tarif journalier, "
    "estimation 90/120 min gelée au tarif 60 min.", body))
story.append(Paragraph(
    "<b>Fix frontend:</b> 9 nouvelles clés i18n × 6 langues "
    "(send_request_missing_pets, missing_description, etc.). "
    "<code>_referenceRateForBookingPayload</code> tombe maintenant sur dailyRate "
    "si hourlyRate absent. Formule estimation promenade corrigée: 30=halfHour, "
    "60=hourly, 90=hour+halfHour, 120=2×hourly, avec fallback proportionnel. "
    "SitterCard dérive aussi un tarif Jour depuis weekly/7 ou monthly/30 quand "
    "absent (préfixe ~ pour signaler approximation).", body))

# --- 3. Map Boost refonte ---
story.append(Paragraph("3. Map Boost — identité visuelle distincte de Boost (v15-4)", h2))
story.append(Paragraph(
    "<b>Problème:</b> Boost et Map Boost utilisaient les mêmes médailles bronze/silver/"
    "gold/platinum. Impossible de comprendre la différence au premier coup d'œil.", body))
story.append(Paragraph(
    "<b>Fix:</b> nouveau widget <code>MapBoostPinIcon</code> (pin cartographique + "
    "halos concentriques animés — pulse avec décalage pour effet radar). Nouveaux "
    "titres: 📍 Découverte (3j) / 🔆 Visible (7j) / ✨ Pin Doré (15j, badge Top map) "
    "/ 🗺️ Map Premium (30j). Accent bleu-map (#3B82F6) + or (#F59E0B) au lieu du "
    "rouge primaryColor. Prix fallback si API fail: 1.99 / 4.99 / 8.99 / 14.99 €. "
    "Bonus cohérence: CTA \"Booster mon pin\" sur PawMap (banner bleu, à côté du "
    "banner or \"Passer Premium\"). La ligne \"1 boost map offert\" dans l'onglet "
    "Premium devient cliquable et bascule sur l'onglet Map Boost.", body))
story.append(Paragraph(
    "<b>Fichiers:</b> lib/views/boost/widgets/map_boost_pin_icon.dart (nouveau), "
    "lib/views/boost/coin_shop_screen.dart, lib/views/map/paw_map_screen.dart, "
    "lib/controllers/map_boost_controller.dart, lib/utils/app_colors.dart.", small))

# --- 4. Signalement compact ---
story.append(Paragraph("4. Signalement compact 1 page (v15-4)", h2))
story.append(Paragraph(
    "<b>Problème:</b> create_report_sheet mélangeait 19 types (gratuits + Premium) "
    "dans un grand Wrap nécessitant du scroll. Description obsolète \"3 types "
    "gratuits\" (il y en a 4 depuis v15).", body))
story.append(Paragraph(
    "<b>Fix:</b> section \"Gratuits\" (vert pâle) en tête avec les 4 types libres. "
    "Section \"Premium\" en grille 3 colonnes pour les 15 Premium (cadenas pour "
    "non-Premium). Textes corrigés. Note field 2 lignes (était 3). Paddings "
    "réduits. Tient sur 1 écran standard sans scroll.", body))

story.append(PageBreak())

# --- 5. Admin seed + tier labels ---
story.append(Paragraph("5. Admin web — seed CGU/Privacy + labels Map Boost (v15-5)", h2))
story.append(Paragraph(
    "<b>Problème:</b> dans l'admin web, les sections Terms & Conditions et Privacy "
    "Policy affichaient \"No document yet\" pour toutes les langues — alors que "
    "l'app affichait bien les textes depuis les .md bundlés. La collection Mongo "
    "TermsDocument / PrivacyPolicyDocument était simplement vide. "
    "Pricing Map Boost affichait \"bronze / silver / gold / platinum\" en brut.", body))
story.append(Paragraph(
    "<b>Fix:</b> nouveau script <code>backend/src/scripts/seedLegalDocs.js</code> qui "
    "importe les 12 .md de <code>backend/legal/</code> dans Mongo (upsert safe, "
    "options --force et --dry-run). Lancé une fois sur Render Shell → les 6 langues × "
    "2 types sont maintenant visibles dans l'admin. "
    "Dans <code>admin_dashboard.html</code>, nouvelle fonction <code>tierLabel(cat, "
    "tier)</code> qui traduit les clés backend en labels humains selon la catégorie "
    "(Boost garde 🥉🥈🥇💎, Map Boost devient 📍🔆✨🗺️).", body))

# --- 6. Feed P0 + Backend fixes ---
story.append(Paragraph("6. Feed P0 Sitter/Walker + backend fixes (v15-6)", h2))
story.append(Paragraph(
    "<b>Problème P0 (v12 non fixé jusqu'ici):</b> les Sitter/Walker ne voyaient "
    "aucune annonce Owner dans leur feed Accueil. La route <code>/posts</code> "
    "(publique) ne renvoyait pas les reservation requests. La route dédiée "
    "<code>/posts/requests</code> existait mais sans middleware auth, donc "
    "<code>req.user</code> était undefined et le filtrage par rôle ne s'appliquait pas.", body))
story.append(Paragraph(
    "<b>Fix backend:</b> ajout de <code>requireAuth</code> sur "
    "<code>GET /posts/requests</code>. Le controller filtre déjà par rôle (walker → "
    "serviceTypes='dog_walking', sitter → $nin:['dog_walking'] + preferences). "
    "<b>Fix frontend:</b> nouvelle méthode <code>PostRepository.getRequestPosts()</code> "
    "avec requiresAuth: true. <code>PostsController.loadReservationRequests()</code> "
    "appelé au onInit et refresh. Le feed Sitter (partagé avec Walker via "
    "SitterHomescreen réutilisé) utilise maintenant <code>reservationRequests</code> "
    "en priorité, avec <code>posts</code> (média) en fallback.", body))
story.append(Paragraph(
    "<b>Fix backend complémentaires:</b> "
    "<code>bookingController.js:267</code> accepte maintenant "
    "<code>hourlyRate OR dailyRate OR weeklyRate OR monthlyRate</code>, et dérive "
    "automatiquement un hourlyRate équivalent pour tierPricing "
    "(daily/8h, weekly/56h, monthly/240h). "
    "<code>walkerController.js</code> (listWalkers + findNearbyWalkers) accepte les "
    "walkers créés avant l'ajout du champ <code>status</code> (fallback $exists:false). "
    "Ça fait réapparaître les walkers legacy dans l'onglet Promeneurs de l'Owner.", body))

story.append(PageBreak())

# ===== COMMANDES UTILES =====
story.append(Paragraph("Commandes utiles", h1))

story.append(Paragraph("Build APK debug + copie Downloads", h2))
story.append(Paragraph(
    "<pre>cd C:\\Users\\Usuario\\Downloads\\HopeTSIT_FINAL_FIXED\\HopeTSIT_FINAL\\frontend\n"
    "flutter analyze\n"
    "flutter build apk --debug\n"
    "copy build\\app\\outputs\\flutter-apk\\app-debug.apk C:\\Users\\Usuario\\Downloads\\HopeTSIT_v15-6.apk\n"
    "flutter install</pre>", mono))

story.append(Paragraph("Push backend sur Render", h2))
story.append(Paragraph(
    "<pre>cd C:\\Users\\Usuario\\Downloads\\HopeTSIT_FINAL_FIXED\\HopeTSIT_FINAL\n"
    "git add backend/ frontend/ admin_dashboard.html\n"
    "git commit -m \"Backend: description\"\n"
    "git push origin main\n"
    "# Si git dit 'index.lock: File exists' :\n"
    "#   del C:\\Users\\...\\HopeTSIT_FINAL\\.git\\index.lock</pre>", mono))

story.append(Paragraph("Seed CGU/Privacy Policy (1x après push)", h2))
story.append(Paragraph(
    "<pre># Sur Render Dashboard -> hopetsit-backend -> Shell\n"
    "node src/scripts/seedLegalDocs.js --dry-run   # preview\n"
    "node src/scripts/seedLegalDocs.js             # safe seed\n"
    "node src/scripts/seedLegalDocs.js --force     # overwrite tout</pre>", mono))

story.append(Paragraph("Backup complet", h2))
story.append(Paragraph(
    "<pre>cd C:\\Users\\Usuario\\Downloads\n"
    "xcopy /E /I /H HopeTSIT_FINAL_FIXED HopeTSIT_BACKUP_v16</pre>", mono))

story.append(Paragraph("Logs debug [FEED DEBUG]", h2))
story.append(Paragraph(
    "<pre>adb logcat -c\n"
    "adb logcat | findstr \"FEED DEBUG\"</pre>", mono))

story.append(PageBreak())

# ===== CE QUI RESTE A FAIRE =====
story.append(Paragraph("Ce qui reste à faire", h1))

todo = [
    ["P", "Tâche", "Où"],
    ["P0", "Owner → Walker direct booking (ajouter walkerId au Booking model)",
     "backend/src/models/Booking.js + bookingController.js (refonte)"],
    ["P1", "Notifications in-app + push + email quand booking créée",
     "bookingController.createBooking + services/notificationSender"],
    ["P1", "Tester candidature Sitter/Walker sur annonce Owner (Applications)",
     "backend routes/applicationRoutes.js + frontend sitter_homescreen"],
    ["P2", "Traduction FR de l'admin HTML (actuellement tout en EN)",
     "admin_dashboard.html (~120 labels à traduire)"],
    ["P2", "Admin Shop Activity filter: tiers Map Boost distincts de Boost",
     "admin_dashboard.html lignes 528-536"],
    ["P3", "Bbox search au lieu de radius pour gros zooms PawMap",
     "paw_map_controller.dart + backend mapPoiController"],
    ["P3", "Nettoyer les debugPrint [FEED DEBUG] maintenant que feed marche",
     "lib/controllers/posts_controller.dart"],
]
t = Table(todo, colWidths=[1.2*cm, 9.5*cm, 6.3*cm])
t.setStyle(TableStyle([
    ('BACKGROUND', (0,0), (-1,0), colors.HexColor('#C62828')),
    ('TEXTCOLOR', (0,0), (-1,0), colors.white),
    ('FONTNAME', (0,0), (-1,0), 'Helvetica-Bold'),
    ('FONTSIZE', (0,0), (-1,-1), 8.5),
    ('GRID', (0,0), (-1,-1), 0.4, colors.grey),
    ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
    ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, colors.HexColor('#FDECEA')]),
]))
story.append(t)

# --- Plan refonte Booking pour Walker ---
story.append(Paragraph("Plan refonte P0 — Owner → Walker direct booking", h2))
story.append(Paragraph(
    "Le Booking model a actuellement <code>sitterId: ref:'Sitter' required</code>. "
    "Quand l'Owner tape \"Envoyer une demande\" sur un Walker, le frontend envoie "
    "<code>sitterId = walkerId</code>, mais le backend appelle "
    "<code>Sitter.findById(sitterId)</code> → null → 404 \"Sitter not found\".", body))
story.append(Paragraph(
    "<b>Option A (recommandée):</b> ajouter <code>walkerId</code> optionnel au "
    "Booking model, exiger exactement un des deux (sitterId OU walkerId) via un "
    "validator Mongoose. Adapter ~30 callsites dans bookingController "
    "(findBy*, populate, sanitize). Migration optionnelle: laisser les bookings "
    "existants avec sitterId en place (rétrocompat).", body))
story.append(Paragraph(
    "<b>Option B:</b> champ <code>providerType</code> + <code>providerId</code> "
    "polymorphe via <code>refPath</code>. Plus propre à long terme mais migration "
    "plus lourde.", body))
story.append(Paragraph(
    "<b>Temps estimé:</b> 2-3h, avec test complet du cycle Owner → Walker → "
    "accept/reject → payment → conversation.", small))

story.append(PageBreak())

# ===== REGLES CRITIQUES =====
story.append(Paragraph("Règles critiques (à respecter absolument)", h1))

rules_txt = [
    ("JAMAIS de regex automatique multi-fichiers",
     "Les regex trop agressives ont cassé 377 fichiers en début de session. "
     "Toujours Edit tool ciblé, une modif à la fois."),
    ("TOUJOURS flutter analyze avant build",
     "Détection immédiate. Un analyze foiré vaut mieux qu'un build foiré."),
    ("NE PAS toucher à la création côté Owner",
     "Elle marche. Les bugs de lecture sont côté feed / Sitter / Walker."),
    ("Backend Render à jour jusqu'à v16",
     "Tous les fix (feed P0 auth, rates flexibles, walker legacy, seed legal) déployés. "
     "Vérifier git log avant de penser qu'un endpoint manque."),
    ("Backup avant grosse modif",
     "xcopy /E /I /H HopeTSIT_FINAL_FIXED HopeTSIT_BACKUP_vXX. Sauvé la session au moins 5 fois."),
    ("Valider AVANT de coder",
     "Diagnostic → options → OK user → application → analyze → test. "
     "Ne pas inventer des fix sur base d'hypothèses."),
    ("Tester chaque fix avant d'enchaîner",
     "Build APK + test sur téléphone. Les bugs visibles (snackbar, message à l'écran) "
     "sont plus rapides à diagnostiquer que le code."),
    ("Aller doucement, demander avant",
     "Quand le user dit \"fais doucement\", faire 1 étape, lui dire ce qui a été fait, "
     "attendre validation, puis continuer."),
]
for rule, desc in rules_txt:
    story.append(Paragraph(f"• <b>{rule}</b>", body))
    story.append(Paragraph(f"  {desc}", small))

story.append(Spacer(1, 12))
story.append(Paragraph(
    "<i>Fin du récap v16. Les 3 profils fonctionnent, le feed P0 est enfin corrigé, "
    "Map Boost a son identité visuelle. Prochain gros chantier: Owner → Walker "
    "direct booking (refonte Booking model).</i>", small))

doc.build(story)
print(f"✓ Generated: {OUT}")

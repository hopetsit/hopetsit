"""Generate HopeTSIT Recap v13 PDF."""
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, PageBreak, Table, TableStyle,
    KeepTogether,
)
from reportlab.lib.enums import TA_LEFT, TA_CENTER

OUT = "HopeTSIT_Recap_v13.pdf"

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
warn = ParagraphStyle('warn', parent=body, textColor=colors.HexColor('#E65100'))

doc = SimpleDocTemplate(OUT, pagesize=A4,
                        leftMargin=1.8*cm, rightMargin=1.8*cm,
                        topMargin=1.6*cm, bottomMargin=1.6*cm)

story = []

# ====== COVER ======
story.append(Paragraph("HopeTSIT — Récap v13", title))
story.append(Paragraph("État du projet : Walker role, référrals, edit-profile dédié, Sitter sans tarif horaire",
                       small))
story.append(Spacer(1, 8))
story.append(Paragraph(
    "Snapshot de la session qui a livré l'APK v13. "
    "Ce document permet de reprendre dans une nouvelle conversation "
    "sans refaire les erreurs déjà corrigées.", body))

story.append(Spacer(1, 12))
story.append(Paragraph("État actuel (v13)", h1))

state = [
    ["Composant", "Statut"],
    ["Flutter analyze", "0 erreur, 0 warning"],
    ["APK debug build", "OK — HopeTSIT_v13.apk"],
    ["Backend Render", "Walker role + referrals supportés (déployé)"],
    ["Walker signup + OTP", "Route directe vers WalkerNavWrapper"],
    ["Walker — Profil", "Charge sans 403"],
    ["Walker — Modifier profil", "Écran dédié EditWalkerProfileScreen"],
    ["Walker — Parrainages", "Code généré automatiquement"],
    ["Owner — Modifier profil", "100% Owner, inchangé"],
    ["Sitter — Modifier profil", "Tarif horaire retiré, autres tarifs OK"],
    ["Switch de rôle", "Owner ↔ Sitter ↔ Walker sans bug"],
    ["PawMap", "GPS + recherche ville + 17 types reports"],
    ["Feed Walker/Sitter", "Debug prints actifs (à investiguer)"],
]
t = Table(state, colWidths=[7*cm, 10*cm])
t.setStyle(TableStyle([
    ('BACKGROUND', (0,0), (-1,0), colors.HexColor('#1A237E')),
    ('TEXTCOLOR', (0,0), (-1,0), colors.white),
    ('FONTNAME', (0,0), (-1,0), 'Helvetica-Bold'),
    ('FONTSIZE', (0,0), (-1,-1), 9),
    ('GRID', (0,0), (-1,-1), 0.4, colors.grey),
    ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
    ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, colors.HexColor('#F5F5F5')]),
]))
story.append(t)

story.append(PageBreak())

# ====== PROMPT DE REPRISE ======
story.append(Paragraph("Prompt de reprise (à coller dans une nouvelle conversation)", h1))
story.append(Paragraph(
    "Copiez le bloc ci-dessous en début de conversation. Il donne à Claude "
    "tout le contexte nécessaire pour continuer sans refaire les erreurs.", body))
story.append(Spacer(1, 8))

prompt = """\
Je travaille sur HopeTSIT, une app Flutter/GetX de pet-sitting avec 3 rôles: Owner, Sitter, Walker.
Backend Node.js sur Render: https://hopetsit-backend.onrender.com (déjà à jour, support walker complet).
Frontend dans: C:\\Users\\Usuario\\Downloads\\HopeTSIT_FINAL_FIXED\\HopeTSIT_FINAL\\frontend
Backend dans: C:\\Users\\Usuario\\Downloads\\HopeTSIT_FINAL_FIXED\\HopeTSIT_FINAL\\backend

Dernier APK qui fonctionne: v13 (dans Downloads/HopeTSIT_v13.apk).

RÈGLES CRITIQUES (je les ai apprises à la dure dans la session précédente):
1. JAMAIS de script Python/sed/regex automatique sur plusieurs fichiers Flutter.
   Toujours Edit tool ciblé, une modif à la fois.
2. Toujours `flutter analyze` après chaque modif, avant de passer à la suite.
3. Jamais toucher à la création de post côté Owner (elle marche).
4. Les modèles backend NodeJS sont sensibles: un simple ajout de champ non connu
   fait retourner 400/403 sur certains endpoints.
5. Backend Render déjà à jour avec walker role. Frontend seul pour la plupart
   des corrections sauf si cas de 403 / unknown role.

État au moment de ce prompt:
- 0 issue dans flutter analyze
- Walker: signup+OTP+nav OK, parrainage OK, edit profile OK (écran dédié)
- Sitter: tarif horaire retiré de l'UI (autres tarifs OK)
- Owner: aucun changement, comportement historique

Bugs connus restants:
- Feed Walker/Sitter: les publications Owner n'apparaissent pas.
  Debug prints en place dans PostsController (cherchez [FEED DEBUG] dans
  adb logcat). Diagnostic précédent pointe vers:
  * App appelle GET /posts (public, sans filtre rôle)
  * Backend a GET /posts/requests qui filtre bien par rôle mais est jamais appelé
  * Fix probable: rebrancher PostsController sur /posts/requests avec auth
- Upload avatar walker: à vérifier (route /users/me/profile-picture utilisée,
  pas sûr que le backend résolve le walker doc)

Quand tu corriges un bug:
1. Diagnostic d'abord, PAS de code
2. Me montrer ce que tu as trouvé
3. Proposer 2-3 options avec tes recommandations
4. Attendre mon OK
5. Appliquer avec Edit tool ciblé
6. flutter analyze pour vérifier
7. Me dire quoi tester
"""

# Split into lines and escape for reportlab
from xml.sax.saxutils import escape
for line in prompt.splitlines():
    story.append(Paragraph(escape(line) if line.strip() else "&nbsp;", mono))

story.append(PageBreak())

# ====== MODIFS v12 -> v13 ======
story.append(Paragraph("Modifications v12 → v13", h1))

story.append(Paragraph("1. Backend Render — support walker pour les référrals", h2))
story.append(Paragraph("Fichier: <b>backend/src/controllers/userController.js</b> ligne 1000 — "
                       "ajout de <b>&#39;walker&#39;</b> dans la whitelist de <b>getMyReferralsRoute</b>. "
                       "Avant: bloquait avec 403 Unsupported role. Après: accepte walker.", body))
story.append(Paragraph("Fichier: <b>backend/src/services/referralService.js</b> — ajout de "
                       "l&#39;import <b>Walker</b>, helper <b>resolveReferralModel</b>, et "
                       "<b>findReferrerByCode</b> lookup Walker. Le code de parrainage est généré "
                       "automatiquement au premier appel pour les walkers existants.", body))
story.append(Paragraph("<i>Déployé sur Render. Le parrainage Walker fonctionne.</i>", ok))

story.append(Paragraph("2. Frontend — écran Modifier profil Walker dédié", h2))
story.append(Paragraph("<b>Avant</b>: Walker → Profil → Modifier profil ouvrait "
                       "<b>EditOwnerProfileScreen</b> qui tapait <b>GET /users/me/profile</b> "
                       "→ 403 Unsupported role.", body))
story.append(Paragraph("<b>Après</b>: Walker → Profil → Modifier profil ouvre "
                       "<b>EditWalkerProfileScreen</b> qui tape <b>GET /walkers/me</b> + "
                       "<b>GET /walkers/me/rates</b>.", body))

new_files = [
    ["Fichier créé", "Rôle"],
    ["lib/controllers/edit_walker_profile_controller.dart",
     "Controller dédié, utilise WalkerRepository"],
    ["lib/views/pet_walker/profile/edit_walker_profile_screen.dart",
     "UI dédiée: champs communs + tarif 60min + toggle atOwner"],
]
t = Table(new_files, colWidths=[9*cm, 8*cm])
t.setStyle(TableStyle([
    ('BACKGROUND', (0,0), (-1,0), colors.HexColor('#00695C')),
    ('TEXTCOLOR', (0,0), (-1,0), colors.white),
    ('FONTNAME', (0,0), (-1,0), 'Helvetica-Bold'),
    ('FONTSIZE', (0,0), (-1,-1), 8),
    ('GRID', (0,0), (-1,-1), 0.4, colors.grey),
    ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
]))
story.append(t)
story.append(Spacer(1, 6))

modified_files = [
    ["Fichier modifié", "Changement"],
    ["lib/views/pet_walker/profile/walker_profile_screen.dart",
     "Import + ligne 586: EditOwnerProfileScreen → EditWalkerProfileScreen"],
    ["lib/controllers/edit_owner_profile_controller.dart",
     "Revert: retour 100% Owner (plus de branching walker)"],
]
t = Table(modified_files, colWidths=[9*cm, 8*cm])
t.setStyle(TableStyle([
    ('BACKGROUND', (0,0), (-1,0), colors.HexColor('#E65100')),
    ('TEXTCOLOR', (0,0), (-1,0), colors.white),
    ('FONTNAME', (0,0), (-1,0), 'Helvetica-Bold'),
    ('FONTSIZE', (0,0), (-1,-1), 8),
    ('GRID', (0,0), (-1,-1), 0.4, colors.grey),
    ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
]))
story.append(t)

story.append(Paragraph("3. Sitter — retrait du tarif horaire", h2))
story.append(Paragraph("Les Sitters travaillent sur une base minimum 1 jour. Le champ "
                       "&quot;Tarif horaire&quot; a été retiré de l&#39;UI mais "
                       "<b>hourlyRateController</b> est conservé dans le controller "
                       "(28 autres fichiers y font référence).", body))
story.append(Paragraph("<b>Fichier:</b> lib/views/pet_sitter/profile/edit_sitter_profile_screen.dart — "
                       "bloc &quot;Hourly Rate Field&quot; (lignes 358-382) supprimé", body))
story.append(Paragraph("<b>Fichier:</b> lib/controllers/edit_sitter_profile_controller.dart "
                       "ligne 442 — <b>hourlyRate: null</b> dans updateProfile → "
                       "le backend ne reçoit plus de valeur, il garde ce qu&#39;il a en BDD", body))
story.append(Paragraph("Les tarifs journalier, hebdomadaire et mensuel sont toujours visibles "
                       "et éditables.", body))

story.append(PageBreak())

# ====== CE QUI RESTE A FAIRE ======
story.append(Paragraph("Ce qui reste à faire", h1))

remaining = [
    ["P", "Tâche", "Où"],
    ["P0", "Feed Walker/Sitter: afficher les publications Owner",
     "PostsController + SitterHomescreen"],
    ["P1", "Vérifier upload avatar Walker (peut être cassé)",
     "WalkerRepository ou backend /users/me/profile-picture"],
    ["P2", "Nettoyer les debugPrint [FEED DEBUG] une fois le feed fixé",
     "posts_controller.dart"],
    ["P2", "Masquer les traductions de sitter_detail_hourly_rate_label "
           "sur les 6 fichiers de langue si le champ doit disparaître partout",
     "lib/localization/translations/*.dart"],
    ["P3", "Ajouter plusieurs durées de tarif pour Walker "
           "(30/45/60/90 min) au lieu d&#39;une seule",
     "EditWalkerProfileScreen"],
    ["P3", "Créer un écran EditWalkerProfileScreen multilingue "
           "(actuellement les libellés Walker-only sont en français en dur)",
     "edit_walker_profile_screen.dart + translations/*.dart"],
]
t = Table(remaining, colWidths=[1.2*cm, 9*cm, 6.8*cm])
t.setStyle(TableStyle([
    ('BACKGROUND', (0,0), (-1,0), colors.HexColor('#C62828')),
    ('TEXTCOLOR', (0,0), (-1,0), colors.white),
    ('FONTNAME', (0,0), (-1,0), 'Helvetica-Bold'),
    ('FONTSIZE', (0,0), (-1,-1), 8),
    ('GRID', (0,0), (-1,-1), 0.4, colors.grey),
    ('VALIGN', (0,0), (-1,-1), 'TOP'),
    ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, colors.HexColor('#FFEBEE')]),
]))
story.append(t)

story.append(Paragraph("Bug feed Walker/Sitter — diagnostic déjà fait", h2))
story.append(Paragraph("Le bug le plus important. Diagnostic du v12:", body))
story.append(Paragraph(
    "• Les Owners créent bien des demandes (serviceTypes envoyé correctement, "
    "schéma Mongo pas strict sur les valeurs).<br/>"
    "• L&#39;app appelle <b>GET /posts</b> (handler <b>listPosts</b>) qui "
    "retourne tous les posts SANS filtre postType ni rôle.<br/>"
    "• Le backend a <b>GET /posts/requests</b> (handler <b>getRequestPosts</b>) "
    "qui filtre par rôle (walker → dog_walking, sitter → exclut dog_walking) "
    "mais l&#39;app ne l&#39;appelle JAMAIS.<br/>"
    "• Fix proposé (non appliqué encore): rebrancher "
    "<b>PostsController.loadPostsWithoutMedia()</b> sur <b>/posts/requests</b> "
    "avec <b>requiresAuth: true</b>.", body))
story.append(Paragraph("Les debug prints [FEED DEBUG] sont déjà en place dans "
                       "posts_controller.dart. Pour les voir:", body))
story.append(Paragraph(
    "adb logcat | findstr \"FEED DEBUG\"", mono))

story.append(PageBreak())

# ====== COMMANDES UTILES ======
story.append(Paragraph("Commandes utiles", h1))

story.append(Paragraph("Build APK debug + copie dans Downloads", h2))
story.append(Paragraph(
    "cd C:\\Users\\Usuario\\Downloads\\HopeTSIT_FINAL_FIXED\\HopeTSIT_FINAL\\frontend<br/>"
    "flutter build apk --debug &amp;&amp; copy build\\app\\outputs\\flutter-apk\\app-debug.apk C:\\Users\\Usuario\\Downloads\\HopeTSIT_v14.apk",
    mono))

story.append(Paragraph("Analyse statique (avant commit)", h2))
story.append(Paragraph("flutter analyze", mono))

story.append(Paragraph("Installer APK sur téléphone (USB + débogage)", h2))
story.append(Paragraph("adb install -r C:\\Users\\Usuario\\Downloads\\HopeTSIT_v13.apk",
                       mono))

story.append(Paragraph("Lire les logs [FEED DEBUG]", h2))
story.append(Paragraph(
    "adb logcat -c<br/>"
    "adb logcat | findstr \"FEED DEBUG\"", mono))

story.append(Paragraph("Backup du projet avant grosse modif", h2))
story.append(Paragraph(
    "cd C:\\Users\\Usuario\\Downloads<br/>"
    "xcopy /E /I /H HopeTSIT_FINAL_FIXED HopeTSIT_BACKUP_v13",
    mono))

story.append(Paragraph("Push backend sur Render (quand il y a des modifs)", h2))
story.append(Paragraph(
    "cd C:\\Users\\Usuario\\Downloads\\HopeTSIT_FINAL_FIXED\\HopeTSIT_FINAL<br/>"
    "git add backend/<br/>"
    "git commit -m &quot;Backend: description&quot;<br/>"
    "git push origin main",
    mono))

# ====== REGLES CRITIQUES ======
story.append(Paragraph("Règles critiques (à ne pas oublier)", h1))

rules = [
    ("JAMAIS de script Python/regex/sed automatique",
     "Les regex trop agressives ont cassé 377 fichiers au début de la session. "
     "Toujours Edit tool ciblé, une modif à la fois."),
    ("TOUJOURS flutter analyze avant de build",
     "Un analyze à chaque modif = détection immédiate des cassés. "
     "Un build foiré = plus de temps perdu que 10 analyzes."),
    ("NE PAS toucher à la création côté Owner",
     "Les demandes Owner sont bien envoyées au backend. Le bug du feed est "
     "côté lecture, pas côté écriture."),
    ("Backend Render déjà à jour",
     "Tous les fix walker/referrals côté backend sont déployés. "
     "Vérifier avant de penser qu&#39;un endpoint manque."),
    ("Backup avant grosse modif",
     "xcopy /E /I /H HopeTSIT_FINAL_FIXED HopeTSIT_BACKUP_xxx. "
     "Le backup v12 nous a sauvés plusieurs fois."),
    ("Demander validation avant de modifier quelque chose de sensible",
     "Surtout si le code est utilisé dans plus de 10 fichiers. "
     "Montrer le plan, attendre OK, puis appliquer."),
]
for title_rule, desc in rules:
    story.append(Paragraph(f"• <b>{title_rule}</b>", body))
    story.append(Paragraph(f"  {desc}", small))
    story.append(Spacer(1, 4))

story.append(Spacer(1, 20))
story.append(Paragraph(
    "Fin du récap v13. Bonne continuation — "
    "et surtout, faites des backups avant les grosses modifs.", small))

doc.build(story)
print(f"Generated {OUT}")

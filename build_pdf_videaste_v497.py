# -*- coding: utf-8 -*-
"""Guide pour le videaste — HoPetSit v23.1.497. Sortie dans Downloads."""
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, ListFlowable, ListItem
from reportlab.lib.enums import TA_JUSTIFY

OUT = "C:/Users/Usuario/Downloads/HoPetSit_Guide_Videaste_v23.1.497.pdf"
doc = SimpleDocTemplate(OUT, pagesize=A4, leftMargin=1.8*cm, rightMargin=1.8*cm,
                        topMargin=1.7*cm, bottomMargin=1.7*cm, title="HoPetSit - Guide Videaste v497")
s = getSampleStyleSheet()
H1 = ParagraphStyle("H1", parent=s["Heading1"], fontSize=21, textColor=colors.HexColor("#F0562B"), spaceAfter=4)
SUB = ParagraphStyle("SUB", parent=s["BodyText"], fontSize=10.5, textColor=colors.HexColor("#666666"), spaceAfter=12)
H2 = ParagraphStyle("H2", parent=s["Heading2"], fontSize=14, textColor=colors.HexColor("#1F1D1B"), spaceBefore=13, spaceAfter=6)
P = ParagraphStyle("P", parent=s["BodyText"], fontSize=10.5, leading=15, alignment=TA_JUSTIFY)
B = ParagraphStyle("B", parent=P, leftIndent=10, spaceAfter=2)
NOTE = ParagraphStyle("NOTE", parent=P, textColor=colors.HexColor("#8A4B0A"),
                      backColor=colors.HexColor("#FEF3C7"), borderPadding=6, spaceBefore=4, spaceAfter=6)


def bullets(items):
    return ListFlowable(
        [ListItem(Paragraph(t, B), leftIndent=8, value="•") for t in items],
        bulletType="bullet", start="•", leftIndent=10,
    )


f = []
f.append(Paragraph("HoPetSit - Guide pour le videaste", H1))
f.append(Paragraph("Version app 23.1.497 - l'app suit la langue du telephone (6 langues : FR/EN/ES/DE/IT/PT). Couleur de marque : orange #F0562B. Le site web fait maintenant tout ce que fait l'app (vitrine + dashboard + PawMap).", SUB))

f.append(Paragraph("1. C'est quoi HoPetSit ?", H2))
f.append(Paragraph("Une application de garde et de promenade d'animaux qui met en relation des proprietaires avec des promeneurs et des pet-sitters de confiance. Au-dela de la garde, l'app integre une carte communautaire (PawMap), des lieux pet-friendly (PawSpot), un suivi en temps reel de l'animal pendant le service (PawFollow), un programme de fidelite (PawPoints) et des abonnements (PawPremium / PawBoost).", P))

f.append(Paragraph("2. Les 3 roles (chacun a sa couleur)", H2))
f.append(bullets([
    "<b>Proprietaire</b> (orange) : poste une annonce, choisit un prestataire, paie, suit son animal en direct.",
    "<b>Promeneur</b> (vert) : propose des promenades (30 min / 1 h / 2 h), recoit des demandes, partage sa position pendant la balade.",
    "<b>Gardien / Pet-sitter</b> (bleu) : propose la garde (chez lui ou au domicile), la garderie, etc.",
]))

f.append(Paragraph("3. Fonctionnalites cles a filmer", H2))
f.append(bullets([
    "Ecran d'accueil moderne (logo, 4 services, boutons d'inscription / connexion).",
    "Inscription guidee (photo mise en avant, infos, localisation avec auto-detection + recherche de ville, tarifs, apercu).",
    "Profils par role : photo + statut + 'jours actifs' + note, badges d'abonnement (jours restants).",
    "Recherche de prestataires + annonces (cartes premium par animal).",
    "Reservation + paiement securise.",
    "Messagerie en bulles + Suivi en direct (carte) entre proprietaire et prestataire.",
    "<b>PawMap</b> : carte avec halos animes, lieux PawSpot, signalements, et <b>membres proches en ROSE</b> (badge patte rose, couronne si Premium) - NOUVEAU.",
    "<b>4 boutons PawMap</b> : Voir spots / Voir signaux / Tag spot / Signaler (creation au viseur central).",
    "PawPoints (fidelite) + boutique PawPremium / PawBoost / PawFollow / PawSpot.",
]))

f.append(Paragraph("4. Scenario de tournage suggere (ordre des plans)", H2))
f.append(bullets([
    "Plan 1 - Ouverture : ecran d'accueil orange, logo HoPetSit, la grille des 4 services.",
    "Plan 2 - Inscription : derouler les etapes d'un promeneur (vert) ou gardien (bleu) - montrer la photo de profil mise en avant + l'auto-detection de position.",
    "Plan 3 - Profil : en-tete (photo + nom + statut + 'jours actifs' + note) + badges d'abonnement.",
    "Plan 4 - Cote proprietaire : publier une demande, parcourir les prestataires, ouvrir une annonce.",
    "Plan 5 - Reservation + paiement (montrer la confirmation).",
    "Plan 6 - Conversation : bulles de messages, bouton Traduire, puis 'Suivi en direct'.",
    "Plan 7 - LE moment fort : suivi en temps reel sur la carte (2 telephones, voir note ci-dessous).",
    "Plan 8 - PawMap : se balader sur la carte, montrer un PawSpot, un signalement, et les MEMBRES en ROSE autour.",
    "Plan 9 - PawPoints + boutique (abonnements) pour finir sur la valeur ajoutee.",
    "Plan 10 (bonus) - Le SITE WEB : accueil + dashboard + PawMap (memes donnees que l'app) pour montrer le multi-plateforme.",
]))

f.append(Paragraph("5. Nouveautes recentes (v488 -> v497) a mettre en valeur", H2))
f.append(bullets([
    "PawMap : membres proches affiches en ROSE (app ET site web), couronne doree pour les Premium.",
    "Notifications + emails dans la langue de l'utilisateur (suivent la langue choisie).",
    "Badge / couronne Premium visibles pour le staff et les abonnes, partout (carte, profil, liste d'amis).",
    "Demande d'ami : notification (cloche + bandeau d'accueil) sur les 3 roles + email.",
    "Site web complet : PawMap (spots / signaux / tag / signaler), PawPoints, code promo, dashboard.",
]))

f.append(Paragraph("6. Conseils pratiques", H2))
f.append(bullets([
    "Utiliser la DERNIERE version : HoPetSit_v23.1.497.apk (Android) ou la build iOS 23.1.497.",
    "Pour filmer le suivi en direct et les membres roses, prevoir 2 telephones (2 comptes) avec un abonnement actif (PawSpot/PawPremium) + un service paye.",
    "Mode clair conseille pour la lisibilite ; un court plan en mode sombre fait un joli bonus (l'app suit le theme du telephone).",
    "Activer la localisation et les notifications sur les telephones de tournage.",
    "Enregistrement d'ecran natif du telephone = qualite maximale (eviter de filmer l'ecran a la camera).",
    "Le site web (vitrine + telechargement de l'app) peut servir de plan d'intro/outro.",
]))

f.append(Spacer(1, 0.2*cm))
f.append(Paragraph("Note : certaines actions (paiement reel, suivi en direct, membres roses sur la carte) demandent un compte et un abonnement actifs. Prevenir l'equipe pour preparer 2 comptes de demonstration ABONNES avant le tournage.", NOTE))

doc.build(f)
print("OK", OUT)

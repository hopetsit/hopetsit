"""Generate HopeTSIT Logo Brief PDF — brief prompt for a new Claude conversation."""
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, PageBreak, Table, TableStyle,
)
from reportlab.lib.enums import TA_LEFT, TA_CENTER

OUT = "HopeTSIT_Logo_Brief.pdf"

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

story.append(Paragraph("HopeTSIT — Brief logo", title))
story.append(Paragraph("À coller dans une nouvelle conversation Claude (ou Midjourney / DALL-E) pour générer le logo de l'app", small))

story.append(Paragraph("Contexte produit (1 ligne)", h1))
story.append(Paragraph(
    "HopeTSIT est une app mobile européenne de pet-sitting communautaire avec "
    "3 rôles — Owner (propriétaire), Sitter (garde d'animaux), Walker (promeneur) "
    "— et une PawMap sociale qui localise vétos, parcs à chiens, points d'eau "
    "et signalements temps réel.", body))

story.append(Paragraph("Prompt principal (à copier-coller)", h1))

prompt = """\
Tu es un directeur artistique. Je veux un logo pour une app mobile de pet-sitting
appelee HopeTSIT. Voici le brief exhaustif :

IDENTITE & VALEURS
- Marque : HopeTSIT (prononce "Hope-T-S-I-T")
- Secteur : pet-sitting communautaire europeen (france / belgique / suisse /
  espagne / italie / allemagne / portugal / pays-bas / autriche / royaume-uni /
  luxembourg)
- Promesse : confier son animal a des voisins de confiance, avec une carte
  sociale (PawMap) qui relie proprietaires + sitters + promeneurs
- Valeurs : chaleur, confiance, communaute locale, securite animale, simplicite
- Ton : moderne mais accessible, pas luxe premium, pas kiddy, plutot "tech
  bienveillante" (type Vinted ou Gemini mais avec l'ame animale de Pawshake)

UTILISATEURS
- 3 roles distincts qui utilisent la meme app :
  1. Owner (proprietaire) — cherche un gardien ou promeneur pour son animal
  2. Sitter (gardien) — accueille ou visite des animaux
  3. Walker (promeneur) — promene des chiens
- Tranche d'age : 25-55 ans, citadins, urbains periurbains, smartphones Android+iOS

STYLE VISUEL
- Flat, moderne, mobile-first, epure
- Coins arrondis, pas de pointes agressives
- Evocateur d'un pin de carte (map pin) + pate d'animal + maison :
  l'idee "animal accueilli quelque part pres de chez toi"
- Doit marcher sur fond fonce ET clair (dark mode supporte)
- Doit etre reconnaissable en 16×16 px (favicon, notification push)

COULEURS (palette actuelle de l'app)
- Primary (rouge-orange chaleureux) : #EF4324
- Primary dark (pour hover/pressed) : #C23A20
- Vert walker (complementaire promenade) : #008000
- Bleu sitter (complementaire garde) : #1A73E8
- Or premium (accent abonnement) : #F59E0B
- Neutre fond clair : #F5F5F5
- Neutre fond sombre : #0D0D0D

ELEMENTS SOUHAITES (choisis-en 1 ou 2, pas plus)
- Une pate (paw) stylisee
- Un pin de localisation (map pin)
- Une goutte d'eau (reference aux points d'eau signales sur la PawMap)
- Un coeur discret (confiance)
- Une ombre de chien ou silhouette simple
- Les lettres H et T stylisees (initiales HopeTSIT)

ELEMENTS INTERDITS
- Pas d'os (cliche)
- Pas de laisse enroulee
- Pas de chien dessine trop realiste
- Pas de visage humain
- Pas de typo Comic Sans ou similaire

LIVRABLES ATTENDUS (en plusieurs variantes)
1. Logo principal carre 1024×1024 sur fond transparent (SVG + PNG)
2. Variante monochrome blanc (pour fond colore)
3. Variante monochrome noir (pour fond blanc)
4. App icon iOS (carre arrondi 1024×1024 sans transparence, fond plein)
5. App icon Android (adaptive : foreground layer + background layer separes)
6. Favicon 32×32 lisible
7. Wordmark horizontal "HopeTSIT" pour le header app (logo + nom cote a cote)

CONTRAINTES TECHNIQUES
- SVG optimise (viewBox propre, pas de transform imbrique, paths simplifies)
- PNG export a 3 tailles : 512, 1024, 2048 px
- Texte "HopeTSIT" en DM Sans (sans serif moderne) ou equivalent libre

PROCESSUS ATTENDU
1. Propose-moi 3 directions creatives differentes en mode esquisse verbale
   (juste decrire, pas de rendu) : par ex. "direction A = pin de carte avec
   pate en relief au centre, rouge-orange dominant, blanc en fond, look
   Airbnb-Uber"
2. Je choisis une direction
3. Tu generes la version finale dans chaque variante demandee
4. Tu m'explique les choix typo, couleur, proportions

MOOD-BOARD REFERENCES (pour calibrer)
- Airbnb logo (Belo) — simplicite geometrique
- Vinted — chaleur et accessibilite
- Pawshake — secteur direct
- Waze — communautaire, carto
- Hopper — courbes rondes, confiance

Commence par me proposer les 3 directions, puis attend ma validation.
"""
story.append(Paragraph("<pre>" + prompt.replace("<", "&lt;").replace(">", "&gt;") + "</pre>", mono))

story.append(PageBreak())

story.append(Paragraph("Comment utiliser ce brief", h1))
story.append(Paragraph(
    "Ouvre une <b>nouvelle conversation Claude</b> (une nouvelle page vierge, "
    "pas la suite de celle où tu as développé l'app — sinon il va te proposer "
    "du Flutter au lieu de directions artistiques).", body))
story.append(Paragraph(
    "Colle le prompt principal (encadré gris ci-dessus) dans le premier message. "
    "Claude va te répondre avec 3 directions créatives verbales. Tu en choisis une. "
    "Puis il génère les variantes.", body))
story.append(Paragraph(
    "<b>Astuce :</b> si tu préfères un générateur d'image direct (DALL-E / "
    "Midjourney / Stable Diffusion), prends uniquement la section \"ELEMENTS "
    "SOUHAITES\" + \"STYLE VISUEL\" + \"COULEURS\" et formule-le en une seule "
    "phrase. Exemple :", body))

mj_prompt = """\
A modern flat minimalist logo for a European pet-sitting mobile app called
HopeTSIT, featuring a stylized map pin with a subtle paw silhouette inside,
warm red-orange (#EF4324) dominant with soft white accents, clean geometric
lines, rounded corners, dark-mode friendly, recognizable at 16x16px, white
background, vector style, Airbnb-meets-Pawshake aesthetic, trust and
community feel, no text.
"""
story.append(Paragraph("<pre>" + mj_prompt + "</pre>", mono))

story.append(Paragraph("Checklist pour valider le résultat", h1))
story.append(Paragraph(
    "Avant de figer le logo, verifie que :", body))
check = [
    "Lisible a 16 px (teste-le comme favicon dans ton navigateur)",
    "Contraste OK sur fond clair ET fond sombre (dark mode)",
    "Identifie clairement le secteur pet-sitting / animaux (pas juste un pin generique)",
    "Ne ressemble PAS a un logo connu (Airbnb, Waze, Pawshake, Uber, Rover)",
    "Marche en monochrome noir et blanc (test d'impression)",
    "Export SVG propre (pas d'effet raster), viewBox 0 0 1024 1024",
    "Palette de couleurs coherente avec l'app (primary #EF4324)",
    "App icon iOS et Android (foreground + background) livres",
    "Wordmark horizontal optionnel pour le header",
    "Droits d'usage libres (si Midjourney/DALL-E : commercial OK ; si humain, ceder les droits)",
]
for c in check:
    story.append(Paragraph(f"&#9744; {c}", body))

doc.build(story)
print(f"OK: {OUT}")

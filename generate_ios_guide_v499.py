# -*- coding: utf-8 -*-
"""
Genere le guide de build iOS HoPetSit v23.1.499.
Sortie : ~/Downloads/HoPetSit_iOS_Build_Guide_v23.1.499.pdf
"""
import os
from pathlib import Path
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import mm
from reportlab.lib.colors import HexColor
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, HRFlowable,
)

OUT = Path.home() / "Downloads" / "HoPetSit_iOS_Build_Guide_v23.1.499.pdf"
ORANGE = HexColor("#EF4324")
INK = HexColor("#17141f")
MUTED = HexColor("#6b7280")


def esc(s):
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


styles = getSampleStyleSheet()
H1 = ParagraphStyle("H1", parent=styles["Heading1"], textColor=ORANGE, fontSize=20, spaceAfter=4)
SUB = ParagraphStyle("SUB", parent=styles["Normal"], textColor=MUTED, fontSize=10, spaceAfter=10)
H2 = ParagraphStyle("H2", parent=styles["Heading2"], textColor=INK, fontSize=13, spaceBefore=12, spaceAfter=4)
BODY = ParagraphStyle("BODY", parent=styles["Normal"], textColor=INK, fontSize=10.5, leading=15, spaceAfter=5)
CODE = ParagraphStyle("CODE", parent=styles["Code"], fontSize=9.5, leading=13,
                      backColor=HexColor("#f3f4f6"), borderPadding=6, spaceAfter=6, textColor=INK)
WARN = ParagraphStyle("WARN", parent=BODY, backColor=HexColor("#FEF3C7"), borderPadding=6,
                      textColor=HexColor("#92400E"))


def li(t):
    return Paragraph("&bull;&nbsp;&nbsp;" + t, BODY)


story = []
story.append(Paragraph("HoPetSit - Guide de build iOS", H1))
story.append(Paragraph("Version 23.1.499 (Android) - iOS build 502 - CARDELLI HERMANOS LIMITED", SUB))
story.append(HRFlowable(width="100%", color=HexColor("#e5e7eb")))

story.append(Paragraph("Identifiants du projet", H2))
data = [
    ["Bundle iOS", "com.hopetsit.app  (INCHANGE - le renommage v498 ne touche QUE Android)"],
    ["Apple Team ID", "49C67YDPJ5"],
    ["App Store ID", "6763645719"],
    ["Firebase", "projet hopetsit (470089536255)"],
    ["Repo", "github.com/hopetsit/hopetsit (origin)"],
    ["Backend", "hopetsit-backend.onrender.com (plan payant)"],
]
t = Table([[esc(a), esc(b)] for a, b in data], colWidths=[38 * mm, 130 * mm])
t.setStyle(TableStyle([
    ("FONT", (0, 0), (-1, -1), "Helvetica", 9.5),
    ("FONT", (0, 0), (0, -1), "Helvetica-Bold", 9.5),
    ("TEXTCOLOR", (0, 0), (-1, -1), INK),
    ("VALIGN", (0, 0), (-1, -1), "TOP"),
    ("BOTTOMPADDING", (0, 0), (-1, -1), 5), ("TOPPADDING", (0, 0), (-1, -1), 5),
    ("LINEBELOW", (0, 0), (-1, -2), 0.4, HexColor("#e5e7eb")),
]))
story.append(t)

story.append(Paragraph("1. Recuperer le dernier code (IMPORTANT)", H2))
story.append(Paragraph("Tout le travail recent (renommage package Android, fixes couronne premium, "
                       "admin) est sur origin/main. Sur le Mac :", BODY))
story.append(Paragraph(esc("git pull origin main"), CODE))
story.append(Paragraph(esc("# Si tes correctifs Apple locaux disparaissent apres le pull :"), CODE))
story.append(Paragraph(esc("git apply HoPetSit_modifs_locales_20260625.patch"), CODE))
story.append(Paragraph("NE PAS ecraser le Mac avec le zip de sauvegarde : il ecraserait les "
                       "correctifs Apple non commites. Le zip est une sauvegarde, pas une source de sync.", WARN))

story.append(Paragraph("2. Pre-requis Mac", H2))
story.append(li("Xcode a jour (App Store) + Command Line Tools."))
story.append(li("Flutter installe (flutter doctor) + CocoaPods (sudo gem install cocoapods)."))
story.append(li("Compte Apple Developer (Team 49C67YDPJ5) connecte dans Xcode."))

story.append(Paragraph("3. Bump de version (avant chaque build)", H2))
story.append(Paragraph("Dans frontend/pubspec.yaml, incrementer la ligne version "
                       "(ex. 23.1.503+503). Le build number doit etre superieur au precedent "
                       "accepte par App Store Connect.", BODY))

story.append(Paragraph("4. Build iOS", H2))
story.append(Paragraph(esc("cd frontend"), CODE))
story.append(Paragraph(esc("flutter pub get"), CODE))
story.append(Paragraph(esc("cd ios && pod install && cd .."), CODE))
story.append(Paragraph(esc("flutter build ipa --release"), CODE))
story.append(Paragraph("Puis ouvrir ios/Runner.xcworkspace dans Xcode -> Product -> Archive -> "
                       "Distribute App -> App Store Connect. (Ou utiliser Transporter / Codemagic "
                       "avec le .ipa genere dans build/ios/ipa/.)", BODY))

story.append(Paragraph("5. Apple Sign-In (reference si ca recasse)", H2))
story.append(Paragraph("3 causes empilees deja corrigees (detail : docs/claude-memory/"
                       "apple-signin-fix-and-demo-account.md) :", BODY))
story.append(li("CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements ajoute aux 3 configs du target "
                "Runner (project.pbxproj)."))
story.append(li("loginWithApple : OAuthProvider('apple.com').credential(idToken, rawNonce, "
                "accessToken: appleCredential.authorizationCode) <- le fix cle."))
story.append(li("Lib the_apple_sign_in remplacee par sign_in_with_apple v8 + crypto (nonce SHA-256)."))

story.append(Paragraph("6. Points de vigilance App Store", H2))
story.append(Paragraph("COMPTE DEMO : fournir un compte email + mot de passe (PAS Google/Apple a "
                       "2 facteurs) dans App Store Connect -> Informations de connexion. C'est la "
                       "cause des refus Apple ET Google.", WARN))
story.append(li("Regle 3.1.1 : paiements par carte (Airwallex) au lieu d'achat integre Apple - "
                "risque de refus. Plan B : masquer la boutique sur iOS."))
story.append(li("Le renommage package v498 concerne UNIQUEMENT Android. iOS garde com.hopetsit.app."))

story.append(Spacer(1, 8))
story.append(HRFlowable(width="100%", color=HexColor("#e5e7eb")))
story.append(Paragraph("Genere automatiquement - HoPetSit / CARDELLI HERMANOS LIMITED", SUB))

OUT.parent.mkdir(parents=True, exist_ok=True)
SimpleDocTemplate(str(OUT), pagesize=A4,
                  leftMargin=18 * mm, rightMargin=18 * mm,
                  topMargin=16 * mm, bottomMargin=16 * mm).build(story)
print("PDF iOS genere :", OUT, "(", OUT.stat().st_size // 1024, "KB )")

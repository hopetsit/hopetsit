# -*- coding: utf-8 -*-
"""Videographer guide (ENGLISH) — HoPetSit v23.1.497. Two videos:
   (1) Presentation/marketing video, (2) Google Play submission video.
   Output to Downloads."""
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, ListFlowable, ListItem
from reportlab.lib.enums import TA_JUSTIFY

OUT = "C:/Users/Usuario/Downloads/HoPetSit_Videographer_Guide_v23.1.497_EN.pdf"
doc = SimpleDocTemplate(OUT, pagesize=A4, leftMargin=1.8*cm, rightMargin=1.8*cm,
                        topMargin=1.7*cm, bottomMargin=1.7*cm, title="HoPetSit - Videographer Guide (EN)")
s = getSampleStyleSheet()
H1 = ParagraphStyle("H1", parent=s["Heading1"], fontSize=21, textColor=colors.HexColor("#F0562B"), spaceAfter=4)
SUB = ParagraphStyle("SUB", parent=s["BodyText"], fontSize=10.5, textColor=colors.HexColor("#666666"), spaceAfter=12)
H2 = ParagraphStyle("H2", parent=s["Heading2"], fontSize=14, textColor=colors.HexColor("#1F1D1B"), spaceBefore=13, spaceAfter=6)
H3 = ParagraphStyle("H3", parent=s["Heading3"], fontSize=12, textColor=colors.HexColor("#F0562B"), spaceBefore=8, spaceAfter=4)
P = ParagraphStyle("P", parent=s["BodyText"], fontSize=10.5, leading=15, alignment=TA_JUSTIFY)
B = ParagraphStyle("B", parent=P, leftIndent=10, spaceAfter=2)
NOTE = ParagraphStyle("NOTE", parent=P, textColor=colors.HexColor("#8A4B0A"),
                      backColor=colors.HexColor("#FEF3C7"), borderPadding=6, spaceBefore=4, spaceAfter=6)


def bullets(items):
    return ListFlowable(
        [ListItem(Paragraph(t, B), leftIndent=8, value="-") for t in items],
        bulletType="bullet", start="-", leftIndent=10,
    )


f = []
f.append(Paragraph("HoPetSit - Videographer Guide", H1))
f.append(Paragraph("App version 23.1.497 - the app follows the phone language (6 languages: EN/FR/ES/DE/IT/PT). Brand color: orange #F0562B. Two videos are needed: (1) a presentation / marketing video, and (2) a short video for the Google Play submission / review.", SUB))

f.append(Paragraph("1. What is HoPetSit?", H2))
f.append(Paragraph("A pet sitting and dog walking app that connects pet owners with trusted walkers and sitters. Beyond bookings, it includes a community map (PawMap), pet-friendly places (PawSpot), real-time tracking of the pet during the service (PawFollow), a loyalty program (PawPoints) and subscriptions (PawPremium / PawBoost). Everything works on both the mobile app and the website (same data).", P))

f.append(Paragraph("2. The 3 roles (each has its color)", H2))
f.append(bullets([
    "<b>Owner</b> (orange): posts a request, picks a provider, pays, tracks the pet live.",
    "<b>Walker</b> (green): offers walks (30 min / 1 h / 2 h), receives requests, shares location during the walk.",
    "<b>Sitter</b> (blue): offers boarding (at their place or the owner's), daycare, etc.",
]))

f.append(Paragraph("3. Key features to film", H2))
f.append(bullets([
    "Modern home screen (logo, 4 services, sign-up / log-in buttons).",
    "Guided sign-up (highlighted profile photo, info, location with auto-detect + city search, rates, preview).",
    "Role profiles: photo + status + 'active days' + rating, subscription badges (days left).",
    "Provider search + listings (premium per-pet cards).",
    "Booking + secure payment.",
    "Chat in bubbles + Live tracking (map) between owner and provider.",
    "<b>PawMap</b>: animated halos, PawSpot places, reports, and <b>nearby members shown in PINK</b> (pink paw badge, gold crown if Premium).",
    "<b>PawMap action bar</b>: Report / See reports / Tag a spot / See spots (precise center crosshair).",
    "PawPoints (loyalty) + shop (PawPremium / PawBoost / PawFollow / PawSpot).",
]))

# ---- VIDEO 1 ----
f.append(Paragraph("4. VIDEO 1 - Presentation / marketing (60-90 s)", H2))
f.append(Paragraph("Goal: make people want to download the app. Energetic, music, captions. Show the value: trust, real-time tracking, community.", P))
f.append(Paragraph("Suggested shot order", H3))
f.append(bullets([
    "Shot 1 - Hook: orange home screen, HoPetSit logo, the 2x2 grid of 4 services.",
    "Shot 2 - Sign-up: quickly go through a walker (green) or sitter (blue) sign-up - show the highlighted profile photo + location auto-detect.",
    "Shot 3 - Profile: header (photo + name + status + 'active days' + rating) + subscription badges.",
    "Shot 4 - Owner side: post a request, browse providers, open a listing.",
    "Shot 5 - Booking + payment (show the confirmation).",
    "Shot 6 - Chat: message bubbles, Translate button, then 'Live tracking'.",
    "Shot 7 - THE highlight: real-time tracking on the map (2 phones - see note below).",
    "Shot 8 - PawMap: pan the map, show a PawSpot, a report, and the PINK members around.",
    "Shot 9 - PawPoints + shop (subscriptions) to close on the added value.",
    "Shot 10 (bonus) - The WEBSITE: home + dashboard + PawMap (same data as the app) to show multi-platform.",
]))

# ---- VIDEO 2 ----
f.append(Paragraph("5. VIDEO 2 - Google Play submission / review (15-30 s)", H2))
f.append(Paragraph("Goal: a clear, honest screen recording for the Google Play console (app review / closed-to-production access). Google reviewers must see the CORE function actually working - no marketing fluff, no fast cuts. A plain narrated walkthrough is best.", P))
f.append(Paragraph("What Google wants to see", H3))
f.append(bullets([
    "A real account logging in (owner) on a real device or emulator.",
    "The core loop end to end: search a provider OR post a request -> open a listing -> book -> pay (test/sandbox) -> confirmation.",
    "If you advertise location features: show the LIVE TRACKING with the in-app permission prompt being accepted (Google checks that background/location usage matches the declaration).",
    "Show that data is the user's own and that sensitive actions ask for confirmation.",
    "Keep it ONE continuous take if possible, screen-recorded at the phone's native resolution, portrait.",
]))
f.append(Paragraph("Tips for the review video", H3))
f.append(bullets([
    "No music needed; a calm voice-over (or on-screen captions) describing each step helps the reviewer.",
    "Use a demo account WITHOUT real personal data.",
    "Avoid showing payment card numbers; use the sandbox / test flow.",
    "Mention the app name 'HoPetSit' and the version 23.1.497 at the start.",
    "If location/background is used, the video MUST show the prominent in-app disclosure + the system permission dialog (mandatory for Play approval).",
]))

f.append(Paragraph("6. Practical tips (both videos)", H2))
f.append(bullets([
    "Use the LATEST build: HoPetSit_v23.1.497.apk (Android) / the .aab for the Play Store / iOS build 23.1.497.",
    "For live tracking and pink members, prepare 2 phones (2 accounts) with an ACTIVE subscription (PawSpot/PawPremium) + a paid service.",
    "Light mode recommended for readability; a short dark-mode shot is a nice bonus (the app follows the phone theme).",
    "Enable location and notifications on the filming phones.",
    "Native screen recording = best quality (don't film the screen with a camera).",
    "The website (showcase + app download) can be used as an intro/outro shot.",
]))

f.append(Spacer(1, 0.2*cm))
f.append(Paragraph("Note: some actions (real payment, live tracking, pink members on the map) require an account and an ACTIVE subscription. Ask the team to prepare 2 SUBSCRIBED demo accounts before filming.", NOTE))

doc.build(f)
print("OK", OUT)

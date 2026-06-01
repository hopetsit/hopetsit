"""v23.1.180 - Add missing notification templates in 6 backend locale files.

Templates added: friend_request_received, live_tracking_request_received,
live_tracking_accepted, live_tracking_refused, family_member_added.
Without these templates, sendNotification skipped the notifs entirely
('template missing' warning) - explaining Daniel's "notifications arrive
en retard" (they never arrived in real-time via socket or push).
"""
import json
from pathlib import Path

LOCALES_DIR = Path(__file__).parent / "backend" / "src" / "locales"

# Use double-quoted strings only to avoid bash heredoc issues; use unicode
# escapes for apostrophes / quotes where needed.
EMAIL_BTN = (
    '<p><a href="{{emailLink}}" style="display:inline-block;padding:12px 24px;'
    'background:#EF4324;color:#FFFFFF;text-decoration:none;border-radius:8px;'
    'font-weight:700;font-family:sans-serif;">{btn}</a></p>'
)

TEMPLATES = {
    "fr": {
        "friend_request_received": {
            "title": "Demande d’ami reçue",
            "body": "Quelqu’un veut t’ajouter comme ami sur HoPetSit. Ouvre l’app pour accepter ou refuser.",
            "emailSubject": "Demande d’ami — HoPetSit",
            "emailBody": "<p>Tu as reçu une nouvelle demande d’ami sur HoPetSit. Ouvre l’app pour répondre.</p>" + EMAIL_BTN.format(btn="Voir la demande"),
        },
        "live_tracking_request_received": {
            "title": "Demande de suivi en direct",
            "body": "Une demande de suivi de position en temps réel vient d’arriver dans ton chat.",
            "emailSubject": "Demande de suivi en direct — HoPetSit",
            "emailBody": "<p>Une demande de suivi en direct a été envoyée dans ton chat. Ouvre l’app pour accepter ou refuser.</p>" + EMAIL_BTN.format(btn="Voir la demande"),
        },
        "live_tracking_accepted": {
            "title": "Suivi en direct accepté",
            "body": "Ta demande de suivi en direct a été acceptée. Tu peux maintenant voir la position sur la PawMap.",
            "emailSubject": "Suivi en direct accepté — HoPetSit",
            "emailBody": "<p>Ta demande de suivi en direct a été acceptée. Ouvre la PawMap pour voir la position en temps réel.</p>",
        },
        "live_tracking_refused": {
            "title": "Suivi en direct refusé",
            "body": "Ta demande de suivi en direct a été refusée.",
            "emailSubject": "Suivi en direct refusé — HoPetSit",
            "emailBody": "<p>Ta demande de suivi en direct a été refusée.</p>",
        },
        "family_member_added": {
            "title": "Ajouté à une famille PawFollow",
            "body": "Tu fais maintenant partie d’une famille PawFollow. Vous pouvez vous suivre en direct sur la PawMap.",
            "emailSubject": "Bienvenue dans la famille PawFollow — HoPetSit",
            "emailBody": "<p>Tu as été ajouté à une famille PawFollow. Tous les membres peuvent maintenant se suivre en direct sur la PawMap.</p>",
        },
    },
    "en": {
        "friend_request_received": {
            "title": "Friend request received",
            "body": "Someone wants to add you as a friend on HoPetSit. Open the app to accept or decline.",
            "emailSubject": "Friend request — HoPetSit",
            "emailBody": "<p>You received a new friend request on HoPetSit. Open the app to respond.</p>" + EMAIL_BTN.format(btn="View request"),
        },
        "live_tracking_request_received": {
            "title": "Live tracking request",
            "body": "A live position tracking request just landed in your chat.",
            "emailSubject": "Live tracking request — HoPetSit",
            "emailBody": "<p>A live tracking request was sent to your chat. Open the app to accept or decline.</p>" + EMAIL_BTN.format(btn="View request"),
        },
        "live_tracking_accepted": {
            "title": "Live tracking accepted",
            "body": "Your live tracking request was accepted. You can now see the position on PawMap.",
            "emailSubject": "Live tracking accepted — HoPetSit",
            "emailBody": "<p>Your live tracking request was accepted. Open PawMap to see the live position.</p>",
        },
        "live_tracking_refused": {
            "title": "Live tracking declined",
            "body": "Your live tracking request was declined.",
            "emailSubject": "Live tracking declined — HoPetSit",
            "emailBody": "<p>Your live tracking request was declined.</p>",
        },
        "family_member_added": {
            "title": "Added to a PawFollow family",
            "body": "You are now part of a PawFollow family. Members can track each other live on PawMap.",
            "emailSubject": "Welcome to the PawFollow family — HoPetSit",
            "emailBody": "<p>You have been added to a PawFollow family. All members can now track each other live on PawMap.</p>",
        },
    },
    "es": {
        "friend_request_received": {
            "title": "Solicitud de amistad recibida",
            "body": "Alguien quiere añadirte como amigo en HoPetSit. Abre la app para aceptar o rechazar.",
            "emailSubject": "Solicitud de amistad — HoPetSit",
            "emailBody": "<p>Recibiste una nueva solicitud de amistad en HoPetSit. Abre la app para responder.</p>" + EMAIL_BTN.format(btn="Ver solicitud"),
        },
        "live_tracking_request_received": {
            "title": "Solicitud de seguimiento en vivo",
            "body": "Una solicitud de seguimiento de posición en vivo acaba de llegar a tu chat.",
            "emailSubject": "Solicitud de seguimiento — HoPetSit",
            "emailBody": "<p>Una solicitud de seguimiento en vivo se envió a tu chat. Abre la app para aceptar o rechazar.</p>" + EMAIL_BTN.format(btn="Ver solicitud"),
        },
        "live_tracking_accepted": {
            "title": "Seguimiento en vivo aceptado",
            "body": "Tu solicitud de seguimiento en vivo fue aceptada. Puedes ver la posición en PawMap.",
            "emailSubject": "Seguimiento aceptado — HoPetSit",
            "emailBody": "<p>Tu solicitud de seguimiento en vivo fue aceptada. Abre PawMap para ver la posición en directo.</p>",
        },
        "live_tracking_refused": {
            "title": "Seguimiento en vivo rechazado",
            "body": "Tu solicitud de seguimiento en vivo fue rechazada.",
            "emailSubject": "Seguimiento rechazado — HoPetSit",
            "emailBody": "<p>Tu solicitud de seguimiento en vivo fue rechazada.</p>",
        },
        "family_member_added": {
            "title": "Añadido a una familia PawFollow",
            "body": "Ahora formas parte de una familia PawFollow. Los miembros pueden seguirse en vivo en PawMap.",
            "emailSubject": "Bienvenido a la familia PawFollow — HoPetSit",
            "emailBody": "<p>Has sido añadido a una familia PawFollow. Todos los miembros pueden seguirse en vivo en PawMap.</p>",
        },
    },
    "de": {
        "friend_request_received": {
            "title": "Freundschaftsanfrage erhalten",
            "body": "Jemand möchte dich als Freund auf HoPetSit hinzufügen. Öffne die App, um anzunehmen oder abzulehnen.",
            "emailSubject": "Freundschaftsanfrage — HoPetSit",
            "emailBody": "<p>Du hast eine neue Freundschaftsanfrage auf HoPetSit erhalten. Öffne die App, um zu antworten.</p>" + EMAIL_BTN.format(btn="Anfrage ansehen"),
        },
        "live_tracking_request_received": {
            "title": "Live-Tracking-Anfrage",
            "body": "Eine Live-Tracking-Anfrage ist gerade in deinem Chat eingegangen.",
            "emailSubject": "Live-Tracking-Anfrage — HoPetSit",
            "emailBody": "<p>Eine Live-Tracking-Anfrage wurde an deinen Chat gesendet. Öffne die App, um anzunehmen oder abzulehnen.</p>",
        },
        "live_tracking_accepted": {
            "title": "Live-Tracking angenommen",
            "body": "Deine Live-Tracking-Anfrage wurde angenommen. Du kannst die Position jetzt auf der PawMap sehen.",
            "emailSubject": "Live-Tracking angenommen — HoPetSit",
            "emailBody": "<p>Deine Live-Tracking-Anfrage wurde angenommen. Öffne die PawMap, um die Position live zu sehen.</p>",
        },
        "live_tracking_refused": {
            "title": "Live-Tracking abgelehnt",
            "body": "Deine Live-Tracking-Anfrage wurde abgelehnt.",
            "emailSubject": "Live-Tracking abgelehnt — HoPetSit",
            "emailBody": "<p>Deine Live-Tracking-Anfrage wurde abgelehnt.</p>",
        },
        "family_member_added": {
            "title": "Zur PawFollow-Familie hinzugefügt",
            "body": "Du bist jetzt Teil einer PawFollow-Familie. Mitglieder können sich live auf der PawMap verfolgen.",
            "emailSubject": "Willkommen in der PawFollow-Familie — HoPetSit",
            "emailBody": "<p>Du wurdest zu einer PawFollow-Familie hinzugefügt. Alle Mitglieder können sich jetzt live auf der PawMap verfolgen.</p>",
        },
    },
    "it": {
        "friend_request_received": {
            "title": "Richiesta di amicizia ricevuta",
            "body": "Qualcuno vuole aggiungerti come amico su HoPetSit. Apri l’app per accettare o rifiutare.",
            "emailSubject": "Richiesta di amicizia — HoPetSit",
            "emailBody": "<p>Hai ricevuto una nuova richiesta di amicizia su HoPetSit. Apri l’app per rispondere.</p>" + EMAIL_BTN.format(btn="Vedi richiesta"),
        },
        "live_tracking_request_received": {
            "title": "Richiesta di tracciamento live",
            "body": "Una richiesta di tracciamento della posizione in tempo reale e appena arrivata nella tua chat.",
            "emailSubject": "Richiesta di tracciamento — HoPetSit",
            "emailBody": "<p>Una richiesta di tracciamento live e stata inviata alla tua chat. Apri l’app per accettare o rifiutare.</p>",
        },
        "live_tracking_accepted": {
            "title": "Tracciamento live accettato",
            "body": "La tua richiesta di tracciamento live e stata accettata. Puoi vedere la posizione su PawMap.",
            "emailSubject": "Tracciamento accettato — HoPetSit",
            "emailBody": "<p>La tua richiesta di tracciamento live e stata accettata. Apri PawMap per vedere la posizione in diretta.</p>",
        },
        "live_tracking_refused": {
            "title": "Tracciamento live rifiutato",
            "body": "La tua richiesta di tracciamento live e stata rifiutata.",
            "emailSubject": "Tracciamento rifiutato — HoPetSit",
            "emailBody": "<p>La tua richiesta di tracciamento live e stata rifiutata.</p>",
        },
        "family_member_added": {
            "title": "Aggiunto a una famiglia PawFollow",
            "body": "Ora fai parte di una famiglia PawFollow. I membri possono seguirsi in diretta su PawMap.",
            "emailSubject": "Benvenuto nella famiglia PawFollow — HoPetSit",
            "emailBody": "<p>Sei stato aggiunto a una famiglia PawFollow. Tutti i membri possono ora seguirsi in diretta su PawMap.</p>",
        },
    },
    "pt": {
        "friend_request_received": {
            "title": "Pedido de amizade recebido",
            "body": "Alguém quer adicionar-te como amigo no HoPetSit. Abre a app para aceitar ou recusar.",
            "emailSubject": "Pedido de amizade — HoPetSit",
            "emailBody": "<p>Recebeste um novo pedido de amizade no HoPetSit. Abre a app para responder.</p>" + EMAIL_BTN.format(btn="Ver pedido"),
        },
        "live_tracking_request_received": {
            "title": "Pedido de rastreamento ao vivo",
            "body": "Um pedido de rastreamento de posição em tempo real acabou de chegar ao teu chat.",
            "emailSubject": "Pedido de rastreamento — HoPetSit",
            "emailBody": "<p>Um pedido de rastreamento ao vivo foi enviado para o teu chat. Abre a app para aceitar ou recusar.</p>",
        },
        "live_tracking_accepted": {
            "title": "Rastreamento ao vivo aceite",
            "body": "O teu pedido de rastreamento ao vivo foi aceite. Podes ver a posição no PawMap.",
            "emailSubject": "Rastreamento aceite — HoPetSit",
            "emailBody": "<p>O teu pedido de rastreamento ao vivo foi aceite. Abre o PawMap para veres a posição ao vivo.</p>",
        },
        "live_tracking_refused": {
            "title": "Rastreamento ao vivo recusado",
            "body": "O teu pedido de rastreamento ao vivo foi recusado.",
            "emailSubject": "Rastreamento recusado — HoPetSit",
            "emailBody": "<p>O teu pedido de rastreamento ao vivo foi recusado.</p>",
        },
        "family_member_added": {
            "title": "Adicionado a uma família PawFollow",
            "body": "Agora fazes parte de uma família PawFollow. Os membros podem seguir-se ao vivo no PawMap.",
            "emailSubject": "Bem-vindo à família PawFollow — HoPetSit",
            "emailBody": "<p>Foste adicionado a uma família PawFollow. Todos os membros podem agora seguir-se ao vivo no PawMap.</p>",
        },
    },
}


def main():
    for lang, templates in TEMPLATES.items():
        p = LOCALES_DIR / lang / "notifications.json"
        data = json.loads(p.read_text(encoding="utf-8"))
        added = 0
        skipped = 0
        for key, val in templates.items():
            if key in data:
                skipped += 1
                continue
            data[key] = val
            added += 1
        p.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
        print(f"  [{lang}] +{added} templates (skipped {skipped})")
    print("DONE")


if __name__ == "__main__":
    main()

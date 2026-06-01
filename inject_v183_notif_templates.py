import json
import os

BASE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "backend", "src", "locales")

TEMPLATES = {
    "fr": {
        "family_invitation_received": {
            "title": "Invitation Famille PawFollow",
            "body": "Tu as recu une invitation a rejoindre une famille PawFollow. Ouvre l app pour accepter ou refuser.",
            "emailSubject": "Invitation Famille - HoPetSit",
            "emailBody": "<p>Tu as recu une invitation a rejoindre une famille PawFollow. Ouvre l app HoPetSit pour repondre.</p>"
        },
        "family_invitation_accepted": {
            "title": "Invitation acceptee",
            "body": "Un membre vient d accepter ton invitation Famille PawFollow.",
            "emailSubject": "Invitation acceptee - HoPetSit",
            "emailBody": "<p>Un membre vient d accepter ton invitation Famille PawFollow. Tu peux maintenant le suivre en direct sur la PawMap.</p>"
        },
        "family_invitation_refused": {
            "title": "Invitation refusee",
            "body": "Un membre a refuse ton invitation Famille PawFollow. Une place est de nouveau disponible.",
            "emailSubject": "Invitation refusee - HoPetSit",
            "emailBody": "<p>Un membre a refuse ton invitation Famille PawFollow. Une place est de nouveau disponible dans ton plan Famille.</p>"
        }
    },
    "en": {
        "family_invitation_received": {
            "title": "PawFollow Family invitation",
            "body": "You have received an invitation to join a PawFollow family. Open the app to accept or refuse.",
            "emailSubject": "Family invitation - HoPetSit",
            "emailBody": "<p>You have received an invitation to join a PawFollow family. Open the HoPetSit app to respond.</p>"
        },
        "family_invitation_accepted": {
            "title": "Invitation accepted",
            "body": "A member just accepted your PawFollow Family invitation.",
            "emailSubject": "Invitation accepted - HoPetSit",
            "emailBody": "<p>A member just accepted your PawFollow Family invitation. You can now track them live on the PawMap.</p>"
        },
        "family_invitation_refused": {
            "title": "Invitation refused",
            "body": "A member refused your PawFollow Family invitation. A slot is available again.",
            "emailSubject": "Invitation refused - HoPetSit",
            "emailBody": "<p>A member refused your PawFollow Family invitation. A slot is available again in your Family plan.</p>"
        }
    },
    "es": {
        "family_invitation_received": {
            "title": "Invitacion Familia PawFollow",
            "body": "Has recibido una invitacion para unirte a una familia PawFollow. Abre la app para aceptar o rechazar.",
            "emailSubject": "Invitacion Familia - HoPetSit",
            "emailBody": "<p>Has recibido una invitacion para unirte a una familia PawFollow. Abre la app HoPetSit para responder.</p>"
        },
        "family_invitation_accepted": {
            "title": "Invitacion aceptada",
            "body": "Un miembro acaba de aceptar tu invitacion Familia PawFollow.",
            "emailSubject": "Invitacion aceptada - HoPetSit",
            "emailBody": "<p>Un miembro acaba de aceptar tu invitacion Familia PawFollow. Ahora puedes seguirlo en vivo en la PawMap.</p>"
        },
        "family_invitation_refused": {
            "title": "Invitacion rechazada",
            "body": "Un miembro rechazo tu invitacion Familia PawFollow. Una plaza esta disponible nuevamente.",
            "emailSubject": "Invitacion rechazada - HoPetSit",
            "emailBody": "<p>Un miembro rechazo tu invitacion Familia PawFollow. Una plaza esta disponible nuevamente en tu plan Familia.</p>"
        }
    },
    "de": {
        "family_invitation_received": {
            "title": "PawFollow Familieneinladung",
            "body": "Du hast eine Einladung erhalten, einer PawFollow-Familie beizutreten. Oeffne die App, um anzunehmen oder abzulehnen.",
            "emailSubject": "Familieneinladung - HoPetSit",
            "emailBody": "<p>Du hast eine Einladung erhalten, einer PawFollow-Familie beizutreten. Oeffne die HoPetSit-App, um zu antworten.</p>"
        },
        "family_invitation_accepted": {
            "title": "Einladung angenommen",
            "body": "Ein Mitglied hat gerade deine PawFollow-Familieneinladung angenommen.",
            "emailSubject": "Einladung angenommen - HoPetSit",
            "emailBody": "<p>Ein Mitglied hat gerade deine PawFollow-Familieneinladung angenommen. Du kannst es jetzt live auf der PawMap verfolgen.</p>"
        },
        "family_invitation_refused": {
            "title": "Einladung abgelehnt",
            "body": "Ein Mitglied hat deine PawFollow-Familieneinladung abgelehnt. Ein Platz ist wieder verfuegbar.",
            "emailSubject": "Einladung abgelehnt - HoPetSit",
            "emailBody": "<p>Ein Mitglied hat deine PawFollow-Familieneinladung abgelehnt. Ein Platz ist wieder in deinem Familienplan verfuegbar.</p>"
        }
    },
    "it": {
        "family_invitation_received": {
            "title": "Invito Famiglia PawFollow",
            "body": "Hai ricevuto un invito a unirti a una famiglia PawFollow. Apri l app per accettare o rifiutare.",
            "emailSubject": "Invito Famiglia - HoPetSit",
            "emailBody": "<p>Hai ricevuto un invito a unirti a una famiglia PawFollow. Apri l app HoPetSit per rispondere.</p>"
        },
        "family_invitation_accepted": {
            "title": "Invito accettato",
            "body": "Un membro ha appena accettato il tuo invito Famiglia PawFollow.",
            "emailSubject": "Invito accettato - HoPetSit",
            "emailBody": "<p>Un membro ha appena accettato il tuo invito Famiglia PawFollow. Ora puoi seguirlo in diretta sulla PawMap.</p>"
        },
        "family_invitation_refused": {
            "title": "Invito rifiutato",
            "body": "Un membro ha rifiutato il tuo invito Famiglia PawFollow. Un posto e nuovamente disponibile.",
            "emailSubject": "Invito rifiutato - HoPetSit",
            "emailBody": "<p>Un membro ha rifiutato il tuo invito Famiglia PawFollow. Un posto e nuovamente disponibile nel tuo piano Famiglia.</p>"
        }
    },
    "pt": {
        "family_invitation_received": {
            "title": "Convite Familia PawFollow",
            "body": "Recebeste um convite para te juntares a uma familia PawFollow. Abre a app para aceitar ou recusar.",
            "emailSubject": "Convite Familia - HoPetSit",
            "emailBody": "<p>Recebeste um convite para te juntares a uma familia PawFollow. Abre a app HoPetSit para responder.</p>"
        },
        "family_invitation_accepted": {
            "title": "Convite aceite",
            "body": "Um membro aceitou o teu convite Familia PawFollow.",
            "emailSubject": "Convite aceite - HoPetSit",
            "emailBody": "<p>Um membro aceitou o teu convite Familia PawFollow. Agora podes segui-lo ao vivo na PawMap.</p>"
        },
        "family_invitation_refused": {
            "title": "Convite recusado",
            "body": "Um membro recusou o teu convite Familia PawFollow. Uma vaga esta novamente disponivel.",
            "emailSubject": "Convite recusado - HoPetSit",
            "emailBody": "<p>Um membro recusou o teu convite Familia PawFollow. Uma vaga esta novamente disponivel no teu plano Familia.</p>"
        }
    }
}

for lang, by_key in TEMPLATES.items():
    p = os.path.join(BASE, lang, "notifications.json")
    with open(p, encoding="utf-8") as f:
        data = json.load(f)
    added = 0
    for k, v in by_key.items():
        if k not in data:
            data[k] = v
            added += 1
    with open(p, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    print(f"  [{lang}] +{added} templates")
print("DONE")

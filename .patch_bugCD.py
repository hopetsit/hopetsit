import sys, subprocess

REPO = '/sessions/relaxed-jolly-pasteur/mnt/HopeTSIT_FINAL_FIXED/HopeTSIT_FINAL'

def head(path):
    return subprocess.check_output(
        ['git', 'show', f'HEAD:{path}'], cwd=REPO, encoding='utf-8'
    )

def write(path, content):
    with open(f'{REPO}/{path}', 'w') as f:
        f.write(content)

# ============ BUG C: extend _titleMap in notification_card.dart ============
nc_path = 'frontend/lib/widgets/notification_card.dart'
nc = head(nc_path)

old_title_map = """  static const _titleMap = {
    'new request': 'notif_title_new_request',
    'new application': 'notif_title_new_application',
    'application accepted': 'notif_title_application_accepted',
    'application rejected': 'notif_title_application_rejected',
    'new message': 'notif_title_new_message',
    'new like': 'notif_title_new_like',
    'new comment': 'notif_title_new_comment',
    'booking confirmed': 'notif_title_booking_confirmed',
    'booking cancelled': 'notif_title_booking_cancelled',
    'payment received': 'notif_title_payment_received',
  };"""

new_title_map = """  static const _titleMap = {
    'new request': 'notif_title_new_request',
    'new application': 'notif_title_new_application',
    'application accepted': 'notif_title_application_accepted',
    'application rejected': 'notif_title_application_rejected',
    'new message': 'notif_title_new_message',
    'new like': 'notif_title_new_like',
    'new comment': 'notif_title_new_comment',
    'booking confirmed': 'notif_title_booking_confirmed',
    'booking cancelled': 'notif_title_booking_cancelled',
    'payment received': 'notif_title_payment_received',
    // Session v16.3b - added entries for booking_* notification types coming
    // from the backend (bookingController createNotificationSafe strings).
    'new booking request': 'notif_title_booking_new',
    'booking accepted': 'notif_title_booking_accepted',
    'booking rejected': 'notif_title_booking_rejected',
    'booking paid': 'notif_title_booking_paid',
    'booking request cancelled': 'notif_title_booking_cancelled',
  };"""

if old_title_map not in nc:
    sys.exit('title map pattern not found')
nc = nc.replace(old_title_map, new_title_map, 1)

# Extend body map too
old_body_map = """  static const _bodyMap = {
    'a sitter sent you a request.': 'notif_body_sitter_sent_request',
    'an owner sent you a request.': 'notif_body_owner_sent_request',
    'your application was accepted.': 'notif_body_application_accepted',
    'your application was rejected.': 'notif_body_application_rejected',
    'you have a new message.': 'notif_body_new_message',
    'someone liked your post.': 'notif_body_post_liked',
    'someone commented on your post.': 'notif_body_post_commented',
  };"""

new_body_map = """  static const _bodyMap = {
    'a sitter sent you a request.': 'notif_body_sitter_sent_request',
    'an owner sent you a request.': 'notif_body_owner_sent_request',
    'your application was accepted.': 'notif_body_application_accepted',
    'your application was rejected.': 'notif_body_application_rejected',
    'you have a new message.': 'notif_body_new_message',
    'someone liked your post.': 'notif_body_post_liked',
    'someone commented on your post.': 'notif_body_post_commented',
    // Session v16.3b.
    'you received a new booking request.': 'notif_body_booking_new',
    'your booking request was accepted.': 'notif_body_booking_accepted',
    'your booking request was rejected.': 'notif_body_booking_rejected',
    'a pet-care provider sent you a request.': 'notif_body_provider_sent_request',
  };"""

if old_body_map not in nc:
    sys.exit('body map pattern not found')
nc = nc.replace(old_body_map, new_body_map, 1)
write(nc_path, nc)
print(f'notification_card.dart: OK ({len(nc)} bytes)')

# ============ BUG C: add translation keys to all 6 locale files ============
LOCALES = {
    'fr': {
        'notif_title_booking_new': 'Nouvelle demande de réservation',
        'notif_title_booking_accepted': 'Réservation acceptée',
        'notif_title_booking_rejected': 'Réservation refusée',
        'notif_title_booking_paid': 'Paiement confirmé',
        'notif_body_booking_new': 'Vous avez reçu une nouvelle demande de réservation.',
        'notif_body_booking_accepted': 'Votre demande de réservation a été acceptée.',
        'notif_body_booking_rejected': 'Votre demande de réservation a été refusée.',
        'notif_body_provider_sent_request': 'Un prestataire vous a envoyé une demande.',
    },
    'en': {
        'notif_title_booking_new': 'New booking request',
        'notif_title_booking_accepted': 'Booking accepted',
        'notif_title_booking_rejected': 'Booking rejected',
        'notif_title_booking_paid': 'Payment received',
        'notif_body_booking_new': 'You received a new booking request.',
        'notif_body_booking_accepted': 'Your booking request was accepted.',
        'notif_body_booking_rejected': 'Your booking request was rejected.',
        'notif_body_provider_sent_request': 'A pet-care provider sent you a request.',
    },
    'es': {
        'notif_title_booking_new': 'Nueva solicitud de reserva',
        'notif_title_booking_accepted': 'Reserva aceptada',
        'notif_title_booking_rejected': 'Reserva rechazada',
        'notif_title_booking_paid': 'Pago recibido',
        'notif_body_booking_new': 'Has recibido una nueva solicitud de reserva.',
        'notif_body_booking_accepted': 'Tu solicitud de reserva fue aceptada.',
        'notif_body_booking_rejected': 'Tu solicitud de reserva fue rechazada.',
        'notif_body_provider_sent_request': 'Un proveedor te ha enviado una solicitud.',
    },
    'it': {
        'notif_title_booking_new': 'Nuova richiesta di prenotazione',
        'notif_title_booking_accepted': 'Prenotazione accettata',
        'notif_title_booking_rejected': 'Prenotazione rifiutata',
        'notif_title_booking_paid': 'Pagamento ricevuto',
        'notif_body_booking_new': 'Hai ricevuto una nuova richiesta di prenotazione.',
        'notif_body_booking_accepted': 'La tua richiesta di prenotazione è stata accettata.',
        'notif_body_booking_rejected': 'La tua richiesta di prenotazione è stata rifiutata.',
        'notif_body_provider_sent_request': 'Un fornitore ti ha inviato una richiesta.',
    },
    'de': {
        'notif_title_booking_new': 'Neue Buchungsanfrage',
        'notif_title_booking_accepted': 'Buchung angenommen',
        'notif_title_booking_rejected': 'Buchung abgelehnt',
        'notif_title_booking_paid': 'Zahlung erhalten',
        'notif_body_booking_new': 'Sie haben eine neue Buchungsanfrage erhalten.',
        'notif_body_booking_accepted': 'Ihre Buchungsanfrage wurde angenommen.',
        'notif_body_booking_rejected': 'Ihre Buchungsanfrage wurde abgelehnt.',
        'notif_body_provider_sent_request': 'Ein Dienstleister hat Ihnen eine Anfrage gesendet.',
    },
    'pt': {
        'notif_title_booking_new': 'Novo pedido de reserva',
        'notif_title_booking_accepted': 'Reserva aceita',
        'notif_title_booking_rejected': 'Reserva recusada',
        'notif_title_booking_paid': 'Pagamento recebido',
        'notif_body_booking_new': 'Você recebeu um novo pedido de reserva.',
        'notif_body_booking_accepted': 'Seu pedido de reserva foi aceito.',
        'notif_body_booking_rejected': 'Seu pedido de reserva foi rejeitado.',
        'notif_body_provider_sent_request': 'Um prestador de serviços enviou um pedido.',
    },
}

for locale, keys in LOCALES.items():
    locale_path = f'frontend/lib/localization/translations/{locale}.dart'
    content = head(locale_path)
    # Insert new keys after the last existing notif_body_* line.
    # Find the last notif_body_post_commented line and append after it.
    anchor = "'notif_body_post_commented':"
    if anchor not in content:
        sys.exit(f'{locale}: anchor not found')
    # Split at anchor
    idx = content.index(anchor)
    # Find end of that line (next newline)
    line_end = content.index('\n', idx)
    # Build insertion block
    insertion = ''
    for k, v in keys.items():
        escaped = v.replace("'", "\\'")
        insertion += f"\n      '{k}': '{escaped}',"
    new_content = content[:line_end] + insertion + content[line_end:]
    write(locale_path, new_content)
    print(f'{locale}.dart: +{len(keys)} keys')

# ============ BUG D: notifications_screen.dart — add walker role routing ============
ns_path = 'frontend/lib/views/notifications/notifications_screen.dart'
ns = head(ns_path)

# Find the sitter-role block and mirror it for walker (walkers receive the
# same booking_new/booking_accepted notification types as sitters in our
# current model). Also handle owner receiving booking_accepted/rejected/paid
# by opening the BookingAgreementScreen via bookingId fetch.
old_sitter_block = """    // Sitter-specific routing: map notification types to booking cards.
    if (role == 'sitter') {
      final bookingId = _dataString(data, 'bookingId');

      if (bookingId != null && bookingId.isNotEmpty) {
        if (type == 'booking_new') {
          Get.to(
            () => NotificationSitterNewRequestCardViewScreen(
              bookingId: bookingId,
            ),
          );
          return;
        }

        if (type.contains('application_accepted')) {
          Get.to(
            () =>
                NotificationSitterAcceptedCardViewScreen(bookingId: bookingId),
          );
          return;
        }
      }
    }"""

new_provider_block = """    // Session v16.3b - route for BOTH sitter AND walker (both are providers
    // and receive the same booking_new notification when an owner books them
    // directly). Using the sitter screens since they are role-agnostic at
    // the data level.
    if (role == 'sitter' || role == 'walker') {
      final bookingId = _dataString(data, 'bookingId');

      if (bookingId != null && bookingId.isNotEmpty) {
        if (type == 'booking_new') {
          Get.to(
            () => NotificationSitterNewRequestCardViewScreen(
              bookingId: bookingId,
            ),
          );
          return;
        }

        if (type.contains('application_accepted')) {
          Get.to(
            () =>
                NotificationSitterAcceptedCardViewScreen(bookingId: bookingId),
          );
          return;
        }
      }
    }

    // Session v16.3b - owner gets notified on booking_accepted / rejected /
    // paid. Tap should open the booking detail so owner can agree & pay.
    if (role == 'owner' &&
        (type == 'booking_accepted' ||
            type == 'booking_rejected' ||
            type == 'booking_paid')) {
      final bookingId = _dataString(data, 'bookingId');
      if (bookingId != null && bookingId.isNotEmpty) {
        Get.toNamed('/reservations');
        return;
      }
    }"""

if old_sitter_block not in ns:
    sys.exit('sitter routing block not found')
ns = ns.replace(old_sitter_block, new_provider_block, 1)
write(ns_path, ns)
print(f'notifications_screen.dart: OK ({len(ns)} bytes)')

print('\nALL BUG C + D EDITS APPLIED')

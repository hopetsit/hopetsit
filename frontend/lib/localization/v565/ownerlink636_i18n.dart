// 636 (08/11/2026, ordre de Daniel « le proprio doit pouvoir payer du site OU
// de l'app ») — écran de connexion : encart « Pas de mot de passe ? » pour les
// comptes créés par le site (pub) → POST /auth/owner-link, e-mail avec le lien
// signé qui ouvre les candidats dans l'app. Réponse neutre, compte connu ou non.
const Map<String, Map<String, String>> ownerlink636I18n =
    <String, Map<String, String>>{
  'en': <String, String>{
    'ownerlink636_title': 'No password? Get your link by e-mail',
    'ownerlink636_body':
        'Your account was created from the website, without a password. Enter your e-mail: you will receive a link that opens your candidates directly in the app.',
    'ownerlink636_email_hint': 'Your e-mail address',
    'ownerlink636_send': 'Send me my link',
    'ownerlink636_sent':
        'If an owner account exists with this e-mail, the link is on its way. Open the e-mail on this phone.',
    'ownerlink636_too_many': 'Too many requests. Try again in 15 minutes.',
    'ownerlink636_email_invalid': 'Invalid e-mail address.',
  },
  'fr': <String, String>{
    'ownerlink636_title': 'Pas de mot de passe ? Reçois ton lien par e-mail',
    'ownerlink636_body':
        'Ton compte a été créé depuis le site, sans mot de passe. Entre ton e-mail : tu reçois un lien qui ouvre directement tes candidats dans l\'app.',
    'ownerlink636_email_hint': 'Ton adresse e-mail',
    'ownerlink636_send': 'Recevoir mon lien',
    'ownerlink636_sent':
        'Si un compte propriétaire existe avec cet e-mail, le lien est parti. Ouvre l\'e-mail sur ce téléphone.',
    'ownerlink636_too_many': 'Trop d\'envois. Réessaie dans 15 minutes.',
    'ownerlink636_email_invalid': 'Adresse e-mail invalide.',
  },
  'es': <String, String>{
    'ownerlink636_title': '¿Sin contraseña? Recibe tu enlace por e-mail',
    'ownerlink636_body':
        'Tu cuenta se creó desde la web, sin contraseña. Escribe tu e-mail: recibirás un enlace que abre tus candidatos directamente en la app.',
    'ownerlink636_email_hint': 'Tu dirección de e-mail',
    'ownerlink636_send': 'Recibir mi enlace',
    'ownerlink636_sent':
        'Si existe una cuenta de propietario con este e-mail, el enlace ya va en camino. Abre el e-mail en este teléfono.',
    'ownerlink636_too_many': 'Demasiados envíos. Inténtalo de nuevo en 15 minutos.',
    'ownerlink636_email_invalid': 'Dirección de e-mail no válida.',
  },
  'de': <String, String>{
    'ownerlink636_title': 'Kein Passwort? Hol dir deinen Link per E-Mail',
    'ownerlink636_body':
        'Dein Konto wurde über die Website ohne Passwort erstellt. Gib deine E-Mail ein: Du erhältst einen Link, der deine Bewerber direkt in der App öffnet.',
    'ownerlink636_email_hint': 'Deine E-Mail-Adresse',
    'ownerlink636_send': 'Link anfordern',
    'ownerlink636_sent':
        'Falls ein Besitzerkonto mit dieser E-Mail existiert, ist der Link unterwegs. Öffne die E-Mail auf diesem Handy.',
    'ownerlink636_too_many': 'Zu viele Anfragen. Versuche es in 15 Minuten erneut.',
    'ownerlink636_email_invalid': 'Ungültige E-Mail-Adresse.',
  },
  'it': <String, String>{
    'ownerlink636_title': 'Senza password? Ricevi il tuo link via e-mail',
    'ownerlink636_body':
        'Il tuo account è stato creato dal sito, senza password. Inserisci la tua e-mail: riceverai un link che apre i tuoi candidati direttamente nell\'app.',
    'ownerlink636_email_hint': 'Il tuo indirizzo e-mail',
    'ownerlink636_send': 'Ricevi il mio link',
    'ownerlink636_sent':
        'Se esiste un account proprietario con questa e-mail, il link è in arrivo. Apri l\'e-mail su questo telefono.',
    'ownerlink636_too_many': 'Troppi invii. Riprova tra 15 minuti.',
    'ownerlink636_email_invalid': 'Indirizzo e-mail non valido.',
  },
  'pt': <String, String>{
    'ownerlink636_title': 'Sem palavra-passe? Recebe o teu link por e-mail',
    'ownerlink636_body':
        'A tua conta foi criada a partir do site, sem palavra-passe. Introduz o teu e-mail: recebes um link que abre os teus candidatos diretamente na app.',
    'ownerlink636_email_hint': 'O teu endereço de e-mail',
    'ownerlink636_send': 'Receber o meu link',
    'ownerlink636_sent':
        'Se existir uma conta de proprietário com este e-mail, o link já seguiu. Abre o e-mail neste telemóvel.',
    'ownerlink636_too_many': 'Demasiados envios. Tenta de novo dentro de 15 minutos.',
    'ownerlink636_email_invalid': 'Endereço de e-mail inválido.',
  },
  'ko': <String, String>{
    'ownerlink636_title': '비밀번호가 없나요? 이메일로 링크를 받으세요',
    'ownerlink636_body':
        '계정이 웹사이트에서 비밀번호 없이 만들어졌습니다. 이메일을 입력하면 앱에서 지원자를 바로 여는 링크를 받게 됩니다.',
    'ownerlink636_email_hint': '이메일 주소',
    'ownerlink636_send': '링크 받기',
    'ownerlink636_sent':
        '이 이메일로 등록된 보호자 계정이 있다면 링크를 보냈습니다. 이 휴대폰에서 이메일을 열어 주세요.',
    'ownerlink636_too_many': '요청이 너무 많습니다. 15분 후에 다시 시도해 주세요.',
    'ownerlink636_email_invalid': '올바르지 않은 이메일 주소입니다.',
  },
  'ja': <String, String>{
    'ownerlink636_title': 'パスワードがない？メールでリンクを受け取る',
    'ownerlink636_body':
        'あなたのアカウントはウェブサイトからパスワードなしで作成されました。メールアドレスを入力すると、アプリで応募者を直接開くリンクが届きます。',
    'ownerlink636_email_hint': 'メールアドレス',
    'ownerlink636_send': 'リンクを受け取る',
    'ownerlink636_sent':
        'このメールアドレスの飼い主アカウントがあれば、リンクを送信しました。このスマートフォンでメールを開いてください。',
    'ownerlink636_too_many': '送信回数が多すぎます。15分後にもう一度お試しください。',
    'ownerlink636_email_invalid': 'メールアドレスが正しくありません。',
  },
  'pl': <String, String>{
    'ownerlink636_title': 'Nie masz hasła? Odbierz link e-mailem',
    'ownerlink636_body':
        'Twoje konto zostało utworzone na stronie, bez hasła. Wpisz swój e-mail: otrzymasz link, który otworzy Twoich kandydatów bezpośrednio w aplikacji.',
    'ownerlink636_email_hint': 'Twój adres e-mail',
    'ownerlink636_send': 'Wyślij mi link',
    'ownerlink636_sent':
        'Jeśli istnieje konto właściciela z tym e-mailem, link został wysłany. Otwórz e-mail na tym telefonie.',
    'ownerlink636_too_many': 'Zbyt wiele prób. Spróbuj ponownie za 15 minut.',
    'ownerlink636_email_invalid': 'Nieprawidłowy adres e-mail.',
  },
};

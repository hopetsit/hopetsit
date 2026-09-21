// v575 — clés du lot « profils synchronisés » (Daniel, 21/09/2026) :
//   • « dans mon profil j'ai que "nom" et pas "nom et prénom" » → Prénom + Nom ;
//   • « il y a 2 fois "Langue préférée" » → « Langue de l'app » (réglage) vs
//     « Langues parlées » (info visible par les autres membres) ;
//   • aide du champ « À propos de moi » (le minimum de 20 caractères n'était
//     écrit nulle part, la bio semblait refusée) ;
//   • élément « Nom et prénom » de la barre « profil complété à X % ».
//
// Règle du lot : la MÊME clé dans les 9 langues (en fr es de it pt ko ja pl),
// tutoiement en français. Placeholder `{min}` remplacé par `trParams`.
//
// Ce paquet est fusionné par `v565_i18n.dart`.
const Map<String, Map<String, String>> profile575I18n =
    <String, Map<String, String>>{
  'en': <String, String>{
    'label_first_name': 'First name',
    'hint_first_name': 'Your first name',
    'label_last_name': 'Last name',
    'hint_last_name': 'Your last name',
    'error_first_name_required': 'Please enter your first name.',
    'error_last_name_required': 'Please enter your last name.',
    'completion_item_name': 'First and last name',
    'about_helper': 'At least {min} characters so your profile counts as complete.',
    'label_spoken_languages': 'Languages you speak',
    'spoken_languages_empty': 'Choose your languages',
    'spoken_languages_helper':
        'The languages you can talk to other members in. This is not the app display language.',
    'pref_app_language_sub': 'The language HoPetSit is displayed in.',
  },
  'fr': <String, String>{
    'label_first_name': 'Prénom',
    'hint_first_name': 'Ton prénom',
    'label_last_name': 'Nom',
    'hint_last_name': 'Ton nom',
    'error_first_name_required': 'Entre ton prénom.',
    'error_last_name_required': 'Entre ton nom.',
    'completion_item_name': 'Nom et prénom',
    'about_helper': 'Au moins {min} caractères pour que ton profil soit compté comme complet.',
    'label_spoken_languages': 'Langues parlées',
    'spoken_languages_empty': 'Choisis tes langues',
    'spoken_languages_helper':
        "Les langues dans lesquelles tu peux échanger avec les autres membres. Ce n'est pas la langue d'affichage de l'app.",
    'pref_app_language_sub': "La langue dans laquelle HoPetSit s'affiche.",
  },
  'es': <String, String>{
    'label_first_name': 'Nombre',
    'hint_first_name': 'Tu nombre',
    'label_last_name': 'Apellidos',
    'hint_last_name': 'Tus apellidos',
    'error_first_name_required': 'Introduce tu nombre.',
    'error_last_name_required': 'Introduce tus apellidos.',
    'completion_item_name': 'Nombre y apellidos',
    'about_helper': 'Al menos {min} caracteres para que tu perfil cuente como completo.',
    'label_spoken_languages': 'Idiomas que hablas',
    'spoken_languages_empty': 'Elige tus idiomas',
    'spoken_languages_helper':
        'Los idiomas en los que puedes hablar con otros miembros. No es el idioma de la aplicación.',
    'pref_app_language_sub': 'El idioma en el que se muestra HoPetSit.',
  },
  'de': <String, String>{
    'label_first_name': 'Vorname',
    'hint_first_name': 'Dein Vorname',
    'label_last_name': 'Nachname',
    'hint_last_name': 'Dein Nachname',
    'error_first_name_required': 'Bitte gib deinen Vornamen ein.',
    'error_last_name_required': 'Bitte gib deinen Nachnamen ein.',
    'completion_item_name': 'Vor- und Nachname',
    'about_helper': 'Mindestens {min} Zeichen, damit dein Profil als vollständig zählt.',
    'label_spoken_languages': 'Gesprochene Sprachen',
    'spoken_languages_empty': 'Wähle deine Sprachen',
    'spoken_languages_helper':
        'Die Sprachen, in denen du dich mit anderen Mitgliedern austauschen kannst. Nicht die Anzeigesprache der App.',
    'pref_app_language_sub': 'Die Sprache, in der HoPetSit angezeigt wird.',
  },
  'it': <String, String>{
    'label_first_name': 'Nome',
    'hint_first_name': 'Il tuo nome',
    'label_last_name': 'Cognome',
    'hint_last_name': 'Il tuo cognome',
    'error_first_name_required': 'Inserisci il tuo nome.',
    'error_last_name_required': 'Inserisci il tuo cognome.',
    'completion_item_name': 'Nome e cognome',
    'about_helper': 'Almeno {min} caratteri perché il profilo risulti completo.',
    'label_spoken_languages': 'Lingue parlate',
    'spoken_languages_empty': 'Scegli le tue lingue',
    'spoken_languages_helper':
        "Le lingue in cui puoi parlare con gli altri membri. Non è la lingua di visualizzazione dell'app.",
    'pref_app_language_sub': 'La lingua in cui viene visualizzata HoPetSit.',
  },
  'pt': <String, String>{
    'label_first_name': 'Nome próprio',
    'hint_first_name': 'O teu nome próprio',
    'label_last_name': 'Apelido',
    'hint_last_name': 'O teu apelido',
    'error_first_name_required': 'Introduz o teu nome próprio.',
    'error_last_name_required': 'Introduz o teu apelido.',
    'completion_item_name': 'Nome e apelido',
    'about_helper': 'Pelo menos {min} caracteres para o teu perfil contar como completo.',
    'label_spoken_languages': 'Idiomas que falas',
    'spoken_languages_empty': 'Escolhe os teus idiomas',
    'spoken_languages_helper':
        'Os idiomas em que podes falar com os outros membros. Não é o idioma de apresentação da app.',
    'pref_app_language_sub': 'O idioma em que a HoPetSit é apresentada.',
  },
  'ko': <String, String>{
    'label_first_name': '이름',
    'hint_first_name': '이름을 입력하세요',
    'label_last_name': '성',
    'hint_last_name': '성을 입력하세요',
    'error_first_name_required': '이름을 입력해 주세요.',
    'error_last_name_required': '성을 입력해 주세요.',
    'completion_item_name': '성과 이름',
    'about_helper': '프로필이 완성으로 인정되려면 최소 {min}자가 필요합니다.',
    'label_spoken_languages': '구사 가능 언어',
    'spoken_languages_empty': '언어를 선택하세요',
    'spoken_languages_helper': '다른 회원과 대화할 수 있는 언어입니다. 앱 표시 언어와는 다릅니다.',
    'pref_app_language_sub': 'HoPetSit이 표시되는 언어입니다.',
  },
  'ja': <String, String>{
    'label_first_name': '名',
    'hint_first_name': '名を入力してください',
    'label_last_name': '姓',
    'hint_last_name': '姓を入力してください',
    'error_first_name_required': '名を入力してください。',
    'error_last_name_required': '姓を入力してください。',
    'completion_item_name': '姓名',
    'about_helper': 'プロフィールが完成とみなされるには{min}文字以上必要です。',
    'label_spoken_languages': '話せる言語',
    'spoken_languages_empty': '言語を選んでください',
    'spoken_languages_helper': '他のメンバーと話せる言語です。アプリの表示言語とは異なります。',
    'pref_app_language_sub': 'HoPetSit が表示される言語です。',
  },
  'pl': <String, String>{
    'label_first_name': 'Imię',
    'hint_first_name': 'Twoje imię',
    'label_last_name': 'Nazwisko',
    'hint_last_name': 'Twoje nazwisko',
    'error_first_name_required': 'Podaj swoje imię.',
    'error_last_name_required': 'Podaj swoje nazwisko.',
    'completion_item_name': 'Imię i nazwisko',
    'about_helper': 'Co najmniej {min} znaków, aby profil liczył się jako kompletny.',
    'label_spoken_languages': 'Języki, którymi mówisz',
    'spoken_languages_empty': 'Wybierz swoje języki',
    'spoken_languages_helper':
        'Języki, w których możesz rozmawiać z innymi członkami. To nie jest język wyświetlania aplikacji.',
    'pref_app_language_sub': 'Język, w którym wyświetla się HoPetSit.',
  },
};

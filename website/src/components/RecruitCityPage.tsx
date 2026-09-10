import Link from "next/link";
import type { RecruitCity, RecruitLang } from "@/lib/recruit-cities";
import { OWNER_PATH_PREFIX } from "@/lib/recruit-cities";

// v547 — page « devenir pet sitter à <ville> » (composant serveur statique,
// indexable). Copie par langue, détail local injecté pour que chaque page
// soit unique aux yeux de Google.

type Copy = {
  kicker: (c: RecruitCity) => string;
  h1: (c: RecruitCity) => string;
  intro: (c: RecruitCity) => string;
  badges: string[];
  howTitle: string;
  steps: { t: string; p: string }[];
  faqTitle: string;
  faq: (c: RecruitCity) => { q: string; a: string }[];
  ctaTitle: (c: RecruitCity) => string;
  ctaText: (c: RecruitCity) => string;
  ctaBtn: string;
  localTitle: (c: RecruitCity) => string;
  inLanguage: string;
};

const COPY: Record<RecruitLang, Copy> = {
  fr: {
    kicker: (c) => c.region,
    h1: (c) => `Devenir pet sitter à ${c.name} — soyez payé pour aimer les animaux`,
    intro: (c) =>
      `Étudiant, en télétravail, retraité ou simplement passionné ? À ${c.name}, des propriétaires de chiens et de chats cherchent quelqu'un de confiance pour les garder pendant les vacances ou les journées de travail. HoPetSit vous met en relation avec eux : vous fixez vos tarifs, vous choisissez vos services, vous êtes payé en sécurité.`,
    badges: ["💶 Vos tarifs, vos règles", "📅 Vous choisissez vos horaires", "✓ Badge vérifié", "🔒 Zéro impayé"],
    howTitle: "Comment ça marche",
    steps: [
      { t: "Créez votre profil gratuit", p: "Photo, présentation, services proposés (garde à domicile, visites, promenades) et VOS tarifs — c'est vous qui décidez." },
      { t: "Faites vérifier votre identité", p: "5 minutes dans l'app. Le badge ✓ rassure les propriétaires : les profils vérifiés reçoivent beaucoup plus de demandes." },
      { t: "Recevez des demandes et discutez", p: "Les propriétaires de votre quartier vous contactent par chat. Vous acceptez uniquement ce qui vous convient." },
      { t: "Soyez payé en toute sécurité", p: "Le paiement est bloqué dans l'app dès la réservation et versé sur votre compte bancaire une fois le service terminé." },
    ],
    faqTitle: "Questions fréquentes",
    faq: (c) => [
      { q: `Combien peut-on gagner comme pet sitter à ${c.name} ?`, a: `À ${c.name}, les gardes se facturent généralement ${c.dayRate} par jour et les promenades ${c.walkRate}. Avec quelques clients réguliers, un complément de 300 à 600 € par mois est réaliste.` },
      { q: "Faut-il un diplôme ou un statut particulier ?", a: "Aucun diplôme n'est requis pour commencer sur HoPetSit — il faut aimer les animaux, être fiable et avoir 18 ans ou plus. Pour une activité régulière, le statut d'auto-entrepreneur se crée gratuitement en ligne." },
      { q: "L'inscription coûte-t-elle quelque chose ?", a: "Non, l'inscription et le profil sont gratuits. Seule la vérification d'identité (badge ✓, fortement recommandée) coûte 3 €." },
      { q: "Comment le suivi GPS protège-t-il aussi le sitter ?", a: "Pendant une promenade, le suivi PawFollow prouve que le service a bien été rendu, du départ au retour. Transparence pour le propriétaire, protection pour vous." },
    ],
    ctaTitle: (c) => `Les premiers inscrits à ${c.name} prennent les meilleurs clients`,
    ctaText: (c) => `HoPetSit se lance à ${c.name} : peu de concurrence entre sitters, des propriétaires qui arrivent chaque semaine. C'est le meilleur moment pour créer votre profil.`,
    ctaBtn: "Créer mon profil gratuit",
    localTitle: (c) => `Garder des animaux à ${c.name}`,
    inLanguage: "fr",
  },
  en: {
    kicker: (c) => c.region,
    h1: (c) => `Become a pet sitter in ${c.name} — get paid to love animals`,
    intro: (c) =>
      `Student, remote worker, retiree or simply an animal lover? In ${c.name}, dog and cat owners are looking for someone they can trust while they work or travel. HoPetSit connects you with them: you set your rates, you choose your services, you get paid securely.`,
    badges: ["💵 Your rates, your rules", "📅 You choose your hours", "✓ Verified badge", "🔒 Guaranteed payment"],
    howTitle: "How it works",
    steps: [
      { t: "Create your free profile", p: "Photo, bio, services (home sitting, drop-in visits, walks) and YOUR rates — you decide." },
      { t: "Get your identity verified", p: "5 minutes in the app. The ✓ badge reassures owners: verified profiles receive far more requests." },
      { t: "Receive requests and chat", p: "Owners in your neighborhood contact you by chat. You only accept what suits you." },
      { t: "Get paid securely", p: "Payment is held in the app at booking and released to your bank account once the service is done. No unpaid jobs." },
    ],
    faqTitle: "Frequently asked questions",
    faq: (c) => [
      { q: `How much can a pet sitter earn in ${c.name}?`, a: `In ${c.name}, sitting typically pays ${c.dayRate} per day and walks ${c.walkRate}. With a few regular clients, ${c.dayRate.startsWith("$") ? "$400–800" : c.dayRate.startsWith("£") ? "£300–600" : "€300–600"} a month on the side is realistic.` },
      { q: "Do I need a license or certification?", a: "No certification is required to start on HoPetSit — you need to love animals, be reliable and be 18 or older." },
      { q: "Does it cost anything to sign up?", a: `No. Signing up and creating your profile is free. Only identity verification (the ✓ badge, strongly recommended) costs ${c.dayRate.startsWith("$") ? "$3" : c.dayRate.startsWith("£") ? "£3" : "€3"}.` },
      { q: "How does GPS tracking protect the sitter too?", a: "During a walk, PawFollow tracking proves the service was delivered from start to finish. Transparency for the owner, protection for you." },
    ],
    ctaTitle: (c) => `Early sitters in ${c.name} get the best clients`,
    ctaText: (c) => `HoPetSit is launching in ${c.name}: little competition between sitters, new owners every week. This is the best time to create your profile.`,
    ctaBtn: "Create my free profile",
    localTitle: (c) => `Pet sitting in ${c.name}`,
    inLanguage: "en",
  },
  pl: {
    kicker: (c) => c.region,
    h1: (c) => `Zostań opiekunem zwierząt w mieście ${c.name} — zarabiaj, robiąc to, co kochasz`,
    intro: (c) =>
      `Studiujesz, pracujesz zdalnie, jesteś na emeryturze albo po prostu kochasz zwierzęta? W mieście ${c.name} właściciele psów i kotów szukają zaufanej osoby na czas pracy lub wyjazdu. HoPetSit łączy Cię z nimi: sam ustalasz stawki, wybierasz usługi i otrzymujesz bezpieczną zapłatę.`,
    badges: ["💰 Twoje stawki, Twoje zasady", "📅 Sam wybierasz godziny", "✓ Zweryfikowany profil", "🔒 Gwarancja zapłaty"],
    howTitle: "Jak to działa",
    steps: [
      { t: "Załóż darmowy profil", p: "Zdjęcie, opis, usługi (opieka w domu, wizyty, spacery) i TWOJE stawki — Ty decydujesz." },
      { t: "Zweryfikuj tożsamość", p: "5 minut w aplikacji. Odznaka ✓ uspokaja właścicieli: zweryfikowane profile dostają znacznie więcej zapytań." },
      { t: "Odbieraj zapytania i rozmawiaj", p: "Właściciele z Twojej okolicy piszą do Ciebie na czacie. Przyjmujesz tylko to, co Ci odpowiada." },
      { t: "Otrzymuj bezpieczną zapłatę", p: "Płatność jest blokowana w aplikacji przy rezerwacji i trafia na Twoje konto po wykonaniu usługi. Zero niezapłaconych zleceń." },
    ],
    faqTitle: "Najczęstsze pytania",
    faq: (c) => [
      { q: `Ile można zarobić jako opiekun zwierząt w mieście ${c.name}?`, a: `W mieście ${c.name} opieka kosztuje zwykle ${c.dayRate} za dzień, a spacer ${c.walkRate}. Z kilkoma stałymi klientami dodatkowe 1000–2000 zł miesięcznie jest realne.` },
      { q: "Czy potrzebuję uprawnień lub kursu?", a: "Nie. Aby zacząć na HoPetSit, wystarczy kochać zwierzęta, być odpowiedzialnym i mieć ukończone 18 lat." },
      { q: "Czy rejestracja coś kosztuje?", a: "Nie. Rejestracja i profil są darmowe. Płatna jest tylko weryfikacja tożsamości (odznaka ✓, mocno zalecana): 3 €." },
      { q: "Jak śledzenie GPS chroni także opiekuna?", a: "Podczas spaceru śledzenie PawFollow udowadnia, że usługa została wykonana od początku do końca. Przejrzystość dla właściciela, ochrona dla Ciebie." },
    ],
    ctaTitle: (c) => `Pierwsi opiekunowie w mieście ${c.name} zdobywają najlepszych klientów`,
    ctaText: (c) => `HoPetSit startuje w mieście ${c.name}: mała konkurencja między opiekunami, nowi właściciele co tydzień. To najlepszy moment, aby założyć profil.`,
    ctaBtn: "Załóż darmowy profil",
    localTitle: (c) => `Opieka nad zwierzętami — ${c.name}`,
    inLanguage: "pl",
  },
  ko: {
    kicker: (c) => c.region,
    h1: (c) => `${c.name} 펫시터 되기 — 동물을 사랑하며 수입을 얻으세요`,
    intro: (c) =>
      `학생, 재택근무자, 은퇴자, 혹은 그저 동물을 사랑하는 분이신가요? ${c.name}의 반려견·반려묘 보호자들은 출근이나 여행 중 믿고 맡길 사람을 찾고 있습니다. HoPetSit이 여러분을 연결합니다. 요금은 직접 정하고, 서비스는 골라서, 안전하게 정산받으세요.`,
    badges: ["💴 내가 정하는 요금", "📅 내가 정하는 시간", "✓ 인증 배지", "🔒 정산 보장"],
    howTitle: "이용 방법",
    steps: [
      { t: "무료 프로필 만들기", p: "사진, 소개, 서비스(방문 돌봄, 짧은 방문, 산책)와 나만의 요금 — 모든 것은 직접 정합니다." },
      { t: "신원 인증하기", p: "앱에서 5분이면 됩니다. ✓ 배지는 보호자를 안심시키고, 인증된 프로필은 훨씬 더 많은 요청을 받습니다." },
      { t: "요청 받고 대화하기", p: "동네 보호자들이 채팅으로 연락합니다. 마음에 드는 요청만 수락하세요." },
      { t: "안전하게 정산받기", p: "예약 시 결제금이 앱에 보관되고, 서비스 완료 후 계좌로 입금됩니다. 미수금 걱정이 없습니다." },
    ],
    faqTitle: "자주 묻는 질문",
    faq: (c) => [
      { q: `${c.name}에서 펫시터는 얼마나 벌 수 있나요?`, a: `${c.name}에서는 하루 돌봄이 보통 ${c.dayRate}, 산책은 ${c.walkRate} 정도입니다. 단골 몇 분만 있어도 월 30만~60만 원의 부수입이 가능합니다.` },
      { q: "자격증이 필요한가요?", a: "아니요. HoPetSit을 시작하는 데 자격증은 필요 없습니다. 동물을 사랑하고, 책임감 있고, 만 18세 이상이면 됩니다." },
      { q: "가입 비용이 있나요?", a: "없습니다. 가입과 프로필 작성은 무료입니다. 신원 인증(✓ 배지, 강력 추천)만 3€입니다." },
      { q: "GPS 추적이 펫시터도 보호하나요?", a: "산책 중 PawFollow 추적은 출발부터 귀가까지 서비스가 제대로 이루어졌음을 증명합니다. 보호자에게는 투명성, 여러분에게는 보호막입니다." },
    ],
    ctaTitle: (c) => `${c.name}의 첫 펫시터가 가장 좋은 고객을 만납니다`,
    ctaText: (c) => `HoPetSit이 ${c.name}에서 시작합니다. 펫시터 간 경쟁은 적고, 새 보호자는 매주 늘어납니다. 지금이 프로필을 만들 최고의 시기입니다.`,
    ctaBtn: "무료 프로필 만들기",
    localTitle: (c) => `${c.name}에서 반려동물 돌보기`,
    inLanguage: "ko",
  },
  // v560 — moteur de croissance : 5 langues de plus (es/de/it/pt/ja).
  es: {
    kicker: (c) => c.region,
    h1: (c) => `Ser cuidador de mascotas en ${c.name} — cobra por amar a los animales`,
    intro: (c) =>
      `¿Estudiante, teletrabajador, jubilado o simplemente amante de los animales? En ${c.name}, dueños de perros y gatos buscan a alguien de confianza para cuidarlos mientras trabajan o viajan. HoPetSit te pone en contacto con ellos: tú fijas tus tarifas, eliges tus servicios y cobras de forma segura.`,
    badges: ["💶 Tus tarifas, tus reglas", "📅 Tú eliges tus horarios", "✓ Insignia verificada", "🔒 Cero impagos"],
    howTitle: "Cómo funciona",
    steps: [
      { t: "Crea tu perfil gratis", p: "Foto, presentación, servicios (cuidado a domicilio, visitas, paseos) y TUS tarifas: tú decides." },
      { t: "Verifica tu identidad", p: "5 minutos en la app. La insignia ✓ tranquiliza a los dueños: los perfiles verificados reciben muchas más solicitudes." },
      { t: "Recibe solicitudes y chatea", p: "Los dueños de tu barrio te contactan por chat. Solo aceptas lo que te conviene." },
      { t: "Cobra con total seguridad", p: "El pago queda bloqueado en la app desde la reserva y se transfiere a tu cuenta al terminar el servicio." },
    ],
    faqTitle: "Preguntas frecuentes",
    faq: (c) => [
      { q: `¿Cuánto se puede ganar como cuidador de mascotas en ${c.name}?`, a: `En ${c.name}, los cuidados se cobran normalmente ${c.dayRate} al día y los paseos ${c.walkRate}. Con algunos clientes habituales, un extra de 300 a 600 € al mes es realista.` },
      { q: "¿Hace falta un título o un estatus especial?", a: "No se requiere ningún título para empezar en HoPetSit: hay que querer a los animales, ser de fiar y tener 18 años o más. Para una actividad regular, infórmate sobre el alta como autónomo." },
      { q: "¿Cuesta algo registrarse?", a: "No, el registro y el perfil son gratuitos. Solo la verificación de identidad (insignia ✓, muy recomendable) cuesta 3 €." },
      { q: "¿Cómo protege también al cuidador el seguimiento GPS?", a: "Durante un paseo, el seguimiento PawFollow demuestra que el servicio se ha realizado, de la salida a la vuelta. Transparencia para el dueño, protección para ti." },
    ],
    ctaTitle: (c) => `Los primeros inscritos en ${c.name} se quedan con los mejores clientes`,
    ctaText: (c) => `HoPetSit acaba de llegar a ${c.name}: poca competencia entre cuidadores y dueños nuevos cada semana. Es el mejor momento para crear tu perfil.`,
    ctaBtn: "Crear mi perfil gratis",
    localTitle: (c) => `Cuidar mascotas en ${c.name}`,
    inLanguage: "es",
  },
  de: {
    kicker: (c) => c.region,
    h1: (c) => `Tiersitter werden in ${c.name} — bezahlt werden, weil du Tiere liebst`,
    intro: (c) =>
      `Student, im Homeoffice, im Ruhestand oder einfach tierlieb? In ${c.name} suchen Hunde- und Katzenhalter jemanden, dem sie ihr Tier während der Arbeit oder im Urlaub anvertrauen können. HoPetSit bringt euch zusammen: du legst deine Preise fest, wählst deine Leistungen und wirst sicher bezahlt.`,
    badges: ["💶 Deine Preise, deine Regeln", "📅 Du wählst deine Zeiten", "✓ Verifiziert-Abzeichen", "🔒 Kein Zahlungsausfall"],
    howTitle: "So funktioniert es",
    steps: [
      { t: "Kostenloses Profil anlegen", p: "Foto, Vorstellung, Leistungen (Betreuung zu Hause, Besuche, Spaziergänge) und DEINE Preise — du entscheidest." },
      { t: "Identität verifizieren lassen", p: "5 Minuten in der App. Das ✓-Abzeichen beruhigt Halter: verifizierte Profile bekommen deutlich mehr Anfragen." },
      { t: "Anfragen erhalten und chatten", p: "Halter aus deinem Viertel schreiben dir per Chat. Du nimmst nur an, was dir passt." },
      { t: "Sicher bezahlt werden", p: "Die Zahlung wird bei der Buchung in der App gesperrt und nach dem Service auf dein Konto überwiesen." },
    ],
    faqTitle: "Häufige Fragen",
    faq: (c) => [
      { q: `Wie viel kann man als Tiersitter in ${c.name} verdienen?`, a: `In ${c.name} kostet eine Betreuung meist ${c.dayRate} pro Tag, ein Spaziergang ${c.walkRate}. Mit ein paar Stammkunden sind 300 bis 600 € Nebenverdienst im Monat realistisch.` },
      { q: "Brauche ich eine Ausbildung oder einen besonderen Status?", a: "Für den Start auf HoPetSit ist keine Ausbildung nötig — du musst Tiere mögen, zuverlässig und mindestens 18 sein. Für eine regelmäßige Tätigkeit informiere dich über die Anmeldung als Kleingewerbe." },
      { q: "Kostet die Anmeldung etwas?", a: "Nein, Anmeldung und Profil sind kostenlos. Nur die Identitätsprüfung (✓-Abzeichen, sehr empfohlen) kostet 3 €." },
      { q: "Wie schützt das GPS-Tracking auch den Sitter?", a: "Beim Spaziergang belegt das PawFollow-Tracking, dass der Service erbracht wurde — vom Start bis zur Rückkehr. Transparenz für den Halter, Schutz für dich." },
    ],
    ctaTitle: (c) => `Die ersten Sitter in ${c.name} bekommen die besten Kunden`,
    ctaText: (c) => `HoPetSit startet gerade in ${c.name}: wenig Konkurrenz unter Sittern, jede Woche neue Halter. Der beste Moment für dein Profil.`,
    ctaBtn: "Mein kostenloses Profil anlegen",
    localTitle: (c) => `Tiere betreuen in ${c.name}`,
    inLanguage: "de",
  },
  it: {
    kicker: (c) => c.region,
    h1: (c) => `Diventare pet sitter a ${c.name} — farsi pagare per amare gli animali`,
    intro: (c) =>
      `Studente, in smart working, in pensione o semplicemente appassionato? A ${c.name}, i proprietari di cani e gatti cercano una persona di fiducia a cui affidarli durante il lavoro o le vacanze. HoPetSit vi mette in contatto: fissi le tue tariffe, scegli i tuoi servizi e vieni pagato in sicurezza.`,
    badges: ["💶 Le tue tariffe, le tue regole", "📅 Scegli tu gli orari", "✓ Badge verificato", "🔒 Zero insoluti"],
    howTitle: "Come funziona",
    steps: [
      { t: "Crea il tuo profilo gratuito", p: "Foto, presentazione, servizi (custodia a domicilio, visite, passeggiate) e LE TUE tariffe: decidi tu." },
      { t: "Verifica la tua identità", p: "5 minuti nell'app. Il badge ✓ rassicura i proprietari: i profili verificati ricevono molte più richieste." },
      { t: "Ricevi richieste e chatta", p: "I proprietari del tuo quartiere ti contattano in chat. Accetti solo ciò che ti va." },
      { t: "Vieni pagato in sicurezza", p: "Il pagamento è bloccato nell'app dalla prenotazione e versato sul tuo conto a servizio concluso." },
    ],
    faqTitle: "Domande frequenti",
    faq: (c) => [
      { q: `Quanto si guadagna come pet sitter a ${c.name}?`, a: `A ${c.name}, le custodie si fatturano in genere ${c.dayRate} al giorno e le passeggiate ${c.walkRate}. Con qualche cliente abituale, un'integrazione di 300-600 € al mese è realistica.` },
      { q: "Serve un diploma o una posizione particolare?", a: "Nessun diploma è richiesto per iniziare su HoPetSit: basta amare gli animali, essere affidabili e avere almeno 18 anni. Per un'attività regolare, informati sull'apertura di una partita IVA." },
      { q: "L'iscrizione costa qualcosa?", a: "No, iscrizione e profilo sono gratuiti. Solo la verifica dell'identità (badge ✓, fortemente consigliata) costa 3 €." },
      { q: "In che modo il monitoraggio GPS protegge anche il sitter?", a: "Durante una passeggiata, il monitoraggio PawFollow prova che il servizio è stato reso, dalla partenza al rientro. Trasparenza per il proprietario, protezione per te." },
    ],
    ctaTitle: (c) => `I primi iscritti a ${c.name} si prendono i clienti migliori`,
    ctaText: (c) => `HoPetSit arriva ora a ${c.name}: poca concorrenza tra sitter, nuovi proprietari ogni settimana. È il momento migliore per creare il tuo profilo.`,
    ctaBtn: "Crea il mio profilo gratuito",
    localTitle: (c) => `Custodire animali a ${c.name}`,
    inLanguage: "it",
  },
  pt: {
    kicker: (c) => c.region,
    h1: (c) => `Ser pet sitter em ${c.name} — ser pago por adorar animais`,
    intro: (c) =>
      `Estudante, em teletrabalho, reformado ou simplesmente apaixonado por animais? Em ${c.name}, donos de cães e gatos procuram alguém de confiança para cuidar deles durante o trabalho ou as férias. A HoPetSit põe-te em contacto com eles: tu defines os teus preços, escolhes os teus serviços e recebes em segurança.`,
    badges: ["💶 Os teus preços, as tuas regras", "📅 Escolhes os teus horários", "✓ Selo verificado", "🔒 Zero calotes"],
    howTitle: "Como funciona",
    steps: [
      { t: "Cria o teu perfil gratuito", p: "Foto, apresentação, serviços (cuidado ao domicílio, visitas, passeios) e OS TEUS preços: és tu que decides." },
      { t: "Verifica a tua identidade", p: "5 minutos na app. O selo ✓ tranquiliza os donos: os perfis verificados recebem muito mais pedidos." },
      { t: "Recebe pedidos e conversa", p: "Os donos do teu bairro contactam-te por chat. Aceitas apenas o que te convém." },
      { t: "Recebe em total segurança", p: "O pagamento fica bloqueado na app desde a reserva e é transferido para a tua conta no fim do serviço." },
    ],
    faqTitle: "Perguntas frequentes",
    faq: (c) => [
      { q: `Quanto se pode ganhar como pet sitter em ${c.name}?`, a: `Em ${c.name}, os cuidados cobram-se normalmente ${c.dayRate} por dia e os passeios ${c.walkRate}. Com alguns clientes regulares, um extra de 300 a 600 € por mês é realista.` },
      { q: "É preciso um diploma ou um estatuto especial?", a: "Não é preciso nenhum diploma para começar na HoPetSit: basta gostar de animais, ser de confiança e ter 18 anos ou mais. Para uma atividade regular, informa-te sobre a abertura de atividade." },
      { q: "A inscrição custa alguma coisa?", a: "Não, a inscrição e o perfil são gratuitos. Só a verificação de identidade (selo ✓, muito recomendada) custa 3 €." },
      { q: "Como é que o rastreio GPS também protege o cuidador?", a: "Durante um passeio, o seguimento PawFollow prova que o serviço foi prestado, da partida ao regresso. Transparência para o dono, proteção para ti." },
    ],
    ctaTitle: (c) => `Os primeiros inscritos em ${c.name} ficam com os melhores clientes`,
    ctaText: (c) => `A HoPetSit está a chegar a ${c.name}: pouca concorrência entre cuidadores, novos donos todas as semanas. É a melhor altura para criares o teu perfil.`,
    ctaBtn: "Criar o meu perfil gratuito",
    localTitle: (c) => `Cuidar de animais em ${c.name}`,
    inLanguage: "pt",
  },
  ja: {
    kicker: (c) => c.region,
    h1: (c) => `${c.name}でペットシッターになる — 動物が好きなことでお金を得る`,
    intro: (c) =>
      `学生、在宅ワーカー、リタイア後の方、あるいは単に動物好きの方へ。${c.name}では、仕事や旅行の間に犬や猫を安心して任せられる人を、飼い主さんが探しています。HoPetSitがあなたと飼い主さんをつなぎます。料金は自分で決め、サービスを選び、安全に報酬を受け取れます。`,
    badges: ["💴 料金はあなたが決める", "📅 時間もあなたが決める", "✓ 認証バッジ", "🔒 未払いゼロ"],
    howTitle: "仕組み",
    steps: [
      { t: "無料でプロフィールを作成", p: "写真、自己紹介、提供サービス（在宅でのお世話、訪問、散歩）と、あなたの料金。すべてあなたが決めます。" },
      { t: "本人確認を受ける", p: "アプリで5分。✓バッジは飼い主さんを安心させ、認証済みプロフィールははるかに多くの依頼を受けます。" },
      { t: "依頼を受けてチャット", p: "近所の飼い主さんがチャットで連絡してきます。引き受けるのは、あなたに合う依頼だけ。" },
      { t: "安全に報酬を受け取る", p: "予約時にお支払いがアプリ内で保管され、サービス完了後にあなたの口座へ振り込まれます。" },
    ],
    faqTitle: "よくある質問",
    faq: (c) => [
      { q: `${c.name}でペットシッターはどのくらい稼げますか？`, a: `${c.name}では、お世話は1日あたり${c.dayRate}、散歩は${c.walkRate}が一般的です。常連が数人いれば、月3〜6万円ほどの副収入が現実的です。` },
      { q: "資格や特別な手続きは必要ですか？", a: "HoPetSitを始めるのに資格は不要です。動物が好きで、責任感があり、18歳以上であれば大丈夫。継続的に行う場合は、開業届などについて調べてみてください。" },
      { q: "登録に費用はかかりますか？", a: "いいえ、登録もプロフィール作成も無料です。本人確認（✓バッジ、強くおすすめ）のみ3ユーロです。" },
      { q: "GPS追跡はシッターも守ってくれますか？", a: "散歩中のPawFollow追跡は、出発から帰宅までサービスが確かに行われたことを証明します。飼い主さんには透明性を、あなたには安心を。" },
    ],
    ctaTitle: (c) => `${c.name}の最初のシッターが、いちばん良いお客様と出会えます`,
    ctaText: (c) => `HoPetSitは${c.name}で始まったばかり。シッター同士の競争は少なく、毎週新しい飼い主さんが登録しています。プロフィールを作るなら今です。`,
    ctaBtn: "無料でプロフィールを作る",
    localTitle: (c) => `${c.name}でペットのお世話をする`,
    inLanguage: "ja",
  },
};

export function recruitMetadata(c: RecruitCity, canonical: string) {
  const copy = COPY[c.lang];
  const title =
    c.lang === "fr" ? `Devenir pet sitter à ${c.name} — HoPetSit`
    : c.lang === "en" ? `Become a pet sitter in ${c.name} — HoPetSit`
    : c.lang === "pl" ? `Zostań opiekunem zwierząt — ${c.name} — HoPetSit`
    : c.lang === "es" ? `Ser cuidador de mascotas en ${c.name} — HoPetSit`
    : c.lang === "de" ? `Tiersitter werden in ${c.name} — HoPetSit`
    : c.lang === "it" ? `Diventare pet sitter a ${c.name} — HoPetSit`
    : c.lang === "pt" ? `Ser pet sitter em ${c.name} — HoPetSit`
    : c.lang === "ja" ? `${c.name}でペットシッターになる — HoPetSit`
    : `${c.name} 펫시터 되기 — HoPetSit`;
  return {
    title,
    description: copy.intro(c).slice(0, 155),
    alternates: { canonical },
    openGraph: { title, description: copy.intro(c).slice(0, 155), url: canonical, type: "website" as const },
  };
}

export default function RecruitCityPage({ city }: { city: RecruitCity }) {
  const copy = COPY[city.lang];
  const faq = copy.faq(city);
  const jsonLd = {
    "@context": "https://schema.org",
    "@graph": [
      { "@type": "WebPage", name: copy.h1(city), inLanguage: copy.inLanguage },
      {
        "@type": "FAQPage",
        mainEntity: faq.map((f) => ({
          "@type": "Question",
          name: f.q,
          acceptedAnswer: { "@type": "Answer", text: f.a },
        })),
      },
    ],
  };

  return (
    <div className="mx-auto max-w-3xl px-4 py-16 md:py-24">
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }} />
      <p className="text-sm font-semibold text-sitter-dark">{copy.kicker(city)}</p>
      <h1 className="mt-2 font-display text-3xl font-extrabold tracking-tight text-ink md:text-4xl">{copy.h1(city)}</h1>
      <p className="mt-4 text-lg leading-relaxed text-ink-muted">{copy.intro(city)}</p>

      <div className="mt-8 flex flex-wrap gap-3">
        {copy.badges.map((b) => (
          <span key={b} className="rounded-full border border-ink/10 bg-white px-4 py-2 text-sm font-semibold text-ink shadow-card">{b}</span>
        ))}
      </div>

      <div className="mt-10 rounded-2xl border border-sitter/20 bg-sitter-light/60 p-6">
        <h2 className="font-display text-xl font-extrabold text-ink">{copy.localTitle(city)}</h2>
        <p className="mt-2 text-sm leading-relaxed text-ink-muted">{city.local}</p>
      </div>

      <h2 className="mt-14 font-display text-2xl font-extrabold text-ink">{copy.howTitle}</h2>
      <ol className="mt-6 space-y-4">
        {copy.steps.map((s, i) => (
          <li key={s.t} className="flex gap-5 rounded-2xl border border-ink/5 bg-white p-6 shadow-card">
            <div className="grid h-12 w-12 shrink-0 place-items-center rounded-2xl bg-sitter-light text-lg font-extrabold text-sitter-dark">{i + 1}</div>
            <div>
              <h3 className="text-base font-bold text-ink">{s.t}</h3>
              <p className="mt-1.5 text-sm leading-relaxed text-ink-muted">{s.p}</p>
            </div>
          </li>
        ))}
      </ol>

      <h2 className="mt-14 font-display text-2xl font-extrabold text-ink">{copy.faqTitle}</h2>
      <div className="mt-6 space-y-4">
        {faq.map((f) => (
          <div key={f.q} className="rounded-2xl border border-ink/5 bg-white p-5 shadow-card">
            <h3 className="font-bold text-ink">{f.q}</h3>
            <p className="mt-2 text-sm leading-relaxed text-ink-muted">{f.a}</p>
          </div>
        ))}
      </div>

      <div className="mt-14 rounded-3xl bg-sitter-light p-8 text-center">
        <h2 className="font-display text-2xl font-extrabold text-ink">{copy.ctaTitle(city)}</h2>
        <p className="mx-auto mt-2 max-w-md text-sm text-ink-muted">{copy.ctaText(city)}</p>
        <Link href="/download" className="mt-5 inline-block rounded-full bg-sitter px-7 py-3 text-sm font-bold text-white">{copy.ctaBtn}</Link>
      </div>

      {/* v560 — lien croisé vers la page « trouver un pet sitter à <ville> ». */}
      <p className="mt-8 text-center text-sm">
        <Link href={`${OWNER_PATH_PREFIX[city.lang]}/${city.slug}`} className="font-semibold text-owner underline-offset-4 hover:underline">
          {OWNER_LINK[city.lang](city)}
        </Link>
      </p>
    </div>
  );
}

const OWNER_LINK: Record<RecruitLang, (c: RecruitCity) => string> = {
  fr: (c) => `Vous êtes propriétaire ? Trouver un pet sitter à ${c.name} →`,
  en: (c) => `Pet owner? Find a pet sitter in ${c.name} →`,
  es: (c) => `¿Tienes mascota? Encuentra un cuidador en ${c.name} →`,
  de: (c) => `Tierhalter? Finde einen Tiersitter in ${c.name} →`,
  it: (c) => `Hai un animale? Trova un pet sitter a ${c.name} →`,
  pt: (c) => `Tens um animal? Encontra um pet sitter em ${c.name} →`,
  pl: (c) => `Masz zwierzaka? Znajdź opiekuna — ${c.name} →`,
  ko: (c) => `보호자이신가요? ${c.name} 펫시터 찾기 →`,
  ja: (c) => `飼い主の方へ：${c.name}でペットシッターを探す →`,
};

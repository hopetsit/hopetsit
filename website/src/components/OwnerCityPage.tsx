import Link from "next/link";
import ParisLocalPlaces, { parisEntry, parisFaq } from "@/components/ParisLocalPlaces";
import { GetAppButton } from "@/components/GetAppButton";
import { OwnerSignupCta } from "@/components/OwnerSignupCta";
import { CitySupplyProof } from "@/components/CitySupplyProof";
import type { RecruitCity, RecruitLang } from "@/lib/recruit-cities";
import { RECRUIT_PATH_PREFIX, OWNER_PATH_PREFIX, nearbyCities, NEARBY_LABEL } from "@/lib/recruit-cities";

// v560 — moteur de croissance : pages « trouver un pet sitter à <ville> »
// (intention PROPRIÉTAIRE : « pet sitter Paris 11 », « cuidador de perros
// Alicante »…). Même source de données que les pages de recrutement
// (recruit-cities.ts) : une ville = deux pages, liées entre elles.

// v575 — premier écran mobile orienté conversion (trafic pub Meta, 100 %
// mobile). Une phrase, trois preuves, UN bouton. Tout est rendu côté serveur
// (aucun useT ici : ces pages sont statiques et doivent sortir du HTML dans la
// bonne langue pour Google), donc les textes vivent dans COPY comme le reste.
const PROOF_ICONS = ["🔒", "✓", "🗓"];

type Copy = {
  kicker: (c: RecruitCity) => string;
  h1: (c: RecruitCity) => string;
  /** Accroche courte au-dessus de la ligne de flottaison. */
  heroLead: (c: RecruitCity) => string;
  /** 3 preuves courtes : paiement · identité · annulation. */
  proofs: [string, string, string];
  /** Libellé du bouton principal (ouvre le store de l'appareil). */
  heroCta: string;
  /** Petite ligne sous le bouton (gratuité + stores). */
  // 23/09 (Bob) : le bouton ouvre le formulaire web sans compte (v581) ;
  // l'ancienne note parlait encore de l'App Store et contredisait le bouton.
  heroCtaNote: string;
  /** v577 — lien secondaire vers le store (le bouton principal mène au site). */
  heroAppLink: string;
  /** Lien secondaire vers la carte des membres. */
  heroSecondary: string;
  intro: (c: RecruitCity) => string;
  servicesTitle: string;
  services: { icon: string; t: string; p: string }[];
  whyTitle: string;
  why: { icon: string; t: string; p: string }[];
  pricesTitle: (c: RecruitCity) => string;
  prices: (c: RecruitCity) => string;
  faqTitle: string;
  faq: (c: RecruitCity) => { q: string; a: string }[];
  ctaTitle: (c: RecruitCity) => string;
  ctaText: string;
  ctaBtn: string;
  recruitLink: (c: RecruitCity) => string;
  inLanguage: string;
  metaTitle: (c: RecruitCity) => string;
};

const COPY: Record<RecruitLang, Copy> = {
  fr: {
    kicker: (c) => c.region,
    h1: (c) => `Pet sitter à ${c.name} : garde de chien, chat et promenades`,
    heroLead: (c) => `Un pet-sitter vérifié près de chez toi à ${c.name}. Tu publies ta demande, tu choisis, tu ne paies qu'à la réservation.`,
    proofs: ["Paiement sécurisé", "Identité vérifiée", "Annulation gratuite 72 h"],
    heroCta: "Publier ma demande",
    heroCtaNote: "Gratuit · sans compte pour commencer · 2 minutes",
    heroAppLink: "Ou télécharger l'app HoPetSit →",
    heroSecondary: "Voir les gardiens près de chez moi →",
    intro: (c) =>
      `Week-end, vacances, journées de travail à rallonge : à ${c.name}, HoPetSit vous met en relation avec des gardiens et promeneurs vérifiés près de chez vous. Vous publiez votre demande gratuitement, vous comparez les profils, vous discutez par chat et vous ne payez que si vous réservez.`,
    servicesTitle: "Les services près de chez vous",
    services: [
      { icon: "🏠", t: "Garde à domicile", p: "Votre animal reste chez vous, dans ses habitudes. Le gardien vient dormir ou passe plusieurs fois par jour." },
      { icon: "🐾", t: "Visites pour chats", p: "Nourriture, litière, câlins et une photo à chaque passage : idéal pour les chats qui n'aiment pas bouger." },
      { icon: "🚶", t: "Promenades de chien", p: "Une sortie en semaine, à l'heure qui vous arrange, suivie en direct sur la carte du départ au retour." },
    ],
    whyTitle: "Pourquoi HoPetSit",
    why: [
      { icon: "✓", t: "Profils vérifiés", p: "Identité contrôlée, avis réels de propriétaires, badge visible sur chaque profil." },
      { icon: "🔒", t: "Paiement sécurisé", p: "L'argent est bloqué dans l'app et versé au gardien seulement une fois le service terminé." },
      { icon: "📍", t: "Suivi en direct", p: "PawFollow vous montre la promenade en temps réel. Vous savez où est votre chien, tout le temps." },
      { icon: "🗺️", t: "PawMap", p: "Les membres autour de vous, les lieux pet-friendly, leurs horaires et l'itinéraire pour y aller." },
    ],
    pricesTitle: (c) => `Combien coûte un pet sitter à ${c.name} ?`,
    prices: (c) => `À ${c.name}, comptez ${c.dayRate} par jour pour une garde et ${c.walkRate} pour une promenade. Chaque gardien fixe ses tarifs : vous les voyez sur son profil avant de réserver, sans surprise.`,
    faqTitle: "Questions fréquentes",
    faq: (c) => [
      { q: `Comment trouver un pet sitter de confiance à ${c.name} ?`, a: `Publiez votre demande dans l'app : les gardiens vérifiés de ${c.name} vous répondent. Regardez les avis, discutez par chat, et réservez seulement quand vous êtes à l'aise.` },
      { q: "Le paiement est-il vraiment sécurisé ?", a: "Oui. Le montant est bloqué dans l'app à la réservation et versé au gardien après le service. En cas de problème, notre support intervient avant tout versement." },
      { q: "Puis-je suivre la promenade de mon chien ?", a: "Oui, avec PawFollow : le trajet s'affiche en direct sur la carte, du départ au retour, avec la distance et la durée." },
      { q: "Combien coûte l'inscription ?", a: "Rien. Publier une demande et discuter avec les gardiens est gratuit. Vous payez uniquement la garde que vous réservez." },
    ],
    ctaTitle: (c) => `Trouvez votre gardien à ${c.name}`,
    ctaText: "Publiez votre demande en deux minutes et recevez les réponses des gardiens près de chez vous.",
    ctaBtn: "Publier ma demande gratuite",
    recruitLink: (c) => `Vous aimez les animaux ? Devenez pet sitter à ${c.name} →`,
    inLanguage: "fr",
    metaTitle: (c) => `Pet sitter à ${c.name} — garde de chien, chat & promenades`,
  },
  en: {
    kicker: (c) => c.region,
    h1: (c) => `Pet sitters in ${c.name}: dog boarding, cat visits and dog walks`,
    heroLead: (c) => `A verified pet sitter near you in ${c.name}. Post your request, pick your sitter, pay only when you book.`,
    proofs: ["Secure payment", "ID verified", "72 h free cancellation"],
    heroCta: "Post my request",
    heroCtaNote: "Free · no account needed to start · 2 minutes",
    heroAppLink: "Or download the HoPetSit app →",
    heroSecondary: "See sitters near me →",
    intro: (c) =>
      `Weekends, vacations, long workdays: in ${c.name}, HoPetSit connects you with verified sitters and dog walkers near you. Post your request for free, compare profiles, chat, and only pay when you book.`,
    servicesTitle: "Services near you",
    services: [
      { icon: "🏠", t: "In-home sitting", p: "Your pet stays home, in its routine. The sitter sleeps over or stops by several times a day." },
      { icon: "🐾", t: "Cat drop-in visits", p: "Food, litter, cuddles and a photo at every visit: perfect for cats who hate moving." },
      { icon: "🚶", t: "Dog walking", p: "A weekday walk at the time that suits you, tracked live on the map from door to door." },
    ],
    whyTitle: "Why HoPetSit",
    why: [
      { icon: "✓", t: "Verified profiles", p: "ID-checked sitters, real owner reviews, a visible badge on every profile." },
      { icon: "🔒", t: "Secure payment", p: "Money is held in the app and released to the sitter only once the service is done." },
      { icon: "📍", t: "Live tracking", p: "PawFollow shows the walk in real time. You know where your dog is, always." },
      { icon: "🗺️", t: "PawMap", p: "Members around you, pet-friendly places, their opening hours and directions to get there." },
    ],
    pricesTitle: (c) => `How much does a pet sitter cost in ${c.name}?`,
    prices: (c) => `In ${c.name}, expect ${c.dayRate} per day for sitting and ${c.walkRate} for a walk. Every sitter sets their own rates: you see them on the profile before booking, no surprises.`,
    faqTitle: "Frequently asked questions",
    faq: (c) => [
      { q: `How do I find a trustworthy pet sitter in ${c.name}?`, a: `Post your request in the app: verified sitters in ${c.name} reply. Read reviews, chat, and book only when you feel comfortable.` },
      { q: "Is payment really secure?", a: "Yes. The amount is held in the app at booking and released to the sitter after the service. If anything goes wrong, our support steps in before any payout." },
      { q: "Can I follow my dog's walk?", a: "Yes, with PawFollow: the route shows live on the map from start to finish, with distance and duration." },
      { q: "How much does it cost to sign up?", a: "Nothing. Posting a request and chatting with sitters is free. You only pay for the booking you make." },
    ],
    ctaTitle: (c) => `Find your sitter in ${c.name}`,
    ctaText: "Post your request in two minutes and get replies from sitters near you.",
    ctaBtn: "Post my free request",
    recruitLink: (c) => `Love animals? Become a pet sitter in ${c.name} →`,
    inLanguage: "en",
    metaTitle: (c) => `Pet sitters in ${c.name} — dog sitting, cat visits & walks`,
  },
  es: {
    kicker: (c) => c.region,
    h1: (c) => `Cuidador de mascotas en ${c.name}: cuidado de perros, gatos y paseos`,
    heroLead: (c) => `Un cuidador verificado cerca de ti en ${c.name}. Publicas tu solicitud, eliges y solo pagas al reservar.`,
    proofs: ["Pago seguro", "Identidad verificada", "Cancelación gratis 72 h"],
    heroCta: "Publicar mi solicitud",
    heroCtaNote: "Gratis · sin cuenta para empezar · 2 minutos",
    heroAppLink: "O descargar la app HoPetSit →",
    heroSecondary: "Ver cuidadores cerca de mí →",
    intro: (c) =>
      `Fin de semana, vacaciones, jornadas largas: en ${c.name}, HoPetSit te pone en contacto con cuidadores y paseadores verificados cerca de ti. Publicas tu solicitud gratis, comparas perfiles, chateas y solo pagas si reservas.`,
    servicesTitle: "Servicios cerca de ti",
    services: [
      { icon: "🏠", t: "Cuidado a domicilio", p: "Tu mascota se queda en casa, con sus rutinas. El cuidador duerme allí o pasa varias veces al día." },
      { icon: "🐾", t: "Visitas para gatos", p: "Comida, arenero, mimos y una foto en cada visita: ideal para gatos que odian moverse." },
      { icon: "🚶", t: "Paseos de perros", p: "Una salida entre semana, a la hora que te convenga, seguida en directo en el mapa de puerta a puerta." },
    ],
    whyTitle: "Por qué HoPetSit",
    why: [
      { icon: "✓", t: "Perfiles verificados", p: "Identidad comprobada, reseñas reales de dueños, insignia visible en cada perfil." },
      { icon: "🔒", t: "Pago seguro", p: "El dinero queda bloqueado en la app y se entrega al cuidador solo al terminar el servicio." },
      { icon: "📍", t: "Seguimiento en directo", p: "PawFollow te muestra el paseo en tiempo real. Sabes dónde está tu perro, siempre." },
      { icon: "🗺️", t: "PawMap", p: "Miembros cerca de ti, lugares pet-friendly, sus horarios y la ruta para llegar." },
    ],
    pricesTitle: (c) => `¿Cuánto cuesta un cuidador de mascotas en ${c.name}?`,
    prices: (c) => `En ${c.name}, calcula ${c.dayRate} al día por un cuidado y ${c.walkRate} por un paseo. Cada cuidador fija sus tarifas: las ves en su perfil antes de reservar, sin sorpresas.`,
    faqTitle: "Preguntas frecuentes",
    faq: (c) => [
      { q: `¿Cómo encontrar un cuidador de confianza en ${c.name}?`, a: `Publica tu solicitud en la app: los cuidadores verificados de ${c.name} te responden. Lee las reseñas, chatea y reserva solo cuando estés tranquilo.` },
      { q: "¿El pago es realmente seguro?", a: "Sí. El importe queda bloqueado en la app al reservar y se entrega al cuidador después del servicio. Si hay un problema, nuestro soporte interviene antes de cualquier pago." },
      { q: "¿Puedo seguir el paseo de mi perro?", a: "Sí, con PawFollow: la ruta se muestra en directo en el mapa, de principio a fin, con distancia y duración." },
      { q: "¿Cuánto cuesta registrarse?", a: "Nada. Publicar una solicitud y chatear con los cuidadores es gratis. Solo pagas el cuidado que reservas." },
    ],
    ctaTitle: (c) => `Encuentra a tu cuidador en ${c.name}`,
    ctaText: "Publica tu solicitud en dos minutos y recibe respuestas de cuidadores cerca de ti.",
    ctaBtn: "Publicar mi solicitud gratis",
    recruitLink: (c) => `¿Te gustan los animales? Sé cuidador de mascotas en ${c.name} →`,
    inLanguage: "es",
    metaTitle: (c) => `Cuidador de mascotas en ${c.name} — perros, gatos y paseos`,
  },
  de: {
    kicker: (c) => c.region,
    h1: (c) => `Tiersitter in ${c.name}: Hundebetreuung, Katzenbesuche und Gassi-Service`,
    heroLead: (c) => `Ein verifizierter Tiersitter in deiner Nähe in ${c.name}. Anfrage veröffentlichen, auswählen, erst bei der Buchung bezahlen.`,
    proofs: ["Sichere Zahlung", "Identität geprüft", "Storno gratis 72 Std."],
    heroCta: "Anfrage veröffentlichen",
    heroCtaNote: "Kostenlos · ohne Konto starten · 2 Minuten",
    heroAppLink: "Oder die HoPetSit-App laden →",
    heroSecondary: "Sitter in meiner Nähe ansehen →",
    intro: (c) =>
      `Wochenende, Urlaub, lange Arbeitstage: in ${c.name} verbindet dich HoPetSit mit verifizierten Sittern und Gassigehern in deiner Nähe. Anfrage kostenlos veröffentlichen, Profile vergleichen, chatten und nur bei einer Buchung bezahlen.`,
    servicesTitle: "Leistungen in deiner Nähe",
    services: [
      { icon: "🏠", t: "Betreuung zu Hause", p: "Dein Tier bleibt in seiner gewohnten Umgebung. Der Sitter übernachtet oder kommt mehrmals am Tag vorbei." },
      { icon: "🐾", t: "Katzenbesuche", p: "Futter, Katzenklo, Streicheleinheiten und ein Foto bei jedem Besuch: ideal für Katzen, die Umzüge hassen." },
      { icon: "🚶", t: "Gassi-Service", p: "Ein Spaziergang unter der Woche zur passenden Uhrzeit, live auf der Karte verfolgt, von Tür zu Tür." },
    ],
    whyTitle: "Warum HoPetSit",
    why: [
      { icon: "✓", t: "Verifizierte Profile", p: "Geprüfte Identität, echte Bewertungen von Haltern, sichtbares Abzeichen auf jedem Profil." },
      { icon: "🔒", t: "Sichere Zahlung", p: "Das Geld bleibt in der App gesperrt und geht erst nach dem Service an den Sitter." },
      { icon: "📍", t: "Live-Tracking", p: "PawFollow zeigt dir den Spaziergang in Echtzeit. Du weißt immer, wo dein Hund ist." },
      { icon: "🗺️", t: "PawMap", p: "Mitglieder in deiner Nähe, tierfreundliche Orte, ihre Öffnungszeiten und der Weg dorthin." },
    ],
    pricesTitle: (c) => `Was kostet ein Tiersitter in ${c.name}?`,
    prices: (c) => `In ${c.name} rechnest du mit ${c.dayRate} pro Tag für eine Betreuung und ${c.walkRate} für einen Spaziergang. Jeder Sitter legt seine Preise selbst fest: du siehst sie vor der Buchung im Profil, ohne Überraschungen.`,
    faqTitle: "Häufige Fragen",
    faq: (c) => [
      { q: `Wie finde ich einen vertrauenswürdigen Tiersitter in ${c.name}?`, a: `Veröffentliche deine Anfrage in der App: verifizierte Sitter aus ${c.name} antworten dir. Lies die Bewertungen, chatte und buche erst, wenn du dich wohlfühlst.` },
      { q: "Ist die Zahlung wirklich sicher?", a: "Ja. Der Betrag wird bei der Buchung in der App gesperrt und nach dem Service an den Sitter überwiesen. Bei Problemen greift unser Support vor jeder Auszahlung ein." },
      { q: "Kann ich den Spaziergang meines Hundes verfolgen?", a: "Ja, mit PawFollow: die Route erscheint live auf der Karte, von Anfang bis Ende, mit Distanz und Dauer." },
      { q: "Was kostet die Anmeldung?", a: "Nichts. Eine Anfrage zu veröffentlichen und mit Sittern zu chatten ist kostenlos. Du bezahlst nur die Betreuung, die du buchst." },
    ],
    ctaTitle: (c) => `Finde deinen Sitter in ${c.name}`,
    ctaText: "Veröffentliche deine Anfrage in zwei Minuten und erhalte Antworten von Sittern in deiner Nähe.",
    ctaBtn: "Kostenlose Anfrage veröffentlichen",
    recruitLink: (c) => `Du liebst Tiere? Werde Tiersitter in ${c.name} →`,
    inLanguage: "de",
    metaTitle: (c) => `Tiersitter in ${c.name} — Hundebetreuung, Katzenbesuche & Gassi`,
  },
  it: {
    kicker: (c) => c.region,
    h1: (c) => `Pet sitter a ${c.name}: custodia di cani, gatti e passeggiate`,
    heroLead: (c) => `Un pet sitter verificato vicino a te a ${c.name}. Pubblichi la richiesta, scegli e paghi solo quando prenoti.`,
    proofs: ["Pagamento sicuro", "Identità verificata", "Cancellazione gratis 72 h"],
    heroCta: "Pubblica la mia richiesta",
    heroCtaNote: "Gratis · senza account per iniziare · 2 minuti",
    heroAppLink: "Oppure scarica l'app HoPetSit →",
    heroSecondary: "Vedi i sitter vicino a me →",
    intro: (c) =>
      `Weekend, vacanze, giornate di lavoro infinite: a ${c.name}, HoPetSit ti mette in contatto con pet sitter e dog walker verificati vicino a te. Pubblichi la richiesta gratis, confronti i profili, chatti e paghi solo se prenoti.`,
    servicesTitle: "I servizi vicino a te",
    services: [
      { icon: "🏠", t: "Custodia a domicilio", p: "Il tuo animale resta a casa sua, con le sue abitudini. Il sitter dorme lì o passa più volte al giorno." },
      { icon: "🐾", t: "Visite per gatti", p: "Cibo, lettiera, coccole e una foto a ogni visita: perfetto per i gatti che odiano spostarsi." },
      { icon: "🚶", t: "Passeggiate per cani", p: "Un'uscita in settimana all'ora che preferisci, seguita in diretta sulla mappa da porta a porta." },
    ],
    whyTitle: "Perché HoPetSit",
    why: [
      { icon: "✓", t: "Profili verificati", p: "Identità controllata, recensioni vere dei proprietari, badge visibile su ogni profilo." },
      { icon: "🔒", t: "Pagamento sicuro", p: "Il denaro resta bloccato nell'app e va al sitter solo a servizio concluso." },
      { icon: "📍", t: "Monitoraggio live", p: "PawFollow ti mostra la passeggiata in tempo reale. Sai sempre dov'è il tuo cane." },
      { icon: "🗺️", t: "PawMap", p: "I membri vicino a te, i luoghi pet-friendly, i loro orari e il percorso per arrivarci." },
    ],
    pricesTitle: (c) => `Quanto costa un pet sitter a ${c.name}?`,
    prices: (c) => `A ${c.name}, calcola ${c.dayRate} al giorno per una custodia e ${c.walkRate} per una passeggiata. Ogni sitter fissa le proprie tariffe: le vedi sul profilo prima di prenotare, senza sorprese.`,
    faqTitle: "Domande frequenti",
    faq: (c) => [
      { q: `Come trovare un pet sitter affidabile a ${c.name}?`, a: `Pubblica la tua richiesta nell'app: i sitter verificati di ${c.name} ti rispondono. Leggi le recensioni, chatta e prenota solo quando ti senti tranquillo.` },
      { q: "Il pagamento è davvero sicuro?", a: "Sì. L'importo è bloccato nell'app alla prenotazione e versato al sitter dopo il servizio. In caso di problemi, il nostro supporto interviene prima di qualsiasi pagamento." },
      { q: "Posso seguire la passeggiata del mio cane?", a: "Sì, con PawFollow: il percorso appare in diretta sulla mappa, dall'inizio alla fine, con distanza e durata." },
      { q: "Quanto costa iscriversi?", a: "Niente. Pubblicare una richiesta e chattare con i sitter è gratis. Paghi solo la custodia che prenoti." },
    ],
    ctaTitle: (c) => `Trova il tuo sitter a ${c.name}`,
    ctaText: "Pubblica la richiesta in due minuti e ricevi le risposte dei sitter vicino a te.",
    ctaBtn: "Pubblicare la mia richiesta gratuita",
    recruitLink: (c) => `Ami gli animali? Diventa pet sitter a ${c.name} →`,
    inLanguage: "it",
    metaTitle: (c) => `Pet sitter a ${c.name} — custodia cani, gatti e passeggiate`,
  },
  pt: {
    kicker: (c) => c.region,
    h1: (c) => `Pet sitter em ${c.name}: cuidado de cães, gatos e passeios`,
    heroLead: (c) => `Um pet sitter verificado perto de ti em ${c.name}. Publicas o teu pedido, escolhes e só pagas ao reservar.`,
    proofs: ["Pagamento seguro", "Identidade verificada", "Cancelamento grátis 72 h"],
    heroCta: "Publicar o meu pedido",
    heroCtaNote: "Grátis · sem conta para começar · 2 minutos",
    heroAppLink: "Ou transferir a app HoPetSit →",
    heroSecondary: "Ver cuidadores perto de mim →",
    intro: (c) =>
      `Fim de semana, férias, dias de trabalho longos: em ${c.name}, a HoPetSit põe-te em contacto com cuidadores e passeadores verificados perto de ti. Publicas o teu pedido grátis, comparas perfis, conversas por chat e só pagas se reservares.`,
    servicesTitle: "Os serviços perto de ti",
    services: [
      { icon: "🏠", t: "Cuidado ao domicílio", p: "O teu animal fica em casa, com os seus hábitos. O cuidador dorme lá ou passa várias vezes por dia." },
      { icon: "🐾", t: "Visitas para gatos", p: "Comida, areia, mimos e uma foto em cada visita: ideal para gatos que detestam sair de casa." },
      { icon: "🚶", t: "Passeios de cães", p: "Uma saída durante a semana, à hora que te convém, seguida ao vivo no mapa de porta a porta." },
    ],
    whyTitle: "Porquê a HoPetSit",
    why: [
      { icon: "✓", t: "Perfis verificados", p: "Identidade confirmada, avaliações reais de donos, selo visível em cada perfil." },
      { icon: "🔒", t: "Pagamento seguro", p: "O dinheiro fica bloqueado na app e só é entregue ao cuidador no fim do serviço." },
      { icon: "📍", t: "Seguimento ao vivo", p: "O PawFollow mostra-te o passeio em tempo real. Sabes sempre onde está o teu cão." },
      { icon: "🗺️", t: "PawMap", p: "Os membros perto de ti, os locais pet-friendly, os horários e o itinerário para lá chegar." },
    ],
    pricesTitle: (c) => `Quanto custa um pet sitter em ${c.name}?`,
    prices: (c) => `Em ${c.name}, conta com ${c.dayRate} por dia para um cuidado e ${c.walkRate} por um passeio. Cada cuidador define os seus preços: vês-os no perfil antes de reservar, sem surpresas.`,
    faqTitle: "Perguntas frequentes",
    faq: (c) => [
      { q: `Como encontrar um pet sitter de confiança em ${c.name}?`, a: `Publica o teu pedido na app: os cuidadores verificados de ${c.name} respondem-te. Lê as avaliações, conversa por chat e reserva só quando te sentires à vontade.` },
      { q: "O pagamento é mesmo seguro?", a: "Sim. O valor fica bloqueado na app na reserva e é entregue ao cuidador depois do serviço. Se houver um problema, o nosso apoio intervém antes de qualquer pagamento." },
      { q: "Posso seguir o passeio do meu cão?", a: "Sim, com o PawFollow: o percurso aparece ao vivo no mapa, do início ao fim, com distância e duração." },
      { q: "Quanto custa a inscrição?", a: "Nada. Publicar um pedido e conversar com os cuidadores é grátis. Só pagas o cuidado que reservas." },
    ],
    ctaTitle: (c) => `Encontra o teu cuidador em ${c.name}`,
    ctaText: "Publica o teu pedido em dois minutos e recebe respostas de cuidadores perto de ti.",
    ctaBtn: "Publicar o meu pedido grátis",
    recruitLink: (c) => `Gostas de animais? Sê pet sitter em ${c.name} →`,
    inLanguage: "pt",
    metaTitle: (c) => `Pet sitter em ${c.name} — cuidado de cães, gatos e passeios`,
  },
  pl: {
    kicker: (c) => c.region,
    h1: (c) => `Opiekun zwierząt — ${c.name}: opieka nad psem, kotem i spacery`,
    heroLead: (c) => `Zweryfikowany opiekun blisko Ciebie — ${c.name}. Publikujesz ogłoszenie, wybierasz i płacisz dopiero przy rezerwacji.`,
    proofs: ["Bezpieczna płatność", "Zweryfikowana tożsamość", "Bezpłatna anulacja 72 h"],
    heroCta: "Opublikuj ogłoszenie",
    heroCtaNote: "Za darmo · bez konta na start · 2 minuty",
    heroAppLink: "Albo pobierz aplikację HoPetSit →",
    heroSecondary: "Zobacz opiekunów w okolicy →",
    intro: (c) =>
      `Weekend, urlop, długie dni w pracy: w mieście ${c.name} HoPetSit łączy Cię ze zweryfikowanymi opiekunami i wyprowadzaczami w Twojej okolicy. Publikujesz ogłoszenie za darmo, porównujesz profile, piszesz na czacie i płacisz tylko wtedy, gdy rezerwujesz.`,
    servicesTitle: "Usługi w Twojej okolicy",
    services: [
      { icon: "🏠", t: "Opieka w Twoim domu", p: "Zwierzak zostaje u siebie, w swoich zwyczajach. Opiekun nocuje lub przychodzi kilka razy dziennie." },
      { icon: "🐾", t: "Wizyty u kotów", p: "Jedzenie, kuweta, pieszczoty i zdjęcie przy każdej wizycie: idealne dla kotów, które nie znoszą przeprowadzek." },
      { icon: "🚶", t: "Spacery z psem", p: "Wyjście w tygodniu o dogodnej porze, śledzone na żywo na mapie od drzwi do drzwi." },
    ],
    whyTitle: "Dlaczego HoPetSit",
    why: [
      { icon: "✓", t: "Zweryfikowane profile", p: "Sprawdzona tożsamość, prawdziwe opinie właścicieli, widoczna odznaka na każdym profilu." },
      { icon: "🔒", t: "Bezpieczna płatność", p: "Pieniądze są zablokowane w aplikacji i trafiają do opiekuna dopiero po zakończeniu usługi." },
      { icon: "📍", t: "Śledzenie na żywo", p: "PawFollow pokazuje spacer w czasie rzeczywistym. Zawsze wiesz, gdzie jest Twój pies." },
      { icon: "🗺️", t: "PawMap", p: "Członkowie w okolicy, miejsca przyjazne zwierzętom, ich godziny otwarcia i trasa dojazdu." },
    ],
    pricesTitle: (c) => `Ile kosztuje opiekun zwierząt — ${c.name}?`,
    prices: (c) => `W mieście ${c.name} licz na ${c.dayRate} za dzień opieki i ${c.walkRate} za spacer. Każdy opiekun ustala własne stawki: widzisz je w profilu przed rezerwacją, bez niespodzianek.`,
    faqTitle: "Najczęstsze pytania",
    faq: (c) => [
      { q: `Jak znaleźć zaufanego opiekuna zwierząt — ${c.name}?`, a: `Opublikuj ogłoszenie w aplikacji: zweryfikowani opiekunowie z miasta ${c.name} odpowiedzą. Przeczytaj opinie, porozmawiaj na czacie i rezerwuj dopiero, gdy poczujesz się pewnie.` },
      { q: "Czy płatność jest naprawdę bezpieczna?", a: "Tak. Kwota jest blokowana w aplikacji przy rezerwacji i przekazywana opiekunowi po usłudze. W razie problemu nasz zespół wsparcia interweniuje przed jakąkolwiek wypłatą." },
      { q: "Czy mogę śledzić spacer mojego psa?", a: "Tak, dzięki PawFollow: trasa pojawia się na żywo na mapie, od startu do powrotu, z dystansem i czasem." },
      { q: "Ile kosztuje rejestracja?", a: "Nic. Publikowanie ogłoszenia i czat z opiekunami są bezpłatne. Płacisz tylko za opiekę, którą rezerwujesz." },
    ],
    ctaTitle: (c) => `Znajdź opiekuna — ${c.name}`,
    ctaText: "Opublikuj ogłoszenie w dwie minuty i odbieraj odpowiedzi opiekunów z okolicy.",
    ctaBtn: "Opublikuj bezpłatne ogłoszenie",
    recruitLink: (c) => `Kochasz zwierzęta? Zostań opiekunem — ${c.name} →`,
    inLanguage: "pl",
    metaTitle: (c) => `Opiekun zwierząt ${c.name} — opieka nad psem, kotem i spacery`,
  },
  ko: {
    kicker: (c) => c.region,
    h1: (c) => `${c.name} 펫시터: 강아지 돌봄, 고양이 방문, 산책`,
    heroLead: (c) => `${c.name}에서 가까운 인증된 펫시터. 요청을 올리고, 고르고, 예약할 때만 결제하세요.`,
    proofs: ["안전 결제", "신원 인증", "72시간 무료 취소"],
    heroCta: "무료로 요청 올리기",
    heroCtaNote: "무료 · 계정 없이 시작 · 2분",
    heroAppLink: "HoPetSit 앱 다운로드 →",
    heroSecondary: "근처 펫시터 보기 →",
    intro: (c) =>
      `주말, 휴가, 긴 근무일 — ${c.name}에서 HoPetSit이 근처의 인증된 펫시터와 산책 도우미를 연결해 드립니다. 요청은 무료로 올리고, 프로필을 비교하고, 채팅한 뒤 예약할 때만 결제하세요.`,
    servicesTitle: "근처에서 받을 수 있는 서비스",
    services: [
      { icon: "🏠", t: "방문 돌봄", p: "반려동물은 익숙한 집에 그대로. 펫시터가 자고 가거나 하루에 여러 번 방문합니다." },
      { icon: "🐾", t: "고양이 방문", p: "사료, 화장실, 스킨십, 방문마다 사진 한 장 — 이동을 싫어하는 고양이에게 딱입니다." },
      { icon: "🚶", t: "강아지 산책", p: "원하는 시간에 평일 산책, 출발부터 귀가까지 지도에서 실시간으로 확인합니다." },
    ],
    whyTitle: "HoPetSit을 선택하는 이유",
    why: [
      { icon: "✓", t: "인증된 프로필", p: "신원 확인, 실제 보호자 후기, 모든 프로필에 표시되는 배지." },
      { icon: "🔒", t: "안전 결제", p: "금액은 앱에 보관되고 서비스가 끝난 뒤에만 펫시터에게 전달됩니다." },
      { icon: "📍", t: "실시간 추적", p: "PawFollow가 산책을 실시간으로 보여줍니다. 강아지가 어디 있는지 항상 알 수 있어요." },
      { icon: "🗺️", t: "PawMap", p: "근처 회원, 반려동물 친화 장소, 영업시간, 그리고 가는 길 안내까지." },
    ],
    pricesTitle: (c) => `${c.name} 펫시터 비용은 얼마인가요?`,
    prices: (c) => `${c.name}에서는 돌봄 하루 ${c.dayRate}, 산책 ${c.walkRate} 정도를 예상하세요. 요금은 펫시터가 직접 정하며, 예약 전에 프로필에서 확인할 수 있어 놀랄 일이 없습니다.`,
    faqTitle: "자주 묻는 질문",
    faq: (c) => [
      { q: `${c.name}에서 믿을 수 있는 펫시터를 어떻게 찾나요?`, a: `앱에 요청을 올리면 ${c.name}의 인증된 펫시터가 답합니다. 후기를 읽고, 채팅하고, 마음이 놓일 때만 예약하세요.` },
      { q: "결제가 정말 안전한가요?", a: "네. 예약 시 금액이 앱에 보관되고 서비스 후 펫시터에게 전달됩니다. 문제가 있으면 정산 전에 지원팀이 개입합니다." },
      { q: "강아지 산책을 따라볼 수 있나요?", a: "네, PawFollow로 출발부터 귀가까지 경로가 지도에 실시간으로 표시되고 거리와 시간도 보여요." },
      { q: "가입 비용이 있나요?", a: "없습니다. 요청 올리기와 펫시터와의 채팅은 무료예요. 예약한 돌봄 비용만 결제합니다." },
    ],
    ctaTitle: (c) => `${c.name}에서 펫시터 찾기`,
    ctaText: "2분 만에 요청을 올리면 근처 펫시터의 답을 받을 수 있어요.",
    ctaBtn: "무료로 요청 올리기",
    recruitLink: (c) => `동물을 좋아하시나요? ${c.name} 펫시터 되기 →`,
    inLanguage: "ko",
    metaTitle: (c) => `${c.name} 펫시터 — 강아지 돌봄, 고양이 방문, 산책`,
  },
  ja: {
    kicker: (c) => c.region,
    h1: (c) => `${c.name}のペットシッター：犬のお世話、猫の訪問、散歩`,
    heroLead: (c) => `${c.name}の近くにいる認証済みペットシッター。リクエストを投稿して選び、予約するときだけお支払い。`,
    proofs: ["安全な決済", "本人確認済み", "72時間前まで無料キャンセル"],
    heroCta: "リクエストを投稿",
    heroCtaNote: "無料 · アカウント不要で開始 · 2分",
    heroAppLink: "HoPetSit アプリをダウンロード →",
    heroSecondary: "近くのシッターを見る →",
    intro: (c) =>
      `週末、休暇、長い勤務日。${c.name}では、HoPetSitが近くの認証済みシッターやウォーカーとあなたをつなぎます。リクエストは無料で投稿、プロフィールを比較し、チャットして、予約するときだけお支払い。`,
    servicesTitle: "近くで受けられるサービス",
    services: [
      { icon: "🏠", t: "自宅でのお世話", p: "ペットはいつもの家で、いつもの習慣のまま。シッターが泊まるか、1日に何度か訪問します。" },
      { icon: "🐾", t: "猫の訪問ケア", p: "ごはん、トイレ、なでなで、訪問ごとに写真1枚。移動が苦手な猫に最適です。" },
      { icon: "🚶", t: "犬の散歩", p: "平日、都合のよい時間に散歩。出発から帰宅まで地図でライブ追跡できます。" },
    ],
    whyTitle: "HoPetSitを選ぶ理由",
    why: [
      { icon: "✓", t: "認証済みプロフィール", p: "本人確認済み、飼い主による本物のレビュー、すべてのプロフィールに表示されるバッジ。" },
      { icon: "🔒", t: "安全な決済", p: "お金はアプリ内に保管され、サービス完了後にのみシッターへ支払われます。" },
      { icon: "📍", t: "ライブ追跡", p: "PawFollowが散歩をリアルタイムで表示。愛犬の居場所がいつでも分かります。" },
      { icon: "🗺️", t: "PawMap", p: "近くのメンバー、ペット歓迎スポット、その営業時間、そこまでのルート案内。" },
    ],
    pricesTitle: (c) => `${c.name}のペットシッターの料金は？`,
    prices: (c) => `${c.name}では、お世話は1日${c.dayRate}、散歩は${c.walkRate}が目安です。料金はシッターが自分で設定し、予約前にプロフィールで確認できるので、驚くことはありません。`,
    faqTitle: "よくある質問",
    faq: (c) => [
      { q: `${c.name}で信頼できるペットシッターを見つけるには？`, a: `アプリでリクエストを投稿すると、${c.name}の認証済みシッターが返信します。レビューを読み、チャットし、安心できたときだけ予約してください。` },
      { q: "決済は本当に安全ですか？", a: "はい。予約時に金額がアプリ内で保管され、サービス後にシッターへ支払われます。問題があれば、支払い前にサポートが対応します。" },
      { q: "愛犬の散歩を追跡できますか？", a: "はい、PawFollowで。出発から帰宅までのルートが距離・所要時間とともに地図にライブ表示されます。" },
      { q: "登録に費用はかかりますか？", a: "かかりません。リクエストの投稿もシッターとのチャットも無料です。お支払いは予約したお世話の分だけです。" },
    ],
    ctaTitle: (c) => `${c.name}でシッターを見つける`,
    ctaText: "2分でリクエストを投稿して、近くのシッターからの返信を受け取りましょう。",
    ctaBtn: "無料でリクエストを投稿",
    recruitLink: (c) => `動物が好きですか？${c.name}でペットシッターになる →`,
    inLanguage: "ja",
    metaTitle: (c) => `${c.name}のペットシッター — 犬のお世話・猫の訪問・散歩`,
  },
};

export function ownerMetadata(c: RecruitCity, canonical: string) {
  const copy = COPY[c.lang];
  const title = copy.metaTitle(c);
  const description = copy.intro(c).slice(0, 155);
  return {
    title,
    description,
    alternates: { canonical },
    // v577 — SEO (21/09/2026). Une page qui declare son propre `openGraph`
    // REMPLACE celui du layout, elle n'en herite pas champ par champ : les 621
    // pages villes sortaient donc SANS og:image. Consequence mesuree dans le
    // HTML produit : aucune vignette quand le lien est partage sur WhatsApp,
    // Facebook ou Instagram, et aucune image candidate pour la vignette Google
    // a cote du resultat de recherche. og-image.png fait bien 1200x630 reels
    // (fichier mesure, pas seulement declare).
    openGraph: { title, description, url: canonical, type: "website" as const, siteName: "HoPetSit", images: [{ url: "https://www.hopetsit.com/og-image.png", width: 1200, height: 630, alt: "HoPetSit" }] },
  };
}

export default function OwnerCityPage({
  city,
  h1,
  children,
}: {
  city: RecruitCity;
  /** Titre H1 propre à la page (sinon le H1 générique de la langue). */
  h1?: string;
  /** Bloc supplémentaire inséré sous l'encadré local (maillage interne…). */
  children?: React.ReactNode;
}) {
  const copy = COPY[city.lang];
  // v562 — arrondissement de Paris : contenu local réel à la place des blocs génériques.
  const paris = city.lang === "fr" && !!parisEntry(city.slug);
  const faq = paris ? parisFaq(city.slug, "owner") : copy.faq(city);
  const heading = h1 ?? (paris ? `Pet sitter ${city.name} : garde et promenade` : copy.h1(city));
  const jsonLd = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "Service",
        name: copy.h1(city),
        serviceType: "Pet sitting, cat visits and dog walking",
        provider: { "@type": "Organization", name: "HoPetSit", url: "https://www.hopetsit.com" },
        areaServed: { "@type": "City", name: city.name },
        // v577 — image declaree dans les donnees structurees : c'est celle
        // que Google retient en priorite pour la vignette du resultat.
        image: "https://www.hopetsit.com/og-image.png",
        inLanguage: copy.inLanguage,
      },
      ...(faq.length ? [{
        "@type": "FAQPage",
        mainEntity: faq.map((f) => ({
          "@type": "Question",
          name: f.q,
          acceptedAnswer: { "@type": "Answer", text: f.a },
        })),
      }] : []),
    ],
  };
  const recruitHref = `${RECRUIT_PATH_PREFIX[city.lang]}/${city.slug}`;
  const nearby = paris ? [] : nearbyCities(city.lang, city.slug);

  return (
    <div className="mx-auto max-w-3xl px-4 pb-16 pt-7 md:pb-24 md:pt-16">
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }} />

      {/* v575 — PREMIER ÉCRAN (360 × 640) : titre, 3 preuves, UN bouton.
          Aucune image, aucune police supplémentaire, hauteurs fixes → pas de
          décalage de mise en page. Le texte long (intro) passe sous le pli. */}
      {!paris && <p className="text-sm font-semibold text-owner">{copy.kicker(city)}</p>}
      <h1 className="mt-1.5 font-display text-[1.6rem] font-extrabold leading-[1.15] tracking-tight text-ink md:mt-2 md:text-4xl">{heading}</h1>
      <p className="mt-3 text-[15px] leading-relaxed text-ink-muted md:text-lg">{copy.heroLead(city)}</p>

      {/* 22/09/2026 — preuve que l'offre existe vraiment (compte en direct).
          Les arrondissements interrogent « Paris » : un gardien inscrit à
          Paris dessert le 11e comme le 15e. Le bloc disparaît s'il n'y a
          personne ou si le serveur ne répond pas. */}
      <CitySupplyProof
        city={city.name.replace(/\s+\d+\s*(er|e|ème|eme|th|st|nd|rd)?$/i, "").trim() || city.name}
        lang={city.lang}
      />

      <ul className="mt-5 grid grid-cols-3 gap-2">
        {copy.proofs.map((p, i) => (
          <li key={p} className="rounded-2xl bg-bg-soft px-2 py-3 text-center">
            <span aria-hidden="true" className="block text-base leading-none">{PROOF_ICONS[i]}</span>
            <span className="mt-1.5 block text-[11px] font-semibold leading-tight text-ink md:text-xs">{p}</span>
          </li>
        ))}
      </ul>

      {/* v577 — le bouton principal mène au parcours WEB (/signup puis
          /posts/create) : publier une demande ne demande plus d'installer
          l'app. Le store reste accessible juste en dessous. */}
      <OwnerSignupCta
        label={copy.heroCta}
        city={city.name}
        className="mt-5 block w-full rounded-full bg-owner px-6 py-4 text-center text-base font-bold text-white shadow-cta transition hover:bg-owner-dark md:mx-auto md:w-auto md:min-w-[18rem]"
      />
      <p className="mt-2.5 text-center text-xs text-ink-soft">{copy.heroCtaNote}</p>
      <p className="mt-3 text-center text-sm">
        <GetAppButton label={copy.heroAppLink} className="font-semibold text-owner-dark underline-offset-4 hover:underline" />
      </p>
      <p className="mt-2 text-center text-sm">
        <Link href="/map" className="font-semibold text-owner-dark underline-offset-4 hover:underline">{copy.heroSecondary}</Link>
      </p>

      {/* ——— sous la ligne de flottaison ——— */}
      {!paris && <p className="mt-10 text-base leading-relaxed text-ink-muted md:text-lg">{copy.intro(city)}</p>}

      <div className="mt-8 rounded-2xl border border-owner/20 bg-owner-light/60 p-6">
        <p className="text-sm leading-relaxed text-ink">{city.local}</p>
      </div>

      {children}

      {paris && <ParisLocalPlaces slug={city.slug} mode="owner" />}

      {!paris && (<>
      <h2 className="mt-14 font-display text-2xl font-extrabold text-ink">{copy.servicesTitle}</h2>
      <div className="mt-6 grid gap-4 md:grid-cols-3">
        {copy.services.map((s) => (
          <div key={s.t} className="rounded-2xl border border-ink/5 bg-white p-5 shadow-card">
            <div className="text-2xl">{s.icon}</div>
            <h3 className="mt-2 text-base font-bold text-ink">{s.t}</h3>
            <p className="mt-1.5 text-sm leading-relaxed text-ink-muted">{s.p}</p>
          </div>
        ))}
      </div>

      <h2 className="mt-14 font-display text-2xl font-extrabold text-ink">{copy.whyTitle}</h2>
      <ul className="mt-6 grid gap-4 md:grid-cols-2">
        {copy.why.map((w) => (
          <li key={w.t} className="flex gap-4 rounded-2xl border border-ink/5 bg-white p-5 shadow-card">
            <div className="grid h-10 w-10 shrink-0 place-items-center rounded-xl bg-owner-light text-lg font-extrabold text-owner-dark">{w.icon}</div>
            <div>
              <h3 className="text-base font-bold text-ink">{w.t}</h3>
              <p className="mt-1 text-sm leading-relaxed text-ink-muted">{w.p}</p>
            </div>
          </li>
        ))}
      </ul>

      <div className="mt-14 rounded-2xl border border-ink/10 bg-bg-soft p-6">
        <h2 className="font-display text-xl font-extrabold text-ink">{copy.pricesTitle(city)}</h2>
        <p className="mt-2 text-sm leading-relaxed text-ink-muted">{copy.prices(city)}</p>
      </div>

      <h2 className="mt-14 font-display text-2xl font-extrabold text-ink">{copy.faqTitle}</h2>
      <div className="mt-6 space-y-4">
        {faq.map((f) => (
          <div key={f.q} className="rounded-2xl border border-ink/5 bg-white p-5 shadow-card">
            <h3 className="font-bold text-ink">{f.q}</h3>
            <p className="mt-2 text-sm leading-relaxed text-ink-muted">{f.a}</p>
          </div>
        ))}
      </div>
      </>)}

      <div className="mt-14 rounded-3xl bg-owner-light p-8 text-center">
        <h2 className="font-display text-2xl font-extrabold text-ink">{paris ? `${city.name} avec HoPetSit` : copy.ctaTitle(city)}</h2>
        {!paris && <p className="mx-auto mt-2 max-w-md text-sm text-ink-muted">{copy.ctaText}</p>}
        <OwnerSignupCta label={paris ? "Publier ma demande" : copy.ctaBtn} city={city.name} className="mt-5 inline-block rounded-full bg-owner px-7 py-3 text-sm font-bold text-white" />
      </div>

      <p className="mt-8 text-center text-sm">
        <Link href={recruitHref} className="font-semibold text-sitter-dark underline-offset-4 hover:underline">{paris ? `${city.name} : devenir pet sitter →` : copy.recruitLink(city)}</Link>
      </p>

      {/* v576 — villes voisines : donne à Google un chemin depuis les pages déjà
          indexées vers celles qu'il n'a jamais explorées. Paris a déjà son propre
          maillage (ParisLocalPlaces), on ne le double pas. */}
      {!paris && nearby.length > 0 && (
        <nav aria-label={NEARBY_LABEL[city.lang]} className="mt-10 border-t border-black/5 pt-6">
          <h2 className="text-sm font-semibold text-ink">{NEARBY_LABEL[city.lang]}</h2>
          <ul className="mt-3 flex flex-wrap gap-x-4 gap-y-2 text-sm">
            {nearby.map((n) => (
              <li key={n.slug}>
                <Link href={`${OWNER_PATH_PREFIX[n.lang]}/${n.slug}`} className="text-owner underline-offset-4 hover:underline">{n.name}</Link>
              </li>
            ))}
          </ul>
        </nav>
      )}
    </div>
  );
}

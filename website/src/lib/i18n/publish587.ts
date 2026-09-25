// v587 (point 8 de Daniel) — LIEU DU SERVICE sur le site (« Publier une annonce »
// /posts/create, réservation directe /book, liste /posts). Mêmes options et
// mêmes libellés que l'app (frontend/lib/localization/v565/publish587_i18n.dart) :
//   garde (house_sitting, pet_sitting, day_care, long_stay) : at_owner | at_sitter
//   promenade (dog_walking) : pickup | meeting_point (+ meetingPoint = adresse / quartier)
//   visites (home_visit) : at_owner, fixé
// Fichier autonome (pas de fusion dans translations.ts) : `p587(lang, clé)`.
import type { Lang } from "./translations";

type D = Record<string, string>;

export const PUBLISH587: Record<Lang, D> = {
  en: {
    svc587_title_sitting: "Where will the care take place?",
    svc587_title_walk: "Where does the walk start?",
    svc587_title_visit: "Where are the visits?",
    svc587_opt_at_owner: "At my home",
    svc587_opt_at_owner_sub: "The sitter comes to your place",
    svc587_opt_at_sitter: "At the sitter's",
    svc587_opt_at_sitter_sub: "You drop your pet off at their place",
    svc587_opt_both: "Either suits me",
    svc587_opt_pickup: "Pick up at my home",
    svc587_opt_pickup_sub: "The walker comes to collect your dog",
    svc587_opt_meeting: "Meeting point",
    svc587_opt_meeting_sub: "You meet at an agreed place",
    svc587_meeting_hint: "Address or neighbourhood (e.g. Central Park)",
    svc587_visit_fixed: "At my home: the sitter visits you",
    svc587_required: "Choose where the service takes place.",
    svc587_meeting_required: "Enter the address or neighbourhood of the meeting point.",
    svc587_field: "Service location",
    svc587_show_at_owner: "At the owner's home",
    svc587_show_at_sitter: "At the sitter's home",
    svc587_show_both: "Owner's or sitter's home",
    svc587_show_pickup: "Pick-up at the owner's home",
    svc587_show_meeting: "Meeting point",
  },
  fr: {
    svc587_title_sitting: "Où se passe la garde ?",
    svc587_title_walk: "Où commence la promenade ?",
    svc587_title_visit: "Où se font les visites ?",
    svc587_opt_at_owner: "Chez moi",
    svc587_opt_at_owner_sub: "Le gardien vient chez toi",
    svc587_opt_at_sitter: "Chez le gardien",
    svc587_opt_at_sitter_sub: "Tu déposes ton animal chez lui",
    svc587_opt_both: "Les deux me conviennent",
    svc587_opt_pickup: "Récupérer chez moi",
    svc587_opt_pickup_sub: "Le promeneur vient chercher ton chien",
    svc587_opt_meeting: "Point de rendez-vous",
    svc587_opt_meeting_sub: "Vous vous retrouvez à un endroit convenu",
    svc587_meeting_hint: "Adresse ou quartier (ex. parc Monceau)",
    svc587_visit_fixed: "Chez moi : le gardien passe à ton domicile",
    svc587_required: "Choisis où se passe le service.",
    svc587_meeting_required: "Indique l'adresse ou le quartier du rendez-vous.",
    svc587_field: "Lieu du service",
    svc587_show_at_owner: "Chez le propriétaire",
    svc587_show_at_sitter: "Chez le gardien",
    svc587_show_both: "Chez le propriétaire ou le gardien",
    svc587_show_pickup: "Prise en charge au domicile",
    svc587_show_meeting: "Point de rendez-vous",
  },
  es: {
    svc587_title_sitting: "¿Dónde será el cuidado?",
    svc587_title_walk: "¿Dónde empieza el paseo?",
    svc587_title_visit: "¿Dónde son las visitas?",
    svc587_opt_at_owner: "En mi casa",
    svc587_opt_at_owner_sub: "El cuidador va a tu casa",
    svc587_opt_at_sitter: "En casa del cuidador",
    svc587_opt_at_sitter_sub: "Dejas a tu mascota en su casa",
    svc587_opt_both: "Me valen las dos",
    svc587_opt_pickup: "Recoger en mi casa",
    svc587_opt_pickup_sub: "El paseador viene a buscar a tu perro",
    svc587_opt_meeting: "Punto de encuentro",
    svc587_opt_meeting_sub: "Quedáis en un lugar acordado",
    svc587_meeting_hint: "Dirección o barrio (p. ej. parque del Retiro)",
    svc587_visit_fixed: "En mi casa: el cuidador te visita",
    svc587_required: "Elige dónde se hace el servicio.",
    svc587_meeting_required: "Indica la dirección o el barrio del punto de encuentro.",
    svc587_field: "Lugar del servicio",
    svc587_show_at_owner: "En casa del dueño",
    svc587_show_at_sitter: "En casa del cuidador",
    svc587_show_both: "En casa del dueño o del cuidador",
    svc587_show_pickup: "Recogida en casa del dueño",
    svc587_show_meeting: "Punto de encuentro",
  },
  de: {
    svc587_title_sitting: "Wo findet die Betreuung statt?",
    svc587_title_walk: "Wo beginnt der Spaziergang?",
    svc587_title_visit: "Wo finden die Besuche statt?",
    svc587_opt_at_owner: "Bei mir zu Hause",
    svc587_opt_at_owner_sub: "Der Tiersitter kommt zu dir",
    svc587_opt_at_sitter: "Beim Tiersitter",
    svc587_opt_at_sitter_sub: "Du bringst dein Tier zu ihm",
    svc587_opt_both: "Beides passt mir",
    svc587_opt_pickup: "Bei mir abholen",
    svc587_opt_pickup_sub: "Der Gassigeher holt deinen Hund ab",
    svc587_opt_meeting: "Treffpunkt",
    svc587_opt_meeting_sub: "Ihr trefft euch an einem vereinbarten Ort",
    svc587_meeting_hint: "Adresse oder Viertel (z. B. Tiergarten)",
    svc587_visit_fixed: "Bei mir zu Hause: Der Tiersitter besucht dich",
    svc587_required: "Wähle, wo der Service stattfindet.",
    svc587_meeting_required: "Gib die Adresse oder das Viertel des Treffpunkts an.",
    svc587_field: "Ort des Service",
    svc587_show_at_owner: "Beim Besitzer",
    svc587_show_at_sitter: "Beim Tiersitter",
    svc587_show_both: "Beim Besitzer oder Tiersitter",
    svc587_show_pickup: "Abholung beim Besitzer",
    svc587_show_meeting: "Treffpunkt",
  },
  it: {
    svc587_title_sitting: "Dove si svolge la custodia?",
    svc587_title_walk: "Dove inizia la passeggiata?",
    svc587_title_visit: "Dove si svolgono le visite?",
    svc587_opt_at_owner: "A casa mia",
    svc587_opt_at_owner_sub: "Il pet sitter viene da te",
    svc587_opt_at_sitter: "A casa del pet sitter",
    svc587_opt_at_sitter_sub: "Porti il tuo animale da lui",
    svc587_opt_both: "Vanno bene entrambi",
    svc587_opt_pickup: "Ritiro a casa mia",
    svc587_opt_pickup_sub: "Il dog walker viene a prendere il tuo cane",
    svc587_opt_meeting: "Punto d'incontro",
    svc587_opt_meeting_sub: "Vi incontrate in un luogo concordato",
    svc587_meeting_hint: "Indirizzo o quartiere (es. parco Sempione)",
    svc587_visit_fixed: "A casa mia: il pet sitter passa da te",
    svc587_required: "Scegli dove si svolge il servizio.",
    svc587_meeting_required: "Indica l'indirizzo o il quartiere del punto d'incontro.",
    svc587_field: "Luogo del servizio",
    svc587_show_at_owner: "A casa del proprietario",
    svc587_show_at_sitter: "A casa del pet sitter",
    svc587_show_both: "A casa del proprietario o del pet sitter",
    svc587_show_pickup: "Ritiro a casa del proprietario",
    svc587_show_meeting: "Punto d'incontro",
  },
  pt: {
    svc587_title_sitting: "Onde decorre o cuidado?",
    svc587_title_walk: "Onde começa o passeio?",
    svc587_title_visit: "Onde são as visitas?",
    svc587_opt_at_owner: "Em minha casa",
    svc587_opt_at_owner_sub: "O pet sitter vai a tua casa",
    svc587_opt_at_sitter: "Em casa do pet sitter",
    svc587_opt_at_sitter_sub: "Deixas o teu animal em casa dele",
    svc587_opt_both: "Qualquer um me serve",
    svc587_opt_pickup: "Recolher em minha casa",
    svc587_opt_pickup_sub: "O passeador vem buscar o teu cão",
    svc587_opt_meeting: "Ponto de encontro",
    svc587_opt_meeting_sub: "Encontram-se num local combinado",
    svc587_meeting_hint: "Morada ou bairro (ex. Jardim da Estrela)",
    svc587_visit_fixed: "Em minha casa: o pet sitter visita-te",
    svc587_required: "Escolhe onde decorre o serviço.",
    svc587_meeting_required: "Indica a morada ou o bairro do ponto de encontro.",
    svc587_field: "Local do serviço",
    svc587_show_at_owner: "Em casa do dono",
    svc587_show_at_sitter: "Em casa do pet sitter",
    svc587_show_both: "Em casa do dono ou do pet sitter",
    svc587_show_pickup: "Recolha em casa do dono",
    svc587_show_meeting: "Ponto de encontro",
  },
  ko: {
    svc587_title_sitting: "돌봄 장소는 어디인가요?",
    svc587_title_walk: "산책은 어디서 시작하나요?",
    svc587_title_visit: "방문 장소는 어디인가요?",
    svc587_opt_at_owner: "우리 집",
    svc587_opt_at_owner_sub: "시터가 집으로 방문해요",
    svc587_opt_at_sitter: "시터의 집",
    svc587_opt_at_sitter_sub: "반려동물을 시터 집에 맡겨요",
    svc587_opt_both: "둘 다 괜찮아요",
    svc587_opt_pickup: "집에서 픽업",
    svc587_opt_pickup_sub: "워커가 강아지를 데리러 와요",
    svc587_opt_meeting: "만남 장소",
    svc587_opt_meeting_sub: "약속한 장소에서 만나요",
    svc587_meeting_hint: "주소 또는 동네 (예: 서울숲)",
    svc587_visit_fixed: "우리 집: 시터가 집으로 방문해요",
    svc587_required: "서비스 장소를 선택하세요.",
    svc587_meeting_required: "만남 장소의 주소나 동네를 입력하세요.",
    svc587_field: "서비스 장소",
    svc587_show_at_owner: "보호자 집",
    svc587_show_at_sitter: "시터 집",
    svc587_show_both: "보호자 집 또는 시터 집",
    svc587_show_pickup: "보호자 집에서 픽업",
    svc587_show_meeting: "만남 장소",
  },
  ja: {
    svc587_title_sitting: "お世話の場所はどこですか？",
    svc587_title_walk: "散歩はどこから始めますか？",
    svc587_title_visit: "訪問先はどこですか？",
    svc587_opt_at_owner: "自宅",
    svc587_opt_at_owner_sub: "シッターがあなたの家に来ます",
    svc587_opt_at_sitter: "シッターの家",
    svc587_opt_at_sitter_sub: "ペットをシッターの家に預けます",
    svc587_opt_both: "どちらでも大丈夫",
    svc587_opt_pickup: "自宅でお迎え",
    svc587_opt_pickup_sub: "ウォーカーが犬を迎えに来ます",
    svc587_opt_meeting: "待ち合わせ場所",
    svc587_opt_meeting_sub: "決めた場所で待ち合わせます",
    svc587_meeting_hint: "住所またはエリア（例：代々木公園）",
    svc587_visit_fixed: "自宅：シッターが訪問します",
    svc587_required: "サービスの場所を選んでください。",
    svc587_meeting_required: "待ち合わせ場所の住所またはエリアを入力してください。",
    svc587_field: "サービスの場所",
    svc587_show_at_owner: "飼い主の自宅",
    svc587_show_at_sitter: "シッターの自宅",
    svc587_show_both: "飼い主またはシッターの自宅",
    svc587_show_pickup: "飼い主の自宅でお迎え",
    svc587_show_meeting: "待ち合わせ場所",
  },
  pl: {
    svc587_title_sitting: "Gdzie odbędzie się opieka?",
    svc587_title_walk: "Gdzie zaczyna się spacer?",
    svc587_title_visit: "Gdzie odbywają się wizyty?",
    svc587_opt_at_owner: "U mnie w domu",
    svc587_opt_at_owner_sub: "Opiekun przychodzi do ciebie",
    svc587_opt_at_sitter: "U opiekuna",
    svc587_opt_at_sitter_sub: "Zostawiasz zwierzę u niego",
    svc587_opt_both: "Obie opcje mi pasują",
    svc587_opt_pickup: "Odbiór z mojego domu",
    svc587_opt_pickup_sub: "Wyprowadzacz przychodzi po twojego psa",
    svc587_opt_meeting: "Miejsce spotkania",
    svc587_opt_meeting_sub: "Spotykacie się w umówionym miejscu",
    svc587_meeting_hint: "Adres lub dzielnica (np. Pole Mokotowskie)",
    svc587_visit_fixed: "U mnie w domu: opiekun cię odwiedza",
    svc587_required: "Wybierz, gdzie odbywa się usługa.",
    svc587_meeting_required: "Podaj adres lub dzielnicę miejsca spotkania.",
    svc587_field: "Miejsce usługi",
    svc587_show_at_owner: "U właściciela",
    svc587_show_at_sitter: "U opiekuna",
    svc587_show_both: "U właściciela lub opiekuna",
    svc587_show_pickup: "Odbiór z domu właściciela",
    svc587_show_meeting: "Miejsce spotkania",
  },
};

/** Texte traduit (repli anglais, puis la clé). */
export const p587 = (lang: Lang, key: string): string =>
  PUBLISH587[lang]?.[key] ?? PUBLISH587.en[key] ?? key;

export type ServiceLocation = "at_owner" | "at_sitter" | "both" | "pickup" | "meeting_point";
export type LocationFamily = "sitting" | "walk" | "visit";

const VISITS = new Set(["home_visit", "drop_in", "drop_in_visit", "pet_visit", "visit", "visits"]);

export function locationFamily(service?: string | null): LocationFamily | null {
  const s = String(service || "").trim().toLowerCase();
  if (!s) return null;
  if (s === "dog_walking" || s === "walking") return "walk";
  if (VISITS.has(s)) return "visit";
  return "sitting";
}

/** Options proposées pour un service (l'ancien « both » reste si déjà choisi). */
export function locationOptions(service?: string | null, current?: string | null): ServiceLocation[] {
  switch (locationFamily(service)) {
    case "walk": return ["pickup", "meeting_point"];
    case "visit": return ["at_owner"];
    case "sitting": return current === "both" ? ["at_owner", "at_sitter", "both"] : ["at_owner", "at_sitter"];
    default: return [];
  }
}

export function locationTitleKey(service?: string | null): string {
  const f = locationFamily(service);
  return f === "walk" ? "svc587_title_walk" : f === "visit" ? "svc587_title_visit" : "svc587_title_sitting";
}

export const OPTION_KEYS: Record<ServiceLocation, { label: string; sub: string }> = {
  at_owner: { label: "svc587_opt_at_owner", sub: "svc587_opt_at_owner_sub" },
  at_sitter: { label: "svc587_opt_at_sitter", sub: "svc587_opt_at_sitter_sub" },
  both: { label: "svc587_opt_both", sub: "" },
  pickup: { label: "svc587_opt_pickup", sub: "svc587_opt_pickup_sub" },
  meeting_point: { label: "svc587_opt_meeting", sub: "svc587_opt_meeting_sub" },
};

/** Le choix est-il complet pour ce service (adresse du RDV comprise) ? */
export function locationComplete(service: string | null | undefined, value: string, meetingPoint: string): boolean {
  if (locationFamily(service) === "visit") return true;
  if (!locationOptions(service, value).includes(value as ServiceLocation)) return false;
  return value !== "meeting_point" || meetingPoint.trim().length > 0;
}

/** Valeur à envoyer au serveur (undefined si rien de valable). */
export function locationToSend(service: string | null | undefined, value: string): ServiceLocation | undefined {
  if (locationFamily(service) === "visit") return "at_owner";
  return locationOptions(service, value).includes(value as ServiceLocation) ? (value as ServiceLocation) : undefined;
}

/** Libellé NEUTRE (lu par le propriétaire et le prestataire). */
export function locationDisplay(
  lang: Lang,
  post: { serviceLocation?: string | null; meetingPoint?: string | null; houseSittingVenue?: string | null },
): string {
  const sl = String(post.serviceLocation || "");
  if (sl === "at_owner") return p587(lang, "svc587_show_at_owner");
  if (sl === "at_sitter") return p587(lang, "svc587_show_at_sitter");
  if (sl === "both") return p587(lang, "svc587_show_both");
  if (sl === "pickup") return p587(lang, "svc587_show_pickup");
  if (sl === "meeting_point") {
    const place = String(post.meetingPoint || "").trim();
    return place ? `${p587(lang, "svc587_show_meeting")} · ${place}` : p587(lang, "svc587_show_meeting");
  }
  if (post.houseSittingVenue === "owners_home") return p587(lang, "svc587_show_at_owner");
  if (post.houseSittingVenue === "sitters_home") return p587(lang, "svc587_show_at_sitter");
  return "";
}

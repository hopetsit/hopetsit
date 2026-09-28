// 28/09/2026 (LEO) — « Demander à <prénom> » depuis la carte publique (/pawmap)
// et le profil public (/p/<rôle>/<id>). Mesure du 28/09 : /pawmap 20 visiteurs
// → 0 clic, /map 36 → 0. Un visiteur sans compte n'avait qu'un « Inscris-toi »
// qui l'envoyait vers une inscription SÉPARÉE de sa demande.
//
// Le bouton ouvre la demande de NEO (/posts/create) avec la ville du
// prestataire pré-remplie : le compte propriétaire s'y crée sur le même écran.
// Le serveur ne sait pas (encore) adresser une demande à UN prestataire
// précis : elle part aux prestataires de la ville — c'est ce que dit la note.
// Fichier autonome : `dm(lang, clé)`. {name} et {city} ne se traduisent pas.
import type { Lang } from "./langs";

type D = Record<"ask" | "ask_any" | "note_city" | "note" | "profile" | "book", string>;

export const DEMANDER: Record<Lang, D> = {
  fr: {
    ask: "Demander à {name}",
    ask_any: "Faire une demande",
    note_city: "Gratuit, sans engagement. Ta demande part aux gardiens et promeneurs de {city}.",
    note: "Gratuit, sans engagement. Ta demande part aux gardiens et promeneurs près de chez toi.",
    profile: "Voir le profil",
    book: "Réserver",
  },
  en: {
    ask: "Ask {name}",
    ask_any: "Make a request",
    note_city: "Free, no commitment. Your request goes to sitters and walkers in {city}.",
    note: "Free, no commitment. Your request goes to sitters and walkers near you.",
    profile: "See profile",
    book: "Book",
  },
  es: {
    ask: "Pedir a {name}",
    ask_any: "Hacer una solicitud",
    note_city: "Gratis y sin compromiso. Tu solicitud llega a los cuidadores y paseadores de {city}.",
    note: "Gratis y sin compromiso. Tu solicitud llega a los cuidadores y paseadores cerca de ti.",
    profile: "Ver el perfil",
    book: "Reservar",
  },
  de: {
    ask: "{name} anfragen",
    ask_any: "Anfrage stellen",
    note_city: "Kostenlos und unverbindlich. Deine Anfrage geht an die Sitter und Gassigeher in {city}.",
    note: "Kostenlos und unverbindlich. Deine Anfrage geht an die Sitter und Gassigeher in deiner Nähe.",
    profile: "Profil ansehen",
    book: "Buchen",
  },
  it: {
    ask: "Chiedi a {name}",
    ask_any: "Fai una richiesta",
    note_city: "Gratis, senza impegno. La tua richiesta arriva ai pet sitter e dog walker di {city}.",
    note: "Gratis, senza impegno. La tua richiesta arriva ai pet sitter e dog walker vicino a te.",
    profile: "Vedi il profilo",
    book: "Prenota",
  },
  pt: {
    ask: "Pedir a {name}",
    ask_any: "Fazer um pedido",
    note_city: "Grátis, sem compromisso. O teu pedido chega aos cuidadores e passeadores de {city}.",
    note: "Grátis, sem compromisso. O teu pedido chega aos cuidadores e passeadores perto de ti.",
    profile: "Ver o perfil",
    book: "Reservar",
  },
  pl: {
    ask: "Zapytaj: {name}",
    ask_any: "Wyślij prośbę",
    note_city: "Za darmo, bez zobowiązań. Twoja prośba trafi do opiekunów i wyprowadzających psy w {city}.",
    note: "Za darmo, bez zobowiązań. Twoja prośba trafi do opiekunów i wyprowadzających psy w pobliżu.",
    profile: "Zobacz profil",
    book: "Zarezerwuj",
  },
  ja: {
    ask: "{name}さんに依頼",
    ask_any: "依頼する",
    note_city: "無料・義務なし。依頼は{city}のシッターとお散歩代行に届きます。",
    note: "無料・義務なし。依頼は近くのシッターとお散歩代行に届きます。",
    profile: "プロフィールを見る",
    book: "予約",
  },
  ko: {
    ask: "{name}님에게 요청",
    ask_any: "요청하기",
    note_city: "무료, 부담 없음. 요청은 {city}의 시터와 산책 도우미에게 전달됩니다.",
    note: "무료, 부담 없음. 요청은 근처의 시터와 산책 도우미에게 전달됩니다.",
    profile: "프로필 보기",
    book: "예약",
  },
};

export const dm = (lang: Lang, key: keyof D): string =>
  DEMANDER[lang]?.[key] ?? DEMANDER.en[key] ?? key;

/** Libellé du bouton : « Demander à Marie », ou générique sans prénom. */
export const askLabel = (lang: Lang, name?: string | null): string => {
  const first = (name || "").trim().split(/\s+/)[0];
  return first ? dm(lang, "ask").replace("{name}", first) : dm(lang, "ask_any");
};

/** Note sous le bouton (ville du prestataire si connue). */
export const askNote = (lang: Lang, city?: string | null): string => {
  const c = (city || "").trim();
  return c ? dm(lang, "note_city").replace("{city}", c) : dm(lang, "note");
};

/** La demande de NEO, ville du prestataire pré-remplie (seul paramètre lu). */
export const askHref = (city?: string | null): string => {
  const c = (city || "").trim();
  return c ? `/posts/create?city=${encodeURIComponent(c)}` : "/posts/create";
};

// 28/09/2026 (LEO) — « Demander à <prénom> » depuis la carte publique (/pawmap)
// et le profil public (/p/<rôle>/<id>). Mesure du 28/09 : /pawmap 20 visiteurs
// → 0 clic, /map 36 → 0. Un visiteur sans compte n'avait qu'un « Inscris-toi »
// qui l'envoyait vers une inscription SÉPARÉE de sa demande.
//
// Le bouton ouvre la demande de NEO (/posts/create) avec la ville du
// prestataire pré-remplie : le compte propriétaire s'y crée sur le même écran.
// 28/09 soir (NEO) — la demande est maintenant ADRESSÉE au prestataire :
// `askHref` ajoute `&for=<rôle>:<id>`, le serveur le prévient en premier
// (notification « <Prénom> vous a choisi »), puis la ville comme avant.
// La note sous le bouton le dit (note_for_city / note_for).
// Fichier autonome : `dm(lang, clé)`. {name} et {city} ne se traduisent pas.
import type { Lang } from "./langs";

type D = Record<"ask" | "ask_any" | "note_city" | "note" | "note_for_city" | "note_for" | "profile" | "book", string>;

export const DEMANDER: Record<Lang, D> = {
  fr: {
    ask: "Demander à {name}",
    ask_any: "Faire une demande",
    note_city: "Gratuit, sans engagement. Ta demande part aux gardiens et promeneurs de {city}.",
    note: "Gratuit, sans engagement. Ta demande part aux gardiens et promeneurs près de chez toi.",
    note_for_city: "Gratuit, sans engagement. {name} est prévenu·e en premier, puis les autres gardiens et promeneurs de {city}.",
    note_for: "Gratuit, sans engagement. {name} est prévenu·e en premier, puis les autres gardiens et promeneurs près de chez toi.",
    profile: "Voir le profil",
    book: "Réserver",
  },
  en: {
    ask: "Ask {name}",
    ask_any: "Make a request",
    note_city: "Free, no commitment. Your request goes to sitters and walkers in {city}.",
    note: "Free, no commitment. Your request goes to sitters and walkers near you.",
    note_for_city: "Free, no commitment. {name} is notified first, then the other sitters and walkers in {city}.",
    note_for: "Free, no commitment. {name} is notified first, then the other sitters and walkers near you.",
    profile: "See profile",
    book: "Book",
  },
  es: {
    ask: "Pedir a {name}",
    ask_any: "Hacer una solicitud",
    note_city: "Gratis y sin compromiso. Tu solicitud llega a los cuidadores y paseadores de {city}.",
    note: "Gratis y sin compromiso. Tu solicitud llega a los cuidadores y paseadores cerca de ti.",
    note_for_city: "Gratis y sin compromiso. {name} recibe el aviso primero y después los demás cuidadores y paseadores de {city}.",
    note_for: "Gratis y sin compromiso. {name} recibe el aviso primero y después los demás cuidadores y paseadores cerca de ti.",
    profile: "Ver el perfil",
    book: "Reservar",
  },
  de: {
    ask: "{name} anfragen",
    ask_any: "Anfrage stellen",
    note_city: "Kostenlos und unverbindlich. Deine Anfrage geht an die Sitter und Gassigeher in {city}.",
    note: "Kostenlos und unverbindlich. Deine Anfrage geht an die Sitter und Gassigeher in deiner Nähe.",
    note_for_city: "Kostenlos und unverbindlich. {name} wird zuerst benachrichtigt, danach die anderen Sitter und Gassigeher in {city}.",
    note_for: "Kostenlos und unverbindlich. {name} wird zuerst benachrichtigt, danach die anderen Sitter und Gassigeher in deiner Nähe.",
    profile: "Profil ansehen",
    book: "Buchen",
  },
  it: {
    ask: "Chiedi a {name}",
    ask_any: "Fai una richiesta",
    note_city: "Gratis, senza impegno. La tua richiesta arriva ai pet sitter e dog walker di {city}.",
    note: "Gratis, senza impegno. La tua richiesta arriva ai pet sitter e dog walker vicino a te.",
    note_for_city: "Gratis, senza impegno. {name} viene avvisato per primo, poi gli altri pet sitter e dog walker di {city}.",
    note_for: "Gratis, senza impegno. {name} viene avvisato per primo, poi gli altri pet sitter e dog walker vicino a te.",
    profile: "Vedi il profilo",
    book: "Prenota",
  },
  pt: {
    ask: "Pedir a {name}",
    ask_any: "Fazer um pedido",
    note_city: "Grátis, sem compromisso. O teu pedido chega aos cuidadores e passeadores de {city}.",
    note: "Grátis, sem compromisso. O teu pedido chega aos cuidadores e passeadores perto de ti.",
    note_for_city: "Grátis, sem compromisso. {name} é avisado primeiro, depois os outros cuidadores e passeadores de {city}.",
    note_for: "Grátis, sem compromisso. {name} é avisado primeiro, depois os outros cuidadores e passeadores perto de ti.",
    profile: "Ver o perfil",
    book: "Reservar",
  },
  pl: {
    ask: "Zapytaj: {name}",
    ask_any: "Wyślij prośbę",
    note_city: "Za darmo, bez zobowiązań. Twoja prośba trafi do opiekunów i wyprowadzających psy w {city}.",
    note: "Za darmo, bez zobowiązań. Twoja prośba trafi do opiekunów i wyprowadzających psy w pobliżu.",
    note_for_city: "Za darmo, bez zobowiązań. {name} dostanie powiadomienie jako pierwsza osoba, potem pozostali opiekunowie i wyprowadzający psy w {city}.",
    note_for: "Za darmo, bez zobowiązań. {name} dostanie powiadomienie jako pierwsza osoba, potem pozostali opiekunowie i wyprowadzający psy w pobliżu.",
    profile: "Zobacz profil",
    book: "Zarezerwuj",
  },
  ja: {
    ask: "{name}さんに依頼",
    ask_any: "依頼する",
    note_city: "無料・義務なし。依頼は{city}のシッターとお散歩代行に届きます。",
    note: "無料・義務なし。依頼は近くのシッターとお散歩代行に届きます。",
    note_for_city: "無料・義務なし。まず{name}さんに通知され、その後{city}の他のシッターとお散歩代行にも届きます。",
    note_for: "無料・義務なし。まず{name}さんに通知され、その後近くの他のシッターとお散歩代行にも届きます。",
    profile: "プロフィールを見る",
    book: "予約",
  },
  ko: {
    ask: "{name}님에게 요청",
    ask_any: "요청하기",
    note_city: "무료, 부담 없음. 요청은 {city}의 시터와 산책 도우미에게 전달됩니다.",
    note: "무료, 부담 없음. 요청은 근처의 시터와 산책 도우미에게 전달됩니다.",
    note_for_city: "무료, 부담 없음. {name}님에게 먼저 알림이 가고, 그다음 {city}의 다른 시터와 산책 도우미에게 전달됩니다.",
    note_for: "무료, 부담 없음. {name}님에게 먼저 알림이 가고, 그다음 근처의 다른 시터와 산책 도우미에게 전달됩니다.",
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

/** Note sous le bouton : avec le prénom du prestataire (prévenu en premier), ville si connue. */
export const askNote = (lang: Lang, city?: string | null, name?: string | null): string => {
  const c = (city || "").trim();
  const first = (name || "").trim().split(/\s+/)[0];
  if (first) {
    return c
      ? dm(lang, "note_for_city").replace("{name}", first).replace("{city}", c)
      : dm(lang, "note_for").replace("{name}", first);
  }
  return c ? dm(lang, "note_city").replace("{city}", c) : dm(lang, "note");
};

export type AskRole = "sitter" | "walker";
const ID_RE = /^[a-f0-9]{24}$/i;

/**
 * La demande de NEO : ville pré-remplie, et `for=<rôle>:<id>` quand le bouton
 * vise un prestataire précis (il est prévenu en premier par le serveur).
 */
export const askHref = (city?: string | null, role?: AskRole | string | null, id?: string | null): string => {
  const c = (city || "").trim();
  const q: string[] = [];
  if (c) q.push(`city=${encodeURIComponent(c)}`);
  const r = String(role || "").trim();
  const i = String(id || "").trim();
  if ((r === "sitter" || r === "walker") && ID_RE.test(i)) q.push(`for=${r}:${i}`);
  return q.length ? `/posts/create?${q.join("&")}` : "/posts/create";
};

/** Lecture de `?for=` : { role, id } ou null si la valeur n'a pas la forme attendue. */
export const parseAskFor = (raw?: string | null): { role: AskRole; id: string } | null => {
  const m = /^(sitter|walker):([a-f0-9]{24})$/i.exec(String(raw || "").trim());
  return m ? { role: m[1].toLowerCase() as AskRole, id: m[2] } : null;
};

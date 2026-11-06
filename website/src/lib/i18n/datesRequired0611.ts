// 06/11/2026 (NEO, ordre de Daniel « dates obligatoires ») — textes des dates OBLIGATOIRES
// pour toute nouvelle demande créée sur le site (/posts/create, formulaire des pages villes,
// /posts/confirmer). Mesure de FLO (14 j) : 19 demandes sur 45 avec candidats étaient « dates à
// prévoir » → aucun prix total, le bouton « Payer » n'apparaissait jamais (409 DATES_REQUIRED),
// 0 paiement. Fichier autonome (pas de fusion dans translations.ts) : `dr(lang, clé)`.
// 9 langues, tutoiement comme le reste du formulaire.
import type { Lang } from "./langs";

type D = Record<string, string>;

export const DATES_REQUIRED_0611: Record<Lang, D> = {
  fr: {
    hint: "Les gardiens te répondent avec un prix précis seulement si tu donnes tes dates.",
    walk_required: "Indique la date et l'heure de la balade.",
    dates_fail: "Ta demande est publiée, mais tes dates n'ont pas été enregistrées : pose-les depuis « Voir ma demande ».",
  },
  en: {
    hint: "Sitters reply with an exact price only if you give your dates.",
    walk_required: "Enter the date and time of the walk.",
    dates_fail: "Your request is live, but your dates weren't saved: set them from “See my request”.",
  },
  es: {
    hint: "Los cuidadores te responden con un precio exacto solo si indicas tus fechas.",
    walk_required: "Indica la fecha y la hora del paseo.",
    dates_fail: "Tu solicitud está publicada, pero tus fechas no se guardaron: indícalas desde «Ver mi solicitud».",
  },
  de: {
    hint: "Tiersitter antworten nur mit einem genauen Preis, wenn du deine Daten angibst.",
    walk_required: "Gib Datum und Uhrzeit des Spaziergangs an.",
    dates_fail: "Deine Anfrage ist online, aber deine Daten wurden nicht gespeichert: trage sie unter „Meine Anfrage ansehen“ ein.",
  },
  it: {
    hint: "I pet sitter ti rispondono con un prezzo preciso solo se indichi le tue date.",
    walk_required: "Indica la data e l'ora della passeggiata.",
    dates_fail: "La tua richiesta è pubblicata, ma le date non sono state salvate: inseriscile da «Vedi la mia richiesta».",
  },
  pt: {
    hint: "Os cuidadores respondem com um preço exato apenas se indicares as tuas datas.",
    walk_required: "Indica a data e a hora do passeio.",
    dates_fail: "O teu pedido está publicado, mas as datas não foram guardadas: define-as em «Ver o meu pedido».",
  },
  ko: {
    hint: "날짜를 알려주셔야 돌보미가 정확한 가격으로 답할 수 있어요.",
    walk_required: "산책 날짜와 시간을 입력해 주세요.",
    dates_fail: "요청은 게시되었지만 날짜가 저장되지 않았어요. ‘내 요청 보기’에서 날짜를 설정해 주세요.",
  },
  ja: {
    hint: "日程を入力すると、シッターから正確な料金で返事が届きます。",
    walk_required: "散歩の日付と時間を入力してください。",
    dates_fail: "リクエストは公開されましたが、日程は保存されませんでした。「リクエストを見る」から設定してください。",
  },
  pl: {
    hint: "Opiekunowie odpowiedzą z dokładną ceną tylko, jeśli podasz swoje daty.",
    walk_required: "Podaj datę i godzinę spaceru.",
    dates_fail: "Twoje ogłoszenie jest opublikowane, ale daty nie zostały zapisane: ustaw je w „Zobacz moje ogłoszenie”.",
  },
};

export function dr(lang: Lang | string, key: string): string {
  const l = (lang in DATES_REQUIRED_0611 ? lang : "fr") as Lang;
  return DATES_REQUIRED_0611[l][key] ?? DATES_REQUIRED_0611.fr[key] ?? key;
}

/** « 2026-11-20 » + « 10:00 » (heure locale du navigateur) → ISO ; vide si illisible. */
export function walkStartIso0611(day: string, time: string): string {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(day) || !/^\d{2}:\d{2}$/.test(time)) return "";
  const d = new Date(`${day}T${time}:00`);
  return Number.isNaN(d.getTime()) ? "" : d.toISOString();
}

/** Fin d'une balade = début + durée (minutes, 60 par défaut, jamais moins de 15). */
export function walkEndIso0611(startIso: string, minutes?: number | null): string {
  const start = new Date(startIso);
  if (Number.isNaN(start.getTime())) return "";
  const m = Math.max(15, Number(minutes) || 60);
  return new Date(start.getTime() + m * 60000).toISOString();
}

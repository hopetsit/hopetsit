// 25/09/2026 — PawMap 587 : budget d'une demande (option A de Daniel), mêmes
// textes que l'app (frontend/lib/localization/v565/budget587_i18n.dart).
import type { Lang } from "./translations";

type D = Record<string, string>;

export const BUDGET587: Record<Lang, D> = {
  fr: {
    b587_title: "Mon budget",
    b587_sub: "Facultatif. Indique combien tu veux payer : le montant s'affiche sur ta demande et sur la PawMap. Laisse vide si tu préfères en discuter.",
    b587_hint: "Ex. 35",
    b587_none: "Aucun (à discuter)",
    b587_field: "Budget prévu",
  },
  en: {
    b587_title: "My budget",
    b587_sub: "Optional. Say how much you'd like to pay: the amount shows on your request and on the PawMap. Leave it empty if you'd rather discuss it.",
    b587_hint: "e.g. 35",
    b587_none: "None (to discuss)",
    b587_field: "Planned budget",
  },
  es: {
    b587_title: "Mi presupuesto",
    b587_sub: "Opcional. Indica cuánto quieres pagar: el importe aparece en tu solicitud y en el PawMap. Déjalo vacío si prefieres hablarlo.",
    b587_hint: "Ej. 35",
    b587_none: "Ninguno (a convenir)",
    b587_field: "Presupuesto previsto",
  },
  de: {
    b587_title: "Mein Budget",
    b587_sub: "Optional. Gib an, wie viel du zahlen möchtest: Der Betrag erscheint in deiner Anfrage und auf der PawMap. Lass das Feld leer, wenn du lieber darüber sprichst.",
    b587_hint: "z. B. 35",
    b587_none: "Keins (nach Absprache)",
    b587_field: "Geplantes Budget",
  },
  it: {
    b587_title: "Il mio budget",
    b587_sub: "Facoltativo. Indica quanto vuoi pagare: l'importo appare sulla tua richiesta e sulla PawMap. Lascia vuoto se preferisci parlarne.",
    b587_hint: "Es. 35",
    b587_none: "Nessuno (da concordare)",
    b587_field: "Budget previsto",
  },
  pt: {
    b587_title: "O meu orçamento",
    b587_sub: "Opcional. Indica quanto queres pagar: o valor aparece no teu pedido e no PawMap. Deixa vazio se preferires combinar.",
    b587_hint: "Ex. 35",
    b587_none: "Nenhum (a combinar)",
    b587_field: "Orçamento previsto",
  },
  ko: {
    b587_title: "내 예산",
    b587_sub: "선택 사항이에요. 지불하고 싶은 금액을 적어 주세요. 금액은 내 요청과 PawMap에 표시돼요. 상의하고 싶다면 비워 두세요.",
    b587_hint: "예: 35",
    b587_none: "없음 (협의)",
    b587_field: "예상 예산",
  },
  ja: {
    b587_title: "予算",
    b587_sub: "任意です。支払いたい金額を入力してください。金額はあなたの依頼と PawMap に表示されます。相談したい場合は空欄のままで大丈夫です。",
    b587_hint: "例：35",
    b587_none: "なし（相談）",
    b587_field: "予定の予算",
  },
  pl: {
    b587_title: "Mój budżet",
    b587_sub: "Opcjonalnie. Podaj, ile chcesz zapłacić: kwota pojawi się w twoim zgłoszeniu i na PawMap. Zostaw puste, jeśli wolisz to omówić.",
    b587_hint: "np. 35",
    b587_none: "Brak (do ustalenia)",
    b587_field: "Planowany budżet",
  },
};

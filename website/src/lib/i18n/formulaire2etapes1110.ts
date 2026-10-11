// 11/10/2026 (SAM, mission BOB) — FORMULAIRE « PUBLIER MA DEMANDE » EN 2 ÉTAPES.
//
// Mesure du 10/10 (3 jours de pub Paris, page refaite le 08/10) : 225 arrivées
// → 4 clics « Publier ma demande » → 3 formulaires ouverts → 0 demande. Sur 7 j,
// 10 formulaires ouverts et PERSONNE n'a touché le champ « Prénom » du compte
// (repère pub_compte = 0). Cause mesurée à 375 px : le formulaire faisait
// 3 338 px de haut (4,1 écrans), 11 champs, le compte à 1 551 px et le bouton
// « Publier » à ≈ 3 200 px. Désormais : étape 1 = un écran (ville, service,
// dates, une ligne), étape 2 = compte + « Publier ». Le reste est replié.
// Fichier autonome (pas de fusion dans translations.ts) : `f2(lang, clé)`.
import type { Lang } from "./langs";

type D = Record<string, string>;

export const FORM_2_ETAPES: Record<Lang, D> = {
  fr: {
    title: "Publier ma demande — gratuit",
    sub: "2 minutes. Les gardiens et promeneurs de ta ville sont prévenus tout de suite.",
    step_of: "Étape {n} sur 2",
    body_label: "Ta demande, en une phrase",
    body_ph: "Ex. : garder mon chat 5 jours pendant les vacances",
    body_required: "Décris ta demande en une phrase.",
    service_required: "Choisis un service.",
    next: "Continuer",
    back: "Modifier ma demande",
    details_toggle: "Ajouter des détails (facultatif)",
    details_sub: "Budget, animaux, notes, photos",
  },
  en: {
    title: "Post my request — free",
    sub: "2 minutes. Sitters and walkers in your city are notified right away.",
    step_of: "Step {n} of 2",
    body_label: "Your request, in one sentence",
    body_ph: "E.g.: look after my cat for 5 days during the holidays",
    body_required: "Describe your request in one sentence.",
    service_required: "Choose a service.",
    next: "Continue",
    back: "Edit my request",
    details_toggle: "Add details (optional)",
    details_sub: "Budget, pets, notes, photos",
  },
  es: {
    title: "Publicar mi solicitud — gratis",
    sub: "2 minutos. Los cuidadores y paseadores de tu ciudad reciben el aviso al instante.",
    step_of: "Paso {n} de 2",
    body_label: "Tu solicitud, en una frase",
    body_ph: "Ej.: cuidar a mi gato 5 días durante las vacaciones",
    body_required: "Describe tu solicitud en una frase.",
    service_required: "Elige un servicio.",
    next: "Continuar",
    back: "Modificar mi solicitud",
    details_toggle: "Añadir detalles (opcional)",
    details_sub: "Presupuesto, mascotas, notas, fotos",
  },
  de: {
    title: "Meine Anfrage veröffentlichen — kostenlos",
    sub: "2 Minuten. Tiersitter und Gassigeher in deiner Stadt werden sofort benachrichtigt.",
    step_of: "Schritt {n} von 2",
    body_label: "Deine Anfrage in einem Satz",
    body_ph: "Z. B.: meine Katze 5 Tage im Urlaub betreuen",
    body_required: "Beschreibe deine Anfrage in einem Satz.",
    service_required: "Wähle einen Service.",
    next: "Weiter",
    back: "Anfrage ändern",
    details_toggle: "Details hinzufügen (optional)",
    details_sub: "Budget, Tiere, Notizen, Fotos",
  },
  it: {
    title: "Pubblica la mia richiesta — gratis",
    sub: "2 minuti. I pet sitter e i dog walker della tua città vengono avvisati subito.",
    step_of: "Passo {n} di 2",
    body_label: "La tua richiesta, in una frase",
    body_ph: "Es.: badare al mio gatto per 5 giorni durante le vacanze",
    body_required: "Descrivi la tua richiesta in una frase.",
    service_required: "Scegli un servizio.",
    next: "Continua",
    back: "Modifica la richiesta",
    details_toggle: "Aggiungi dettagli (facoltativo)",
    details_sub: "Budget, animali, note, foto",
  },
  pt: {
    title: "Publicar o meu pedido — grátis",
    sub: "2 minutos. Os pet sitters e passeadores da tua cidade são avisados de imediato.",
    step_of: "Passo {n} de 2",
    body_label: "O teu pedido, numa frase",
    body_ph: "Ex.: cuidar do meu gato 5 dias durante as férias",
    body_required: "Descreve o teu pedido numa frase.",
    service_required: "Escolhe um serviço.",
    next: "Continuar",
    back: "Alterar o meu pedido",
    details_toggle: "Adicionar detalhes (opcional)",
    details_sub: "Orçamento, animais, notas, fotos",
  },
  ko: {
    title: "내 요청 올리기 — 무료",
    sub: "2분이면 충분해요. 내 도시의 펫시터와 산책 도우미에게 바로 알림이 갑니다.",
    step_of: "{n}/2 단계",
    body_label: "요청 내용을 한 문장으로",
    body_ph: "예: 휴가 동안 5일간 고양이 돌봄",
    body_required: "요청 내용을 한 문장으로 적어 주세요.",
    service_required: "서비스를 선택해 주세요.",
    next: "계속",
    back: "요청 수정",
    details_toggle: "세부 정보 추가 (선택)",
    details_sub: "예산, 반려동물, 메모, 사진",
  },
  ja: {
    title: "リクエストを投稿 — 無料",
    sub: "2分で完了。あなたの街のペットシッターと散歩代行者にすぐ通知されます。",
    step_of: "ステップ {n} / 2",
    body_label: "リクエストをひとことで",
    body_ph: "例：休暇中の5日間、猫のお世話",
    body_required: "リクエストをひとことで書いてください。",
    service_required: "サービスを選んでください。",
    next: "次へ",
    back: "リクエストを修正",
    details_toggle: "詳細を追加（任意）",
    details_sub: "予算、ペット、メモ、写真",
  },
  pl: {
    title: "Opublikuj moją prośbę — za darmo",
    sub: "2 minuty. Opiekunowie i wyprowadzacze psów w Twoim mieście dostają powiadomienie od razu.",
    step_of: "Krok {n} z 2",
    body_label: "Twoja prośba w jednym zdaniu",
    body_ph: "Np.: opieka nad moim kotem przez 5 dni w czasie urlopu",
    body_required: "Opisz swoją prośbę w jednym zdaniu.",
    service_required: "Wybierz usługę.",
    next: "Dalej",
    back: "Zmień prośbę",
    details_toggle: "Dodaj szczegóły (opcjonalnie)",
    details_sub: "Budżet, zwierzęta, notatki, zdjęcia",
  },
};

export function f2(lang: Lang, key: string): string {
  return FORM_2_ETAPES[lang]?.[key] ?? FORM_2_ETAPES.en[key] ?? key;
}

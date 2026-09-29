// 29/09/2026 (NEO, mission BOB « pourquoi aucun propriétaire n'a publié ») —
// textes des deux retouches du formulaire de demande :
//   1. preuve sociale près du bouton « Publier » : « N gardiens et promeneurs
//      à <ville> seront prévenus » (chiffre VRAI lu sur /supply/city, rien si 0) ;
//   2. rappel du brouillon au retour sur le site : « Ta demande n'est pas partie ».
// {n} et {city} sont des variables : ne jamais les traduire.
import type { Lang } from "./langs";

type D = Record<string, string>;

export const PROOF_2909: Record<Lang, D> = {
  fr: {
    proof_many: "{n} gardiens et promeneurs à {city} seront prévenus dès que tu publies.",
    proof_one: "1 gardien ou promeneur à {city} sera prévenu dès que tu publies.",
    draft_title: "Ta demande de garde n'est pas partie.",
    draft_sub: "Elle est gardée ici, telle que tu l'as écrite. Une minute suffit pour la publier.",
    draft_cta: "Finir ma demande",
    draft_later: "Plus tard",
  },
  en: {
    proof_many: "{n} sitters and walkers in {city} will be notified as soon as you publish.",
    proof_one: "1 sitter or walker in {city} will be notified as soon as you publish.",
    draft_title: "Your care request wasn't sent.",
    draft_sub: "It's saved here exactly as you wrote it. One minute is enough to publish it.",
    draft_cta: "Finish my request",
    draft_later: "Later",
  },
  es: {
    proof_many: "{n} cuidadores y paseadores en {city} recibirán un aviso en cuanto publiques.",
    proof_one: "1 cuidador o paseador en {city} recibirá un aviso en cuanto publiques.",
    draft_title: "Tu solicitud de cuidado no se ha enviado.",
    draft_sub: "Está guardada aquí tal como la escribiste. Un minuto basta para publicarla.",
    draft_cta: "Terminar mi solicitud",
    draft_later: "Más tarde",
  },
  de: {
    proof_many: "{n} Sitter und Gassigeher in {city} werden benachrichtigt, sobald du veröffentlichst.",
    proof_one: "1 Sitter oder Gassigeher in {city} wird benachrichtigt, sobald du veröffentlichst.",
    draft_title: "Deine Betreuungsanfrage wurde nicht gesendet.",
    draft_sub: "Sie ist hier gespeichert, genau wie du sie geschrieben hast. Eine Minute reicht, um sie zu veröffentlichen.",
    draft_cta: "Anfrage fertigstellen",
    draft_later: "Später",
  },
  it: {
    proof_many: "{n} pet sitter e dog walker a {city} saranno avvisati appena pubblichi.",
    proof_one: "1 pet sitter o dog walker a {city} sarà avvisato appena pubblichi.",
    draft_title: "La tua richiesta non è stata inviata.",
    draft_sub: "È salvata qui, esattamente come l'hai scritta. Basta un minuto per pubblicarla.",
    draft_cta: "Completare la richiesta",
    draft_later: "Più tardi",
  },
  pt: {
    proof_many: "{n} cuidadores e passeadores em {city} serão avisados assim que publicares.",
    proof_one: "1 cuidador ou passeador em {city} será avisado assim que publicares.",
    draft_title: "O teu pedido não foi enviado.",
    draft_sub: "Está guardado aqui, tal como o escreveste. Um minuto chega para o publicar.",
    draft_cta: "Terminar o meu pedido",
    draft_later: "Mais tarde",
  },
  pl: {
    proof_many: "{n} opiekunów i wyprowadzaczy w {city} dostanie powiadomienie, gdy tylko opublikujesz.",
    proof_one: "1 opiekun lub wyprowadzacz w {city} dostanie powiadomienie, gdy tylko opublikujesz.",
    draft_title: "Twoja prośba o opiekę nie została wysłana.",
    draft_sub: "Jest zapisana tutaj, dokładnie tak, jak ją napisałeś. Minuta wystarczy, żeby ją opublikować.",
    draft_cta: "Dokończ prośbę",
    draft_later: "Później",
  },
  ko: {
    proof_many: "게시하는 즉시 {city}의 펫시터와 산책 도우미 {n}명에게 알림이 갑니다.",
    proof_one: "게시하는 즉시 {city}의 펫시터 또는 산책 도우미 1명에게 알림이 갑니다.",
    draft_title: "돌봄 요청이 아직 전송되지 않았어요.",
    draft_sub: "작성한 그대로 여기에 저장되어 있어요. 1분이면 게시할 수 있어요.",
    draft_cta: "요청 마무리하기",
    draft_later: "나중에",
  },
  ja: {
    proof_many: "公開するとすぐに{city}のシッターと散歩スタッフ{n}人に通知されます。",
    proof_one: "公開するとすぐに{city}のシッターまたは散歩スタッフ1人に通知されます。",
    draft_title: "お世話のリクエストはまだ送信されていません。",
    draft_sub: "書いた内容のままここに保存されています。1分で公開できます。",
    draft_cta: "リクエストを仕上げる",
    draft_later: "あとで",
  },
};

export const pr = (lang: Lang, key: string): string =>
  PROOF_2909[lang]?.[key] ?? PROOF_2909.en[key] ?? key;

// 07/10/2026 — LEO (613) : « Rejoindre john · 355 m · 4 min à pied » pendant un suivi (clés pm613_*
// et route_duration_* COPIÉES de l'app : pm613_i18n.dart + translations/<lang>.dart) et la légende
// de la nouvelle épingle d'alerte (legend_report_body, écrite pour le site).
// Fichier GÉNÉRÉ par ~/hopetsit-social/site_613/build_site613.py — ne pas modifier à la main.
import type { Lang } from "./translations";

type D = Record<string, string>;

export const SITE613: Record<Lang, D> = {
  fr: {
    pm613_join: "Rejoindre @name",
    pm613_join_plain: "Le rejoindre",
    pm613_walk_time: "@t à pied",
    route_duration_min: "{min} min",
    route_duration_h: "{h} h {min}",
    legend_report_body: "Rond blanc, anneau de couleur selon la gravité : rouge = danger, orange = attention, bleu = info. Un halo = signalé il y a moins de 2 h ; il pâlit en vieillissant. Visible par tout le monde, abonné ou non.",
  },
  en: {
    pm613_join: "Join @name",
    pm613_join_plain: "Join them",
    pm613_walk_time: "@t on foot",
    route_duration_min: "{min} min",
    route_duration_h: "{h} h {min} min",
    legend_report_body: "White circle with a coloured ring for how serious it is: red = danger, orange = caution, blue = info. A glow = reported less than 2 h ago; it fades as it gets older. Visible to everyone, subscribed or not.",
  },
  es: {
    pm613_join: "Reunirme con @name",
    pm613_join_plain: "Reunirme",
    pm613_walk_time: "@t a pie",
    route_duration_min: "{min} min",
    route_duration_h: "{h} h {min} min",
    legend_report_body: "Círculo blanco con un anillo de color según la gravedad: rojo = peligro, naranja = atención, azul = información. Un halo = avisado hace menos de 2 h; se aclara con el tiempo. Visible para todos, con o sin suscripción.",
  },
  de: {
    pm613_join: "Zu @name gehen",
    pm613_join_plain: "Hingehen",
    pm613_walk_time: "@t zu Fuß",
    route_duration_min: "{min} Min.",
    route_duration_h: "{h} Std. {min} Min.",
    legend_report_body: "Weißer Kreis mit farbigem Ring je nach Ernst: Rot = Gefahr, Orange = Achtung, Blau = Info. Ein Schein = vor weniger als 2 Std. gemeldet; mit der Zeit wird er blasser. Für alle sichtbar, mit oder ohne Abo.",
  },
  it: {
    pm613_join: "Raggiungi @name",
    pm613_join_plain: "Raggiungi",
    pm613_walk_time: "@t a piedi",
    route_duration_min: "{min} min",
    route_duration_h: "{h} h {min} min",
    legend_report_body: "Cerchio bianco con un anello colorato secondo la gravità: rosso = pericolo, arancione = attenzione, blu = info. Un alone = segnalato meno di 2 h fa; sbiadisce col tempo. Visibile a tutti, abbonati o no.",
  },
  pt: {
    pm613_join: "Ir ter com @name",
    pm613_join_plain: "Juntar-me",
    pm613_walk_time: "@t a pé",
    route_duration_min: "{min} min",
    route_duration_h: "{h} h {min} min",
    legend_report_body: "Círculo branco com um anel de cor conforme a gravidade: vermelho = perigo, laranja = atenção, azul = informação. Um halo = assinalado há menos de 2 h; vai esbatendo com o tempo. Visível para todos, com ou sem subscrição.",
  },
  ko: {
    pm613_join: "@name에게 가기",
    pm613_join_plain: "함께하기",
    pm613_walk_time: "도보 @t",
    route_duration_min: "{min}분",
    route_duration_h: "{h}시간 {min}분",
    legend_report_body: "심각도에 따라 색 테두리가 있는 흰 원: 빨강 = 위험, 주황 = 주의, 파랑 = 정보. 빛나는 테두리 = 2시간 이내 제보이며 시간이 지나면 흐려집니다. 구독 여부와 상관없이 모두에게 보입니다.",
  },
  ja: {
    pm613_join: "@nameと合流",
    pm613_join_plain: "合流する",
    pm613_walk_time: "徒歩@t",
    route_duration_min: "{min}分",
    route_duration_h: "{h}時間{min}分",
    legend_report_body: "重要度で色が変わる輪の付いた白い丸：赤＝危険、オレンジ＝注意、青＝お知らせ。光の輪＝2時間以内の報告で、時間とともに薄くなります。サブスクの有無にかかわらず全員に表示されます。",
  },
  pl: {
    pm613_join: "Dołącz do @name",
    pm613_join_plain: "Dołącz",
    pm613_walk_time: "@t pieszo",
    route_duration_min: "{min} min",
    route_duration_h: "{h} godz. {min} min",
    legend_report_body: "Białe kółko z kolorową obwódką zależną od wagi: czerwona = niebezpieczeństwo, pomarańczowa = uwaga, niebieska = informacja. Poświata = zgłoszone mniej niż 2 godz. temu; z czasem blednie. Widoczne dla wszystkich, z subskrypcją lub bez.",
  },
};

// 30/09/2026 — LEO : build 604 (ZOE, serveur). Une demande de suivi en direct
// (carte pawfollow_request du chat) peut maintenant finir en statut « ended »
// (metadata.endReason : live_stopped | duration_ended | follow_stopped |
// share_stopped). TEXTES DE L'APP, repris mot pour mot de
// frontend/lib/localization/v565/chat_i18n.dart (cs_pf_status_ended,
// cs_pf_status_expired — « Expirée » s'affichait « En attente »).
// 9 langues, fusionné dans translations.ts.
import type { Lang } from "./translations";

type D = Record<string, string>;

export const PAWFOLLOW604: Record<Lang, D> = {
  fr: { chat_follow_ended: "Suivi terminé", chat_follow_expired: "Expirée" },
  en: { chat_follow_ended: "Tracking ended", chat_follow_expired: "Expired" },
  es: { chat_follow_ended: "Seguimiento finalizado", chat_follow_expired: "Caducada" },
  de: { chat_follow_ended: "Tracking beendet", chat_follow_expired: "Abgelaufen" },
  it: { chat_follow_ended: "Tracciamento terminato", chat_follow_expired: "Scaduta" },
  pt: { chat_follow_ended: "Seguimento terminado", chat_follow_expired: "Expirado" },
  ko: { chat_follow_ended: "추적 종료", chat_follow_expired: "만료됨" },
  ja: { chat_follow_ended: "追跡終了", chat_follow_expired: "期限切れ" },
  pl: { chat_follow_ended: "Śledzenie zakończone", chat_follow_expired: "Wygasła" },
};

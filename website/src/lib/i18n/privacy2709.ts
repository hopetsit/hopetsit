// 27/09/2026 — Daniel : expliquer dans « Comprendre la PawMap » que les
// positions sont floutées (~1 km) et que seul le Direct montre la position
// réelle. 9 langues, fusionné dans translations.ts (même mécanisme que map590.ts).
import type { Lang } from "./translations";

type D = Record<string, string>;

export const PRIVACY2709: Record<Lang, D> = {
  fr: { priv2709_title: "Votre position reste privée", priv2709_body: "Sur la carte, personne n'apparaît à son adresse exacte : pour votre sécurité et votre vie privée, chaque membre est placé dans un rayon d'environ 1 km autour de chez lui. Seul le mode Direct montre la position réelle, en temps réel, et uniquement pendant qu'il est activé." },
  en: { priv2709_title: "Your location stays private", priv2709_body: "No one is shown at their exact address on the map: for your safety and privacy, every member is placed within about 1 km of their home. Only Live mode shows the real position, in real time, and only while it is switched on." },
  es: { priv2709_title: "Tu ubicación sigue siendo privada", priv2709_body: "En el mapa nadie aparece en su dirección exacta: por tu seguridad y tu privacidad, cada miembro se sitúa en un radio de unos 1 km alrededor de su casa. Solo el modo Directo muestra la posición real, en tiempo real, y únicamente mientras está activado." },
  de: { priv2709_title: "Dein Standort bleibt privat", priv2709_body: "Auf der Karte erscheint niemand an seiner genauen Adresse: Zu deiner Sicherheit und zum Schutz deiner Privatsphäre wird jedes Mitglied in einem Umkreis von etwa 1 km um sein Zuhause angezeigt. Nur der Live-Modus zeigt die echte Position, in Echtzeit, und nur solange er eingeschaltet ist." },
  it: { priv2709_title: "La tua posizione resta privata", priv2709_body: "Sulla mappa nessuno appare al suo indirizzo esatto: per la tua sicurezza e la tua privacy, ogni membro è collocato in un raggio di circa 1 km da casa sua. Solo la modalità Diretta mostra la posizione reale, in tempo reale, e solo finché è attiva." },
  pt: { priv2709_title: "A sua localização continua privada", priv2709_body: "No mapa, ninguém aparece na sua morada exata: pela sua segurança e privacidade, cada membro é colocado num raio de cerca de 1 km à volta de casa. Só o modo Direto mostra a posição real, em tempo real, e apenas enquanto está ativado." },
  ko: { priv2709_title: "내 위치는 비공개로 보호돼요", priv2709_body: "지도에는 누구도 정확한 주소에 표시되지 않아요. 안전과 사생활 보호를 위해 모든 회원은 집에서 약 1km 반경 안에 표시돼요. 실제 위치는 라이브 모드를 켠 동안에만 실시간으로 보여요." },
  ja: { priv2709_title: "あなたの位置はプライベートに守られます", priv2709_body: "地図上では、誰も正確な住所には表示されません。安全とプライバシーのため、各メンバーは自宅から約1kmの範囲内に表示されます。実際の位置がリアルタイムで表示されるのは、ライブモードをオンにしている間だけです。" },
  pl: { priv2709_title: "Twoja lokalizacja pozostaje prywatna", priv2709_body: "Na mapie nikt nie jest pokazany pod swoim dokładnym adresem: dla Twojego bezpieczeństwa i prywatności każdy członek jest umieszczony w promieniu około 1 km od domu. Tylko tryb Na żywo pokazuje prawdziwą pozycję, w czasie rzeczywistym, i tylko wtedy, gdy jest włączony." },
};

// 10/11/2026 — LEO, build 639 (lot C, contrats figés avec l'app et le serveur) : textes de la
// légende de la PawMap pour le point vert « Disponible aujourd'hui » (CONTRATS §5). Le titre
// réutilise `map_available_today` (même mot que le filtre). 9 langues, fusionné dans translations.ts.
import type { Lang } from "./translations";

type D = Record<string, string>;

export const BUILD639: Record<Lang, D> = {
  fr: { legend639_available_body: "Petit point vert en bas à gauche du rond d'un gardien ou d'un promeneur : il s'est déclaré disponible aujourd'hui et il est passé récemment sur HoPetSit." },
  en: { legend639_available_body: "Small green dot at the bottom left of a sitter's or walker's circle: they said they are available today and have used HoPetSit recently." },
  es: { legend639_available_body: "Pequeño punto verde abajo a la izquierda del círculo de un cuidador o paseador: ha indicado que está disponible hoy y ha usado HoPetSit hace poco." },
  de: { legend639_available_body: "Kleiner grüner Punkt unten links am Kreis eines Sitters oder Gassigehers: Er hat angegeben, heute verfügbar zu sein, und war vor Kurzem auf HoPetSit aktiv." },
  it: { legend639_available_body: "Piccolo punto verde in basso a sinistra del cerchio di un sitter o di un dog walker: ha indicato di essere disponibile oggi ed è passato di recente su HoPetSit." },
  pt: { legend639_available_body: "Pequeno ponto verde no canto inferior esquerdo do círculo de um cuidador ou passeador: indicou que está disponível hoje e usou a HoPetSit recentemente." },
  ko: { legend639_available_body: "펫시터나 산책 도우미 원의 왼쪽 아래에 있는 작은 초록 점: 오늘 가능하다고 표시했고 최근에 HoPetSit을 이용했어요." },
  ja: { legend639_available_body: "シッターや散歩代行の丸の左下にある小さな緑の点：今日対応できると登録していて、最近 HoPetSit を利用しています。" },
  pl: { legend639_available_body: "Mała zielona kropka w lewym dolnym rogu kółka opiekuna lub wyprowadzacza: zaznaczył, że jest dziś dostępny, i niedawno korzystał z HoPetSit." },
};

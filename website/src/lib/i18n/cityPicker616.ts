// 616 (LEO, 08/10/2026, demande de Daniel) — CHAMP VILLE AVEC SUGGESTIONS
// sur « Publier une annonce » (/posts/create) : suggestions pendant la frappe,
// bouton « Ma position », ville à choisir dans la liste. Fichier autonome
// (comme publish587.ts) : `c616(lang, clé)`. Les 9 langues du site.
import type { Lang } from "./langs";

type K =
  | "my_position"
  | "locating"
  | "denied"
  | "unavailable"
  | "choose_from_list"
  | "no_result"
  | "searching"
  | "list_label";

const T: Record<Lang, Record<K, string>> = {
  fr: {
    my_position: "Ma position",
    locating: "Localisation…",
    denied: "Position refusée. Autorise la localisation dans ton navigateur, ou tape ta ville.",
    unavailable: "Position introuvable pour le moment. Tape ta ville.",
    choose_from_list: "Choisis ta ville dans la liste.",
    no_result: "Aucune ville trouvée. Vérifie l’orthographe.",
    searching: "Recherche…",
    list_label: "Villes proposées",
  },
  en: {
    my_position: "My location",
    locating: "Locating…",
    denied: "Location blocked. Allow location in your browser, or type your city.",
    unavailable: "Can’t find your location right now. Type your city.",
    choose_from_list: "Choose your city from the list.",
    no_result: "No city found. Check the spelling.",
    searching: "Searching…",
    list_label: "Suggested cities",
  },
  es: {
    my_position: "Mi ubicación",
    locating: "Localizando…",
    denied: "Ubicación denegada. Permite la ubicación en tu navegador o escribe tu ciudad.",
    unavailable: "No encontramos tu ubicación ahora mismo. Escribe tu ciudad.",
    choose_from_list: "Elige tu ciudad de la lista.",
    no_result: "No se encontró ninguna ciudad. Revisa la ortografía.",
    searching: "Buscando…",
    list_label: "Ciudades sugeridas",
  },
  de: {
    my_position: "Mein Standort",
    locating: "Wird geortet…",
    denied: "Standort abgelehnt. Erlaube den Standort im Browser oder gib deine Stadt ein.",
    unavailable: "Dein Standort ist gerade nicht auffindbar. Gib deine Stadt ein.",
    choose_from_list: "Wähle deine Stadt aus der Liste.",
    no_result: "Keine Stadt gefunden. Prüfe die Schreibweise.",
    searching: "Suche…",
    list_label: "Vorgeschlagene Städte",
  },
  it: {
    my_position: "La mia posizione",
    locating: "Localizzazione…",
    denied: "Posizione negata. Consenti la posizione nel browser o scrivi la tua città.",
    unavailable: "Posizione non trovata al momento. Scrivi la tua città.",
    choose_from_list: "Scegli la tua città dall’elenco.",
    no_result: "Nessuna città trovata. Controlla l’ortografia.",
    searching: "Ricerca…",
    list_label: "Città suggerite",
  },
  pt: {
    my_position: "A minha localização",
    locating: "A localizar…",
    denied: "Localização recusada. Permite a localização no navegador ou escreve a tua cidade.",
    unavailable: "Não encontramos a tua localização agora. Escreve a tua cidade.",
    choose_from_list: "Escolhe a tua cidade na lista.",
    no_result: "Nenhuma cidade encontrada. Verifica a ortografia.",
    searching: "A procurar…",
    list_label: "Cidades sugeridas",
  },
  ko: {
    my_position: "내 위치",
    locating: "위치 확인 중…",
    denied: "위치 권한이 거부되었습니다. 브라우저에서 위치를 허용하거나 도시를 입력하세요.",
    unavailable: "지금은 위치를 찾을 수 없습니다. 도시를 입력하세요.",
    choose_from_list: "목록에서 도시를 선택하세요.",
    no_result: "도시를 찾을 수 없습니다. 철자를 확인하세요.",
    searching: "검색 중…",
    list_label: "추천 도시",
  },
  ja: {
    my_position: "現在地",
    locating: "位置を取得中…",
    denied: "位置情報が拒否されました。ブラウザで位置情報を許可するか、都市名を入力してください。",
    unavailable: "現在地を取得できませんでした。都市名を入力してください。",
    choose_from_list: "リストから都市を選んでください。",
    no_result: "都市が見つかりません。つづりを確認してください。",
    searching: "検索中…",
    list_label: "候補の都市",
  },
  pl: {
    my_position: "Moja lokalizacja",
    locating: "Ustalanie lokalizacji…",
    denied: "Odmowa dostępu do lokalizacji. Zezwól na nią w przeglądarce albo wpisz miasto.",
    unavailable: "Nie udało się teraz ustalić lokalizacji. Wpisz miasto.",
    choose_from_list: "Wybierz miasto z listy.",
    no_result: "Nie znaleziono miasta. Sprawdź pisownię.",
    searching: "Szukam…",
    list_label: "Proponowane miasta",
  },
};

export function c616(lang: Lang, k: K): string {
  return (T[lang] || T.fr)[k] || T.fr[k];
}

export const CITY616_KEYS = Object.keys(T.fr) as K[];
export const CITY616_TEXTS = T;

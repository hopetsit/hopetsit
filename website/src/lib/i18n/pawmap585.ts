// 25/09/2026 — PawMap 585 (site) : une personne = un point avec tous ses
// rôles (choix du profil, liste d'un groupe superposé), fiche du bas,
// capsule droite (zoom, satellite, membres). 9 langues, fusionné dans
// translations.ts (même mécanisme que pawmap584.ts). Les variables {count},
// {d} ne se traduisent jamais.
import type { Lang } from "./translations";

type D = Record<string, string>;

export const PAWMAP585: Record<Lang, D> = {
  fr: {
    map_distance_from_center: "à {d} du centre de la carte",
    map_zoom_in: "Zoomer", map_zoom_out: "Dézoomer",
    map_layer_satellite: "Vue satellite", map_layer_plan: "Vue plan",
    map_members_hide: "Masquer les membres", map_members_show: "Afficher les membres",
    map_friend_badge: "Ami", map_choose_profile: "Choisis le profil à voir",
    map_profiles_here: "{count} profils à cet endroit", map_see: "Voir",
    map_distance_from_you: "à {d} de toi", map_back: "Retour",
  },
  en: {
    map_distance_from_center: "{d} from the map centre",
    map_zoom_in: "Zoom in", map_zoom_out: "Zoom out",
    map_layer_satellite: "Satellite view", map_layer_plan: "Map view",
    map_members_hide: "Hide members", map_members_show: "Show members",
    map_friend_badge: "Friend", map_choose_profile: "Choose which profile to see",
    map_profiles_here: "{count} profiles at this spot", map_see: "View",
    map_distance_from_you: "{d} from you", map_back: "Back",
  },
  es: {
    map_distance_from_center: "a {d} del centro del mapa",
    map_zoom_in: "Acercar", map_zoom_out: "Alejar",
    map_layer_satellite: "Vista satélite", map_layer_plan: "Vista de mapa",
    map_members_hide: "Ocultar miembros", map_members_show: "Mostrar miembros",
    map_friend_badge: "Amigo", map_choose_profile: "Elige el perfil que quieres ver",
    map_profiles_here: "{count} perfiles en este lugar", map_see: "Ver",
    map_distance_from_you: "a {d} de ti", map_back: "Volver",
  },
  de: {
    map_distance_from_center: "{d} von der Kartenmitte",
    map_zoom_in: "Vergrößern", map_zoom_out: "Verkleinern",
    map_layer_satellite: "Satellitenansicht", map_layer_plan: "Kartenansicht",
    map_members_hide: "Mitglieder ausblenden", map_members_show: "Mitglieder anzeigen",
    map_friend_badge: "Freund", map_choose_profile: "Wähle das Profil, das du sehen möchtest",
    map_profiles_here: "{count} Profile an diesem Ort", map_see: "Ansehen",
    map_distance_from_you: "{d} von dir entfernt", map_back: "Zurück",
  },
  it: {
    map_distance_from_center: "a {d} dal centro della mappa",
    map_zoom_in: "Ingrandisci", map_zoom_out: "Riduci",
    map_layer_satellite: "Vista satellite", map_layer_plan: "Vista mappa",
    map_members_hide: "Nascondi i membri", map_members_show: "Mostra i membri",
    map_friend_badge: "Amico", map_choose_profile: "Scegli il profilo da vedere",
    map_profiles_here: "{count} profili in questo punto", map_see: "Vedi",
    map_distance_from_you: "a {d} da te", map_back: "Indietro",
  },
  pt: {
    map_distance_from_center: "a {d} do centro do mapa",
    map_zoom_in: "Aproximar", map_zoom_out: "Afastar",
    map_layer_satellite: "Vista de satélite", map_layer_plan: "Vista de mapa",
    map_members_hide: "Ocultar membros", map_members_show: "Mostrar membros",
    map_friend_badge: "Amigo", map_choose_profile: "Escolhe o perfil que queres ver",
    map_profiles_here: "{count} perfis neste local", map_see: "Ver",
    map_distance_from_you: "a {d} de ti", map_back: "Voltar",
  },
  ko: {
    map_distance_from_center: "지도 중심에서 {d}",
    map_zoom_in: "확대", map_zoom_out: "축소",
    map_layer_satellite: "위성 보기", map_layer_plan: "지도 보기",
    map_members_hide: "회원 숨기기", map_members_show: "회원 보기",
    map_friend_badge: "친구", map_choose_profile: "볼 프로필을 선택하세요",
    map_profiles_here: "이 위치의 프로필 {count}개", map_see: "보기",
    map_distance_from_you: "내 위치에서 {d}", map_back: "뒤로",
  },
  ja: {
    map_distance_from_center: "地図の中心から {d}",
    map_zoom_in: "拡大", map_zoom_out: "縮小",
    map_layer_satellite: "航空写真", map_layer_plan: "地図",
    map_members_hide: "メンバーを非表示", map_members_show: "メンバーを表示",
    map_friend_badge: "友だち", map_choose_profile: "表示するプロフィールを選択",
    map_profiles_here: "この場所のプロフィール {count} 件", map_see: "見る",
    map_distance_from_you: "あなたから {d}", map_back: "戻る",
  },
  pl: {
    map_distance_from_center: "{d} od środka mapy",
    map_zoom_in: "Przybliż", map_zoom_out: "Oddal",
    map_layer_satellite: "Widok satelitarny", map_layer_plan: "Widok mapy",
    map_members_hide: "Ukryj członków", map_members_show: "Pokaż członków",
    map_friend_badge: "Znajomy", map_choose_profile: "Wybierz profil do wyświetlenia",
    map_profiles_here: "Profile w tym miejscu: {count}", map_see: "Zobacz",
    map_distance_from_you: "{d} od ciebie", map_back: "Wstecz",
  },
};

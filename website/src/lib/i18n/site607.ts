// 02/10/2026 — LEO (build 607, mission de BOB, décision de Daniel du 02/10) :
// aide « Comprendre la PawMap » du site, 2 sections nouvelles — « Ramène tes
// clients / Pionnier » et « Les peluches de la Balade ». MÊMES CLÉS que l'app
// (help607_*) : ZOE reprend ces textes mot pour mot. Textes simples et
// honnêtes : aucune promesse de revenus, la récompense = des PawPoints.
// Fusionné dans translations.ts (même mécanisme que site605.ts).
import type { Lang } from "./translations";

type D = Record<string, string>;

export const SITE607: Record<Lang, D> = {
  fr: {
    help607_pioneer_badge: "Pionnier",
    help607_pioneer_title: "Ramène tes clients · badge Pionnier",
    help607_pioneer_body:
      "Gardien ou promeneur, tu as ta propre page : hopetsit.com/s/ton-prénom. Envoie-la à tes voisins et à tes clients (WhatsApp, SMS, e-mail) ou imprime ton affiche avec son QR code : ils voient tes tarifs, tes avis et te réservent sur HoPetSit.\nSi tu es le seul à proposer tes services à moins de 25 km, tu as le badge « Pionnier » : tu es le premier dans ton coin. Le badge ne garantit pas de réservations, il montre que tu es là le premier.",
    help607_plush_title: "Les peluches de la Balade",
    help607_plush_body:
      "Pendant une Balade, de petites peluches apparaissent sur la carte, dans les parcs publics près de toi. Approche-toi à moins de 30 mètres : tu l'attrapes et tu gagnes +20 PawPoints. Une peluche par jour et par personne. Tes peluches sont rangées dans ta collection, sur la page PawPoints.\nElles ne valent pas d'argent : seulement des PawPoints et une raison de plus de sortir. Regarde où tu marches.",
  },
  en: {
    help607_pioneer_badge: "Pioneer",
    help607_pioneer_title: "Bring your clients · Pioneer badge",
    help607_pioneer_body:
      "Sitter or walker, you have your own page: hopetsit.com/s/your-name. Send it to your neighbours and clients (WhatsApp, text, email) or print your poster with its QR code: they see your rates and reviews and book you on HoPetSit.\nIf nobody else offers your services within 25 km, you get the “Pioneer” badge: you are the first in your area. The badge does not guarantee bookings; it shows you were there first.",
    help607_plush_title: "Walk plushies",
    help607_plush_body:
      "During a Walk, small plushies appear on the map, in public parks near you. Get within 30 metres: you catch it and earn +20 PawPoints. One plushie per person per day. Your plushies are kept in your collection, on the PawPoints page.\nThey are not worth money: only PawPoints and one more reason to go out. Watch where you walk.",
  },
  es: {
    help607_pioneer_badge: "Pionero",
    help607_pioneer_title: "Trae a tus clientes · insignia Pionero",
    help607_pioneer_body:
      "Cuidador o paseador, tienes tu propia página: hopetsit.com/s/tu-nombre. Envíasela a tus vecinos y clientes (WhatsApp, SMS, e-mail) o imprime tu cartel con su código QR: ven tus tarifas y tus opiniones y te reservan en HoPetSit.\nSi nadie más ofrece tus servicios a menos de 25 km, tienes la insignia «Pionero»: eres el primero en tu zona. La insignia no garantiza reservas; muestra que llegaste el primero.",
    help607_plush_title: "Los peluches del Paseo",
    help607_plush_body:
      "Durante un Paseo, aparecen pequeños peluches en el mapa, en los parques públicos cerca de ti. Acércate a menos de 30 metros: lo atrapas y ganas +20 PawPoints. Un peluche por persona y por día. Tus peluches se guardan en tu colección, en la página PawPoints.\nNo valen dinero: solo PawPoints y una razón más para salir. Mira por dónde caminas.",
  },
  de: {
    help607_pioneer_badge: "Pionier",
    help607_pioneer_title: "Bring deine Kunden mit · Pionier-Abzeichen",
    help607_pioneer_body:
      "Als Tiersitter oder Gassigeher hast du deine eigene Seite: hopetsit.com/s/dein-name. Schick sie deinen Nachbarn und Kunden (WhatsApp, SMS, E-Mail) oder druck dein Plakat mit QR-Code aus: Sie sehen deine Preise und Bewertungen und buchen dich auf HoPetSit.\nWenn sonst niemand im Umkreis von 25 km deine Dienste anbietet, bekommst du das Abzeichen „Pionier“: Du bist der Erste in deiner Gegend. Das Abzeichen garantiert keine Buchungen; es zeigt, dass du zuerst da warst.",
    help607_plush_title: "Die Plüschtiere des Spaziergangs",
    help607_plush_body:
      "Während eines Spaziergangs erscheinen kleine Plüschtiere auf der Karte, in öffentlichen Parks in deiner Nähe. Komm auf weniger als 30 Meter heran: Du fängst es und bekommst +20 PawPoints. Ein Plüschtier pro Person und Tag. Deine Plüschtiere landen in deiner Sammlung auf der PawPoints-Seite.\nSie sind kein Geld wert: nur PawPoints und ein Grund mehr, rauszugehen. Achte auf deinen Weg.",
  },
  it: {
    help607_pioneer_badge: "Pioniere",
    help607_pioneer_title: "Porta i tuoi clienti · badge Pioniere",
    help607_pioneer_body:
      "Pet sitter o dog walker, hai la tua pagina: hopetsit.com/s/il-tuo-nome. Inviala ai vicini e ai clienti (WhatsApp, SMS, e-mail) o stampa il tuo poster con il codice QR: vedono le tue tariffe e le recensioni e ti prenotano su HoPetSit.\nSe nessun altro offre i tuoi servizi entro 25 km, hai il badge «Pioniere»: sei il primo nella tua zona. Il badge non garantisce prenotazioni; mostra che sei arrivato per primo.",
    help607_plush_title: "I peluche della Passeggiata",
    help607_plush_body:
      "Durante una Passeggiata, piccoli peluche compaiono sulla mappa, nei parchi pubblici vicino a te. Avvicinati a meno di 30 metri: lo prendi e guadagni +20 PawPoints. Un peluche al giorno a persona. I tuoi peluche finiscono nella tua collezione, nella pagina PawPoints.\nNon valgono denaro: solo PawPoints e un motivo in più per uscire. Guarda dove cammini.",
  },
  pt: {
    help607_pioneer_badge: "Pioneiro",
    help607_pioneer_title: "Traz os teus clientes · selo Pioneiro",
    help607_pioneer_body:
      "Cuidador ou passeador, tens a tua própria página: hopetsit.com/s/o-teu-nome. Envia-a aos teus vizinhos e clientes (WhatsApp, SMS, e-mail) ou imprime o teu cartaz com o código QR: veem os teus preços e avaliações e reservam-te no HoPetSit.\nSe mais ninguém oferece os teus serviços num raio de 25 km, tens o selo «Pioneiro»: és o primeiro na tua zona. O selo não garante reservas; mostra que chegaste primeiro.",
    help607_plush_title: "Os peluches do Passeio",
    help607_plush_body:
      "Durante um Passeio, pequenos peluches aparecem no mapa, nos parques públicos perto de ti. Aproxima-te a menos de 30 metros: apanha-lo e ganhas +20 PawPoints. Um peluche por pessoa e por dia. Os teus peluches ficam na tua coleção, na página PawPoints.\nNão valem dinheiro: apenas PawPoints e mais uma razão para sair. Olha por onde andas.",
  },
  ko: {
    help607_pioneer_badge: "개척자",
    help607_pioneer_title: "고객을 데려오세요 · 개척자 배지",
    help607_pioneer_body:
      "펫시터나 산책 도우미라면 나만의 페이지가 있어요: hopetsit.com/s/내-이름. 이웃과 고객에게 보내거나(WhatsApp, 문자, 이메일) QR 코드가 있는 포스터를 인쇄하세요. 내 요금과 후기를 보고 HoPetSit에서 바로 예약해요.\n반경 25km 안에 같은 서비스를 제공하는 사람이 없으면 ‘개척자’ 배지를 받아요. 우리 동네의 첫 번째라는 뜻이에요. 배지가 예약을 보장하지는 않아요. 내가 먼저 왔다는 표시예요.",
    help607_plush_title: "산책 인형",
    help607_plush_body:
      "산책 중에 근처 공원의 지도 위에 작은 인형이 나타나요. 30미터 안으로 다가가면 인형을 잡고 +20 PawPoints를 받아요. 인형은 한 사람당 하루에 하나예요. 잡은 인형은 PawPoints 페이지의 내 컬렉션에 보관돼요.\n인형은 돈이 아니에요. PawPoints와 밖으로 나갈 이유 하나가 더 생길 뿐이에요. 걸을 때 주변을 잘 살펴보세요.",
  },
  ja: {
    help607_pioneer_badge: "パイオニア",
    help607_pioneer_title: "お客さんを連れてこよう・パイオニアバッジ",
    help607_pioneer_body:
      "シッターやお散歩代行の方には自分専用のページがあります：hopetsit.com/s/あなたの名前。ご近所やお客さんに送るか（WhatsApp、SMS、メール）、QRコード付きのポスターを印刷しましょう。料金や口コミを見て、HoPetSitで予約できます。\n半径25km以内に同じサービスを提供する人がほかにいなければ「パイオニア」バッジがもらえます。地域で最初の一人という印です。バッジは予約を保証するものではなく、あなたが最初にいたことを示します。",
    help607_plush_title: "お散歩ぬいぐるみ",
    help607_plush_body:
      "お散歩中、近くの公園の地図上に小さなぬいぐるみが現れます。30メートル以内に近づくとつかまえて、+20 PawPointsがもらえます。ぬいぐるみは1人1日1つまでです。ぬいぐるみはPawPointsページのコレクションに入ります。\nお金の価値はありません。PawPointsと、外に出る理由がひとつ増えるだけです。足元に気をつけて歩きましょう。",
  },
  pl: {
    help607_pioneer_badge: "Pionier",
    help607_pioneer_title: "Przyprowadź swoich klientów · odznaka Pionier",
    help607_pioneer_body:
      "Jako opiekun lub wyprowadzacz masz własną stronę: hopetsit.com/s/twoje-imie. Wyślij ją sąsiadom i klientom (WhatsApp, SMS, e-mail) albo wydrukuj plakat z kodem QR: zobaczą twoje stawki i opinie i zarezerwują cię w HoPetSit.\nJeśli nikt inny nie oferuje twoich usług w promieniu 25 km, dostajesz odznakę „Pionier”: jesteś pierwszy w okolicy. Odznaka nie gwarantuje rezerwacji; pokazuje, że byłeś tu pierwszy.",
    help607_plush_title: "Pluszaki ze Spaceru",
    help607_plush_body:
      "Podczas Spaceru na mapie, w publicznych parkach w pobliżu, pojawiają się małe pluszaki. Podejdź na mniej niż 30 metrów: łapiesz go i zdobywasz +20 PawPoints. Jeden pluszak na osobę dziennie. Twoje pluszaki trafiają do kolekcji na stronie PawPoints.\nNie są warte pieniędzy: tylko PawPoints i jeszcze jeden powód, żeby wyjść. Patrz pod nogi.",
  },
};

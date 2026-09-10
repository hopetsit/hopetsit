// v547 — SEO programmatique « devenir pet sitter à <ville> ».
// Stratégie supply-first, Paris d'abord (objectif : premiers clients), puis
// USA, Pologne, Corée. Une page statique par ville/arrondissement, générée
// par le composant RecruitCityPage. Ajouter une ligne = une page indexable.

// v560 — moteur de croissance : +5 langues (es/de/it/pt/ja) et +57 villes.
export type RecruitLang = "fr" | "en" | "pl" | "ko" | "es" | "de" | "it" | "pt" | "ja";

export type RecruitCity = {
  slug: string;        // segment d'URL
  name: string;        // nom affiché (« Paris 11e », « Boulogne-Billancourt »)
  region: string;      // sous-titre (« Paris & Île-de-France »)
  lang: RecruitLang;
  /** Détail local pour rendre la page unique (quartiers, parcs, ambiance). */
  local: string;
  /** Fourchette de prix locale affichée dans la FAQ (déjà formatée). */
  dayRate: string;
  walkRate: string;
};

const PARIS_ARR: Array<[number, string]> = [
  [1, "Louvre, Palais-Royal et les Tuileries — beaucoup de résidents en appartement, peu d'espaces verts privés : la promenade est très demandée."],
  [2, "Sentier, Bourse et les passages couverts — un quartier de bureaux où les chiens attendent leurs maîtres toute la journée."],
  [3, "Le Marais nord, Arts-et-Métiers, le square du Temple — familles et jeunes actifs, forte densité de petits chiens."],
  [4, "Le Marais, l'île Saint-Louis et la place des Vosges — visites à domicile pour chats très fréquentes."],
  [5, "Quartier latin, Mouffetard, le Jardin des Plantes — étudiants disponibles et propriétaires qui voyagent souvent."],
  [6, "Saint-Germain-des-Prés, le Luxembourg — l'un des jardins les plus prisés des promeneurs de la capitale."],
  [7, "Invalides, Champ-de-Mars, Gros-Caillou — grands appartements, chiens de race, gardes de nuit régulières."],
  [8, "Champs-Élysées, parc Monceau, Madeleine — clientèle qui part souvent en week-end et cherche des gardes fiables."],
  [9, "Pigalle, Nouvelle-Athènes, les Grands Boulevards — jeunes couples, beaucoup de chats et de petits chiens."],
  [10, "Canal Saint-Martin, gares du Nord et de l'Est — voyageurs fréquents, gardes courtes autour des départs."],
  [11, "Oberkampf, Bastille, République — l'arrondissement le plus peuplé de Paris : la demande y est constante."],
  [12, "Bois de Vincennes, Bercy, Nation — le terrain de jeu idéal pour les promeneurs de grands chiens."],
  [13, "Butte-aux-Cailles, Bibliothèque, Olympiades — quartier familial en pleine croissance, peu de sitters installés."],
  [14, "Montparnasse, Alésia, parc Montsouris — retraités et familles qui privilégient la garde à domicile."],
  [15, "Vaugirard, Convention, parc André-Citroën — le plus grand arrondissement, des milliers de chiens déclarés."],
  [16, "Passy, Auteuil, le bois de Boulogne — demande élevée en gardes longues pendant les vacances scolaires."],
  [17, "Batignolles, Ternes, parc Martin-Luther-King — nouveaux résidents, beaucoup de chiots à sociabiliser."],
  [18, "Montmartre, Jules-Joffrin, la Goutte-d'Or — un tissu de voisinage où le bouche-à-oreille fait vite le plein."],
  [19, "Buttes-Chaumont, La Villette, le bassin — parcs immenses, promenades très demandées en semaine."],
  [20, "Belleville, Ménilmontant, Père-Lachaise — jeunes actifs en télétravail, gardes à la journée fréquentes."],
];

const PARIS_SUBURBS: Array<[string, string, string]> = [
  ["boulogne-billancourt", "Boulogne-Billancourt", "Aux portes du bois de Boulogne, familles nombreuses et chiens sportifs : les promeneurs y trouvent vite des habitués."],
  ["neuilly-sur-seine", "Neuilly-sur-Seine", "Grands appartements, animaux de race et gardes de nuit régulières : une clientèle exigeante et fidèle."],
  ["levallois-perret", "Levallois-Perret", "Une des villes les plus denses d'Europe : des centaines de chiens et très peu de sitters disponibles."],
  ["asnieres-sur-seine", "Asnières-sur-Seine", "Le premier pet sitter HoPetSit d'Île-de-France est ici : la ville où la communauté démarre."],
  ["clichy", "Clichy", "Jeunes actifs et familles, tout près des Batignolles : promenades et visites pour chats très demandées."],
  ["issy-les-moulineaux", "Issy-les-Moulineaux", "Quartiers résidentiels et bords de Seine : idéal pour des promenades régulières en semaine."],
  ["montreuil", "Montreuil", "La ville la plus peuplée de l'Est parisien : gardes à domicile et promenades au parc des Beaumonts."],
  ["vincennes", "Vincennes", "Le bois à deux pas : les propriétaires de grands chiens y cherchent des promeneurs endurants."],
  ["saint-denis", "Saint-Denis", "Peu de sitters installés, beaucoup de familles : une place à prendre pour les premiers inscrits."],
  ["ivry-sur-seine", "Ivry-sur-Seine", "Une ville en pleine transformation, proche de Paris 13 : la demande arrive plus vite que l'offre."],
  ["saint-maur-des-fosses", "Saint-Maur-des-Fossés", "Pavillons, jardins et boucle de la Marne : la garde à domicile y est la norme."],
  ["versailles", "Versailles", "Le parc du château et les grands jardins : promenades longues et gardes pendant les vacances."],
];

export const RECRUIT_CITIES: RecruitCity[] = [
  ...PARIS_ARR.map(([n, local]): RecruitCity => ({
    slug: `paris-${n}`,
    name: `Paris ${n}${n === 1 ? "er" : "e"}`,
    region: "Paris & Île-de-France",
    lang: "fr",
    local,
    dayRate: "20 à 30 €",
    walkRate: "12 à 20 €",
  })),
  ...PARIS_SUBURBS.map(([slug, name, local]): RecruitCity => ({
    slug, name, region: "Île-de-France", lang: "fr", local,
    dayRate: "18 à 28 €", walkRate: "12 à 18 €",
  })),
  { slug: "lyon", name: "Lyon", region: "Auvergne-Rhône-Alpes", lang: "fr", local: "Parc de la Tête d'Or, Croix-Rousse, Confluence : la deuxième ville de France pour les chiens en appartement.", dayRate: "18 à 26 €", walkRate: "10 à 16 €" },
  { slug: "marseille", name: "Marseille", region: "Provence-Alpes-Côte d'Azur", lang: "fr", local: "Calanques, Prado, Borély : promenades au soleil toute l'année et gardes estivales très demandées.", dayRate: "16 à 25 €", walkRate: "10 à 15 €" },
  { slug: "bordeaux", name: "Bordeaux", region: "Nouvelle-Aquitaine", lang: "fr", local: "Chartrons, Bastide, parc Bordelais : jeunes familles et beaucoup de télétravail.", dayRate: "17 à 25 €", walkRate: "10 à 16 €" },
  { slug: "lille", name: "Lille", region: "Hauts-de-France", lang: "fr", local: "Vieux-Lille, Vauban, la Citadelle : étudiants disponibles et propriétaires qui partent souvent le week-end.", dayRate: "16 à 24 €", walkRate: "10 à 15 €" },
  { slug: "toulouse", name: "Toulouse", region: "Occitanie", lang: "fr", local: "Saint-Cyprien, Compans, les berges de la Garonne : une ville jeune, très active, peu de sitters installés.", dayRate: "16 à 24 €", walkRate: "10 à 15 €" },
  { slug: "nice", name: "Nice", region: "Provence-Alpes-Côte d'Azur", lang: "fr", local: "Promenade des Anglais, Cimiez, le port : gardes touristiques et clientèle internationale.", dayRate: "18 à 28 €", walkRate: "12 à 18 €" },
  { slug: "nantes", name: "Nantes", region: "Pays de la Loire", lang: "fr", local: "Île de Nantes, Procé, bords de l'Erdre : familles et jeunes actifs, forte croissance.", dayRate: "16 à 24 €", walkRate: "10 à 15 €" },
  // ---------- USA (English) ----------
  { slug: "new-york", name: "New York", region: "New York, USA", lang: "en", local: "Apartment living from Brooklyn to the Upper West Side means dog walkers are booked every single weekday.", dayRate: "$40–70", walkRate: "$20–35" },
  { slug: "los-angeles", name: "Los Angeles", region: "California, USA", lang: "en", local: "From Silver Lake to Santa Monica, owners travel often and want a trusted sitter who knows the neighborhood.", dayRate: "$40–65", walkRate: "$20–30" },
  { slug: "dallas", name: "Dallas", region: "Texas, USA", lang: "en", local: "Uptown, Lakewood, Plano and Frisco: HoPetSit's first US community started here — early sitters get the regulars.", dayRate: "$30–55", walkRate: "$15–25" },
  { slug: "houston", name: "Houston", region: "Texas, USA", lang: "en", local: "Sprawling neighborhoods, big yards and hot summers: overnight sitting and midday walks are in constant demand.", dayRate: "$30–55", walkRate: "$15–25" },
  { slug: "miami", name: "Miami", region: "Florida, USA", lang: "en", local: "Brickell, Wynwood and Coral Gables: frequent travelers, small dogs and a year-round need for reliable sitters.", dayRate: "$35–60", walkRate: "$18–30" },
  { slug: "chicago", name: "Chicago", region: "Illinois, USA", lang: "en", local: "Lincoln Park, Wicker Park and the lakefront trail: walkers with regular clients are the norm here.", dayRate: "$35–60", walkRate: "$18–30" },
  { slug: "austin", name: "Austin", region: "Texas, USA", lang: "en", local: "One of the most dog-friendly cities in America — and one of the fastest-growing. Supply can't keep up.", dayRate: "$30–55", walkRate: "$15–25" },
  // ---------- Pologne (polski) ----------
  { slug: "warszawa", name: "Warszawa", region: "Mazowsze, Polska", lang: "pl", local: "Mokotów, Wola, Praga i Łazienki: coraz więcej psów w mieszkaniach, a opiekunów wciąż brakuje.", dayRate: "60–100 zł", walkRate: "30–50 zł" },
  { slug: "krakow", name: "Kraków", region: "Małopolska, Polska", lang: "pl", local: "Kazimierz, Podgórze, Błonia: studenci z wolnym czasem i właściciele, którzy często wyjeżdżają.", dayRate: "50–90 zł", walkRate: "25–45 zł" },
  { slug: "wroclaw", name: "Wrocław", region: "Dolny Śląsk, Polska", lang: "pl", local: "Nadodrze, Krzyki, Park Szczytnicki: młode rodziny i mnóstwo psów na spacerach nad Odrą.", dayRate: "50–90 zł", walkRate: "25–45 zł" },
  { slug: "poznan", name: "Poznań", region: "Wielkopolska, Polska", lang: "pl", local: "Jeżyce, Łazarz, Cytadela: aktywne miasto, w którym opieka dzienna nad psem jest codzienną potrzebą.", dayRate: "50–85 zł", walkRate: "25–40 zł" },
  { slug: "gdansk", name: "Gdańsk", region: "Pomorze, Polska", lang: "pl", local: "Wrzeszcz, Oliwa, plaże Trójmiasta: długie spacery nad morzem i opieka w sezonie letnim.", dayRate: "50–90 zł", walkRate: "25–45 zł" },
  // ---------- Corée (한국어) ----------
  { slug: "seoul", name: "서울", region: "대한민국", lang: "ko", local: "강남, 마포, 성수, 한강공원까지 — 1인 가구와 맞벌이 가정이 많아 평일 산책과 주말 돌봄 수요가 꾸준합니다.", dayRate: "3만~5만 원", walkRate: "1만 5천~2만 5천 원" },
  { slug: "busan", name: "부산", region: "대한민국", lang: "ko", local: "해운대, 광안리, 서면 — 바다를 따라 걷는 산책 코스와 여름 휴가철 돌봄 수요가 많습니다.", dayRate: "2만 5천~4만 5천 원", walkRate: "1만 5천~2만 원" },
  { slug: "incheon", name: "인천", region: "대한민국", lang: "ko", local: "송도, 청라, 부평 — 신도시 아파트 단지가 많아 반려견 돌봄 서비스가 빠르게 자리 잡고 있습니다.", dayRate: "2만 5천~4만 원", walkRate: "1만 5천~2만 원" },
  { slug: "daegu", name: "대구", region: "대한민국", lang: "ko", local: "수성구, 동성로, 앞산공원 — 여름이 더워 이른 아침과 저녁 산책 대행 수요가 높습니다.", dayRate: "2만 5천~4만 원", walkRate: "1만 5천~2만 원" },
  { slug: "daejeon", name: "대전", region: "대한민국", lang: "ko", local: "둔산, 유성, 갑천 산책로 — 연구단지의 맞벌이 가정이 많아 평일 돌봄이 꾸준합니다.", dayRate: "2만 5천~4만 원", walkRate: "1만 5천~2만 원" },
  // ---------- France (suite, v560) ----------
  { slug: "strasbourg", name: "Strasbourg", region: "Grand Est", lang: "fr", local: "Krutenau, Neudorf, parc de l'Orangerie : une ville cyclable où les promenades quotidiennes sont la norme.", dayRate: "16 à 24 €", walkRate: "10 à 15 €" },
  { slug: "montpellier", name: "Montpellier", region: "Occitanie", lang: "fr", local: "Écusson, Port-Marianne, les plages à 20 minutes : étudiants disponibles toute l'année.", dayRate: "16 à 24 €", walkRate: "10 à 15 €" },
  { slug: "rennes", name: "Rennes", region: "Bretagne", lang: "fr", local: "Thabor, Sainte-Anne, les Prairies Saint-Martin : une ville jeune où la garde entre voisins se professionnalise.", dayRate: "15 à 23 €", walkRate: "10 à 14 €" },
  { slug: "grenoble", name: "Grenoble", region: "Auvergne-Rhône-Alpes", lang: "fr", local: "Berriat, Île-Verte, la Bastille : chiens sportifs et propriétaires souvent en montagne le week-end.", dayRate: "15 à 23 €", walkRate: "10 à 14 €" },
  { slug: "rouen", name: "Rouen", region: "Normandie", lang: "fr", local: "Saint-Marc, Jardin des Plantes, les quais : familles et beaucoup de trajets vers Paris en semaine.", dayRate: "15 à 22 €", walkRate: "9 à 14 €" },
  { slug: "reims", name: "Reims", region: "Grand Est", lang: "fr", local: "Centre, Clairmarais, parc de Champagne : peu de sitters installés, une place à prendre.", dayRate: "15 à 22 €", walkRate: "9 à 14 €" },
  { slug: "toulon", name: "Toulon", region: "Provence-Alpes-Côte d'Azur", lang: "fr", local: "Mourillon, le Faron, les plages : gardes estivales et promenades au soleil.", dayRate: "16 à 24 €", walkRate: "10 à 15 €" },
  { slug: "angers", name: "Angers", region: "Pays de la Loire", lang: "fr", local: "La Doutre, Saint-Serge, le lac de Maine : une ville verte, très familiale.", dayRate: "15 à 22 €", walkRate: "9 à 14 €" },
  { slug: "dijon", name: "Dijon", region: "Bourgogne-Franche-Comté", lang: "fr", local: "Centre historique, lac Kir, parc de la Colombière : propriétaires qui voyagent souvent.", dayRate: "15 à 22 €", walkRate: "9 à 14 €" },
  { slug: "nimes", name: "Nîmes", region: "Occitanie", lang: "fr", local: "Écusson, Jardins de la Fontaine, les garrigues : promenades matinales avant la chaleur.", dayRate: "15 à 22 €", walkRate: "9 à 14 €" },
  // ---------- USA (suite, v560) ----------
  { slug: "san-francisco", name: "San Francisco", region: "California, USA", lang: "en", local: "The Mission, Noe Valley, Golden Gate Park: more dogs than kids, and owners who commute or travel constantly.", dayRate: "$45–75", walkRate: "$25–40" },
  { slug: "seattle", name: "Seattle", region: "Washington, USA", lang: "en", local: "Capitol Hill, Ballard, Green Lake: one of the most dog-owning cities in the US, with rainy-day walks in demand.", dayRate: "$40–65", walkRate: "$20–35" },
  { slug: "boston", name: "Boston", region: "Massachusetts, USA", lang: "en", local: "Back Bay, South End, the Esplanade: dense neighborhoods where midday walkers keep regular clients for years.", dayRate: "$40–65", walkRate: "$20–35" },
  { slug: "denver", name: "Denver", region: "Colorado, USA", lang: "en", local: "Highlands, Wash Park, Cherry Creek: outdoor-loving owners who hike on weekends and need sitters at home.", dayRate: "$35–60", walkRate: "$18–30" },
  { slug: "atlanta", name: "Atlanta", region: "Georgia, USA", lang: "en", local: "Midtown, Decatur, the BeltLine: HoPetSit's first Georgia members joined here — early sitters get the regulars.", dayRate: "$30–55", walkRate: "$15–25" },
  { slug: "phoenix", name: "Phoenix", region: "Arizona, USA", lang: "en", local: "Scottsdale, Tempe, Arcadia: early-morning walks in summer and snowbird owners who travel for months.", dayRate: "$30–55", walkRate: "$15–25" },
  { slug: "san-diego", name: "San Diego", region: "California, USA", lang: "en", local: "North Park, La Jolla, Ocean Beach: beach walks year-round and a military community that deploys often.", dayRate: "$40–65", walkRate: "$20–30" },
  { slug: "philadelphia", name: "Philadelphia", region: "Pennsylvania, USA", lang: "en", local: "Fishtown, Rittenhouse, Fairmount Park: row-house living means daily walks are a must.", dayRate: "$35–60", walkRate: "$18–30" },
  // ---------- Pologne (suite, v560) ----------
  { slug: "lodz", name: "Łódź", region: "Łódzkie, Polska", lang: "pl", local: "Manufaktura, Piotrkowska, park Poniatowskiego: coraz więcej młodych właścicieli psów w centrum.", dayRate: "45–80 zł", walkRate: "25–40 zł" },
  { slug: "szczecin", name: "Szczecin", region: "Zachodniopomorskie, Polska", lang: "pl", local: "Śródmieście, Pogodno, Jasne Błonia: zielone miasto, w którym długie spacery są codziennością.", dayRate: "45–80 zł", walkRate: "25–40 zł" },
  { slug: "katowice", name: "Katowice", region: "Śląskie, Polska", lang: "pl", local: "Koszutka, Ligota, Dolina Trzech Stawów: rodziny pracujące na zmiany potrzebują opieki w ciągu dnia.", dayRate: "45–80 zł", walkRate: "25–40 zł" },
  // ---------- Espagne (español) ----------
  { slug: "madrid", name: "Madrid", region: "Comunidad de Madrid, España", lang: "es", local: "Chamberí, Malasaña, Retiro y Casa de Campo: pisos pequeños, muchos perros y dueños que viajan a menudo.", dayRate: "18 a 28 €", walkRate: "10 a 16 €" },
  { slug: "barcelona", name: "Barcelona", region: "Cataluña, España", lang: "es", local: "Gràcia, Eixample, Poblenou y la Barceloneta: paseos junto al mar y una comunidad internacional que sale mucho.", dayRate: "18 a 28 €", walkRate: "10 a 16 €" },
  { slug: "valencia", name: "Valencia", region: "Comunidad Valenciana, España", lang: "es", local: "Ruzafa, El Carmen, el Jardín del Turia: 9 km de parque para pasear y familias que buscan cuidadores de confianza.", dayRate: "16 a 25 €", walkRate: "9 a 15 €" },
  { slug: "sevilla", name: "Sevilla", region: "Andalucía, España", lang: "es", local: "Triana, Nervión, el parque de María Luisa: paseos a primera hora en verano y cuidado en casa en vacaciones.", dayRate: "15 a 24 €", walkRate: "9 a 14 €" },
  { slug: "malaga", name: "Málaga", region: "Andalucía, España", lang: "es", local: "Centro, Teatinos, la Malagueta: residentes internacionales y dueños que viajan durante todo el año.", dayRate: "16 a 25 €", walkRate: "9 a 15 €" },
  { slug: "alicante", name: "Alicante", region: "Comunidad Valenciana, España", lang: "es", local: "Playa de San Juan, Centro, y toda la Marina Alta hasta Dénia y Jávea: los primeros miembros de HoPetSit en España están aquí.", dayRate: "16 a 25 €", walkRate: "9 a 15 €" },
  { slug: "bilbao", name: "Bilbao", region: "País Vasco, España", lang: "es", local: "Abando, Indautxu, el parque de Doña Casilda: una ciudad compacta donde los paseadores fidelizan rápido.", dayRate: "16 a 25 €", walkRate: "10 a 15 €" },
  { slug: "zaragoza", name: "Zaragoza", region: "Aragón, España", lang: "es", local: "Centro, Delicias, el parque Grande: pocos cuidadores instalados y mucha demanda en puentes y vacaciones.", dayRate: "15 a 23 €", walkRate: "9 a 14 €" },
  // ---------- Allemagne (Deutsch) ----------
  { slug: "berlin", name: "Berlin", region: "Berlin, Deutschland", lang: "de", local: "Prenzlauer Berg, Kreuzberg, Tempelhofer Feld: eine der hundefreundlichsten Städte Europas — und ständig neue Halter.", dayRate: "20 bis 30 €", walkRate: "12 bis 18 €" },
  { slug: "muenchen", name: "München", region: "Bayern, Deutschland", lang: "de", local: "Schwabing, Haidhausen, Englischer Garten: anspruchsvolle Halter, die zuverlässige Betreuung gut bezahlen.", dayRate: "22 bis 35 €", walkRate: "14 bis 20 €" },
  { slug: "hamburg", name: "Hamburg", region: "Hamburg, Deutschland", lang: "de", local: "Eimsbüttel, Ottensen, Alster und Elbstrand: lange Spaziergänge bei jedem Wetter sind hier Alltag.", dayRate: "20 bis 30 €", walkRate: "12 bis 18 €" },
  { slug: "koeln", name: "Köln", region: "Nordrhein-Westfalen, Deutschland", lang: "de", local: "Ehrenfeld, Südstadt, Stadtwald: junge Familien und viele Pendler, die tagsüber Betreuung brauchen.", dayRate: "18 bis 28 €", walkRate: "12 bis 17 €" },
  { slug: "frankfurt", name: "Frankfurt am Main", region: "Hessen, Deutschland", lang: "de", local: "Bornheim, Sachsenhausen, Stadtwald: Geschäftsreisende und Halter mit langen Arbeitstagen.", dayRate: "20 bis 30 €", walkRate: "12 bis 18 €" },
  { slug: "stuttgart", name: "Stuttgart", region: "Baden-Württemberg, Deutschland", lang: "de", local: "West, Vaihingen, Rosensteinpark: Hügel, Wälder und Halter, die am Wochenende gern wandern.", dayRate: "20 bis 30 €", walkRate: "12 bis 18 €" },
  // ---------- Italie (italiano) ----------
  { slug: "roma", name: "Roma", region: "Lazio, Italia", lang: "it", local: "Prati, Trastevere, Villa Borghese e Villa Pamphili: tantissimi cani in appartamento e proprietari spesso in viaggio.", dayRate: "18 a 28 €", walkRate: "10 a 16 €" },
  { slug: "milano", name: "Milano", region: "Lombardia, Italia", lang: "it", local: "Isola, Porta Romana, Parco Sempione: giornate lavorative lunghe e una forte domanda di passeggiate a mezzogiorno.", dayRate: "20 a 30 €", walkRate: "12 a 18 €" },
  { slug: "torino", name: "Torino", region: "Piemonte, Italia", lang: "it", local: "San Salvario, Crocetta, il Valentino: una città verde dove la passeggiata quotidiana è un'abitudine.", dayRate: "16 a 25 €", walkRate: "10 a 15 €" },
  { slug: "napoli", name: "Napoli", region: "Campania, Italia", lang: "it", local: "Vomero, Chiaia, Posillipo: pochi pet sitter organizzati e molte famiglie che cercano una persona di fiducia.", dayRate: "15 a 23 €", walkRate: "9 a 14 €" },
  { slug: "firenze", name: "Firenze", region: "Toscana, Italia", lang: "it", local: "Santo Spirito, Campo di Marte, le Cascine: residenti internazionali e proprietari che viaggiano spesso.", dayRate: "16 a 25 €", walkRate: "10 a 15 €" },
  { slug: "bologna", name: "Bologna", region: "Emilia-Romagna, Italia", lang: "it", local: "Bolognina, Santo Stefano, i Giardini Margherita: studenti disponibili e famiglie con cani di taglia media.", dayRate: "16 a 24 €", walkRate: "10 a 15 €" },
  // ---------- Portugal (português) ----------
  { slug: "lisboa", name: "Lisboa", region: "Lisboa, Portugal", lang: "pt", local: "Campo de Ourique, Alvalade, Monsanto: uma comunidade internacional que viaja muito e procura cuidadores de confiança.", dayRate: "15 a 25 €", walkRate: "8 a 14 €" },
  { slug: "porto", name: "Porto", region: "Porto, Portugal", lang: "pt", local: "Foz, Cedofeita, Parque da Cidade: passeios junto ao rio e ao mar, famílias que trabalham fora todo o dia.", dayRate: "14 a 22 €", walkRate: "8 a 13 €" },
  { slug: "braga", name: "Braga", region: "Braga, Portugal", lang: "pt", local: "Centro, São Vítor, Bom Jesus: uma cidade jovem, com estudantes disponíveis e poucos cuidadores instalados.", dayRate: "12 a 20 €", walkRate: "7 a 12 €" },
  { slug: "coimbra", name: "Coimbra", region: "Coimbra, Portugal", lang: "pt", local: "Baixa, Celas, o Choupal: estudantes com tempo livre e proprietários que viajam nas férias.", dayRate: "12 a 20 €", walkRate: "7 a 12 €" },
  // ---------- Japon (日本語) ----------
  { slug: "tokyo", name: "東京", region: "日本", lang: "ja", local: "世田谷、目黒、代々木公園周辺 — 単身世帯と共働き家庭が多く、平日の散歩代行と留守中のお世話の需要が安定しています。", dayRate: "4,000〜7,000円", walkRate: "2,000〜3,500円" },
  { slug: "osaka", name: "大阪", region: "日本", lang: "ja", local: "北区、天王寺、鶴見緑地 — 小型犬が多く、旅行や出張の際の預かりニーズが高いエリアです。", dayRate: "3,500〜6,000円", walkRate: "1,800〜3,000円" },
  { slug: "nagoya", name: "名古屋", region: "日本", lang: "ja", local: "千種、名東、鶴舞公園 — 郊外に一戸建てが多く、自宅でのお世話や長めの散歩が好まれます。", dayRate: "3,500〜6,000円", walkRate: "1,800〜3,000円" },
  { slug: "fukuoka", name: "福岡", region: "日本", lang: "ja", local: "中央区、早良区、大濠公園 — 住みやすさで人気の街、若い飼い主が多くシッターはまだ少数です。", dayRate: "3,000〜5,500円", walkRate: "1,500〜2,800円" },
];

export const RECRUIT_PATH_PREFIX: Record<RecruitLang, string> = {
  fr: "/devenir-petsitter",
  en: "/become-a-pet-sitter",
  pl: "/zostan-opiekunem",
  ko: "/pet-sitter-korea",
  es: "/ser-cuidador-de-mascotas",
  de: "/tiersitter-werden",
  it: "/diventare-pet-sitter",
  pt: "/ser-pet-sitter",
  ja: "/pet-sitter-japan",
};

export function recruitCitiesFor(lang: RecruitLang): RecruitCity[] {
  return RECRUIT_CITIES.filter((c) => c.lang === lang);
}

export function recruitCity(lang: RecruitLang, slug: string): RecruitCity | undefined {
  return RECRUIT_CITIES.find((c) => c.lang === lang && c.slug === slug);
}

export function recruitPaths(): string[] {
  return RECRUIT_CITIES.map((c) => `${RECRUIT_PATH_PREFIX[c.lang]}/${c.slug}`);
}

// v560 — pages côté PROPRIÉTAIRE « trouver un pet sitter à <ville> » (même
// donnée, deuxième intention de recherche). Composant OwnerCityPage.
export const OWNER_PATH_PREFIX: Record<RecruitLang, string> = {
  fr: "/garde-animaux",
  en: "/pet-sitting",
  pl: "/opieka-nad-zwierzetami",
  ko: "/pet-sitting-korea",
  es: "/cuidado-de-mascotas",
  de: "/tierbetreuung",
  it: "/custodia-animali",
  pt: "/cuidado-de-animais",
  ja: "/pet-sitting-japan",
};

export function ownerPaths(): string[] {
  return RECRUIT_CITIES.map((c) => `${OWNER_PATH_PREFIX[c.lang]}/${c.slug}`);
}

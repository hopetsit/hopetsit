// v547 — SEO programmatique « devenir pet sitter à <ville> ».
// Stratégie supply-first, Paris d'abord (objectif : premiers clients), puis
// USA, Pologne, Corée. Une page statique par ville/arrondissement, générée
// par le composant RecruitCityPage. Ajouter une ligne = une page indexable.

export type RecruitLang = "fr" | "en" | "pl" | "ko";

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
];

export const RECRUIT_PATH_PREFIX: Record<RecruitLang, string> = {
  fr: "/devenir-petsitter",
  en: "/become-a-pet-sitter",
  pl: "/zostan-opiekunem",
  ko: "/pet-sitter-korea",
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

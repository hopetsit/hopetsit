// 01/10/2026 (SAM) — push USA gratuit (Daniel : « pousser San Francisco, Dallas
// et New York gratuitement »). Règle SEO du 20/09 : aucune page nouvelle, on
// rend UNIQUES les pages qui existent déjà (/pet-sitting/<ville> et
// /become-a-pet-sitter/<ville>) avec du contenu local réel : quartiers, parcs
// où l'on promène, contraintes locales. Aucun chiffre d'activité, aucune
// promesse de revenus. Composant serveur, aucun hook.

type Mode = "owner" | "recruit";
type Guide = {
  hoods: string[];
  walks: { name: string; note: string }[];
  tips: string[];
  faq: Record<Mode, { q: string; a: string }[]>;
};

const GUIDES: Record<string, Guide> = {
  "new-york": {
    hoods: ["Upper West Side", "Upper East Side", "Harlem", "Park Slope", "Williamsburg", "Astoria", "Long Island City", "the East Village"],
    walks: [
      { name: "Central Park", note: "off-leash courtesy hours before 9 a.m. and after 9 p.m. — the rest of the day dogs stay leashed" },
      { name: "Prospect Park", note: "Long Meadow is Brooklyn's favorite early-morning off-leash spot" },
      { name: "Tompkins Square Park dog run", note: "the East Village run, busy every evening" },
      { name: "Hudson River Park", note: "dog runs along the West Side, handy for Chelsea and the West Village" },
    ],
    tips: [
      "Most New York dogs live in apartments without a yard, so a midday walk on workdays matters more than anywhere else.",
      "Doorman buildings usually need the sitter's name in advance — add it to your request so the key handover is smooth.",
      "Summer pavement and winter de-icing salt are both hard on paws: ask your sitter to keep walks short at noon in July and to wipe paws in winter.",
    ],
    faq: {
      owner: [
        { q: "Can my dog walker take my dog off-leash in Central Park?", a: "Only during the park's courtesy hours (before 9 a.m. and after 9 p.m.) and only in the areas where it is allowed. Tell your walker in the request whether your dog has reliable recall." },
        { q: "How does key handover work in a doorman building?", a: "Give your doorman the sitter's first name before the first visit, or meet the sitter once in person. You chat with the sitter in the app before you book, so you can arrange it there." },
      ],
      recruit: [
        { q: "Where do New York dog walkers find regular clients?", a: "Mostly in apartment neighborhoods where owners work long days: the Upper West Side, Park Slope, Astoria or Long Island City. Set your service area around the blocks you can reach on foot." },
        { q: "What do New York owners expect from a walker?", a: "Punctual midday walks, respect for building rules and leash laws, and a short update after each walk. HoPetSit shares the walk live on the map so the owner sees it." },
      ],
    },
  },
  "san-francisco": {
    hoods: ["the Mission", "Noe Valley", "Bernal Heights", "the Marina", "Pacific Heights", "the Inner Richmond", "the Sunset", "SoMa"],
    walks: [
      { name: "Fort Funston", note: "ocean bluffs and off-leash trails, a classic weekend walk" },
      { name: "Crissy Field", note: "flat beach walk with the Golden Gate in view" },
      { name: "Bernal Heights Park", note: "hilltop loop where many local dogs run every morning" },
      { name: "Golden Gate Park", note: "large park with dedicated dog play areas" },
      { name: "Mission Dolores Park", note: "the neighborhood meeting point for Mission and Noe Valley dogs" },
    ],
    tips: [
      "Many San Francisco owners commute down the Peninsula or travel for work: overnight sitting and drop-in visits for cats are common requests.",
      "Microclimates are real — fog on the west side, sun in the Mission — so pack a towel for beach walks at Fort Funston or Crissy Field.",
      "Parking is hard in most neighborhoods: mention in your request whether the sitter can walk or bike to you.",
    ],
    faq: {
      owner: [
        { q: "Where can my dog run off-leash in San Francisco?", a: "Popular spots include Fort Funston, parts of Crissy Field and the dog play areas of Golden Gate Park. Rules vary by area and season, so tell your sitter which places your dog already knows." },
        { q: "Can a sitter look after my cat while I travel?", a: "Yes. Post a request for drop-in visits: the sitter comes to feed, play and clean the litter box, and you get updates in the app." },
      ],
      recruit: [
        { q: "Which San Francisco neighborhoods are best for a new pet sitter?", a: "Start with the neighborhood you live in. Owners prefer someone close by, and walking or biking between clients is much easier than driving and parking." },
        { q: "Do I need a car to pet sit in San Francisco?", a: "No. Most walks happen within a few blocks of the owner's home. Set your service area to what you can reach on foot, by bike or by Muni." },
      ],
    },
  },
  dallas: {
    hoods: ["Uptown", "Lakewood", "Lower Greenville", "the M Streets", "Oak Cliff and Bishop Arts", "Lake Highlands", "Deep Ellum", "Preston Hollow"],
    walks: [
      { name: "White Rock Lake", note: "the lake loop and its dog park, the east side's favorite walk" },
      { name: "Katy Trail", note: "shaded trail through Uptown, busy at sunrise and after work" },
      { name: "Klyde Warren Park", note: "downtown deck park with a small dog area" },
      { name: "Bark Park Central", note: "Deep Ellum dog park under the freeway, shaded in summer" },
    ],
    tips: [
      "Texas summers are hot: from June to September, good sitters walk dogs early in the morning or after sunset and keep midday outings short.",
      "Many Dallas homes have a yard — say in your request whether the sitter should walk your dog or just do yard time and play.",
      "Plano, Frisco, Richardson and Irving are covered too: set the exact address in your request so nearby sitters see it.",
    ],
    faq: {
      owner: [
        { q: "How do sitters handle the Dallas summer heat?", a: "Walks move to early morning and evening, with water and shade. Tell your sitter in the request if your dog is a short-nosed breed or older — they need even shorter outings in the heat." },
        { q: "Is my suburb covered, like Plano or Frisco?", a: "Yes. Your request is shown to sitters around your address, not only in Dallas proper." },
      ],
      recruit: [
        { q: "When are Dallas pet sitters most in demand?", a: "Weekends, holidays and summer trips for overnight sitting, and workdays for midday walks in Uptown, Lakewood and the M Streets." },
        { q: "Do I need a car to pet sit in Dallas?", a: "It helps, because distances are long. Many sitters focus on a few neighborhoods close to home to keep travel short." },
      ],
    },
  },
  // 08/10/2026 — Search Console : 44 pages rattachées par Google à des sites
  // étrangers (747live.bet, marcustheatres.com…). Ces pages étaient identiques
  // à 91-93 % d'une ville à l'autre ; San Francisco, rendue unique ici le 01/10,
  // est revenue « Envoyée et indexée » sous sa propre URL le 06/10. Même remède
  // pour les villes US touchées. Faits locaux connus et durables seulement.
  frisco: {
    hoods: ["Starwood", "Stonebriar", "Phillips Creek Ranch", "Newman Village", "Richwoods", "the Frisco Square area", "Hollyhock"],
    walks: [
      { name: "Frisco Commons Park", note: "lawns and loop trails near the historic downtown, the go-to evening walk" },
      { name: "Neighborhood trails", note: "most master-planned communities have their own trail network and ponds, so many walks start at the front door" },
      { name: "The Star district", note: "open plazas around the Cowboys headquarters, busy on game days" },
    ],
    tips: [
      "Frisco grew fast: many households are young families with a new puppy, and puppies need short visits several times a day rather than one long walk.",
      "Most homes have a fenced backyard — say in your request whether the sitter should walk your dog or let it play in the yard, and mention any gate code or HOA rule.",
      "From June to September, walks move to sunrise and after sunset: the pavement in new subdivisions has little shade.",
    ],
    faq: {
      owner: [
        { q: "Are there pet sitters in Frisco or only in Dallas?", a: "Your request is shown to sitters around your address, so sitters from Frisco, Plano, McKinney and Little Elm can see it." },
        { q: "Can a sitter look after a young puppy during the workday?", a: "Yes. Ask for two or three short drop-in visits instead of one long walk: feeding, a potty break and play. You agree on the schedule in the chat before booking." },
      ],
      recruit: [
        { q: "Who needs a pet sitter in Frisco?", a: "Families who commute to Dallas or travel often, and owners of puppies who cannot stay alone all day. Drop-in visits and overnight stays are the most common requests." },
        { q: "Do I need a car to pet sit in Frisco?", a: "Yes in most cases: distances between subdivisions are long. Keep your service area to the neighborhoods you can reach in a few minutes." },
      ],
    },
  },
  austin: {
    hoods: ["Zilker", "Travis Heights", "Bouldin Creek", "Hyde Park", "Mueller", "East Austin", "Crestview", "Allandale"],
    walks: [
      { name: "Zilker Metropolitan Park", note: "big off-leash area on the lawns near Barton Springs, busy every weekend" },
      { name: "Red Bud Isle", note: "small wooded island on Lady Bird Lake where dogs can run off-leash and swim" },
      { name: "Lady Bird Lake Hike-and-Bike Trail", note: "the 10-mile loop around the lake, leashed, at its best at sunrise" },
      { name: "Auditorium Shores", note: "off-leash lawn on the south shore with a view of downtown" },
    ],
    tips: [
      "Toxic blue-green algae has been found in Lady Bird Lake in several summers: check the City of Austin advisories before your dog swims, and tell your sitter if swimming is off-limits.",
      "Texas heat is serious from June to September: good sitters walk dogs early and late and carry water.",
      "Austin traffic is slow at rush hour — pick a sitter who lives in or near your neighborhood.",
    ],
    faq: {
      owner: [
        { q: "Can my sitter take my dog to an off-leash area in Austin?", a: "Yes, if your dog has reliable recall. Zilker Park, Red Bud Isle and Auditorium Shores are popular. Say in your request which places your dog already knows and whether swimming is allowed." },
        { q: "What happens on very hot days?", a: "Walks move to early morning and evening, with water and shade. Tell your sitter if your dog is older or short-nosed: they need even shorter outings in the heat." },
      ],
      recruit: [
        { q: "Where do Austin pet sitters find clients?", a: "In central neighborhoods where people work long days, like Travis Heights, Hyde Park, Mueller and East Austin, and among owners who travel for festivals and holidays." },
        { q: "What should I check before letting a dog swim?", a: "The owner's permission first, then the city's algae advisories for Lady Bird Lake. When in doubt, keep the dog out of the water." },
      ],
    },
  },
  "kansas-city": {
    hoods: ["Brookside", "Waldo", "Westport", "the Plaza area", "the Crossroads", "River Market", "Midtown", "North Kansas City"],
    walks: [
      { name: "Penn Valley Park", note: "has a fenced off-leash dog park near Union Station" },
      { name: "Loose Park", note: "leashed loop around the lawns and the rose garden" },
      { name: "Brush Creek trail", note: "flat paved walk along the creek by the Country Club Plaza" },
      { name: "Shawnee Mission Park", note: "on the Kansas side, one of the largest off-leash areas in the region, with lake access" },
    ],
    tips: [
      "The metro spans two states: write your full address in the request so sitters on both the Missouri and Kansas sides can see it.",
      "Summers are hot and humid and winters bring ice: ask your sitter to adapt the length of walks and wipe paws after salted sidewalks.",
      "Spring thunderstorms scare many dogs — tell your sitter if yours hides or needs a safe room during storms.",
    ],
    faq: {
      owner: [
        { q: "I live in Overland Park or Olathe — am I covered?", a: "Yes. Requests are shown to sitters around your address, on the Kansas side as well as in Kansas City, Missouri." },
        { q: "My dog is afraid of storms. What should I tell the sitter?", a: "Where your dog likes to hide, whether it can stay alone during a storm and any calming routine you use. Put it in your request and the chat before booking." },
      ],
      recruit: [
        { q: "Which Kansas City neighborhoods are good to start in?", a: "Brookside, Waldo, Westport and Midtown have many dog owners living close together, so you can fit several visits into one trip." },
        { q: "Can I pet sit across the state line?", a: "Yes. Set your service area around where you live; owners on both sides of the state line can book you." },
      ],
    },
  },
  "new-orleans": {
    hoods: ["Uptown", "the Garden District", "Mid-City", "the Irish Channel", "the Bywater", "the Marigny", "Lakeview", "Algiers Point"],
    walks: [
      { name: "City Park", note: "large park in Mid-City with NOLA City Bark, the off-leash dog park (membership tag required)" },
      { name: "Audubon Park", note: "the shaded loop around the lagoon, leashed, Uptown's daily walk" },
      { name: "The Fly", note: "riverfront lawn behind Audubon Park, open and breezy" },
      { name: "Bayou St. John", note: "quiet walk along the water between Mid-City and City Park" },
    ],
    tips: [
      "Mosquitoes are around most of the year, so heartworm and flea prevention are year-round — let your sitter know your dog's schedule.",
      "Hurricane season runs from June to November: share your evacuation plan and a backup contact with your sitter if you travel during those months.",
      "Mardi Gras and parade days mean crowds, noise and closed streets — plan walk routes away from the parade routes.",
    ],
    faq: {
      owner: [
        { q: "Can a sitter take my dog to City Park's dog park?", a: "NOLA City Bark needs a membership tag. If your dog has one, mention it in the request; otherwise your sitter can walk your dog in the rest of City Park on leash." },
        { q: "What if a storm hits while I am away?", a: "Agree on a plan before booking: where your dog goes, who has a key and who to call. The chat keeps it written down for both of you." },
      ],
      recruit: [
        { q: "When are New Orleans pet sitters most in demand?", a: "Around Mardi Gras, festival weekends and holidays, when owners travel or work long shifts in hospitality, and for daily walks in Uptown and Mid-City." },
        { q: "What should a sitter know about the heat?", a: "Walk early and late, avoid hot pavement, carry water and watch for signs of overheating. Owners appreciate a short update after each walk." },
      ],
    },
  },
  "birmingham-al": {
    hoods: ["Avondale", "Highland Park", "Southside", "Crestwood", "Forest Park", "Lakeview", "Homewood", "Mountain Brook"],
    walks: [
      { name: "Railroad Park", note: "downtown lawns and paths, leashed, lively in the evening" },
      { name: "Red Mountain Park", note: "wooded trails on the ridge, with a dog park" },
      { name: "Avondale Park", note: "the neighborhood park for Avondale and Forest Park dogs" },
      { name: "Vulcan Trail", note: "short flat trail below the Vulcan statue with a view over the city" },
    ],
    tips: [
      "Spring brings severe weather: share with your sitter where your dog should shelter if there is a tornado warning.",
      "Summers are hot and humid — midday walks stay short and shaded.",
      "The city is hilly: tell your sitter if your dog is older or has joint problems so walks stay gentle.",
    ],
    faq: {
      owner: [
        { q: "Are suburbs like Homewood or Mountain Brook covered?", a: "Yes. Requests are shown to sitters around your address, not only in the city of Birmingham." },
        { q: "What should my sitter do during a tornado warning?", a: "Follow the plan you agree on in the chat: the safest room in your home, where the leash and crate are, and who to call." },
      ],
      recruit: [
        { q: "Where do Birmingham pet sitters find clients?", a: "In walkable neighborhoods like Avondale, Highland Park, Southside and Crestwood, and among families in Homewood and Mountain Brook who travel." },
        { q: "Do I need a car to pet sit in Birmingham?", a: "Usually yes, because neighborhoods are spread out over the hills. Keep your service area close to home." },
      ],
    },
  },
  phoenix: {
    hoods: ["Arcadia", "Ahwatukee", "Encanto", "Roosevelt Row", "North Central", "Moon Valley", "Desert Ridge", "Laveen"],
    walks: [
      { name: "Papago Park", note: "flat paths among the red buttes, leashed, best at sunrise" },
      { name: "Encanto Park", note: "shaded lagoon loop close to downtown" },
      { name: "Steele Indian School Park", note: "wide lawns in Midtown, popular in the cooler months" },
      { name: "Phoenix Mountains Preserve", note: "desert trails for fit dogs, early mornings only in summer" },
    ],
    tips: [
      "Phoenix bans dogs from city trails when it is 100°F or hotter. From May to September, walks happen at dawn or after dark.",
      "Asphalt burns paws in summer: test it with the back of your hand for seven seconds before a walk.",
      "On desert trails, keep dogs leashed and on the path — rattlesnakes and cactus spines are common.",
    ],
    faq: {
      owner: [
        { q: "How do sitters walk dogs in the Phoenix summer?", a: "Very early or late, short, with water. On the hottest days a sitter may replace the walk with indoor play — agree on it in the chat." },
        { q: "I am a snowbird. Can a sitter look after my pet for months?", a: "Yes, but plan regular drop-in visits or several sitters over the season. Describe the dates and the routine in your request." },
      ],
      recruit: [
        { q: "When are Phoenix pet sitters most in demand?", a: "In winter, when visitors and snowbirds arrive and travel, and during summer trips when locals escape the heat." },
        { q: "What should I know about the trail rules?", a: "Dogs are not allowed on city trails at 100°F or more. Plan walks for dawn or after dark from May to September." },
      ],
    },
  },
  fresno: {
    hoods: ["the Tower District", "Fig Garden", "Old Fig", "the Woodward Park area", "Sunnyside", "Bullard", "Copper River", "Clovis nearby"],
    walks: [
      { name: "Woodward Park", note: "large park in north Fresno with a fenced dog park" },
      { name: "Sugar Pine Trail", note: "paved trail through north Fresno, flat and easy" },
      { name: "Roeding Park", note: "shaded park west of downtown" },
    ],
    tips: [
      "Summer days often pass 100°F: walks happen at sunrise or after sunset.",
      "In spring, foxtail grass seeds get stuck in paws, ears and noses — check your dog after every walk in dry grass.",
      "During wildfire season the air can turn smoky: ask your sitter to keep walks short when air quality is poor.",
    ],
    faq: {
      owner: [
        { q: "Is Clovis covered too?", a: "Yes. Your request is shown to sitters around your address, in Fresno and Clovis alike." },
        { q: "What do sitters do on smoky days?", a: "Short potty breaks instead of long walks, and indoor play. You can agree on it in the chat before booking." },
      ],
      recruit: [
        { q: "Where can I start pet sitting in Fresno?", a: "Close to home: the Tower District, Fig Garden and north Fresno around Woodward Park have many dog owners." },
        { q: "What is the main seasonal risk for dogs?", a: "Heat in summer and foxtails in spring. Walk early, avoid dry grass and check paws and ears after each walk." },
      ],
    },
  },
  milwaukee: {
    hoods: ["Bay View", "the Third Ward", "the East Side", "Riverwest", "Walker's Point", "Washington Heights", "Wauwatosa", "Shorewood"],
    walks: [
      { name: "Lake Park", note: "bluff-top paths along Lake Michigan on the East Side" },
      { name: "Estabrook Park", note: "has a fenced off-leash dog exercise area by the Milwaukee River" },
      { name: "Oak Leaf Trail", note: "paved trail network that runs through the whole county" },
      { name: "Hank Aaron State Trail", note: "flat trail along the Menomonee River valley" },
    ],
    tips: [
      "Winters are long and cold: road salt hurts paws, so ask your sitter to wipe paws or use booties.",
      "The lakefront is windy even in spring — short-haired dogs may need a coat.",
      "Summer weekends are busy with festivals by the lake: plan walk routes away from the crowds.",
    ],
    faq: {
      owner: [
        { q: "Are Wauwatosa and Shorewood covered?", a: "Yes. Requests are shown to sitters around your address, not only in the city of Milwaukee." },
        { q: "What happens on very cold days?", a: "Shorter walks, paws wiped after salted sidewalks and more indoor play. Tell your sitter if your dog wears a coat or booties." },
      ],
      recruit: [
        { q: "Where do Milwaukee pet sitters find regular clients?", a: "In apartment neighborhoods like the Third Ward, the East Side, Bay View and Walker's Point, where owners need midday walks." },
        { q: "Is winter a slow season?", a: "Not for drop-in visits and holiday sitting: owners travel around Thanksgiving and the winter holidays." },
      ],
    },
  },
  honolulu: {
    hoods: ["Kaimukī", "Mānoa", "Kakaʻako", "Makiki", "Kāhala", "Hawaiʻi Kai", "Nuʻuanu", "Kailua (windward side)"],
    walks: [
      { name: "Kapiʻolani Park", note: "big lawns at the foot of Diamond Head, leashed" },
      { name: "Ala Wai Canal path", note: "flat walk along the canal, cooler early in the morning" },
      { name: "Hawaiʻi Kai Dog Park", note: "fenced dog park in east Oʻahu" },
    ],
    tips: [
      "Pets are not allowed on the Diamond Head summit trail, and many beaches restrict dogs — check the rules before a beach walk.",
      "Hawaiʻi is rabies-free: pets arriving from the mainland go through the state's quarantine program, so plan any move well ahead.",
      "Sun and hot sand are hard on paws all year: walk early, carry water, look for shade.",
    ],
    faq: {
      owner: [
        { q: "Can my sitter take my dog to the beach?", a: "Only where dogs are allowed — many Oʻahu beaches restrict them. Tell your sitter which spots your dog already goes to." },
        { q: "Is the windward side covered?", a: "Yes. Your request is shown to sitters around your address, including Kailua and Kāneʻohe." },
      ],
      recruit: [
        { q: "Who needs a pet sitter in Honolulu?", a: "Owners who fly to the neighbor islands or the mainland, often for several days, and people working long shifts who need midday walks." },
        { q: "What do Honolulu owners expect?", a: "Walks at cool hours, care with the sun and the heat, and respect for park and beach rules." },
      ],
    },
  },
  "virginia-beach": {
    hoods: ["the North End", "Great Neck", "Lynnhaven", "Chic's Beach", "Kempsville", "Red Mill", "Princess Anne", "Sandbridge"],
    walks: [
      { name: "First Landing State Park", note: "trails through the maritime forest, leashed" },
      { name: "Mount Trashmore Park", note: "lakes, hills and a dog park in the middle of the city" },
      { name: "Red Wing Park", note: "shaded park with a fenced dog area" },
    ],
    tips: [
      "Dogs are restricted on the resort-area beach and boardwalk in summer — check the season's rules before a beach walk.",
      "Many owners are Navy families: deployments and moves mean long bookings, so agree on routines and an emergency contact in writing.",
      "Ticks are common in wooded parks like First Landing: check your dog after each walk.",
    ],
    faq: {
      owner: [
        { q: "Can a sitter care for my pet during a deployment?", a: "Yes. Post a long request with the dates, the routine and a backup contact; you can chat with sitters before you book." },
        { q: "Can my dog go to the beach with the sitter?", a: "Only where and when dogs are allowed. Summer rules are strict in the resort area; quieter beaches and parks are the safer choice." },
      ],
      recruit: [
        { q: "Who needs a pet sitter in Virginia Beach?", a: "Military families during deployments and trainings, and owners who travel in the summer season." },
        { q: "What should I check after a park walk?", a: "Ticks, especially after wooded trails. Owners appreciate a short message saying the dog was checked." },
      ],
    },
  },
  albuquerque: {
    hoods: ["Nob Hill", "the North Valley", "the Northeast Heights", "Old Town", "Downtown", "Ridgecrest", "the Westside", "Los Ranchos"],
    walks: [
      { name: "Paseo del Bosque Trail", note: "flat trail through the cottonwoods along the Rio Grande" },
      { name: "Elena Gallegos Open Space", note: "foothill trails below the Sandia Mountains, leashed" },
      { name: "Tingley Beach area", note: "paths around the ponds next to the bosque" },
    ],
    tips: [
      "At more than 5,000 feet, the sun is strong and the air is dry: carry water even on mild days.",
      "Goatheads (puncture vine thorns) get stuck in paws — check paws after walks on dry ground.",
      "During the Balloon Fiesta in October, early-morning burners can scare dogs on the north side of town.",
    ],
    faq: {
      owner: [
        { q: "What should my sitter know about the dry climate?", a: "Bring water, avoid hot midday walks in summer and check paws for goatheads. Put any of your dog's sensitivities in the request." },
        { q: "My dog is afraid of the balloons. What can a sitter do?", a: "Keep early-morning walks short or indoors during the Fiesta and stay away from launch areas. Agree on it in the chat." },
      ],
      recruit: [
        { q: "Where do Albuquerque pet sitters find clients?", a: "In Nob Hill, the Northeast Heights and the North Valley, and among owners who travel during the Fiesta and the holidays." },
        { q: "What are the local walking hazards?", a: "Strong sun, dry air and goathead thorns. Walk early, carry water and check paws after each walk." },
      ],
    },
  },
  "long-beach": {
    hoods: ["Belmont Shore", "Naples", "Alamitos Beach", "Bluff Park", "Bixby Knolls", "California Heights", "Los Altos", "Downtown"],
    walks: [
      { name: "Rosie's Dog Beach", note: "off-leash dog beach in Belmont Shore" },
      { name: "Bluff Park", note: "ocean-view lawn along Ocean Boulevard" },
      { name: "El Dorado Park", note: "large park on the east side with wide lawns" },
      { name: "Recreation Park", note: "east-side park with a dog park" },
    ],
    tips: [
      "Many Long Beach owners live in apartments near the shore: midday walks matter on workdays.",
      "Rosie's Dog Beach has set hours — check them before planning a beach walk with your sitter.",
      "Sand and saltwater dry out paws and coats: a quick rinse after the beach keeps skin healthy.",
    ],
    faq: {
      owner: [
        { q: "Can my sitter take my dog to Rosie's Dog Beach?", a: "Yes, during the beach's opening hours and if your dog is sociable off-leash. Say in your request whether you want the beach or a leashed walk." },
        { q: "Can I find a sitter for my cat in an apartment?", a: "Yes. Post a request for drop-in visits: feeding, litter and play, with updates in the app." },
      ],
      recruit: [
        { q: "Where do Long Beach pet sitters find clients?", a: "Along the shore in Belmont Shore, Alamitos Beach and Bluff Park, where many apartment owners need midday walks." },
        { q: "Do I need a car?", a: "Not always: many walks happen within a few blocks. Set your service area to what you can reach on foot or by bike." },
      ],
    },
  },
  // 09/10/2026 (GUS) — 9 villes US à fortes impressions Google et 0 clic
  // (Los Angeles 545, Indianapolis 389, Denver 353, Atlanta 304, Cincinnati 295,
  // Miami 291, Columbus 248, Houston 248, Decatur GA 220 affichages / 28 j,
  // positions 13-24). Même remède : contenu local réel, aucun chiffre inventé.
  "los-angeles": {
    hoods: ["Silver Lake", "Los Feliz", "Echo Park", "Santa Monica", "Venice", "Culver City", "Pasadena", "Sherman Oaks", "Studio City"],
    walks: [
      { name: "Runyon Canyon", note: "the Hollywood hike where many local dogs go off-leash on the marked trails — early mornings beat the heat and the crowds" },
      { name: "Griffith Park", note: "miles of trails on leash, with shade along the Fern Dell and Ferndell Drive side" },
      { name: "Silver Lake Dog Park", note: "the Eastside's busiest off-leash park, by the reservoir" },
      { name: "Rosie's Dog Beach, Long Beach", note: "the only official off-leash beach in Los Angeles County, worth the drive for water dogs" },
      { name: "Sepulveda Basin Off-Leash Dog Park", note: "a large fenced park in the Valley, with a separate small-dog area" },
    ],
    tips: [
      "Los Angeles is a driving city: say in your request whether the sitter can reach you without a long freeway drive, or look for someone in your own neighborhood.",
      "Summer afternoons are hot and the pavement burns paws — walks happen early in the morning or after sunset from June to September.",
      "Entertainment and travel schedules change at the last minute: tell your sitter how flexible you need them to be before you book.",
    ],
    faq: {
      owner: [
        { q: "Where can my dog run off-leash in Los Angeles?", a: "Fenced dog parks such as Silver Lake Dog Park or the Sepulveda Basin Off-Leash Dog Park, and the marked off-leash trails of Runyon Canyon. Elsewhere in the city dogs stay on a leash. Tell your sitter which places your dog already knows." },
        { q: "I travel a lot for work. Can a sitter stay at my home?", a: "Yes. Post a request for overnight sitting: the sitter stays with your pet at your place, keeps the usual routine and sends you updates and photos in the app." },
      ],
      recruit: [
        { q: "Which Los Angeles neighborhoods are easiest to start in?", a: "Your own. Owners prefer someone close by, and in Los Angeles that means avoiding freeway drives between clients. Set your service area to a few neighborhoods you can reach in minutes." },
        { q: "What do Los Angeles owners ask for most?", a: "Midday walks for apartment dogs on the Westside and the Eastside, and overnight sitting when they travel. The map in HoPetSit shows owners nearby who are looking for help." },
      ],
    },
  },
  indianapolis: {
    hoods: ["Broad Ripple", "Fountain Square", "Irvington", "Meridian-Kessler", "Butler-Tarkington", "Mass Ave", "Fishers", "Carmel"],
    walks: [
      { name: "Broad Ripple Park dog park", note: "a fenced off-leash area by the White River, the Northside's regular meeting point" },
      { name: "Monon Trail", note: "a long paved trail from downtown through Broad Ripple to Carmel, ideal for leashed walks" },
      { name: "Eagle Creek Park", note: "one of the largest city parks in the country, with wooded trails and a dedicated dog park" },
      { name: "Paul Ruster Park dog park", note: "the Eastside's fenced park with room to run" },
    ],
    tips: [
      "Indianapolis is affordable and spread out: most homes have a yard, so owners mostly need drop-in visits and overnight sitting when they travel.",
      "Winters are cold and icy — ask your sitter to wipe paws after salted sidewalks and to shorten walks on the coldest days.",
      "Race weekends and conventions fill the city: book your sitter early for May and for big event dates.",
    ],
    faq: {
      owner: [
        { q: "Where do Indianapolis dog walkers take dogs?", a: "On the Monon Trail, in Broad Ripple Park or Eagle Creek Park, and in the fenced dog parks around the city. You can see each walk live on the map in the app." },
        { q: "Can I get someone to feed my cat while I am away?", a: "Yes. Post a request for drop-in visits and a sitter nearby will come to feed, play and clean the litter box, with a short update after each visit." },
      ],
      recruit: [
        { q: "Is there demand for pet sitters in Indianapolis?", a: "Owners here regularly look for someone close by for drop-in visits, dog walks and overnight stays. Start in your own neighborhood and set a service area you can reach easily." },
        { q: "Do I need experience to start?", a: "You need to be reliable, comfortable with animals and clear about what you offer. Complete your profile with photos and the services you provide, then answer requests on the map." },
      ],
    },
  },
  denver: {
    hoods: ["the Highlands", "Washington Park", "Cherry Creek", "Capitol Hill", "Sloan's Lake", "Park Hill", "Baker", "Stapleton/Central Park"],
    walks: [
      { name: "Cherry Creek State Park off-leash area", note: "a huge fenced-free off-leash area with water access, the weekend favorite" },
      { name: "Washington Park", note: "a classic loop around the lakes, dogs on leash" },
      { name: "Sloan's Lake Park", note: "a flat lakeside walk on the west side" },
      { name: "Chatfield State Park dog off-leash area", note: "south of the city, trails and ponds for swimming" },
      { name: "Railyard Dog Park", note: "downtown's fenced park near Union Station" },
    ],
    tips: [
      "Denver owners hike and ski on weekends: weekend day care and overnight sitting are the most common requests.",
      "Altitude and dry air mean dogs need water on every walk, and summer thunderstorms arrive fast in the afternoon.",
      "Snow days are frequent in winter — agree with your sitter on what happens when roads are bad.",
    ],
    faq: {
      owner: [
        { q: "Where can my dog go off-leash near Denver?", a: "The off-leash areas of Cherry Creek State Park and Chatfield State Park are the best known, plus fenced city dog parks such as Railyard Dog Park. Inside most city parks dogs stay on a leash." },
        { q: "Can a sitter watch my dog while I ski for the weekend?", a: "Yes. Post a request for the weekend: a nearby sitter can host your dog or stay at your home, and you follow updates in the app." },
      ],
      recruit: [
        { q: "When is pet sitting demand highest in Denver?", a: "Weekends and holidays, when owners head to the mountains. If you are free on weekends you will find regular clients quickly." },
        { q: "Which Denver neighborhoods have the most dogs?", a: "The Highlands, Washington Park, Capitol Hill and Sloan's Lake are dense with dog owners. Start in the one you live in and keep your service area small." },
      ],
    },
  },
  atlanta: {
    hoods: ["Midtown", "Virginia-Highland", "Inman Park", "Old Fourth Ward", "Grant Park", "Decatur", "Buckhead", "East Atlanta"],
    walks: [
      { name: "Piedmont Park Dog Park", note: "Midtown's fenced off-leash park, with a separate small-dog area" },
      { name: "The Atlanta BeltLine Eastside Trail", note: "a paved loop through Old Fourth Ward and Inman Park, dogs on leash" },
      { name: "Freedom Park Trail", note: "a quieter green trail linking Inman Park, Candler Park and Little Five Points" },
      { name: "Grant Park", note: "shaded paths around Zoo Atlanta, popular with neighborhood dogs" },
    ],
    tips: [
      "Atlanta summers are hot and humid: walks move to early morning and evening from June to September.",
      "Traffic is slow — a sitter in your own neighborhood is worth more than one across town.",
      "Many owners here travel for work through the airport: overnight sitting and drop-in visits for cats are common requests.",
    ],
    faq: {
      owner: [
        { q: "Where do Atlanta dog walkers go?", a: "The BeltLine, Piedmont Park and the neighborhood parks of Grant Park, Inman Park and Decatur. Off-leash play happens in fenced dog parks such as Piedmont Park Dog Park." },
        { q: "How do I find a trustworthy sitter near me in Atlanta?", a: "Open the map in HoPetSit to see sitters nearby, read their profile and reviews, chat with them in the app, then book. Verified profiles carry a badge." },
      ],
      recruit: [
        { q: "Where should a new pet sitter in Atlanta start?", a: "In your own neighborhood: Midtown, Virginia-Highland, Inman Park and Decatur have many dogs and owners who work long days. A small service area means more regular clients." },
        { q: "What services are most requested in Atlanta?", a: "Midday walks on weekdays, overnight sitting during business trips and drop-in visits for cats. Say clearly in your profile which ones you offer." },
      ],
    },
  },
  cincinnati: {
    hoods: ["Over-the-Rhine", "Hyde Park", "Oakley", "Mount Adams", "Northside", "Clifton", "Mount Lookout", "Covington and Newport across the river"],
    walks: [
      { name: "Washington Park dog park", note: "Over-the-Rhine's fenced off-leash park right in the neighborhood" },
      { name: "Mount Airy Forest dog park", note: "a large fenced park inside the city's biggest forest, with wooded trails" },
      { name: "Ault Park", note: "gardens and overlooks in Mount Lookout, dogs on leash" },
      { name: "Smale Riverfront Park", note: "a riverside walk downtown, with the Purple People Bridge to Newport" },
    ],
    tips: [
      "Cincinnati's hills make walks a real workout: tell your sitter if your dog is older or prefers flat routes.",
      "Many neighborhoods are made of townhouses and small yards, so weekday walks and drop-in visits are the usual requests.",
      "Reds and Bengals game days fill downtown and Over-the-Rhine — plan walks around the crowds.",
    ],
    faq: {
      owner: [
        { q: "Where can my dog run off-leash in Cincinnati?", a: "In fenced dog parks such as Washington Park dog park in Over-the-Rhine or Mount Airy Forest dog park. Elsewhere dogs stay leashed. Tell your sitter which park your dog knows." },
        { q: "Can I book a cat sitter for a weekend away?", a: "Yes. Post a request for drop-in visits: the sitter feeds, plays and cleans the litter box, and you get an update after each visit in the app." },
      ],
      recruit: [
        { q: "Which Cincinnati neighborhoods are good for a new sitter?", a: "Over-the-Rhine, Hyde Park, Oakley and Northside are full of dog owners. Start where you live and set a service area you can cover on foot or with a short drive." },
        { q: "What do Cincinnati owners expect?", a: "Reliable weekday walks, respect for leash rules, and a short update with a photo after each visit. HoPetSit shares the walk live on the map." },
      ],
    },
  },
  miami: {
    hoods: ["Brickell", "Wynwood", "Coral Gables", "Coconut Grove", "Miami Beach", "Little Havana", "Edgewater", "Key Biscayne"],
    walks: [
      { name: "Haulover Beach dog park and dog beach", note: "the area's best-known place where dogs can play in the water, with set hours" },
      { name: "Amelia Earhart Park Bark Park", note: "a large fenced off-leash park in Hialeah with small- and large-dog areas" },
      { name: "Kennedy Park, Coconut Grove", note: "a fenced dog park by the bay, the Grove's meeting point" },
      { name: "Tropical Park dog park", note: "fenced areas inside one of the city's biggest parks" },
      { name: "South Pointe Park", note: "a bayfront walk at the tip of Miami Beach, dogs on leash" },
    ],
    tips: [
      "Heat and humidity last most of the year: walks happen early morning or after sunset, and shade and water matter on every outing.",
      "Many Miami dogs are small and live in high-rises: building rules and elevator etiquette are part of the job — mention them in your request.",
      "Hurricane season runs from June to November — agree in advance with your sitter on what happens if a storm is announced.",
    ],
    faq: {
      owner: [
        { q: "Where can my dog swim or play off-leash in Miami?", a: "Haulover Beach has a dog beach with set hours, and fenced parks such as Amelia Earhart Park Bark Park, Kennedy Park or Tropical Park let dogs run. Tell your sitter which places your dog already knows." },
        { q: "I travel often. Can the same sitter come back each time?", a: "Yes. Once you have found a sitter you trust on the map, you can book them again directly in the app and keep the same routine for your pet." },
      ],
      recruit: [
        { q: "Where do Miami pet sitters find clients?", a: "In the high-rise neighborhoods of Brickell, Edgewater and Miami Beach, and in family areas such as Coral Gables and Coconut Grove. Start in your own neighborhood and keep your service area small." },
        { q: "What do Miami owners ask for?", a: "Midday walks for apartment dogs, overnight sitting during frequent travel, and drop-in visits for cats. Early-morning availability is a real advantage in the heat." },
      ],
    },
  },
  columbus: {
    hoods: ["the Short North", "German Village", "Clintonville", "Grandview Heights", "Victorian Village", "Olde Towne East", "Upper Arlington", "Bexley"],
    walks: [
      { name: "Scioto Audubon Metro Park dog park", note: "a fenced off-leash park downtown by the river, with a separate small-dog area" },
      { name: "Schiller Park", note: "German Village's leafy park, dogs on leash" },
      { name: "Olentangy Trail", note: "a long paved trail along the river through Clintonville and the university area" },
      { name: "Whetstone Park", note: "the Park of Roses and riverside paths in Clintonville" },
      { name: "Alum Creek Dog Park", note: "a large off-leash park north of the city with water access" },
    ],
    tips: [
      "Students and young families mean many weekday schedules: midday walks and drop-in visits are the most common requests.",
      "Ohio State home games fill the campus area and the Short North — plan walks early on those Saturdays.",
      "Winters bring ice and road salt: ask your sitter to wipe paws after walks.",
    ],
    faq: {
      owner: [
        { q: "Where can my dog run off-leash in Columbus?", a: "In fenced parks such as the Scioto Audubon Metro Park dog park downtown or Alum Creek Dog Park north of the city. In neighborhood parks like Schiller Park dogs stay leashed." },
        { q: "How do I choose a sitter in Columbus?", a: "Open the map, look at the sitters near you, read their profile and reviews, and chat with them in the app before you book. Verified profiles carry a badge." },
      ],
      recruit: [
        { q: "Where should a new Columbus sitter start?", a: "In your own neighborhood: the Short North, German Village, Clintonville and Grandview have lots of dogs and owners who work or study all day." },
        { q: "What services sell best in Columbus?", a: "Weekday walks, drop-in visits for cats and overnight sitting during holidays and travel. Say clearly in your profile what you offer and when." },
      ],
    },
  },
  houston: {
    hoods: ["the Heights", "Montrose", "Midtown", "River Oaks", "West University", "the Museum District", "EaDo", "Memorial", "Sugar Land", "Katy"],
    walks: [
      { name: "Johnny Steele Dog Park, Buffalo Bayou", note: "the city's best-known fenced dog park, with ponds for swimming" },
      { name: "Memorial Park", note: "miles of trails and a dedicated dog area, the west side's weekend walk" },
      { name: "Discovery Green", note: "downtown's park with a small dog run" },
      { name: "Hermann Park", note: "shaded loops in the Museum District, dogs on leash" },
      { name: "White Oak Bayou Trail", note: "a paved trail through the Heights" },
    ],
    tips: [
      "Houston heat lasts from May to October: walks happen early morning or after dark, and water comes on every walk.",
      "The city is huge — a sitter in your own neighborhood saves everyone an hour on the freeway.",
      "Hurricane season and sudden floods are part of life here: agree with your sitter in advance on what happens if a storm is announced.",
    ],
    faq: {
      owner: [
        { q: "Where can my dog run off-leash in Houston?", a: "In fenced parks such as Johnny Steele Dog Park on Buffalo Bayou, the dog area of Memorial Park or the run at Discovery Green. Elsewhere dogs stay leashed. Tell your sitter which park your dog knows." },
        { q: "Can a sitter stay at my home during a business trip?", a: "Yes. Post a request for overnight sitting: the sitter keeps your pet's routine at your place and sends updates and photos in the app." },
      ],
      recruit: [
        { q: "Which Houston neighborhoods are good for a new pet sitter?", a: "The Heights, Montrose, Midtown and the Museum District are dense with dog owners. Start where you live and keep your service area to what you can reach without a long drive." },
        { q: "What do Houston owners need most?", a: "Midday walks for dogs home alone, overnight sitting during travel and drop-in visits for cats. Early-morning availability is a real advantage in the heat." },
      ],
    },
  },
  "decatur-ga": {
    hoods: ["Oakhurst", "Winnona Park", "Downtown Decatur", "Great Lakes", "Glennwood Estates", "Avondale Estates", "Kirkwood", "East Lake"],
    walks: [
      { name: "Glenlake Park dog park", note: "Decatur's fenced off-leash park, with separate areas for small and large dogs" },
      { name: "Oakhurst Park", note: "the neighborhood park where many local dogs walk every morning" },
      { name: "Decatur's downtown square", note: "a walkable center with dog-friendly patios, dogs on leash" },
      { name: "PATH Foundation trails", note: "paved trails linking Decatur, Avondale Estates and the Atlanta BeltLine" },
    ],
    tips: [
      "Decatur is one of the most walkable suburbs of Atlanta: most clients are within a short walk or bike ride of each other.",
      "Hot, humid summers push walks to early morning and evening from June to September.",
      "Many owners commute into Atlanta or travel through the airport: weekday walks and overnight sitting are the usual requests.",
    ],
    faq: {
      owner: [
        { q: "Where can my dog go off-leash in Decatur?", a: "In Glenlake Park dog park, which has separate areas for small and large dogs. In Oakhurst Park and on the PATH trails dogs stay leashed." },
        { q: "Is there already a sitter near me in Decatur?", a: "Open the map in HoPetSit to see sitters around Decatur and nearby Kirkwood, East Lake and Avondale Estates. You chat with them in the app before you book." },
      ],
      recruit: [
        { q: "Is Decatur a good place to start as a pet sitter?", a: "Yes: it is walkable, full of dogs and close to Atlanta neighborhoods such as Kirkwood and East Lake. Start in your own area and keep your service area small." },
        { q: "What do Decatur owners expect?", a: "Reliable weekday walks, respect for leash rules outside the dog park and a short update after each visit. HoPetSit shares the walk live on the map." },
      ],
    },
  },
};

// 08/10/2026 — même remède pour les villes françaises touchées (rattachées par
// Google à un site étranger). Faits locaux connus et durables seulement.
const GUIDES_FR: Record<string, Guide> = {
  malakoff: {
    hoods: ["le centre-ville", "le Plateau de Vanves", "le quartier Étienne-Dolet", "les abords de la Coulée verte", "les rues proches de la porte de Vanves"],
    walks: [
      { name: "Coulée verte du sud parisien", note: "promenade plantée qui traverse Malakoff vers Châtillon et Fontenay, idéale pour une sortie tranquille" },
      { name: "Parc Montsouris", note: "à quelques minutes, côté Paris 14e, pour les grandes balades du week-end" },
      { name: "Square et rues calmes du centre", note: "pour les sorties courtes du matin et du soir" },
    ],
    tips: [
      "Beaucoup de foyers vivent en appartement sans jardin : la promenade du midi en semaine compte plus que tout.",
      "La ligne 13 (Malakoff–Plateau de Vanves, Malakoff–Rue Étienne Dolet) permet aux pet-sitters de Paris 14e et 15e de venir facilement.",
      "Les chats d'appartement sont nombreux : les visites à domicile pendant les vacances sont la demande la plus courante.",
    ],
    faq: {
      owner: [
        { q: "Un pet-sitter de Paris peut-il venir à Malakoff ?", a: "Oui. Votre demande est montrée aux pet-sitters autour de votre adresse, y compris dans le 14e, le 15e et à Vanves ou Montrouge." },
        { q: "Puis-je faire garder mon chat sans le déplacer ?", a: "Oui. Publiez une demande de visites à domicile : le pet-sitter vient nourrir, jouer et nettoyer la litière, et vous recevez des nouvelles dans l'app." },
      ],
      recruit: [
        { q: "Où trouver ses premiers clients à Malakoff ?", a: "Autour de chez vous : les propriétaires préfèrent quelqu'un qui habite à pied. Malakoff, Vanves, Montrouge et le sud du 14e forment une même zone." },
        { q: "Faut-il un jardin pour garder des animaux ?", a: "Non. La plupart des demandes sont des visites à domicile ou des promenades, chez le propriétaire." },
      ],
    },
  },
  "les-lilas": {
    hoods: ["le centre autour de la mairie", "le quartier des Bruyères", "le haut des Lilas vers Romainville", "les rues pavillonnaires", "les abords de la porte des Lilas"],
    walks: [
      { name: "Parc Lucie-Aubrac", note: "le parc de la ville, pour les sorties quotidiennes" },
      { name: "Parc des Buttes-Chaumont", note: "à deux pas, côté Paris 19e, pour les grandes balades" },
      { name: "Rues pavillonnaires calmes", note: "parfaites pour les petites sorties du matin et du soir" },
    ],
    tips: [
      "Petite ville où tout se fait à pied : choisissez un pet-sitter du quartier, il pourra passer plusieurs fois par jour.",
      "La ligne 11 (Mairie des Lilas) relie la ville au 19e et au 20e : les pet-sitters de l'est parisien viennent facilement.",
      "Le bouche-à-oreille compte beaucoup : laisser un avis après la garde aide le pet-sitter et les voisins.",
    ],
    faq: {
      owner: [
        { q: "Ma demande est-elle vue par des pet-sitters du 19e et du 20e ?", a: "Oui. Elle est montrée aux pet-sitters autour de votre adresse, aux Lilas comme dans les communes et arrondissements voisins." },
        { q: "Puis-je rencontrer le pet-sitter avant de réserver ?", a: "Oui. Vous discutez dans l'app avant la réservation et pouvez convenir d'une première rencontre." },
      ],
      recruit: [
        { q: "Y a-t-il de la demande aux Lilas ?", a: "Oui, surtout pour les visites à domicile pendant les vacances et les promenades en semaine. Être du quartier est un vrai avantage." },
        { q: "Puis-je aussi garder dans le 19e ou le 20e ?", a: "Oui. Réglez votre zone d'intervention sur ce que vous pouvez rejoindre à pied ou en métro." },
      ],
    },
  },
  "enghien-les-bains": {
    hoods: ["les bords du lac", "le centre autour de la gare", "les rues de villas", "le quartier de la Mairie", "les limites avec Soisy et Deuil-la-Barre"],
    walks: [
      { name: "Tour du lac d'Enghien", note: "la promenade emblématique de la ville, en laisse" },
      { name: "Forêt de Montmorency", note: "à quelques minutes en voiture, pour les grandes sorties en forêt" },
      { name: "Rues résidentielles autour du lac", note: "calmes pour les sorties courtes" },
    ],
    tips: [
      "Beaucoup de maisons avec jardin : précisez si le pet-sitter doit promener votre chien ou seulement passer le voir et jouer au jardin.",
      "La gare d'Enghien (ligne H) met la ville à 15 minutes de Paris Nord : pratique pour les pet-sitters qui n'ont pas de voiture.",
      "Les gardes de nuit et les longs week-ends sont fréquents : décrivez bien la routine de l'animal dans la demande.",
    ],
    faq: {
      owner: [
        { q: "Les communes voisines sont-elles couvertes ?", a: "Oui. Votre demande est montrée aux pet-sitters autour de votre adresse : Enghien, Soisy, Deuil-la-Barre, Montmorency, Saint-Gratien…" },
        { q: "Un pet-sitter peut-il dormir chez moi ?", a: "Oui. Publiez une demande de garde à domicile avec les dates ; vous en discutez dans l'app avant de réserver." },
      ],
      recruit: [
        { q: "Quelles gardes sont demandées à Enghien-les-Bains ?", a: "Des gardes de nuit, des visites pendant les vacances et des promenades autour du lac." },
        { q: "Faut-il une voiture ?", a: "Pas forcément : la ville est petite et bien desservie par la ligne H. Une voiture aide pour les sorties en forêt de Montmorency." },
      ],
    },
  },
  annecy: {
    hoods: ["la Vieille Ville", "Annecy-le-Vieux", "Seynod", "Cran-Gevrier", "Meythet", "Pringy", "les Fins", "Novel"],
    walks: [
      { name: "Bords du lac et Pâquier", note: "la promenade au bord de l'eau, en laisse, magnifique tôt le matin" },
      { name: "Voie verte du lac", note: "piste plate qui longe la rive ouest, à partager avec les vélos" },
      { name: "Le Semnoz", note: "sentiers en forêt et en alpage pour les chiens sportifs" },
      { name: "Mont Veyrier", note: "randonnée plus raide pour les chiens habitués à la montagne" },
    ],
    tips: [
      "En été, les chiens sont souvent interdits sur les plages surveillées du lac : vérifiez les règles avant une baignade.",
      "En montagne, les troupeaux ont parfois des chiens de protection (patous) : tenir son chien en laisse et contourner le troupeau.",
      "Annecy est très touristique l'été : réservez tôt pour les gardes de juillet-août.",
    ],
    faq: {
      owner: [
        { q: "Mon pet-sitter peut-il emmener mon chien en randonnée ?", a: "Oui si vous l'acceptez et si votre chien est habitué. Précisez dans la demande les sentiers qu'il connaît et sa forme." },
        { q: "Les communes autour d'Annecy sont-elles couvertes ?", a: "Oui. Votre demande est montrée aux pet-sitters autour de votre adresse, dans toute l'agglomération." },
      ],
      recruit: [
        { q: "Quand la demande est-elle la plus forte à Annecy ?", a: "L'été et pendant les vacances scolaires, quand les habitants partent et que les vacanciers arrivent avec leurs animaux." },
        { q: "Que faut-il savoir pour promener en montagne ?", a: "Garder le chien en laisse près des troupeaux, contourner les chiens de protection, prévoir de l'eau et adapter l'effort à l'animal." },
      ],
    },
  },
  strasbourg: {
    hoods: ["la Krutenau", "Neudorf", "la Robertsau", "l'Esplanade", "l'Orangerie", "les Contades", "Cronenbourg", "la Petite France"],
    walks: [
      { name: "Berges de l'Ill", note: "promenades le long de l'eau en plein centre" },
      { name: "Jardin des Deux Rives", note: "grand parc au bord du Rhin, face à Kehl" },
      { name: "Forêt de la Robertsau", note: "sentiers ombragés au nord de la ville" },
      { name: "Parc de la Citadelle", note: "parc arboré près de l'Esplanade" },
    ],
    tips: [
      "Ville très cyclable : beaucoup de pet-sitters se déplacent à vélo ou en tram, précisez si vous habitez loin d'un arrêt.",
      "Pendant le marché de Noël, le centre est bondé : prévoyez des promenades hors de la Grande Île.",
      "Les hivers sont froids : essuyer les pattes après les trottoirs salés.",
    ],
    faq: {
      owner: [
        { q: "Les communes de l'Eurométropole sont-elles couvertes ?", a: "Oui. Votre demande est montrée aux pet-sitters autour de votre adresse, à Strasbourg comme à Schiltigheim, Illkirch ou Lingolsheim." },
        { q: "Puis-je faire garder mon chat pendant les vacances ?", a: "Oui. Publiez une demande de visites à domicile : nourriture, litière, jeu et nouvelles dans l'app." },
      ],
      recruit: [
        { q: "Où commencer comme pet-sitter à Strasbourg ?", a: "Dans votre quartier : la Krutenau, Neudorf, l'Esplanade et la Robertsau comptent beaucoup de propriétaires en appartement." },
        { q: "Peut-on garder sans voiture ?", a: "Oui. Le vélo et le tram suffisent pour la plupart des visites ; réglez votre zone sur ce que vous rejoignez facilement." },
      ],
    },
  },
  "le-havre": {
    hoods: ["le centre reconstruit", "Saint-François", "Sanvic", "Graville", "Rouelles", "le quartier de l'Eure", "les Docks", "les abords de Sainte-Adresse"],
    walks: [
      { name: "Front de mer", note: "longue promenade face à la Manche, ventée mais superbe" },
      { name: "Forêt de Montgeon", note: "grand espace boisé en haut de la ville, idéal pour les longues sorties" },
      { name: "Jardins suspendus", note: "anciens forts transformés en jardins, avec vue sur l'estuaire" },
    ],
    tips: [
      "Le vent et la pluie sont fréquents : séchez bien votre chien après la promenade et prévoyez un manteau pour les races à poil ras.",
      "Sur la plage, les règles pour les chiens changent selon la saison : vérifiez-les avant d'y aller.",
      "La ville haute et la ville basse sont reliées par le funiculaire et le tram : pratique pour les pet-sitters sans voiture.",
    ],
    faq: {
      owner: [
        { q: "Sainte-Adresse et Montivilliers sont-elles couvertes ?", a: "Oui. Votre demande est montrée aux pet-sitters autour de votre adresse, dans toute l'agglomération." },
        { q: "Mon chien peut-il aller à la plage avec le pet-sitter ?", a: "Seulement là et quand les chiens sont autorisés. Sinon, la forêt de Montgeon est une belle alternative." },
      ],
      recruit: [
        { q: "Quelles demandes trouve-t-on au Havre ?", a: "Des promenades en semaine pour les propriétaires qui travaillent, et des gardes pendant les vacances." },
        { q: "Comment se déplacer entre la ville haute et la ville basse ?", a: "Le tram et le funiculaire relient les deux. Réglez votre zone sur ce que vous rejoignez facilement." },
      ],
    },
  },
};

export function usGuide(slug: string, lang: string): Guide | null {
  if (lang === "en") return GUIDES[slug] ?? null;
  if (lang === "fr") return GUIDES_FR[slug] ?? null;
  return null;
}

export function usFaq(slug: string, lang: string, mode: Mode): { q: string; a: string }[] {
  return usGuide(slug, lang)?.faq[mode] ?? [];
}

export default function UsLocalGuide({ slug, lang, name, mode }: { slug: string; lang: string; name: string; mode: Mode }) {
  const g = usGuide(slug, lang);
  if (!g) return null;
  const fr = lang === "fr";
  return (
    <section className="mt-10" aria-labelledby="us-local-guide">
      <h2 id="us-local-guide" className="font-display text-2xl font-extrabold text-ink">
        {fr
          ? mode === "owner" ? `Faire garder son animal à ${name} : le guide local` : `Pet-sitter à ${name} : ce qu'il faut savoir`
          : mode === "owner" ? `Pet care in ${name}: the local guide` : `Pet sitting in ${name}: what to know`}
      </h2>
      <p className="mt-3 text-sm leading-relaxed text-ink-muted">
        {fr
          ? mode === "owner" ? "Quartiers où les propriétaires publient des demandes : " : "Quartiers où commencer : "
          : mode === "owner" ? "Neighborhoods where owners post requests: " : "Neighborhoods to start in: "}
        {g.hoods.join(", ")}.
      </p>
      <h3 className="mt-6 text-base font-bold text-ink">
        {fr
          ? mode === "owner" ? "Où les pet-sitters promènent les chiens" : "Où vous promènerez"
          : mode === "owner" ? "Where local sitters walk dogs" : "Where you will walk"}
      </h3>
      <ul className="mt-3 grid gap-3 md:grid-cols-2">
        {g.walks.map((w) => (
          <li key={w.name} className="rounded-2xl border border-ink/5 bg-white p-4 shadow-card">
            <span className="block text-sm font-bold text-ink">{w.name}</span>
            <span className="mt-1 block text-sm leading-relaxed text-ink-muted">{w.note}</span>
          </li>
        ))}
      </ul>
      <h3 className="mt-6 text-base font-bold text-ink">{fr ? `Bon à savoir à ${name}` : `Good to know in ${name}`}</h3>
      <ul className="mt-3 space-y-2">
        {g.tips.map((t) => (
          <li key={t} className="flex gap-2 text-sm leading-relaxed text-ink-muted">
            <span aria-hidden="true" className="mt-2 h-1.5 w-1.5 shrink-0 rounded-full bg-owner" />
            <span>{t}</span>
          </li>
        ))}
      </ul>
    </section>
  );
}

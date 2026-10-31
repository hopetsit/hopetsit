// 01/10/2026 (SAM) — push USA gratuit (Daniel : « pousser San Francisco, Dallas
// et New York gratuitement »). Règle SEO du 20/09 : aucune page nouvelle, on
// rend UNIQUES les pages qui existent déjà (/pet-sitting/<ville> et
// /become-a-pet-sitter/<ville>) avec du contenu local réel : quartiers, parcs
// où l'on promène, contraintes locales. Aucun chiffre d'activité, aucune
// promesse de revenus. Composant serveur, aucun hook.

import Link from "@/components/SiteLink";

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
  // 10/10/2026 (GUS) — 8 villes de plus : Chicago, Boston et Fort Worth (pages clés
  // non indexées, jumelles à 92 % des autres villes) + Naples, Arlington, St. Louis,
  // Detroit et Washington (impressions sans clic, page 2). Faits locaux durables.
  chicago: {
    hoods: ["Lincoln Park", "Lakeview", "Wicker Park", "Logan Square", "Bucktown", "West Loop", "Hyde Park", "Andersonville"],
    walks: [
      { name: "Montrose Dog Beach", note: "the city's best-known off-leash dog beach on Lake Michigan, busy from spring to fall" },
      { name: "Lakefront Trail", note: "18 miles along the lake, dogs on leash, with long stretches through Lincoln Park" },
      { name: "The 606 (Bloomingdale Trail)", note: "an elevated trail linking Wicker Park, Bucktown, Humboldt Park and Logan Square" },
      { name: "Wiggly Field (Noethling Park)", note: "Lakeview's fenced dog-friendly area, a neighborhood meeting point" },
      { name: "Lincoln Park", note: "the large lakefront park, dogs on leash on the paths and lawns" },
    ],
    tips: [
      "Chicago Park District dog-friendly areas require a permit tag for the dog: ask the owner for it before heading to an off-leash area.",
      "Winters are long and salted sidewalks hurt paws: January and February walks are short, and many owners provide boots or paw balm.",
      "Most owners in Lakeview, the West Loop or the Loop live in apartments or high-rises without a yard: the midday walk is the most requested service.",
    ],
    faq: {
      owner: [
        { q: "Where can my dog run off-leash in Chicago?", a: "In the Chicago Park District dog-friendly areas such as Montrose Dog Beach or Wiggly Field, with the required permit tag. On the Lakefront Trail and in Lincoln Park dogs stay leashed." },
        { q: "Is there a sitter near me in Chicago?", a: "Open the map in HoPetSit to see sitters and walkers around Lincoln Park, Lakeview, Wicker Park, Logan Square or Hyde Park. You chat with them in the app before booking." },
      ],
      recruit: [
        { q: "Which Chicago neighborhoods are good to start in?", a: "Dense, walkable ones with many apartments: Lakeview, Lincoln Park, Wicker Park, Logan Square and the West Loop. Keep your service area to a few blocks so you can chain midday walks." },
        { q: "What do Chicago owners expect in winter?", a: "Shorter walks, paws wiped after salted sidewalks and a message after each visit. HoPetSit shares the walk live on the map, so the owner sees the route." },
      ],
    },
  },
  boston: {
    hoods: ["Back Bay", "South End", "Beacon Hill", "North End", "Jamaica Plain", "Charlestown", "Allston-Brighton", "South Boston"],
    walks: [
      { name: "Charles River Esplanade", note: "riverside paths from Beacon Hill to Allston, dogs on leash, the classic Boston walk" },
      { name: "Arnold Arboretum", note: "281 acres of trees and trails in Jamaica Plain, dogs on leash" },
      { name: "Peters Park dog run", note: "the fenced dog run of the South End, busy mornings and evenings" },
      { name: "Castle Island and Pleasure Bay", note: "a waterfront loop in South Boston with sea air and wide paths" },
      { name: "Boston Common and the Public Garden", note: "the historic parks downtown, dogs on leash" },
    ],
    tips: [
      "Off-leash is only allowed in the city's designated dog recreation spaces: everywhere else, including the Common, dogs stay on leash.",
      "Snow and ice from December to March make walks shorter; many owners ask for a quick paw rinse after salted sidewalks.",
      "Many apartments are in triple-deckers and brownstones without a yard, and new tenants arrive each September: demand for midday walks rises in the fall.",
    ],
    faq: {
      owner: [
        { q: "Where can my dog go off-leash in Boston?", a: "Only in designated dog recreation spaces such as the Peters Park dog run in the South End. On the Esplanade, in the Arboretum and on the Common dogs stay leashed." },
        { q: "Is there a sitter near me in Boston?", a: "Open the map in HoPetSit to see sitters around Back Bay, the South End, Jamaica Plain, Charlestown or Allston-Brighton. You chat in the app before you book." },
      ],
      recruit: [
        { q: "Where should a new pet sitter start in Boston?", a: "In walkable neighborhoods with many apartments: Back Bay, the South End, Beacon Hill, Jamaica Plain or Allston-Brighton. Start in your own neighborhood and keep your service area small." },
        { q: "What do Boston owners expect?", a: "Punctual midday walks, leash rules respected outside dog runs and a short update after each visit. HoPetSit shares the walk live on the map." },
      ],
    },
  },
  "fort-worth": {
    hoods: ["Near Southside and Magnolia", "Fairmount", "TCU and Westcliff", "Arlington Heights", "Tanglewood", "Cultural District", "Downtown and Sundance Square", "Alliance"],
    walks: [
      { name: "Trinity Trails", note: "a network of paved trails along the Trinity River, dogs on leash, shaded sections near the Cultural District" },
      { name: "Fort Woof Dog Park", note: "the large off-leash park in Gateway Park, with separate areas for small and large dogs" },
      { name: "ZBonz Dog Park", note: "the off-leash park in Z Boaz Park on the west side" },
      { name: "Trinity Park", note: "the riverside park next to the Cultural District, a favorite for evening walks" },
      { name: "Magnolia Avenue", note: "the Near Southside street of dog-friendly patios, dogs on leash" },
    ],
    tips: [
      "Summers are very hot: from June to September walks move to early morning and after sunset, and sitters check the pavement temperature before heading out.",
      "Fort Worth is spread out and most homes have a yard: drop-in visits and overnight sitting are requested as often as walks.",
      "Many sitters cover Fort Worth and nearby Dallas suburbs: keep your service area tight to avoid long drives between clients.",
    ],
    faq: {
      owner: [
        { q: "Where can my dog run off-leash in Fort Worth?", a: "In Fort Woof Dog Park (Gateway Park) and ZBonz Dog Park (Z Boaz Park), both fenced with separate areas for small and large dogs. On the Trinity Trails dogs stay leashed." },
        { q: "Is there a sitter near me in Fort Worth?", a: "Open the map in HoPetSit to see sitters around the Near Southside, Fairmount, TCU, Arlington Heights or Tanglewood. You chat with them in the app before you book." },
      ],
      recruit: [
        { q: "Where should I start as a pet sitter in Fort Worth?", a: "In the walkable neighborhoods close to each other: Near Southside, Fairmount, TCU and Westcliff, Arlington Heights. Start in your own area and grow from there." },
        { q: "What do Fort Worth owners expect?", a: "Walks at cool hours in summer, reliable drop-in visits while they travel and a short update after each visit. HoPetSit shares the walk live on the map." },
      ],
    },
  },
  "naples-fl": {
    hoods: ["Old Naples", "Park Shore", "Pelican Bay", "North Naples", "Vanderbilt Beach", "Golden Gate", "Lely Resort", "East Naples"],
    walks: [
      { name: "Rover Run dog park (Veterans Community Park)", note: "the city's fenced off-leash park in North Naples" },
      { name: "Gordon River Greenway", note: "a paved trail through mangroves and wetlands, dogs on leash" },
      { name: "Cambier Park", note: "the downtown park a few blocks from Fifth Avenue South, dogs on leash" },
      { name: "Baker Park", note: "a waterfront park on the Gordon River, next to downtown" },
      { name: "Dog Beach at Bonita Beach", note: "just north of Naples, one of the few beaches in the area where dogs may go off-leash" },
    ],
    tips: [
      "Naples fills up with seasonal residents from November to April: demand for sitting and walks peaks in winter and drops in summer.",
      "Summer afternoons bring heat and storms: walks happen early morning and in the evening, and hot sand burns paws.",
      "Alligators live in ponds and canals across Collier County: keep dogs leashed and away from the water's edge, especially at dusk.",
    ],
    faq: {
      owner: [
        { q: "Where can my dog go off-leash in Naples?", a: "In Rover Run at Veterans Community Park, which is fenced. Most Naples beaches do not allow dogs; the Dog Beach at Bonita Beach, just north, does." },
        { q: "Is there a sitter near me in Naples?", a: "Open the map in HoPetSit to see sitters around Old Naples, Park Shore, Pelican Bay, North Naples or Lely Resort. You chat with them in the app before you book." },
      ],
      recruit: [
        { q: "When is the busy season for pet sitters in Naples?", a: "From November to April, when seasonal residents are in town and travel for the holidays. Summer is quieter, so build your regular clients in winter." },
        { q: "What do Naples owners expect?", a: "Walks at cool hours, dogs kept away from ponds and canals, and a short update after each visit. HoPetSit shares the walk live on the map." },
      ],
    },
  },
  "arlington-tx": {
    hoods: ["Downtown Arlington and UTA", "North Arlington", "Southwest Arlington", "Viridian", "Interlochen", "Rush Creek", "East Arlington", "Entertainment District"],
    walks: [
      { name: "River Legacy Parks", note: "1,300 acres along the Trinity River with paved and natural trails, dogs on leash" },
      { name: "Tails 'N Trails Dog Park", note: "Arlington's fenced off-leash park with separate areas for small and large dogs" },
      { name: "Veterans Park", note: "a large park in southwest Arlington with trails and open lawns" },
      { name: "Bowman Springs Park on Lake Arlington", note: "lakeside paths and shade on the west side" },
    ],
    tips: [
      "Game days at AT&T Stadium and Globe Life Field clog the roads around the Entertainment District: plan walks before or after the crowds.",
      "Summers are very hot: walks happen early morning and after sunset from June to September.",
      "Arlington is a car city with many single-family homes: drop-in visits and overnight sitting are as common as walks, and UTA students look for part-time sitting work.",
    ],
    faq: {
      owner: [
        { q: "Where can my dog run off-leash in Arlington?", a: "In Tails 'N Trails Dog Park, which is fenced with separate areas for small and large dogs. In River Legacy Parks and Veterans Park dogs stay leashed." },
        { q: "Is there a sitter near me in Arlington?", a: "Open the map in HoPetSit to see sitters around Downtown and UTA, North Arlington, Southwest Arlington or Viridian. You chat with them in the app before you book." },
      ],
      recruit: [
        { q: "Where should I start as a pet sitter in Arlington?", a: "Around UTA and downtown if you live there, or in your own neighborhood in North or Southwest Arlington. Keep your service area small: distances add up quickly in Arlington." },
        { q: "What do Arlington owners expect?", a: "Reliable visits while they work or travel, walks at cool hours in summer and a short update after each visit. HoPetSit shares the walk live on the map." },
      ],
    },
  },
  "st-louis": {
    hoods: ["Central West End", "Tower Grove South", "Soulard", "The Hill", "Lafayette Square", "Dogtown", "Shaw", "Benton Park"],
    walks: [
      { name: "Forest Park", note: "1,300 acres of paths, lakes and lawns next to the Central West End, dogs on leash" },
      { name: "Tower Grove Park", note: "the Victorian park between Shaw and Tower Grove South, a daily walk for many local dogs" },
      { name: "Lafayette Park", note: "the historic square of Lafayette Square, dogs on leash" },
      { name: "River des Peres Greenway", note: "a paved trail across the south side of the city" },
    ],
    tips: [
      "Summers are hot and humid and winters bring ice: walk times shift to early morning in July and August, and paws need a wipe after salted sidewalks in January.",
      "The Central West End and Soulard have many apartments without yards: midday walks are the usual request, while south-side houses ask for drop-in visits.",
      "Many neighborhoods sit next to each other: a sitter based in Tower Grove South can cover Shaw, The Hill and Benton Park on foot or by bike.",
    ],
    faq: {
      owner: [
        { q: "Can my dog go off-leash in Forest Park?", a: "No: in Forest Park, Tower Grove Park and Lafayette Park dogs stay on leash. Off-leash play is for fenced dog parks only." },
        { q: "Is there a sitter near me in St. Louis?", a: "Open the map in HoPetSit to see sitters around the Central West End, Tower Grove South, Soulard, Lafayette Square or Dogtown. You chat with them in the app before you book." },
      ],
      recruit: [
        { q: "Where should I start as a pet sitter in St. Louis?", a: "In the walkable south-side neighborhoods (Tower Grove South, Shaw, Soulard, Benton Park) or around the Central West End. Start in your own neighborhood." },
        { q: "What do St. Louis owners expect?", a: "Punctual midday walks, leash rules respected in the parks and a short update after each visit. HoPetSit shares the walk live on the map." },
      ],
    },
  },
  detroit: {
    hoods: ["Midtown", "Corktown", "Downtown", "Indian Village", "West Village", "Boston-Edison", "Palmer Woods", "Southwest Detroit"],
    walks: [
      { name: "Belle Isle Park", note: "the 982-acre island park on the Detroit River, dogs on leash on the paths and lawns" },
      { name: "Detroit Riverwalk", note: "the riverfront promenade from downtown toward Belle Isle, dogs on leash" },
      { name: "Dequindre Cut Greenway", note: "a below-grade trail linking the riverfront to Eastern Market and Midtown" },
      { name: "Palmer Park", note: "a large park with wooded trails on the north side" },
      { name: "Rouge Park", note: "Detroit's largest park, with trails on the far west side" },
    ],
    tips: [
      "Winters are cold and snowy: January and February walks are short, and owners appreciate paws wiped after salted sidewalks.",
      "Downtown, Midtown and Corktown have many apartments and lofts without yards: the midday walk is the most requested service.",
      "Neighborhoods such as Indian Village, Boston-Edison and Palmer Woods are houses with yards: owners ask for drop-in visits and overnight sitting when they travel.",
    ],
    faq: {
      owner: [
        { q: "Can my dog go off-leash on Belle Isle?", a: "No: Belle Isle is a state park and dogs stay on leash there, as on the Riverwalk and the Dequindre Cut. Off-leash play is for fenced dog parks only." },
        { q: "Is there a sitter near me in Detroit?", a: "Open the map in HoPetSit to see sitters around Midtown, Corktown, Downtown, Indian Village or Southwest Detroit. You chat with them in the app before you book." },
      ],
      recruit: [
        { q: "Where should I start as a pet sitter in Detroit?", a: "In Midtown, Corktown or Downtown if you live nearby, where apartments are dense and midday walks are in demand. Otherwise start in your own neighborhood and keep your area small." },
        { q: "What do Detroit owners expect?", a: "Reliable walks in all weather, leash rules respected in the parks and a short update after each visit. HoPetSit shares the walk live on the map." },
      ],
    },
  },
  "washington-dc": {
    hoods: ["Capitol Hill", "Dupont Circle", "Logan Circle", "Shaw", "Columbia Heights", "Georgetown", "Navy Yard", "Adams Morgan"],
    walks: [
      { name: "Rock Creek Park", note: "more than 1,700 acres of wooded trails through the city, dogs on leash" },
      { name: "Shaw Dog Park", note: "a fenced dog park in the heart of Shaw, busy mornings and evenings" },
      { name: "The National Mall", note: "wide gravel paths and lawns between the monuments, dogs on leash" },
      { name: "Capital Crescent Trail", note: "a paved trail from Georgetown along the Potomac toward Bethesda" },
      { name: "Yards Park and the Anacostia Riverwalk", note: "the Navy Yard waterfront, popular with the neighborhood's many dogs" },
    ],
    tips: [
      "Summers are hot and humid: July and August walks move to early morning and evening.",
      "Rowhouses and apartments without yards fill Capitol Hill, Shaw, Logan Circle and Navy Yard: midday walks are the most requested service.",
      "Many owners travel for work: drop-in visits and overnight sitting for a few days are common requests, especially around congressional recesses and holidays.",
    ],
    faq: {
      owner: [
        { q: "Where can my dog go off-leash in Washington, DC?", a: "In the official DC dog parks such as Shaw Dog Park, which are fenced. In Rock Creek Park, on the National Mall and along the waterfront dogs stay leashed." },
        { q: "Is there a sitter near me in DC?", a: "Open the map in HoPetSit to see sitters around Capitol Hill, Dupont Circle, Shaw, Columbia Heights or Navy Yard. You chat with them in the app before you book." },
      ],
      recruit: [
        { q: "Where should I start as a pet sitter in DC?", a: "In the dense rowhouse neighborhoods: Capitol Hill, Shaw, Logan Circle, Columbia Heights or Navy Yard. Keep your service area to a few blocks so you can chain midday walks." },
        { q: "What do DC owners expect?", a: "Punctual midday walks, respect for leash rules outside dog parks and a short update after each visit. HoPetSit shares the walk live on the map." },
      ],
    },
  },
  // 22/10/2026 (GUS) — Search Console 28 j (USA) : les 6 pages villes à plus forts affichages
  // SANS guide local, 0 clic : minneapolis 209 (« dog sitting minneapolis » 15e, « pet sitter » 17e),
  // plano 188, colorado-springs 155, irving 151, buffalo 105, baltimore 86 (« pet sitter baltimore »
  // 5e, « pet sitting baltimore » 12e). Même remède que les 32 autres villes US : contenu local vrai et
  // durable (quartiers, parcs connus, climat), aucun chiffre d'activité, aucune promesse.
  minneapolis: {
    hoods: ["Uptown", "North Loop", "Northeast", "Linden Hills", "Longfellow", "Powderhorn", "Nokomis", "Loring Park"],
    walks: [
      { name: "Chain of Lakes", note: "the paths around Bde Maka Ska, Lake of the Isles and Lake Harriet, dogs on leash" },
      { name: "Minnehaha Regional Park", note: "the falls, the creek trails and a large off-leash dog area near the Mississippi" },
      { name: "Midtown Greenway", note: "a former rail corridor turned trail across south Minneapolis" },
      { name: "Mississippi riverfront", note: "the Stone Arch Bridge and the river paths near the North Loop and Northeast" },
      { name: "Loring Park", note: "a small downtown park next to the Walker Art Center sculpture garden" },
    ],
    tips: [
      "Winters are long and very cold: walks get shorter from December to February, and owners appreciate paws wiped after salted sidewalks.",
      "Uptown, the North Loop and Loring Park have many apartments without yards: the midday walk is the most requested service.",
      "Houses with yards around the lakes, Longfellow and Nokomis: owners ask for drop-in visits and overnight sitting when they travel, especially over the holidays.",
    ],
    faq: {
      owner: [
        { q: "Can my dog go off-leash around the lakes in Minneapolis?", a: "No: on the Chain of Lakes paths dogs stay on leash. Off-leash play is for the designated dog parks, such as the one in Minnehaha Regional Park." },
        { q: "Is there a sitter near me in Minneapolis?", a: "Open the map in HoPetSit to see sitters around Uptown, the North Loop, Northeast, Longfellow or Nokomis. You chat with them in the app before you book." },
      ],
      recruit: [
        { q: "Where should I start as a pet sitter in Minneapolis?", a: "In Uptown, the North Loop or Loring Park if you live nearby, where apartments are dense and midday walks are in demand. Otherwise start in your own neighborhood and keep your area small." },
        { q: "What do Minneapolis owners expect?", a: "Walks in all weather, including deep winter, leash rules respected around the lakes and a short update after each visit. HoPetSit shares the walk live on the map." },
      ],
    },
  },
  plano: {
    hoods: ["Legacy West", "Downtown Plano", "Willow Bend", "West Plano", "Deerfield", "Old Shepard Place", "Los Rios", "Preston Meadow"],
    walks: [
      { name: "Arbor Hills Nature Preserve", note: "paved and natural trails over rolling hills in west Plano, dogs on leash" },
      { name: "Oak Point Park and Nature Preserve", note: "Plano's largest park, with trails along the creek on the east side" },
      { name: "Jack Carter Dog Park", note: "a fenced off-leash dog park in Jack Carter Park" },
      { name: "Chisholm Trail", note: "a creekside trail that crosses central Plano from north to south" },
      { name: "Bob Woodruff Park", note: "wide lawns and trails next to Oak Point on the east side" },
    ],
    tips: [
      "Summers are very hot: from June to September, walks move to early morning and evening, and pavement can burn paws in the afternoon.",
      "Plano is mostly houses with fenced yards: owners ask for drop-in visits and overnight sitting when they travel, more than for daily walks.",
      "Around Legacy West and the corporate campuses, many owners travel for work: short sittings of a few days during the week are common.",
    ],
    faq: {
      owner: [
        { q: "Where can my dog go off-leash in Plano?", a: "In fenced dog parks such as Jack Carter Dog Park. On the trails of Arbor Hills, Oak Point and the Chisholm Trail dogs stay leashed." },
        { q: "Is there a sitter near me in Plano?", a: "Open the map in HoPetSit to see sitters around Legacy West, Downtown Plano, Willow Bend or West Plano. You chat with them in the app before you book." },
      ],
      recruit: [
        { q: "Where should I start as a pet sitter in Plano?", a: "In your own neighborhood: Plano owners like a sitter who lives close by for drop-in visits. Keep your service area small so you can chain several visits in a day." },
        { q: "What do Plano owners expect?", a: "Visits at the agreed times, walks early or late in summer heat, and a short update after each visit. HoPetSit shares the walk live on the map." },
      ],
    },
  },
  "colorado-springs": {
    hoods: ["Downtown", "Old Colorado City", "Old North End", "Patty Jewett", "Broadmoor", "Briargate", "Rockrimmon", "Northgate"],
    walks: [
      { name: "Garden of the Gods", note: "the red rock park on the west side, dogs on leash on the trails" },
      { name: "Bear Creek Dog Park", note: "a large fenced off-leash park with a creek, in Bear Creek Regional Park" },
      { name: "Red Rock Canyon Open Space", note: "trails between rock formations, with a designated off-leash area for dogs" },
      { name: "Palmer Park", note: "mesa-top trails in the middle of the city, with off-leash areas" },
      { name: "Ute Valley Park", note: "trails on the north-west side, popular with hikers and their dogs" },
    ],
    tips: [
      "The city sits at about 6,000 feet: sun and dry air are strong, so sitters carry water for the dog on every long walk.",
      "Weather changes fast, with snow possible from fall to spring: owners appreciate a sitter who adapts the walk to the day.",
      "Many military families live here: they often ask for longer sittings, and for a sitter who keeps the same routine while they are away.",
    ],
    faq: {
      owner: [
        { q: "Where can my dog go off-leash in Colorado Springs?", a: "In fenced dog parks such as Bear Creek Dog Park, or in designated off-leash areas such as the one in Red Rock Canyon Open Space. In Garden of the Gods dogs stay leashed." },
        { q: "Is there a sitter near me in Colorado Springs?", a: "Open the map in HoPetSit to see sitters around Downtown, Old Colorado City, Briargate or Patty Jewett. You chat with them in the app before you book." },
      ],
      recruit: [
        { q: "Where should I start as a pet sitter in Colorado Springs?", a: "In your own part of town: distances are long here, so a small service area lets you chain visits. Downtown and Old North End have more apartments and midday walks." },
        { q: "What do Colorado Springs owners expect?", a: "Water and shade on long walks, leash rules respected on the trails, and a short update after each visit. HoPetSit shares the walk live on the map." },
      ],
    },
  },
  irving: {
    hoods: ["Las Colinas", "Valley Ranch", "Irving Heritage District", "Hackberry Creek", "Twin Wells", "Plymouth Park", "Cottonwood Valley", "University Hills"],
    walks: [
      { name: "Lake Carolyn", note: "the promenade around the lake and the Mandalay Canal in Las Colinas, dogs on leash" },
      { name: "Campión Trail", note: "a long paved trail along the Elm Fork of the Trinity River" },
      { name: "Trinity View Park", note: "riverside lawns and a trailhead of the Campión Trail" },
      { name: "Valley Ranch canals", note: "the walkways along the canals of Valley Ranch" },
    ],
    tips: [
      "Summers are very hot: from June to September, walks move to early morning and evening, and pavement can burn paws in the afternoon.",
      "Las Colinas and Valley Ranch have many apartments without yards: the midday walk is the most requested service.",
      "DFW Airport is next door and many owners fly for work: short sittings and drop-in visits during the week are common.",
    ],
    faq: {
      owner: [
        { q: "Where can I walk my dog in Irving?", a: "Around Lake Carolyn in Las Colinas, along the Campión Trail by the Trinity River, or in Trinity View Park. Dogs stay leashed on these paths." },
        { q: "Is there a sitter near me in Irving?", a: "Open the map in HoPetSit to see sitters around Las Colinas, Valley Ranch or the Heritage District. You chat with them in the app before you book." },
      ],
      recruit: [
        { q: "Where should I start as a pet sitter in Irving?", a: "In Las Colinas or Valley Ranch if you live nearby, where apartments are dense and midday walks are in demand. Keep your service area small so you can chain visits." },
        { q: "What do Irving owners expect?", a: "Reliable visits while they travel, walks early or late in summer heat, and a short update after each visit. HoPetSit shares the walk live on the map." },
      ],
    },
  },
  buffalo: {
    hoods: ["Elmwood Village", "Allentown", "North Buffalo", "Hertel", "Parkside", "Black Rock", "South Buffalo", "Downtown"],
    walks: [
      { name: "Delaware Park", note: "the large Olmsted park in the north of the city, with a loop path around the meadow, dogs on leash" },
      { name: "Shoreline Trail", note: "the trail along the Niagara River and the waterfront" },
      { name: "Canalside and the Erie Basin Marina", note: "the downtown waterfront promenade, dogs on leash" },
      { name: "Cazenovia Park", note: "the Olmsted park of South Buffalo, with a creek and wide lawns" },
    ],
    tips: [
      "Lake-effect snow can fall hard in winter: owners appreciate a sitter who comes even on snow days and wipes paws after salted sidewalks.",
      "Elmwood Village, Allentown and North Buffalo are mostly older doubles and houses with small yards: daily walks and drop-in visits are the most common requests.",
      "Summers are mild and many owners leave for lake weekends: overnight sitting and visits fill up in July and August.",
    ],
    faq: {
      owner: [
        { q: "Can my dog go off-leash in Delaware Park?", a: "No: dogs stay on leash in Delaware Park, on the waterfront and along the trails. Off-leash play is for fenced dog parks only." },
        { q: "Is there a sitter near me in Buffalo?", a: "Open the map in HoPetSit to see sitters around Elmwood Village, Allentown, North Buffalo or Parkside. You chat with them in the app before you book." },
      ],
      recruit: [
        { q: "Where should I start as a pet sitter in Buffalo?", a: "In Elmwood Village, Allentown or North Buffalo if you live nearby: dogs are everywhere and walks are close together. Keep your service area small." },
        { q: "What do Buffalo owners expect?", a: "Walks in all weather, snow included, leash rules respected in the parks and a short update after each visit. HoPetSit shares the walk live on the map." },
      ],
    },
  },
  baltimore: {
    hoods: ["Fells Point", "Federal Hill", "Canton", "Patterson Park", "Hampden", "Mount Vernon", "Locust Point", "Roland Park"],
    walks: [
      { name: "Patterson Park", note: "the large park of east Baltimore, with a fenced dog park" },
      { name: "Waterfront Promenade", note: "the harbor walk from the Inner Harbor to Fells Point and Canton, dogs on leash" },
      { name: "Druid Hill Park", note: "one of the oldest city parks in the country, with a lake loop" },
      { name: "Federal Hill Park", note: "the hilltop park above the Inner Harbor" },
      { name: "Gwynns Falls Trail", note: "a long trail through the stream valley on the west side" },
    ],
    tips: [
      "Summers are hot and humid: July and August walks move to early morning and evening.",
      "Fells Point, Federal Hill, Canton and Mount Vernon are rowhouses and apartments without yards: midday walks are the most requested service.",
      "Roland Park and the north of the city have more houses with yards: owners ask for drop-in visits and overnight sitting when they travel.",
    ],
    faq: {
      owner: [
        { q: "Where can my dog go off-leash in Baltimore?", a: "In fenced dog parks such as the one in Patterson Park. On the Waterfront Promenade and in the other parks dogs stay leashed." },
        { q: "Is there a sitter near me in Baltimore?", a: "Open the map in HoPetSit to see sitters around Fells Point, Federal Hill, Canton, Hampden or Mount Vernon. You chat with them in the app before you book." },
      ],
      recruit: [
        { q: "Where should I start as a pet sitter in Baltimore?", a: "In the rowhouse neighborhoods: Fells Point, Federal Hill, Canton or Patterson Park. Keep your service area to a few blocks so you can chain midday walks." },
        { q: "What do Baltimore owners expect?", a: "Punctual midday walks, leash rules respected outside dog parks and a short update after each visit. HoPetSit shares the walk live on the map." },
      ],
    },
  },
  // 23/10/2026 (GUS) — 3 villes US très vues sur Google (fort-myers 189 affichages,
  // las-vegas 65, denton 56, 0 clic) sans guide local. Même remède, aucun chiffre inventé.
  "fort-myers": {
    hoods: ["the Downtown River District", "McGregor", "Whiskey Creek", "Iona", "Gateway", "San Carlos Park", "Fort Myers Beach", "Cape Coral across the river"],
    walks: [
      { name: "Lakes Regional Park", note: "the big county park with a fenced dog park and flat paved loops" },
      { name: "Centennial Park", note: "the riverfront park downtown, dogs on leash" },
      { name: "Wa-Ke Hatchee Park", note: "south Fort Myers park with its own dog park" },
      { name: "Dog Beach at New Pass", note: "the county's off-leash dog beach between Bonita Beach and Lovers Key" },
      { name: "John Yarbrough Linear Park", note: "a long paved trail along the Ten Mile Canal for easy morning walks" },
    ],
    tips: [
      "Seasonal residents arrive from November to April: demand for overnight sitting and drop-in visits peaks in winter and drops in summer.",
      "Summers are hot and stormy: walks move to early morning and evening, and afternoon thunderstorms cut outings short from June to September.",
      "Hurricane season runs from June to November — share your evacuation plan and a backup contact with your sitter if you travel then.",
      "Alligators live in ponds and canals across Lee County: dogs stay leashed and away from the water's edge, especially at dusk.",
    ],
    faq: {
      owner: [
        { q: "Where can my dog go off-leash in Fort Myers?", a: "In the fenced dog parks of Lakes Regional Park and Wa-Ke Hatchee Park, or at the county dog beach at New Pass. Everywhere else, including the riverfront, dogs stay leashed." },
        { q: "Is there a sitter near me in Fort Myers?", a: "Open the map in HoPetSit to see sitters around McGregor, the River District, Gateway, San Carlos Park or Cape Coral. You chat with them in the app before you book." },
      ],
      recruit: [
        { q: "When is pet sitting demand highest in Fort Myers?", a: "From November to April, when seasonal residents are here, and around the holidays. Being available in winter is a real advantage." },
        { q: "What do Fort Myers owners expect?", a: "Walks at cool hours, dogs kept away from ponds and canals, and a short update after each visit. HoPetSit shares the walk live on the map." },
      ],
    },
  },
  "las-vegas": {
    hoods: ["Summerlin", "Spring Valley", "the Arts District and Downtown", "Centennial Hills", "Southern Highlands", "Green Valley", "Henderson", "North Las Vegas"],
    walks: [
      { name: "Desert Breeze Park", note: "a large west-side park with a popular fenced dog park" },
      { name: "Sunset Park", note: "the big park near the airport with its own dog park and lake loop" },
      { name: "Floyd Lamb Park at Tule Springs", note: "shady lawns and ponds in the north, dogs on leash" },
      { name: "Red Rock Canyon", note: "desert trails west of Summerlin, dogs leashed and only in cool months" },
      { name: "Kellogg-Zaher Dog Park", note: "a well-known neighborhood dog park in the west valley" },
    ],
    tips: [
      "From May to September the heat is dangerous: walks happen at dawn or after dark, and good sitters check the pavement with a hand before heading out.",
      "Many Las Vegas owners work night and swing shifts on the Strip: walks and visits at unusual hours are common requests, so say your schedule in the request.",
      "The air is very dry: water comes on every walk, and short-nosed dogs stay indoors in the afternoon.",
    ],
    faq: {
      owner: [
        { q: "Can a sitter walk my dog during the day in summer?", a: "Not in the afternoon heat. Agree on dawn or evening walks, and indoor play or a short potty break at midday. Put it in your request." },
        { q: "Is there a sitter near me in Las Vegas?", a: "Open the map in HoPetSit to see sitters around Summerlin, Spring Valley, Henderson, Green Valley or Centennial Hills. You chat with them in the app before you book." },
      ],
      recruit: [
        { q: "Where should I start as a pet sitter in Las Vegas?", a: "In your own part of the valley — Summerlin, Spring Valley, Henderson or Centennial Hills. The city is spread out, so keep your service area to what you can reach in a few minutes." },
        { q: "What do Las Vegas owners expect?", a: "Walks at safe hours, water on every outing, flexibility with shift schedules and a short update after each visit. HoPetSit shares the walk live on the map." },
      ],
    },
  },
  denton: {
    hoods: ["the Downtown Square", "around UNT", "around TWU", "the Oak-Hickory historic district", "Southridge", "Robson Ranch", "Corinth and Lake Dallas", "Argyle"],
    walks: [
      { name: "South Lakes Park", note: "the south-side park with Wiggly Field, Denton's fenced dog park" },
      { name: "North Lakes Park", note: "big lawns and ponds, easy loops on leash" },
      { name: "Clear Creek Natural Heritage Center", note: "creek-side trails north of town, dogs on leash" },
      { name: "Ray Roberts Lake State Park", note: "lake trails for weekend hikes, dogs leashed" },
      { name: "Denton Rail Trail", note: "the paved trail toward Lake Dallas, flat and shaded in places" },
    ],
    tips: [
      "Two universities set the rhythm of the town: many sitters are students, available on weekdays during the semester and often away in summer and over the holidays.",
      "Texas summers are hot from June to September: walks happen early in the morning or after sunset, and water comes on every outing.",
      "Families near Lake Lewisville and in Robson Ranch travel on weekends: drop-in visits and overnight sitting are frequent requests.",
    ],
    faq: {
      owner: [
        { q: "Where can my dog run off-leash in Denton?", a: "At Wiggly Field, the fenced dog park in South Lakes Park. On the trails and in the other parks dogs stay leashed." },
        { q: "Is there a sitter near me in Denton?", a: "Open the map in HoPetSit to see sitters around the Square, UNT, TWU, Southridge or Corinth. You chat with them in the app before you book." },
      ],
      recruit: [
        { q: "Can I pet sit as a UNT or TWU student?", a: "Yes. Set your availability around your classes and your service area to the neighborhoods you can reach on foot or by bike. Owners near campus look for midday walks on weekdays." },
        { q: "What do Denton owners expect?", a: "Walks at cool hours in summer, punctuality, and a short update after each visit. HoPetSit shares the walk live on the map." },
      ],
    },
  },
};

// 08/10/2026 — même remède pour les villes françaises touchées (rattachées par
// Google à un site étranger). Faits locaux connus et durables seulement.
const GUIDES_FR: Record<string, Guide> = {
  // 19/10/2026 (GUS) — Search Console 28 j : /garde-animaux/paris en 44e-50e place sur
  // « petsitter paris » (49 affichages), « garde animaux paris » (46), « dogsitting paris » (30),
  // « pet sitter paris » (29), « dog sitting paris » (21), 0 clic. La page phare n'avait AUCUN
  // contenu propre à Paris (texte commun à toutes les villes FR). Faits durables et vérifiables
  // seulement : aucun chiffre d'activité, aucune promesse, aucune règle de parc affirmée en détail.
  paris: {
    hoods: ["les 20 arrondissements", "le Marais et le centre", "Montmartre et le 18e", "le 11e et l'est parisien", "le 15e et le sud-ouest", "la petite couronne (Boulogne-Billancourt, Montreuil, Vincennes, Levallois…)"],
    walks: [
      { name: "Bois de Boulogne (16e)", note: "le grand espace vert de l'ouest parisien, pour les longues balades du week-end, en suivant la signalisation sur la laisse" },
      { name: "Bois de Vincennes (12e)", note: "son pendant à l'est, accessible depuis le 12e et le 20e, pour les sorties longues" },
      { name: "Quais du canal Saint-Martin et bassin de la Villette", note: "une promenade à plat, en laisse, pratique pour la sortie du soir dans le 10e et le 19e" },
      { name: "Parcs et jardins de quartier", note: "beaucoup acceptent les chiens tenus en laisse et certains ont un espace canin : le règlement est affiché à chaque entrée" },
    ],
    tips: [
      "En appartement sans jardin, la sortie du midi en semaine est souvent la plus dure à assurer : un dog sitter qui habite le même arrondissement peut passer à heure fixe pour la promenade.",
      "Pour un chat, les visites à domicile (cat sitting) évitent le transport et la pension : il garde ses repères. Une ou deux visites par jour selon son caractère.",
      "Pense aux codes : digicode, interphone, étage, et un double des clés remis en main propre lors de la rencontre, jamais dans une annonce.",
      "Toussaint, Noël, été : beaucoup de Parisiens partent aux mêmes dates. Publie ta demande plusieurs semaines avant pour avoir le choix du petsitter.",
      "Dans le métro, les petits animaux voyagent dans un sac ou un panier ; pour un grand chien, les conditions de la RATP sont plus strictes : un pet sitter du quartier évite le trajet.",
    ],
    faq: {
      owner: [
        { q: "Pet sitter, petsitter, dog sitter ou cat sitter à Paris : quelle différence ?", a: "Aucune sur HoPetSit : ce sont les mêmes gardiens. Le dog sitting regroupe la garde et la promenade de chien, le cat sitting les visites à domicile pour un chat. Tu précises le service dans ta demande." },
        { q: "Que donner au pet sitter avant une garde à Paris ?", a: "Le digicode, l'étage, un double des clés et la routine de l'animal (repas, sorties, vétérinaire habituel). Remets les clés lors d'une rencontre avant la garde, après avoir discuté dans l'app." },
        { q: "Où promener son chien à Paris ?", a: "Dans les bois de Boulogne et de Vincennes, le long du canal Saint-Martin, et dans les parcs et jardins qui acceptent les chiens en laisse : le règlement est affiché à chaque entrée." },
      ],
      recruit: [
        { q: "Où trouver ses premiers clients à Paris ?", a: "Dans ton arrondissement : les propriétaires préfèrent quelqu'un qui habite à pied, surtout pour la promenade du midi et les visites de chat." },
        { q: "Faut-il un jardin pour garder des animaux à Paris ?", a: "Non. La plupart des demandes sont des visites à domicile ou des promenades, chez le propriétaire." },
      ],
    },
  },
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
        { q: "Un pet-sitter de Paris peut-il venir à Malakoff ?", a: "Oui. Ta demande est montrée aux pet-sitters autour de ton adresse, y compris dans le 14e, le 15e et à Vanves ou Montrouge." },
        { q: "Puis-je faire garder mon chat sans le déplacer ?", a: "Oui. Publie une demande de visites à domicile : le pet-sitter vient nourrir, jouer et nettoyer la litière, et tu reçois des nouvelles dans l'app." },
      ],
      recruit: [
        { q: "Où trouver ses premiers clients à Malakoff ?", a: "Autour de chez toi : les propriétaires préfèrent quelqu'un qui habite à pied. Malakoff, Vanves, Montrouge et le sud du 14e forment une même zone." },
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
      "Petite ville où tout se fait à pied : choisis un pet-sitter du quartier, il pourra passer plusieurs fois par jour.",
      "La ligne 11 (Mairie des Lilas) relie la ville au 19e et au 20e : les pet-sitters de l'est parisien viennent facilement.",
      "Le bouche-à-oreille compte beaucoup : laisser un avis après la garde aide le pet-sitter et les voisins.",
    ],
    faq: {
      owner: [
        { q: "Ma demande est-elle vue par des pet-sitters du 19e et du 20e ?", a: "Oui. Elle est montrée aux pet-sitters autour de ton adresse, aux Lilas comme dans les communes et arrondissements voisins." },
        { q: "Puis-je rencontrer le pet-sitter avant de réserver ?", a: "Oui. Tu discutes dans l'app avant la réservation et tu peux convenir d'une première rencontre." },
      ],
      recruit: [
        { q: "Y a-t-il de la demande aux Lilas ?", a: "Oui, surtout pour les visites à domicile pendant les vacances et les promenades en semaine. Être du quartier est un vrai avantage." },
        { q: "Puis-je aussi garder dans le 19e ou le 20e ?", a: "Oui. Règle ta zone d'intervention sur ce que tu peux rejoindre à pied ou en métro." },
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
      "Beaucoup de maisons avec jardin : précise si le pet-sitter doit promener ton chien ou seulement passer le voir et jouer au jardin.",
      "La gare d'Enghien (ligne H) met la ville à 15 minutes de Paris Nord : pratique pour les pet-sitters qui n'ont pas de voiture.",
      "Les gardes de nuit et les longs week-ends sont fréquents : décris bien la routine de l'animal dans la demande.",
    ],
    faq: {
      owner: [
        { q: "Les communes voisines sont-elles couvertes ?", a: "Oui. Ta demande est montrée aux pet-sitters autour de ton adresse : Enghien, Soisy, Deuil-la-Barre, Montmorency, Saint-Gratien…" },
        { q: "Un pet-sitter peut-il dormir chez moi ?", a: "Oui. Publie une demande de garde à domicile avec les dates ; tu en discutes dans l'app avant de réserver." },
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
      "En été, les chiens sont souvent interdits sur les plages surveillées du lac : vérifie les règles avant une baignade.",
      "En montagne, les troupeaux ont parfois des chiens de protection (patous) : tenir son chien en laisse et contourner le troupeau.",
      "Annecy est très touristique l'été : réserve tôt pour les gardes de juillet-août.",
    ],
    faq: {
      owner: [
        { q: "Mon pet-sitter peut-il emmener mon chien en randonnée ?", a: "Oui si tu l'acceptes et si ton chien est habitué. Précise dans la demande les sentiers qu'il connaît et sa forme." },
        { q: "Les communes autour d'Annecy sont-elles couvertes ?", a: "Oui. Ta demande est montrée aux pet-sitters autour de ton adresse, dans toute l'agglomération." },
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
      "Ville très cyclable : beaucoup de pet-sitters se déplacent à vélo ou en tram, précise si tu habites loin d'un arrêt.",
      "Pendant le marché de Noël, le centre est bondé : prévois des promenades hors de la Grande Île.",
      "Les hivers sont froids : essuyer les pattes après les trottoirs salés.",
    ],
    faq: {
      owner: [
        { q: "Les communes de l'Eurométropole sont-elles couvertes ?", a: "Oui. Ta demande est montrée aux pet-sitters autour de ton adresse, à Strasbourg comme à Schiltigheim, Illkirch ou Lingolsheim." },
        { q: "Puis-je faire garder mon chat pendant les vacances ?", a: "Oui. Publie une demande de visites à domicile : nourriture, litière, jeu et nouvelles dans l'app." },
      ],
      recruit: [
        { q: "Où commencer comme pet-sitter à Strasbourg ?", a: "Dans ton quartier : la Krutenau, Neudorf, l'Esplanade et la Robertsau comptent beaucoup de propriétaires en appartement." },
        { q: "Peut-on garder sans voiture ?", a: "Oui. Le vélo et le tram suffisent pour la plupart des visites ; règle ta zone sur ce que tu rejoins facilement." },
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
      "Le vent et la pluie sont fréquents : sèche bien ton chien après la promenade et prévois un manteau pour les races à poil ras.",
      "Sur la plage, les règles pour les chiens changent selon la saison : vérifie-les avant d'y aller.",
      "La ville haute et la ville basse sont reliées par le funiculaire et le tram : pratique pour les pet-sitters sans voiture.",
    ],
    faq: {
      owner: [
        { q: "Sainte-Adresse et Montivilliers sont-elles couvertes ?", a: "Oui. Ta demande est montrée aux pet-sitters autour de ton adresse, dans toute l'agglomération." },
        { q: "Mon chien peut-il aller à la plage avec le pet-sitter ?", a: "Seulement là et quand les chiens sont autorisés. Sinon, la forêt de Montgeon est une belle alternative." },
      ],
      recruit: [
        { q: "Quelles demandes trouve-t-on au Havre ?", a: "Des promenades en semaine pour les propriétaires qui travaillent, et des gardes pendant les vacances." },
        { q: "Comment se déplacer entre la ville haute et la ville basse ?", a: "Le tram et le funiculaire relient les deux. Règle ta zone sur ce que tu rejoins facilement." },
      ],
    },
  },
  // 23/10/2026 (GUS) — 7 villes FR très vues sur Google sans clic ni guide local :
  // la-rochelle 93 affichages, lille 75, grenoble 71, marseille 66, lyon 62, avignon 59, brest 46.
  "la-rochelle": {
    hoods: ["le Vieux-Port", "les Minimes", "La Genette", "Tasdon", "Villeneuve-les-Salines", "Port-Neuf", "Lafond", "La Pallice"],
    walks: [
      { name: "Parc Charruyer", note: "le grand parc le long des anciens remparts, la balade quotidienne du centre" },
      { name: "Allées du Mail", note: "promenade en bord de mer jusqu'à la plage de la Concurrence, en laisse" },
      { name: "Pointe de Chef de Baie", note: "sentier côtier et falaises à l'ouest de la ville" },
      { name: "Marais de Tasdon", note: "chemins plats autour du lac et des marais, au calme" },
    ],
    tips: [
      "En saison, les chiens sont interdits sur les plages surveillées (Minimes, Concurrence, Chef de Baie) : vérifie le panneau avant d'y aller.",
      "La Rochelle est très touristique de juin à septembre : réserve tôt pour les gardes d'été, les pet-sitters du quartier sont vite pris.",
      "Tout se fait à vélo : un pet-sitter du quartier peut passer plusieurs fois par jour pour les visites à domicile.",
    ],
    faq: {
      owner: [
        { q: "Mon chien peut-il aller à la plage avec le pet-sitter ?", a: "Hors saison oui, sur les plages qui l'autorisent. En été, les plages surveillées lui sont interdites : prévois le parc Charruyer ou le sentier de Chef de Baie." },
        { q: "Les communes autour de La Rochelle sont-elles couvertes ?", a: "Oui. Ta demande est montrée aux pet-sitters autour de ton adresse, à Aytré, Lagord, Périgny ou Puilboreau comme en ville." },
      ],
      recruit: [
        { q: "Quand la demande est-elle la plus forte à La Rochelle ?", a: "L'été et pendant les vacances scolaires, quand les habitants partent et que les vacanciers arrivent avec leurs animaux." },
        { q: "Par où commencer comme pet-sitter à La Rochelle ?", a: "Par ton quartier : le centre, les Minimes, La Genette ou Tasdon. Règle ta zone sur ce que tu rejoins à pied ou à vélo." },
      ],
    },
  },
  lille: {
    hoods: ["le Vieux-Lille", "Wazemmes", "Vauban-Esquermes", "Moulins", "Fives", "Saint-Maurice Pellevoisin", "les Bois-Blancs", "Lille-Sud"],
    walks: [
      { name: "Parc de la Citadelle", note: "le poumon vert de Lille, grande boucle autour des remparts" },
      { name: "Berges de la Deûle", note: "chemin plat vers Lambersart et les Bois-Blancs" },
      { name: "Jardin Vauban", note: "le parc du quartier Vauban, pour les sorties courtes" },
      { name: "Parc Jean-Baptiste Lebas", note: "au sud du centre, entre Moulins et Wazemmes" },
      { name: "Parc Matisse", note: "près des gares, pratique pour les chiens d'appartement du centre" },
    ],
    tips: [
      "Il pleut souvent : prévois une serviette à l'entrée et dis au pet-sitter si ton chien a un manteau.",
      "Beaucoup de Lillois vivent en appartement sans jardin : la promenade de midi en semaine est le service le plus demandé.",
      "Ville étudiante : de nombreux pet-sitters sont disponibles en semaine pendant l'année universitaire, moins l'été.",
    ],
    faq: {
      owner: [
        { q: "Où mon chien peut-il courir à Lille ?", a: "Dans les espaces de liberté pour chiens signalés dans les parcs, comme à la Citadelle. Ailleurs, dans les parcs et sur les berges, il reste en laisse." },
        { q: "Y a-t-il un pet-sitter près de chez moi à Lille ?", a: "Ouvre la carte dans HoPetSit pour voir les pet-sitters autour du Vieux-Lille, de Wazemmes, de Vauban, de Fives ou de Moulins. Tu discutes dans l'app avant de réserver." },
      ],
      recruit: [
        { q: "Par où commencer comme pet-sitter à Lille ?", a: "Par ton quartier : Vauban, Wazemmes, le Vieux-Lille ou Fives. Garde une zone que tu parcours à pied ou en métro pour enchaîner les promenades de midi." },
        { q: "Qu'attendent les propriétaires lillois ?", a: "Des promenades à l'heure, le chien en laisse hors des espaces autorisés, et un petit message après chaque visite. HoPetSit partage la balade en direct sur la carte." },
      ],
    },
  },
  grenoble: {
    hoods: ["l'hyper-centre", "l'Île Verte", "Championnet", "Berriat et Saint-Bruno", "les Eaux-Claires", "La Tronche", "Meylan", "Saint-Martin-d'Hères"],
    walks: [
      { name: "Parc Paul-Mistral", note: "le grand parc du centre, la sortie quotidienne de beaucoup de chiens" },
      { name: "La Bastille", note: "sentiers en montée depuis le quai, chiens en laisse, vue sur toute la vallée" },
      { name: "Berges de l'Isère", note: "chemins plats le long de la rivière vers La Tronche et Meylan" },
      { name: "Parc de l'Île d'Amour", note: "à Meylan, au bord de l'Isère, pour les grandes balades" },
      { name: "Vercors et Chartreuse", note: "sentiers en forêt et en alpage pour les chiens sportifs, le week-end" },
    ],
    tips: [
      "Les étés sont chauds dans la cuvette : en juillet-août, les promenades se font tôt le matin ou le soir, avec de l'eau.",
      "En montagne, les troupeaux ont parfois des chiens de protection (patous) : tenir son chien en laisse et contourner le troupeau.",
      "Beaucoup de propriétaires partent en montagne le week-end : les visites à domicile et les gardes de deux jours sont très demandées.",
    ],
    faq: {
      owner: [
        { q: "Mon pet-sitter peut-il emmener mon chien à la Bastille ou en montagne ?", a: "Oui si tu l'acceptes et si ton chien est habitué. Précise dans la demande les sentiers qu'il connaît et sa forme physique." },
        { q: "Y a-t-il un pet-sitter près de chez moi à Grenoble ?", a: "Ouvre la carte dans HoPetSit pour voir les pet-sitters autour du centre, de l'Île Verte, de Berriat, de Meylan ou de Saint-Martin-d'Hères. Tu discutes dans l'app avant de réserver." },
      ],
      recruit: [
        { q: "Quand la demande est-elle la plus forte à Grenoble ?", a: "Les week-ends et les vacances scolaires, quand les habitants partent en montagne. Être disponible le week-end est un vrai avantage." },
        { q: "Que faut-il savoir pour promener en montagne ?", a: "Garder le chien en laisse près des troupeaux, contourner les chiens de protection, prévoir de l'eau et adapter l'effort à l'animal." },
      ],
    },
  },
  marseille: {
    hoods: ["le Vieux-Port et le Panier", "Endoume et le Roucas-Blanc", "Castellane", "La Plaine et Cours Julien", "Bonneveine", "Mazargues", "Saint-Barnabé", "Sainte-Marguerite"],
    walks: [
      { name: "Parc Borély", note: "le grand parc du sud de la ville, à côté des plages du Prado" },
      { name: "Corniche Kennedy", note: "promenade en bord de mer, en laisse, superbe tôt le matin" },
      { name: "Parc du 26e Centenaire", note: "le parc du centre, entre Castellane et Saint-Pierre" },
      { name: "Parc Longchamp", note: "le jardin historique près de Cinq-Avenues" },
      { name: "Campagne Pastré et les Calanques", note: "chemins vers Marseilleveyre et Sormiou, chiens en laisse" },
    ],
    tips: [
      "En saison, les plages sont interdites aux chiens, sauf l'espace qui leur est réservé : vérifie le panneau avant d'y aller.",
      "En été, l'accès aux massifs (Calanques, Marseilleveyre) est réglementé les jours de risque d'incendie : consulte l'affichage du jour avant une randonnée.",
      "Les promenades d'été se font tôt le matin ou le soir, avec de l'eau ; par mistral, préfère les parcs abrités.",
    ],
    faq: {
      owner: [
        { q: "Mon chien peut-il aller dans les Calanques avec le pet-sitter ?", a: "Oui, en laisse, hors des jours où l'accès aux massifs est fermé pour risque d'incendie. Précise dans la demande les chemins qu'il connaît et son endurance." },
        { q: "Y a-t-il un pet-sitter près de chez moi à Marseille ?", a: "Ouvre la carte dans HoPetSit pour voir les pet-sitters autour du Vieux-Port, d'Endoume, de Castellane, de Bonneveine ou de Saint-Barnabé. Tu discutes dans l'app avant de réserver." },
      ],
      recruit: [
        { q: "Par où commencer comme pet-sitter à Marseille ?", a: "Par ton quartier : la ville est immense et les propriétaires préfèrent quelqu'un de proche. Règle ta zone sur quelques arrondissements que tu rejoins vite." },
        { q: "Quand la demande est-elle la plus forte à Marseille ?", a: "L'été et pendant les vacances scolaires, quand les habitants partent et que les visiteurs arrivent avec leurs animaux." },
      ],
    },
  },
  lyon: {
    hoods: ["la Presqu'île", "la Croix-Rousse", "le Vieux-Lyon", "les Brotteaux et la Part-Dieu", "Monplaisir", "Gerland", "Vaise", "Confluence", "Villeurbanne"],
    walks: [
      { name: "Parc de la Tête d'Or", note: "le grand parc du 6e, chiens en laisse et certains espaces interdits : respecte les panneaux" },
      { name: "Berges du Rhône", note: "promenade plate du parc de la Tête d'Or jusqu'à Gerland" },
      { name: "Parc de Gerland", note: "au sud, grandes pelouses et bords du Rhône" },
      { name: "Parc de la Feyssine", note: "à Villeurbanne, chemins nature au bord du Rhône" },
      { name: "Grand Parc de Miribel-Jonage", note: "pour les grandes balades du week-end, en laisse près des plans d'eau" },
    ],
    tips: [
      "Lyon est dense et beaucoup d'animaux vivent en appartement : la promenade de midi en semaine est le service le plus demandé.",
      "Les étés sont chauds : en juillet-août, les sorties se font tôt le matin ou le soir, avec de l'eau.",
      "Les propriétaires partent souvent le week-end (montagne, Beaujolais) : les visites à domicile et les gardes de deux jours sont fréquentes.",
    ],
    faq: {
      owner: [
        { q: "Où mon chien peut-il courir à Lyon ?", a: "Dans les espaces de liberté signalés dans les parcs. À la Tête d'Or, sur les berges et dans les autres parcs, il reste en laisse." },
        { q: "Y a-t-il un pet-sitter près de chez moi à Lyon ?", a: "Ouvre la carte dans HoPetSit pour voir les pet-sitters autour de la Croix-Rousse, de la Presqu'île, de Monplaisir, de Gerland ou de Villeurbanne. Tu discutes dans l'app avant de réserver." },
      ],
      recruit: [
        { q: "Par où commencer comme pet-sitter à Lyon ?", a: "Par ton arrondissement : les propriétaires préfèrent quelqu'un de proche. Garde une zone que tu parcours à pied ou en métro pour enchaîner les promenades de midi." },
        { q: "Qu'attendent les propriétaires lyonnais ?", a: "Des promenades à l'heure, le chien en laisse hors des espaces autorisés, et un petit message après chaque visite. HoPetSit partage la balade en direct sur la carte." },
      ],
    },
  },
  avignon: {
    hoods: ["l'intra-muros", "Saint-Ruf", "Monclar", "Montfavet", "la Barthelasse", "les Rotondes", "Villeneuve-lès-Avignon", "Les Angles"],
    walks: [
      { name: "Île de la Barthelasse", note: "chemins plats le long du Rhône, la grande balade des Avignonnais" },
      { name: "Rocher des Doms", note: "le jardin au-dessus du Palais des Papes, en laisse" },
      { name: "Berges du Rhône", note: "promenade au pied des remparts, face au pont" },
      { name: "Parc Chico-Mendès", note: "le parc du quartier Monclar, pour les sorties quotidiennes" },
    ],
    tips: [
      "En juillet, le Festival remplit l'intra-muros : foule, bruit et rues fermées — prévois des balades sur la Barthelasse ou hors des remparts.",
      "Les étés sont chauds et le mistral souffle fort : promenades tôt le matin ou le soir, avec de l'eau.",
      "Beaucoup d'habitants partent en été : les visites à domicile et les gardes longues sont très demandées de juin à septembre.",
    ],
    faq: {
      owner: [
        { q: "Mon chien supporte mal le Festival. Que dire au pet-sitter ?", a: "Où il se cache, s'il peut rester seul avec le bruit et les horaires calmes pour sortir. Mettez-le dans la demande et dans la discussion avant de réserver." },
        { q: "Villeneuve ou Les Angles sont-elles couvertes ?", a: "Oui. Ta demande est montrée aux pet-sitters autour de ton adresse, des deux côtés du Rhône." },
      ],
      recruit: [
        { q: "Quand la demande est-elle la plus forte à Avignon ?", a: "En juillet pendant le Festival et tout l'été, quand les habitants partent. Être disponible ces mois-là est un vrai avantage." },
        { q: "Par où commencer comme pet-sitter à Avignon ?", a: "Par ton quartier : l'intra-muros, Saint-Ruf, Monclar ou Montfavet. Règle ta zone sur ce que tu rejoins à pied ou à vélo." },
      ],
    },
  },
  brest: {
    hoods: ["Siam et le centre", "Saint-Martin", "Recouvrance", "Saint-Marc", "Bellevue", "Lambézellec", "Kerinou", "Le Relecq-Kerhuon"],
    walks: [
      { name: "Vallon du Stang-Alar", note: "le jardin botanique et son vallon, en laisse, la balade préférée du centre" },
      { name: "Plage du Moulin Blanc", note: "la plage de la ville, chiens autorisés hors saison et selon l'affichage" },
      { name: "Rives de Penfeld", note: "chemins au bord de la rivière, du centre jusqu'à Lambézellec" },
      { name: "Bois de Keroual", note: "à Guilers, grande forêt pour les chiens sportifs" },
      { name: "Sentier côtier GR34", note: "le long de la rade, vers Plougastel ou le Conquet, chiens en laisse" },
    ],
    tips: [
      "Il pleut et il vente souvent : prévois une serviette à l'entrée et dis au pet-sitter si ton chien a un manteau.",
      "Ville de marins et de militaires : les gardes longues pendant les missions et les déplacements sont fréquentes.",
      "Sur la côte, surveille les marées et la houle : les promenades sur les rochers se font à marée basse, en laisse.",
    ],
    faq: {
      owner: [
        { q: "Mon chien peut-il aller à la plage avec le pet-sitter ?", a: "Hors saison oui, au Moulin Blanc et sur les plages qui l'autorisent. En été, respecte l'affichage de chaque plage. Précise dans la demande s'il aime l'eau." },
        { q: "Y a-t-il un pet-sitter près de chez moi à Brest ?", a: "Ouvre la carte dans HoPetSit pour voir les pet-sitters autour de Siam, de Saint-Martin, de Recouvrance, de Saint-Marc ou de Bellevue. Tu discutes dans l'app avant de réserver." },
      ],
      recruit: [
        { q: "Quand la demande est-elle la plus forte à Brest ?", a: "Pendant les vacances scolaires et lors des missions et déplacements des habitants, toute l'année. Les gardes longues sont fréquentes." },
        { q: "Par où commencer comme pet-sitter à Brest ?", a: "Par ton quartier : le centre, Saint-Martin, Saint-Marc ou Bellevue. Règle ta zone sur ce que tu rejoins à pied ou en tram." },
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

const DFW = new Set(["dallas", "fort-worth", "plano", "frisco", "irving", "arlington-tx"]);

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
          ? mode === "owner" ? "Quartiers couverts : " : "Quartiers où commencer : "
          : mode === "owner" ? "Neighborhoods where owners post requests: " : "Neighborhoods to start in: "}
        {g.hoods.join(", ")}.
      </p>
      <h3 className="mt-6 text-base font-bold text-ink">
        {fr
          ? mode === "owner" ? "Où les pet-sitters promènent les chiens" : "Où tu promèneras"
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
      {/* 12/10 (GUS) — Search Console 28 j : « dog sitting <ville> » et « dog sitter <ville> » en
          10e-20e place avec 0 clic sur ~800 affichages (Los Angeles 78, Columbus 71+58, Miami 48,
          Naples 39, Detroit 37, Houston 37, Decatur 81+63…). La page ne disait pas ce qu'est une
          garde de chien ici. Bloc propriétaire EN, texte vrai (garde à domicile, visites, balades
          suivies en direct), aucun chiffre inventé ; lieux de promenade pris dans le guide local. */}
      {!fr && mode === "owner" && (
        <div className="mt-8" aria-labelledby="us-dog-sitting">
          <h2 id="us-dog-sitting" className="font-display text-2xl font-extrabold text-ink">{`Dog sitting in ${name}: at your home, walks included`}</h2>
          <p className="mt-3 text-sm leading-relaxed text-ink-muted">
            {`Dog sitting in ${name} means your dog stays in its own home and routine: the sitter sleeps over or stops by for feeding, play and walks, and sends you a photo or a short note after each visit. Walks are tracked live on the map, so you can see when your dog went out to ${g.walks.slice(0, 2).map((w) => w.name).join(" or ")} and for how long. Sitters live around ${g.hoods.slice(0, 3).join(", ")} and the nearby neighborhoods.`}
          </p>
          <ul className="mt-3 space-y-2">
            {[
              "Going away for a weekend or a vacation? Ask for an overnight sitter who stays at your place, or for daily visits if your dog is fine alone at night.",
              "Long workdays? Book a dog sitter for a midday visit and a walk, at the time that suits you.",
              `Post your dates and what your dog needs; sitters near you in ${name} reply in the app. You chat first, read reviews, and the amount stays in the app until the sitting is done.`,
            ].map((t) => (
              <li key={t} className="flex gap-2 text-sm leading-relaxed text-ink-muted">
                <span aria-hidden="true" className="mt-2 h-1.5 w-1.5 shrink-0 rounded-full bg-owner" />
                <span>{t}</span>
              </li>
            ))}
          </ul>
          {/* 14/10 (GUS) — lien vers le guide général « dog sitting » (article du 14/10). */}
          <p className="mt-3 text-sm leading-relaxed text-ink-muted">
            New to this?{" "}
            <Link href="/blog/what-is-dog-sitting" className="font-semibold text-owner underline">
              Dog sitting explained: visits, day sitting or overnight stays, and how to choose a sitter
            </Link>
            .
          </p>
          {/* 26/10 (GUS) — Search Console 28 j : le guide des prix de Dallas a 793 affichages pour
              3 clics (place 17), surtout sur « tarif par jour / pour la nuit ». Aucune page
              Dallas-Fort Worth ne le reliait : lien depuis les pages propriétaires de la région. */}
          {DFW.has(slug) && (
            <p className="mt-2 text-sm leading-relaxed text-ink-muted">
              What does it cost?{" "}
              <Link href="/blog/how-much-does-a-pet-sitter-cost-in-dallas" className="font-semibold text-owner underline">
                Pet sitting rates per day and overnight in Dallas-Fort Worth
              </Link>
              .
            </p>
          )}
        </div>
      )}
      {/* 11/10 (GUS) — Search Console : « cat sitting / cat sitter <ville> » en 11e-20e place
          (Naples 38 affichages, Cincinnati 34, Honolulu 23, St. Louis 15) avec 0 clic : la page
          ne parlait des chats qu'en un mot. Bloc propriétaire EN, texte vrai (visites à domicile),
          aucun chiffre inventé ; les quartiers viennent du guide local de la ville. */}
      {!fr && mode === "owner" && (
        <div className="mt-8" aria-labelledby="us-cat-sitting">
          <h2 id="us-cat-sitting" className="font-display text-2xl font-extrabold text-ink">{`Cat sitting in ${name}: drop-in visits at home`}</h2>
          <p className="mt-3 text-sm leading-relaxed text-ink-muted">
            {`Most cats are happier staying home than being boarded. A cat sitter in ${name} comes to your place once or twice a day: fresh food and water, a clean litter box, playtime or quiet company, medication if your cat needs it, and a photo or short note after each visit in the app. Sitters who offer cat visits live around ${g.hoods.slice(0, 3).join(", ")} and the surrounding neighborhoods.`}
          </p>
          <ul className="mt-3 space-y-2">
            {[
              "Post a request for cat drop-in visits with your dates and how many visits a day you want; sitters near you reply in the app.",
              "Chat first, then book: the amount stays in the app until the visits are done.",
              `Longer trip? Ask for a sitter who can also sleep over so your cat keeps its routine in ${name}.`,
            ].map((t) => (
              <li key={t} className="flex gap-2 text-sm leading-relaxed text-ink-muted">
                <span aria-hidden="true" className="mt-2 h-1.5 w-1.5 shrink-0 rounded-full bg-owner" />
                <span>{t}</span>
              </li>
            ))}
          </ul>
          {/* 21/10 (GUS) — lien vers le guide général « cat sitting » (article du 21/10). */}
          <p className="mt-3 text-sm leading-relaxed text-ink-muted">
            New to this?{" "}
            <Link href="/blog/what-is-cat-sitting" className="font-semibold text-owner underline">
              Cat sitting explained: what happens on each visit and how many visits your cat needs
            </Link>
            .
          </p>
        </div>
      )}
    </section>
  );
}

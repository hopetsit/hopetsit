import DATA from "@/lib/city-districts.json";

// 31/10/2026 (GUS, consigne de Daniel relayée par BOB) — section « Quartiers » des pages piliers
// New York (5 boroughs), Séoul (25 gu) et Tokyo (23 arrondissements spéciaux), sur le modèle de Paris.
// Données RÉELLES : OpenStreetMap, lieux limités à la frontière administrative de chaque quartier
// (~/hopetsit-social/city_districts_build.py). Aucun chiffre inventé : on affiche les comptes OSM
// en citant la source. Une ancre par quartier (#id) + « quartiers proches » (centre à centre).
type D = { id: string; name: string; en: string; counts: { vet: number; shop: number; groomer: number; dogpark: number }; dogparks: string[]; parks: string[]; hoods: string[]; near: string[] };
const CITY_LANG: Record<string, "en" | "ko" | "ja"> = { "new-york": "en", seoul: "ko", tokyo: "ja" };
// Guide de la ville (article du blog dans la langue de la ville) — lien entrant depuis la page pilier indexée.
const GUIDE: Record<string, { href: string; label: string }> = {
  "new-york": { href: "/blog/pet-sitting-new-york-holidays", label: "Guide: pet sitting in New York over the holidays →" },
  seoul: { href: "/blog/seoul-pet-sitter-guide", label: "가이드: 서울 반려견 산책·펫시터 가이드 →" },
  tokyo: { href: "/blog/tokyo-pet-sitter-guide", label: "ガイド：東京でペットシッターを頼むときのポイント →" },
};

const T = {
  en: {
    title: (c: string) => `${c} neighborhoods`,
    intro: "Pick your borough: the dog runs, parks and pet services around you, from OpenStreetMap data limited to each borough's official boundary.",
    counts: (c: D["counts"]) => `Listed in OpenStreetMap within the borough: ${c.vet} vets, ${c.shop} pet shops, ${c.groomer} groomers, ${c.dogpark} dog runs.`,
    hoods: "Neighborhoods:", dogparks: "Dog runs:", parks: "Parks:", near: "Nearby:", src: "Source: © OpenStreetMap contributors (ODbL).",
    label: (d: D) => d.en,
  },
  ko: {
    title: (c: string) => `${c} 구별 안내`,
    intro: "내 동네를 고르세요. 각 구의 공식 경계 안에 있는 반려견 놀이터, 공원, 반려동물 시설을 OpenStreetMap 자료로 정리했습니다.",
    counts: (c: D["counts"]) => `OpenStreetMap에 등록된 구 내 시설: 동물병원 ${c.vet}곳, 반려동물 용품점 ${c.shop}곳, 미용실 ${c.groomer}곳, 반려견 놀이터 ${c.dogpark}곳.`,
    hoods: "동네:", dogparks: "반려견 놀이터:", parks: "공원:", near: "가까운 구:", src: "출처: © OpenStreetMap 기여자 (ODbL).",
    label: (d: D) => `${d.name} ${d.en}`,
  },
  ja: {
    title: (c: string) => `${c}の区別ガイド`,
    intro: "お住まいの区を選んでください。各区の境界内にあるドッグラン、公園、ペット関連施設を OpenStreetMap のデータでまとめました。",
    counts: (c: D["counts"]) => `OpenStreetMap に登録された区内の施設：動物病院 ${c.vet}、ペットショップ ${c.shop}、トリミングサロン ${c.groomer}、ドッグラン ${c.dogpark}。`,
    hoods: "地区：", dogparks: "ドッグラン：", parks: "公園：", near: "近くの区：", src: "出典：© OpenStreetMap contributors (ODbL)。",
    label: (d: D) => `${d.name}（${d.en}）`,
  },
};

export default function CityDistricts3110({ slug, lang, name }: { slug: string; lang: string; name: string }) {
  const l = CITY_LANG[slug];
  const list = (DATA as Record<string, D[]>)[slug];
  if (!l || l !== lang || !list?.length) return null;
  const t = T[l];
  const byId = Object.fromEntries(list.map((d) => [d.id, d]));
  return (
    <section id="districts" className="mt-14 scroll-mt-24" data-districts-3110={slug}>
      <h2 className="font-display text-2xl font-extrabold text-ink">{t.title(name)}</h2>
      <p className="mt-2 text-sm leading-relaxed text-ink-muted">{t.intro}</p>
      {GUIDE[slug] && <p className="mt-2 text-sm"><a href={GUIDE[slug].href} className="font-bold text-owner-dark underline-offset-2 hover:underline">{GUIDE[slug].label}</a></p>}
      <nav className="mt-4 flex flex-wrap gap-2">
        {list.map((d) => (
          <a key={d.id} href={`#${d.id}`} className="inline-flex min-h-[40px] items-center rounded-full bg-owner-light px-3 text-sm font-semibold text-owner-dark">{t.label(d)}</a>
        ))}
      </nav>
      <div className="mt-6 grid gap-4 md:grid-cols-2">
        {list.map((d) => (
          <article key={d.id} id={d.id} className="scroll-mt-24 rounded-2xl border border-ink/5 bg-white p-5 shadow-card">
            <h3 className="font-bold text-ink">
              {/* New York : chaque borough a sa page (31/10, GUS) — lien entrant depuis le pilier indexé. */}
              {slug === "new-york" ? <a href={`/pet-sitting-new-york/${d.id}`} className="underline-offset-2 hover:underline">{t.label(d)} →</a> : t.label(d)}
            </h3>
            {/* Comptes OSM affichés seulement quand ils sont représentatifs (≥ 10 vétérinaires recensés) :
                à Séoul et Tokyo, OSM recense mal les commerces (Naver/Kakao, Google y dominent) — un « 2 » serait trompeur. */}
            {slug === "new-york" && d.counts.vet >= 10 && <p className="mt-2 text-sm leading-relaxed text-ink-muted">{t.counts(d.counts)}</p>}
            {d.hoods.length > 0 && <p className="mt-2 text-sm leading-relaxed text-ink-muted"><b className="text-ink">{t.hoods}</b> {d.hoods.join(", ")}</p>}
            {d.dogparks.length > 0 && <p className="mt-2 text-sm leading-relaxed text-ink-muted"><b className="text-ink">{t.dogparks}</b> {d.dogparks.join(", ")}</p>}
            {d.parks.length > 0 && <p className="mt-2 text-sm leading-relaxed text-ink-muted"><b className="text-ink">{t.parks}</b> {d.parks.join(", ")}</p>}
            <p className="mt-3 text-sm">
              <span className="font-semibold text-ink">{t.near} </span>
              {d.near.map((n, i) => byId[n] && (
                <span key={n}>{i > 0 && " · "}<a href={`#${n}`} className="font-semibold text-owner-dark underline-offset-2 hover:underline">{t.label(byId[n])}</a></span>
              ))}
            </p>
          </article>
        ))}
      </div>
      <p className="mt-3 text-xs text-ink-muted">{t.src}</p>
    </section>
  );
}

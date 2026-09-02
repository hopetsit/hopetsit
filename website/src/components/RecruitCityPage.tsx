import Link from "next/link";
import type { RecruitCity, RecruitLang } from "@/lib/recruit-cities";

// v547 — page « devenir pet sitter à <ville> » (composant serveur statique,
// indexable). Copie par langue, détail local injecté pour que chaque page
// soit unique aux yeux de Google.

type Copy = {
  kicker: (c: RecruitCity) => string;
  h1: (c: RecruitCity) => string;
  intro: (c: RecruitCity) => string;
  badges: string[];
  howTitle: string;
  steps: { t: string; p: string }[];
  faqTitle: string;
  faq: (c: RecruitCity) => { q: string; a: string }[];
  ctaTitle: (c: RecruitCity) => string;
  ctaText: (c: RecruitCity) => string;
  ctaBtn: string;
  localTitle: (c: RecruitCity) => string;
  inLanguage: string;
};

const COPY: Record<RecruitLang, Copy> = {
  fr: {
    kicker: (c) => c.region,
    h1: (c) => `Devenir pet sitter à ${c.name} — soyez payé pour aimer les animaux`,
    intro: (c) =>
      `Étudiant, en télétravail, retraité ou simplement passionné ? À ${c.name}, des propriétaires de chiens et de chats cherchent quelqu'un de confiance pour les garder pendant les vacances ou les journées de travail. HoPetSit vous met en relation avec eux : vous fixez vos tarifs, vous choisissez vos services, vous êtes payé en sécurité.`,
    badges: ["💶 Vos tarifs, vos règles", "📅 Vous choisissez vos horaires", "✓ Badge vérifié", "🔒 Zéro impayé"],
    howTitle: "Comment ça marche",
    steps: [
      { t: "Créez votre profil gratuit", p: "Photo, présentation, services proposés (garde à domicile, visites, promenades) et VOS tarifs — c'est vous qui décidez." },
      { t: "Faites vérifier votre identité", p: "5 minutes dans l'app. Le badge ✓ rassure les propriétaires : les profils vérifiés reçoivent beaucoup plus de demandes." },
      { t: "Recevez des demandes et discutez", p: "Les propriétaires de votre quartier vous contactent par chat. Vous acceptez uniquement ce qui vous convient." },
      { t: "Soyez payé en toute sécurité", p: "Le paiement est bloqué dans l'app dès la réservation et versé sur votre compte bancaire une fois le service terminé." },
    ],
    faqTitle: "Questions fréquentes",
    faq: (c) => [
      { q: `Combien peut-on gagner comme pet sitter à ${c.name} ?`, a: `À ${c.name}, les gardes se facturent généralement ${c.dayRate} par jour et les promenades ${c.walkRate}. Avec quelques clients réguliers, un complément de 300 à 600 € par mois est réaliste.` },
      { q: "Faut-il un diplôme ou un statut particulier ?", a: "Aucun diplôme n'est requis pour commencer sur HoPetSit — il faut aimer les animaux, être fiable et avoir 18 ans ou plus. Pour une activité régulière, le statut d'auto-entrepreneur se crée gratuitement en ligne." },
      { q: "L'inscription coûte-t-elle quelque chose ?", a: "Non, l'inscription et le profil sont gratuits. Seule la vérification d'identité (badge ✓, fortement recommandée) coûte 3 €." },
      { q: "Comment le suivi GPS protège-t-il aussi le sitter ?", a: "Pendant une promenade, le suivi PawFollow prouve que le service a bien été rendu, du départ au retour. Transparence pour le propriétaire, protection pour vous." },
    ],
    ctaTitle: (c) => `Les premiers inscrits à ${c.name} prennent les meilleurs clients`,
    ctaText: (c) => `HoPetSit se lance à ${c.name} : peu de concurrence entre sitters, des propriétaires qui arrivent chaque semaine. C'est le meilleur moment pour créer votre profil.`,
    ctaBtn: "Créer mon profil gratuit",
    localTitle: (c) => `Garder des animaux à ${c.name}`,
    inLanguage: "fr",
  },
  en: {
    kicker: (c) => c.region,
    h1: (c) => `Become a pet sitter in ${c.name} — get paid to love animals`,
    intro: (c) =>
      `Student, remote worker, retiree or simply an animal lover? In ${c.name}, dog and cat owners are looking for someone they can trust while they work or travel. HoPetSit connects you with them: you set your rates, you choose your services, you get paid securely.`,
    badges: ["💵 Your rates, your rules", "📅 You choose your hours", "✓ Verified badge", "🔒 Guaranteed payment"],
    howTitle: "How it works",
    steps: [
      { t: "Create your free profile", p: "Photo, bio, services (home sitting, drop-in visits, walks) and YOUR rates — you decide." },
      { t: "Get your identity verified", p: "5 minutes in the app. The ✓ badge reassures owners: verified profiles receive far more requests." },
      { t: "Receive requests and chat", p: "Owners in your neighborhood contact you by chat. You only accept what suits you." },
      { t: "Get paid securely", p: "Payment is held in the app at booking and released to your bank account once the service is done. No unpaid jobs." },
    ],
    faqTitle: "Frequently asked questions",
    faq: (c) => [
      { q: `How much can a pet sitter earn in ${c.name}?`, a: `In ${c.name}, sitting typically pays ${c.dayRate} per day and walks ${c.walkRate}. With a few regular clients, $400–800 a month on the side is realistic.` },
      { q: "Do I need a license or certification?", a: "No certification is required to start on HoPetSit — you need to love animals, be reliable and be 18 or older." },
      { q: "Does it cost anything to sign up?", a: "No. Signing up and creating your profile is free. Only identity verification (the ✓ badge, strongly recommended) costs $3." },
      { q: "How does GPS tracking protect the sitter too?", a: "During a walk, PawFollow tracking proves the service was delivered from start to finish. Transparency for the owner, protection for you." },
    ],
    ctaTitle: (c) => `Early sitters in ${c.name} get the best clients`,
    ctaText: (c) => `HoPetSit is launching in ${c.name}: little competition between sitters, new owners every week. This is the best time to create your profile.`,
    ctaBtn: "Create my free profile",
    localTitle: (c) => `Pet sitting in ${c.name}`,
    inLanguage: "en",
  },
  pl: {
    kicker: (c) => c.region,
    h1: (c) => `Zostań opiekunem zwierząt w mieście ${c.name} — zarabiaj, robiąc to, co kochasz`,
    intro: (c) =>
      `Studiujesz, pracujesz zdalnie, jesteś na emeryturze albo po prostu kochasz zwierzęta? W mieście ${c.name} właściciele psów i kotów szukają zaufanej osoby na czas pracy lub wyjazdu. HoPetSit łączy Cię z nimi: sam ustalasz stawki, wybierasz usługi i otrzymujesz bezpieczną zapłatę.`,
    badges: ["💰 Twoje stawki, Twoje zasady", "📅 Sam wybierasz godziny", "✓ Zweryfikowany profil", "🔒 Gwarancja zapłaty"],
    howTitle: "Jak to działa",
    steps: [
      { t: "Załóż darmowy profil", p: "Zdjęcie, opis, usługi (opieka w domu, wizyty, spacery) i TWOJE stawki — Ty decydujesz." },
      { t: "Zweryfikuj tożsamość", p: "5 minut w aplikacji. Odznaka ✓ uspokaja właścicieli: zweryfikowane profile dostają znacznie więcej zapytań." },
      { t: "Odbieraj zapytania i rozmawiaj", p: "Właściciele z Twojej okolicy piszą do Ciebie na czacie. Przyjmujesz tylko to, co Ci odpowiada." },
      { t: "Otrzymuj bezpieczną zapłatę", p: "Płatność jest blokowana w aplikacji przy rezerwacji i trafia na Twoje konto po wykonaniu usługi. Zero niezapłaconych zleceń." },
    ],
    faqTitle: "Najczęstsze pytania",
    faq: (c) => [
      { q: `Ile można zarobić jako opiekun zwierząt w mieście ${c.name}?`, a: `W mieście ${c.name} opieka kosztuje zwykle ${c.dayRate} za dzień, a spacer ${c.walkRate}. Z kilkoma stałymi klientami dodatkowe 1000–2000 zł miesięcznie jest realne.` },
      { q: "Czy potrzebuję uprawnień lub kursu?", a: "Nie. Aby zacząć na HoPetSit, wystarczy kochać zwierzęta, być odpowiedzialnym i mieć ukończone 18 lat." },
      { q: "Czy rejestracja coś kosztuje?", a: "Nie. Rejestracja i profil są darmowe. Płatna jest tylko weryfikacja tożsamości (odznaka ✓, mocno zalecana): 3 €." },
      { q: "Jak śledzenie GPS chroni także opiekuna?", a: "Podczas spaceru śledzenie PawFollow udowadnia, że usługa została wykonana od początku do końca. Przejrzystość dla właściciela, ochrona dla Ciebie." },
    ],
    ctaTitle: (c) => `Pierwsi opiekunowie w mieście ${c.name} zdobywają najlepszych klientów`,
    ctaText: (c) => `HoPetSit startuje w mieście ${c.name}: mała konkurencja między opiekunami, nowi właściciele co tydzień. To najlepszy moment, aby założyć profil.`,
    ctaBtn: "Załóż darmowy profil",
    localTitle: (c) => `Opieka nad zwierzętami — ${c.name}`,
    inLanguage: "pl",
  },
  ko: {
    kicker: (c) => c.region,
    h1: (c) => `${c.name} 펫시터 되기 — 동물을 사랑하며 수입을 얻으세요`,
    intro: (c) =>
      `학생, 재택근무자, 은퇴자, 혹은 그저 동물을 사랑하는 분이신가요? ${c.name}의 반려견·반려묘 보호자들은 출근이나 여행 중 믿고 맡길 사람을 찾고 있습니다. HoPetSit이 여러분을 연결합니다. 요금은 직접 정하고, 서비스는 골라서, 안전하게 정산받으세요.`,
    badges: ["💴 내가 정하는 요금", "📅 내가 정하는 시간", "✓ 인증 배지", "🔒 정산 보장"],
    howTitle: "이용 방법",
    steps: [
      { t: "무료 프로필 만들기", p: "사진, 소개, 서비스(방문 돌봄, 짧은 방문, 산책)와 나만의 요금 — 모든 것은 직접 정합니다." },
      { t: "신원 인증하기", p: "앱에서 5분이면 됩니다. ✓ 배지는 보호자를 안심시키고, 인증된 프로필은 훨씬 더 많은 요청을 받습니다." },
      { t: "요청 받고 대화하기", p: "동네 보호자들이 채팅으로 연락합니다. 마음에 드는 요청만 수락하세요." },
      { t: "안전하게 정산받기", p: "예약 시 결제금이 앱에 보관되고, 서비스 완료 후 계좌로 입금됩니다. 미수금 걱정이 없습니다." },
    ],
    faqTitle: "자주 묻는 질문",
    faq: (c) => [
      { q: `${c.name}에서 펫시터는 얼마나 벌 수 있나요?`, a: `${c.name}에서는 하루 돌봄이 보통 ${c.dayRate}, 산책은 ${c.walkRate} 정도입니다. 단골 몇 분만 있어도 월 30만~60만 원의 부수입이 가능합니다.` },
      { q: "자격증이 필요한가요?", a: "아니요. HoPetSit을 시작하는 데 자격증은 필요 없습니다. 동물을 사랑하고, 책임감 있고, 만 18세 이상이면 됩니다." },
      { q: "가입 비용이 있나요?", a: "없습니다. 가입과 프로필 작성은 무료입니다. 신원 인증(✓ 배지, 강력 추천)만 3€입니다." },
      { q: "GPS 추적이 펫시터도 보호하나요?", a: "산책 중 PawFollow 추적은 출발부터 귀가까지 서비스가 제대로 이루어졌음을 증명합니다. 보호자에게는 투명성, 여러분에게는 보호막입니다." },
    ],
    ctaTitle: (c) => `${c.name}의 첫 펫시터가 가장 좋은 고객을 만납니다`,
    ctaText: (c) => `HoPetSit이 ${c.name}에서 시작합니다. 펫시터 간 경쟁은 적고, 새 보호자는 매주 늘어납니다. 지금이 프로필을 만들 최고의 시기입니다.`,
    ctaBtn: "무료 프로필 만들기",
    localTitle: (c) => `${c.name}에서 반려동물 돌보기`,
    inLanguage: "ko",
  },
};

export function recruitMetadata(c: RecruitCity, canonical: string) {
  const copy = COPY[c.lang];
  const title =
    c.lang === "fr" ? `Devenir pet sitter à ${c.name} — HoPetSit`
    : c.lang === "en" ? `Become a pet sitter in ${c.name} — HoPetSit`
    : c.lang === "pl" ? `Zostań opiekunem zwierząt — ${c.name} — HoPetSit`
    : `${c.name} 펫시터 되기 — HoPetSit`;
  return {
    title,
    description: copy.intro(c).slice(0, 155),
    alternates: { canonical },
    openGraph: { title, description: copy.intro(c).slice(0, 155), url: canonical, type: "website" as const },
  };
}

export default function RecruitCityPage({ city }: { city: RecruitCity }) {
  const copy = COPY[city.lang];
  const faq = copy.faq(city);
  const jsonLd = {
    "@context": "https://schema.org",
    "@graph": [
      { "@type": "WebPage", name: copy.h1(city), inLanguage: copy.inLanguage },
      {
        "@type": "FAQPage",
        mainEntity: faq.map((f) => ({
          "@type": "Question",
          name: f.q,
          acceptedAnswer: { "@type": "Answer", text: f.a },
        })),
      },
    ],
  };

  return (
    <div className="mx-auto max-w-3xl px-4 py-16 md:py-24">
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }} />
      <p className="text-sm font-semibold text-sitter-dark">{copy.kicker(city)}</p>
      <h1 className="mt-2 font-display text-3xl font-extrabold tracking-tight text-ink md:text-4xl">{copy.h1(city)}</h1>
      <p className="mt-4 text-lg leading-relaxed text-ink-muted">{copy.intro(city)}</p>

      <div className="mt-8 flex flex-wrap gap-3">
        {copy.badges.map((b) => (
          <span key={b} className="rounded-full border border-ink/10 bg-white px-4 py-2 text-sm font-semibold text-ink shadow-card">{b}</span>
        ))}
      </div>

      <div className="mt-10 rounded-2xl border border-sitter/20 bg-sitter-light/60 p-6">
        <h2 className="font-display text-xl font-extrabold text-ink">{copy.localTitle(city)}</h2>
        <p className="mt-2 text-sm leading-relaxed text-ink-muted">{city.local}</p>
      </div>

      <h2 className="mt-14 font-display text-2xl font-extrabold text-ink">{copy.howTitle}</h2>
      <ol className="mt-6 space-y-4">
        {copy.steps.map((s, i) => (
          <li key={s.t} className="flex gap-5 rounded-2xl border border-ink/5 bg-white p-6 shadow-card">
            <div className="grid h-12 w-12 shrink-0 place-items-center rounded-2xl bg-sitter-light text-lg font-extrabold text-sitter-dark">{i + 1}</div>
            <div>
              <h3 className="text-base font-bold text-ink">{s.t}</h3>
              <p className="mt-1.5 text-sm leading-relaxed text-ink-muted">{s.p}</p>
            </div>
          </li>
        ))}
      </ol>

      <h2 className="mt-14 font-display text-2xl font-extrabold text-ink">{copy.faqTitle}</h2>
      <div className="mt-6 space-y-4">
        {faq.map((f) => (
          <div key={f.q} className="rounded-2xl border border-ink/5 bg-white p-5 shadow-card">
            <h3 className="font-bold text-ink">{f.q}</h3>
            <p className="mt-2 text-sm leading-relaxed text-ink-muted">{f.a}</p>
          </div>
        ))}
      </div>

      <div className="mt-14 rounded-3xl bg-sitter-light p-8 text-center">
        <h2 className="font-display text-2xl font-extrabold text-ink">{copy.ctaTitle(city)}</h2>
        <p className="mx-auto mt-2 max-w-md text-sm text-ink-muted">{copy.ctaText(city)}</p>
        <Link href="/download" className="mt-5 inline-block rounded-full bg-sitter px-7 py-3 text-sm font-bold text-white">{copy.ctaBtn}</Link>
      </div>
    </div>
  );
}

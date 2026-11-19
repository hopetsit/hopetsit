import type { Metadata } from "next";
import Image from "next/image";
import Link from "@/components/SiteLink";

// 18/11/2026 (GUS, mercredi) — règle de Daniel du 01/11 : chaque semaine un article neuf avec
// sa propre image en ko + ja. Sujet choisi par la DEMANDE mesurée (Search Console, Corée, 28 j) :
// « 강아지 맡기는 비용 » (11e place), « 강아지 맡길 곳 » (19e), « 애견호텔 » (26e) — aucune page ne
// répond à la question du prix. AUCUN prix ni chiffre inventé : l'article explique ce qui fait
// varier le prix et comment comparer deux devis. Relié au pilier /pet-sitting-korea/seoul, au
// guide « 강아지 맡기는 곳 » et à la page de recrutement.
const URL = "https://www.hopetsit.com/blog/seoul-dog-boarding-cost";
const IMG = "https://www.hopetsit.com/blog/seoul-dog-boarding-cost.jpg";
const TITLE = "강아지 맡기는 비용, 무엇으로 정해질까 : 서울에서 견적 비교하는 법";
const DESCRIPTION =
  "강아지 맡기는 비용은 왜 곳마다 다를까요? 애견호텔·위탁·방문 펫시터의 요금이 정해지는 기준, 추가 요금이 붙는 경우, 서울에서 견적을 제대로 비교하는 법과 비용을 줄이는 현실적인 방법을 정리했습니다.";
const HEADLINE = "강아지 맡기는 비용, 무엇으로 정해질까 : 서울에서 견적 비교하는 법";
const COVER_ALT = "강아지 사진, 강아지 맡기는 비용 가이드 표지";

export const metadata: Metadata = {
  title: TITLE,
  description: DESCRIPTION,
  alternates: { canonical: URL },
  openGraph: {
    title: TITLE,
    description: DESCRIPTION,
    url: URL,
    type: "article",
    locale: "ko_KR",
    siteName: "HoPetSit",
    images: [{ url: IMG, width: 1200, height: 630, alt: COVER_ALT }],
  },
};

const FAQ = [
  {
    q: "강아지 맡기는 비용은 보통 얼마인가요?",
    a: "정해진 금액은 없습니다. 기간, 강아지 크기와 수, 맡기는 방식(애견호텔, 펫시터 집 위탁, 방문 돌봄), 산책 횟수, 시기에 따라 달라집니다. 그래서 금액 하나만 보기보다 같은 조건으로 여러 곳의 견적을 받아 비교하는 것이 가장 정확합니다.",
  },
  {
    q: "가장 싼 곳을 고르면 안 되나요?",
    a: "가격만으로 고르면 나중에 추가 요금이 붙거나, 강아지가 혼자 있는 시간이 길어질 수 있습니다. 총액에 무엇이 포함되어 있는지, 밤에 누가 곁에 있는지, 산책은 몇 번 하는지를 함께 보고 고르세요.",
  },
  {
    q: "HoPetSit에서는 비용을 어떻게 확인하나요?",
    a: "요청을 올리는 것은 무료입니다. 근처 펫시터가 각자 정한 요금으로 답장하고, 보호자는 확정하기 전에 총액을 먼저 확인합니다. 결제는 안전하게 보관되었다가 돌봄이 끝난 뒤 펫시터에게 전달됩니다.",
  },
  {
    q: "명절이나 연말에는 더 비싼가요?",
    a: "맡기려는 보호자가 한꺼번에 몰리는 시기에는 요금이 달라지는 곳이 있고, 무엇보다 자리가 빨리 찹니다. 일정이 정해지면 바로 문의해서 그 날짜의 요금과 예약 가능 여부를 확인하세요.",
  },
];

const FACTORS = [
  {
    t: "맡기는 방식",
    d: "애견호텔은 시설 이용료, 펫시터 집 위탁은 하루 단위 돌봄, 방문 펫시터는 방문 횟수와 머무는 시간을 기준으로 요금을 정하는 경우가 많습니다. 기준이 서로 달라서 금액만 나란히 놓고 비교하기 어렵습니다.",
  },
  {
    t: "기간과 시간대",
    d: "하루인지 일주일인지, 낮 동안만인지 밤까지 포함인지에 따라 달라집니다. 맡기는 시간과 데려오는 시간을 어떻게 계산하는지(하루 단위인지, 시간 단위인지)도 곳마다 다릅니다.",
  },
  {
    t: "강아지 크기와 마릿수",
    d: "소형견, 중형견, 대형견으로 요금을 나누는 곳이 많습니다. 두 마리를 함께 맡길 때 두 번째 강아지 요금을 다르게 받는지도 확인해 보세요.",
  },
  {
    t: "손이 더 가는 돌봄",
    d: "약 먹이기, 노견 돌봄, 어린 강아지 배변 훈련, 분리불안처럼 사람이 더 오래 곁에 있어야 하는 경우에는 요금이 달라질 수 있습니다. 숨기지 말고 처음부터 알려야 정확한 견적이 나옵니다.",
  },
];

const EXTRAS = [
  "산책 : 기본 요금에 포함인지, 횟수와 시간은 얼마인지.",
  "픽업·데려다주기 : 집까지 와 주는지, 따로 요금이 있는지.",
  "목욕·빗질·발 닦기 같은 관리.",
  "사료와 간식 : 보호자가 챙겨 가는지, 그곳에서 제공하는지.",
  "늦은 체크아웃이나 일정 변경, 취소했을 때의 규정.",
  "명절·연휴 같은 성수기 요금.",
];

const COMPARE = [
  "같은 조건으로 물어보세요 : 날짜, 맡기는 시간과 데려오는 시간, 강아지 크기, 원하는 산책 횟수를 똑같이 알려야 비교가 됩니다.",
  "총액을 받아 두세요 : 하루 요금이 아니라 전체 기간의 총액과 그 안에 포함된 내용을 글로 확인합니다.",
  "강아지가 혼자 있는 시간을 물어보세요 : 금액이 비슷하다면 사람이 곁에 있는 시간이 긴 쪽이 강아지에게 더 편합니다.",
  "소식을 어떻게 받는지 확인하세요 : 사진과 메시지를 얼마나 자주 보내 주는지는 요금표에 나오지 않지만 마음이 놓이는 정도가 크게 다릅니다.",
];

const SAVE = [
  "일찍 알아보기 : 날짜가 정해지면 바로 문의하면 고를 수 있는 곳이 많고, 급하게 비싼 곳을 고르는 일을 피할 수 있습니다.",
  "집 근처에서 찾기 : 가까우면 픽업 요금이나 이동 시간이 줄고, 급한 일이 생겨도 대처가 쉽습니다.",
  "필요한 것만 부탁하기 : 낮에만 집을 비운다면 숙박 대신 방문 산책이나 낮 돌봄으로 충분할 수 있습니다.",
  "같은 펫시터에게 꾸준히 맡기기 : 강아지가 익숙해져서 적응 시간이 줄고, 매번 처음부터 설명할 필요가 없습니다.",
];

export default function ArticleSeoulDogBoardingCost() {
  const jsonLd = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "Article",
        headline: HEADLINE,
        description: DESCRIPTION,
        inLanguage: "ko-KR",
        mainEntityOfPage: URL,
        datePublished: "2026-11-18",
        image: { "@type": "ImageObject", url: IMG, width: 1200, height: 630 },
        author: { "@type": "Organization", name: "HoPetSit" },
        publisher: {
          "@type": "Organization",
          name: "HoPetSit",
          url: "https://www.hopetsit.com",
          logo: { "@type": "ImageObject", url: "https://www.hopetsit.com/logo.png" },
        },
      },
      {
        "@type": "FAQPage",
        mainEntity: FAQ.map((f) => ({
          "@type": "Question",
          name: f.q,
          acceptedAnswer: { "@type": "Answer", text: f.a },
        })),
      },
    ],
  };

  return (
    <div className="mx-auto max-w-3xl break-keep px-4 py-16 md:py-24">
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }} />
      <p className="text-sm font-semibold text-owner">생활 가이드 · 서울 · 강아지</p>
      <h1 className="mt-2 font-display text-3xl font-extrabold tracking-tight text-ink md:text-4xl">
        강아지 맡기는 비용, 무엇으로 정해질까 : 서울에서 견적 비교하는 법
      </h1>
      <Image
        src="/blog/seoul-dog-boarding-cost.jpg"
        alt={COVER_ALT}
        width={1200}
        height={630}
        priority
        sizes="(max-width: 768px) 100vw, 768px"
        className="mt-6 h-auto w-full rounded-2xl"
      />
      <p className="mt-4 text-lg leading-relaxed text-ink-muted">
        여행이나 출장 날짜가 잡히면 가장 먼저 드는 생각이 &ldquo;강아지 맡기는 비용이 얼마나 들까?&rdquo;
        입니다. 그런데 막상 알아보면 곳마다 금액도, 계산하는 방식도 달라서 비교하기가 쉽지 않습니다. 이
        글에서는 금액을 나열하는 대신, 비용이 무엇으로 정해지는지와 서울에서 견적을 제대로 비교하는 법을
        정리했습니다. 기준을 알고 나면 우리 강아지에게 맞는 곳을 훨씬 쉽게 고를 수 있습니다.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        강아지 맡기는 비용을 정하는 네 가지
      </h2>
      <div className="mt-6 grid gap-4 md:grid-cols-2">
        {FACTORS.map((f) => (
          <div key={f.t} className="rounded-2xl border border-ink/5 bg-white p-5 shadow-card">
            <h3 className="font-bold text-ink">{f.t}</h3>
            <p className="mt-2 text-sm leading-relaxed text-ink-muted">{f.d}</p>
          </div>
        ))}
      </div>
      <p className="mt-6 leading-relaxed text-ink-muted">
        세 가지 방식이 각각 어떤 강아지에게 맞는지는{" "}
        <Link href="/blog/seoul-dog-boarding-guide" className="font-semibold text-owner underline">
          서울 강아지 맡기는 곳 : 애견호텔·위탁·방문 펫시터 비교
        </Link>
        에서 자세히 다뤘습니다. 방식을 먼저 정하고 비용을 비교하면 헷갈리지 않습니다.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        기본 요금에 포함되지 않을 수 있는 것
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        처음 들은 금액과 마지막에 내는 금액이 다른 이유는 대부분 추가 항목 때문입니다. 문의할 때 아래
        항목이 기본 요금에 들어 있는지 하나씩 물어보세요.
      </p>
      <ul className="mt-4 space-y-2">
        {EXTRAS.map((t) => (
          <li key={t} className="flex gap-2 leading-relaxed text-ink-muted">
            <span aria-hidden="true" className="mt-2.5 h-1.5 w-1.5 shrink-0 rounded-full bg-owner" />
            <span>{t}</span>
          </li>
        ))}
      </ul>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        견적을 제대로 비교하는 법
      </h2>
      <ul className="mt-4 space-y-2">
        {COMPARE.map((t) => (
          <li key={t} className="flex gap-2 leading-relaxed text-ink-muted">
            <span aria-hidden="true" className="mt-2.5 h-1.5 w-1.5 shrink-0 rounded-full bg-owner" />
            <span>{t}</span>
          </li>
        ))}
      </ul>
      <p className="mt-4 leading-relaxed text-ink-muted">
        가장 낮은 금액이 항상 가장 좋은 선택은 아닙니다. 강아지가 밥을 잘 먹고, 산책을 충분히 하고,
        편하게 잠들 수 있는지가 결국 그 비용의 가치를 정합니다. 처음 맡기는 곳이라면 긴 여행 전에
        반나절이나 하루짜리 돌봄을 먼저 부탁해 보는 것도 좋은 방법입니다. 적은 비용으로 강아지와
        펫시터가 잘 맞는지 미리 확인할 수 있습니다.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        비용을 줄이는 현실적인 방법
      </h2>
      <ul className="mt-4 space-y-2">
        {SAVE.map((t) => (
          <li key={t} className="flex gap-2 leading-relaxed text-ink-muted">
            <span aria-hidden="true" className="mt-2.5 h-1.5 w-1.5 shrink-0 rounded-full bg-owner" />
            <span>{t}</span>
          </li>
        ))}
      </ul>
      <p className="mt-4 leading-relaxed text-ink-muted">
        매일의 산책만 도움이 필요하다면{" "}
        <Link href="/blog/seoul-pet-sitter-guide" className="font-semibold text-owner underline">
          서울 반려견 산책·펫시터 가이드
        </Link>
        를 참고해 보세요.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        HoPetSit에서는 확정 전에 총액을 먼저 봅니다
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        HoPetSit에서는 무료로 요청을 올리면 근처의 펫시터와 산책 도우미가 각자 정한 요금으로 답장합니다.
        날짜, 위탁인지 방문인지, 산책 횟수는 요청을 올릴 때 직접 정하기 때문에, 받은 답장들을 같은 조건으로
        비교할 수 있습니다. 확정하기 전에 총액을 먼저 확인하고, 결제는 안전하게 보관되었다가 돌봄이 끝난
        뒤 펫시터에게 전달됩니다. 집과 가까운 곳에서 찾고 싶다면{" "}
        <Link href="/pet-sitting-korea/seoul#districts" className="font-semibold text-owner underline">
          서울 25개 구별 정보
        </Link>
        에서 내가 사는 구를 먼저 확인해 보세요.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">자주 묻는 질문</h2>
      <div className="mt-6 space-y-4">
        {FAQ.map((f) => (
          <div key={f.q} className="rounded-2xl border border-ink/5 bg-white p-5 shadow-card">
            <h3 className="font-bold text-ink">{f.q}</h3>
            <p className="mt-2 text-sm leading-relaxed text-ink-muted">{f.a}</p>
          </div>
        ))}
      </div>

      <div className="mt-14 rounded-3xl bg-owner-light p-8 text-center">
        <h2 className="font-display text-2xl font-extrabold text-ink">같은 조건으로 요금을 비교해 보세요</h2>
        <p className="mx-auto mt-2 max-w-md text-sm text-ink-muted">
          요청은 무료입니다. 근처 펫시터의 답장을 받아 보고, 총액을 확인한 뒤에 정하면 됩니다.
        </p>
        <Link
          href="/#publier"
          className="mt-5 inline-block rounded-full bg-owner px-7 py-3 text-sm font-bold text-white"
        >
          요청 올리기
        </Link>
        <p className="mt-4 text-sm font-bold">
          <Link href="/pet-sitter-korea/seoul" className="text-owner underline">
            서울에서 펫시터·산책 도우미로 활동하기 →
          </Link>
        </p>
      </div>
    </div>
  );
}

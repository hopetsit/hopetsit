import type { Metadata } from "next";
import Image from "next/image";
import Link from "@/components/SiteLink";

// 25/11/2026 (GUS, mercredi) — règle de Daniel du 01/11 : chaque semaine un article neuf avec
// sa propre image en ko + ja. Sujet choisi par la DEMANDE mesurée (Search Console, Corée, 28 j) :
// « 애견호텔 » (18 affichages, 25e place — la requête coréenne la plus vue), « 애견 호텔 서울 »
// (13e), « 애견 호텔 » (10e). Les 2 articles existants comparent les 3 modes de garde et expliquent
// le prix ; aucun n'explique COMMENT choisir un hôtel pour chien. AUCUN prix ni chiffre inventé.
// Relié au pilier /pet-sitting-korea/seoul, aux 2 guides « 강아지 맡기는 곳 / 비용 » et au recrutement.
const URL = "https://www.hopetsit.com/blog/seoul-dog-hotel-checklist";
const IMG = "https://www.hopetsit.com/blog/seoul-dog-hotel-checklist.jpg";
const TITLE = "애견호텔 고르는 법 : 서울에서 예약 전 확인할 체크리스트";
const DESCRIPTION =
  "애견호텔, 어디를 보고 골라야 할까요? 서울에서 애견호텔을 예약하기 전에 직접 가서 확인할 것, 꼭 물어볼 질문, 맡기기 전 준비물, 그리고 애견호텔이 잘 맞지 않는 강아지를 위한 다른 방법까지 정리했습니다.";
const HEADLINE = "애견호텔 고르는 법 : 서울에서 예약 전 확인할 체크리스트";
const COVER_ALT = "강아지 사진, 애견호텔 고르는 법 가이드 표지";

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
    q: "애견호텔은 얼마나 미리 예약해야 하나요?",
    a: "정해진 기준은 없지만, 명절과 연휴, 여름 휴가철처럼 맡기려는 보호자가 몰리는 시기에는 자리가 빨리 찹니다. 일정이 정해지면 바로 문의하고, 처음 가는 곳이라면 예약 전에 한 번 방문해 보는 시간까지 생각해 두세요.",
  },
  {
    q: "처음 맡기는데 강아지가 잘 지낼지 걱정돼요.",
    a: "긴 일정 전에 반나절이나 하루만 먼저 맡겨 보세요. 밥을 잘 먹었는지, 잠은 잘 잤는지, 집에 돌아와서 어떤 모습인지 보면 그곳이 우리 강아지에게 맞는지 알 수 있습니다.",
  },
  {
    q: "애견호텔이 맞지 않는 강아지도 있나요?",
    a: "있습니다. 낯선 강아지나 소리에 예민한 강아지, 노견, 분리불안이 있는 강아지는 여러 마리가 함께 지내는 환경이 힘들 수 있습니다. 이런 경우에는 한 가정에서 돌보는 위탁이나, 집으로 찾아오는 방문 펫시터가 더 편할 수 있습니다.",
  },
  {
    q: "HoPetSit은 애견호텔인가요?",
    a: "아닙니다. HoPetSit은 시설이 아니라, 보호자와 동네의 펫시터·산책 도우미를 이어 주는 서비스입니다. 무료로 요청을 올리면 근처 펫시터가 각자 정한 요금으로 답장하고, 확정하기 전에 총액을 먼저 확인할 수 있습니다.",
  },
];

const VISIT = [
  {
    t: "청결과 냄새",
    d: "문을 열었을 때의 냄새, 바닥과 켄넬의 상태, 물그릇이 깨끗한지를 봅니다. 사진으로는 알 수 없는 부분이라 직접 가 보는 것이 가장 확실합니다.",
  },
  {
    t: "지내는 공간",
    d: "강아지가 개별 공간에서 쉬는지, 여럿이 함께 지내는지, 크기나 성향에 따라 공간을 나누는지 확인하세요. 우리 강아지가 편하게 누울 만큼 넉넉한지도 봅니다.",
  },
  {
    t: "환기와 온도",
    d: "서울의 여름은 덥고 습하고 겨울은 건조하고 춥습니다. 냉난방과 환기가 밤에도 유지되는지 물어보세요.",
  },
  {
    t: "돌보는 사람",
    d: "강아지를 대하는 모습을 잠깐만 지켜봐도 많은 것이 보입니다. 이름을 불러 주는지, 겁먹은 강아지에게 어떻게 다가가는지 살펴보세요.",
  },
];

const QUESTIONS = [
  "밤에는 누가 곁에 있나요? 사람이 상주하는지, CCTV로만 확인하는지 물어보세요.",
  "산책은 하나요? 한다면 하루에 몇 번, 어디에서 하는지 확인합니다.",
  "다른 강아지와 함께 놀게 하나요? 원하지 않으면 따로 지낼 수 있는지도 물어보세요.",
  "예방접종 확인이 필요한가요? 필요한 서류를 미리 알아 두면 당일에 당황하지 않습니다.",
  "아프거나 다쳤을 때는 어떻게 하나요? 어느 동물병원으로 가는지, 보호자에게 언제 연락하는지 확인하세요.",
  "소식은 어떻게 받나요? 사진이나 영상을 얼마나 자주 보내 주는지 물어보세요.",
  "동물위탁관리업으로 등록된 곳인가요? 등록 여부는 믿고 맡길 수 있는지 판단하는 기본 정보입니다.",
  "총액에는 무엇이 포함되나요? 산책, 목욕, 픽업, 늦은 체크아웃, 취소 규정까지 글로 받아 두세요.",
];

const PACK = [
  "평소 먹던 사료 : 기간보다 조금 넉넉하게, 한 끼씩 나눠 담으면 편합니다.",
  "집 냄새가 나는 담요나 방석, 좋아하는 장난감 하나.",
  "먹는 약이 있다면 약과 먹이는 방법을 적은 메모.",
  "다니는 동물병원 이름과 연락처, 보호자 외에 연락할 수 있는 사람의 번호.",
  "알레르기, 무서워하는 것, 배변 습관처럼 꼭 알아야 할 내용.",
  "인식표가 달린 목줄이나 하네스.",
];

export default function ArticleSeoulDogHotelChecklist() {
  const jsonLd = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "Article",
        headline: HEADLINE,
        description: DESCRIPTION,
        inLanguage: "ko-KR",
        mainEntityOfPage: URL,
        datePublished: "2026-11-25",
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
        애견호텔 고르는 법 : 서울에서 예약 전 확인할 체크리스트
      </h1>
      <Image
        src="/blog/seoul-dog-hotel-checklist.jpg"
        alt={COVER_ALT}
        width={1200}
        height={630}
        priority
        sizes="(max-width: 768px) 100vw, 768px"
        className="mt-6 h-auto w-full rounded-2xl"
      />
      <p className="mt-4 text-lg leading-relaxed text-ink-muted">
        여행이나 출장, 명절 귀성을 앞두고 애견호텔을 검색하면 서울에는 고를 곳이 정말 많습니다. 그런데
        사진과 후기만 보고는 우리 강아지가 그곳에서 편하게 지낼 수 있을지 알기 어렵습니다. 이 글에서는
        애견호텔을 예약하기 전에 직접 가서 볼 것, 꼭 물어볼 질문, 맡기기 전에 챙길 것을 순서대로
        정리했습니다. 체크리스트처럼 하나씩 확인해 보세요.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        애견호텔, 먼저 직접 가서 볼 네 가지
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        예약 전에 방문이 가능한지 물어보세요. 강아지가 지내는 공간을 보여 주는 곳이라면 그것만으로도
        좋은 신호입니다. 가능하면 강아지와 함께 가서 반응을 살펴보는 것이 좋습니다.
      </p>
      <div className="mt-6 grid gap-4 md:grid-cols-2">
        {VISIT.map((f) => (
          <div key={f.t} className="rounded-2xl border border-ink/5 bg-white p-5 shadow-card">
            <h3 className="font-bold text-ink">{f.t}</h3>
            <p className="mt-2 text-sm leading-relaxed text-ink-muted">{f.d}</p>
          </div>
        ))}
      </div>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        예약 전에 꼭 물어볼 여덟 가지
      </h2>
      <ul className="mt-4 space-y-2">
        {QUESTIONS.map((t) => (
          <li key={t} className="flex gap-2 leading-relaxed text-ink-muted">
            <span aria-hidden="true" className="mt-2.5 h-1.5 w-1.5 shrink-0 rounded-full bg-owner" />
            <span>{t}</span>
          </li>
        ))}
      </ul>
      <p className="mt-4 leading-relaxed text-ink-muted">
        질문에 망설임 없이 구체적으로 답해 주는 곳이 믿을 만한 곳입니다. 요금이 어떻게 정해지는지, 견적을
        어떻게 비교하는지는{" "}
        <Link href="/blog/seoul-dog-boarding-cost" className="font-semibold text-owner underline">
          강아지 맡기는 비용, 무엇으로 정해질까
        </Link>
        에서 따로 다뤘습니다.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        맡기기 전에 챙길 것
      </h2>
      <ul className="mt-4 space-y-2">
        {PACK.map((t) => (
          <li key={t} className="flex gap-2 leading-relaxed text-ink-muted">
            <span aria-hidden="true" className="mt-2.5 h-1.5 w-1.5 shrink-0 rounded-full bg-owner" />
            <span>{t}</span>
          </li>
        ))}
      </ul>
      <p className="mt-4 leading-relaxed text-ink-muted">
        맡기는 날에는 평소처럼 산책을 하고, 헤어질 때는 길게 인사하지 않는 편이 강아지에게 덜 불안합니다.
        갑자기 사료를 바꾸면 배탈이 나기 쉬우니, 먹던 것을 그대로 가져가세요.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        데려온 뒤에 살펴볼 것
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        집에 돌아온 강아지가 하루 이틀 평소보다 많이 자는 것은 흔한 일입니다. 낯선 곳에서 긴장했다가
        풀리는 것이니 조용히 쉬게 해 주세요. 다만 밥을 계속 먹지 않거나, 설사와 구토가 이어지거나,
        기침을 하거나, 몸에 상처가 보이면 동물병원에 문의하는 것이 좋습니다. 맡긴 곳에도 지내는 동안
        어땠는지 물어보면 다음에 맡길 때 도움이 됩니다.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        애견호텔이 맞지 않는 강아지라면
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        모든 강아지가 애견호텔에서 편한 것은 아닙니다. 다른 강아지를 무서워하거나, 소리에 예민하거나,
        나이가 많아 익숙한 환경이 중요한 강아지에게는 여러 마리가 함께 지내는 곳이 부담이 될 수 있습니다.
        이럴 때는 펫시터 집에서 가족처럼 지내는 위탁이나, 펫시터가 집으로 찾아오는 방문 돌봄을 생각해
        보세요. 세 가지 방식의 차이는{" "}
        <Link href="/blog/seoul-dog-boarding-guide" className="font-semibold text-owner underline">
          서울 강아지 맡기는 곳 : 애견호텔·위탁·방문 펫시터 비교
        </Link>
        에 정리해 두었습니다.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        HoPetSit으로 동네 펫시터에게 물어보기
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        HoPetSit은 애견호텔이 아니라, 보호자와 동네의 펫시터·산책 도우미를 이어 주는 서비스입니다. 무료로
        요청을 올리면 근처 펫시터가 각자 정한 요금으로 답장하고, 메시지로 위에 적은 질문을 그대로 물어볼
        수 있습니다. 확정하기 전에 총액을 먼저 확인하고, 결제는 안전하게 보관되었다가 돌봄이 끝난 뒤
        펫시터에게 전달됩니다. 집과 가까운 곳에서 찾고 싶다면{" "}
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
        <h2 className="font-display text-2xl font-extrabold text-ink">우리 강아지에게 맞는 돌봄을 찾아보세요</h2>
        <p className="mx-auto mt-2 max-w-md text-sm text-ink-muted">
          요청은 무료입니다. 근처 펫시터의 답장을 받아 보고, 궁금한 것을 물어본 뒤에 정하면 됩니다.
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

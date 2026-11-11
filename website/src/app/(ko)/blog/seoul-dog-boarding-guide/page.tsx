import type { Metadata } from "next";
import Image from "next/image";
import Link from "@/components/SiteLink";

// 11/11/2026 (GUS, mercredi) — règle de Daniel du 01/11 : chaque semaine un article neuf avec
// sa propre image en ko + ja. Sujet choisi par la DEMANDE mesurée (Search Console, 90 j) :
// « 강아지 맡기는 곳 » (11e place, aucune page qui y répond vraiment), « 강아지 위탁 »,
// « 강아지 돌봄 ». Relié à la page pilier /pet-sitting-korea/seoul, aux 2 guides de Séoul et à
// la page de recrutement. Aucun prix, aucun chiffre inventé : chaque gardien fixe son tarif.
const URL = "https://www.hopetsit.com/blog/seoul-dog-boarding-guide";
const IMG = "https://www.hopetsit.com/blog/seoul-dog-boarding-guide.jpg";
const TITLE = "서울 강아지 맡기는 곳 : 애견호텔·위탁·방문 펫시터 비교";
const DESCRIPTION =
  "서울에서 강아지 맡기는 곳을 찾고 있나요? 애견호텔, 펫시터 집 위탁, 방문 펫시터의 차이와 우리 강아지에게 맞는 곳 고르는 법, 맡기기 전에 꼭 물어볼 질문과 챙길 준비물을 정리했습니다.";
const HEADLINE = "서울 강아지 맡기는 곳 : 애견호텔·위탁·방문 펫시터 비교와 고르는 법";
const COVER_ALT = "강아지 사진, 서울 강아지 맡기는 곳 가이드 표지";

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
    q: "처음 맡기는 강아지라면 어디가 좋을까요?",
    a: "처음이라면 낯선 곳에 오래 두기보다 짧은 돌봄부터 시작하는 것이 좋습니다. 반나절이나 하루짜리 돌봄을 먼저 부탁해 보고, 강아지가 그 사람과 잘 지내는지 확인한 뒤에 긴 여행을 맡기면 보호자도 강아지도 훨씬 편합니다.",
  },
  {
    q: "강아지 위탁 비용은 얼마인가요?",
    a: "정해진 가격은 없습니다. 기간, 강아지 수, 산책 횟수, 위탁인지 방문인지에 따라 달라집니다. HoPetSit에서는 펫시터가 각자 요금을 정하고, 보호자는 확정하기 전에 총액을 먼저 확인합니다.",
  },
  {
    q: "분리불안이 있는 강아지도 맡길 수 있나요?",
    a: "맡길 수 있지만 방식을 잘 골라야 합니다. 혼자 있는 시간이 긴 곳보다는 사람이 오래 곁에 있는 펫시터 집 위탁이나 우리 집에 머무는 돌봄이 잘 맞는 경우가 많습니다. 펫시터에게 분리불안이 있다는 사실과 평소에 도움이 되는 방법을 미리 꼭 알려 주세요.",
  },
  {
    q: "명절이나 연말에는 언제 예약해야 하나요?",
    a: "일정이 정해지는 대로 바로 요청을 올리는 것을 권합니다. 같은 시기에 맡기려는 보호자가 한꺼번에 늘어나기 때문에, 빨리 올릴수록 고를 수 있는 펫시터가 많아집니다.",
  },
];

const COMPARE = [
  {
    t: "애견호텔·애견유치원",
    d: "정해진 시설에 여러 강아지가 함께 지냅니다. 다른 강아지와 잘 어울리고 활동량이 많은 강아지에게 맞을 수 있습니다. 다만 밤에 사람이 곁에 있는지, 강아지끼리 어떻게 나눠 지내는지는 곳마다 달라서 직접 가서 확인해야 합니다.",
  },
  {
    t: "펫시터 집에 맡기는 위탁",
    d: "강아지가 펫시터의 집에서 가족처럼 지냅니다. 한 번에 돌보는 강아지가 적어 사람과 함께 있는 시간이 길고, 낯을 덜 가리는 강아지라면 금방 편안해집니다. 그 집에 다른 반려동물이 있는지, 산책은 어디로 가는지 미리 물어보세요.",
  },
  {
    t: "방문 펫시터 (우리 집 돌봄)",
    d: "강아지는 집에 그대로 있고 펫시터가 찾아와 밥, 물, 산책, 배변 정리를 해 줍니다. 노견이나 환경이 바뀌면 힘들어하는 강아지에게 부담이 적습니다. 오래 집을 비운다면 펫시터가 우리 집에 머무는 돌봄을 부탁할 수도 있습니다.",
  },
];

const QUESTIONS = [
  "밤에는 누가 강아지 곁에 있나요? 혼자 두는 시간이 있다면 얼마나 되나요?",
  "산책은 하루에 몇 번, 어디로 가나요? 목줄은 어떤 걸 쓰나요?",
  "다른 강아지나 고양이와 함께 지내게 되나요?",
  "강아지가 아프거나 밥을 안 먹으면 어떻게 연락해 주나요? 가까운 동물병원은 어디인가요?",
  "사진이나 소식은 얼마나 자주 보내 주나요?",
];

const BRING = [
  "평소 먹던 사료와 간식 : 갑자기 사료를 바꾸면 배탈이 나기 쉬우니 맡기는 기간보다 넉넉하게 챙겨 주세요.",
  "익숙한 냄새가 나는 담요나 방석, 좋아하는 장난감.",
  "목줄·하네스와 인식표 : 서울에서는 반려견 동물등록이 의무이고, 공공장소에서는 목줄을 해야 합니다. 등록번호와 보호자 연락처를 펫시터에게도 알려 주세요.",
  "건강 정보 : 먹는 약과 먹이는 방법, 예방접종 기록, 알레르기, 다니는 동물병원 연락처.",
  "생활 메모 : 밥 시간과 양, 산책 습관, 무서워하는 것(오토바이, 큰 개, 천둥 등), 배변 신호.",
];

export default function ArticleSeoulDogBoardingGuide() {
  const jsonLd = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "Article",
        headline: HEADLINE,
        description: DESCRIPTION,
        inLanguage: "ko-KR",
        mainEntityOfPage: URL,
        datePublished: "2026-11-11",
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
        서울 강아지 맡기는 곳 : 애견호텔·위탁·방문 펫시터 비교와 고르는 법
      </h1>
      <Image
        src="/blog/seoul-dog-boarding-guide.jpg"
        alt={COVER_ALT}
        width={1200}
        height={630}
        priority
        sizes="(max-width: 768px) 100vw, 768px"
        className="mt-6 h-auto w-full rounded-2xl"
      />
      <p className="mt-4 text-lg leading-relaxed text-ink-muted">
        출장, 여행, 명절 귀성, 갑작스러운 입원까지. 강아지와 사는 사람이라면 언젠가 한 번은 &ldquo;우리
        강아지를 어디에 맡기지?&rdquo; 하는 순간을 만납니다. 서울에는 애견호텔부터 펫시터 집 위탁, 집으로
        찾아오는 방문 펫시터까지 선택지가 많지만, 그만큼 무엇이 우리 강아지에게 맞는지 고르기가 어렵습니다.
        이 글에서는 세 가지 방식의 차이와, 맡기기 전에 꼭 확인할 것들을 정리했습니다.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        강아지 맡기는 곳, 세 가지 방식 비교
      </h2>
      <div className="mt-6 grid gap-4 md:grid-cols-3">
        {COMPARE.map((f) => (
          <div key={f.t} className="rounded-2xl border border-ink/5 bg-white p-5 shadow-card">
            <h3 className="font-bold text-ink">{f.t}</h3>
            <p className="mt-2 text-sm leading-relaxed text-ink-muted">{f.d}</p>
          </div>
        ))}
      </div>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        우리 강아지에게 맞는 곳은 성격이 정해 줍니다
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        가장 좋은 곳은 &lsquo;가장 유명한 곳&rsquo;이 아니라 우리 강아지가 편하게 쉴 수 있는 곳입니다.
        다른 강아지를 보면 반가워서 꼬리를 흔드는 강아지라면 여러 강아지와 어울리는 환경도 즐거울 수
        있습니다. 반대로 낯선 강아지에게 짖거나 겁을 먹는 강아지, 소리에 예민한 강아지라면 한 집에서
        조용히 지내는 위탁이나 집에서 받는 방문 돌봄이 더 잘 맞습니다.
      </p>
      <p className="mt-4 leading-relaxed text-ink-muted">
        나이도 중요합니다. 어린 강아지는 배변 훈련과 규칙적인 생활이 이어져야 하고, 노견은 계단,
        미끄러운 바닥, 약 먹는 시간 같은 작은 것들이 컨디션을 좌우합니다. 이런 경우에는 사람이 오래
        곁에 있는 방식을 고르고, 펫시터에게 평소 생활을 최대한 자세히 알려 주는 것이 좋습니다. 산책을
        중심으로 한 돌봄이 궁금하다면{" "}
        <Link href="/blog/seoul-pet-sitter-guide" className="font-semibold text-owner underline">
          서울 반려견 산책·펫시터 가이드
        </Link>
        도 함께 읽어 보세요.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        맡기기 전에 꼭 물어볼 질문
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        어디에 맡기든 같은 질문을 해 보면 차이가 잘 보입니다. 대답이 구체적일수록 믿을 만합니다.
      </p>
      <ul className="mt-4 space-y-2">
        {QUESTIONS.map((t) => (
          <li key={t} className="flex gap-2 leading-relaxed text-ink-muted">
            <span aria-hidden="true" className="mt-2.5 h-1.5 w-1.5 shrink-0 rounded-full bg-owner" />
            <span>{t}</span>
          </li>
        ))}
      </ul>
      <p className="mt-4 leading-relaxed text-ink-muted">
        가능하다면 맡기기 전에 한 번 직접 만나 보세요. 펫시터가 강아지에게 억지로 다가가지 않고 냄새를
        맡게 기다려 주는지, 사료와 산책 습관을 꼼꼼히 묻는지 보면 많은 것을 알 수 있습니다.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        맡길 때 챙겨 갈 것
      </h2>
      <ul className="mt-4 space-y-2">
        {BRING.map((t) => (
          <li key={t} className="flex gap-2 leading-relaxed text-ink-muted">
            <span aria-hidden="true" className="mt-2.5 h-1.5 w-1.5 shrink-0 rounded-full bg-owner" />
            <span>{t}</span>
          </li>
        ))}
      </ul>
      <p className="mt-4 leading-relaxed text-ink-muted">
        고양이도 함께 키운다면 고양이는 집에서 지내게 하는 경우가 많습니다. 자세한 내용은{" "}
        <Link href="/blog/seoul-cat-sitter-guide" className="font-semibold text-owner underline">
          서울 아파트 고양이 돌봄 가이드
        </Link>
        에 정리해 두었습니다.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        HoPetSit으로 우리 동네에서 맡길 곳 찾기
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        HoPetSit에서는 무료로 요청을 올리면 근처의 펫시터와 산책 도우미가 각자 정한 요금으로 답장합니다.
        위탁인지 방문인지, 날짜와 산책 횟수는 요청을 올릴 때 직접 정할 수 있습니다. 앱 채팅으로 사진과
        소식을 주고받고, 결제는 안전하게 보관되었다가 돌봄이 끝난 뒤 펫시터에게 전달됩니다. 집과 가까운
        곳에서 찾고 싶다면{" "}
        <Link href="/pet-sitting-korea/seoul#districts" className="font-semibold text-owner underline">
          서울 25개 구별 정보
        </Link>
        에서 내가 사는 구의 동물병원과 산책 장소도 함께 확인해 보세요.
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
        <h2 className="font-display text-2xl font-extrabold text-ink">우리 강아지 맡길 곳, 동네에서 찾아보세요</h2>
        <p className="mx-auto mt-2 max-w-md text-sm text-ink-muted">
          위탁, 방문 돌봄, 산책까지. 서울 25개 구 어디서나 무료로 요청을 올릴 수 있습니다.
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

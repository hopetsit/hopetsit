import type { Metadata } from "next";
import Link from "@/components/SiteLink";

// 31/10/2026 (GUS) — consigne de Daniel du 31/10 au soir : SEO sur 4 pôles (Paris + Europe,
// New York, Séoul, Tokyo) et un article par ville dans la langue de la ville. Article coréen
// pour Séoul, relié à la page pilier /pet-sitting-korea/seoul (section quartiers #districts)
// et à la page de recrutement /pet-sitter-korea/seoul. Aucun prix, aucun chiffre inventé :
// chaque gardien fixe son tarif dans l'app.
const URL = "https://www.hopetsit.com/blog/seoul-pet-sitter-guide";
const TITLE = "서울 반려견 산책·펫시터 가이드 : 동네에서 믿을 수 있는 돌봄 찾기";
const DESCRIPTION =
  "서울에서 반려견 산책이나 펫시터가 필요할 때 알아둘 것 : 돌봄 방식 4가지, 한강공원·서울숲 산책 요령, 반려동물 등록과 목줄 규칙, 명절 장기 외출 준비, 믿을 수 있는 펫시터 고르는 법.";
const HEADLINE = "서울 반려견 산책·펫시터 가이드 : 동네에서 믿을 수 있는 돌봄 찾기";

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
    images: [{ url: "https://www.hopetsit.com/og-image.png", width: 1200, height: 630, alt: "HoPetSit" }],
  },
};

const FAQ = [
  {
    q: "펫시터와 산책 도우미는 무엇이 다른가요?",
    a: "산책 도우미는 정해진 시간에 와서 강아지를 데리고 나갔다가 돌아오는 일만 합니다. 펫시터는 산책뿐 아니라 밥, 물, 약 챙기기, 방문 돌봄, 하룻밤 이상 맡기는 돌봄까지 맡습니다. 고양이 돌봄도 펫시터의 몫입니다.",
  },
  {
    q: "서울에서 펫시터 비용은 얼마인가요?",
    a: "정해진 가격은 없습니다. 산책인지 방문인지, 며칠인지, 반려동물이 몇 마리인지에 따라 달라집니다. HoPetSit에서는 펫시터가 각자 요금을 정하고, 보호자는 확정하기 전에 총액을 먼저 확인합니다.",
  },
  {
    q: "처음 맡기기 전에 펫시터를 만나볼 수 있나요?",
    a: "네, 꼭 만나보시길 권합니다. 앱 채팅으로 시간을 정해 집 근처 공원이나 집에서 강아지와 함께 짧게 만나보세요. 강아지가 낯을 가리는지, 펫시터가 어떻게 다가가는지 직접 볼 수 있습니다.",
  },
  {
    q: "산책을 제대로 했는지 어떻게 알 수 있나요?",
    a: "돌봄이 진행되는 동안 PawFollow GPS 기록으로 산책 경로를 지도에서 실시간으로 볼 수 있고, 앱 채팅으로 사진과 메시지를 주고받을 수 있습니다.",
  },
  {
    q: "일정이 바뀌어 취소해야 하면요?",
    a: "가능한 한 빨리 앱 채팅으로 펫시터에게 알려 주세요. HoPetSit에서는 돌봄 시작 72시간 전까지 무료로 취소할 수 있습니다.",
  },
];

const FORMULES = [
  {
    t: "펫시터 집에서 맡기기",
    d: "며칠 동안 강아지가 펫시터의 집에서 지냅니다. 주말 여행이나 명절처럼 집을 오래 비울 때 많이 찾는 방식이에요. 강아지가 혼자 있는 시간이 거의 없고, 산책 리듬도 평소처럼 유지됩니다.",
  },
  {
    t: "우리 집에서 돌봄",
    d: "펫시터가 보호자의 집으로 와서 지내거나 자고 갑니다. 강아지가 익숙한 방석, 익숙한 동네에서 그대로 지낼 수 있어 나이 든 강아지, 겁이 많은 강아지, 고양이와 함께 사는 집에 잘 맞습니다.",
  },
  {
    t: "방문 돌봄",
    d: "하루에 한두 번 펫시터가 들러 밥과 물을 챙기고, 배변 정리와 짧은 산책, 놀이를 해 줍니다. 혼자 있는 데 익숙한 성견이나 고양이의 짧은 외출에 적당하고, 어린 강아지에게는 맞지 않습니다.",
  },
  {
    t: "산책",
    d: "30분에서 1시간 정도의 산책입니다. 맞벌이나 1인 가구처럼 낮 동안 집이 비는 경우, 점심때 한 번 나가는 것만으로도 강아지의 하루가 크게 달라집니다.",
  },
];

const PARCS = [
  {
    t: "한강공원",
    d: "여의도, 반포, 뚝섬, 망원 등 한강을 따라 이어지는 공원은 서울에서 가장 쉽게 갈 수 있는 긴 산책로입니다. 자전거 도로와 겹치는 구간이 많으니 목줄을 짧게 잡고, 사람이 많은 주말 저녁에는 조용한 시간대를 고르세요.",
  },
  {
    t: "서울숲",
    d: "성수동 근처의 큰 공원으로, 숲길과 잔디가 있어 강아지와 걷기 좋습니다. 공원 안에도 반려견 출입이나 목줄 관련 안내가 있는 구역이 있으니 입구의 안내판을 먼저 확인하세요.",
  },
  {
    t: "올림픽공원",
    d: "송파구의 넓은 공원으로 평지가 많아 노견이나 소형견과 천천히 걷기에 좋습니다. 행사나 공연이 있는 날에는 붐빌 수 있어요.",
  },
  {
    t: "동네 공원과 반려견 놀이터",
    d: "마포, 성동, 강남 등 여러 구에 반려견 놀이터가 있습니다. 이용 시간, 등록 여부 확인, 대형견·소형견 구역 구분 같은 규칙이 곳곳마다 다르니 구청 안내를 확인하고 이용하세요.",
  },
];

export default function ArticleSeoulPetSitterGuide() {
  const jsonLd = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "Article",
        headline: HEADLINE,
        description: DESCRIPTION,
        inLanguage: "ko-KR",
        mainEntityOfPage: URL,
        datePublished: "2026-10-31",
        image: { "@type": "ImageObject", url: "https://www.hopetsit.com/og-image.png", width: 1200, height: 630 },
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
    <div className="mx-auto max-w-3xl px-4 py-16 md:py-24">
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }} />
      <p className="text-sm font-semibold text-owner">생활 가이드 · 서울</p>
      <h1 className="mt-2 font-display text-3xl font-extrabold tracking-tight text-ink md:text-4xl">
        서울 반려견 산책·펫시터 가이드 : 동네에서 믿을 수 있는 돌봄 찾기
      </h1>
      <p className="mt-4 text-lg leading-relaxed text-ink-muted">
        야근이 잦은 평일, 갑자기 잡힌 출장, 고향에 내려가는 명절. 서울에서 강아지와 사는 사람이라면
        누구나 한 번쯤 &ldquo;오늘은 누가 산책을 시켜 주지?&rdquo; 하고 고민합니다. 이 글에서는 서울에서
        펫시터나 산책 도우미를 찾을 때 알아두면 좋은 돌봄 방식, 산책 장소, 꼭 지켜야 할 규칙, 그리고
        믿을 수 있는 사람을 고르는 방법을 정리했습니다.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        펫시터는 무엇을 해 주나요?
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        펫시터는 보호자가 돌볼 수 없을 때 보호자 대신 반려동물을 챙기는 사람입니다. 애견호텔과 달리
        한 사람이 소수의 동물만 돌보기 때문에, 낯선 소리나 다른 개가 많은 환경에 예민한 강아지에게
        훨씬 편안한 선택이 될 수 있습니다.
      </p>
      <p className="mt-4 leading-relaxed text-ink-muted">
        하는 일은 보호자가 평소에 하던 그대로입니다. 정해진 시간에 밥을 주고, 깨끗한 물을 갈아 주고,
        산책과 놀이를 하고, 먹는 약이 있으면 챙깁니다. 그리고 그날그날 사진과 함께 소식을 전해
        주고, 이상한 점이 보이면 바로 보호자에게 연락하고 필요하면 동물병원에 데려갑니다.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        서울에서 많이 찾는 돌봄 방식 4가지
      </h2>
      <div className="mt-6 grid gap-4 md:grid-cols-2">
        {FORMULES.map((f) => (
          <div key={f.t} className="rounded-2xl border border-ink/5 bg-white p-5 shadow-card">
            <h3 className="font-bold text-ink">{f.t}</h3>
            <p className="mt-2 text-sm leading-relaxed text-ink-muted">{f.d}</p>
          </div>
        ))}
      </div>
      <p className="mt-6 leading-relaxed text-ink-muted">
        어떤 방식이 맞는지 모르겠다면 강아지의 나이와 성격, 그리고 집을 비우는 시간을 기준으로
        생각해 보세요. 반나절이면 산책이나 방문, 하루 이상이면 펫시터 집이나 우리 집에서의 돌봄이
        일반적입니다.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        서울의 산책 장소, 이렇게 고르세요
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        펫시터에게 맡길 때는 강아지가 평소에 다니던 길을 알려 주는 것이 가장 좋습니다. 익숙한 냄새와
        길은 낯선 사람과의 산책에서 오는 긴장을 크게 줄여 줍니다. 서울에서 산책 장소로 많이 찾는
        곳은 다음과 같습니다.
      </p>
      <div className="mt-6 grid gap-4 md:grid-cols-2">
        {PARCS.map((f) => (
          <div key={f.t} className="rounded-2xl border border-ink/5 bg-white p-5 shadow-card">
            <h3 className="font-bold text-ink">{f.t}</h3>
            <p className="mt-2 text-sm leading-relaxed text-ink-muted">{f.d}</p>
          </div>
        ))}
      </div>
      <p className="mt-6 leading-relaxed text-ink-muted">
        구마다 공원과 동물병원, 반려동물 용품점이 어디에 있는지는{" "}
        <Link href="/pet-sitting-korea/seoul#districts" className="font-semibold text-owner underline">
          서울 25개 구별 정보
        </Link>
        에서 동네별로 확인할 수 있습니다.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        펫시터에게 맡기기 전에 꼭 확인할 규칙
      </h2>
      <ul className="mt-4 space-y-2">
        {[
          "반려동물 등록 : 주택이나 준주택에서 기르는 생후 2개월 이상의 개는 관할 시·군·구에 등록해야 합니다. 등록 정보(내장칩 또는 외장 인식표)를 펫시터에게도 알려 주세요.",
          "목줄과 인식표 : 외출할 때는 목줄이나 가슴줄을 하고, 공용 공간에서는 줄을 짧게 잡아야 합니다. 맹견으로 분류되는 견종은 입마개 등 추가 의무가 있습니다.",
          "배변 처리 : 산책 중 배설물은 바로 치워야 합니다. 펫시터에게 배변 봉투를 넉넉히 챙겨 주세요.",
          "공동주택 생활 : 엘리베이터에서는 강아지를 안거나 줄을 짧게 잡는 것이 기본 예절입니다. 우리 집 돌봄이라면 관리실이나 이웃에게 미리 알려 두면 오해가 줄어듭니다.",
          "규칙은 바뀔 수 있으니, 최신 내용은 농림축산식품부와 구청 안내를 함께 확인하세요.",
        ].map((t) => (
          <li key={t} className="flex gap-2 leading-relaxed text-ink-muted">
            <span aria-hidden="true" className="mt-2.5 h-1.5 w-1.5 shrink-0 rounded-full bg-owner" />
            <span>{t}</span>
          </li>
        ))}
      </ul>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        계절과 명절에 따라 달라지는 준비
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        서울의 여름은 덥고 습합니다. 한낮의 아스팔트는 강아지 발바닥에 화상을 입힐 수 있으니, 여름
        산책은 이른 아침이나 해가 진 뒤로 부탁하세요. 겨울에는 한강 바람이 매섭고, 길에 뿌린
        제설제가 발바닥을 자극할 수 있습니다. 산책 후 발을 닦아 달라고 미리 말해 두면 좋습니다.
      </p>
      <p className="mt-4 leading-relaxed text-ink-muted">
        추석과 설날처럼 며칠씩 집을 비우는 연휴에는 펫시터를 찾는 사람이 한꺼번에 몰립니다. 날짜가
        정해지는 대로 일찍 요청을 올리고, 처음 맡기는 펫시터라면 연휴 전에 한 번 짧게 맡겨 보는 것도
        좋은 방법입니다.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        펫시터에게 건네줄 것 체크리스트
      </h2>
      <ul className="mt-4 space-y-2">
        {[
          "사료와 간식 : 평소 양과 시간, 금지 음식까지 적어 주세요.",
          "예방접종 수첩 : 종합백신, 광견병 접종 기록과 복용 중인 약.",
          "단골 동물병원과 가까운 24시 동물병원 연락처.",
          "집 열쇠나 도어락 비밀번호 전달 방법 : 직접 만나서 전달하고, 돌봄이 끝나면 비밀번호를 바꾸세요.",
          "강아지의 습관 : 무서워하는 것, 다른 개와의 관계, 산책 중 주워 먹는 버릇 등.",
        ].map((t) => (
          <li key={t} className="flex gap-2 leading-relaxed text-ink-muted">
            <span aria-hidden="true" className="mt-2.5 h-1.5 w-1.5 shrink-0 rounded-full bg-owner" />
            <span>{t}</span>
          </li>
        ))}
      </ul>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        HoPetSit으로 우리 동네 펫시터 찾기
      </h2>
      <ol className="mt-4 space-y-3">
        {[
          "요청을 무료로 올리세요 : 반려동물, 날짜, 원하는 돌봄 방식(맡기기, 방문, 산책)과 사는 구를 적으면 됩니다.",
          "가까운 펫시터와 산책 도우미가 요청을 보고 각자 정한 요금으로 답장합니다.",
          "프로필과 후기를 비교하고, 앱 채팅으로 이야기를 나눈 뒤 강아지와 함께 미리 만나 보세요.",
          "마음에 드는 펫시터를 골라 앱에서 결제합니다. 결제는 안전하게 보관되었다가 돌봄이 끝난 뒤 펫시터에게 전달됩니다.",
        ].map((t, i) => (
          <li key={t} className="flex gap-3 leading-relaxed text-ink-muted">
            <span className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-owner text-sm font-bold text-white">
              {i + 1}
            </span>
            <span>{t}</span>
          </li>
        ))}
      </ol>
      <p className="mt-6 leading-relaxed text-ink-muted">
        서울에서 강아지와 고양이를 돌보는 일을 하고 싶다면{" "}
        <Link href="/pet-sitter-korea/seoul" className="font-semibold text-owner underline">
          서울에서 펫시터로 활동하기
        </Link>
        를 읽어 보세요.
      </p>

      <p className="mt-4 leading-relaxed text-ink-muted">
        고양이와 함께 산다면{" "}
        <Link href="/blog/seoul-cat-sitter-guide" className="font-semibold text-owner underline">
          서울 아파트 고양이 돌봄 : 방문 캣시터와 탁묘 비교
        </Link>
        도 함께 읽어 보세요. 여행이나 출장으로 며칠 집을 비운다면{" "}
        <Link href="/blog/seoul-dog-boarding-guide" className="font-semibold text-owner underline">
          서울 강아지 맡기는 곳 : 애견호텔·위탁·방문 펫시터 비교
        </Link>
        에서 어디에 맡길지 고르는 법을 정리했습니다.
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
        <h2 className="font-display text-2xl font-extrabold text-ink">우리 동네 펫시터를 찾아보세요</h2>
        <p className="mx-auto mt-2 max-w-md text-sm text-ink-muted">
          맡기기, 방문 돌봄, 산책까지. 서울 25개 구 어디서나 요청을 올릴 수 있습니다.
        </p>
        <Link
          href="/#publier"
          className="mt-5 inline-block rounded-full bg-owner px-7 py-3 text-sm font-bold text-white"
        >
          요청 올리기
        </Link>
        <p className="mt-4 text-sm font-bold">
          <Link href="/pet-sitter-korea/seoul" className="text-owner underline">
            펫시터 되기 →
          </Link>
        </p>
      </div>
    </div>
  );
}

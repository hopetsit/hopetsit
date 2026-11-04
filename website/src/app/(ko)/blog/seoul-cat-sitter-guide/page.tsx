import type { Metadata } from "next";
import Image from "next/image";
import Link from "@/components/SiteLink";

// 04/11/2026 (GUS, mercredi) — règle de Daniel du 01/11 : chaque semaine un article neuf avec
// sa propre image en ko + ja. Sujet suivant de website/marketing/sujets_4poles.md (Séoul) :
// la garde du chat en appartement à Séoul (방문 돌봄 / 탁묘). Relié à la page pilier
// /pet-sitting-korea/seoul, au premier guide de Séoul et à la page de recrutement.
// Aucun prix, aucun chiffre inventé : chaque gardien fixe son tarif dans l'app.
const URL = "https://www.hopetsit.com/blog/seoul-cat-sitter-guide";
const IMG = "https://www.hopetsit.com/blog/seoul-cat-sitter-guide.jpg";
const TITLE = "서울 아파트 고양이 돌봄 : 방문 캣시터와 탁묘, 무엇이 맞을까";
const DESCRIPTION =
  "서울에서 집을 비울 때 고양이는 어떻게 맡길까요? 방문 캣시터와 탁묘(위탁)의 차이, 아파트·오피스텔에서 준비할 것, 화장실·물·창문 점검, 캣시터에게 남길 메모와 믿을 수 있는 사람 고르는 법.";
const HEADLINE = "서울 아파트 고양이 돌봄 : 방문 캣시터와 탁묘, 무엇이 맞을까";
const COVER_ALT = "고양이 사진, 서울 고양이 돌봄 가이드 표지";

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
    q: "고양이는 며칠까지 혼자 둘 수 있나요?",
    a: "건강한 성묘라도 사람이 하루에 한 번은 들여다보는 것이 좋습니다. 물그릇이 엎어지거나 화장실이 막히는 일, 갑자기 밥을 먹지 않는 일은 사람이 직접 봐야 알 수 있기 때문입니다. 자동급식기가 있어도 방문을 대신하지는 못합니다.",
  },
  {
    q: "방문 캣시터는 하루에 몇 번 오나요?",
    a: "보통 하루 한 번이고, 아기 고양이나 약을 먹는 고양이, 여러 마리가 사는 집이라면 하루 두 번을 부탁하는 경우가 많습니다. 횟수와 시간은 요청을 올릴 때 직접 정할 수 있습니다.",
  },
  {
    q: "캣시터 비용은 얼마인가요?",
    a: "정해진 가격은 없습니다. 방문 횟수, 기간, 고양이 수에 따라 달라집니다. HoPetSit에서는 캣시터가 각자 요금을 정하고, 보호자는 확정하기 전에 총액을 먼저 확인합니다.",
  },
  {
    q: "도어락 비밀번호를 알려 줘도 괜찮을까요?",
    a: "처음에는 직접 만나서 전달하고, 돌봄이 끝나면 비밀번호를 바꾸는 것을 권합니다. 임시 비밀번호 기능이 있는 도어락이라면 돌봄 기간에만 쓰는 번호를 따로 만들어 두면 더 안심할 수 있습니다.",
  },
];

const COMPARE = [
  {
    t: "방문 돌봄 (방문 캣시터)",
    d: "고양이는 집에 그대로 있고, 캣시터가 하루 한두 번 찾아와 밥과 물을 챙기고 화장실을 치우고 놀아 줍니다. 낯선 곳을 싫어하는 고양이에게 가장 부담이 적은 방법이라 고양이 돌봄에서 가장 많이 찾는 방식입니다.",
  },
  {
    t: "탁묘 (캣시터 집에 맡기기)",
    d: "고양이가 캣시터의 집에서 지냅니다. 사람과 함께 있는 시간이 길어 외로움을 많이 타는 고양이, 약을 자주 먹어야 하는 고양이에게 맞을 수 있습니다. 다만 이동과 새 환경에 적응하는 시간이 필요하고, 그 집에 다른 동물이 있는지 꼭 확인해야 합니다.",
  },
  {
    t: "우리 집에서 지내는 돌봄",
    d: "캣시터가 보호자의 집에 머물거나 자고 갑니다. 고양이는 익숙한 공간에서 지내면서도 사람이 오래 곁에 있어, 노묘나 여러 마리가 사는 집, 긴 출장에 잘 맞습니다.",
  },
];

const CHECK = [
  "화장실 : 모래를 넉넉히 채워 두고, 남은 모래 봉투가 어디 있는지 알려 주세요. 고양이마다 쓰는 모래가 다르니 평소 쓰던 것을 그대로 두는 것이 좋습니다.",
  "물 : 물그릇을 두세 곳에 나눠 두면 하나가 엎어져도 괜찮습니다. 정수기형 급수기를 쓴다면 필터 교체 방법도 적어 두세요.",
  "창문과 방충망 : 고층 아파트에서는 방묘창이나 방묘문이 제대로 잠겼는지 확인하고, 캣시터에게 창문을 열지 말아 달라고 미리 말해 두세요.",
  "숨는 곳 : 손님이 오면 숨는 고양이가 많습니다. 자주 숨는 곳(침대 밑, 옷장 안)을 알려 주면 캣시터가 고양이 상태를 확인하기 쉽습니다.",
  "위험한 것 : 백합 같은 꽃, 끈과 고무줄, 사람 약은 고양이 손이 닿지 않는 곳에 치워 두세요.",
  "난방과 냉방 : 겨울에 집을 비울 때 보일러를 완전히 끄지 말고, 여름에는 에어컨이나 환기 방법을 정해 두세요.",
];

const MEMO = [
  "사료와 간식 : 종류, 한 번에 주는 양, 시간. 습식 사료라면 남은 것을 언제 치울지도 적어 주세요.",
  "건강 정보 : 먹는 약, 예방접종 기록, 최근에 아팠던 일.",
  "단골 동물병원과 가까운 24시 동물병원 연락처.",
  "평소 모습 : 잘 먹는지, 화장실을 하루에 몇 번 쓰는지, 좋아하는 장난감과 싫어하는 것.",
  "관리실 연락처 : 아파트나 오피스텔이라면 출입 방법과 주차, 택배 보관 위치도 함께.",
];

export default function ArticleSeoulCatSitterGuide() {
  const jsonLd = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "Article",
        headline: HEADLINE,
        description: DESCRIPTION,
        inLanguage: "ko-KR",
        mainEntityOfPage: URL,
        datePublished: "2026-11-04",
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
    <div className="mx-auto max-w-3xl px-4 py-16 md:py-24">
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }} />
      <p className="text-sm font-semibold text-owner">생활 가이드 · 서울 · 고양이</p>
      <h1 className="mt-2 font-display text-3xl font-extrabold tracking-tight text-ink md:text-4xl">
        서울 아파트 고양이 돌봄 : 방문 캣시터와 탁묘, 무엇이 맞을까
      </h1>
      <Image
        src="/blog/seoul-cat-sitter-guide.jpg"
        alt={COVER_ALT}
        width={1200}
        height={630}
        priority
        sizes="(max-width: 768px) 100vw, 768px"
        className="mt-6 h-auto w-full rounded-2xl"
      />
      <p className="mt-4 text-lg leading-relaxed text-ink-muted">
        강아지는 산책 때문에라도 누군가에게 맡기지만, 고양이는 &ldquo;혼자서도 잘 지내니까&rdquo; 하고
        넘기기 쉽습니다. 하지만 2박 3일 출장이나 명절 귀성처럼 집을 비우는 날이 이어지면 이야기가
        달라집니다. 이 글에서는 서울의 아파트와 오피스텔에서 고양이를 키우는 보호자가 집을 비울 때
        고를 수 있는 돌봄 방식과, 맡기기 전에 집에서 준비할 것을 정리했습니다.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        고양이는 왜 &lsquo;집에서&rsquo; 돌보는 경우가 많을까요?
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        고양이는 사람보다 공간에 더 강하게 적응하는 동물입니다. 익숙한 냄새, 늘 앉던 창가, 늘 쓰던
        화장실이 고양이에게는 안정감의 전부입니다. 그래서 이동장에 넣어 낯선 곳으로 데려가는 것만으로도
        밥을 거르거나 숨어서 나오지 않는 고양이가 적지 않습니다.
      </p>
      <p className="mt-4 leading-relaxed text-ink-muted">
        그렇다고 혼자 두기만 해서는 안 됩니다. 물그릇이 엎어지거나, 화장실이 너무 더러워져 다른 곳에
        볼일을 보거나, 컨디션이 갑자기 나빠지는 일은 누군가 직접 들여다봐야 알 수 있습니다. 집에서
        지내게 하면서 사람이 찾아오는 방문 돌봄이 고양이에게 가장 많이 쓰이는 이유입니다.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        방문 돌봄, 탁묘, 우리 집 돌봄 비교
      </h2>
      <div className="mt-6 grid gap-4 md:grid-cols-3">
        {COMPARE.map((f) => (
          <div key={f.t} className="rounded-2xl border border-ink/5 bg-white p-5 shadow-card">
            <h3 className="font-bold text-ink">{f.t}</h3>
            <p className="mt-2 text-sm leading-relaxed text-ink-muted">{f.d}</p>
          </div>
        ))}
      </div>
      <p className="mt-6 leading-relaxed text-ink-muted">
        고르기 어렵다면 고양이의 성격부터 떠올려 보세요. 손님이 오면 숨는 고양이, 이동장을 보기만 해도
        우는 고양이라면 방문 돌봄이 맞습니다. 사람을 졸졸 따라다니고 혼자 있으면 우는 고양이라면 탁묘나
        우리 집 돌봄을 생각해 볼 만합니다. 강아지와 함께 사는 집이라면 산책까지 맡길 수 있는{" "}
        <Link href="/blog/seoul-pet-sitter-guide" className="font-semibold text-owner underline">
          서울 반려견 산책·펫시터 가이드
        </Link>
        도 함께 읽어 보세요.
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        아파트·오피스텔에서 집을 비우기 전에 점검할 것
      </h2>
      <ul className="mt-4 space-y-2">
        {CHECK.map((t) => (
          <li key={t} className="flex gap-2 leading-relaxed text-ink-muted">
            <span aria-hidden="true" className="mt-2.5 h-1.5 w-1.5 shrink-0 rounded-full bg-owner" />
            <span>{t}</span>
          </li>
        ))}
      </ul>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        캣시터에게 남길 메모
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        처음 오는 사람은 고양이의 &lsquo;평소&rsquo;를 모릅니다. 평소 모습을 알아야 무엇이 이상한지도 알 수
        있습니다. 한 장짜리 메모를 냉장고에 붙여 두거나 앱 채팅으로 미리 보내 두세요.
      </p>
      <ul className="mt-4 space-y-2">
        {MEMO.map((t) => (
          <li key={t} className="flex gap-2 leading-relaxed text-ink-muted">
            <span aria-hidden="true" className="mt-2.5 h-1.5 w-1.5 shrink-0 rounded-full bg-owner" />
            <span>{t}</span>
          </li>
        ))}
      </ul>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        믿을 수 있는 캣시터 고르는 법
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        방문 돌봄은 보호자가 없는 집에 다른 사람이 들어오는 일입니다. 그래서 고양이를 잘 다루는지만큼
        약속을 잘 지키는 사람인지가 중요합니다. 프로필에 고양이를 돌본 경험이 적혀 있는지, 후기에서
        &lsquo;사진을 자주 보내 줬다&rsquo;, &lsquo;시간을 잘 지켰다&rsquo; 같은 이야기가 있는지 살펴보세요.
      </p>
      <p className="mt-4 leading-relaxed text-ink-muted">
        맡기기 전에는 꼭 한 번 집에서 만나 보세요. 캣시터가 고양이에게 억지로 다가가지 않고 기다려
        주는지, 화장실과 사료 위치를 꼼꼼히 묻는지 보면 많은 것을 알 수 있습니다. 첫 돌봄이 긴 여행이라면
        그 전에 하루 이틀짜리 짧은 돌봄을 먼저 부탁해 보는 것도 좋은 방법입니다.
      </p>
      <p className="mt-4 leading-relaxed text-ink-muted">
        HoPetSit에서는 무료로 요청을 올리면 근처의 캣시터가 각자 정한 요금으로 답장합니다. 앱 채팅으로
        사진과 소식을 주고받을 수 있고, 결제는 안전하게 보관되었다가 돌봄이 끝난 뒤 캣시터에게
        전달됩니다. 내가 사는 구의 동물병원과 반려동물 용품점은{" "}
        <Link href="/pet-sitting-korea/seoul#districts" className="font-semibold text-owner underline">
          서울 25개 구별 정보
        </Link>
        에서 확인할 수 있습니다.
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
        <h2 className="font-display text-2xl font-extrabold text-ink">우리 동네 캣시터를 찾아보세요</h2>
        <p className="mx-auto mt-2 max-w-md text-sm text-ink-muted">
          방문 돌봄, 탁묘, 우리 집 돌봄까지. 서울 25개 구 어디서나 무료로 요청을 올릴 수 있습니다.
        </p>
        <Link
          href="/#publier"
          className="mt-5 inline-block rounded-full bg-owner px-7 py-3 text-sm font-bold text-white"
        >
          요청 올리기
        </Link>
        <p className="mt-4 text-sm font-bold">
          <Link href="/pet-sitter-korea/seoul" className="text-owner underline">
            서울에서 캣시터·펫시터로 활동하기 →
          </Link>
        </p>
      </div>
    </div>
  );
}

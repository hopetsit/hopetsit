import type { Metadata } from "next";
import Image from "next/image";
import Link from "@/components/SiteLink";

// 25/11/2026 (GUS, mercredi) — règle de Daniel du 01/11 : chaque semaine un article neuf avec
// sa propre image en ko + ja. Sujet choisi par la DEMANDE mesurée (Search Console, Japon, 28 j) :
// « 海外旅行中にペットを預けるなら、どのサービスがおすすめ？ » (10e place), « 老猫 長期預かり » et
// « 高齢猫 長期預かり » (7 affichages, 51e-95e place) — ces requêtes tombent aujourd'hui sur
// l'article du Nouvel An, qui ne parle ni de voyage à l'étranger ni de garde longue.
// Aucun prix, aucun chiffre inventé. Relié au pilier /pet-sitting-japan/tokyo, aux guides de
// Tokyo et à la page de recrutement.
const URL = "https://www.hopetsit.com/blog/tokyo-long-trip-pet-care";
const IMG = "https://www.hopetsit.com/blog/tokyo-long-trip-pet-care.jpg";
const TITLE = "海外旅行や長期出張でペットを預けるには : 東京での長期預かりの選び方";
const DESCRIPTION =
  "海外旅行や長期出張のあいだ、犬や猫をどこに預ける？ペットホテル、動物病院、訪問ペットシッター、シッター宅での預かりの違いと、高齢の猫・犬を長期で預けるときの注意点、出発前に決めておくことを東京の飼い主向けにまとめました。";
const HEADLINE = "海外旅行や長期出張でペットを預けるには : 東京での長期預かりの選び方";
const COVER_ALT = "犬の写真、海外旅行や長期出張でペットを預けるガイドの表紙";

export const metadata: Metadata = {
  title: TITLE,
  description: DESCRIPTION,
  alternates: { canonical: URL },
  openGraph: {
    title: TITLE,
    description: DESCRIPTION,
    url: URL,
    type: "article",
    locale: "ja_JP",
    siteName: "HoPetSit",
    images: [{ url: IMG, width: 1200, height: 630, alt: COVER_ALT }],
  },
};

const FAQ = [
  {
    q: "海外旅行中にペットを預けるなら、どのサービスがおすすめですか？",
    a: "ペットの性格と体調によって変わります。環境の変化が苦手な猫や高齢のペットには、家に来てもらう訪問ペットシッターが合うことが多く、人と過ごすのが好きな犬にはシッター宅での預かりやペットホテルが合うことがあります。持病がある場合は、まずかかりつけの動物病院に相談しましょう。",
  },
  {
    q: "高齢の猫を長期で預けても大丈夫ですか？",
    a: "一概には言えません。高齢の猫は環境の変化や移動が負担になりやすいので、住み慣れた家で毎日お世話をしてもらう方法を考える飼い主が多いです。出発前にかかりつけの獣医師に体調を診てもらい、留守中の過ごし方を相談してから決めると安心です。",
  },
  {
    q: "長期の場合、料金はどのくらいかかりますか？",
    a: "決まった金額はありません。日数、訪問の回数、ペットの頭数や大きさ、時期によって変わります。HoPetSitではシッターがそれぞれ料金を決め、飼い主は確定する前に合計金額を確認できます。同じ条件で複数の返事を比べるのがおすすめです。",
  },
  {
    q: "いつごろから探し始めればいいですか？",
    a: "日程が決まったら早めに動きましょう。長い期間を通して頼める人や施設は限られますし、出発前に顔合わせや短いお試しをしておく時間も必要です。連休や年末年始と重なる場合は、さらに余裕を持つと安心です。",
  },
];

const OPTIONS = [
  {
    t: "訪問ペットシッター",
    d: "ペットは住み慣れた家で過ごし、シッターが決めた時間に来てお世話をします。環境が変わらないので、猫や高齢のペット、移動が苦手な子に向いています。シッターがいない時間はペットだけで過ごすことになります。",
  },
  {
    t: "シッター宅での預かり",
    d: "家庭の中で、人のそばで過ごせます。ひとりの時間が苦手な犬に向いています。ほかの動物がいるか、散歩の回数、夜の過ごし方を事前に確認しましょう。",
  },
  {
    t: "ペットホテル",
    d: "スタッフがいて設備が整っています。過ごすスペース、散歩や運動の時間、夜間に人がいるかどうかは施設によって違うので、見学して確かめるのがおすすめです。",
  },
  {
    t: "動物病院での預かり",
    d: "持病がある、毎日の投薬や体調の見守りが必要、というペットには安心です。預かりをしているか、長期でも可能かは病院によって違うので、かかりつけの病院に聞いてみましょう。",
  },
];

const LONG = [
  "途中で担当が変わるかどうか : 同じ人が通して見てくれると、小さな変化に気づきやすくなります。",
  "フードや薬、トイレ用品の量 : 予定より帰りが遅れても足りるように、多めに用意しておきます。",
  "連絡の頻度と時差 : 写真やメッセージをいつ、どのくらい送ってもらうか。海外では時差があるので、返事が遅れることも伝えておきます。",
  "日本にいる緊急連絡先 : 自分に連絡がつかないときに、代わりに判断できる家族や友人を決めておきます。",
  "体調が悪くなったとき : どの動物病院に連れて行くか、どこまで任せるかを書いて渡しておきます。",
  "帰国が遅れた場合 : 飛行機の遅れや予定変更のときに延長できるかを、最初に確認しておきます。",
];

const SENIOR = [
  "出発前に、かかりつけの動物病院で体調を診てもらう。",
  "いつもの食事量、水を飲む量、トイレの回数をメモして渡す。変化に気づく目安になります。",
  "薬がある場合は、飲ませ方を実際に見せて、練習してもらう。",
  "段差や寒さなど、部屋の中で気をつけてほしい場所を伝える。",
  "寝床や毛布、使い慣れたトイレなど、いつもの物をそのまま使えるようにする。",
];

export default function ArticleTokyoLongTripPetCare() {
  const jsonLd = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "Article",
        headline: HEADLINE,
        description: DESCRIPTION,
        inLanguage: "ja-JP",
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
    <div className="mx-auto max-w-3xl px-4 py-16 md:py-24">
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }} />
      <p className="text-sm font-semibold text-owner">暮らしのガイド · 東京 · 犬と猫</p>
      <h1 className="mt-2 font-display text-3xl font-extrabold tracking-tight text-ink md:text-4xl">
        海外旅行や長期出張でペットを預けるには : 東京での長期預かりの選び方
      </h1>
      <Image
        src="/blog/tokyo-long-trip-pet-care.jpg"
        alt={COVER_ALT}
        width={1200}
        height={630}
        priority
        sizes="(max-width: 768px) 100vw, 768px"
        className="mt-6 h-auto w-full rounded-2xl"
      />
      <p className="mt-4 text-lg leading-relaxed text-ink-muted">
        海外旅行、長期の出張、入院や帰省。一泊二日なら何とかなっても、一週間、二週間と家を空けるとなると「そのあいだ、うちの子をどこに預けよう」と悩む飼い主は多いはずです。期間が長くなるほど、預け先の選び方と事前の準備が大切になります。この記事では、東京で犬や猫を長期で預けるときの選択肢と、高齢のペットの場合に気をつけたいこと、出発前に決めておくことをまとめました。
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        長期で預けるときの四つの選択肢
      </h2>
      <div className="mt-6 grid gap-4 md:grid-cols-2">
        {OPTIONS.map((f) => (
          <div key={f.t} className="rounded-2xl border border-ink/5 bg-white p-5 shadow-card">
            <h3 className="font-bold text-ink">{f.t}</h3>
            <p className="mt-2 text-sm leading-relaxed text-ink-muted">{f.d}</p>
          </div>
        ))}
      </div>
      <p className="mt-6 leading-relaxed text-ink-muted">
        どれが一番よいかは、ペットによって違います。迷ったときは「知らない場所でも落ち着けるか」「ひとりの時間が長くても平気か」「毎日の投薬や見守りが必要か」の三つで考えると決めやすくなります。猫の場合の訪問と預かりの違いは
        <Link href="/blog/tokyo-cat-home-visit-sitter" className="font-semibold text-owner underline">
          ペットシッターに家に来てもらう : 東京のマンションで猫の留守番
        </Link>
        で詳しく紹介しています。
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        期間が長いからこそ確認したいこと
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        数日の留守番と長期の預かりでは、考えておくことが変わります。頼む前に、次の点を預け先と話しておきましょう。
      </p>
      <ul className="mt-4 space-y-2">
        {LONG.map((t) => (
          <li key={t} className="flex gap-2 leading-relaxed text-ink-muted">
            <span aria-hidden="true" className="mt-2.5 h-1.5 w-1.5 shrink-0 rounded-full bg-owner" />
            <span>{t}</span>
          </li>
        ))}
      </ul>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        高齢の猫・犬を長期で預けるとき
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        年を重ねたペットは、環境の変化や移動が若いころより負担になりやすく、体調の変化も出やすくなります。そのため、住み慣れた家で毎日お世話をしてもらう方法や、医療の目が届く動物病院での預かりを考える飼い主が多いです。どちらが合うかは体調によるので、まずかかりつけの獣医師に相談しましょう。そのうえで、次の準備をしておくと安心です。
      </p>
      <ul className="mt-4 space-y-2">
        {SENIOR.map((t) => (
          <li key={t} className="flex gap-2 leading-relaxed text-ink-muted">
            <span aria-hidden="true" className="mt-2.5 h-1.5 w-1.5 shrink-0 rounded-full bg-owner" />
            <span>{t}</span>
          </li>
        ))}
      </ul>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        出発前にやっておきたいこと
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        長期で預ける前に、まず半日や一泊の短いお試しをしておきましょう。ごはんを食べたか、よく眠れたか、帰ってきたあとの様子はどうかを見れば、その預け先が合っているかが分かります。訪問シッターに頼む場合は、出発前に一度家に来てもらい、フードの場所やトイレの掃除の仕方、鍵の受け渡しを一緒に確認しておくと安心です。頼むときの基本は
        <Link href="/blog/tokyo-pet-sitter-guide" className="font-semibold text-owner underline">
          東京でペットシッターを頼むときのポイント
        </Link>
        にまとめています。出発が年末年始と重なるなら、
        <Link href="/blog/tokyo-new-year-pet-care" className="font-semibold text-owner underline">
          年末年始に犬・猫を預けるには
        </Link>
        もあわせて読んでおくと、準備の時期がわかります。
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        HoPetSitで長期のお世話を相談する
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        HoPetSitは施設ではなく、飼い主と近くのペットシッター・お散歩代行をつなぐサービスです。無料で依頼を出すと、近くのシッターがそれぞれ決めた料金で返事をくれます。日にちや、訪問か預かりかは依頼を出すときに自分で決められるので、長い期間でも同じ条件で返事を比べられます。確定する前に合計金額を確認でき、お支払いは安全に預かられ、お世話が終わってからシッターに渡されます。家から近いシッターを探したいときは、
        <Link href="/pet-sitting-japan/tokyo#districts" className="font-semibold text-owner underline">
          東京23区のエリア情報
        </Link>
        から住んでいる区を確認してみてください。
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">よくある質問</h2>
      <div className="mt-6 space-y-4">
        {FAQ.map((f) => (
          <div key={f.q} className="rounded-2xl border border-ink/5 bg-white p-5 shadow-card">
            <h3 className="font-bold text-ink">{f.q}</h3>
            <p className="mt-2 text-sm leading-relaxed text-ink-muted">{f.a}</p>
          </div>
        ))}
      </div>

      <div className="mt-14 rounded-3xl bg-owner-light p-8 text-center">
        <h2 className="font-display text-2xl font-extrabold text-ink">出発が決まったら、早めに相談してみましょう</h2>
        <p className="mx-auto mt-2 max-w-md text-sm text-ink-muted">
          依頼は無料です。近くのシッターからの返事を見て、気になることを聞いてから決められます。
        </p>
        <Link
          href="/#publier"
          className="mt-5 inline-block rounded-full bg-owner px-7 py-3 text-sm font-bold text-white"
        >
          依頼を出す
        </Link>
        <p className="mt-4 text-sm font-bold">
          <Link href="/pet-sitter-japan/tokyo" className="text-owner underline">
            東京でペットシッターとして活動する →
          </Link>
        </p>
      </div>
    </div>
  );
}

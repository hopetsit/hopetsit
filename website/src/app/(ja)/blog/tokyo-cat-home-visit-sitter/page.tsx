import type { Metadata } from "next";
import Image from "next/image";
import Link from "@/components/SiteLink";

// 18/11/2026 (GUS, mercredi) — règle de Daniel du 01/11 : chaque semaine un article neuf avec
// sa propre image en ko + ja. Sujet choisi par la DEMANDE mesurée (Search Console, Japon, 28 j) :
// « ペットシッター 家に来てもらう » (11e place), « cat sitting » (15 affichages, 8e), et sujet
// non coché de sujets_4poles.md (chat en appartement à Tokyo : visite ou garde ailleurs).
// Aucune page ne parlait du chat ni de la visite à domicile. Aucun prix, aucun chiffre inventé.
// Relié au pilier /pet-sitting-japan/tokyo, aux guides de Tokyo et à la page de recrutement.
const URL = "https://www.hopetsit.com/blog/tokyo-cat-home-visit-sitter";
const IMG = "https://www.hopetsit.com/blog/tokyo-cat-home-visit-sitter.jpg";
const TITLE = "ペットシッターに家に来てもらう : 東京のマンションで猫の留守番";
const DESCRIPTION =
  "出張や旅行のあいだ、猫はどうする？東京のマンションでペットシッターに家に来てもらう訪問型と、預かりの違いを比較。訪問でしてもらえること、鍵とオートロックの受け渡し、頼む前の準備をまとめました。";
const HEADLINE = "ペットシッターに家に来てもらう : 東京のマンションで猫の留守番、訪問と預かりの比較";
const COVER_ALT = "猫の写真、東京で猫の訪問ペットシッターを頼むガイドの表紙";

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
    q: "猫は何日くらい留守番できますか？",
    a: "猫の年齢や性格、健康状態によって違うので、一概には言えません。大切なのは、留守のあいだも毎日だれかがごはん・水・トイレと体調を確認することです。子猫や高齢の猫、持病のある猫は、訪問の回数を増やすか、かかりつけの獣医師に相談してから決めましょう。",
  },
  {
    q: "人見知りの猫でも訪問シッターを頼めますか？",
    a: "頼めます。猫は隠れたままでもかまいません。無理に触らず、ごはんの減り方やトイレの様子から体調を見てもらうよう伝えておきましょう。出発前に一度顔合わせをしておくと、猫も飼い主も安心です。",
  },
  {
    q: "鍵を預けるのが心配です。",
    a: "顔合わせのときに、鍵をいつ・どうやって渡して、いつ返してもらうかを決めておきましょう。プロフィールや口コミを確認し、訪問のたびに写真やメッセージで報告をもらうようにすると安心です。",
  },
  {
    q: "料金はどのくらいですか？",
    a: "決まった金額はありません。訪問の回数や時間、猫の頭数、時期によって変わります。HoPetSitではシッターがそれぞれ料金を決め、飼い主は確定する前に合計金額を確認できます。",
  },
];

const COMPARE = [
  {
    t: "訪問（家に来てもらう）",
    d: "猫は住み慣れた部屋で過ごし、シッターが決めた時間に来てお世話をします。環境が変わらないので、縄張り意識の強い猫や移動が苦手な猫に向いています。シッターがいない時間は猫だけで過ごすことになります。",
  },
  {
    t: "預かり（シッターの家・ペットホテル）",
    d: "人の目が届く時間が長くなります。投薬や見守りが必要な猫には安心ですが、キャリーでの移動や知らない場所のにおいがストレスになる猫もいます。ほかの動物がいるかどうかも事前に確認しましょう。",
  },
];

const VISIT = [
  "ごはんと水の交換 : いつものフードを、いつもの量で。食べ残しの量も見てもらいます。",
  "トイレの掃除 : 回数や状態は体調を知る大切な手がかりです。",
  "遊びと声かけ : 猫のペースに合わせて。隠れている猫には無理をしません。",
  "体調のチェック : 食欲、吐いたあと、目や鼻の様子、いつもと違う行動がないか。",
  "写真やメッセージでの報告 : 訪問のたびに様子を知らせてもらうと安心です。",
  "部屋の確認 : 室温、窓や玄関の戸締まり、倒れているものがないか。",
];

const MANSION = [
  "オートロックと鍵 : エントランスの入り方、鍵の受け渡しと返却の方法を顔合わせのときに決めておきます。",
  "管理規約 : 留守中に飼い主以外が出入りする場合、管理人や管理会社への連絡が必要かどうか、あらかじめ確認しておきましょう。",
  "脱走防止 : 玄関を開ける前に猫の居場所を確認してもらう、ベランダや窓は開けない、といったルールを伝えます。",
  "室温 : エアコンの設定と、リモコンの場所を伝えておきます。夏も冬も、留守中の室温は猫の体調に直結します。",
  "ごみとにおい : トイレ砂やごみをどこにまとめておくか、収集日に出す必要があるかを決めておきます。",
];

const PREP = [
  "フードとトイレ砂は、留守の日数より多めに用意する。",
  "ごはんの量と時間、好きな遊び、苦手なこと（掃除機の音、抱っこなど）を書いたメモ。",
  "かかりつけの動物病院の名前と連絡先、持病や飲んでいる薬。",
  "キャリーケースの置き場所 : 万一のとき、すぐに病院へ連れて行けるように。",
  "緊急時の連絡先 : 自分のほかに、近くにいる家族や友人の連絡先も。",
];

export default function ArticleTokyoCatHomeVisitSitter() {
  const jsonLd = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "Article",
        headline: HEADLINE,
        description: DESCRIPTION,
        inLanguage: "ja-JP",
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
    <div className="mx-auto max-w-3xl px-4 py-16 md:py-24">
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }} />
      <p className="text-sm font-semibold text-owner">暮らしのガイド · 東京 · 猫</p>
      <h1 className="mt-2 font-display text-3xl font-extrabold tracking-tight text-ink md:text-4xl">
        ペットシッターに家に来てもらう : 東京のマンションで猫の留守番、訪問と預かりの比較
      </h1>
      <Image
        src="/blog/tokyo-cat-home-visit-sitter.jpg"
        alt={COVER_ALT}
        width={1200}
        height={630}
        priority
        sizes="(max-width: 768px) 100vw, 768px"
        className="mt-6 h-auto w-full rounded-2xl"
      />
      <p className="mt-4 text-lg leading-relaxed text-ink-muted">
        出張、帰省、旅行、急な入院。家を空けることになったとき、猫と暮らす人がまず悩むのが「留守のあいだ、この子をどうしよう」ということです。猫は環境の変化が苦手な動物なので、ペットシッターに家に来てもらう訪問型のお世話を選ぶ人が増えています。この記事では、東京のマンションで猫の留守番を頼むときに、訪問と預かりのどちらが合うのか、そして頼む前に決めておきたいことをまとめました。
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        訪問と預かり、どちらが猫に合う？
      </h2>
      <div className="mt-6 grid gap-4 md:grid-cols-2">
        {COMPARE.map((f) => (
          <div key={f.t} className="rounded-2xl border border-ink/5 bg-white p-5 shadow-card">
            <h3 className="font-bold text-ink">{f.t}</h3>
            <p className="mt-2 text-sm leading-relaxed text-ink-muted">{f.d}</p>
          </div>
        ))}
      </div>
      <p className="mt-6 leading-relaxed text-ink-muted">
        迷ったときは、猫の性格と体調で考えましょう。健康で、知らない場所に行くと固まってしまう猫なら、家に来てもらうほうが負担は少なくなります。毎日の投薬がある猫や、長い時間ひとりにするのが心配な猫なら、預かりや、シッターに自宅へ泊まってもらう方法も選択肢になります。預け方の基本は
        <Link href="/blog/tokyo-pet-sitter-guide" className="font-semibold text-owner underline">
          東京でペットシッターを頼むときのポイント
        </Link>
        でも紹介しています。
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        家に来てもらうと、何をしてもらえる？
      </h2>
      <ul className="mt-4 space-y-2">
        {VISIT.map((t) => (
          <li key={t} className="flex gap-2 leading-relaxed text-ink-muted">
            <span aria-hidden="true" className="mt-2.5 h-1.5 w-1.5 shrink-0 rounded-full bg-owner" />
            <span>{t}</span>
          </li>
        ))}
      </ul>
      <p className="mt-4 leading-relaxed text-ink-muted">
        訪問の回数は、猫の年齢や性格に合わせて決めます。食事の回数が多い子猫や、体調の変化が出やすい高齢の猫は、回数を多めにしておくと安心です。何をどこまでお願いしたいかは、依頼を出すときに具体的に書いておきましょう。
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        マンションならではの確認ポイント
      </h2>
      <ul className="mt-4 space-y-2">
        {MANSION.map((t) => (
          <li key={t} className="flex gap-2 leading-relaxed text-ink-muted">
            <span aria-hidden="true" className="mt-2.5 h-1.5 w-1.5 shrink-0 rounded-full bg-owner" />
            <span>{t}</span>
          </li>
        ))}
      </ul>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        出発前に用意しておくもの
      </h2>
      <ul className="mt-4 space-y-2">
        {PREP.map((t) => (
          <li key={t} className="flex gap-2 leading-relaxed text-ink-muted">
            <span aria-hidden="true" className="mt-2.5 h-1.5 w-1.5 shrink-0 rounded-full bg-owner" />
            <span>{t}</span>
          </li>
        ))}
      </ul>
      <p className="mt-4 leading-relaxed text-ink-muted">
        できれば出発前に一度、シッターに家へ来てもらって顔合わせをしましょう。猫に無理に近づかず、普段の様子を細かく聞いてくれるシッターなら安心して任せられます。年末年始に家を空ける予定があるなら、
        <Link href="/blog/tokyo-new-year-pet-care" className="font-semibold text-owner underline">
          年末年始に犬・猫を預けるには
        </Link>
        もあわせて読んでおくと、準備の時期がわかります。
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        HoPetSitで近くの訪問シッターを探す
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        HoPetSitでは、無料で依頼を出すと、近くのペットシッターがそれぞれ決めた料金で返事をくれます。訪問の日にちや回数は依頼を出すときに自分で決められ、チャットで写真や様子を受け取れます。確定する前に合計金額を確認でき、お支払いは安全に預かられ、お世話が終わってからシッターに渡されます。家から近いシッターを探したいときは、
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
        <h2 className="font-display text-2xl font-extrabold text-ink">家に来てくれるシッターを探してみましょう</h2>
        <p className="mx-auto mt-2 max-w-md text-sm text-ink-muted">
          訪問のお世話から預かりまで。東京23区どこからでも無料で依頼を出せます。
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

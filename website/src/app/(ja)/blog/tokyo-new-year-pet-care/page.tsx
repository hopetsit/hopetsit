import type { Metadata } from "next";
import Image from "next/image";
import Link from "@/components/SiteLink";

// 04/11/2026 (GUS, mercredi) — règle de Daniel du 01/11 : chaque semaine un article neuf avec
// sa propre image en ko + ja. Sujet suivant de website/marketing/sujets_4poles.md (Tokyo) :
// faire garder son chien ou son chat pendant 年末年始 à Tokyo (réservations à faire tôt).
// Relié à la page pilier /pet-sitting-japan/tokyo, au premier guide de Tokyo et à la page de
// recrutement. Aucun prix, aucun chiffre inventé : chaque gardien fixe son tarif dans l'app.
const URL = "https://www.hopetsit.com/blog/tokyo-new-year-pet-care";
const IMG = "https://www.hopetsit.com/blog/tokyo-new-year-pet-care.jpg";
const TITLE = "年末年始に犬・猫を預けるには : 東京で早めに準備すること";
const DESCRIPTION =
  "年末年始の帰省や旅行で東京の家を空けるとき、犬や猫をどう預ける？ペットシッターとペットホテルの選び方、予約の時期、動物病院の休診への備え、お正月の食べ物の注意点、シッターに渡すメモをまとめました。";
const HEADLINE = "年末年始に犬・猫を預けるには : 東京で早めに準備すること";
const COVER_ALT = "犬の写真、年末年始のペットの預け方ガイドの表紙";

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
    q: "年末年始のシッターはいつ頃から探せばいいですか？",
    a: "帰省や旅行の日程が決まったら、すぐに依頼を出すのがおすすめです。年末年始は同じ時期に頼みたい人が一度に増えるので、早いほど選べるシッターが多くなります。初めてのシッターなら、その前に短いお世話を一度頼んでおくと安心です。",
  },
  {
    q: "年末年始は料金が上がりますか？",
    a: "決まった料金はありません。各シッターが自分で料金を決めるので、年末年始の扱いもシッターによって違います。HoPetSitでは確定する前に合計金額を確認できるので、日数や訪問回数と合わせて事前に見ておきましょう。",
  },
  {
    q: "猫だけなら数日留守番させても大丈夫ですか？",
    a: "自動給餌器があっても、1日1回は人が様子を見るのが安心です。水がこぼれていないか、トイレが使えているか、食欲があるかは、実際に見ないと分かりません。猫には自宅への訪問のお世話がよく選ばれます。",
  },
  {
    q: "予定が変わったらキャンセルできますか？",
    a: "できるだけ早くアプリのチャットでシッターに伝えてください。HoPetSitでは、お世話の開始72時間前まで無料でキャンセルできます。",
  },
];

const FORMULES = [
  {
    t: "自宅への訪問",
    d: "シッターが1日1〜2回訪問し、ごはん、水、トイレの掃除、遊びや短い散歩をします。環境の変化が苦手な猫や、留守番に慣れた成犬に向いています。",
  },
  {
    t: "自宅に泊まってもらう",
    d: "シッターが飼い主さんの家で過ごし、夜も一緒にいます。いつもの部屋で過ごせて、人がそばにいる時間も長いので、シニアの子や甘えん坊の子、長めの帰省に合います。",
  },
  {
    t: "シッターの家で預かり",
    d: "愛犬がシッターの家で数日過ごします。散歩のリズムを保ちやすく、ひとりの時間が少ないのが良いところです。先住の犬や猫がいるかは必ず確認しましょう。",
  },
  {
    t: "ペットホテル",
    d: "施設で多くの動物を預かります。年末年始は早く埋まりやすく、ワクチンの証明書を求められることが多いので、利用するなら条件を早めに確認しておきましょう。",
  },
];

const CHECK = [
  "かかりつけの動物病院の年末年始の休診日を確認し、休み中に開いている夜間・救急の動物病院の連絡先をメモしておく。",
  "フードとトイレ用品（ペットシーツ、猫砂）は、年末の前に多めに買っておく。お店も配送も休みに入ることがあります。",
  "飲んでいる薬があれば、留守の日数より少し多めに用意しておく。",
  "狂犬病予防注射の注射済票と混合ワクチンの証明書を、すぐ出せる場所にまとめておく。",
  "首輪の迷子札とマイクロチップの登録情報が今の連絡先になっているか確かめる。",
  "冬の留守中の室温をどうするか決めておく。暖房をつけたままにするか、シッターに訪問時の調整を頼むか。",
];

const FOOD = [
  "ねぎ類（玉ねぎ、長ねぎ）：お雑煮やすき焼き、鍋の残りに入っていることが多く、犬にも猫にも危険です。",
  "お餅：のどに詰まりやすいので、テーブルに置いたままにしないこと。",
  "チョコレートやぶどう、レーズン：お菓子やおせちのそばに置かないように。",
  "鶏の骨：割れると鋭くなります。ごみ箱はふたのあるものに。",
  "来客が多い日は、ドアの開け閉めで脱走しやすくなります。玄関に柵をつけるか、別の部屋で過ごさせると安心です。",
];

export default function ArticleTokyoNewYearPetCare() {
  const jsonLd = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "Article",
        headline: HEADLINE,
        description: DESCRIPTION,
        inLanguage: "ja-JP",
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
      <p className="text-sm font-semibold text-owner">暮らしのガイド · 東京 · 年末年始</p>
      <h1 className="mt-2 font-display text-3xl font-extrabold tracking-tight text-ink md:text-4xl">
        年末年始に犬・猫を預けるには : 東京で早めに準備すること
      </h1>
      <Image
        src="/blog/tokyo-new-year-pet-care.jpg"
        alt={COVER_ALT}
        width={1200}
        height={630}
        priority
        sizes="(max-width: 768px) 100vw, 768px"
        className="mt-6 h-auto w-full rounded-2xl"
      />
      <p className="mt-4 text-lg leading-relaxed text-ink-muted">
        実家への帰省、年末の旅行、お正月の初詣。東京で犬や猫と暮らしていると、年末年始は「この子をどうしよう」と考える時期でもあります。休みが重なるこの時期は、シッターもペットホテルも予約が集まり、動物病院やお店も休みに入ります。この記事では、年末年始に家を空けるときの預け方と、今のうちにしておきたい準備をまとめました。
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        年末年始が「いつもの留守」と違うところ
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        いちばんの違いは、みんなが同じ日に出かけることです。シッターやペットホテルを探す人が一度に増えるので、直前になると選べる相手が少なくなります。もうひとつは、かかりつけの動物病院が休診になることが多い点です。体調を崩したときにどこへ連れて行くかを、出かける前に決めておく必要があります。
      </p>
      <p className="mt-4 leading-relaxed text-ink-muted">
        そして、冬の東京は朝晩が冷え込みます。留守中の部屋の温度、乾燥、水が冷たくなりすぎないかなど、夏とは違う気配りが必要です。
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        預け方は4つ。性格と日数で選ぶ
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
        猫はなわばりを大切にする動物なので、知らない場所へ移動するより、自宅に来てもらう形が向いている子が多いです。犬は散歩の回数と、ひとりで過ごせる時間を目安に考えましょう。シッターの選び方の基本は{" "}
        <Link href="/blog/tokyo-pet-sitter-guide" className="font-semibold text-owner underline">
          東京でペットシッターを頼むときのポイント
        </Link>
        にまとめています。
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        出かける前にしておきたい準備
      </h2>
      <ul className="mt-4 space-y-2">
        {CHECK.map((t) => (
          <li key={t} className="flex gap-2 leading-relaxed text-ink-muted">
            <span aria-hidden="true" className="mt-2.5 h-1.5 w-1.5 shrink-0 rounded-full bg-owner" />
            <span>{t}</span>
          </li>
        ))}
      </ul>
      <p className="mt-6 leading-relaxed text-ink-muted">
        住んでいる区の動物病院やペット用品店の場所は、{" "}
        <Link href="/pet-sitting-japan/tokyo#districts" className="font-semibold text-owner underline">
          東京23区のエリア別情報
        </Link>
        で確認できます。
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        お正月の食べ物と来客に気をつける
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        出かける前後や、家に親戚が集まる日も油断は禁物です。お正月のごちそうには、犬や猫にとって危ないものがいくつもあります。シッターにも同じことを伝えておきましょう。
      </p>
      <ul className="mt-4 space-y-2">
        {FOOD.map((t) => (
          <li key={t} className="flex gap-2 leading-relaxed text-ink-muted">
            <span aria-hidden="true" className="mt-2.5 h-1.5 w-1.5 shrink-0 rounded-full bg-owner" />
            <span>{t}</span>
          </li>
        ))}
      </ul>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        シッターに渡すメモと、顔合わせ
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        ごはんの量と時間、散歩のコース、苦手なもの、薬の飲ませ方、緊急時の連絡先と動物病院。これを1枚のメモにして冷蔵庫に貼るか、アプリのチャットで先に送っておくと、シッターが迷いません。鍵の受け渡しは直接会って行い、マンションならオートロックやゴミ出しのルールも伝えておきましょう。
      </p>
      <p className="mt-4 leading-relaxed text-ink-muted">
        初めて頼む相手なら、年末の前に一度、自宅で顔合わせをしてください。愛犬や愛猫への近づき方、質問の丁寧さを見るだけでも、多くのことが分かります。HoPetSitでは、無料で依頼を出すと近くのシッターがそれぞれ決めた料金で返信します。お世話の間はチャットで写真や様子を受け取れ、散歩はPawFollowの
        GPS記録で地図上で確認できます。支払いは安全に預かられ、お世話が終わってからシッターに渡ります。
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
        <h2 className="font-display text-2xl font-extrabold text-ink">年末年始のシッターを早めに探しましょう</h2>
        <p className="mx-auto mt-2 max-w-md text-sm text-ink-muted">
          訪問、泊まり、預かり、散歩まで。東京23区のどこからでも無料で依頼を出せます。
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

import type { Metadata } from "next";
import Link from "@/components/SiteLink";

// 31/10/2026 (GUS) — consigne de Daniel du 31/10 au soir : SEO sur 4 pôles (Paris + Europe,
// New York, Séoul, Tokyo) et un article par ville dans la langue de la ville. Article japonais
// pour Tokyo, relié à la page pilier /pet-sitting-japan/tokyo (section quartiers #districts)
// et à la page de recrutement /pet-sitter-japan/tokyo. Aucun prix, aucun chiffre inventé :
// chaque gardien fixe son tarif dans l'app.
const URL = "https://www.hopetsit.com/blog/tokyo-pet-sitter-guide";
const TITLE = "東京でペットシッターを頼むときのポイント : 選び方と準備";
const DESCRIPTION =
  "東京でペットシッターや散歩代行を頼む前に知っておきたいこと。4つのお世話の形、代々木公園・駒沢公園での散歩のコツ、犬の登録と狂犬病予防注射、お盆・年末年始の準備、信頼できるシッターの選び方。";
const HEADLINE = "東京でペットシッターを頼むときのポイント : 選び方と準備";

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
    images: [{ url: "https://www.hopetsit.com/og-image.png", width: 1200, height: 630, alt: "HoPetSit" }],
  },
};

const FAQ = [
  {
    q: "ペットシッターとペットホテルの違いは？",
    a: "ペットホテルは施設で多くの動物を預かります。ペットシッターは一人が少数の動物だけをお世話し、シッターの家か飼い主さんの家で過ごします。環境の変化や他の犬が苦手な子には、シッターのほうが落ち着きやすいことがあります。",
  },
  {
    q: "東京のペットシッターの料金はどれくらい？",
    a: "決まった料金はありません。散歩か訪問か、何日間か、何頭かによって変わります。HoPetSitでは各シッターが自分で料金を決め、飼い主さんは確定する前に合計金額を確認できます。",
  },
  {
    q: "頼む前にシッターと会えますか？",
    a: "はい、ぜひ事前に会ってください。アプリのチャットで日時を決め、近所の公園やご自宅で、愛犬と一緒に短い顔合わせをしましょう。犬の反応やシッターの接し方を自分の目で確かめられます。",
  },
  {
    q: "散歩にきちんと行ったか分かりますか？",
    a: "お世話の間は、PawFollowのGPS記録で散歩のルートを地図上でリアルタイムに確認でき、アプリのチャットで写真やメッセージをやり取りできます。",
  },
  {
    q: "予定が変わってキャンセルしたいときは？",
    a: "できるだけ早くアプリのチャットでシッターに伝えてください。HoPetSitでは、お世話の開始72時間前まで無料でキャンセルできます。",
  },
];

const FORMULES = [
  {
    t: "シッターの家で預かり",
    d: "数日間、愛犬がシッターの家で過ごします。旅行や帰省など長く家を空けるときによく選ばれる形です。ひとりになる時間が少なく、散歩のリズムもいつも通りに保てます。",
  },
  {
    t: "自宅でのお世話",
    d: "シッターが飼い主さんの家に来て過ごしたり、泊まったりします。いつものベッド、いつもの近所で過ごせるので、シニア犬や怖がりな子、猫と暮らす家庭に向いています。",
  },
  {
    t: "訪問のお世話",
    d: "1日に1〜2回シッターが訪問し、ごはんと水、トイレの片付け、短い散歩や遊びをします。留守番に慣れた成犬や猫の短い外出に合いますが、子犬には向きません。",
  },
  {
    t: "散歩代行",
    d: "30分から1時間ほどの散歩です。共働きや一人暮らしで日中家が空く場合、昼に一度外に出るだけで愛犬の一日が大きく変わります。",
  },
];

const PARCS = [
  {
    t: "代々木公園",
    d: "渋谷区の広い公園で、園内にドッグランもあります。週末は人が多いので、リードを短く持ち、混雑する時間を避けるようシッターと決めておくと安心です。",
  },
  {
    t: "駒沢オリンピック公園",
    d: "世田谷区と目黒区にまたがる公園で、ジョギングコースと広い芝生があり、犬連れの散歩によく使われます。走る人や自転車が多いので、すれ違いに注意しましょう。",
  },
  {
    t: "砧公園",
    d: "世田谷区の緑の多い公園で、木陰が多く、夏の朝夕の散歩にも向いています。ドッグランなどの利用ルールは現地の案内で確認してください。",
  },
  {
    t: "近所の公園と川沿い",
    d: "区立公園の中には犬の立ち入りやリードについて独自のルールがあるところもあります。目黒川沿いや多摩川の河川敷など、いつもの散歩道をシッターに伝えておきましょう。",
  },
];

export default function ArticleTokyoPetSitterGuide() {
  const jsonLd = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "Article",
        headline: HEADLINE,
        description: DESCRIPTION,
        inLanguage: "ja-JP",
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
      <p className="text-sm font-semibold text-owner">暮らしのガイド · 東京</p>
      <h1 className="mt-2 font-display text-3xl font-extrabold tracking-tight text-ink md:text-4xl">
        東京でペットシッターを頼むときのポイント : 選び方と準備
      </h1>
      <p className="mt-4 text-lg leading-relaxed text-ink-muted">
        残業が続く平日、急な出張、お盆や年末年始の帰省。東京で犬と暮らしていると、「今日は誰に散歩を
        頼もう」と悩む日が必ずあります。この記事では、東京でペットシッターや散歩代行を探すときに知って
        おきたいお世話の形、散歩の場所、守るべきルール、そして信頼できる人の選び方をまとめました。
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        ペットシッターは何をしてくれるの？
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        ペットシッターは、飼い主さんがお世話できないときに代わりに動物の面倒を見る人です。たくさんの
        動物を預かる施設とは違い、一人が少数の動物だけを見るので、知らない音や他の犬が多い環境が苦手な
        子にとって、ずっと穏やかな選択肢になります。
      </p>
      <p className="mt-4 leading-relaxed text-ink-muted">
        することは、普段飼い主さんがしていることと同じです。決まった時間にごはんをあげ、新しい水に替え、
        散歩と遊びをし、薬があれば飲ませます。そして写真と一緒にその日の様子を伝え、気になることがあれば
        すぐに飼い主さんに連絡し、必要なら動物病院に連れて行きます。
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">東京でよく選ばれる4つのお世話の形</h2>
      <div className="mt-6 grid gap-4 md:grid-cols-2">
        {FORMULES.map((f) => (
          <div key={f.t} className="rounded-2xl border border-ink/5 bg-white p-5 shadow-card">
            <h3 className="font-bold text-ink">{f.t}</h3>
            <p className="mt-2 text-sm leading-relaxed text-ink-muted">{f.d}</p>
          </div>
        ))}
      </div>
      <p className="mt-6 leading-relaxed text-ink-muted">
        どれが合うか迷ったら、愛犬の年齢と性格、そして家を空ける時間で考えてみてください。半日なら散歩や
        訪問、1日以上ならシッターの家か自宅でのお世話が一般的です。
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">東京の散歩スポットの選び方</h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        シッターに頼むときは、愛犬がいつも歩いている道を教えてあげるのがいちばんです。慣れたにおいと道は、
        知らない人との散歩の緊張を大きく和らげます。東京で犬の散歩によく使われる場所は次のとおりです。
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
        区ごとの公園、動物病院、ペット用品店の場所は、
        <Link href="/pet-sitting-japan/tokyo#districts" className="font-semibold text-owner underline">
          東京23区の地域別情報
        </Link>
        で確認できます。
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">頼む前に確認しておきたいルール</h2>
      <ul className="mt-4 space-y-2">
        {[
          "犬の登録 : 生後91日以上の犬は、住んでいる区市町村への登録が必要です。鑑札や注射済票の場所をシッターにも伝えておきましょう。",
          "狂犬病予防注射 : 年に1回の接種が義務づけられています。接種の記録をワクチン証明と一緒に渡しておくと安心です。",
          "リードとマナー : 散歩中はリードをつけ、フンは必ず持ち帰ります。おしっこの後に水で流すのが一般的なマナーなので、水を入れたボトルも用意しておきましょう。",
          "マンション暮らし : エレベーターや共用部分では抱っこする、またはリードを短く持つなど、建物のルールをシッターにも共有してください。",
          "ルールは変わることがあるので、最新の内容は環境省や区の案内もあわせて確認してください。",
        ].map((t) => (
          <li key={t} className="flex gap-2 leading-relaxed text-ink-muted">
            <span aria-hidden="true" className="mt-2.5 h-1.5 w-1.5 shrink-0 rounded-full bg-owner" />
            <span>{t}</span>
          </li>
        ))}
      </ul>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">季節と長期休みに合わせた準備</h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        東京の夏は蒸し暑く、日中のアスファルトは犬の肉球をやけどさせるほど熱くなります。夏の散歩は早朝か
        日が沈んでからにしてもらいましょう。冬は乾燥と朝晩の冷え込みがあるので、シニア犬や短毛の子には
        服を用意し、散歩後に足を拭いてもらうよう伝えておくと安心です。
      </p>
      <p className="mt-4 leading-relaxed text-ink-muted">
        お盆や年末年始、ゴールデンウィークは、シッターを探す人が一度に増える時期です。日程が決まったら
        早めに依頼を出し、はじめてのシッターなら連休の前に一度短いお世話を頼んでみるのもよい方法です。
        年末年始の準備は{" "}
        <Link href="/blog/tokyo-new-year-pet-care" className="font-semibold text-owner underline">
          年末年始に犬・猫を預けるには
        </Link>
        で詳しくまとめています。毎日の散歩だけを頼みたいときは{" "}
        <Link href="/blog/tokyo-dog-walking-guide" className="font-semibold text-owner underline">
          東京で犬の散歩代行を頼むには
        </Link>
        も参考にしてください。
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">シッターに渡すものチェックリスト</h2>
      <ul className="mt-4 space-y-2">
        {[
          "フードとおやつ : いつもの量と時間、与えてはいけないものも書いておきましょう。",
          "ワクチン証明と狂犬病予防注射の記録、飲んでいる薬。",
          "かかりつけの動物病院と、近くの夜間・救急の動物病院の連絡先。",
          "鍵の受け渡し方法 : 直接会って渡し、お世話が終わったら返してもらいましょう。",
          "愛犬のくせ : 怖がるもの、他の犬との相性、拾い食いの有無など。",
        ].map((t) => (
          <li key={t} className="flex gap-2 leading-relaxed text-ink-muted">
            <span aria-hidden="true" className="mt-2.5 h-1.5 w-1.5 shrink-0 rounded-full bg-owner" />
            <span>{t}</span>
          </li>
        ))}
      </ul>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">HoPetSitで近所のシッターを探す</h2>
      <ol className="mt-4 space-y-3">
        {[
          "依頼を無料で投稿します : ペット、日程、希望するお世話の形（預かり、訪問、散歩）と住んでいる区を書くだけです。",
          "近くのシッターや散歩代行の人が依頼を見て、それぞれが決めた料金で返信します。",
          "プロフィールとレビューを比べ、アプリのチャットで話してから、愛犬と一緒に顔合わせをしましょう。",
          "気に入ったシッターを選んでアプリで支払います。支払いは安全に預かられ、お世話が終わってからシッターに渡ります。",
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
        東京で犬や猫のお世話をする側になりたい方は、
        <Link href="/pet-sitter-japan/tokyo" className="font-semibold text-owner underline">
          東京でペットシッターとして活動する
        </Link>
        をご覧ください。
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
        <h2 className="font-display text-2xl font-extrabold text-ink">近所のペットシッターを探しましょう</h2>
        <p className="mx-auto mt-2 max-w-md text-sm text-ink-muted">
          預かり、訪問、散歩まで。東京23区のどこからでも依頼を投稿できます。
        </p>
        <Link
          href="/#publier"
          className="mt-5 inline-block rounded-full bg-owner px-7 py-3 text-sm font-bold text-white"
        >
          依頼を投稿する
        </Link>
        <p className="mt-4 text-sm font-bold">
          <Link href="/pet-sitter-japan/tokyo" className="text-owner underline">
            ペットシッターになる →
          </Link>
        </p>
      </div>
    </div>
  );
}

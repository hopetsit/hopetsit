import type { Metadata } from "next";
import Image from "next/image";
import Link from "@/components/SiteLink";

// 11/11/2026 (GUS, mercredi) — règle de Daniel du 01/11 : chaque semaine un article neuf avec
// sa propre image en ko + ja. Sujet choisi par la DEMANDE mesurée (Search Console, 90 j) :
// « ドッグシッター » (11-12e place), « ペット 散歩 代行 » (11e), « 訪問ペットシッター » (10e),
// aucune page qui parle de la promenade à Tokyo. Relié à la page pilier /pet-sitting-japan/tokyo,
// aux 2 guides de Tokyo et à la page de recrutement. Aucun prix, aucun chiffre inventé.
const URL = "https://www.hopetsit.com/blog/tokyo-dog-walking-guide";
const IMG = "https://www.hopetsit.com/blog/tokyo-dog-walking-guide.jpg";
const TITLE = "東京で犬の散歩代行を頼むには : ドッグシッターの選び方";
const DESCRIPTION =
  "仕事や通院で散歩に行けない日、東京で犬の散歩代行（ドッグシッター）を頼むには？散歩代行でしてもらえること、初めての顔合わせで確認すること、鍵の受け渡し、冬の夕方の散歩の注意点をまとめました。";
const HEADLINE = "東京で犬の散歩代行を頼むには : ドッグシッターの選び方と準備";
const COVER_ALT = "犬の写真、東京の犬の散歩代行ガイドの表紙";

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
    q: "散歩代行は1回だけでも頼めますか？",
    a: "頼めます。残業の日だけ、通院の日だけといった単発の依頼も、平日は毎日といった定期の依頼もできます。依頼を出すときに、日にち、時間帯、散歩の長さを自分で決められます。",
  },
  {
    q: "散歩代行の料金はいくらですか？",
    a: "決まった料金はありません。散歩の長さ、回数、頭数によって変わります。HoPetSitでは各シッターが自分で料金を決め、飼い主は確定する前に合計金額を確認できます。",
  },
  {
    q: "散歩中の様子は分かりますか？",
    a: "アプリのチャットで写真やメッセージを受け取れます。散歩のルートをその場で地図で見られる機能もあるので、初めてのシッターでも安心しやすくなります。",
  },
  {
    q: "ほかの犬が苦手な子でも頼めますか？",
    a: "頼めます。依頼を出すときと顔合わせのときに、苦手なもの（ほかの犬、自転車、大きな音など）をはっきり伝えてください。人の少ない時間帯や道を選んでもらうなど、シッターと一緒に散歩の仕方を決めておくと安心です。",
  },
];

const SERVICES = [
  {
    t: "散歩",
    d: "決めた時間に家まで迎えに来て、いつものコースや近くの公園を歩きます。歩くペースや休憩の取り方も、その子に合わせてもらえます。",
  },
  {
    t: "散歩のあとのケア",
    d: "足を拭く、水を替える、ごはんをあげるなど、帰ってからの小さなお世話も一緒に頼めます。何をしてほしいかは事前に伝えておきましょう。",
  },
  {
    t: "訪問のお世話",
    d: "シニア犬や子犬で長く歩けない子には、家に来てトイレの片付けや遊び相手をしてもらう訪問型のお世話も向いています。",
  },
  {
    t: "様子の報告",
    d: "うんちの状態、歩き方、食欲など、気づいたことをシッターから報告してもらうと、体調の変化に早く気づけます。",
  },
];

const MEET = [
  "一緒に少し歩いてみる：リードの持ち方、ほかの犬や自転車とすれ違うときの動きを見ておくと安心です。",
  "いつものコースを伝える：交通量の多い道、工事中の場所、犬が怖がる場所があれば教えておきましょう。",
  "鍵の受け渡しを決める：直接手渡しするのか、管理人に預けるのか、オートロックの開け方も含めて決めておきます。",
  "緊急時の連絡先：かかりつけの動物病院、夜間に診てもらえる病院、飼い主に連絡がつかないときの連絡先。",
  "してほしくないこと：知らない人におやつをもらう、ノーリードにする、など。",
];

const WINTER = [
  "冬は日が暮れるのが早く、夕方の散歩はすぐに暗くなります。光る首輪や反射材のついたハーネスを用意しておきましょう。",
  "短毛の犬や小型犬、シニア犬は寒さに弱いので、服を着せるかどうか、散歩の長さをどうするかをシッターと決めておきます。",
  "東京でも公園や歩道ではリードをつけるのが基本です。散歩代行でも同じで、ドッグラン以外でリードを外すことはありません。",
  "雨や雪の日の過ごし方（短い散歩にする、室内で遊ぶなど）も、前もって決めておくと迷いません。",
];

export default function ArticleTokyoDogWalkingGuide() {
  const jsonLd = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "Article",
        headline: HEADLINE,
        description: DESCRIPTION,
        inLanguage: "ja-JP",
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
    <div className="mx-auto max-w-3xl px-4 py-16 md:py-24">
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }} />
      <p className="text-sm font-semibold text-owner">暮らしのガイド · 東京 · 犬</p>
      <h1 className="mt-2 font-display text-3xl font-extrabold tracking-tight text-ink md:text-4xl">
        東京で犬の散歩代行を頼むには : ドッグシッターの選び方と準備
      </h1>
      <Image
        src="/blog/tokyo-dog-walking-guide.jpg"
        alt={COVER_ALT}
        width={1200}
        height={630}
        priority
        sizes="(max-width: 768px) 100vw, 768px"
        className="mt-6 h-auto w-full rounded-2xl"
      />
      <p className="mt-4 text-lg leading-relaxed text-ink-muted">
        残業で帰りが遅くなる日、体調を崩した日、通院や出張で家を空ける日。毎日の散歩は犬にとって大切な時間ですが、いつも飼い主が行けるとは限りません。そんなときに頼れるのが、家まで来て散歩をしてくれる散歩代行（ドッグシッター）です。この記事では、東京で散歩代行を頼むときに知っておきたいことと、初めてのシッターに任せる前の準備をまとめました。
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        散歩代行でしてもらえること
      </h2>
      <div className="mt-6 grid gap-4 md:grid-cols-2">
        {SERVICES.map((f) => (
          <div key={f.t} className="rounded-2xl border border-ink/5 bg-white p-5 shadow-card">
            <h3 className="font-bold text-ink">{f.t}</h3>
            <p className="mt-2 text-sm leading-relaxed text-ink-muted">{f.d}</p>
          </div>
        ))}
      </div>
      <p className="mt-6 leading-relaxed text-ink-muted">
        泊まりがけで家を空けるなら、散歩代行よりも、シッターの家で預かってもらう方法や、自宅に泊まってもらう方法が合うこともあります。預け方の選び方は
        <Link href="/blog/tokyo-pet-sitter-guide" className="font-semibold text-owner underline">
          東京でペットシッターを頼むときのポイント
        </Link>
        で詳しく紹介しています。
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        どんなシッターを選べばいい？
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        散歩代行で一番大切なのは、犬を安全に歩かせられることです。プロフィールに犬の散歩やお世話の経験が書かれているか、口コミに「時間どおりに来てくれた」「写真をたくさん送ってくれた」といった声があるかを見てみましょう。大型犬や力の強い犬なら、同じくらいの大きさの犬を散歩させた経験があるかも聞いておくと安心です。
      </p>
      <p className="mt-4 leading-relaxed text-ink-muted">
        家から近いシッターを選ぶのもおすすめです。近所なら急な依頼にも応じてもらいやすく、いつものコースや近くの公園もよく知っています。毎回同じシッターにお願いできれば、犬も早く慣れてくれます。
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        初めての顔合わせで確認すること
      </h2>
      <ul className="mt-4 space-y-2">
        {MEET.map((t) => (
          <li key={t} className="flex gap-2 leading-relaxed text-ink-muted">
            <span aria-hidden="true" className="mt-2.5 h-1.5 w-1.5 shrink-0 rounded-full bg-owner" />
            <span>{t}</span>
          </li>
        ))}
      </ul>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        冬の夕方の散歩で気をつけること
      </h2>
      <ul className="mt-4 space-y-2">
        {WINTER.map((t) => (
          <li key={t} className="flex gap-2 leading-relaxed text-ink-muted">
            <span aria-hidden="true" className="mt-2.5 h-1.5 w-1.5 shrink-0 rounded-full bg-owner" />
            <span>{t}</span>
          </li>
        ))}
      </ul>
      <p className="mt-4 leading-relaxed text-ink-muted">
        年末年始に帰省や旅行で家を空ける予定があるなら、
        <Link href="/blog/tokyo-new-year-pet-care" className="font-semibold text-owner underline">
          年末年始に犬・猫を預けるには
        </Link>
        もあわせて読んでおくと準備がスムーズです。
      </p>

      <h2 className="mt-12 font-display text-2xl font-extrabold text-ink">
        HoPetSitで近くのドッグシッターを探す
      </h2>
      <p className="mt-4 leading-relaxed text-ink-muted">
        HoPetSitでは、無料で依頼を出すと、近くのドッグシッターや散歩シッターがそれぞれ決めた料金で返事をくれます。散歩の日時や長さは依頼を出すときに自分で決められ、チャットで写真や様子を受け取れます。お支払いは安全に預かられ、お世話が終わってからシッターに渡されます。住んでいる区の動物病院や散歩できる公園は
        <Link href="/pet-sitting-japan/tokyo#districts" className="font-semibold text-owner underline">
          東京23区のエリア情報
        </Link>
        で確認できます。
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
        <h2 className="font-display text-2xl font-extrabold text-ink">近くのドッグシッターを探してみましょう</h2>
        <p className="mx-auto mt-2 max-w-md text-sm text-ink-muted">
          散歩代行、訪問のお世話、預かりまで。東京23区どこからでも無料で依頼を出せます。
        </p>
        <Link
          href="/#publier"
          className="mt-5 inline-block rounded-full bg-owner px-7 py-3 text-sm font-bold text-white"
        >
          依頼を出す
        </Link>
        <p className="mt-4 text-sm font-bold">
          <Link href="/pet-sitter-japan/tokyo" className="text-owner underline">
            東京でドッグシッターとして活動する →
          </Link>
        </p>
      </div>
    </div>
  );
}

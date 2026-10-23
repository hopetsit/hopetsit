"use client";

// 22/10/2026 (SAM, accord de Daniel « bouton 1 clic ») — arrivée depuis
// l'e-mail envoyé aux contacts de la pub à formulaire Meta (?l=<jeton>).
// La pub promet « sans créer de compte, les gardiens vous répondent » ; mesure
// des 48 h précédentes : 11 contacts → 0 compte → 0 demande, à cause du mot de
// passe et du code exigés par /posts/create. Ici : on montre la demande déjà
// décrite dans la pub, UN bouton la publie (compte créé et vérifié par le
// serveur, session ouverte). /posts est en noindex (middleware).

import Link from "next/link";
import { useEffect, useRef, useState } from "react";
import { trackSiteEvent } from "@/components/SiteAnalytics";
import { confirmAdLead, getAdLead, type AdLeadSummary } from "@/lib/api";

const TXT = {
  fr: {
    hello: (p: string) => (p ? `Bonjour ${p} !` : "Bonjour !"),
    intro: "Voici la demande que vous avez laissée. Publiez-la et les gardiens près de chez vous sont prévenus tout de suite.",
    where: "Où se passe la garde ?",
    atOwner: "Chez moi", atOwnerSub: "Le gardien vient chez vous",
    atSitter: "Chez le gardien", atSitterSub: "Vous déposez votre animal chez lui",
    cta: "Publier ma demande — gratuit",
    busy: "Publication…",
    terms: "En publiant, vous acceptez les",
    termsLink: "conditions d'utilisation",
    noAccount: "Pas de mot de passe à créer : votre compte est ouvert avec votre e-mail.",
    done: "C'est publié !",
    already: "Votre demande est en ligne !",
    alreadySub: "Les gardiens et promeneurs près de chez vous ont été prévenus. Leurs réponses arrivent par e-mail et dans l'app.",
    doneSub: (n?: number) => (n && n > 0
      ? `${n} gardien${n > 1 ? "s" : ""} et promeneur${n > 1 ? "s" : ""} près de chez vous ${n > 1 ? "sont prévenus" : "est prévenu"}. Vous recevrez leurs réponses par e-mail et dans l'app.`
      : "Les gardiens et promeneurs près de chez vous sont prévenus. Vous recevrez leurs réponses par e-mail et dans l'app."),
    see: "Voir ma demande",
    pwd: "Pour vous reconnecter plus tard : « Mot de passe oublié » avec votre e-mail.",
    gone: "Ce lien n'est plus valable.",
    goneSub: "Vous pouvez publier votre demande en 1 minute ici :",
    goneCta: "Publier ma demande",
    err: "La publication n'a pas abouti. Réessayez dans un instant.",
    svc: { garde: "Garde", promenade: "Promenades", visites: "Visites à domicile" },
    ani: { chien: "votre chien", chat: "votre chat", autre: "votre animal" },
    when: { bientot: "dans les 15 jours", fetes: "pendant les fêtes", plus_tard: "date à préciser avec le gardien" },
    for: "pour", in: "à",
  },
  en: {
    hello: (p: string) => (p ? `Hi ${p}!` : "Hi!"),
    intro: "Here is the request you left. Publish it and sitters near you are notified right away.",
    where: "Where should the sitting happen?",
    atOwner: "At my place", atOwnerSub: "The sitter comes to your home",
    atSitter: "At the sitter's", atSitterSub: "You drop your pet off at theirs",
    cta: "Publish my request — free",
    busy: "Publishing…",
    terms: "By publishing, you accept the",
    termsLink: "terms of use",
    noAccount: "No password to create: your account opens with your email.",
    done: "It's live!",
    already: "Your request is live!",
    alreadySub: "Sitters and dog walkers near you have been notified. Their replies arrive by email and in the app.",
    doneSub: (n?: number) => (n && n > 0
      ? `${n} sitter${n > 1 ? "s and dog walkers" : " or dog walker"} near you ${n > 1 ? "were" : "was"} notified. You'll get their replies by email and in the app.`
      : "Sitters and dog walkers near you are notified. You'll get their replies by email and in the app."),
    see: "See my request",
    pwd: "To sign in later: “Forgot password” with your email.",
    gone: "This link is no longer valid.",
    goneSub: "You can publish your request in 1 minute here:",
    goneCta: "Publish my request",
    err: "Publishing didn't go through. Please try again in a moment.",
    svc: { garde: "Pet sitting", promenade: "Dog walks", visites: "Drop-in visits" },
    ani: { chien: "your dog", chat: "your cat", autre: "your pet" },
    when: { bientot: "within 2 weeks", fetes: "over the holidays", plus_tard: "dates to agree with the sitter" },
    for: "for", in: "in",
  },
} as const;

export default function ConfirmLeadPage() {
  const [id, setId] = useState("");
  const [lead, setLead] = useState<AdLeadSummary | null>(null);
  const [gone, setGone] = useState(false);
  const [lieu, setLieu] = useState<"at_owner" | "at_sitter" | "">("");
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState("");
  const [done, setDone] = useState<{ postId: string | null; notified?: number } | null>(null);
  // 23/10 (BOB, accord de Daniel) — `next` : cible interne (ex. /application/<id>) demandée par
  // le bouton d'un e-mail (candidature, réservation, message). Si la demande est déjà en ligne,
  // on ouvre la session sans mot de passe et on y va tout seul, sans clic.
  const [next, setNext] = useState("");
  const [opening, setOpening] = useState(false);
  const seen = useRef(false);
  const auto = useRef(false);

  useEffect(() => {
    let l = "";
    let n = "";
    try {
      const q = new URLSearchParams(window.location.search);
      l = (q.get("l") || "").trim();
      n = (q.get("next") || "").trim();
    } catch { /* URL exotique */ }
    setId(l);
    // chemin interne seulement : commence par un seul « / », jamais « // » ni « http »
    if (/^\/(?!\/)[^\s]*$/.test(n)) setNext(n);
    if (!/^[a-f0-9]{32}$/.test(l)) { setGone(true); return; }
    getAdLead(l)
      .then((d) => {
        setLead(d);
        if (!seen.current) { seen.current = true; trackSiteEvent("cta_click", { label: "lead_vu" }); }
      })
      .catch(() => setGone(true));
  }, []);

  useEffect(() => {
    if (!lead || !lead.confirmed || !next || auto.current) return;
    auto.current = true;
    setOpening(true);
    confirmAdLead(id)
      .then(() => { trackSiteEvent("cta_click", { label: "lead_next" }); window.location.href = next; })
      .catch(() => { setOpening(false); setErr(TXT[lead.lang === "en" ? "en" : "fr"].err); });
  }, [lead, next, id]);

  const t = TXT[lead?.lang === "en" ? "en" : "fr"];
  const needsLieu = lead?.service === "garde";

  async function onConfirm() {
    if (!lead || busy) return;
    if (needsLieu && !lieu) { setErr(t.where); return; }
    setBusy(true);
    setErr("");
    try {
      const r = await confirmAdLead(id, needsLieu ? (lieu || undefined) : undefined);
      trackSiteEvent("cta_click", { label: "lead_confirme" });
      setDone({ postId: r.postId, notified: r.notified });
      try { window.scrollTo({ top: 0, behavior: "smooth" }); } catch { /* ignore */ }
    } catch {
      setErr(t.err);
    } finally {
      setBusy(false);
    }
  }

  // 23/10 : /post/<id> exige une session. Depuis l'e-mail « votre demande est en ligne », le
  // contact n'en a pas : ce bouton rejoue confirmAdLead (idempotent : même demande, session
  // ouverte avec son e-mail) puis ouvre la demande. Pas de mot de passe à saisir.
  async function onSeePost(postId: string | null) {
    if (busy) return;
    setBusy(true);
    setErr("");
    try {
      const r = await confirmAdLead(id);
      const target = r.postId || postId;
      window.location.href = next || (target ? `/post/${target}` : "/posts");
    } catch {
      setErr(t.err);
      setBusy(false);
    }
  }

  const card = "mx-auto w-full max-w-md rounded-[24px] bg-white p-5 shadow-sm sm:p-7";
  const bigBtn = "flex min-h-[52px] w-full items-center justify-center rounded-full bg-owner px-6 text-base font-bold text-white transition hover:bg-owner-dark disabled:opacity-60";

  if (gone) {
    return (
      <main className="min-h-[70vh] bg-[#FFF7F4] px-4 py-10">
        <div className={card}>
          <h1 className="font-display text-2xl font-extrabold text-ink">{t.gone}</h1>
          <p className="mt-2 text-[#6E4F48]">{t.goneSub}</p>
          <Link href="/posts/create" className={`${bigBtn} mt-5`}>{t.goneCta}</Link>
        </div>
      </main>
    );
  }

  if (!lead || opening) {
    return <main className="min-h-[70vh] bg-[#FFF7F4] px-4 py-10"><div className={`${card} h-64 animate-pulse`} /></main>;
  }

  if (done || lead.confirmed) {
    // 23/10 (SAM, consigne de Daniel) : le suivi publie la demande dès le formulaire rempli ;
    // le lien de l'e-mail arrive donc le plus souvent sur une demande déjà en ligne.
    const postId = done?.postId || lead.postId || null;
    return (
      <main className="min-h-[70vh] bg-[#FFF7F4] px-4 py-10">
        <div className={`${card} text-center`}>
          <div className="text-5xl" aria-hidden>🐾</div>
          <h1 className="mt-2 font-display text-3xl font-extrabold text-ink">{done ? t.done : t.already}</h1>
          <p className="mt-3 text-[#6E4F48]">{done ? t.doneSub(done.notified) : t.alreadySub}</p>
          {postId && (
            <button type="button" onClick={() => onSeePost(postId)} disabled={busy} className={`${bigBtn} mt-6`}>
              {busy ? t.busy : t.see}
            </button>
          )}
          {err && <p role="alert" className="mt-3 text-sm font-semibold text-owner-dark">{err}</p>}
          <p className="mt-4 text-xs text-[#6E4F48]">{t.pwd}</p>
        </div>
      </main>
    );
  }

  return (
    <main className="min-h-[70vh] bg-[#FFF7F4] px-4 py-8">
      <div className={card}>
        <h1 className="font-display text-3xl font-extrabold leading-tight text-ink">{t.hello(lead.firstName)}</h1>
        <p className="mt-2 text-[#6E4F48]">{t.intro}</p>

        <div className="mt-5 rounded-2xl border border-owner/30 bg-owner-light p-4">
          <p className="text-lg font-bold text-ink">
            {t.svc[lead.service]} {t.for} {t.ani[lead.animal]}
          </p>
          <p className="mt-1 text-sm text-[#6E4F48]">📍 {lead.city} · 🗓 {t.when[lead.quand]}</p>
        </div>

        {needsLieu && (
          <fieldset className="mt-5">
            <legend className="mb-2 text-sm font-semibold text-ink">{t.where}</legend>
            <div className="grid gap-2">
              {([["at_owner", t.atOwner, t.atOwnerSub, "🏠"], ["at_sitter", t.atSitter, t.atSitterSub, "🐾"]] as const).map(([v, label, sub, icon]) => (
                <button
                  key={v}
                  type="button"
                  aria-pressed={lieu === v}
                  onClick={() => { setLieu(v); setErr(""); }}
                  className={`flex min-h-[56px] items-center gap-3 rounded-2xl border-2 px-4 py-2 text-left transition ${lieu === v ? "border-owner bg-owner-light" : "border-[#EADBD6] bg-white"}`}
                >
                  <span className="text-xl" aria-hidden>{icon}</span>
                  <span>
                    <span className="block font-bold text-ink">{label}</span>
                    <span className="block text-xs text-[#6E4F48]">{sub}</span>
                  </span>
                </button>
              ))}
            </div>
          </fieldset>
        )}

        <button type="button" onClick={onConfirm} disabled={busy} className={`${bigBtn} mt-6`}>
          {busy ? t.busy : t.cta}
        </button>
        {err && <p role="alert" className="mt-3 text-center text-sm font-semibold text-owner-dark">{err}</p>}
        <p className="mt-4 text-center text-xs text-[#6E4F48]">{t.noAccount}</p>
        <p className="mt-1 text-center text-xs text-[#6E4F48]">
          {t.terms} <Link href="/terms" className="font-semibold text-owner-dark underline">{t.termsLink}</Link>.
        </p>
      </div>
    </main>
  );
}

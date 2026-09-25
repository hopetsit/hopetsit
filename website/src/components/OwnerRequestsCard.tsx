"use client";

// 25/09/2026 (PawMap 586, point 9) — « Demandes en cours » d'un PROPRIÉTAIRE,
// vues par un gardien / promeneur connecté (fiche de la carte et /p/owner/:id).
// Service, dates, animal, budget, distance ou ville — jamais l'adresse. Bouton
// signature à la couleur du rôle du VISITEUR : « Proposer mes services » en un
// clic (même contrat que l'app). Rien à afficher → `onEmpty` (la fiche montre
// alors « Message »).
import { useEffect, useState } from "react";
import { useT } from "@/lib/i18n/LanguageProvider";
import { getOwnerActiveRequests, getStoredUser, myBasePrice, proposeMyServices, type OwnerActiveRequest } from "@/lib/api";
import { AppIcon } from "@/components/AppIcon";

const GRAD = { sitter: "linear-gradient(90deg,#2F6FD6,#1E4FB0)", walker: "linear-gradient(90deg,#2FAE4E,#15803D)" } as const;
const DARK = { sitter: "#1E4FB0", walker: "#15803D" } as const;
type St = "idle" | "busy" | "sent" | "already" | "accepted" | "rejected" | "error" | "noprice";

function stateFrom(s?: string | null): St {
  return s === "pending" ? "already" : s === "accepted" ? "accepted" : s === "rejected" ? "rejected" : "idle";
}

export function OwnerRequestsCard({ ownerId, from, onLoaded }: { ownerId: string; from?: { lat: number; lng: number } | null; onLoaded?: (count: number) => void }) {
  const { t, lang } = useT();
  const [role, setRole] = useState<"sitter" | "walker" | null>(null);
  const [posts, setPosts] = useState<OwnerActiveRequest[] | null>(null);
  const [st, setSt] = useState<Record<string, St>>({});

  useEffect(() => {
    const u = getStoredUser();
    const r = u && (u.role === "sitter" || u.role === "walker") ? u.role : null;
    setRole(r);
    if (!r) { setPosts([]); onLoaded?.(0); return; }
    let alive = true;
    getOwnerActiveRequests(ownerId, from).then(({ posts: list }) => {
      if (!alive) return;
      setPosts(list);
      setSt(Object.fromEntries(list.map((p) => [p.id, stateFrom(p.myApplication)])));
      onLoaded?.(list.length);
    });
    return () => { alive = false; };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [ownerId]);

  if (!role || !posts || posts.length === 0) return null;

  const svc = (s: string) => t(s === "dog_walking" ? "posts_svc_dog_walking" : s === "day_care" ? "posts_svc_day_care" : "posts_svc_house_sitting");
  const day = (iso?: string | null) => (iso ? new Date(iso).toLocaleDateString(lang, { day: "numeric", month: "short" }) : "");
  const money = (v: number, c?: string) => { try { return new Intl.NumberFormat(lang, { style: "currency", currency: c || "EUR", maximumFractionDigits: 0 }).format(v); } catch { return `${v} ${c || "€"}`; } };

  async function offer(p: OwnerActiveRequest) {
    const u = getStoredUser();
    if (!u || !role) return;
    setSt((m) => ({ ...m, [p.id]: "busy" }));
    const base = await myBasePrice(role, u.id);
    if (base <= 0) { setSt((m) => ({ ...m, [p.id]: "noprice" })); return; }
    try {
      const r = await proposeMyServices(p, role, base);
      setSt((m) => ({ ...m, [p.id]: r }));
    } catch (e) {
      const msg = e instanceof Error ? e.message.toLowerCase() : "";
      setSt((m) => ({ ...m, [p.id]: msg.includes("already") || msg.includes("duplicate") ? "already" : "error" }));
    }
  }

  return (
    <section className="rounded-2xl bg-[#FFF6F2] p-3 ring-1 ring-[#F6D9CF]" aria-label={t("m586_req_title")}>
      <h3 className="flex items-center gap-1.5 text-[13px] font-bold text-[#9E1F0B]">
        <AppIcon name="megaphone" size={15} color="#C92A12" />{t("m586_req_title")}
        <span className="rounded-full bg-white px-1.5 text-[11px] text-[#9E1F0B]">{posts.length}</span>
      </h3>
      <ul className="mt-2 space-y-2">
        {posts.map((p) => {
          const s = st[p.id] || "idle";
          const dates = [day(p.startDate), day(p.endDate)].filter(Boolean).filter((v, i, a) => a.indexOf(v) === i).join(" → ");
          const where = p.distanceKm ? t("m586_km").replace("{km}", String(p.distanceKm)) : p.city || "";
          const done = s === "sent" || s === "already" || s === "accepted";
          return (
            <li key={p.id} className="rounded-xl bg-white p-2.5">
              <p className="text-[13px] font-bold text-[#231715]">{p.serviceTypes.map(svc).join(" · ") || svc(role === "walker" ? "dog_walking" : "house_sitting")}</p>
              <p className="mt-0.5 text-[12px] leading-snug text-[#6E4F48]">
                {[dates, p.pets.map((x) => x.name).filter(Boolean).join(", "), where].filter(Boolean).join(" · ")}
              </p>
              {(p.budget ?? 0) > 0 && <p className="mt-0.5 text-[12px] font-bold text-[#9E1F0B]">{t("m586_req_budget")} : {money(p.budget!, p.currency)}</p>}
              {done || s === "rejected" ? (
                <p className="mt-2 flex min-h-[40px] items-center justify-center gap-1.5 rounded-[14px] px-3 text-center text-[13px] font-bold" style={s === "rejected" ? { background: "#FBE9E5", color: "#9E1F0B" } : { background: role === "walker" ? "#E8F8EE" : "#EAF1FE", color: DARK[role] }}>
                  {s !== "rejected" && <AppIcon name="check" size={15} color={DARK[role]} />}
                  {t(s === "sent" ? "m586_req_sent" : s === "already" ? "m586_req_already" : s === "accepted" ? "m586_req_accepted" : "m586_req_rejected")}
                </p>
              ) : (
                <button
                  type="button"
                  onClick={() => void offer(p)}
                  disabled={s === "busy"}
                  className="relative mt-2 flex min-h-[46px] w-full items-center justify-center gap-2 overflow-hidden rounded-[16px] px-3 text-center text-[14px] font-bold leading-tight text-white transition active:scale-[0.97]"
                  style={{ background: GRAD[role] }}
                >
                  <span aria-hidden className="pointer-events-none absolute inset-x-0 top-0 h-1/2 bg-white/15" />
                  <span className="relative grid h-7 w-7 shrink-0 place-items-center rounded-full bg-white"><AppIcon name={role === "walker" ? "walker" : "home"} size={15} color={DARK[role]} /></span>
                  <span className="relative">{s === "busy" ? "…" : t("m586_req_offer")}</span>
                </button>
              )}
              {s === "noprice" && <p className="mt-1.5 text-[12px] font-bold text-[#9A3412]">{t("m586_req_no_price")}</p>}
              {s === "error" && <p className="mt-1.5 text-[12px] font-bold text-[#B42318]" role="alert">{t("m586_req_error")}</p>}
            </li>
          );
        })}
      </ul>
    </section>
  );
}

export default OwnerRequestsCard;

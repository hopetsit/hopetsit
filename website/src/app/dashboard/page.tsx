"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { useT } from "@/lib/i18n/LanguageProvider";
import { AuthUser, clearAuth, getStoredUser } from "@/lib/api";

export default function DashboardPage() {
  const { t } = useT();
  const router = useRouter();
  const [user, setUser] = useState<AuthUser | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const u = getStoredUser();
    if (!u) {
      router.replace("/login");
      return;
    }
    setUser(u);
    setLoading(false);
  }, [router]);

  if (loading) {
    return <div className="mx-auto max-w-md px-4 py-24 text-center text-ink-muted">{t("common_loading")}</div>;
  }

  function logout() {
    clearAuth();
    router.replace("/");
  }

  const roleColor = user?.role === "owner" ? "owner" : user?.role === "walker" ? "walker" : "sitter";

  return (
    <div className="mx-auto max-w-2xl px-4 py-16 md:py-24">
      <div className={`rounded-3xl bg-${roleColor} p-8 text-white shadow-card md:p-12`}>
        <div className="text-sm font-medium uppercase tracking-wider opacity-80">
          {user?.role}
        </div>
        <h1 className="mt-2 font-display text-3xl font-extrabold md:text-4xl">
          {t("dash_welcome")}, {user?.name?.split(" ")[0] || "you"} 👋
        </h1>
        <p className="mt-3 max-w-md text-white/85">{t("dash_sub")}</p>

        <div className="mt-7 flex flex-wrap gap-3">
          <a
            href="hopetsit://"
            className="rounded-full bg-white px-5 py-2.5 text-sm font-semibold text-ink hover:bg-bg-soft"
          >
            {t("dash_open_app")}
          </a>
          <Link
            href="/download"
            className="rounded-full border border-white/40 px-5 py-2.5 text-sm font-semibold text-white hover:bg-white/10"
          >
            {t("dash_download_app")}
          </Link>
        </div>
      </div>

      <div className="mt-8 rounded-2xl border border-ink/5 bg-white p-6 shadow-card">
        <div className="flex items-center justify-between">
          <div>
            <div className="text-xs uppercase text-ink-soft">Email</div>
            <div className="text-sm font-semibold text-ink">{user?.email}</div>
          </div>
          <button
            onClick={logout}
            className="rounded-full border border-ink/10 px-4 py-2 text-sm font-semibold text-ink hover:border-ink/30"
          >
            {t("dash_logout")}
          </button>
        </div>
      </div>
    </div>
  );
}

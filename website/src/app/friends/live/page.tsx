"use client";

// v23.1 carte unique — Daniel : "sur le site web, UNE SEULE carte : depuis
// /map on a PawFollow (amis/famille en direct), PawSpot (spots
// communautaires) et l'itinéraire, tout réuni ; la page /friends/live est
// fusionnée". Toute la logique amis/famille/socket vit désormais sur
// /map (couche PawFollow) — cette page ne fait plus qu'une redirection
// client immédiate pour les anciens liens, favoris et notifications.

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect } from "react";
import { useT } from "@/lib/i18n/LanguageProvider";

export default function FriendsLiveRedirectPage() {
  const { t } = useT();
  const router = useRouter();

  useEffect(() => {
    router.replace("/map");
  }, [router]);

  // Mini fallback le temps de la redirection (ou si JS désactivé partiel).
  return (
    <div className="mx-auto max-w-5xl px-4 py-24 text-center text-ink-muted">
      <p>{t("friends_live_redirect")}</p>
      <Link
        href="/map"
        className="mt-4 inline-block text-sm font-semibold text-walker underline"
      >
        🗺️ {t("nav_pawmap")}
      </Link>
    </div>
  );
}

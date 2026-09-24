"use client";

// 25/09/2026 — LOT D : fond « à mon animal » du SITE (NORME_DESIGN.md), jumeau
// de celui de l'app : papier peint de pattes et de cœurs teinté à la COULEUR
// DU RÔLE ACTIF (propriétaire orange pâle, gardien bleu pâle, promeneur VERT
// pâle), avec les objets de MON animal (chien = os + balle, chat = poisson +
// pelote, oiseau = plume, lapin = carotte). Visiteur sans compte = pattes.
// Ce composant ne rend RIEN : il pose `data-role` / `data-pet` / `data-wp`
// sur <html>, et `globals.css` fait le reste (masque SVG + variables). Le
// réglage « Mon fond » (auto / pattes / aucun) est celui du compte
// (`preferences.wallpaper`), lu depuis le profil quand il existe.

import { useEffect } from "react";
import { getMyPets, getMyProfile, getStoredUser } from "@/lib/api";

function speciesOf(category: string | undefined): string {
  const c = (category || "").toLowerCase();
  if (/(dog|chien|perro|hund|cane|cão|pies|개|犬)/.test(c)) return "dog";
  if (/(cat|chat|gato|katze|gatto|kot|고양이|猫)/.test(c)) return "cat";
  if (/(bird|oiseau|pájaro|vogel|uccello|pássaro|ptak|새|鳥)/.test(c)) return "bird";
  if (/(rabbit|lapin|conejo|kaninchen|coniglio|coelho|królik|토끼|ウサギ|small|rongeur)/.test(c)) return "rabbit";
  return "";
}

export function RoleWallpaper() {
  useEffect(() => {
    const html = document.documentElement;
    const user = getStoredUser();
    html.dataset.role = user?.role || "";
    html.dataset.pet = "";
    html.dataset.wp = "auto";
    if (!user) return;
    let alive = true;
    (async () => {
      try {
        const profile = await getMyProfile();
        const wp = (profile as unknown as { preferences?: { wallpaper?: string } }).preferences?.wallpaper;
        if (alive && (wp === "paws" || wp === "none" || wp === "auto")) html.dataset.wp = wp;
      } catch { /* pas de profil lisible → auto */ }
      if (user.role !== "owner") return;
      try {
        const pets = await getMyPets();
        if (!alive) return;
        const species = Array.from(new Set(pets.map((p) => speciesOf(p.category)).filter(Boolean)));
        html.dataset.pet = species.length > 1 ? "mix" : species[0] || "";
      } catch { /* pas d'animaux lisibles → pattes */ }
    })();
    return () => { alive = false; };
  }, []);
  return null;
}

export default RoleWallpaper;

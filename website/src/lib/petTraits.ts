// v465 — Daniel : sur le site, le « Caractère des animaux » affichait les clés
// brutes EN (« playful affectionate curious calm ») au lieu du libellé
// localisé. Les traits sont stockés en clés anglaises ; ce helper les traduit
// pour l'AFFICHAGE (le formulaire d'édition garde les clés brutes). Aligné sur
// la map `pet_trait_*` de l'app Flutter (frontend/lib/localization).
const TRAITS: Record<string, Partial<Record<string, string>>> = {
  energetic: { fr: "Énergique", en: "Energetic", es: "Enérgico", de: "Energiegeladen", it: "Energico", pt: "Energético" },
  calm: { fr: "Calme", en: "Calm", es: "Tranquilo", de: "Ruhig", it: "Calmo", pt: "Calmo" },
  playful: { fr: "Joueur", en: "Playful", es: "Juguetón", de: "Verspielt", it: "Giocoso", pt: "Brincalhão" },
  social: { fr: "Sociable", en: "Social", es: "Sociable", de: "Sozial", it: "Socievole", pt: "Sociável" },
  affectionate: { fr: "Affectueux", en: "Affectionate", es: "Cariñoso", de: "Anhänglich", it: "Affettuoso", pt: "Afetuoso" },
  protective: { fr: "Protecteur", en: "Protective", es: "Protector", de: "Beschützend", it: "Protettivo", pt: "Protetor" },
  smart: { fr: "Intelligent", en: "Smart", es: "Inteligente", de: "Klug", it: "Intelligente", pt: "Inteligente" },
  independent: { fr: "Indépendant", en: "Independent", es: "Independiente", de: "Unabhängig", it: "Indipendente", pt: "Independente" },
  shy: { fr: "Timide", en: "Shy", es: "Tímido", de: "Schüchtern", it: "Timido", pt: "Tímido" },
  curious: { fr: "Curieux", en: "Curious", es: "Curioso", de: "Neugierig", it: "Curioso", pt: "Curioso" },
  gentle: { fr: "Doux", en: "Gentle", es: "Dócil", de: "Sanft", it: "Dolce", pt: "Dócil" },
  obedient: { fr: "Obéissant", en: "Obedient", es: "Obediente", de: "Gehorsam", it: "Obbediente", pt: "Obediente" },
};

export function petTraitLabel(key: string, lang: string): string {
  const k = String(key || "").trim().toLowerCase();
  const row = TRAITS[k];
  if (!row) return key; // trait inconnu (ex. saisie libre) → tel quel
  return row[lang] || row.en || key;
}

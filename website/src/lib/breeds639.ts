// 639 (10/11/2026, LEO — CONTRATS §3) — races courantes proposées en SUGGESTION sur la fiche animal et
// dans la demande rapide. Même liste, même ordre et mêmes noms que l'app (frontend/lib/utils/breeds639.dart).
// La race reste un champ libre et facultatif : ces listes ne valident rien, elles aident seulement à taper.
// Nom français si la langue est le français, anglais sinon (comme l'app). Autre espèce = pas de suggestion.

type Breed = { en: string; fr: string };

const DOGS: Breed[] = [
  { en: "Labrador Retriever", fr: "Labrador" },
  { en: "Golden Retriever", fr: "Golden Retriever" },
  { en: "German Shepherd", fr: "Berger allemand" },
  { en: "French Bulldog", fr: "Bouledogue français" },
  { en: "Australian Shepherd", fr: "Berger australien" },
  { en: "Belgian Malinois", fr: "Berger belge malinois" },
  { en: "Border Collie", fr: "Border Collie" },
  { en: "Cavalier King Charles", fr: "Cavalier King Charles" },
  { en: "Chihuahua", fr: "Chihuahua" },
  { en: "Yorkshire Terrier", fr: "Yorkshire Terrier" },
  { en: "Jack Russell Terrier", fr: "Jack Russell" },
  { en: "Beagle", fr: "Beagle" },
  { en: "Poodle", fr: "Caniche" },
  { en: "Dachshund", fr: "Teckel" },
  { en: "Shih Tzu", fr: "Shih Tzu" },
  { en: "Siberian Husky", fr: "Husky sibérien" },
  { en: "Cocker Spaniel", fr: "Cocker" },
  { en: "Staffordshire Bull Terrier", fr: "Staffie" },
  { en: "American Staffordshire Terrier", fr: "American Staff" },
  { en: "Pomeranian", fr: "Spitz nain" },
  { en: "Boxer", fr: "Boxer" },
  { en: "Rottweiler", fr: "Rottweiler" },
  { en: "Bernese Mountain Dog", fr: "Bouvier bernois" },
  { en: "Maltese", fr: "Bichon maltais" },
  { en: "Shiba Inu", fr: "Shiba Inu" },
  { en: "Mixed breed", fr: "Croisé" },
];

const CATS: Breed[] = [
  { en: "Domestic Shorthair", fr: "Européen" },
  { en: "Maine Coon", fr: "Maine Coon" },
  { en: "Bengal", fr: "Bengal" },
  { en: "British Shorthair", fr: "British Shorthair" },
  { en: "Ragdoll", fr: "Ragdoll" },
  { en: "Siamese", fr: "Siamois" },
  { en: "Persian", fr: "Persan" },
  { en: "Sphynx", fr: "Sphynx" },
  { en: "Birman", fr: "Sacré de Birmanie" },
  { en: "Norwegian Forest Cat", fr: "Norvégien" },
  { en: "Siberian", fr: "Sibérien" },
  { en: "Chartreux", fr: "Chartreux" },
  { en: "Russian Blue", fr: "Bleu russe" },
  { en: "Scottish Fold", fr: "Scottish Fold" },
  { en: "Abyssinian", fr: "Abyssin" },
  { en: "Mixed breed", fr: "Croisé" },
];

/** Longueur maximale d'une race envoyée au serveur (CONTRATS §3). */
export const BREED_MAX_639 = 60;

/**
 * Suggestions de races pour une espèce : "Dog" / "chien" → chiens, "Cat" / "chat" → chats, le reste → [].
 * `lang` : "fr" donne les noms français, toute autre langue les noms anglais.
 */
export function breedSuggestions639(species: string | null | undefined, lang: string): string[] {
  const s = String(species || "").trim().toLowerCase();
  const list = s === "dog" || s === "chien" ? DOGS : s === "cat" || s === "chat" ? CATS : [];
  return list.map((b) => (lang === "fr" ? b.fr : b.en));
}

/** Race nettoyée pour l'envoi : espaces réduits, 60 caractères au plus ; "" si rien de saisi. */
export function cleanBreed639(v: string | null | undefined): string {
  return String(v || "").replace(/\s+/g, " ").trim().slice(0, BREED_MAX_639);
}

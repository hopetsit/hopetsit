// 25/09/2026 (PawMap 586, point 8) — « un compte, trois profils » : un
// gardien ou un promeneur a aussi un animal. Réserver (ou écrire à) un
// prestataire se fait TOUJOURS avec le profil PROPRIÉTAIRE : si la session
// est sur un autre rôle, on passe d'abord au profil propriétaire par la route
// existante /users/switch-role (non destructive, crée le profil s'il manque),
// puis on continue.
import { getStoredUser, switchRole } from "@/lib/api";

/** true = le visiteur connecté n'est pas sur son profil propriétaire. */
export function needsOwnerSwitch(): boolean {
  const u = getStoredUser();
  return !!u && u.role !== "owner";
}

/** Est-ce MA fiche (même profil) ? Seul cas sans « Réserver ». */
export function isMyProfile(profileId: string): boolean {
  const u = getStoredUser();
  return !!u && !!profileId && u.id === profileId;
}

/** Passe au profil propriétaire si besoin ; false en cas d'échec. */
export async function ensureOwnerProfile(): Promise<boolean> {
  if (!needsOwnerSwitch()) return true;
  try {
    await switchRole("owner");
    return true;
  } catch {
    return false;
  }
}

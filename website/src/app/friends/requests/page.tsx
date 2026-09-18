"use client";

// v565 (point 29) — route « thème » des e-mails/push `friend_request_received`
// et `family_invitation_received`. La page web /friends affiche les demandes
// reçues en tête : on y renvoie (ou vers l'app sur mobile).

import { AppRoutePage } from "@/components/AppRoutePage";

export default function FriendRequestsRoutePage() {
  return <AppRoutePage appPath="friends/requests" webHref="/friends" redirectAfterMs={1500} />;
}

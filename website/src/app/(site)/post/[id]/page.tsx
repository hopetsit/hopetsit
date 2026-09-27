"use client";

// v565 (point 29) — route « thème » `new_request_nearby`, `post_new`,
// `post_application_eligible` (/post/:id). L'annonce détaillée s'ouvre dans
// l'app ; sur le web, la liste des annonces.

import { AppRoutePage } from "@/components/AppRoutePage";

export default function PostRoutePage({ params }: { params: { id: string } }) {
  const id = String(params?.id || "");
  return <AppRoutePage appPath={`post/${id}`} webHref="/posts" />;
}

// 27/09/2026 — LEO : layout racine des pages écrites en « fr » (HTML servi et
// <html lang> dans cette langue, quel que soit le visiteur). Squelette commun :
// components/RootShell.tsx.
import { RootShell, rootMetadata, rootViewport } from "@/components/RootShell";

export const metadata = rootMetadata;
export const viewport = rootViewport;

export default function Layout({ children }: { children: React.ReactNode }) {
  return (
    <RootShell lang="fr" locked>
      {children}
    </RootShell>
  );
}

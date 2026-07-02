import Link from "next/link";

// v508 — Daniel : « le petit retour Mon espace n'est pas assez visible » →
// vrai bouton pill (blanc, liseré orange, flèche dans un rond) commun à
// toutes les pages internes, à la place du petit texte gris.
export default function BackLink({ href, label }: { href: string; label: string }) {
  return (
    <Link
      href={href}
      className="group inline-flex items-center gap-2.5 rounded-full border border-owner/25 bg-white py-1.5 pl-1.5 pr-4 text-sm font-bold text-ink shadow-sm transition hover:border-owner/50 hover:text-owner hover:shadow-md"
    >
      <span
        aria-hidden
        className="grid h-7 w-7 place-items-center rounded-full bg-owner-light text-owner transition group-hover:-translate-x-0.5"
      >
        ←
      </span>
      {label}
    </Link>
  );
}

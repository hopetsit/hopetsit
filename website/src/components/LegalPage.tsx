// Shared layout for our legal pages (Terms, Privacy, Refund, Imprint).
// Keeps the typography rules and the back-to-top affordance consistent.

import { ReactNode } from "react";

export function LegalPage({ title, lastUpdated, children }: {
  title: string;
  lastUpdated: string;
  children: ReactNode;
}) {
  return (
    <article className="mx-auto max-w-3xl px-4 py-16 md:py-24">
      <h1 className="font-display text-4xl font-extrabold tracking-tight md:text-5xl">
        {title}
      </h1>
      <p className="mt-2 text-sm text-ink-soft">Last updated: {lastUpdated}</p>
      <div className="prose prose-ink mt-10 max-w-none text-ink [&_h2]:mt-10 [&_h2]:text-xl [&_h2]:font-bold [&_h3]:mt-6 [&_h3]:font-semibold [&_p]:mt-3 [&_p]:text-sm [&_p]:leading-relaxed [&_p]:text-ink-muted [&_ul]:mt-3 [&_ul]:list-disc [&_ul]:pl-5 [&_ul]:text-sm [&_ul]:text-ink-muted [&_li]:mt-1.5 [&_a]:text-owner [&_strong]:font-semibold [&_strong]:text-ink">
        {children}
      </div>
    </article>
  );
}

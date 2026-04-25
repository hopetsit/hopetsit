// Inline SVG so we don't need a separate asset to ship the brand mark.
// 32×32 paw silhouette inside a soft rounded square — same orange as the
// app's primary accent. Easy to tweak later.

export function Logo({ size = 36 }: { size?: number }) {
  return (
    <svg
      xmlns="http://www.w3.org/2000/svg"
      width={size}
      height={size}
      viewBox="0 0 64 64"
      aria-hidden="true"
    >
      <rect width="64" height="64" rx="14" fill="#EF4324" />
      <g fill="#fff">
        <ellipse cx="22" cy="26" rx="5" ry="6" />
        <ellipse cx="42" cy="26" rx="5" ry="6" />
        <ellipse cx="14" cy="36" rx="4" ry="5" />
        <ellipse cx="50" cy="36" rx="4" ry="5" />
        <path d="M32 34c-7 0-13 5-13 12 0 4 3 7 7 7 2 0 4-1 6-1s4 1 6 1c4 0 7-3 7-7 0-7-6-12-13-12z" />
      </g>
    </svg>
  );
}

export function LogoWithText({ size = 30 }: { size?: number }) {
  return (
    <span className="inline-flex items-center gap-2 font-display font-extrabold text-ink">
      <Logo size={size} />
      <span className="text-[20px] tracking-tight">
        Ho<span className="text-owner">Pet</span>Sit
      </span>
    </span>
  );
}

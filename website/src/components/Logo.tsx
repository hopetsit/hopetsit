// Official HoPetSit brand logo — copied from frontend/assets/brand/web/logo-orange.svg
// (the exact same asset shipped with the mobile app). Served from /public/logo.svg
// so it can be cached by the CDN, used as og:image and as favicon.

export function Logo({ size = 36 }: { size?: number }) {
  return (
    // eslint-disable-next-line @next/next/no-img-element
    <img
      src="/logo.svg"
      alt="HoPetSit logo"
      width={size}
      height={size}
      className="rounded-[20%]"
      style={{ width: size, height: size }}
    />
  );
}

export function LogoWithText({ size = 32 }: { size?: number }) {
  return (
    <span className="inline-flex items-center gap-2 font-display font-extrabold text-ink">
      <Logo size={size} />
      <span className="text-[20px] tracking-tight">
        Ho<span className="text-owner">Pet</span>Sit
      </span>
    </span>
  );
}

import type { Config } from "tailwindcss";

// HoPetSit brand palette — same accents as the mobile app.
const config: Config = {
  content: ["./src/**/*.{ts,tsx}"],
  // Brand role colours are sometimes built dynamically (e.g. `bg-${role}`) so
  // we whitelist them — Tailwind would otherwise purge them at build time.
  safelist: [
    "bg-owner", "bg-owner-light", "bg-owner-dark",
    "bg-sitter", "bg-sitter-light", "bg-sitter-dark",
    "bg-walker", "bg-walker-light", "bg-walker-dark",
    "text-owner", "text-sitter", "text-walker",
    "text-owner-dark", "text-sitter-dark", "text-walker-dark",
    "border-owner", "border-sitter", "border-walker",
    "ring-owner", "ring-sitter", "ring-walker",
    // v23.1 part 146 — variantes avec opacité utilisées dynamiquement dans
    // les pages portées (profile / pets / bookings / sitter-setup / book).
    "bg-owner/5", "bg-sitter/5", "bg-walker/5",
    "bg-owner/20", "bg-sitter/20", "bg-walker/20",
    "focus:border-owner", "focus:border-sitter", "focus:border-walker",
    "focus:ring-owner/20", "focus:ring-sitter/20", "focus:ring-walker/20",
    "ring-owner/20", "ring-sitter/20", "ring-walker/20",
  ],
  theme: {
    extend: {
      colors: {
        owner:  { DEFAULT: "#EF4324", light: "#FEE7E1", dark: "#C03318" },
        sitter: { DEFAULT: "#1A73E8", light: "#E3EFFE", dark: "#0E5BC0" },
        walker: { DEFAULT: "#16A34A", light: "#DEF7E5", dark: "#0F7C37" },
        ink:    { DEFAULT: "#111827", muted: "#6B7280", soft: "#9CA3AF" },
        bg:     { DEFAULT: "#FFFFFF", soft: "#F9FAFB", panel: "#F3F4F6" },
      },
      fontFamily: {
        sans: ["Inter", "system-ui", "Segoe UI", "Helvetica", "Arial", "sans-serif"],
        display: ["Inter", "system-ui", "sans-serif"],
      },
      boxShadow: {
        card: "0 4px 16px -4px rgba(15, 23, 42, 0.08)",
        cta:  "0 8px 24px -8px rgba(239, 67, 36, 0.45)",
      },
      borderRadius: {
        xl: "14px",
        "2xl": "20px",
      },
    },
  },
  plugins: [],
};

export default config;

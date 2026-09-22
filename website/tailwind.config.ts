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
        owner:  { DEFAULT: "#C92A12", light: "#FBE9E5", dark: "#9E1F0B" },
        sitter: { DEFAULT: "#1A73E8", light: "#E3EFFE", dark: "#0E5BC0" },
        walker: { DEFAULT: "#16A34A", light: "#DEF7E5", dark: "#0F7C37" },
        // v577 — Daniel, 22/09 : « aucun gris nulle part », et la règle vaut
        // aussi pour le site. Les neutres ne sont plus des gris froids mais
        // des encres CHAUDES tirées du rouge de marque (teinte ~14°). Les
        // contrastes restent au-dessus des seuils : encre 17,4:1 sur blanc,
        // muted 7,3:1, soft 4,8:1.
        ink:    { DEFAULT: "#231715", muted: "#6E4F48", soft: "#8A6B64",
                  deep: "#2A1B18", line: "#EADFDC" },
        bg:     { DEFAULT: "#FFFFFF", soft: "#FDF8F7", panel: "#FAEFEC" },
      },
      // v577 — le preflight Tailwind pose #E5E7EB (gris froid) sur toutes les
      // bordures. On le remplace par la ligne chaude de la palette.
      borderColor: {
        DEFAULT: "#EADFDC",
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

import type { Metadata } from "next";
import Link from "@/components/SiteLink";
import { TrackedLink } from "@/components/TrackedLink";
import { RECRUIT_CITIES, RECRUIT_PATH_PREFIX, type RecruitCity } from "@/lib/recruit-cities";

// 09/11/2026 (Bob, semaine 46) — même trou que /devenir-petsitter (FR, 26/10)
// et /become-a-pet-sitter (EN, 02/11) : /ser-cuidador-de-mascotas/<ciudad> es
// una red de 16 páginas ya en línea (España — prioridad n.º 2 de Daniel,
// 20/09 : « las ciudades ya existen, ninguna página nueva, solo hacerlas
// indexar »), pero /ser-cuidador-de-mascotas SIN ciudad daba 404 : ninguna de
// las páginas ya indexadas enlazaba hacia esta red salvo su propia página
// gemela. Ninguna ciudad nueva, ningún idioma nuevo — solo el hub que
// faltaba para una red ya existente (regla SEO del 20/09 : « enlazar lo
// existente en vez de ampliar »).
export const metadata: Metadata = {
  title: "Ser cuidador de mascotas — gana dinero cuidando animales | HoPetSit",
  description:
    "Fija tus tarifas, elige tus servicios (cuidado, visitas, paseos) y cobra con seguridad. Conviértete en cuidador de mascotas o paseador de perros con HoPetSit — inscripción gratuita, disponible en toda España.",
  alternates: { canonical: "https://www.hopetsit.com/ser-cuidador-de-mascotas" },
};

const STEPS = [
  {
    n: "1",
    t: "Crea tu perfil gratis",
    p: "Foto, presentación, servicios (cuidado en casa, visitas, paseos) y TUS tarifas — tú decides.",
  },
  {
    n: "2",
    t: "Verifica tu identidad",
    p: "5 minutos en la app. La insignia ✓ da confianza a los dueños: los perfiles verificados reciben muchas más solicitudes.",
  },
  {
    n: "3",
    t: "Recibe solicitudes y chatea",
    p: "Los dueños cerca de ti te contactan por chat. Solo aceptas lo que te conviene.",
  },
  {
    n: "4",
    t: "Cobra con seguridad",
    p: "El pago queda retenido en la app al reservar y se transfiere a tu cuenta cuando termina el servicio. Cero impagos.",
  },
];

const FAQ = [
  {
    q: "¿Cuánto puede ganar un cuidador de mascotas?",
    a: "Depende de tu ciudad y de tus propias tarifas — te quedas el 100 % de tu precio, la comisión del servicio la paga el dueño.",
  },
  {
    q: "¿Necesito un título o un estatus especial?",
    a: "No se necesita ningún título para empezar en HoPetSit — hay que querer a los animales, ser de confianza y tener 18 años o más. Para una actividad regular y remunerada, infórmate sobre el régimen adecuado (autónomo) según tu comunidad.",
  },
  {
    q: "¿La inscripción cuesta algo?",
    a: "No, la inscripción y el perfil son gratuitos. Solo la verificación de identidad (insignia ✓, muy recomendable) tiene un coste pequeño.",
  },
  {
    q: "¿Cómo protege el seguimiento GPS también al cuidador?",
    a: "Durante un paseo, el seguimiento PawFollow demuestra que el servicio se realizó de verdad, desde la recogida hasta la entrega — transparencia para el dueño, tranquilidad para ti.",
  },
  {
    q: "¿Está HoPetSit disponible en mi ciudad?",
    a: "HoPetSit está disponible en toda España. Las ciudades de abajo tienen su propia página, pero puedes crear tu perfil estés donde estés.",
  },
];

const ES_CITIES = RECRUIT_CITIES.filter(
  (c) => c.lang === "es" && c.slug !== "madrid" && c.slug !== "barcelona",
);

function Chips({ cities }: { cities: RecruitCity[] }) {
  return (
    <ul className="mt-4 flex flex-wrap gap-2">
      {cities.map((c) => (
        <li key={c.slug}>
          <TrackedLink
            href={`${RECRUIT_PATH_PREFIX.es}/${c.slug}`}
            label="maillage"
            className="inline-block rounded-full bg-bg-soft px-3.5 py-2 text-sm font-medium text-ink transition hover:bg-sitter-light hover:text-sitter-dark max-lg:py-3"
          >
            {c.name}
          </TrackedLink>
        </li>
      ))}
    </ul>
  );
}

export default function SerCuidadorDeMascotasPage() {
  const jsonLd = {
    "@context": "https://schema.org",
    "@graph": [
      { "@type": "WebPage", name: "Ser cuidador de mascotas", inLanguage: "es" },
      {
        "@type": "FAQPage",
        mainEntity: FAQ.map((f) => ({
          "@type": "Question",
          name: f.q,
          acceptedAnswer: { "@type": "Answer", text: f.a },
        })),
      },
    ],
  };

  return (
    <div className="mx-auto max-w-3xl px-4 py-16 md:py-24">
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
      />
      <nav aria-label="Migas de pan" className="text-xs font-medium text-ink-soft">
        <ol className="flex flex-wrap items-center gap-x-1.5 gap-y-1">
          <li>
            <TrackedLink href="/" label="maillage" className="underline-offset-4 hover:text-owner-dark hover:underline">Inicio</TrackedLink>
          </li>
          <li aria-hidden="true">›</li>
          <li aria-current="page" className="text-ink">Ser cuidador de mascotas</li>
        </ol>
      </nav>
      <p className="mt-3 text-sm font-semibold text-sitter-dark">España</p>
      <h1 className="mt-1.5 font-display text-[1.6rem] font-extrabold leading-[1.15] tracking-tight text-ink md:mt-2 md:text-4xl">
        Conviértete en cuidador de mascotas — y cobra por querer a los animales
      </h1>
      <p className="mt-4 text-lg leading-relaxed text-ink-muted">
        ¿Estudiante, en teletrabajo, jubilado o simplemente amante de los
        animales? Dueños de perros y gatos cerca de ti buscan a alguien de
        confianza mientras trabajan o viajan. HoPetSit os pone en contacto —
        tú fijas tus tarifas, eliges tus servicios, cobras con seguridad.
      </p>

      <div className="mt-8 flex flex-wrap gap-3">
        {["💶 Tus tarifas, tus reglas", "📅 Tú eliges tus horarios", "✓ Insignia verificada", "🔒 Pago garantizado"].map((b) => (
          <span key={b} className="rounded-full border border-ink/10 bg-white px-4 py-2 text-sm font-semibold text-ink shadow-card">
            {b}
          </span>
        ))}
      </div>

      <h2 className="mt-14 font-display text-2xl font-extrabold text-ink">
        Cómo funciona
      </h2>
      <ol className="mt-6 space-y-4">
        {STEPS.map((s) => (
          <li key={s.n} className="flex gap-5 rounded-2xl border border-ink/5 bg-white p-6 shadow-card">
            <div className="grid h-12 w-12 shrink-0 place-items-center rounded-2xl bg-sitter-light text-lg font-extrabold text-sitter-dark">
              {s.n}
            </div>
            <div>
              <h3 className="text-base font-bold text-ink">{s.t}</h3>
              <p className="mt-1.5 text-sm leading-relaxed text-ink-muted">{s.p}</p>
            </div>
          </li>
        ))}
      </ol>

      <h2 className="mt-14 font-display text-2xl font-extrabold text-ink">Elige tu ciudad</h2>
      <p className="mt-2 text-sm leading-relaxed text-ink-muted">
        Cada ciudad tiene su propia página con lo que piden los dueños locales.
      </p>
      <ul className="mt-4 flex flex-wrap gap-2">
        <li>
          <TrackedLink
            href={`${RECRUIT_PATH_PREFIX.es}/madrid`}
            label="maillage"
            className="inline-block rounded-full bg-sitter px-4 py-2.5 text-sm font-bold text-white transition hover:bg-sitter-dark max-lg:py-3"
          >
            Madrid
          </TrackedLink>
        </li>
        <li>
          <TrackedLink
            href={`${RECRUIT_PATH_PREFIX.es}/barcelona`}
            label="maillage"
            className="inline-block rounded-full bg-sitter px-4 py-2.5 text-sm font-bold text-white transition hover:bg-sitter-dark max-lg:py-3"
          >
            Barcelona
          </TrackedLink>
        </li>
      </ul>

      <h3 className="mt-8 text-sm font-bold text-ink-muted">Más ciudades</h3>
      <Chips cities={ES_CITIES} />

      <h2 className="mt-14 font-display text-2xl font-extrabold text-ink">
        Preguntas frecuentes
      </h2>
      <div className="mt-6 space-y-4">
        {FAQ.map((f) => (
          <div key={f.q} className="rounded-2xl border border-ink/5 bg-white p-5 shadow-card">
            <h3 className="font-bold text-ink">{f.q}</h3>
            <p className="mt-2 text-sm leading-relaxed text-ink-muted">{f.a}</p>
          </div>
        ))}
      </div>

      <div className="mt-14 rounded-3xl bg-sitter-light p-8 text-center">
        <h2 className="font-display text-2xl font-extrabold text-ink">
          Los primeros cuidadores se quedan los mejores barrios
        </h2>
        <p className="mx-auto mt-2 max-w-md text-sm text-ink-muted">
          HoPetSit todavía está creciendo en la mayoría de estas ciudades: poca
          competencia entre cuidadores y cada semana llegan nuevos dueños. Es
          el mejor momento para crear tu perfil.
        </p>
        <Link
          href="/download"
          className="mt-5 inline-block rounded-full bg-sitter px-7 py-3 text-sm font-bold text-white"
        >
          Crear mi perfil gratis
        </Link>
      </div>

      <section className="mt-12 border-t border-owner/15 pt-6">
        <p className="text-center text-sm md:text-left">
          <TrackedLink href="/cuidado-de-mascotas/madrid" label="maillage" className="font-semibold text-owner-dark underline-offset-4 hover:underline">
            ¿Buscas un cuidador? Encuéntralo en Madrid →
          </TrackedLink>
        </p>
        <p className="mt-3 text-center text-sm md:text-left">
          <TrackedLink href="/villes" label="maillage" className="font-semibold text-sitter-dark underline-offset-4 hover:underline">
            Todas las ciudades →
          </TrackedLink>
        </p>
      </section>
    </div>
  );
}

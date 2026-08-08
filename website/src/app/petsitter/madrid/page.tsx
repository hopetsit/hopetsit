import type { Metadata } from "next";
import { CityPage } from "../_cityPage";

export const metadata: Metadata = {
  title: "Cuidador de mascotas en Madrid — paseos y cuidado | HoPetSit",
  description:
    "Encuentra un cuidador de perros y gatos verificado en Madrid. Reseñas reales, pago seguro y seguimiento GPS de cada paseo. Gratis en HoPetSit.",
  alternates: { canonical: "https://www.hopetsit.com/petsitter/madrid" },
};

export default function MadridPage() {
  return (
    <CityPage
      c={{
        city: "Madrid",
        lang: "es",
        h1: "Cuidador de mascotas en Madrid: cuidado de perros, gatos y paseos",
        intro:
          "Entre el trabajo, los findes y las vacaciones, no siempre puedes estar con tu mascota. HoPetSit te conecta con cuidadores y paseadores de perros verificados en Madrid, de Malasaña a Chamberí, para un cuidado con total confianza.",
        servicesTitle: "Servicios cerca de ti",
        services: [
          {
            icon: "🏠",
            t: "Cuidado a domicilio",
            p: "Tu mascota se queda en su entorno, o en casa de un cuidador apasionado de tu barrio.",
          },
          {
            icon: "🚶",
            t: "Paseo de perros",
            p: "Un paseo por El Retiro o Madrid Río mientras estás en la oficina — con seguimiento GPS.",
          },
          {
            icon: "🔑",
            t: "Visitas a domicilio",
            p: "Comida, arenero, mimos y medicación para tu gato que prefiere quedarse en casa.",
          },
        ],
        whyTitle: "Por qué los madrileños eligen HoPetSit",
        why: [
          "Perfiles con identidad verificada y reseñas reales de reservas completadas.",
          "Seguimiento GPS PawFollow: mira el paseo de tu perro en directo en el mapa.",
          "Pago seguro en la app, liberado solo cuando confirmas el servicio.",
          "PawMap: parques, cafés y veterinarios pet-friendly de Madrid, compartidos por la comunidad.",
          "App gratuita, disponible en español y en 6 idiomas.",
        ],
        faqTitle: "Preguntas frecuentes en Madrid",
        faq: [
          {
            q: "¿Cuánto cuesta un cuidador de mascotas en Madrid?",
            a: "Calcula entre 15 y 25 € al día por el cuidado a domicilio en Madrid, y de 10 a 18 € por paseo. Cada cuidador fija libremente su tarifa en su perfil.",
          },
          {
            q: "¿Cómo sé que el cuidador es de confianza?",
            a: "Los perfiles de HoPetSit muestran verificación de identidad y reseñas que solo se pueden dejar tras reservas reales. Puedes chatear antes de confirmar.",
          },
          {
            q: "¿Puedo seguir el paseo de mi perro?",
            a: "Sí — con PawFollow ves la posición del paseador en directo en el mapa durante todo el paseo.",
          },
        ],
        ctaTitle: "Encuentra tu cuidador en Madrid",
        ctaBody:
          "Descarga HoPetSit gratis, compara perfiles cerca de ti y reserva en minutos.",
        ctaButton: "Descargar la app HoPetSit",
      }}
    />
  );
}

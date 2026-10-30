import type { Metadata, Viewport } from "next";
import {
  Caveat,
  Fraunces,
  JetBrains_Mono,
  Plus_Jakarta_Sans,
} from "next/font/google";
import "./globals.css";

const fontSans = Plus_Jakarta_Sans({
  variable: "--font-sans-ui",
  subsets: ["latin"],
  weight: ["400", "500", "600", "700"],
  display: "swap",
});

const fontSerif = Fraunces({
  variable: "--font-serif-card",
  subsets: ["latin"],
  weight: ["400", "500", "600"],
  display: "swap",
});

const fontHand = Caveat({
  variable: "--font-hand-card",
  subsets: ["latin"],
  weight: ["500", "600", "700"],
  display: "swap",
});

const fontMono = JetBrains_Mono({
  variable: "--font-mono-card",
  subsets: ["latin"],
  weight: ["400", "500"],
  display: "swap",
});

export const metadata: Metadata = {
  title: "Amodoro",
  description: "Nuestro espacio compartido diario: tarjetas, actividades, música y películas.",
  applicationName: "Amodoro",
  manifest: "/manifest.webmanifest",
  appleWebApp: {
    capable: true,
    title: "Amodoro",
    statusBarStyle: "default",
  },
};

export const viewport: Viewport = {
  themeColor: "#FCF9F5",
  width: "device-width",
  initialScale: 1,
  viewportFit: "cover",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html
      lang="es"
      className={`${fontSans.variable} ${fontSerif.variable} ${fontHand.variable} ${fontMono.variable} h-full`}
    >
      <body className="min-h-full flex flex-col antialiased selection:bg-[#F2B8B5] selection:text-[#410E0B]">
        {children}
      </body>
    </html>
  );
}

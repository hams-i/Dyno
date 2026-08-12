import type { Metadata } from "next";
import { LocaleProvider } from "@/context/locale-context";
import { ThemeProvider } from "@/components/theme-provider";
import "./globals.css";

export const metadata: Metadata = {
  title: "Dyno Island — Dynamic Island for macOS",
  description:
    "Now Playing, clipboard, timer and counter in a morphing Dynamic Island for the Mac notch.",
  icons: {
    icon: "/logo-256.png",
    apple: "/logo.png",
  },
  openGraph: {
    title: "Dyno Island",
    description: "Dynamic Island for your Mac notch.",
    url: "https://github.com/hams-i/Dyno",
    images: [{ url: "/logo.png" }],
  },
};

export const viewport = {
  width: "device-width",
  initialScale: 1,
  viewportFit: "cover" as const,
  themeColor: [
    { media: "(prefers-color-scheme: light)", color: "#f5f5f7" },
    { media: "(prefers-color-scheme: dark)", color: "#000000" },
  ],
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className="dark" suppressHydrationWarning>
      <body className="min-h-screen antialiased">
        <ThemeProvider>
          <LocaleProvider>{children}</LocaleProvider>
        </ThemeProvider>
      </body>
    </html>
  );
}

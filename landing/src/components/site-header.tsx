"use client";

import Link from "next/link";
import { Moon, Sun } from "lucide-react";
import { useTheme } from "next-themes";
import { useSyncExternalStore } from "react";
import { DynoLogo } from "@/components/dyno-logo";
import { useLocale } from "@/context/locale-context";
import type { Locale } from "@/lib/i18n";
import { cn } from "@/lib/utils";

const subscribe = () => () => {};
const getSnapshot = () => true;
const getServerSnapshot = () => false;

function GitHubIcon({ className }: { className?: string }) {
  return (
    <svg
      viewBox="0 0 24 24"
      fill="currentColor"
      aria-hidden
      className={className}
    >
      <path d="M12 2C6.477 2 2 6.484 2 12.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.531 1.032 1.531 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0 1 12 6.844a9.59 9.59 0 0 1 2.504.337c1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.202 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.943.359.309.678.92.678 1.855 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.02 10.02 0 0 0 22 12.017C22 6.484 17.522 2 12 2Z" />
    </svg>
  );
}

export function SiteHeader() {
  const { t, locale, setLocale } = useLocale();
  const { theme, setTheme } = useTheme();
  const mounted = useSyncExternalStore(subscribe, getSnapshot, getServerSnapshot);

  return (
    <header
      className="sticky top-0 z-50 border-b border-black/[0.06] bg-white/72 backdrop-blur-2xl backdrop-saturate-150 dark:border-white/[0.06] dark:bg-black/55"
    >
      <div className="mx-auto flex h-[52px] max-w-6xl items-center gap-2 px-3 sm:gap-4 sm:px-6">
        <Link
          href="/"
          className="group inline-flex min-w-0 items-center gap-2 sm:gap-2.5"
        >
          <DynoLogo size={28} priority className="shadow-none" />
          <span className="truncate text-[14px] font-semibold tracking-[-0.02em] text-black sm:text-[15px] dark:text-white">
            {t.brand}
          </span>
        </Link>

        <div className="ml-auto flex items-center gap-1 sm:gap-1.5">
          <div className="flex items-center rounded-full border border-black/8 bg-black/[0.04] p-0.5 dark:border-white/10 dark:bg-white/[0.06]">
            <span className="sr-only">{t.controls.language}</span>
            {(["en", "tr"] as Locale[]).map((code) => (
              <button
                key={code}
                type="button"
                onClick={() => setLocale(code)}
                className={cn(
                  "min-h-8 rounded-full px-2.5 py-1 text-[11px] font-semibold uppercase tracking-wide transition-all active:scale-95",
                  locale === code
                    ? "bg-dyno-accent text-dyno-accent-fg shadow-sm"
                    : "text-muted-foreground active:text-foreground sm:hover:text-foreground",
                )}
              >
                {code}
              </button>
            ))}
          </div>

          {mounted && (
            <div className="flex items-center rounded-full border border-black/8 bg-black/[0.04] p-0.5 dark:border-white/10 dark:bg-white/[0.06]">
              <span className="sr-only">{t.controls.theme}</span>
              {[
                { id: "light", icon: Sun, label: t.controls.themeLight },
                { id: "dark", icon: Moon, label: t.controls.themeDark },
              ].map(({ id, icon: Icon, label }) => (
                <button
                  key={id}
                  type="button"
                  title={label}
                  aria-label={label}
                  onClick={() => setTheme(id)}
                  className={cn(
                    "flex size-8 items-center justify-center rounded-full transition-all active:scale-95 sm:size-auto sm:p-1.5",
                    theme === id
                      ? "bg-dyno-accent text-dyno-accent-fg shadow-sm"
                      : "text-muted-foreground active:text-foreground sm:hover:text-foreground",
                  )}
                >
                  <Icon className="size-3.5" />
                </button>
              ))}
            </div>
          )}

          <a
            href="https://github.com/hams-i/Dyno"
            target="_blank"
            rel="noreferrer"
            className="flex size-9 items-center justify-center text-dyno-accent sm:size-auto"
            aria-label="GitHub"
          >
            <GitHubIcon className="size-5 sm:size-6" />
          </a>
        </div>
      </div>
    </header>
  );
}

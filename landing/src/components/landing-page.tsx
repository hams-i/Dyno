"use client";

import { useRef, useState } from "react";
import { AnimatePresence, motion } from "framer-motion";
import { BlurFade } from "@/components/ui/blur-fade";
import { AppleButton } from "@/components/ui/apple-button";
import { ShimmerButton } from "@/components/ui/shimmer-button";
import { DynoLogo } from "@/components/dyno-logo";
import {
  DynamicIslandDemo,
  type IslandTab,
} from "@/components/island/dynamic-island-demo";
import { SiteHeader } from "@/components/site-header";
import { useLocale } from "@/context/locale-context";

const featureTabs: IslandTab[] = ["media", "clipboard", "timer", "counter"];

const featureSlide = {
  enter: (dir: number) => ({
    x: dir > 0 ? 28 : -28,
    opacity: 0,
  }),
  center: {
    x: 0,
    opacity: 1,
  },
  exit: (dir: number) => ({
    x: dir > 0 ? -28 : 28,
    opacity: 0,
  }),
};

export function LandingPage() {
  const { t } = useLocale();
  const [islandTab, setIslandTab] = useState<IslandTab>("media");
  const [tabDirection, setTabDirection] = useState(0);
  const prevTabRef = useRef<IslandTab>("media");
  const feature = t.features.byTab[islandTab];

  const handleTabChange = (next: IslandTab) => {
    const from = featureTabs.indexOf(prevTabRef.current);
    const to = featureTabs.indexOf(next);
    if (from !== to) {
      setTabDirection(to > from ? 1 : -1);
    }
    prevTabRef.current = next;
    setIslandTab(next);
  };

  return (
    <div className="relative min-h-dvh overflow-x-hidden bg-background text-foreground">
      <div
        className="pointer-events-none absolute inset-0 bg-[radial-gradient(ellipse_80%_50%_at_50%_-10%,color-mix(in_oklab,var(--dyno-accent)_14%,transparent),transparent_55%)]"
      />

      <SiteHeader />

      <main>
        <section className="relative mx-auto flex max-w-6xl flex-col items-center px-4 pt-8 text-center sm:px-6 sm:pt-16">
          <BlurFade delay={0.02} inView={false}>
            <div className="inline-flex items-center gap-2.5 sm:gap-3.5">
              <DynoLogo size={40} priority className="shadow-md" />
              <h1 className="text-[24px] font-semibold tracking-[-0.03em] text-black sm:text-[34px] dark:text-white">
                {t.brand}
              </h1>
            </div>
          </BlurFade>
        </section>

        <section id="demo" className="relative mx-auto max-w-6xl px-3 pt-8 sm:px-6 sm:pt-12">
          <BlurFade delay={0.06} inView={false}>
            <DynamicIslandDemo tab={islandTab} onTabChange={handleTabChange} />
          </BlurFade>
        </section>

        <section
          id="features"
          className="mx-auto max-w-6xl px-3 py-14 text-left sm:px-6 sm:py-20"
        >
          <BlurFade>
            <div className="relative max-w-2xl overflow-hidden">
              <AnimatePresence mode="wait" custom={tabDirection}>
                <motion.div
                  key={islandTab}
                  custom={tabDirection}
                  variants={featureSlide}
                  initial="enter"
                  animate="center"
                  exit="exit"
                  transition={{
                    type: "spring",
                    stiffness: 520,
                    damping: 36,
                    mass: 0.65,
                  }}
                >
                  <h2 className="apple-section-title text-[28px] font-semibold text-dyno-accent sm:text-[32px]">
                    {feature.title}
                  </h2>
                  <p className="mt-3 text-[15px] leading-relaxed text-muted-foreground">
                    {feature.desc}
                  </p>
                  <ul className="mt-6 space-y-2.5">
                    {feature.points.map((point) => (
                      <li
                        key={point}
                        className="flex items-start gap-2.5 text-[13px] leading-relaxed text-foreground/85"
                      >
                        <span className="mt-1.5 size-1.5 shrink-0 rounded-full bg-dyno-accent" />
                        {point}
                      </li>
                    ))}
                  </ul>
                </motion.div>
              </AnimatePresence>
            </div>
          </BlurFade>
        </section>

        <section
          id="download"
          className="mx-auto max-w-6xl px-4 pb-16 text-center sm:px-6 sm:pb-24"
        >
          <BlurFade>
            <div className="mx-auto flex max-w-2xl flex-col items-center">
              <p className="mb-4 inline-flex items-center rounded-full border border-dyno-accent/30 bg-dyno-accent/10 px-3.5 py-1 text-[11px] font-semibold tracking-wide text-dyno-accent">
                {t.hero.badge}
              </p>
              <h2 className="apple-hero text-[32px] font-semibold sm:text-[48px]">
                {t.hero.title}{" "}
                <span className="text-dyno-accent">{t.hero.titleAccent}</span>
              </h2>
              <p className="mt-4 text-[16px] leading-relaxed text-muted-foreground sm:text-[17px] sm:leading-8">
                {t.hero.subtitle}
              </p>
              <div className="mt-7 flex flex-wrap items-center justify-center gap-3">
                <a
                  href="https://github.com/hams-i/Dyno"
                  target="_blank"
                  rel="noreferrer"
                >
                  <ShimmerButton
                    shimmerColor="var(--dyno-accent)"
                    background="var(--dyno-accent)"
                    className="px-6 py-2.5 text-sm font-bold text-dyno-accent-fg shadow-[0_8px_28px_-8px_var(--dyno-accent-glow)]"
                  >
                    {t.hero.cta}
                  </ShimmerButton>
                </a>
                <AppleButton
                  href="https://github.com/hams-i/Dyno"
                  variant="secondary"
                  size="md"
                >
                  {t.hero.ctaSecondary}
                </AppleButton>
              </div>
            </div>
          </BlurFade>
        </section>
      </main>

      <footer className="border-t border-black/[0.06] py-8 dark:border-white/[0.06]">
        <div className="mx-auto flex max-w-6xl flex-col items-center gap-3 px-4 text-center text-[11px] text-muted-foreground sm:px-6">
          <DynoLogo size={28} />
          <p>
            {t.brand} · {t.footer.license} · {t.footer.made}
          </p>
        </div>
      </footer>
    </div>
  );
}

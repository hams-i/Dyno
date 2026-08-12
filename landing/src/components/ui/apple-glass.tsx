import type { ReactNode } from "react";
import { cn } from "@/lib/utils";

type AppleGlassProps = {
  children: ReactNode;
  className?: string;
  as?: "div" | "section" | "header" | "article";
};

/** macOS vibrancy / glass panel */
export function AppleGlass({
  children,
  className,
  as: Tag = "div",
}: AppleGlassProps) {
  return (
    <Tag
      className={cn(
        "rounded-2xl border border-black/[0.06] bg-white/72 shadow-sm backdrop-blur-2xl backdrop-saturate-150",
        "dark:border-white/[0.08] dark:bg-white/[0.06] dark:shadow-[0_8px_32px_rgba(0,0,0,0.45)]",
        className,
      )}
    >
      {children}
    </Tag>
  );
}

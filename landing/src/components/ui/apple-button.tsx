import type { ReactNode } from "react";
import { cn } from "@/lib/utils";

type AppleButtonProps = {
  children: ReactNode;
  className?: string;
  href?: string;
  onClick?: () => void;
  variant?: "primary" | "secondary" | "ghost";
  size?: "sm" | "md" | "lg";
};

const variants = {
  primary:
    "bg-dyno-accent text-dyno-accent-fg shadow-[0_1px_0_rgba(255,255,255,0.22)_inset,0_8px_24px_-8px_var(--dyno-accent-glow)] hover:brightness-105 active:scale-[0.98]",
  secondary:
    "border border-black/10 bg-white/80 text-foreground backdrop-blur-md hover:bg-white dark:border-white/12 dark:bg-white/8 dark:text-white dark:hover:bg-white/12",
  ghost:
    "text-muted-foreground hover:bg-black/5 hover:text-foreground dark:hover:bg-white/8 dark:hover:text-white",
};

const sizes = {
  sm: "px-3.5 py-1.5 text-xs font-semibold",
  md: "px-5 py-2.5 text-sm font-semibold",
  lg: "px-6 py-3 text-base font-semibold",
};

export function AppleButton({
  children,
  className,
  href,
  onClick,
  variant = "primary",
  size = "md",
}: AppleButtonProps) {
  const cls = cn(
    "inline-flex items-center justify-center rounded-full transition-all duration-200 ease-out",
    variants[variant],
    sizes[size],
    className,
  );

  if (href) {
    return (
      <a href={href} className={cls} target={href.startsWith("http") ? "_blank" : undefined} rel={href.startsWith("http") ? "noreferrer" : undefined}>
        {children}
      </a>
    );
  }

  return (
    <button type="button" onClick={onClick} className={cls}>
      {children}
    </button>
  );
}

import Image from "next/image";
import { cn } from "@/lib/utils";

type DynoLogoProps = {
  size?: number;
  className?: string;
  priority?: boolean;
};

/** Dyno Island AppIcon — squircle mark used across the landing. */
export function DynoLogo({ size = 32, className, priority }: DynoLogoProps) {
  return (
    <Image
      src="/logo.png"
      alt="Dyno Island"
      width={size}
      height={size}
      priority={priority}
      className={cn("shrink-0 rounded-[22%] shadow-sm", className)}
    />
  );
}

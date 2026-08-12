"use client";

import Image from "next/image";
import type { ReactNode } from "react";
import { cn } from "@/lib/utils";

type MacNotchFrameProps = {
  children: ReactNode;
  className?: string;
  onBackdropPointerDown?: () => void;
};

/**
 * Mac ekran — alt border yok; alt kenar sayfa zeminine mask ile erir.
 * Mobilde parent scale ile küçültür; layout sabit kalır.
 */
export function MacNotchFrame({
  children,
  className,
  onBackdropPointerDown,
}: MacNotchFrameProps) {
  return (
    <div className={cn("relative w-full select-none", className)}>
      <div className="rounded-t-[22px] border-x-[3px] border-t-[3px] border-b-0 border-[#3a3a3c] bg-[#3a3a3c] dark:border-[#4a4a4e] dark:bg-[#4a4a4e]">
        <div className="rounded-t-[19px] border-x-[1.5px] border-t-[1.5px] border-b-0 border-[#0c0c0e] bg-[#0c0c0e]">
          <div
            className="relative min-h-[400px] overflow-hidden rounded-t-[17px]"
            style={{
              maskImage:
                "linear-gradient(to bottom, #000 0%, #000 58%, transparent 100%)",
              WebkitMaskImage:
                "linear-gradient(to bottom, #000 0%, #000 58%, transparent 100%)",
            }}
            onPointerDown={onBackdropPointerDown}
          >
            <Image
              src="/wallpaper.jpg"
              alt=""
              fill
              priority
              sizes="720px"
              className="pointer-events-none object-cover object-[center_30%]"
              draggable={false}
            />
          </div>
        </div>
      </div>

      <div className="absolute left-1/2 top-[4.5px] z-30 -translate-x-1/2">
        {children}
      </div>
    </div>
  );
}

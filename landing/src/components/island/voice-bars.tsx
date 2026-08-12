"use client";

import { motion } from "framer-motion";
import { cn } from "@/lib/utils";

export function VoiceBars({
  playing = true,
  className,
}: {
  playing?: boolean;
  className?: string;
}) {
  const bars = [0, 1, 2, 3];

  return (
    <div className={cn("flex h-[13px] items-center gap-[2.4px]", className)}>
      {bars.map((i) => (
        <motion.span
          key={i}
          className="w-[2.5px] rounded-full bg-[#d1a86f]"
          animate={
            playing
              ? {
                  height: [4, 13, 6, 11, 4],
                }
              : { height: 3 }
          }
          transition={
            playing
              ? {
                  duration: 0.9,
                  repeat: Infinity,
                  delay: i * 0.12,
                  ease: "easeInOut",
                }
              : { duration: 0.35 }
          }
        />
      ))}
    </div>
  );
}

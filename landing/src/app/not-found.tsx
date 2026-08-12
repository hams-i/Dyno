"use client";

import { useEffect } from "react";

/** GitHub Pages 404 → landing ana sayfa. */
export default function NotFound() {
  useEffect(() => {
    const base = process.env.NEXT_PUBLIC_BASE_PATH ?? "";
    window.location.replace(`${base}/`);
  }, []);

  return null;
}

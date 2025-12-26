import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

// IMPORTANT:
// - GitHub Pages needs an absolute base that matches the repo name.
// - Tauri (desktop) needs a relative base, otherwise assets resolve to a non-existent /Concorde-EFB/... path and you get a white screen.
const isTauriBuild =
  Boolean(process.env.TAURI_PLATFORM) ||
  Boolean(process.env.TAURI_ARCH) ||
  Boolean(process.env.TAURI_FAMILY) ||
  process.env.TAURI === "true" ||
  process.env.TAURI === "1";

export default defineConfig({
  base: isTauriBuild ? "./" : "/Concorde-EFB/",
  plugins: [react()],
  build: {
    outDir: "dist",
    outDir: "dist",
    sourcemap: true,
  },
});

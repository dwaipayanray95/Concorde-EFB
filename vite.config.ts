import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

// Stable build base (GitHub Pages)
// Beta build overrides base via: `vite build --base=/Concorde-EFB/beta/`
export default defineConfig({
  base: "/Concorde-EFB/",
  plugins: [react()],
  build: {
    outDir: "dist",
    sourcemap: true,
  },
});
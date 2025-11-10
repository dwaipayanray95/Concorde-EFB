import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

// GitHub Pages serves project sites from /<repo-name>/, so make sure the
// production bundle points its asset URLs at that prefix while keeping the
// local dev server rooted at "/".
const repositoryBase = process.env.GITHUB_REPOSITORY?.split("/")[1] ?? "";

export default defineConfig(({ mode }) => ({
  base: mode === "production" && repositoryBase ? `/${repositoryBase}/` : "/",
  plugins: [react()],
}));

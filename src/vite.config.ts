import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// Vite config for GitHub Pages deployment
// IMPORTANT: base must match the repository name when hosted at
// https://<username>.github.io/<repo>/
export default defineConfig({
  base: '/Concorde-EFB/',
  plugins: [react()],
  build: {
    outDir: 'dist',
    sourcemap: true,
  },
});

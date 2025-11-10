import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// Vite reads vite.config.ts by default. If you keep this filename (vite.config-Concorde-EFB.ts),
// ensure your build uses: vite build --config vite.config-Concorde-EFB.ts, or rename this file to vite.config.ts.

// IMPORTANT: This must match https://dwaipayanray95.github.io/Concorde-EFB/
export default defineConfig({
  base: '/Concorde-EFB/',
  plugins: [react()],
  build: {
    outDir: 'dist',
    sourcemap: true,
  },
})

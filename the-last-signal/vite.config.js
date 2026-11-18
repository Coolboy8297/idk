import { defineConfig } from 'vite';

export default defineConfig({
  // Relative URLs are essential for GitHub Pages repository subdirectories.
  base: './',
  server: { port: 5173 },
  build: { target: 'es2020' },
});

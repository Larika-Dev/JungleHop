import { defineConfig } from 'vite';

export default defineConfig({
  server: { host: true, port: 5173 },
  build: { target: 'es2022', chunkSizeWarningLimit: 4000 },
  test: { include: ['tests/**/*.test.ts'], environment: 'node', testTimeout: 120000 },
} as any);

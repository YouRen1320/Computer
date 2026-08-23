import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

// Responsibility: share Vue transforms between the production build and deterministic component tests.
export default defineConfig({
  plugins: [vue()],
  test: { environment: 'happy-dom', include: ['tests/**/*.test.ts'], restoreMocks: true, unstubGlobals: true },
})

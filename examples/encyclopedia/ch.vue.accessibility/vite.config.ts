import vue from '@vitejs/plugin-vue'
import { defineConfig } from 'vitest/config'

// Responsibility: transform Vue consistently for build and deterministic DOM-contract tests.
export default defineConfig({
  plugins: [vue()],
  test: { environment: 'happy-dom', include: ['tests/**/*.test.ts'], restoreMocks: true },
})

import vue from '@vitejs/plugin-vue'
import { defineConfig } from 'vitest/config'

// Responsibility: keep the component laboratory deterministic in a DOM simulator.
export default defineConfig({
  plugins: [vue()],
  test: { environment: 'happy-dom', include: ['tests/**/*.test.ts'], restoreMocks: true, unstubGlobals: true },
})

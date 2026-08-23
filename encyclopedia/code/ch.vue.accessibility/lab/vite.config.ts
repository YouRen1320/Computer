import vue from '@vitejs/plugin-vue'
import { defineConfig } from 'vitest/config'

// Responsibility: isolate executable healthy tests from the deliberately broken fault catalog.
export default defineConfig({
  plugins: [vue()],
  test: { environment: 'happy-dom', include: ['tests/**/*.test.ts'], restoreMocks: true },
})

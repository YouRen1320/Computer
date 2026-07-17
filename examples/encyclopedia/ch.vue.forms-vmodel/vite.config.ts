import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

// Responsibility: keep the example's SFC build and deterministic DOM tests on one toolchain.
export default defineConfig({
  plugins: [vue()],
  test: {
    environment: 'happy-dom',
  },
})


import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

// Responsibility: keep the lab's component build and reactive transition tests reproducible.
export default defineConfig({
  plugins: [vue()],
  test: {
    environment: 'happy-dom',
  },
})


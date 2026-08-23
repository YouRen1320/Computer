import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

// Responsibility: compile the response model and run deterministic DOM observations.
export default defineConfig({
  plugins: [vue()],
  test: {
    environment: 'happy-dom',
  },
})


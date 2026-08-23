import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

// Responsibility: compile the lab SFCs and run their form matrix in a deterministic DOM.
export default defineConfig({
  plugins: [vue()],
  test: {
    environment: 'happy-dom',
  },
})


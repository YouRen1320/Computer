import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

// Responsibility: compile the lifecycle lab and run controlled timer/DOM transitions.
export default defineConfig({
  plugins: [vue()],
  test: {
    environment: 'happy-dom',
  },
})


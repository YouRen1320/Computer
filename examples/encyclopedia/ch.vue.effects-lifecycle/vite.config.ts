import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

// Responsibility: compile lifecycle SFCs and run their deterministic timer/DOM oracle.
export default defineConfig({
  plugins: [vue()],
  test: {
    environment: 'happy-dom',
  },
})


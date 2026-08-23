import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

// Responsibility: compile component macros/slots and run their deterministic DOM contracts.
export default defineConfig({
  plugins: [vue()],
  test: {
    environment: 'happy-dom',
  },
})


import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

// Responsibility: compile macros/slots and run the parent-child state matrix in Happy DOM.
export default defineConfig({
  plugins: [vue()],
  test: {
    environment: 'happy-dom',
  },
})


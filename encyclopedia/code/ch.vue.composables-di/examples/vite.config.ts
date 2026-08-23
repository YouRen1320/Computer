import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

// Responsibility: compile the SFC boundary and run its dependency/lifecycle contracts in a DOM shim.
export default defineConfig({
  plugins: [vue()],
  test: { environment: 'happy-dom' },
})


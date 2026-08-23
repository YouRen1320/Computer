import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

// Responsibility: execute route/fault matrices in a deterministic DOM and compile all SFC boundaries.
export default defineConfig({ plugins: [vue()], test: { environment: 'happy-dom' } })


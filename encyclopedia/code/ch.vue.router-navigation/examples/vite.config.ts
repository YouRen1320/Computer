import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

// Responsibility: compile route components and exercise navigation with a deterministic DOM environment.
export default defineConfig({ plugins: [vue()], test: { environment: 'happy-dom' } })


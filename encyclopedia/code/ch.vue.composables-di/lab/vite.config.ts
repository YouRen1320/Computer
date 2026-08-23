import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

// Responsibility: run the lab's component, lifecycle, and injected-fault evidence in happy-dom.
export default defineConfig({ plugins: [vue()], test: { environment: 'happy-dom' } })


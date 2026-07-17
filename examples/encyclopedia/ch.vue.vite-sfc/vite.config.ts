import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

// Vue 插件负责把 .vue 文件接入 Vite 的开发与生产变换链。
export default defineConfig({
  plugins: [vue()],
})

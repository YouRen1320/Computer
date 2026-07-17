import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

// 单一 Vue 插件同时服务 dev 与 build，避免两条链使用不同 SFC 规则。
export default defineConfig({
  plugins: [vue()],
})

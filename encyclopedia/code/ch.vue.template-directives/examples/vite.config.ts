import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

// 同一 Vue 编译插件供浏览器构建与 Vitest 使用，避免模板变换链漂移。
export default defineConfig({
  plugins: [vue()],
  test: {
    environment: './tests/memory-environment.ts',
  },
})

import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

// 浏览器构建和 Node 矩阵共享 Vue SFC 插件，避免测试绕过模板编译器。
export default defineConfig({
  plugins: [vue()],
  test: { environment: './tests/memory-environment.ts' },
})

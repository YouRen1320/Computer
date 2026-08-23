import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

// 生产构建保持默认分块，让动态 import 形成可由预算脚本观察的资产。
export default defineConfig({ plugins: [vue()] })


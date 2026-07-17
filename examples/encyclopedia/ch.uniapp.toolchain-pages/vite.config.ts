import { defineConfig } from 'vite'
import uni from '@dcloudio/vite-plugin-uni'

// 构建职责：安装 DCloud 目标插件；平台选择仍由 package script 传入。
export default defineConfig({ plugins: [uni()] })

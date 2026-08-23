import { builtinEnvironments, type Environment } from 'vitest/environments'

// 使用 Node 全局但请求 client 变换，使 .vue 产出 render 而非只供 SSR 的 ssrRender。
const memoryEnvironment: Environment = {
  ...builtinEnvironments.node,
  name: 'factorycare-memory',
  viteEnvironment: 'client',
}

export default memoryEnvironment

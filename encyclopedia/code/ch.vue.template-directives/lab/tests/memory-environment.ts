import { builtinEnvironments, type Environment } from 'vitest/environments'

// 自定义环境保留 Node 的确定性，同时让 Vue 插件生成可交给自定义渲染器的 client render。
const memoryEnvironment: Environment = {
  ...builtinEnvironments.node,
  name: 'factorycare-memory',
  viteEnvironment: 'client',
}

export default memoryEnvironment

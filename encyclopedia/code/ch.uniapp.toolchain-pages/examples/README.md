# uni-app 工具链与页面路由示例

这是一个 Vue 3/Vite 形态的最小源码树。离线验证器检查入口、应用/页面配置、页面 SFC、微信目标脚本、模拟构建工件与页面栈矩阵。

```bash
./verify.sh
```

验证器只使用 Node 内置模块，并把模拟产物写入系统临时目录后删除。它没有运行 DCloud 编译器、pnpm 安装、微信开发者工具或真机，不能替代真实 `pnpm dev:mp-weixin` 与 `pnpm build:mp-weixin` 证据。

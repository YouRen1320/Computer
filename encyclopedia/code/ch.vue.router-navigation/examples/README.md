# Router 路由矩阵观察例

本例用显式路由记录表达工单列表、详情、嵌套布局、登录重定向和 catch-all。测试使用 `createMemoryHistory()` 保存深链接、参数复用、取消与重定向证据；浏览器入口使用 `createWebHistory()`。导航区使用 RouterLink 当前页语义，路由后焦点移至页面标题。

```bash
./verify.sh
```

绿灯证明内存路由矩阵与 Vite 构建，不证明生产服务器 history fallback、真实浏览器 back/forward、SSR/hydration 或服务端授权。

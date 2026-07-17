# Router 导航故障实验

实验固定三种故障：详情组件只读取一次参数，导致实例复用后数据陈旧；认证守卫对 sign-in 自己继续重定向；“服务端”函数不检查身份，证明客户端守卫不是授权。正确矩阵同时观察 URL、matched 组件树与 `router.push()` 结果。

```bash
./verify.sh
```

测试使用 memory history + happy-dom。真实 Web History 服务器回退、浏览器 back/forward、滚动恢复、SSR/hydration 和真实服务端授权仍需后续环境验证。

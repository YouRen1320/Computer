# FactoryCare Composable / DI 故障实验

本实验保存三类故障：模块级 `ref` 让两个调用共享状态；副作用未登记清理使 scope 停止后计数仍为 1；两个字符串 key 相同导致端口碰撞。正确实现把 ref 放在 `useWorkOrderQuery` 内、用 watcher cleanup + `onScopeDispose` 终止请求，并用两个 typed `Symbol` key 表达不同依赖。

```bash
./verify.sh
```

测试矩阵先证明故障的首个可信证据，再用同类 oracle 验证隔离、清理归零和依赖替换。happy-dom/fake repository 不等同于真实网络、真实浏览器卸载或 SSR。

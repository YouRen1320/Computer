# Pinia 状态所有权示例

本示例使用真实 Pinia 实例验证四件事：同一容器内的多消费者同步、getter 派生、`storeToRefs()` 响应性，以及不同 Pinia 容器之间的隔离。

```bash
./verify.sh
```

它不启动浏览器，也不验证持久化、SSR 或服务端状态缓存。


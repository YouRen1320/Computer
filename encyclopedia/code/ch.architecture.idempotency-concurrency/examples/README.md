# 幂等键与乐观并发示例

本示例用离线内存模型展示分派命令的处理顺序：先按可信 scope 查幂等记录，同 fingerprint 重放首次响应、不同 fingerprint 冲突；新请求再用 expected version 竞争写入。

```bash
./verify.sh
```

输出证明同 key 同请求只有一次副作用、不同 payload 返回 409、另一个过期命令也返回 409。内存 Map 和 `synchronized` 不是生产持久化方案；示例明确不宣称跨消息系统 Exactly Once。

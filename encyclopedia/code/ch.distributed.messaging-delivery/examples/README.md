# RabbitMQ 投递语义离线示例

内存 broker 演示 exchange/binding 路由、unroutable return、confirm 不确定后的同 ID 重投、提交后 ack、幂等消费、有限 retry 和 DLQ。

```bash
./verify.sh
```

示例不开网络、不启动 RabbitMQ/Docker，也不证明真实 channel、publisher confirm、quorum queue 或 DLX 行为。

# 线程、JMM、同步与锁最小示例

示例用两个命名平台线程展示 NEW→TERMINATED、start/join happens-before、synchronized、ReentrantLock、AtomicInteger 和不可变快照。错误版用 barrier 强制两个线程先读后写，每次都丢一次更新。

```bash
./verify.sh
```

脚本不靠 sleep、墙钟阈值或线程输出顺序。若 join 超过有界保护会失败，而不是永久挂住。

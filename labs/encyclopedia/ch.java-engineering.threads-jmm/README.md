# FactoryCare 线程与 JMM 同步实验

正确 oracle 用 synchronized、ReentrantLock 与 AtomicInteger 各重跑 40 轮，每轮两个线程各加 200 次并精确得到 400。生命周期、start/join/latch、volatile signal、不可变快照和同锁 check-then-act 另有断言。

```bash
./verify.sh
```

六个故障全部确定性：屏障强制普通/volatile 丢更新，不同 monitor 不互斥，check-then-act 重复，结构检查发现可见性缺边，锁顺序图发现环。没有概率次数、sleep 竞速或真实永久死锁。

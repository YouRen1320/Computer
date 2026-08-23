# 实验：类初始化、角色注解与代理异常链

先预测 `Class.forName` 的初始化副作用、代理关闭前后的事件顺序，以及目标异常最终会以什么类型到达调用方，再运行：

~~~bash
cd labs/encyclopedia/ch.java-engineering.reflection-classloading-proxies
./verify.sh
~~~

实验验证延迟初始化、RUNTIME 注解、显式接口、授权拒绝、异常解包和 TCCL 恢复。五个故障夹具分别展示无接口、private 访问、错误加载器、包装异常和意外静态初始化。完成后请用 120 秒解释“类名相同为何仍可能不是同一类型”。

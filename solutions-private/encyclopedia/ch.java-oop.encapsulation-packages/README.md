# 私有解析：最小设备公共表面

只在公开练习留下越界编译证据后阅读。答案只把 status 收回 private，不改变调用端，不新增 setter；状态仍由 startRepair 维护。

~~~bash
cd solutions-private/encyclopedia/ch.java-oop.encapsulation-packages
./verify.sh
~~~

固定验证器要求八个运行断言通过，并要求包外直接写 status 在编译阶段失败。

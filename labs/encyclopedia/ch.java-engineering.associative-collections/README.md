# 实验：FactoryCare 设备去重、索引、计数与键合同

实验从保序 List 派生 LinkedHashSet 唯一设备、Map 类别频次和 Map<DeviceId, Device> 状态索引。Oracle 用 20 个断言覆盖重复、顺序、等价键、哈希碰撞、缺失/null 区分、不可修改返回值和排序结果。四个故障程序分别注入可变 hash、equals/hashCode 不一致、缺失值自动拆箱和 Comparator 等价类碰撞。

运行前完成预言：

| 输入/故障 | expected size/命中 | 第一处可信证据 |
| --- | --- | --- |
| PUMP-01、FAN-02、PUMP-01 | List=?，Set=? | ? |
| 等价但不同引用 DeviceId | Map 命中=? | ? |
| 不等键拥有相同 hash | Set size=? | ? |
| put 后把 key bucket 从 1 改 2 | containsKey=? | ? |
| Map.get 缺失后拆箱 int | 结果/异常=? | ? |
| TreeSet comparator 只比较 site | 两台同站设备 size=? | ? |

```bash
cd labs/encyclopedia/ch.java-engineering.associative-collections
./verify.sh
```

验收条件：正例 JDK 25 零警告并输出 `assertions=20 passed`；List 保留顺序/重复、Set 保序去重、Map 用稳定等价键命中、缺失分支显式；四个故障必须非零退出且出现固定证据；最终输出 `LAB PASS`。

变更练习：设备编号改为“租户内唯一”。新增 `TenantId` 并把索引键改为不可变组合值；增加同设备号不同租户、同租户重复设备和缺失租户断言。不要用拼接后无法无歧义拆分的字符串键。

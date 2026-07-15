# Week 05 面试题与追问

## 使用方式

每题先回答结论，再说明机制、FactoryCare 代码证据和适用边界。主回答控制在 90 秒，追问再用 60 秒。先保存整轮回答，再查看[答案册的面试校准](./answers.md#面试校准)；本文件不提供答案锚点。

## 1. 什么是函数式接口？

追问：

1. Comparator 是不是函数式接口？
2. 一个接口有两个 default 和一个抽象方法可以吗？
3. 为什么 Lambda 需要目标类型？

## 2. `Predicate`、`Function`、`Consumer`、`Supplier` 有什么区别？

追问：

1. 为什么后备值适合 Supplier？
2. Consumer 是否一定有副作用？
3. Comparator 属于哪类语义？

## 3. Lambda 为什么只能捕获 effectively final 局部变量？

追问：

1. final List 能否 add？
2. 字段也必须 effectively final 吗？
3. 并发下捕获可变对象有什么问题？

## 4. Lambda 和匿名类的 `this` 有什么不同？

追问：你会为了少写代码把长匿名类都改成 Lambda 吗？

## 5. Stream 和 Collection 的区别？

追问：

1. 为什么不建议把 Stream 存为领域对象字段？
2. Stream 能否重复使用？
3. 无限 Stream 是什么概念，本周需不需要？

## 6. 什么是中间操作和终止操作？

追问：

1. 没有终止操作时 map 会执行吗？
2. sorted 是无状态的吗？
3. `count()` 一定会调用前面的每个 map/peek 吗？

## 7. Stream 的惰性有什么价值和风险？

追问：

1. anyMatch 为什么可能少处理元素？
2. peek 日志为什么可能不完整？
3. 先 toList 再 anyMatch 有何变化？

## 8. `map` 和 `flatMap` 如何区别？

追问：

1. Optional 的 map/flatMap 呢？
2. flatMap 会自动去重吗？
3. TS `Array.flatMap` 与 Java `Stream.flatMap` 哪些地方不能直接类比？

## 9. `distinct` 如何判断重复？

追问：

1. 根据单一字段去重怎么做？
2. 用 toMap 去重时 merge 语义是什么？
3. 为什么不建议有状态 filter 去重？

## 10. `toMap` 遇到重复 key 怎么办？

追问：

1. `(a, b) -> a` 有什么问题？
2. merge function 在并行组合下需要满足什么性质？
3. 如何指定返回的 Map 类型？

## 11. `groupingBy` 和 `partitioningBy` 的区别？

追问：

1. 如何按状态计数？
2. 多级 grouping 何时应拆开？
3. 空数据返回什么？

## 12. `reduce` 的单位元是什么？

追问：

1. 最大值为什么常返回 Optional？
2. reduce 能否依赖副作用？
3. 为什么数值求和优先 `mapToInt().sum()`？

## 13. Stream 一定比循环快吗？

追问：

1. 一次 `nanoTime` 为什么不可靠？
2. Stream 是否一定创建中间集合？
3. 你项目中为什么保留某一版？

## 14. 为什么不要滥用 `parallelStream`？

追问：

1. CPU 密集纯函数是否一定适合？
2. 阻塞数据库调用放 parallelStream 呢？
3. 如何控制业务并发资源？

## 15. Optional 解决什么问题？

追问：

1. 空 List 是否再包 Optional？
2. Optional 字段为什么通常不推荐？
3. 参数为什么通常不推荐 Optional？

## 16. `orElse` 和 `orElseGet` 的区别？

追问：

1. 常量默认值用哪个？
2. 后备创建会写数据库怎么办？
3. `orElseThrow` 的 Supplier 何时运行？

## 17. 为什么不直接 `Optional.get()`？

追问：

1. `isPresent` 后 get 可以吗？
2. `ifPresent` 适合什么场景？
3. Optional 链过长时怎么办？

## 18. 如何保证查询排序稳定？

追问：

1. enum 自然顺序是否适合业务优先级？
2. 分页为什么更需要稳定排序？
3. 相同创建时间如何处理？

## 19. 复杂 Stream 怎么调试？

追问：举出你本周真实改回循环的一处代码；若没有，明确说未发生并给出一个应改回的判断标准。

## 20. FactoryCare 的状态占比如何处理空数据？

追问：

1. 占比精度和舍入如何决定？
2. 未来数据库聚合应该在哪层做？
3. 所有状态是否必须出现在结果中？

## 21. 栈和队列在 Java 中用什么实现？

追问：

1. poll 和 remove 区别？
2. ArrayDeque 能否存 null？
3. 有效括号的循环不变量是什么？

## 22. TS/Vue 的数组链能直接迁移吗？

追问：说一个类比帮助你的地方和一个真实写错或由测试预防的地方。

## 23. 如何诚实介绍本周 FactoryCare 查询与统计？

追问：

1. 循环版和 Stream 版是否都真实存在并通过同一测试？
2. 最终保留哪一版，依据是什么？
3. 哪些仍只是内存实验，不是数据库优化？

## 提交与校准

保存回答、代码/测试引用和“未验证”标记后，再打开[面试校准](./answers.md#面试校准)。提前阅读校准内容的本轮只能记为练习。

## 评分

| 维度 | 5 分标准 |
| --- | --- |
| 类型理解 | 能持续说清 T 到 R 的变化 |
| 执行模型 | 能解释惰性、阶段消除、短路和一次性 |
| 业务语义 | 先说空、重复、并列和排序 |
| 工程判断 | 不迷信 Stream/并行，能选循环 |
| 项目证据 | 有真实测试和选择记录，未验证内容明确标记 |

低于 18/25：从错误最多的三个主题各补一个失败实验后重录。

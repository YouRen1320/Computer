# Week 07 独立答案册

> 完成并保存[无 AI 考核](./assessment.md)后再看。

## 1. 自测参考

### 1.1 effectively final 与可变对象

编译器限制局部变量绑定被重新赋值，但引用指向的对象仍可变。捕获 final List 后 add 可以编译，却仍是副作用；并发时还可能不安全。

### 1.2 Stream 何时执行

中间操作建立惰性管道，终止操作通常发起计算，但实现可以消除不影响结果的阶段。短路终止操作可能只处理部分元素；已知大小的集合执行 `map(...).count()` 时，map 甚至可能完全不执行。需要证明逐元素消费时用 `toList/forEach` 等具有相应语义的终止操作，业务逻辑绝不能依赖中间函数副作用。

### 1.3 map 与 flatMap

map 把 T 映射为 R；若 R 本身是容器，会得到嵌套结构。flatMap 要求映射函数返回可铺平的容器/Stream，并把结果合成一层。

### 1.4 distinct

对对象依赖 equals/hashCode 契约。契约错误会让 distinct 的去重行为错误。

### 1.5 toMap 默认抛重复异常

它暴露“key 应唯一”的假设被数据违反。随便保留第一条会隐藏数据问题。只有业务明确允许重复时才定义 merge。

### 1.6 空占比

可以返回空 Map、全零 DTO 或 NoData，关键是契约明确且测试。不能得到 NaN 或抛除零异常。

### 1.7 peek

peek 的执行依赖终止与短路，且本意是观察管道。承担保存会让业务动作次数难以推断，并引入副作用。

### 1.8 parallelStream 资源

通常使用 common ForkJoinPool，业务没有显式拥有和限制其生命周期/容量；阻塞、共享状态、异常与顺序更难控制。

### 1.9 orElse 开销

Java 先计算方法参数，所以有值时 orElse 的后备对象仍会创建。orElseGet 的 Supplier 只在空时运行。

### 1.10 findAll

集合本身已有“零个结果”语义，返回空 List 即可。Optional<List<T>> 产生两种空，调用方不知道它们差别。

### 1.11 何时用循环

多个累积结果、复杂提前退出、逐步错误恢复或嵌套 Collector 难读时，循环通常更清楚。

### 1.12 不能替代数据库

内存 Stream 要先把数据加载进 JVM，不能提供索引、数据库过滤、稳定分页和网络传输优化。后续应让 SQL 执行可下推查询。

## 2. 主报表参考实现思路

### 2.1 比较器

假设 priority 作为 Map key，候选只需比较：

    Comparator<WorkOrder> earliest =
        Comparator.comparing(WorkOrder::createdAt)
            .thenComparing(WorkOrder::id);

若 id 是值对象，确保它实现稳定 Comparator 或显式提取 value。

### 2.2 循环版

以下代码假设 `WorkOrderStatus.isClosed()` 统一实现为 `this == CLOSED || this == CANCELLED`；它只是查询语义，不允许任意转换状态。

    Map<Priority, WorkOrder> earliestByPriority =
        new EnumMap<>(Priority.class);

    for (WorkOrder order : orders) {
        if (order.status().isClosed()) {
            continue;
        }

        WorkOrder current = earliestByPriority.get(order.priority());
        if (current == null || earliest.compare(order, current) < 0) {
            earliestByPriority.put(order.priority(), order);
        }
    }

    return earliestByPriority.entrySet().stream()
        .collect(toUnmodifiableMap(
            Map.Entry::getKey,
            entry -> toSummary(entry.getValue())
        ));

最后一小段使用 Stream 不影响“核心选择是循环”。也可以继续用循环输出 DTO。

### 2.3 Stream + toMap 版

    orders.stream()
        .filter(order -> !order.status().isClosed())
        .collect(toMap(
            WorkOrder::priority,
            Function.identity(),
            BinaryOperator.minBy(earliest),
            () -> new EnumMap<>(Priority.class)
        ));

再显式映射为 Summary。类型轨迹：

    Collection<WorkOrder>
    Stream<WorkOrder>
    Stream<WorkOrder>
    Map<Priority, WorkOrder>
    Map<Priority, WorkOrderSummary>

注意 BinaryOperator.minBy 返回 BinaryOperator<T>，merge 在相同 priority 时保留 earliest。

### 2.4 groupingBy + minBy 版

groupingBy 会得到：

    Map<Priority, Optional<WorkOrder>>

因为 min 可能无值。每个已出现分组实际上非空，但类型仍表达 Optional。可以使用 collectingAndThen 映射，但若因此变得难读，toMap 或循环更适合。

### 2.5 应保留哪版

合理答案不唯一：

- 若团队熟悉 Collector，toMap + minBy 简洁且重复语义明确；
- 若候选规则未来会增加多步错误处理，循环更易扩展和调试；
- 不能只按行数决定；
- 两版都应有同一套测试。

## 3. 看板参考

### 3.1 状态数量

    Map<WorkOrderStatus, Long> countByStatus =
        orders.stream().collect(groupingBy(
            WorkOrder::status,
            () -> new EnumMap<>(WorkOrderStatus.class),
            counting()
        ));

若要求所有状态都出现，创建全零 EnumMap 后覆盖计数。两种契约都可，但要测试。`WorkOrderStatus.isClosed()` 的统一语义应为 `CLOSED` 或 `CANCELLED`，不要在不同查询里各写一套近义判断。

### 3.2 占比

总数为 0 时提前返回明确空结果。非空时使用 count / (double) total。若 UI 需要精确百分比和舍入，后续用明确的 decimal/rounding 契约，不在本周随意格式化字符串。

### 3.3 Top 3

先按设备计数，再按 count 降序、equipmentId 升序排序，limit(3)。这会严格返回最多三条；如果需求要求“并列第三全部返回”，不能简单 limit(3)，需先确定第三名阈值再过滤。

### 3.4 Optional 边界

    WorkOrder order = repository.findById(id)
        .orElseThrow(() -> new WorkOrderNotFound(id));

不要先 isPresent 再 get，也不要让控制器以后自己解释 empty。

## 4. 有效括号参考

    boolean valid(String input) {
        Deque<Character> stack = new ArrayDeque<>();

        for (char value : input.toCharArray()) {
            if (value == '(' || value == '[' || value == '{') {
                stack.push(value);
                continue;
            }

            if (stack.isEmpty()) {
                return false;
            }

            char opening = stack.pop();
            if (!matches(opening, value)) {
                return false;
            }
        }

        return stack.isEmpty();
    }

    boolean matches(char opening, char closing) {
        return opening == '(' && closing == ')'
            || opening == '[' && closing == ']'
            || opening == '{' && closing == '}';
    }

若输入可能包含其他字符，契约要决定拒绝还是忽略；考核题规定只含括号，不必发明额外行为。

## 5. 故障答案

| 故障 | 根因 | 证明 |
| --- | --- | --- |
| map 未执行 | 无终止操作，管道惰性 | 终止前后计数 |
| Stream 重用 | 一次性消费 | 第二次终止抛异常 |
| distinct 错 | equals/hashCode 违约 | 修复前后结果 |
| peek 少保存 | 短路只消费部分 | limit/anyMatch 变体 |
| toMap 抛异常 | key 不唯一且无 merge | 重复设备数据 |
| 后备被创建 | orElse 参数提前求值 | 调用计数 |
| 排序漂移 | 没有 tie-breaker | 打乱输入重复执行 |
| 占比 NaN | 0/0 | 空集合测试 |

## 6. 评分锚点

### 优秀

能先写语义，两版通过同一测试；Stream 类型轨迹准确；最终选择有团队可维护性证据；没有副作用、get 或 parallelStream。

### 通过

主功能和边界正确，个别 Collector 可读性一般，但能解释并愿意改回循环；硬性项全部满足。

### 未通过

只写一条复杂链、无法解释中间类型；重复 key 随手丢弃；空结果崩溃；Optional.get；排序不稳定；为了“性能”使用 parallelStream。

## 7. 考后变体

关闭答案，完成：

> 每台设备最新一张已关闭工单；相同 closedAt 时 id 决胜；没有已关闭工单的设备不出现在结果中；输出 DTO。

先写 toMap + maxBy merge，再改为循环。若两个设备计数并列，再写一个“并列全部返回”的 Top 规则。

## 面试校准

> 先提交[面试题](./interview.md)的独立回答再阅读。以下是机制与边界校准，不是背诵稿。

1. **函数式接口**：只有一个抽象方法；default、static 以及与 Object 公共方法等价的方法不计入。Lambda 依赖目标类型提供实现，`@FunctionalInterface` 让编译器检查约束；Comparator 是典型函数式接口。
2. **四类常用接口**：Predicate 做 T→boolean 判断，Function 做 T→R 变换，Consumer 接收 T 且无返回，Supplier 无输入延迟提供 T。Consumer 不必然产生外部副作用，但常用于动作；后备值适合 Supplier 是因为可以延迟求值。
3. **effectively final**：限制的是被捕获局部变量的绑定不能再次赋值，不保证引用对象不可变。final List 仍可 add；字段不受相同局部捕获规则约束，但共享可变字段会带来副作用和并发风险。
4. **Lambda 的 this**：Lambda 不创建新的 this，指向外部实例；匿名类的 this 指向匿名类对象。是否替换匿名类要看是否真是单一抽象行为及可读性，而不是只看行数。
5. **Stream/Collection**：Collection 持有数据并可反复访问；Stream 描述一次性、通常惰性的计算管道。长期保存或暴露 Stream 会模糊所有权、资源关闭和消费次数；无限流只在有界终止语义下讨论，本周不是项目需要。
6. **中间/终止操作**：filter/map/sorted 返回新流，终止操作产生值或动作。没有终止操作通常不消费源；sorted 是有状态操作。实现可以消除不影响终止结果的阶段，因此已知大小的集合执行 `map(...).count()` 时 map 可能完全不调用。
7. **惰性**：允许操作融合、短路并避免无用中间集合；风险是执行时机和次数不能由副作用猜测。anyMatch 可在首个匹配后停止，peek 也可能只观察部分元素甚至因阶段消除不执行。
8. **map/flatMap**：map 把 T 变成 R；若 R 是容器会形成嵌套。flatMap 把每个元素产生的流铺成一层，不自动去重。Optional 的 flatMap 同样用于避免嵌套 Optional，但与 Stream 的多元素语义不同。
9. **distinct**：对象去重依赖 equals 语义及正确的 hashCode 契约。按单字段去重可先映射稳定 key、使用有明确 merge 的 Map，或设计专门结果；有状态 filter 会隐藏共享状态并破坏并行/复用推理。
10. **toMap 重复 key**：先判断唯一性假设是否被破坏；业务允许重复时显式选择保留最早、最新、合并计数或收集列表。随手 `(a,b)->a` 会隐藏数据问题。并行 collector 的合并函数要满足 collector 所需的结合性，Map 类型可用四参数 `toMap` 指定 supplier。
11. **grouping/partitioning**：groupingBy 可按任意 key 多组，partitioningBy 表达 boolean 两组。按状态计数使用 counting 下游 collector；多层嵌套难读时拆成命名步骤或循环。空结果契约必须预先定义。
12. **reduce**：identity 必须是组合操作的中性值，操作还要满足结合性。求和可用 0；最大值不能随手用 0，因为全负数据会错，因而自然返回 Optional。reduce 不应依赖外部副作用；数值专用流能减少装箱并更清晰。
13. **性能**：不能一般化 Stream 或循环谁更快。比较数据量、遍历、排序、装箱、JIT 与分配，并优先选择可读语义；一次 nanoTime 受预热、GC、调度等影响，可靠比较需 JMH 或严谨多轮实验。
14. **parallelStream**：默认 common pool、拆分/合并成本、阻塞污染、共享副作用、顺序和异常都需考虑。CPU 纯函数也要看规模和测量；数据库阻塞调用不应靠 parallelStream 获得无边界并发，业务资源用显式 Executor、连接池或许可控制。
15. **Optional 语义**：表达返回结果可能缺失，不是全面替代 null。空集合已有零元素语义；Optional 字段、参数或集合元素通常增加两层“无值”和框架映射成本，需要真实契约理由。
16. **orElse/orElseGet**：Java 会先求值方法参数，所以有值时 orElse 的后备对象仍创建；orElseGet 的 Supplier 只在 empty 时运行。常量默认值用 orElse 清楚；带写操作的后备不应隐藏在表达式中。异常 Supplier 也只在空时运行。
17. **避免 get**：直接 get 把缺失变成缺少业务语义的 NoSuchElementException。应用边界使用 orElseThrow 转换，或用 map/分支处理。isPresent+get 虽可正确，但通常不如显式分支/组合清楚；链过长时应拆开。
18. **稳定排序**：定义完整 Comparator，业务主键后加唯一 tie-breaker；不依赖 Map 偶然顺序或 enum ordinal。分页若无全序可能跨页重复/遗漏；createdAt 相同再用 workOrderId。
19. **调试复杂流**：标出每步元素类型，提取命名 Predicate/Function，使用小数据和边界测试，临时 peek 只观察，不承担业务。若仍需多处累积、复杂恢复或难以断点，改回循环。项目回答必须引用真实选择记录。
20. **空占比**：先选空 Map、全零 DTO 或 NoData，并测试总数为 0，不能产生 NaN。精度和舍入由输出契约决定；未来大数据聚合应尽量下推数据库，是否列出所有状态也应显式。
21. **栈/队列**：通常使用 Deque 抽象和 ArrayDeque；栈用 push/pop/peek，队列用 offer/poll/peek。poll 空时返回 null，remove 空时抛异常；ArrayDeque 不接受 null。有效括号的不变量是栈保存尚未匹配的左括号序列。
22. **TS/Vue 类比**：Array.map 立即产生数组而 Stream 惰性；TS interface 不做运行时校验；computed 有响应式缓存而 Stream 没有；服务端还要考虑装箱、排序、数据规模和 SQL 下推；Optional 是运行时对象，不等于 `T | undefined`。
23. **诚实项目表达**：只有在循环/Stream 两版、同一测试集和选择记录真实存在后，才能说明自己完成了组合查询与看板统计对照。应解释最终按规则可见性和维护成本选择，并明确内存 Stream 不是数据库查询优化。若其中一版未完成，直接说计划或练习中，不使用过去时成果话术。

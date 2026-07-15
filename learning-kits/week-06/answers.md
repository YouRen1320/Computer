# Week 06 独立答案册

> 仅在完成[无 AI 考核](./assessment.md)并保存提交后阅读。答案提供判断锚点，不是唯一代码结构。

## 1. 自测题参考答案

### 1.1 为什么不能无差别包装所有失败

业务重复、JSON 损坏和磁盘不可读需要不同处置：业务问题可返回逐条报告；JSON 语法损坏意味着整份契约不可读；磁盘问题需要保留底层原因供排障。若都变成一个无 cause 的 ImportFailedException，调用方无法决定修数据、重试还是告警。

### 1.2 checked 转 unchecked 的边界

通常在一个明确的基础设施适配器边界，把底层 IOException 转成应用可理解的 CatalogReadException，并保留 cause。不是为了少写 throws 随手转换；要确保异常语义稳定，且上层有统一处理策略。

### 1.3 主异常和关闭异常

try 块和 close 同时失败时，try 块异常通常是主异常，close 异常在 getSuppressed 中。排查要看完整 stack trace、cause 和 suppressed。

### 1.4 normalize 的边界

normalize 只消除语法上的点段，不能解析符号链接，也不能防止检查后文件系统状态变化。真实路径约束需结合可信根目录、toRealPath 策略、权限与最终操作方式。

### 1.5 同目录临时文件

同目录更可能处于同一文件系统，原子 move 才可能成立；跨文件系统通常退化成复制与删除，不能提供相同原子语义。

### 1.6 唯一时刻

Instant 可以独立表示时间线时刻。LocalDateTime 没有 offset 或 ZoneId，不能唯一映射到时间线。

### 1.7 Clock.fixed 的价值

它消除测试对真实当前时间的依赖，使边界规则、超时计算和 createdAt 断言可重复。它不解决时区语义错误，时区仍需明确。

### 1.8 JSON 后续验证

映射结构之后仍需字段约束、领域不变量以及与现有状态相关的校验，例如重复设备编码。

### 1.9 DTO 与领域对象合并风险

外部契约变化会迫使领域模型增加 nullable 字段、无参构造或 setter；内部字段也可能被意外序列化。分离后，两边可独立演进并通过显式映射审查。

### 1.10 导出成功的证明

DTO 构建成功、JSON 序列化成功、临时文件完整写入并关闭、目标替换成功，且失败路径没有破坏旧文件。仅调用 writeString 没抛异常不足以涵盖整体契约。

## 2. 综合任务参考设计

### 2.1 异常与结果

一种合理划分：

    final class CatalogReadException extends RuntimeException {
        CatalogReadException(String message, Throwable cause) {
            super(message, cause);
        }
    }

    record ImportIssue(
        int rowNumber,
        String field,
        String code,
        String message
    ) {}

    record ImportReport(
        int importedCount,
        List<ImportIssue> issues
    ) {
        boolean succeeded() {
            return issues.isEmpty();
        }
    }

损坏 JSON 可以是 CatalogFormatException，文件失败是 CatalogReadException；业务字段错误进入 ImportReport。具体 checked/unchecked 可不同，但不能丢语义。

### 2.2 编排顺序

参考伪代码：

    document = reader.read(path)                   // 文件失败
    rows = decoder.decode(document)                // JSON 语法/结构失败
    issues = validator.validateAll(rows)           // 字段、批内重复
    issues += repositoryDuplicateChecks(rows)      // 现有状态
    if issues not empty:
        return report with zero imported
    equipment = map every row through domain factory
    repository.saveAll(equipment)
    return success count

关键是不在所有校验完成前逐条保存。

### 2.3 重复检测

可用 Map 保存 code 第一次出现的行号。再次出现时，至少为后出现记录生成问题；更友好的报告会同时指出首次行号。Set 只能告诉你重复存在，不能直接保留定位信息。

### 2.4 Clock

    Clock fixedClock = Clock.fixed(
        Instant.parse("2026-07-11T08:00:00Z"),
        ZoneOffset.UTC
    );

    WorkOrder order = factoryWith(fixedClock).create(...);
    assertEquals(
        Instant.parse("2026-07-11T08:00:00Z"),
        order.createdAt()
    );

转换为 Asia/Shanghai 后显示为当地时间，但 toInstant 仍等于原 Instant。

### 2.5 安全导出

参考流程：

    Path temp = Files.createTempFile(target.getParent(), ".snapshot-", ".tmp");
    boolean moved = false;
    try {
        Files.writeString(temp, json, UTF_8);
        // ATOMIC_MOVE 会忽略其他 move 选项；不要在这里同时传
        // REPLACE_EXISTING 并把它误当成可移植的原子覆盖保证。
        // 对已存在 target 的行为必须由受支持 provider 的集成测试确认。
        Files.move(temp, target, ATOMIC_MOVE);
        moved = true;
    } catch (AtomicMoveNotSupportedException cause) {
        throw new SnapshotWriteException("目标不支持原子替换", cause);
    } catch (IOException cause) {
        throw new SnapshotWriteException("快照写入失败", cause);
    } finally {
        if (!moved) {
            tryDeleteTempWithoutMaskingOriginalFailure(temp);
        }
    }

只有 `move` 成功才可报告成功；如果目标已存在而 provider 拒绝覆盖，旧目标保持不变并安全失败。真实实现还要处理 target 无 parent、临时文件权限、清理失败和符号链接策略。还必须为受支持平台增加“旧目标已存在”的集成测试；Java 标准本身不承诺 `ATOMIC_MOVE` 在该情况下必然替换。本周答案只覆盖学习范围。

## 3. 缺陷定位表

| 缺陷 | 用户现象 | 最小证据 | 修复 |
| --- | --- | --- | --- |
| catch 后返回空成功 | 显示导入 0 条但无错误 | 让 reader 抛 IOException | 转换并保留 cause |
| 默认编码 | 中文跨环境损坏 | UTF-8 fixture | 显式 UTF-8 |
| 直接映射实体 | 非法字段进入对象 | 构造空 code JSON | DTO 后领域工厂 |
| 重复覆盖 | 导入数与唯一记录不符 | 两条同 code | 先整批检测 |
| 真实 Clock | 时间测试偶发失败 | 重复执行/时区变化 | 注入固定 Clock |
| 直接覆盖 | 失败后目标半截 | move 前故障注入 | 临时写后替换 |
| cause 丢失 | 只能看到包装位置 | 比较 stack trace | 传入 cause |

## 4. 链表参考答案

### 4.1 迭代反转

    Node previous = null;
    Node current = head;

    while (current != null) {
        Node next = current.next;
        current.next = previous;
        previous = current;
        current = next;
    }

    return previous;

循环不变量：previous 指向已经反转好的前缀，current 指向尚未处理的后缀头；两部分加起来仍包含原链表全部节点且不重复。先保存 next，否则修改 current.next 后会丢失未处理后缀。

复杂度：每个节点访问常数次，时间 O(n)；仅使用三个引用，额外空间 O(1)。

### 4.2 边界

- head 为 null，循环不进入，返回 null；
- 单节点保存 next 为 null，next 指向 null，返回原节点；
- 两节点用于人工画图最清晰；
- 本题假设输入无环；有环时循环不会终止，因此契约必须明确。

## 5. 评分锚点

### 90—100

实现边界清晰，失败语义、cause、整批校验、Clock、原子替换都有可重复测试；能指出路径与原子性的限制；口述不是背 API。

### 75—89

主流程正确，关键失败有测试；某些兼容或清理细节不完善，但没有硬性失败项，能诚实说明限制。

### 60—74

成功路径能跑，但异常被过度合并、测试依赖环境或导出失败保护不足。不得进入下一周，先补关键缺口。

### 60 以下

JSON 直接塑造领域实体、捕获后假成功、真实时间测试、文件部分覆盖等基础边界仍未建立，需要重新完成实验。

## 6. 答案看完后的变体

关闭答案，完成一个位置目录 LocationCatalogImporter：

- locationCode 唯一；
- parentCode 可选但若提供必须存在；
- JSON 损坏整批失败；
- 业务错误按记录收集；
- 使用相同文件边界，但不得复制 Equipment 的领域验证逻辑；
- 将链表题改为快慢引用判环。

## 面试校准

> 先提交[面试题](./interview.md)的独立回答再阅读。本节用于核对机制、边界和证据，不是可直接背诵的面试稿。

1. **checked/unchecked**：checked 是编译期处理约束，unchecked 仍会传播。选择要看调用方能否有意义恢复、抽象边界和团队约定。文件适配器可以把 IOException 转为有语义的基础设施异常，但必须保留 cause；领域前置条件失败常用 unchecked，但不是绝对规则。
2. **捕获范围**：局部业务代码不能用 `catch Exception` 吞掉所有失败。进程或请求最外层可以统一记录、转换或终止，但仍要保留错误事实；返回空列表会把“没有数据”和“读取失败”混成同一结果。
3. **finally**：正常返回和异常传播时通常执行，强制终止或 JVM 崩溃不保证；finally 中 return 会覆盖原返回或异常。多个资源由 try-with-resources 反序关闭。
4. **try-with-resources**：资源实现 AutoCloseable，在作用域结束时关闭；业务异常为主异常时，关闭异常通常进入 suppressed。排错同时看 stack trace、cause 和 suppressed，不背编译器展开代码。
5. **字节/字符**：二进制使用字节；文本通过明确字符集解释字节。JSON 契约使用 UTF-8。整体读取只适合有大小上限的小文件，大文件需要受控流式处理。
6. **路径约束**：从可信根目录出发，只接受相对路径，resolve 后 normalize 并检查仍 startsWith 根目录。normalize 不访问文件系统，不能解决符号链接和 TOCTOU；真实路径策略要结合目标是否存在与最终权限。
7. **原子写入**：目标是让读者只看到旧完整文件或新完整文件。同文件系统写临时文件、关闭后请求 `ATOMIC_MOVE`。不是所有 provider 都支持；指定 `ATOMIC_MOVE` 时其他 move 选项被忽略，已存在目标是替换还是失败由 provider 决定，必须限定支持平台并做旧目标集成测试。move 成功也不等于已经获得 fsync 级 crash durability。
8. **Instant/LocalDateTime**：Instant 是时间线唯一时刻；LocalDateTime 是没有时区的墙钟时间，结合 ZoneId/offset 后才能落到时间线。审计和 createdAt 用 Instant，预约需保存业务地区规则。
9. **ZoneId/ZoneOffset**：offset 是固定偏移，ZoneId 带地区历史/未来规则。改变展示 ZoneId 不改变 Instant；夏令时重叠和缺口必须有显式策略。
10. **Duration/Period**：Duration 是秒/纳秒时间线长度，Period 是年/月/日历运算。SLA 连续计时通常用 Duration，按日历定义的保修期用 Period；“一个月”不是固定 30 天。
11. **Clock**：把“现在”变成显式依赖，生产组合根使用系统 Clock，测试使用 fixed/offset Clock。固定时钟只解决时间可重复，不会自动修正时区规则。
12. **JSON 四层**：语法合法、结构可映射之后，仍有字段约束、枚举 code、领域不变量和仓储重复。未知、缺失与显式 null 是不同契约选择。
13. **DTO/领域分离**：外部契约与内部不变量可以独立演进，避免框架要求给领域实体增加 setter/nullable 字段，并控制敏感输出。简单不可变领域值可用 record，但外部 DTO 不应自动等同内部模型。
14. **enum code**：ordinal 与声明顺序耦合，不能成为外部契约。`name()` 只有在明确承诺稳定时才可用；更清楚的方式是稳定 code、显式 `fromCode` 与未知值策略。
15. **批量失败策略**：JSON 整体损坏通常 fail-fast；独立业务行问题可收集以便一次修复。部分写入是否允许必须先定，本周采用全批校验通过后才保存；大文件还要限制错误数量和内存。
16. **排障顺序**：按任务标识找到安全日志，依次区分文件读取、解码、JSON 结构、业务校验，检查异常/cause/suppressed 与首个业务栈帧，用最小脱敏文件复现，修复后补失败回归并核对部分写入。
17. **快照 DTO**：固定字段、排序、时间与枚举表达，避免内部字段意外泄漏，也让导出契约与领域重构解耦。它不是数据库持久化或备份。
18. **链表反转**：修改 `current.next` 前必须保存 next。不变量是 previous 指向已反转前缀、current 指向未处理后缀；迭代时间 O(n)、额外空间 O(1)，输入有环时需另定契约。
19. **TS/Vue 类比边界**：TS interface 没有运行时校验；Promise rejection 与同步异常链不同；JS Date 混合时间语义；浏览器文件 API 隐藏服务端路径、权限和原子性。满分回答必须连接你真实犯过或通过测试预防的一个错误。
20. **诚实项目表达**：只有在导入导出代码、失败测试和提交记录真实存在后，才可说明自己完成了 UTF-8、路径约束、DTO/领域分离、重复检测和受支持 provider 下的原子移动实验。同时必须明确这是个人项目，不是生产大规模 ETL，也不把符号链接、事务、大文件或 crash durability 说成已解决。

第 20 题可按自己的真实证据组织，不能逐字复制。若对应测试不存在，应明确说“设计过但未验证”或暂不使用该案例。

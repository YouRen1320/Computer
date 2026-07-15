# Week 02 独立答案册

仅在提交后读取。

## 设计锚点

- 先验证姓名、数组和每个元素；
- 空数组的 longest/first index 必须由契约决定，可使用 0/-1；
- 单次循环同时维护 total/count/max/firstLongIndex；
- 使用 long 保存总分钟可减少 int 累加溢出；
- 不需要 List/Stream。

## 参考实现骨架

```java
record WorkSummary(
        String technicianName,
        long totalMinutes,
        int entryCount,
        int longestMinutes,
        boolean overtime,
        int firstLongEntryIndex) {
}
```

考核尚未系统学习 record；因此正式答题可以改为多个返回方法、简单数组结果或由题目提供的结果类。评分不因未使用 record 扣分。教师若使用此骨架，应先说明它只是结果载体预览。

```java
static WorkSummary summarize(String rawName, int[] minutes) {
    if (rawName == null || rawName.isBlank()) {
        throw new IllegalArgumentException("technician name is required");
    }
    if (minutes == null) {
        throw new IllegalArgumentException("minutes is required");
    }

    long total = 0;
    int longest = 0;
    int firstLong = -1;
    for (int i = 0; i < minutes.length; i++) {
        int value = minutes[i];
        if (value < 0 || value > 720) {
            throw new IllegalArgumentException("invalid minutes at index " + i);
        }
        total += value;
        if (value > longest) {
            longest = value;
        }
        if (firstLong == -1 && value > 240) {
            firstLong = i;
        }
    }
    return new WorkSummary(rawName.strip(), total, minutes.length,
            longest, total > 480, firstLong);
}
```

若严格不预览 record，可提供题目给定 `WorkSummary` 类；关键评分在控制流。不要让数据载体知识阻塞本周。

## 测试锚点

- `[120, 240, 180]` total 540、longest 240、overtime true、firstLong -1；
- `[241]` firstLong 0；
- `[]` 全零/索引 -1；
- total 480 false，481 true；
- 0 合法；-1/721 报错且消息含索引；
- null/blank 名称、null 数组；
- 原数组前后内容相同。

## limit 变化

推荐契约：0 不处理；1..length 处理对应前缀；大于 length 处理全部或拒绝，必须事先明确；负数拒绝。最简单是在循环上界使用 `Math.min(limit, minutes.length)`，但仍先验证负数。

## 复杂度

扫描 n 个有效元素：时间 O(n)、额外空间 O(1)。若 limit=k 且 k<n，则 O(k)。返回结果对象是 O(1)。

## 调试锚点

过早 return 会让循环第一轮结束。第一个可信证据是：第二个元素从未被访问或 return 发生在循环块内。修复后保留多元素测试。

## 常见扣分

- `==` 比 String 内容；
- 空数组先读 `[0]`；
- `i <= length`；
- `return` 在循环内；
- 遇到非法项静默 continue，违背题目 fail 契约；
- 用全局 static 累加器导致多次调用污染；
- expected 复制生产循环。

## 面试校准

合格回答要结合索引范围、循环不变量、return 层级、String 内容比较和 O(n) 说明。若只背“for 已知次数、while 未知次数”，追问实际业务和故障。

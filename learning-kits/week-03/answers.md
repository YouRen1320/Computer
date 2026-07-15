# Week 03 独立答案册

仅在提交后读取。

## 设计要点

- 构造器只建立有效 Technician/DailyAssignment；
- id/technicianId/maxAssignments final；
- name 通过 rename；
- assignment 数组 private，输入/输出复制；
- current size 由实例字段维护，不是 static；
- 添加前完整校验，失败不修改；
- 本周可用 String 工单号，Week 04 再提取值对象。

## 参考骨架

```java
final class Technician {
    private final String id;
    private String name;

    Technician(String id, String name) {
        this.id = requireText(id, "id");
        this.name = requireText(name, "name");
    }

    void rename(String newName) {
        this.name = requireText(newName, "name");
    }

    String id() { return id; }
    String name() { return name; }

    private static String requireText(String value, String field) {
        if (value == null || value.isBlank()) {
            throw new IllegalArgumentException(field + " is required");
        }
        return value.strip();
    }
}
```

```java
final class DailyAssignment {
    private final String technicianId;
    private final int maxAssignments;
    private final String[] workOrderNumbers;
    private int size;

    DailyAssignment(String technicianId) {
        this(technicianId, 5);
    }

    DailyAssignment(String technicianId, int maxAssignments) {
        if (technicianId == null || technicianId.isBlank()) {
            throw new IllegalArgumentException("technicianId is required");
        }
        if (maxAssignments < 1 || maxAssignments > 20) {
            throw new IllegalArgumentException("maxAssignments out of range");
        }
        this.technicianId = technicianId.strip();
        this.maxAssignments = maxAssignments;
        this.workOrderNumbers = new String[maxAssignments];
    }

    void assign(String rawNumber) {
        if (rawNumber == null || rawNumber.isBlank()) {
            throw new IllegalArgumentException("workOrderNumber is required");
        }
        String number = rawNumber.strip();
        for (int i = 0; i < size; i++) {
            if (workOrderNumbers[i].equals(number)) {
                throw new IllegalStateException("work order already assigned");
            }
        }
        if (size == maxAssignments) {
            throw new IllegalStateException("daily limit reached");
        }
        workOrderNumbers[size++] = number;
    }

    String[] workOrderNumbers() {
        return Arrays.copyOf(workOrderNumbers, size);
    }
}
```

## 测试锚点

- valid Technician/rename；id/name null/blank；
- first/fifth assignment success, sixth fail；
- duplicate fail 且 size 不变；
- returned array modification does not affect object；
- two DailyAssignment objects independent；
- max 1/20 valid, 0/21 invalid；
- default max remains 5。

## 复杂度

assign 查重扫描当前 k 项，时间 O(k)，最大当前固定 20 可视业务常数，但表达算法仍说明线性；空间 O(maxAssignments)。返回快照复制 k 项，时间/空间 O(k)。Week 05 使用 Set 可讨论查重权衡。

## 常见错误

- array public 或 getter 直接返回；
- static size/workOrders；
- 达上限后先写数组再检查；
- `==` 比 String；
- 构造器写成 void；
- 所有方法 public；
- 为“可测试”添加任意 setter；
- 失败后 size 已增加。

## 面试校准

合格回答要能画引用、解释构造有效性、行为维护不变量、static/final/immutable 和防御复制成本。若只说“private 就是封装”，追问如何阻止第六个分配和返回数组泄漏。

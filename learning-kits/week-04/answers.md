# Week 04 独立答案册

仅在提交后读取。

## 设计锚点

- Money 可用 record，compact constructor 拒绝负数；
- 金额算术使用 `Math.addExact/multiplyExact` 或明确整数比例实现；
- ChargePolicy 接口接收 Money 返回 Money；
- service 构造器依赖接口；
- enum 解析外部字符串使用显式 code/`valueOf` 包装错误，不用 ordinal；
- DiscountPolicy 组合 delegate。

## 参考骨架

```java
record Money(long cents) {
    Money {
        if (cents < 0) {
            throw new IllegalArgumentException("cents must be non-negative");
        }
    }

    Money plus(Money other) {
        return new Money(Math.addExact(cents, other.cents));
    }
}

interface ChargePolicy {
    Money calculate(Money base);
}
```

```java
final class NormalPolicy implements ChargePolicy {
    @Override
    public Money calculate(Money base) { return base; }
}

final class WarrantyPolicy implements ChargePolicy {
    @Override
    public Money calculate(Money base) { return new Money(0); }
}

final class EmergencyPolicy implements ChargePolicy {
    @Override
    public Money calculate(Money base) {
        long surcharge = Math.multiplyExact(base.cents(), 20) / 100;
        return base.plus(new Money(surcharge));
    }
}
```

舍入契约需明确；示例向下取整，不是唯一正确答案。

```java
final class DiscountPolicy implements ChargePolicy {
    private final ChargePolicy delegate;

    DiscountPolicy(ChargePolicy delegate) {
        this.delegate = Objects.requireNonNull(delegate);
    }

    @Override
    public Money calculate(Money base) {
        long original = delegate.calculate(base).cents();
        return new Money(Math.max(0, original - 100));
    }
}
```

## 测试锚点

- Money 0/positive/negative/equality；
- Normal same, Warranty 0；
- Emergency boundary/rounding/overflow；
- ChargeService 用 recording/fake policy 验证动态调用；
- 未知/null type；
- Discount 低于/等于/高于 100，组合 Emergency；
- 拼错参数导致 overload 时 `@Override` 应编译报错。

## LSP 校准

所有 ChargePolicy 应接受契约允许的 Money，并返回非负 Money。某子实现突然拒绝 0 或返回 null 会破坏调用者假设。若需要不同前置条件，应修改统一契约或使用不同抽象。

## 复杂度

每个策略固定算术 O(1) 时间/空间。按列表逐个寻找匹配策略为 O(k)。装饰组合层数 d 会带来 O(d) 调用；本项目保持很小。

## 常见扣分

- service 内 `new EmergencyPolicy`；
- interface 只为命名但调用者仍 switch concrete class；
- Money 使用 double；
- enum ordinal；
- record 内可变字段无复制；
- Discount 修改所有策略；
- 继承仅为复用两行；
- 没有 `@Override` 导致静默 overload。

## 面试校准

合格回答应从契约/变化方向出发选择接口、组合、record/enum，而不是背“多态三大特性”。需要能解释一个 LSP 失败、一个浅不可变失败和一次无 AI 新策略。

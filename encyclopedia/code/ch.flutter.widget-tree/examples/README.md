# Widget / Element / Context 身份模型

本示例用 `tree.yml` 表达一棵最小 FactoryCare 树，并用验证器检查：Widget 是配置、Element 提供树位置、State 只附着在 StatefulElement、Context 只能向祖先查找。验证器还锁定
`MaterialApp` 与 `Scaffold` 的已知 StatefulWidget→StatefulElement 映射，避免只检查错误 YAML
自身是否“内部一致”。

```bash
./verify.sh
```

这是可执行的概念 oracle，不宣称替代 Flutter Inspector。真实练习需要在 Flutter 3.44.x 进程中对照 Inspector。

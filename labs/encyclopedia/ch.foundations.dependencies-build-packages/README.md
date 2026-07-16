# 实验：从工具来源到可重复 artifact

## 目标

先预测，再运行一个完全离线的依赖与构建模型。你要能画出直接/传递依赖树，区分源仓库和本地缓存，并用阶段报告证明测试失败不会被误报为已打包。

## 步骤

1. 在 `worksheet.md` 预测 PATH 两种顺序选择的工具。
2. 阅读示例的 `project.json`、`source_repository.json` 和 `project.lock.json`，画依赖树并标直接/传递。
3. 预测冷/热缓存的 hit 数量和 artifact 摘要关系。
4. 预测源仓库缺少 `fc-format@1.0.0` 时，热缓存与空缓存分别怎样表现。
5. 预测新增 1.2.0 后未锁最高版本解析与已锁构建的差异。
6. 预测 test 故障后 package 状态和产物是否存在。
7. 从仓库根目录运行：

   ```bash
   ruby labs/encyclopedia/ch.foundations.dependencies-build-packages/run_lab.rb
   ```

8. 把 actual、首个可信失败和未验证范围填回 worksheet。

## 验收

- 工具与环境来源可追溯；
- 直接/传递依赖和锁文件关系正确；
- 冷/热缓存的 artifact 摘要一致；
- 能解释为什么热缓存通过不能证明冷构建完整；
- 未锁版本确实漂移，锁定构建不漂移；
- test 失败时 package 为 not-run、artifact 不存在；
- 明确本实验是 T1 教学模型，不是 Maven/pnpm/uv 的真实集成测试。

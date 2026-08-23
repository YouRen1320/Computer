# Lab：沿运行链定位 Node、包类型与模块路径故障

目标：先验证双模块绿色基线，再观察三项受控故障的首个证据。

- `fixtures/toolchain-drift.txt` 是固定的版本漂移证据样本；它不会改动本机工具链。
- `faults/wrong-package-type.cjs` 把静态 ESM 导入放入明确 CommonJS 文件。
- `faults/missing-extension.mjs` 故意省略 Node ESM 相对导入扩展名。

运行唯一入口：

```sh
./verify.sh
```

通过只表示局部故障合同可复现。canonical build 仍要求在 Node 24.x/pnpm 11.x 下从空目录执行冻结安装，并保存实际路径、版本、stdout、stderr 与退出码。

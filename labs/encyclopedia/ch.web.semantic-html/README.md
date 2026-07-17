# 实验：定位结构语义丢失

目标是先验证一份正确的静态工单页，再按 `faults.json` 依次注入 `div` 汤、标题跳级和缺失文档语言。每次只改一个变量，先记录失败输出和首个可信证据，再修复并用同一个命令重跑。

```bash
./verify.sh
```

该命令离线验证修复后的 `page.html`、预期标题序列以及完整的故障记录。为了真正完成 lab，还要在副本中亲手注入每个故障并保存红灯；本仓库保留的是可重复绿灯基线。不要修改 `expected-outline.json` 去迎合错误页面。

离线检查不是完整 HTML parser/validator，也没有打开真实浏览器。G4 证据需另补 conformance checker、DOM、Accessibility 面板和目标读屏器结果，并记录工具版本。夹具全部是虚构数据。

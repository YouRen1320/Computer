# 模块、包与 CLI 示例

该示例把优先级规则放入可导入模块，把参数解析放入 CLI，并让 `python -m factorycare_training` 复用同一个 `main`。验证器实际检查无副作用导入、模块缓存、成功与失败退出码。

```bash
./verify.sh
```

验证使用当前可用 `python3` 与临时 `PYTHONPATH=src`，没有执行 uv 安装或发行包构建；因此只证明源码包合同。

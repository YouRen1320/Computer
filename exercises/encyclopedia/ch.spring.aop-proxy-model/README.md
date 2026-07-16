# 修复吞异常 Advice

starter 的 Around Advice 把目标异常换成 `fallback`，破坏业务与事务语义。只能修改 Advice：仍记录一次，但必须传播原异常；不要改 target 或测试。

`./verify.sh` 应稳定显示唯一红灯 `EXPECTED_EXCEPTION_PROPAGATION`；修复后同一入口全绿。

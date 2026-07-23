# 公开练习：补齐工具链门禁

`learner_checks.sh` 目前只打印版本并运行入口，缺少依赖解析、格式门禁和静态分析。
请补齐脚本，使它依次完成：解析实际 Dart、`dart pub get --offline`、格式只检查、
`dart analyze --fatal-infos`、运行入口，并保留可读输出。

公开版本的 `./verify.sh` 应稳定失败；完成练习后再用私有答案对照。

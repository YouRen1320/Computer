# Dart 工具链最小可重复示例

这个应用包只演示工具链证据链，不承担 Dart 类型教学：解析当前 `dart`、读取
`pubspec.yaml`、生成包配置和锁文件、格式检查、静态分析，最后运行 `bin/main.dart`。

运行：

```bash
./verify.sh
```

验证脚本会删除 `.dart_tool/`，但保留应用包应提交的 `pubspec.lock`。

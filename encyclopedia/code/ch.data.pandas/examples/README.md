# pandas 设备/工单清洗与汇总示例

示例清洗 string、nullable 数值与 UTC 时间，验证设备维表唯一性，以 `many_to_one` 左连接并输出技师/类别汇总和质量计数。

```bash
./verify.sh
```

脚本会打印实际 pandas/NumPy 版本。未验证 pandas 3.0.4、pytest、PyArrow、CSV/数据库引擎或真实生产权限边界。

# 练习：阻止领域字段穿过 JSON 边界

starter 故意直接序列化含 `internalCost` 与 `assigneeToken` 的领域对象。先运行 `./verify.sh`，确认只有 `EXPECTED_DOMAIN_FIELDS_HIDDEN` 红灯；再定义响应 DTO，并用显式映射只发布五个合同字段。

验证器既接受未经修改的确定性红灯，也接受完成后的全绿；不要删除字段断言或把敏感字段加入期望集合。

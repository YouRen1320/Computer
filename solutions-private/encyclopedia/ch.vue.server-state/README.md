# 私有参考解：服务端状态竞态

参考解让 request identity 与 alive/abort 共同守住每个提交点；旧 finally 只释放自己的 controller，不写当前 UI 状态。检查器与公开练习保持同一三场景合同。

```sh
./verify.sh
```

预期退出码为 `0`。此结果仍不代表真实 Vue、浏览器或后端已验证。

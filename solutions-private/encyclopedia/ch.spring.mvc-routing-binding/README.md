# 私有答案：HTTP 404 状态修复

答案保留存在资源的 `200`，并用 `ResponseEntity.notFound()` 把缺失资源映射为真正的 `404`。运行 `./verify.sh` 应有两个测试通过。

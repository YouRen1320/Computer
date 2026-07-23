# 生命周期与异步所有权轨迹

`trace.yml` 保存一次“请求 A 被 B 替换、页面随后销毁”的轨迹。验证器检查：只有当前 operation 可提交状态；dispose 必须取消当前任务；完成回调不得在 `mounted=false` 后 setState。

```bash
./verify.sh
```

该模型验证时序合同，不代表某个 HTTP 库已经把服务端工作真正取消。

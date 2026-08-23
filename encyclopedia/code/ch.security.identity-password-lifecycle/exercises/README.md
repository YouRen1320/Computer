# 独立练习：凭据状态与恢复不变量

此练习只使用元数据和 synthetic 状态，不要求你实现新的密码算法。完成五个 TODO：

1. 拒绝明文/可逆存储元数据；
2. 检测 salt 复用；
3. 只接受目的正确、未消费、未过期的 reset grant；
4. 对存在/不存在账号返回相同公开重置合同；
5. 轮换凭据版本并撤销旧 session。

先运行：

```bash
./verify.sh
```

starter 应在 `UNSAFE_STORAGE_ACCEPTED` 处失败，说明正反预言就绪。完成后直接编译运行类，保留所有失败断言；目标是两行 `EXERCISE PASS` 输出。不要把真实密码、Token、pepper 或账号加入夹具。

本练习不实现 Cookie/OAuth/MFA 协议；`canReplaceMfa` 只表达“更换因素必须重新认证”的状态边界。

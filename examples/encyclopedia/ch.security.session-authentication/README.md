# Session 认证生命周期示例

这个纯 JDK 25 示例用密码记录元数据、固定时钟、合成 ID 和内存 Session 演示：

- 密码记录必须是带 salt、可调成本的自适应单向格式；
- 不存在账号与错误密码使用相同公开失败；
- 登录成功轮换 ID，匿名旧 ID 不可复用；
- 恢复授权短期、限定用途且一次性消费；
- 改密递增 credential version 并撤销旧 Session；
- 登出服务端失效，并发会话遵守显式上限。

```bash
./verify.sh
```

程序不接收或哈希真实密码，不输出合成 ID/Token，也不启动 Spring、数据库或邮件服务。生产密码编码必须交给框架 `PasswordEncoder`。

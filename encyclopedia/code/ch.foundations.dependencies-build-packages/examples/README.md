# 示例：完全本地的依赖解析与可重复构建

本示例用 Ruby 标准库实现一个透明教学模型，不访问 Maven Central、Docker Hub 或其他网络服务。`source_repository.json` 是随仓库提交的本地源仓库，`project.lock.json` 固定直接/传递依赖版本及内容摘要。

从仓库根目录运行：

```bash
ruby examples/encyclopedia/ch.foundations.dependencies-build-packages/verify.rb
```

验证器会在系统临时目录中完成并自动释放教学数据，不写用户 Maven 仓库或 shell 配置。它验证：

- PATH 顺序可以选错工具，修正顺序后恢复；
- 子进程只会看到实际继承的环境；
- `fc-report` 是直接依赖，`fc-format` 是传递依赖；
- 冷缓存和热缓存生成相同 artifact SHA-256；
- 热缓存可能掩盖源仓库缺包，空缓存会在 validate 暴露；
- 未锁解析会随新增版本漂移，锁定版本不漂移；
- test 失败后 package 不运行，也没有伪造产物。

`1.x` 和解析策略是本章自定义的教学语法，不等同 Maven、pnpm 或 uv。真实项目应使用对应工具的官方 lock/依赖管理机制。

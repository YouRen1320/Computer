# 示例：离线容器边界模型与本地镜像上下文

默认验证器只使用 Ruby 标准库，不连接 Docker daemon、registry 或公网：

```bash
ruby examples/encyclopedia/ch.foundations.docker-basics/verify.rb
```

它验证镜像层不可被容器写入修改、容器可写层随替换消失、named volume 持久、bind mount 只允许教学临时目录、端口必须发布、同一用户定义网络按名称互通，以及逐项清理边界。

`Dockerfile.local` 供可选真实实验使用。它没有公开基础镜像名称，也没有 `RUN` 下载步骤；真实脚本只接受本机已经存在且含 `python3` 的基础镜像，并使用 `docker build --pull=false`。默认不会执行真实 Docker 操作。

安全约束：

- 不包含 token、登录或 registry 地址；
- 真实服务只发布到 `127.0.0.1`；
- bind source 只能是脚本创建的临时目录；
- 不使用 `prune`、`--force`、特权模式、Docker socket mount 或主机系统目录；
- 只清理本次创建、带唯一 `fc-basics-*` 名称的资源。

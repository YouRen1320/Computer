# 实验：镜像、容器、存储、端口与网络边界

## 默认离线实验

先填 `worksheet.md`，再从仓库根目录运行：

```bash
ruby labs/encyclopedia/ch.foundations.docker-basics/run_offline_lab.rb
```

它不需要 Docker daemon，也不会访问网络或修改真实 Docker 资源。验收包括：镜像摘要不随容器写入变化；无挂载数据随容器替换消失；named volume 数据保留；错误挂载目标可由 inspect/写入路径定位；未发布端口不可从主机访问；同一用户定义网络按容器名互通；清理只接受 `fc-basics-*`。

## 可选真实 daemon 实验

只有在你已经拥有一个**本机现成、可信、含 `python3`** 的基础镜像，并读完脚本后才执行。脚本不会 pull，也不会登录 registry：

```bash
ALLOW_FACTORYCARE_DOCKER_LAB=1 \
FACTORYCARE_DOCKER_IMAGE='<local-image-id-or-local-tag>' \
sh labs/encyclopedia/ch.foundations.docker-basics/run_real_lab.sh
```

可用 `FACTORYCARE_DOCKER_HOST_PORT` 改默认 18080。脚本构建一个唯一命名的本地教学镜像，绑定 `127.0.0.1`，验证未发布/已发布端口、容器网络 DNS、挂错路径、named volume 重建、无卷数据丢失和 bind mount，然后逐项停止并移除本次创建的资源。

执行前确认：

- Docker daemon 已由你自行启动；
- 指定镜像已经在本地，来源与摘要可追溯；
- 端口未占用；
- 没有真实凭据、客户数据或生产目录；
- 接受脚本创建并删除本次唯一命名的容器、网络、卷和教学镜像。

脚本不使用 `prune`、`--force`、`--privileged`、Docker socket mount、`/etc`/`/Users` 等主机系统目录，也不会删除指定的基础镜像。若 daemon 或本地镜像不满足条件，保留离线实验证据并标记真实路径未验证。

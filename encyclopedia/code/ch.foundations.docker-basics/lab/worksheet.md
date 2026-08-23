# Docker 基础实验记录

## 执行前预测

| 场景 | expected | actual | 证据来源 |
| --- | --- | --- | --- |
| 容器层写 `/data/state.txt` 后替换容器 |  |  |  |
| named volume 写入后替换容器 |  |  |  |
| volume 挂到 `/wrong`，应用写 `/expected` |  |  |  |
| 服务监听 8080 但没有 publish |  |  |  |
| `127.0.0.1:18080→8080` |  |  |  |
| 同一用户定义网络按名称访问 |  |  |  |
| 不同网络访问 |  |  |  |
| bind mount 写入教学临时目录 |  |  |  |

## inspect / logs / 文件证据

- 镜像摘要：
- 容器进程状态：
- Mounts type/source/destination：
- Ports host IP/host port/container port：
- Network 名称：
- 首个可信日志：
- 主机文件或 volume 内容：

## 清理清单

- 本次创建的容器：
- 已逐个 stop/remove：
- 本次创建的 network：
- 本次创建的 volume：
- 本次创建的教学 image：
- 未触碰的基础 image/其他资源：

## 验证边界

- 离线模型已验证：
- 真实 daemon 已验证/未验证：
- 未验证的生产镜像加固、Compose、Kubernetes、安全与恢复：

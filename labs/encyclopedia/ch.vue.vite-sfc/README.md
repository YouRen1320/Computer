# FactoryCare 实验：三条 Vite 链与 SFC 红—修—绿

这个实验从最小文件集证明：开发服务器能变换 Vue SFC、生产构建能生成带 source map 的工件、preview 能服务同一份构建。验证器还会在临时副本中删除 `</template>`，要求构建真实非零失败并保留 `.vue` 定位，然后再以原始源码完成绿色构建。

```sh
./verify.sh
```

固定端口只绑定 `127.0.0.1`，preview 仅作本地验收。若端口冲突，先停止占用进程，不要删掉 `--strictPort` 让证据悄悄漂到其他端口。

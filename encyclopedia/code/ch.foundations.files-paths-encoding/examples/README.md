# 示例：用项目树观察路径、UTF-8 与换行

本目录提供一棵固定小项目树。学习者先用编辑器项目面板、面包屑和状态栏观察，不需要使用 Shell 移动、复制或删除文件。

```text
project/
├── README.md
├── .factorycare-note
├── config.json.txt
└── data/
    └── device-note.txt
```

观察任务：

1. 从本示例目录到中文样本的相对路径是 `project/data/device-note.txt`；
2. 若起点改成 `project/`，相对路径变为 `data/device-note.txt`；
3. `.factorycare-note` 只是默认可能隐藏，不是加密文件；
4. `config.json.txt` 的真实末尾扩展名是 `.txt`，不能因名字中含 `.json` 就当成 JSON；
5. `device-note.txt` 使用 UTF-8 与 LF，关闭并重开后中文应无损。

维护者或已经会运行单条命令的学习者，可执行只读验证器：

```text
ruby verify.rb
```

验证器在系统临时目录生成视觉相同的 LF/CRLF 对照，不改写提交的夹具。预期最后一行是 `files-paths-encoding verification: PASS`。

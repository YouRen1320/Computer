---
schema_version: 2
edition: 2026.2-draft
id: ch.data.postgresql-psql
title: PostgreSQL 服务、连接、psql 与脚本执行
responsibility: 教授连接目标、会话和脚本执行证据，不提前讲查询语法、角色管理或生产运维
volume: '04'
order: 2
level: L1
status: drafting
path: book/volume-04-data-postgresql/chapters/ch.data.postgresql-psql.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.data.relational-model
- ch.foundations.cli-streams-exit-codes
version_surfaces:
- postgresql-18
route_tags:
- zero-base
- accelerated-48
- reference
- factorycare-project
stable_core: true
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释PostgreSQL 服务、连接、psql 与脚本执行的职责、适用边界与一个会失败的反例
  covers_topic_groups:
  - postgres-service-connection
  - psql-workflow
  covers_topics:
  - postgres.server-client
  - postgres.connection-string
  - postgres.database-session
  - postgres.psql-meta-command
  - postgres.sql-file-execution
  - postgres.error-exit-evidence
  uses_capabilities:
  - data.relational-schema
  - foundation.shell-command-stream
  - foundation.os-process-memory
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 完成该章的独立构建任务：连接指定 PostgreSQL 数据库，使用 psql 查看当前 server/database/user，执行事务内只读脚本并保存退出证据
  covers_topic_groups:
  - postgres-service-connection
  - psql-workflow
  covers_topics:
  - postgres.server-client
  - postgres.connection-string
  - postgres.database-session
  - postgres.psql-meta-command
  - postgres.sql-file-execution
  - postgres.error-exit-evidence
  uses_capabilities:
  - data.relational-schema
  - foundation.shell-command-stream
  - foundation.os-process-memory
  evidence_kind: runnable-artifact-and-output
  verification_mode: command-output-or-manual-calculation
- id: diagnose
  kind: fault-diagnosis
  text: 注入错误 host/port/database 和脚本中间语法错，区分连接前失败与服务器返回 SQL 错误，并把异常定位到第一处可信证据
  covers_topic_groups:
  - postgres-service-connection
  - psql-workflow
  covers_topics:
  - postgres.server-client
  - postgres.connection-string
  - postgres.database-session
  - postgres.psql-meta-command
  - postgres.sql-file-execution
  - postgres.error-exit-evidence
  uses_capabilities:
  - data.relational-schema
  - foundation.shell-command-stream
  - foundation.os-process-memory
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-observation-rerun
---
# PostgreSQL 服务、连接、psql 与脚本执行

> 本章状态为 `drafting`。命令和行为按 PostgreSQL **18.4** 官方文档于 **2026-07-17** 复核。本机没有 `psql`、`postgres`、`initdb`，Docker daemon 也未运行；因此配套验证采用固定计划、脚本和 transcript 的离线 oracle，不安装软件、不读取凭据、不连接本机或远程数据库。它能验证命令契约和错误分类，不能冒充真实 PostgreSQL 执行证据。

## 1. 本章解决什么问题

初学者看到一个提示符：

```text
factorycare_training=>
```

很容易直接开始输入内容，却不知道自己连接的是哪台服务器、哪个端口、哪个数据库、以哪个角色工作，也不知道一份脚本在中途报错后前面的语句是否已经生效。真正危险的不是少打一个分号，而是**目标和边界不明**：

- 本想连训练库，却因默认值进入同名的其他数据库；
- 本想执行一个文件，却把本地路径误当服务器路径；
- 脚本第二条语句失败，`psql` 默认继续执行后面的语句；
- 只看最后一行“成功”，遗漏 stderr 和非零退出码；
- 把密码放进命令行、连接 URI、截图或 shell 历史；
- 把 psql 客户端版本当成服务器版本；
- 以为关闭终端会自动回滚已经提交的语句。

本章建立一条可复述的证据链：

```text
明确连接目标
  → 客户端发起连接
  → 服务器认证并建立会话
  → 会话报告 server/database/role/schema
  → psql 读取脚本
  → SQL 与元命令分别由正确一侧处理
  → stdout、stderr、退出码和事务结果共同构成证据
```

### 完成标准

你应能：

- 区分 PostgreSQL server、backend、client、`psql` 和 session；
- 写出 host、port、database、user/role 和连接选项组成的目标；
- 解释 database、schema 与 role 的范围，不把三者混成“库名”；
- 使用 `\conninfo`、`\l`、`\dn`、`\dt`、`\d`、`\i`、`\ir`、`\copy` 等常用元命令；
- 用 `-X -v ON_ERROR_STOP=1 -f` 执行固定脚本，并保存三条输出流证据；
- 说明自动提交、显式事务与 `--single-transaction` 的边界；
- 区分连接前失败、连接中断、psql 自身错误和服务器 SQL 错误；
- 解释 `COPY` 与 `\copy` 的文件所在机器和权限边界；
- 不把生产地址、真实密码或破坏性操作带进练习。

本章不教授查询表达式、角色创建/授权、服务器安装、备份恢复、高可用或生产运维。示例中的只读 SQL 是固定探针，先复制运行和理解证据，不扩展为 SELECT 语法课。

## 2. PostgreSQL 是客户端/服务器系统

PostgreSQL 的服务器程序是 `postgres`。一个服务器实例管理一个 database cluster；客户端可以是 `psql`、Java JDBC 应用、图形工具或其他实现 PostgreSQL 协议的程序。

一次典型连接包含：

```text
shell 进程
└── psql 客户端进程
    ── Unix socket 或 TCP/TLS ──▶ PostgreSQL server
                                  └── 为该连接服务的 backend
```

`psql` 不是数据库服务器。安装 psql 只获得客户端，不代表服务器已启动；服务器启动也不代表当前角色有权连接目标数据库。客户端文件系统和服务器文件系统可能完全不同，即使它们恰好在同一台电脑上也要保持这个心智边界。

会话是一次已建立的连接及其上下文。会话有当前数据库、会话角色/当前角色、配置、事务状态和临时状态。关闭 psql 会结束该会话，但不会删除数据库，也不会撤销已经提交的事务。

## 3. 连接目标是一组坐标

一个可审计目标至少包含：

| 参数 | 回答的问题 | 常见选项/环境变量 |
| --- | --- | --- |
| host | 服务器在哪里，或用哪个 Unix socket 目录 | `-h` / `PGHOST` |
| port | 服务器监听哪个端口 | `-p` / `PGPORT` |
| database | 进入哪个数据库 | `-d` / `PGDATABASE` |
| user | 以哪个 PostgreSQL 角色发起认证 | `-U` / `PGUSER` |
| connect timeout | 最多等多久建立连接 | `PGCONNECT_TIMEOUT` 或 conninfo |
| TLS 等选项 | 怎样保护并校验传输目标 | conninfo/URI 参数 |

教学计划使用合成坐标：

```text
host=127.0.0.1
port=55432
dbname=factorycare_training
user=factorycare_reader
connect_timeout=2
```

它们只是离线契约，不代表该端口实际有服务。选择 `127.0.0.1` 和非默认端口，是为了明确“只允许一次性本地训练实例”的意图；验证脚本不会真的尝试连接。

### 默认值为何危险

官方 psql 文档说明，省略 host 时 Unix 系统通常尝试本地 Unix-domain socket；默认 user 往往来自操作系统用户名，默认 database 又可能采用该用户名。便捷默认值适合明确受控的交互环境，却不适合作为自动化证据：

```sh
psql
```

这条命令没有告诉审阅者目标是谁。即使它成功，也不能证明进入了 `factorycare_training`。脚本应显式给出目标或使用受治理的 service/环境配置，并在连接后再次观察会话身份。

## 4. conninfo、URI 与独立参数

libpq 接受两类连接字符串：

```text
host=127.0.0.1 port=55432 dbname=factorycare_training user=factorycare_reader connect_timeout=2
```

或：

```text
postgresql://factorycare_reader@127.0.0.1:55432/factorycare_training?connect_timeout=2
```

它们能表达复杂目标，但 URI 中的用户名、参数甚至密码容易进入进程列表、历史、日志和截图。教材的可复制命令使用独立选项和不含秘密的环境变量：

```sh
PGCONNECT_TIMEOUT=2 \
psql -X --no-password \
  --host=127.0.0.1 \
  --port=55432 \
  --username=factorycare_reader \
  --dbname=factorycare_training
```

`--no-password` 表示不要交互提示，不等于“绕过认证”。若服务器需要密码且没有安全来源，连接应快速失败，自动化不能挂起等待人工输入。

连接参数可来自命令行、环境变量、service 文件、URI 或默认值，后出现或更具体的来源可能覆盖前者。故障排查要记录**最终生效目标**，不能只看你以为传入了什么。

## 5. 密码不属于命令文本

不要这样做：

```text
postgresql://user:real-password@host/database
PGPASSWORD=real-password psql ...
```

尤其不要把真实值写进 Markdown、仓库、CI 日志、命令历史或截图。PostgreSQL 官方提供 `.pgpass`/`PGPASSFILE` 机制；Unix 上密码文件必须禁止 group/world 访问，典型权限是 `0600`，否则会被忽略。生产中还可能使用平台 secret store、短期凭据或身份代理。

本章不创建任何密码文件，也不读取环境中的密码。离线计划明确禁止 `password`、`passfile` 内容和带密码 URI。安全来源由实际环境治理，本章只规定“命令和证据不得泄露秘密”。

## 6. database、schema 与 role 不是同一层

连接成功后，必须分清三个名词：

- **database**：一次普通会话只连接一个数据库；
- **schema**：当前数据库内的命名空间，包含表等对象；
- **role**：cluster 范围的数据库身份；连接以某角色认证，权限检查使用当前用户/角色；
- **table**：位于某数据库的某 schema 中，例如 `factorycare.device`。

一个角色可以被允许连接多个数据库；一个数据库有多个 schema；同一个 schema 中有多张表。角色并不是 schema 的另一个名字，也不因与 schema 同名就自动拥有它。

PostgreSQL 的 `search_path` 决定未限定对象名按什么 schema 顺序解析。`current_schema` 是路径中首个有效 schema，不表示数据库只有一个 schema。为了证据清楚，教学探针同时输出 database、current user、current schema 和 search path；生产安全还要审查可写 schema，不能盲信默认路径。

角色管理如 `CREATE ROLE`、`GRANT`、`SET ROLE` 不在本章范围。这里仅观察“当前会话以谁的权限工作”。

## 7. 启动 psql 前先预测

运行前写下：

```text
expected host: 127.0.0.1
expected port: 55432
expected database: factorycare_training
expected role: factorycare_reader
expected script: inspect-session.sql
expected mode: non-interactive, read-only, stop on first error
```

若实际输出与任一项不同，停止；不要为了“先跑起来”接受默认库。连接成功本身不是正确目标证据，认证成功也不是授权范围正确证据。

## 8. psql 提示符与事务状态

交互提示符通常包含数据库名和状态字符，但它可以被配置，不能作为唯一安全证明。常见外观：

```text
factorycare_training=>
factorycare_training=*>
factorycare_training=!>
```

默认提示中 `=` 常表示不在显式事务块，`*` 常表示事务块中，`!` 常表示事务失败状态。提示符可定制，因此自动化应使用明确命令和结果，不解析人眼提示符做生产判断。

输入未以分号结束时，psql 可能显示续行提示并继续等待。这不一定是服务器卡住；先检查引号、括号和语句终止，再用 `\r` 清空尚未发送的 query buffer。不要反复按回车后误以为数据库无响应。

## 9. SQL 与 psql 元命令由不同一侧处理

以反斜杠开头的 psql 元命令通常由客户端解析，不是发送给服务器的 SQL：

| 元命令 | 用途 | 关键边界 |
| --- | --- | --- |
| `\conninfo` | 显示当前连接信息 | 客户端格式，包含 SSL 信息时可辅助核对 |
| `\l` | 列出可见数据库 | 会查询服务器；可见不等于可连接/可管理 |
| `\c` / `\connect` | 切换连接 | 脚本失败时要防止继续作用于旧目标 |
| `\dn` | 列出 schema | 结果受权限与 pattern 影响 |
| `\dt` | 列出表 | 默认 pattern/search path 可能隐藏其他 schema |
| `\d name` | 描述关系 | 元命令内部会查询系统目录 |
| `\i file` | 包含并执行文件 | 相对当前工作目录解析 |
| `\ir file` | 相对当前脚本目录包含 | 脚本组合通常更可复现 |
| `\copy` | 客户端参与导入/导出 | 文件在客户端侧，权限属于运行 psql 的 OS 用户 |
| `\echo` | 输出脚本文本/变量 | 不证明服务器执行了 SQL |
| `\q` | 退出 psql | 只结束相应输入层/会话 |

SQL 用分号终止；元命令通常在行末结束，不加 SQL 分号。把 `\dt;` 写成带分号的 pattern 可能得到令人困惑的结果。

## 10. 连接后要核对两类身份

第一类是 psql 连接信息：

```text
\conninfo
```

第二类是服务器会话探针：

```sql
SELECT current_database() AS database_name,
       current_user AS role_name,
       current_schema AS schema_name,
       current_setting('server_version_num') AS server_version_num,
       current_setting('search_path') AS search_path;
```

本章把这段 SELECT 当固定探针，不展开投影、函数或别名语法。两类证据互补：

- `\conninfo` 说明客户端认为连接到哪里，并可能显示 SSL；
- 服务器函数说明当前 database、有效 role、schema/search path 和 server version；
- `psql --version` 只说明客户端版本，不能替代 server version；
- 客户端与服务器主版本可以不同，兼容性必须按实际组合验证，不能只凭“都能启动”。

## 11. 为什么自动化使用 `-X`

psql 默认可能读取系统 `psqlrc` 和用户 `~/.psqlrc`。启动文件可以改变输出格式、变量、提示、错误行为甚至执行命令。交互便利配置不应悄悄改变教学或 CI 结果。

```sh
psql -X ...
```

`-X`/`--no-psqlrc` 禁止读取这些启动文件，使脚本更可复现。它不会禁用服务器配置，也不会清空所有环境变量；连接参数仍需显式治理。

## 12. 用 `-f` 执行文件

推荐固定脚本：

```sh
psql -X \
  --set=ON_ERROR_STOP=1 \
  --file=scripts/inspect-session.sql \
  ...明确连接参数...
```

官方文档指出，`-f file` 与 shell 输入重定向通常都能喂入内容，但 `-f` 能让错误信息带更有用的文件行号。它也清楚表达“由 psql 读取这份脚本”，便于复现。

`-c` 的每个参数要么是服务器能完整解析的 command string，要么是一条反斜杠元命令；不要把 SQL 与 psql 元命令随意混在同一个 `-c` 字符串。复杂流程用版本控制中的脚本文件。

脚本路径也是输入。自动化从任意工作目录启动时，`-f relative.sql` 可能找错文件；shell runner 应先算出自身目录，传绝对路径。脚本内部包含子文件时，`\ir` 相对当前脚本目录解析，比 `\i` 相对进程工作目录更稳定。

## 13. `ON_ERROR_STOP`：不要在错误后装作成功

psql 默认在脚本遇到错误后继续处理。对交互探索可能方便，对自动化却可能出现：

```text
第 1 条成功
第 2 条失败
第 3 条成功
脚本最后看起来有成功输出
```

设置：

```text
\set ON_ERROR_STOP on
```

或命令行：

```sh
--set=ON_ERROR_STOP=1
```

非交互脚本遇到错误会立即停止，并以退出码 3 区分脚本错误。不要只依赖脚本文件内设置，因为文件读取前的某些问题由 psql 自身报告；runner 仍应检查进程退出码。

`ON_ERROR_STOP` 控制客户端是否继续读取，不会自动把之前已提交的独立语句回滚。停止执行与事务原子性是两个不同旋钮。

## 14. psql 的退出码契约

PostgreSQL 18 官方文档定义：

| 退出码 | 含义 |
| ---: | --- |
| 0 | psql 正常结束 |
| 1 | psql 自身致命错误，例如文件不存在 |
| 2 | 非交互会话的服务器连接中断/连接问题类别 |
| 3 | 脚本发生错误且设置了 `ON_ERROR_STOP` |

操作系统、包装器或信号还可能产生其他状态，因此不要把表格扩展成所有环境的绝对枚举。最小诊断组合是：

```text
exit code + stderr 第一条错误 + 是否已建立会话 + 脚本文件/行号 + SQLSTATE（若服务器返回）
```

连接参数错误可能在任何 SQL 发送前失败；语法错误则意味着连接已经建立，服务器解析某条 SQL 并返回错误。两者修复路径完全不同。

## 15. stdout、stderr 和退出码都要保存

- stdout：查询结果、很多元命令输出和普通状态；
- stderr：连接错误、SQL 错误、警告等诊断；
- exit code：进程对 shell 的最终状态。

把 stderr 合并进 stdout 会丢失来源信息；只截图终端又可能裁掉退出码。验证记录至少保存：

```text
command（脱敏）
client version
expected target
stdout 文件
stderr 文件
exit code
是否连接成功
第一条可信错误
```

不要把“stderr 为空”当数据库正确，也不要把“有 WARNING”自动当失败；验收应明确期望的状态和内容。

## 16. 事务边界：自动提交不是整份文件一笔事务

如果没有显式事务块，PostgreSQL 的行为可理解为每条命令独立提交。这意味着脚本中间失败时，之前成功的语句可能已经永久生效。

显式边界：

```sql
BEGIN TRANSACTION READ ONLY;
-- 固定只读探针
COMMIT;
```

失败时可以：

```sql
ROLLBACK;
```

对由 `-c`/`-f` 执行的脚本，psql 还提供：

```sh
--single-transaction
```

它在首个命令前发送 `BEGIN`，最后发送 `COMMIT`；若命令失败且 `ON_ERROR_STOP` 已设置，则发送 `ROLLBACK`。二者结合才能接近“全成或全撤”：

```sh
psql -X --set=ON_ERROR_STOP=1 --single-transaction --file=script.sql ...
```

边界：

- 脚本若自己包含 `BEGIN`、`COMMIT` 或 `ROLLBACK`，`--single-transaction` 可能不产生期望效果；
- 不能在事务块中执行的命令会让整体失败；
- 客户端进程被强制终止、连接丢失等情况仍要用服务器证据确认结果；
- 事务能控制数据库变更，不能回滚 psql 已写出的客户端文件或执行的 shell 命令；
- 本章实验只读，不把 `--single-transaction` 冒充写入恢复演练。

## 17. 失败事务状态

显式事务中的某条 SQL 报错后，PostgreSQL 通常把该事务置为失败状态；后续普通 SQL 会继续被拒绝，直到 `ROLLBACK`。提示符常显示 `!`，服务器消息也会说明当前事务已中止。

不要用反复重跑后续语句修复失败事务。先保存第一条错误，再回滚，修复原脚本，从干净事务重跑。第一条错误比一串“current transaction is aborted”更接近根因。

## 18. `\connect` 失败不能静默回到旧库

交互模式下，`\connect` 尝试新目标失败时，psql 可能保留旧连接以方便用户修正；非交互脚本采用更安全的行为，失败后关闭旧连接，避免脚本误在旧数据库继续工作。

因此：

- 交互切库后立刻 `\conninfo`；
- 自动脚本不要依赖隐式复用旧参数；
- `ON_ERROR_STOP` 必须开启；
- 每份高风险脚本开头断言 database/role/schema；
- 错目标时应非零退出，而不是“尽量找一个可连接的库”。

## 19. 导入导出：`\copy` 与 `COPY`

SQL `COPY` 和 psql `\copy` 都能搬运数据，但文件位置与权限不同：

| 形式 | 谁读取/写入文件 | 路径从谁的视角解释 |
| --- | --- | --- |
| `COPY table FROM '/path/file.csv'` | PostgreSQL server | 服务器文件系统与 server OS 用户 |
| `\copy table FROM 'file.csv'` | psql 客户端传输 | 客户端文件系统与运行 psql 的 OS 用户 |
| `COPY ... FROM STDIN/TO STDOUT` | 经连接传输 | 数据流，而非任意服务器文件 |

所以本地文件“明明存在”但 server-side COPY 报不存在，可能是你把客户端路径交给了另一台服务器。`\copy` 不需要 server 直接访问客户端文件，但仍需数据库对象权限和本地文件权限。

### 安全导入契约

导入前至少确认：

- 目标 database/schema/table 和明确列列表；
- 文件编码、CSV header、delimiter、quote、escape；
- `NULL` 标记与空字符串如何区分；
- 重复键、非法外键、坏行的处理策略；
- 事务边界和失败后是否保留部分行；
- 输入来自可信固定文件，而非生产导出的敏感数据；
- 预估行数和导入后核对方式。

PostgreSQL 18 的 `COPY` 支持更多错误处理选项，但本章不把“跳过坏行”设为默认。新手应先让固定训练文件在第一处错误失败，理解数据契约后再决定容错策略。

### 安全导出契约

导出前确认：

- 查询/表是否只包含允许离开的列；
- 目标文件在客户端还是服务器；
- 文件是否会覆盖已有证据；
- CSV 中 `NULL` 与空字符串是否可逆；
- 输出目录权限、保留期和清理方式；
- 日志是否泄漏数据。

`COPY PROGRAM` 或 `\copy ... program` 会执行命令，并涉及 shell 输入安全。本教材不使用它们；不要把不可信值拼进命令字符串。

## 20. 元命令不等于权限证明

`\dt` 没显示表，可能因为：

- 当前 database 错；
- pattern 或 schema 限定不匹配；
- `search_path` 不含目标 schema；
- 当前角色无可见权限；
- 对象不是普通表；
- 启动文件改变显示；
- 表确实不存在。

反过来，能列出对象也不等于有权修改。第一步是核对会话目标和显式 schema，例如 `\dt factorycare.*`，再根据具体错误区分不存在与权限拒绝。不要为了让列表出现就切换超级用户。

## 21. 常见错误的证据矩阵

| 故障 | 是否连接成功 | 首个可信证据 | 常见 psql 退出 |
| --- | --- | --- | ---: |
| host/port 无监听 | 否 | stderr 中实际地址/端口与 refused/timeout | 2 |
| database 不存在 | 否 | 服务器连接错误指明 database | 2 |
| 认证失败 | 否 | 认证错误，不等于网络错误 | 2 |
| `-f` 文件不存在 | 不一定发起连接 | psql 自身 file not found | 1 |
| 脚本 SQL 语法错且 stop-on-error | 是 | 文件、行号、ERROR、SQLSTATE | 3 |
| SQL 错误但未 stop | 是 | stderr 有错误，进程可能仍正常结束 | 可能 0 |
| 显式事务已失败 | 是 | 第一条 SQL 错误，随后 aborted 提示 | 依调用方式 |
| 错误 schema | 是 | 会话探针/search path 与对象错误 | 3 或继续 |

表中的典型退出码以官方 psql 契约和非交互模式为基础；真实认证库、包装器和信号结果仍应现场记录。

## 22. 一份可审计的 runner

概念命令：

```sh
PGCONNECT_TIMEOUT=2 \
psql -X \
  --no-password \
  --set=ON_ERROR_STOP=1 \
  --host=127.0.0.1 \
  --port=55432 \
  --username=factorycare_reader \
  --dbname=factorycare_training \
  --file=/absolute/path/inspect-session.sql
```

逐项说明：

- `PGCONNECT_TIMEOUT=2`：连接阶段有上限；
- `-X`：不加载用户启动文件；
- `--no-password`：无安全凭据时立即失败，不交互等待；
- `ON_ERROR_STOP=1`：脚本错误立即停止；
- host/port/user/database：目标显式；
- `--file`：错误位置可追踪；
- 绝对路径：不依赖调用者当前目录。

本章实际脚本选择“脚本内显式 `BEGIN TRANSACTION READ ONLY`/`COMMIT`”，所以 runner 不再叠加 `--single-transaction`。另一种合法方案是删去脚本内所有事务控制，再由 `--single-transaction` 包裹；不要把两种所有权同时打开。

该命令仍不是生产模板：真实 TLS 校验、认证、service discovery、连接池、审计和变更审批需要单独设计。本章不假定 `sslmode` 的单一值适合所有本地/远程环境。

## 23. FactoryCare 只读会话脚本

配套脚本的职责是观察：

```text
\set ON_ERROR_STOP on
\conninfo

SELECT current_database(),
       current_user,
       current_schema,
       current_setting('server_version_num'),
       current_setting('search_path');

\dn
\dt factorycare.*

BEGIN TRANSACTION READ ONLY;
SELECT current_database(), current_user, current_schema;
COMMIT;
```

真实执行时预期：

1. `\conninfo` 显示指定目标；
2. 服务器探针匹配预期 database/role/schema；
3. 元命令只观察可见对象；
4. 只读事务明确开始并提交；
5. 退出码为 0；
6. stderr 不含意外 ERROR。

离线 oracle 只检查脚本具备这些结构、没有 DDL/DML/角色管理、计划不含密码，并对固定 transcript 分类。

## 24. 离线 oracle 的边界

[最小示例](../../../examples/encyclopedia/ch.data.postgresql-psql/README.md)验证：

- 连接坐标全部显式且只指向合成本地目标；
- `-X`、`--no-password`、`ON_ERROR_STOP` 和 `--file` 齐全；
- 脚本包含连接/会话探针和只读事务；
- 事务由脚本显式拥有，未与 `--single-transaction` 重叠；
- 成功、连接失败、psql 自身失败、SQL 脚本失败映射到 0/2/1/3。

[实验](../../../labs/encyclopedia/ch.data.postgresql-psql/README.md)进一步模拟错误 database、文件缺失和中途 SQL 错误，要求指出失败发生在连接、客户端读文件还是服务器解析阶段。[公开练习](../../../exercises/encyclopedia/ch.data.postgresql-psql/README.md)故意遗漏安全选项与目标，starter 应保持红灯。

离线 parser 不是 PostgreSQL。它不解析完整 SQL、不建立 socket、不认证、不验证 TLS、不访问真实 schema，也不证明某个 `psql` patch 的输出格式。其价值是在当前机器没有 PostgreSQL 时，仍能确定地阻止含密码、隐式目标、继续执行和破坏性语句进入教材主路径。

## 25. 预测—运行—诊断

### 预测

对四个场景先写阶段和退出码：

1. 端口 55432 无服务器；
2. `--file` 指向不存在文件；
3. 连接成功，脚本第 8 行语法错误且 stop-on-error；
4. 全部只读探针成功。

推荐预言：

```text
no listener -> connection -> exit 2 -> zero SQL statements
missing file -> psql client -> exit 1 -> file evidence
syntax error -> server SQL -> exit 3 -> stop at failing statement
success -> complete -> exit 0 -> target identity must also match
```

### 运行

先运行离线 oracle，保存固定 stdout。真实 PostgreSQL 实验只能在明确创建的一次性本地训练实例上进行，并由用户主动提供环境；本章验证器不会探测或复用已有服务。

### 诊断

每次只改变一个输入：

- port 从 55432 改错；
- database 改为不存在名称；
- 去掉 `ON_ERROR_STOP`；
- 删除 `-X`；
- 脚本加入一行故意语法错；
- 交换 database 与 schema 名。

记录首个失败，不要同时改五项后凭猜测修复。

## 26. 安全检查单

- [ ] 命令、URI、日志和截图不含密码；
- [ ] host、port、database、role 与脚本路径显式；
- [ ] 连接超时有上限，非交互不提示；
- [ ] 连接后核对 `\conninfo` 与服务器会话身份；
- [ ] 自动化使用 `-X` 和 `ON_ERROR_STOP`；
- [ ] 写入脚本先定义事务与回滚，本章只读；
- [ ] 导入有固定列、格式、NULL 和行数契约；
- [ ] 导出经过数据最小化与路径权限检查；
- [ ] 不使用生产数据库、真实导出或超级用户；
- [ ] 保存 stdout、stderr、exit code，区分已验证和推测。

## 27. AI 协作边界

让 AI 生成 psql 命令前，要求它明确：

1. 最终连接坐标及每个默认值来源；
2. 秘密从哪里安全取得，但不要输出秘密；
3. 脚本错误是否停止；
4. 事务包含哪些语句；
5. 文件位于客户端还是服务器；
6. 失败时预期退出码和第一条证据；
7. 命令是否可能触及已有数据库；
8. 回滚能覆盖数据库变更还是也涉及外部文件。

拒绝以下做法：

- 自动扫描本机端口并选择“能连上的库”；
- 把密码拼进 URI；
- 用生产备份作练习；
- 为了绕过权限切超级用户；
- 遇错后继续执行并只检查最后输出；
- 在未确认目标时运行导入、删除或角色管理命令。

## 28. 故障速查

| 现象 | 第一检查 | 下一证据 |
| --- | --- | --- |
| connection refused | stderr 的实际 host/port | 服务是否监听该地址，不是密码 |
| no such file/socket | host 被解释为哪个 socket 目录 | client/server socket 配置 |
| database does not exist | `--dbname` 最终值 | 是否把 schema 当 database |
| password authentication failed | role、认证方法、秘密来源 | 不要在命令打印密码 |
| `\dt` 无结果 | database、schema pattern、search path | `\dn` 与显式 `schema.*` |
| 脚本报错却退出 0 | 是否设置 `ON_ERROR_STOP` | stderr 与 runner 状态 |
| current transaction is aborted | 第一条 SQL ERROR | `ROLLBACK` 后修复重跑 |
| COPY 找不到本地文件 | 用的是 `COPY` 还是 `\copy` | server/client 文件系统 |
| 本地能跑 CI 不能跑 | `.psqlrc`、环境默认、相对路径 | `-X` 与显式参数 |
| 版本对不上 | client `psql --version` vs server probe | 实际兼容组合 |

## 29. 120 秒复述模板

> PostgreSQL 是客户端/服务器系统，psql 只是终端客户端。一次连接目标由 host、port、database、role 和连接选项组成，连接成功后还要用 `\conninfo` 和服务器探针确认实际 database、current user、schema、search path 与 server version。database 是一次会话进入的数据库，schema 是其中的命名空间，role 是 cluster 范围身份。自动脚本使用 `-X -v ON_ERROR_STOP=1 -f`，检查 stdout、stderr 和退出码；需要原子边界时再正确使用事务或 `--single-transaction`。psql 的 0/1/2/3 分别表示正常、自身致命错误、连接问题和 stop-on-error 脚本错误。`\copy` 从客户端文件系统搬运，SQL COPY 的文件由服务器访问。反例是只运行 `psql` 依赖默认值，再把最后一行成功当作正确目标。

## 30. 间隔复习

- 24 小时后：默写连接五元组与 `-X/ON_ERROR_STOP/-f` 的职责；
- 3 天后：为四种失败按“连接—客户端—服务器—事务”分类；
- 7 天后：解释 database、schema、role 和 server/client 文件系统边界；
- 14 天后：给一份含隐式目标、密码 URI、无事务和 `\copy` 路径的脚本，逐项标风险。

## 31. 官方资料

- [PostgreSQL 版本策略：18.4 为当前 18.x minor](https://www.postgresql.org/support/versioning/)
- [PostgreSQL 18 psql：选项、元命令、变量与退出状态](https://www.postgresql.org/docs/18/app-psql.html)
- [PostgreSQL 18 libpq 连接字符串与参数](https://www.postgresql.org/docs/18/libpq-connect.html)
- [PostgreSQL 18 database/schema 层次与 search_path](https://www.postgresql.org/docs/18/ddl-schemas.html)
- [PostgreSQL 18 数据库角色边界](https://www.postgresql.org/docs/18/database-roles.html)
- [PostgreSQL 18 会话信息函数](https://www.postgresql.org/docs/18/functions-info.html)
- [PostgreSQL 18 事务启动与自动提交说明](https://www.postgresql.org/docs/18/sql-start-transaction.html)
- [PostgreSQL 18 COPY](https://www.postgresql.org/docs/18/sql-copy.html)
- [PostgreSQL 18 密码文件与 Unix 权限](https://www.postgresql.org/docs/18/libpq-pgpass.html)
- [PostgreSQL 18 连接建立的客户端/服务器模型](https://www.postgresql.org/docs/18/connect-estab.html)

## 32. 已验证、未验证与非目标

已在本机验证：四类离线资产的连接计划、安全选项、脚本结构、只读/禁止语句边界、0/1/2/3 transcript 分类和公开 starter 红灯；连续运行输出应确定且不访问网络。

未验证：真实 PostgreSQL 18.4/psql 18.4 的连接、认证、TLS、元命令展示、事务回滚、COPY、权限、跨版本客户端兼容和操作系统差异；本机没有相应二进制，也没有启动数据库。零基础试读、人工审查和全仓回归延期到 P9。

刻意不做：不安装或启动 PostgreSQL，不探测已有数据库，不管理角色，不执行生产导入导出，不教授查询、DDL、备份恢复、复制、高可用或性能运维。向后兼容妥协：无；本章替换的是 `planned` 占位正文，没有旧命令契约需要保留。

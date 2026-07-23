---
schema_version: 2
edition: 2026.2-draft
id: ch.flutter.network-storage-offline
title: 网络取消、安全存储、缓存与离线队列
responsibility: 在 Flutter 中实现可取消 HTTP、认证安全存储、版本化缓存和幂等离线队列，复用服务端幂等合同而不依赖 uni-app 实现。
volume: '11'
order: 16
level: L3
status: drafting
path: book/volume-11-dart-flutter/chapters/ch.flutter.network-storage-offline.md
catalog: "../../../curriculum/catalog.yml"
prerequisites:
- ch.flutter.state-lifecycle
- ch.architecture.idempotency-concurrency
version_surfaces:
- flutter-stable
- dart-stable
route_tags:
- zero-base
- accelerated-48
- reference
- factorycare-project
stable_core: false
outcomes:
- id: explain
  kind: concept
  text: 在 120 秒内解释“网络取消、安全存储、缓存与离线队列”的职责、边界、失败模式与证据，并给出一个越界反例
  covers_topic_groups:
  - flutter-network-storage
  - flutter-offline-replay
  covers_topics:
  - flutter.http-client-boundary
  - flutter.network-cancellation
  - flutter.secure-storage
  - flutter.cache-versioning
  - flutter.connectivity-signal
  - flutter.offline-command-queue
  - flutter.idempotency-key
  - flutter.replay-backoff
  - flutter.conflict-state
  - flutter.poison-command
  uses_capabilities:
  - mobile.flutter-network-offline
  - mobile.dart-future-cancellation
  - mobile.flutter-layout-lifecycle
  - foundation.http-message
  - architecture.idempotency-consistency
  evidence_kind: timed-teach-back
  verification_mode: oral-explanation
- id: build
  kind: independent-build
  text: 实现带安全凭据、版本化缓存和持久离线队列的 Flutter 工单客户端；独立保存输入、工件、命令与成功/边界/失败结果
  covers_topic_groups:
  - flutter-network-storage
  - flutter-offline-replay
  covers_topics:
  - flutter.http-client-boundary
  - flutter.network-cancellation
  - flutter.secure-storage
  - flutter.cache-versioning
  - flutter.connectivity-signal
  - flutter.offline-command-queue
  - flutter.idempotency-key
  - flutter.replay-backoff
  - flutter.conflict-state
  - flutter.poison-command
  uses_capabilities:
  - mobile.flutter-network-offline
  - mobile.dart-future-cancellation
  - mobile.flutter-layout-lifecycle
  - foundation.http-message
  - architecture.idempotency-consistency
  evidence_kind: runnable-artifact-and-oracle
  verification_mode: mock-server-offline-restart-test-duplicate-replay-test
- id: diagnose
  kind: fault-diagnosis
  text: 面对“仅用 mounted 防请求、明文凭据、缓存 schema 漂移或每次重放生成新幂等键”，指出失败阶段和首个可信证据，修复后重跑原验证并说明残余风险
  covers_topic_groups:
  - flutter-network-storage
  - flutter-offline-replay
  covers_topics:
  - flutter.http-client-boundary
  - flutter.network-cancellation
  - flutter.secure-storage
  - flutter.cache-versioning
  - flutter.connectivity-signal
  - flutter.offline-command-queue
  - flutter.idempotency-key
  - flutter.replay-backoff
  - flutter.conflict-state
  - flutter.poison-command
  uses_capabilities:
  - mobile.flutter-network-offline
  - mobile.dart-future-cancellation
  - mobile.flutter-layout-lifecycle
  - foundation.http-message
  - architecture.idempotency-consistency
  evidence_kind: failure-log-fix-rerun
  verification_mode: injected-fault-rerun
generated_by: scripts/generate-curriculum.rb
generated_spec_digest: 17bdfc4dc88ff543cb06dadae8f7ecfc4dabd4a0a3ef6053db3003e36a2fd129
---
# 网络取消、安全存储、缓存与离线队列

> 一次“提交工单”可能经历断网、超时、页面销毁、进程被杀、重新登录与重复重放。可靠客户端不能只写一个 `await http.post(...)`。它必须把网络工作、凭据、缓存和待执行命令分别建模，并与服务端约定重复请求的语义。本章从零建立这些合同；示例不绑定某个 HTTP、数据库或安全存储插件。

## 1. 先画清四条边界

初学者常把所有数据都叫“缓存”，把所有失败都 catch 成“网络错误”。这样写很快，但无法回答数据是否权威、能否删除、是否需要重试、是否含有敏感信息。先分清四条边界：

1. **HTTP 客户端边界**负责把方法、URI、请求头和请求体发送出去，把状态码、响应头、字节与传输失败翻译成应用认识的结果；它不决定 UI 显示哪一段文字。
2. **凭据边界**负责读取、写入、轮换和删除令牌等认证秘密；普通偏好设置、源码常量、日志和离线命令正文都不是它的位置。
3. **缓存边界**保存可丢弃、可重建的读取结果，并记录 schema、时间与服务端版本；缓存过期不等于业务数据被删除。
4. **离线命令队列**保存用户已经发出的写意图，直到服务器确认、用户解决冲突或系统明确放弃；它不是随时可清空的读取缓存。

以 FactoryCare 为例，“设备列表快照”可以是缓存；“用户刚提交但尚未上传的维修记录”是待同步命令；访问令牌是凭据；`POST /api/work-orders/{id}/transitions` 是 HTTP 边界。把后两者塞进同一个普通 JSON 文件，会同时制造数据丢失和秘密泄露风险。

一个很实用的判断题是：“清空它以后，应用能否只靠服务器恢复？”能恢复的读取副本可能是缓存；不能恢复的用户意图必须作为持久业务数据；能够代表用户身份的值属于凭据；四者的备份、删除和日志规则不同。

## 2. HTTP 不是只看 JSON 正文

HTTP 响应至少包含状态码、响应头和正文。`200`、`201`、`204` 都可能表示成功，但 `204` 没有 JSON 正文；`400` 表示当前请求不符合合同；`401` 通常要求重新认证；`403` 是已识别主体没有权限；`404` 可能是资源不存在，也可能是服务端避免暴露资源；`409` 常用来表达版本或状态冲突；`429` 和部分 `5xx` 可能允许稍后重试。具体语义以项目 API 合同为准。

不要在 Widget 中直接解码任意 JSON：

```dart
sealed class ApiResult<T> {
  const ApiResult();
}

final class ApiSuccess<T> extends ApiResult<T> {
  final T value;
  final String? etag;
  const ApiSuccess(this.value, {this.etag});
}

final class ApiConflict<T> extends ApiResult<T> {
  final String code;
  final Object? serverSnapshot;
  const ApiConflict(this.code, this.serverSnapshot);
}

final class ApiRejected<T> extends ApiResult<T> {
  final int status;
  final String code;
  const ApiRejected(this.status, this.code);
}
```

底层 transport 可以返回 `HttpResponse(status, headers, bytes)`；API service 校验 Content-Type、状态码、JSON 形状和必填字段；repository 再把远程 DTO 转成领域对象。解析错误不是“断网”，`401` 也不是“服务器繁忙”。错误分类会直接决定是否重试、是否登出、是否展示冲突界面。

请求同样有合同：方法是否幂等、路径参数是否编码、Content-Type 是否正确、授权头是否在允许的主机上发送、正文 schema 是哪个版本、是否带超时、追踪 ID 与幂等键。重定向到不同主机时继续附带 Authorization 可能泄露凭据，因此重定向策略也属于客户端边界。

## 3. 依赖倒置：让插件成为可替换细节

Flutter 官方网络 cookbook 使用 `http` package 演示请求，同时提醒不要把平台绑定的 `dart:io` 或 `dart:html` 直接散落在跨平台业务代码中。本章进一步把具体 package 藏在接口后：

```dart
abstract interface class WorkOrderRemote {
  CancelableCall<WorkOrderDto> fetchById(String id);

  CancelableCall<SubmitReceiptDto> submit(
    OfflineCommand command,
    AccessCredential credential,
  );
}

abstract interface class CancelableCall<T> {
  Future<T> get value;
  void cancel();
}
```

真实适配器可用支持 abort、close、cancel token 或客户端级取消的库；测试适配器用受控 `Completer`。repository 只依赖语义接口，因此更换网络库不会迫使 Widget、领域模型和离线队列一起改写。

接口必须诚实。如果底层库不能中止已经发出的工作，就不能把“以后不接收结果”命名成 `cancelNetworkRequest`。可以叫 `ignoreResult`，并在文档中说明资源仍可能继续消耗。命名是合同，不是装饰。

## 4. `Future` 默认不可取消

Dart 的 `Future<T>` 表示一个异步计算最终产生值或错误。它提供 `then`、`catchError`、`timeout` 等组合方法，但没有通用 `cancel()`。拿到 Future 后，调用者无法凭空知道底层是在读文件、等待计时器还是使用网络 socket，也无法通用地回滚它。

真正的取消必须由**工作生产者**提供协议。例如 `dart:io` 的 `HttpClientRequest.abort()` 能中止连接；某些第三方客户端提供 cancel token；Stream subscription 提供 `cancel()`；自己写的循环则必须在安全检查点读取取消信号。只有上层布尔变量而底层从不读取它，不构成取消。

```dart
final class CancellationSignal {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;
}

Future<void> processChunks(
  Iterable<List<int>> chunks,
  CancellationSignal signal,
) async {
  for (final chunk in chunks) {
    if (signal.isCancelled) throw const OperationCancelled();
    await persistChunk(chunk);
  }
}
```

这里是**协作式取消**：每个检查点之前已经完成的写入不会自动撤销，所以操作还要定义部分完成的语义。数据库事务、临时文件再原子替换、或可幂等地恢复，都是可能的方案。

## 5. `mounted` 只是 UI 接收门

在 StatefulWidget 中，`mounted` 表示 State 当前是否仍附着在树上。它能防止页面销毁后调用 `setState`，但不会取消 HTTP、停止服务器处理，也不会阻止 repository 写缓存。

```dart
final call = repository.load(orderId);
_activeCall = call;
try {
  final order = await call.value;
  if (!mounted || !identical(_activeCall, call)) return;
  setState(() => _state = Loaded(order));
} finally {
  if (identical(_activeCall, call)) _activeCall = null;
}

@override
void dispose() {
  _activeCall?.cancel();
  super.dispose();
}
```

上面有两道不同的门：`cancel()` 请求底层停止工作；`mounted + identical` 防止迟到结果更新错误页面。如果底层取消与响应恰好竞态，迟到结果门仍然必要。反过来，只检查 mounted 会让无用请求继续占连接、流量和服务器资源。

如果状态所有者不是页面而是应用级 repository，页面销毁也许不应取消共享请求。这不是例外，而是说明“谁拥有工作，谁决定生命周期”。页面独占的详情刷新通常随页面取消；多个页面共享的同步任务由 repository 或同步协调器拥有。

## 6. timeout、cancel 与 late result 是三件事

`future.timeout(duration)` 的准确含义是：超时后，返回的包装 Future 不再等待原 Future，并以超时结果完成。它**不能通用保证**原操作停止。官方 Dart API 的描述就是“Stop waiting for this future”，而不是终止底层计算。

工程上应同时设计：

- **连接、发送、首字节、总时长策略**：不同阶段可以有不同限制，具体由客户端支持情况决定。
- **可取消句柄**：超时发生时调用真实 transport 的 abort/cancel。
- **迟到结果门**：使用请求世代号或句柄身份，旧请求即使完成也不能覆盖新状态。
- **服务端幂等**：写请求在客户端超时时，服务器可能已经成功，不能盲目换新键重发。

设用户先选择工单 A，马上切到 B。A 请求慢、B 请求快。如果只写“最后完成者更新 UI”，A 会覆盖 B。可在启动时递增 generation：

```dart
var generation = 0;

Future<void> selectOrder(String id) async {
  final mine = ++generation;
  final result = await repository.fetch(id);
  if (mine != generation) return;
  state = Loaded(result);
}
```

generation 只拒绝旧结果，不中止资源；它应与底层取消组合。测试需要故意让 A 后完成，不能只测正常时序。

## 7. 认证凭据不是普通设置

用户名主题色、列表排序偏好可以放普通 key-value store；访问令牌、刷新令牌、私钥或会话秘密不应明文放在那里。安全存储适配器通常借助 Android Keystore 或 Apple Keychain 保护密钥材料，Flutter 业务层应依赖自己的 `CredentialStore` 接口，而不是把具体插件 API 传播到每个 repository。

```dart
abstract interface class CredentialStore {
  Future<AccessCredential?> read();
  Future<void> replace(AccessCredential value);
  Future<void> clear();
}

final class AccessCredential {
  final String accessToken;
  final DateTime expiresAt;
  const AccessCredential(this.accessToken, this.expiresAt);
}
```

安全存储降低“普通文件被复制就直接看到秘密”的风险，但不是魔法保险箱。已经解锁且被完全控制的设备、恶意输入法、运行时注入、截图、调试构建、日志和服务端泄漏仍可能暴露信息。不要承诺“存在 Keychain/Keystore 就绝对安全”。威胁模型至少说明：防谁、保护什么、设备是否可能 root/jailbreak、是否允许系统备份、登出和设备丢失如何处理。

凭据读取还会失败：首次安装为空、系统升级后条目损坏、生物认证取消、Keychain 权限配置不一致、Android 密钥失效。将它们区分为“无会话”“暂时无法解锁”“存储损坏需重新登录”，不要把任何异常都转成空令牌后继续请求。

## 8. 令牌刷新必须串行化

多个请求同时收到 401 时，如果每个都刷新一次，会出现刷新令牌轮换竞态：第二个刷新可能使用已失效旧令牌，甚至把较旧响应写回存储。常用做法是 single-flight：同一时刻最多一个刷新 Future，其他请求等待它，再各自重试最多一次。

规则需要明确：

1. 只有可判定为访问令牌过期的响应才触发刷新，不把无权限的 403 当过期。
2. 刷新请求本身不能递归触发刷新。
3. 成功后原业务请求最多重试一次，并保留原幂等键。
4. 刷新失败则原子清除无效会话、暂停离线重放并进入需登录状态。
5. 日志只记录 token 指纹或会话 ID 的安全摘要，绝不记录完整 Authorization。

如果离线命令跨越登出，必须有产品决定：删除、保留为不可读加密数据、还是重新登录同一账号后恢复。绝不能让 A 用户遗留命令在 B 用户会话下上传。

## 9. 缓存必须带 envelope

缓存不是“把当前对象 `jsonEncode` 一下”。应用升级后字段会新增、改名、变类型；旧进程可能在崩溃前只写了一半；服务端数据也可能已经变化。使用 envelope 保存解释 payload 所需的元数据：

```dart
final class CacheEnvelope {
  final int schemaVersion;
  final DateTime fetchedAt;
  final String? etag;
  final Object? payload;

  const CacheEnvelope({
    required this.schemaVersion,
    required this.fetchedAt,
    required this.etag,
    required this.payload,
  });
}
```

常见字段包括 `schemaVersion`、`fetchedAt`、`serverRevision/etag`、`accountId`、`payload`。版本是客户端持久格式版本，不要误用应用版本号。应用 4.3.1 可能仍使用 cache schema 2；也可能一次应用升级迁移多个 schema。

读取流程应为：读字节 → 验证 envelope 形状 → 依据 schema 逐步迁移或明确失效 → 校验字段与账户作用域 → 转 DTO → 转领域对象。不要把动态 Map 直接强转成最新实体。

## 10. 迁移、失效与原子写

对可重建读取缓存，有三种合法策略：

- **迁移**：旧数据量大、离线价值高，且转换合同明确时，从 v1 逐步转换 v2、v3。
- **失效并重取**：数据可从服务器恢复，迁移风险高时删除旧缓存；离线启动要显示“无可用缓存”，不能崩溃。
- **兼容读取窗口**：新代码暂时读取两版，但只写最新版；窗口结束后删除旧 reader。

迁移应是纯函数并有黄金输入；每一步只懂相邻版本，避免 `if version < 9` 的巨型函数。迁移失败要保留首个可信证据：缓存键、旧版本、失败字段与异常类型，但不得把敏感 payload 整段输出日志。

写入要考虑进程中断。文件存储可先写临时文件、flush 后原子替换；数据库可使用事务；key-value 插件是否提供事务与原子替换要查其文档。把“先删旧值再写新值”暴露给崩溃窗口，会让最后一个可用缓存消失。

缓存新鲜度是产品规则：超过 5 分钟是否禁止展示，还是展示并标记“最后更新于…”？离线应用通常宁可展示陈旧但标注清楚的数据。`fetchedAt` 使用 UTC 持久化，展示时再转本地时区；测试使用注入 Clock，不能依赖当前真实时间。

## 11. connectivity 是线索，不是事实

设备连接 Wi-Fi 只说明存在某种网络接口，不证明 DNS、TLS、代理、企业门户、VPN 或目标服务器可用；“无接口”也可能在检查后瞬间恢复。因此 connectivity 插件输出是**调度提示**，不是请求成功的权威判据。

合理用法：无网络信号时避免频繁主动唤醒；网络类型变化时触发一次有上限的同步；大附件只在符合用户设置的网络上自动传。最终仍由真实请求结果判断成功、认证失败、冲突或可重试传输错误。

反例是：`if (isOnline) { await post(); markSynced(); }`。检查与 POST 之间网络可能断开，更严重的是代码在请求成功前就标记已同步。正确顺序是持久命令 → 尝试请求 → 解析服务端确认 → 原子更新命令与本地投影。

## 12. 离线读取与离线写入不是一回事

Flutter 官方 offline-first 指南把 repository 作为组合本地与远程数据的单一入口，并列出多种读取策略：远程失败后回退本地、先发本地再发远程、或只读本地并由独立同步更新。没有一种适合所有功能。

读取列表可以先显示缓存，再后台更新。这里 UI 状态至少表达：数据来源、是否陈旧、刷新是否失败，而不是只有 `loading/error/data`。例如有旧数据且刷新失败时，保留列表并显示非阻塞提示，通常比用整页错误覆盖更好。

写入则涉及用户意图。在线限定写入可以保证即时得到服务端裁决；离线优先写入允许临时不一致，但必须持久化“稍后要做什么”。只在实体上放 `synchronized=false` 对单一覆盖式更新可能够用，但无法可靠表达多个有顺序的命令、删除、状态迁移与附件上传，所以 FactoryCare 使用显式命令队列。

## 13. 命令 envelope：在第一次接受意图时定身份

离线命令不是 API 请求的任意副本。它应保存重放所需的稳定业务信息：

```dart
enum CommandState { pending, inFlight, conflict, poisoned, acknowledged }

final class OfflineCommand {
  final String commandId;
  final String idempotencyKey;
  final String aggregateId;
  final String type;
  final int payloadVersion;
  final Map<String, Object?> payload;
  final DateTime createdAt;
  final int attempt;
  final DateTime nextAttemptAt;
  final CommandState state;
  final String accountId;

  const OfflineCommand({
    required this.commandId,
    required this.idempotencyKey,
    required this.aggregateId,
    required this.type,
    required this.payloadVersion,
    required this.payload,
    required this.createdAt,
    required this.attempt,
    required this.nextAttemptAt,
    required this.state,
    required this.accountId,
  });
}
```

`commandId` 是本地记录身份；`idempotencyKey` 是与服务端去重合同关联的身份，两者可以相同，也可以分开。最重要的不变量是：**同一个用户意图的所有重试和重放使用同一个 idempotencyKey**。它在首次接受意图时生成并持久化，绝不能在每次 HTTP 调用时生成。

先持久化再告诉用户“已加入待同步”。若采用乐观 UI，本地投影更新和命令插入最好在同一事务中；否则崩溃可能留下界面看似成功却没有待重放证据。对于不能事务化的存储，需要恢复日志或明确的写入顺序与补偿。

## 14. 客户端幂等键必须配合服务端合同

客户端固定一个 UUID 并不能单独保证业务只生效一次。服务器必须在认证主体与操作作用域内原子地记录幂等键、请求摘要和最终结果：

1. 首次收到键 K，验证请求并与业务写入在同一事务或等价原子边界中提交。
2. 再次收到相同 K 且请求摘要相同，返回原结果，不重复执行业务副作用。
3. 相同 K 配不同正文，拒绝为合同冲突，不能悄悄当成新命令。
4. 处理中重复到达时，等待、返回明确处理中状态或可查询句柄，不能并行执行两次。
5. 去重记录保留期必须覆盖客户端最大离线与重放窗口。

因此正确表述是：“在服务端满足幂等合同、键作用域和保留期的条件下，重复传输对应的业务效果至多一次。”不要宣称分布式系统天然 exactly-once。客户端可能收不到成功响应，但服务器已经执行；稳定键让它能安全询问同一结果。

对于 `POST transition`，请求摘要应包含会影响语义的工单 ID、目标状态、期望版本与正文。授权不能被第一次成功永久绕过：服务端要明确重复请求是返回历史结果，还是还需当前身份可访问结果。

## 15. 重放算法必须先分类，再退避

同步器一次取到到期的 pending 命令，将它持久标记为 inFlight，再用原 idempotencyKey 发送。进程可能在服务端成功后、本地确认前崩溃；重启时把遗留 inFlight 恢复为 pending，仍使用原键重放。这正是重复重放测试必须覆盖的窗口。

结果分类示例：

| 结果 | 默认动作 | 说明 |
| --- | --- | --- |
| 2xx 且响应合同有效 | acknowledged | 原子保存回执、更新投影、移出活跃队列 |
| 传输失败、超时、408、429、部分 5xx | pending + backoff | 是否重试仍以 API 合同和 Retry-After 为准 |
| 401 | 暂停队列，刷新一次 | 刷新失败进入需登录，不轮询轰炸 |
| 403/404 | poisoned 或人工处理 | 权限/资源通常不会靠立即重试恢复 |
| 409 | conflict | 保存服务端版本，等待合并、覆盖或放弃决定 |
| 400/422 或 payload schema 无法迁移 | poisoned | 命令本身无效，继续重试只制造流量 |

不要按“异常就重试”写无限循环。重试决策必须看到类型化错误、attempt、nextAttemptAt 和最大策略。服务端返回 `Retry-After` 时应在合理上限内尊重它。

## 16. 指数退避与 jitter

如果一万台设备断网后同时恢复，并且都在 1、2、4、8 秒重试，会形成同步尖峰。指数退避给出随尝试增长的上限，jitter 把客户端分散开。常见 full jitter 形式：

```text
cap = min(maxDelay, baseDelay * 2^attempt)
delay = random(0, cap)
```

生产随机源不应每次用固定种子；测试则注入确定性随机源与 Clock，以断言范围而不是依赖睡眠。attempt 要设置上限避免移位溢出。后台调度还受 iOS/Android 的电量和执行限制，应用不能承诺“精确在 30 秒后运行”。持久化的是最早可尝试时间，而不是定时器必达保证。

队列也要有公平性。一个失败大附件不应永远阻塞所有小命令；同一工单的状态命令却可能必须保序。常用策略是**每个 aggregate 串行、不同 aggregate 有界并行**，并设置全局并发、流量与电量限制。

## 17. 409 冲突是业务状态，不是网络错误

用户离线时把工单从 ASSIGNED 改为 IN_PROGRESS，服务器上可能已经被另一人 CLOSED。携带 `expectedVersion` 的命令会得到 409。客户端不能无限重试，也不能静默覆盖。

`conflict` 状态至少保存：本地意图摘要、提交时基线版本、服务器当前快照/版本、冲突代码和可选操作。UI 可以让用户查看差异，然后选择：接受服务器、依据新版本重新应用可兼容字段、或在有权限且业务允许时显式覆盖。每个选择产生**新的用户意图与新键**；原冲突命令保留审计关系，不修改正文后继续沿用旧键。

某些字段可自动合并，例如不同附件集合；状态机迁移通常不应通用地 last-write-wins。合并规则属于领域层与服务端合同，不属于网络插件。

## 18. poison command 要隔离且可解释

poison command 是无论重试多少次都不会按当前格式成功的命令，例如 payload 缺必填字段、旧 schema 无迁移、资源永久删除或权限被撤销。它若留在队头无限重试，会阻塞后续工作并耗电。

隔离时记录安全的错误代码、最后状态、attempt、诊断时间与关联 ID；敏感正文继续受保护。UI/运维入口应允许用户修正后创建新命令、放弃并回滚乐观投影，或导出脱敏诊断。不要简单 catch 后删除，否则用户会看到操作凭空消失。

队列要设置容量与过期策略，但不能静默淘汰未确认用户写入。达到容量时，应阻止新离线写、提示先同步或由产品定义归档方案。读取缓存的 LRU 淘汰规则不能复用到命令队列。

## 19. 敏感离线正文与最小化原则

安全存储适合小型秘密，不代表把整张业务数据库塞进 Keychain/Keystore。大体量离线数据通常存数据库或文件，并通过平台支持的密钥保护、文件保护或应用层加密降低静态泄漏风险。具体方案依平台、合规、备份与密钥恢复要求决定。

最先做的是数据最小化：命令只存重放所需字段，不复制完整用户档案；令牌只由凭据适配器在发送时注入，不写进命令；日志不记录 Authorization、身份证、精确位置和维修照片 URL 中的签名参数；多账号数据以 accountId 分区。

加密并不解决授权错误、运行中截取、错误账号上传、截图或服务端泄漏。密钥丢失也会让数据永久不可读，所以要为“安全删除”和“必须恢复”选择不同策略。登出前检查未同步命令：产品可能要求先同步、明确放弃、或加密保留给同一账号，不能无提示删除。

## 20. 重启恢复是一等场景

移动进程可能在后台被系统终止，不能依赖内存 List 或 Timer。启动恢复流程建议：

1. 打开版本化存储并完成 schema 迁移；迁移失败时停止同步，不能带错误解释继续读。
2. 读取当前会话身份，隔离其他账号的缓存和命令。
3. 将崩溃遗留的 inFlight 命令恢复为 pending；保留 commandId 与 idempotencyKey。
4. 重建本地投影，显示 pending/conflict/poison 数量。
5. 等待应用生命周期、认证、网络提示和调度策略允许后再同步。
6. 服务端确认后，事务化保存回执并更新本地业务视图。

测试中的关键注入点是“服务器已提交但客户端尚未写 acknowledged 时崩溃”。重启后必然再次发送；只有同一键与服务端去重才能防止重复业务效果。仅测“断网时排队、联网后一次成功”远远不够。

## 21. FactoryCare 完整链路

场景：维修人员在地下设备间把工单 `WO-42` 更新为 IN_PROGRESS，当时没有可用网络。

1. UI 发出 `StartWork(orderId, expectedVersion=7)`，application 层验证本地必要字段。
2. repository 在本地事务中插入命令 C，生成一次 `idempotencyKey=K`，同时把投影标为“待同步”；令牌不进入 C。
3. connectivity 信号仍显示 Wi-Fi，但真实 POST 传输失败。同步器把 C 设回 pending，计算 nextAttemptAt；UI 展示“已保存在本机，待同步”。
4. 应用被系统终止。重启时从持久存储恢复 C，K 保持不变。
5. 用户重新登录同一账号；凭据适配器在发送时读取新 token，同步器发送 C 和 K。
6. 服务器完成状态迁移，但响应丢失。客户端稍后仍用 K 重放，服务端返回第一次结果而不二次触发事件。
7. 客户端事务化记录回执，把投影版本更新为 8，命令 acknowledged。

如果服务器已经把工单改为 CLOSED，则返回 409 和当前版本。客户端把 C 置为 conflict，显示服务器状态并阻止自动重试。维修人员选择接受服务器，原命令作为审计记录结束；这不是网络错误。

附件上传可拆成另一个流程：先持久化本地文件引用与摘要，获取上传会话，分片传输，最后由幂等业务命令关联附件。不要把数十 MB 二进制直接塞进普通命令 JSON。

## 22. 测试矩阵与首个可信证据

一个可求职展示的最小矩阵应包含：

| 场景 | 注入 | 必须观察的判据 |
| --- | --- | --- |
| 成功读取 | 200 + 合法 JSON | DTO 校验后写最新版缓存 |
| HTTP 成功但 schema 错 | 200 + 缺字段 | 解析错误，不伪装断网、不覆盖好缓存 |
| 超时 | transport 延迟 | 等待结束且调用真实 cancel；旧结果不能提交 UI |
| 页面销毁 | await 期间 dispose | 无 setState after dispose；是否取消由所有者合同决定 |
| 凭据损坏 | secure adapter 抛类型化错 | 进入需重新登录/解锁，不发送空 Authorization |
| 缓存升级 | v1 fixture | 迁移到 v2 或明确失效，结果可重复 |
| 无网络后重启 | 队列快照 | 命令、attempt 与原键恢复 |
| 成功响应丢失 | 服务端已记 K | 重放仍用 K，业务效果计数保持 1 |
| 409 | 版本漂移 | command=conflict，不再自动重试 |
| 422 | 不可修复 payload | command=poisoned，不阻塞其他 aggregate |

日志应以事件结构保存：`command_id`、幂等键的安全摘要、aggregate、attempt、上次状态、下次状态、HTTP 分类、耗时、trace ID。首个可信证据不是最终的 `BUILD FAILURE`，而是第一次违反不变量的位置：例如重放前后的 key 不同、cache schema 无 reader、取消后 transport 仍未收到 cancel、409 被错误归为 pending。

避免靠 `Future.delayed` 猜时序。Fake transport 暴露手动完成、失败和 cancel 记录；Fake clock 控制重试到期；Fake store 可导出快照并创建新 repository 模拟进程重启。真正 T4 还要用 mock server、真实持久层与目标平台生命周期补充。

## 23. 诊断四个高频故障

### 23.1 “我已经判断 mounted，为什么服务器仍收到请求？”

失败阶段是网络工作所有权，不是 Widget 渲染。检查 dispose 是否调用可取消句柄、适配器是否把 cancel 传到底层、服务端 trace 是否仍运行。修复后同时断言 transport 收到 cancel 和迟到结果没有更新 UI。残余风险是请求可能在取消前已到服务端，写操作仍需幂等。

### 23.2 “升级后列表全空或启动崩溃”

先看持久 envelope 的 schemaVersion 与解析异常位置。不要立即把所有数据当最新 Map 强转。为旧 fixture 加迁移或明确失效策略，重跑旧版、损坏、未来未知版三个输入。残余风险包括旧版本分布比例与真实大数据迁移耗时。

### 23.3 “同一个提交执行了两次”

对比 command 创建、第一次发送、重启恢复和重放日志中的 key。如果每次 send 生成新 UUID，首个可信证据在客户端；若键相同仍重复，检查服务端作用域、请求摘要、原子提交与保留期。修复后注入“服务端成功、响应丢失”，业务效果必须保持一次。

### 23.4 “某条坏数据让整个同步永久卡住”

检查 4xx/409 是否被通用 catch 归为可重试，队列是否严格全局 FIFO。修复为类型分类、poison/conflict 隔离和每 aggregate 保序的有界调度；验证坏命令不再重试且其他工单仍能同步。

## 24. AI 协作边界

可以让 AI 生成 DTO、adapter 骨架、迁移函数初稿、Fake transport 和测试矩阵，但先提供合同：状态分类、所有者、敏感字段、幂等作用域、服务端响应与允许重试集合。否则 AI 很容易生成“catch 后无限重试”“mounted 等于取消”“每次请求新 UUID”“把 token 写 SharedPreferences”的貌似可运行代码。

必须由开发者核验：

- 阅读所选 HTTP 客户端版本文档，确认取消会作用于哪个阶段，close 是否影响共享连接。
- 阅读安全存储插件与目标平台文档，确认 Keychain access group、Android 备份、认证与密钥失效行为。
- 用真实 API 合同确认状态码、错误 code、幂等键 header、请求摘要、保留期与冲突正文。
- 人为制造响应丢失、重启和重复重放，而不是只看一次绿色 happy path。
- 检查日志、崩溃报告、analytics 与队列快照是否包含秘密。

开发者应能在不整段重新生成的情况下修改一个规则，例如“409 不自动覆盖”“429 读取 Retry-After”“同一工单串行”，并修复对应测试。能运行 AI 输出不等于理解分布式失败窗口。

## 25. 本章验证资产怎么读

本章随附四组 `verify.sh`，都只使用纯 Dart 和内存/文本快照，目的是验证可移植的不变量：Future 没有通用取消而我们定义协作协议、缓存 schema 必须迁移或拒绝、命令跨重启保留同一键、重复重放不重复业务效果。

- `examples` 是最小绿色合同模型。
- `labs` 注入断网、进程重启、响应丢失、409 与 poison，验证状态迁移。
- `exercises` 故意在每次重放生成新键，必须稳定红；学习者要先读失败标记再修复。
- `solutions-private` 是私有回归参考，不应该在无 AI 考试前打开。

这些脚本**没有**启动 Flutter Widget、模拟器、平台 Keychain/Keystore、真实数据库、真实 HTTP socket 或 mock server，也没有验证后台任务的 iOS/Android 调度。因此它们不能单独满足 canonical 中 T4 的全部 oracle。完整验收仍需目标 Flutter stable、可控 mock server、真实持久层、平台安全存储和进程/网络故障注入。

## 26. 120 秒讲解模板

可以按“职责—不变量—失败—证据—越界”组织：HTTP 边界翻译协议，不把所有失败叫网络错；Future 默认无通用取消，mounted 只阻止销毁后 UI 提交，timeout 只停止等待，真实取消需底层协议；凭据放平台安全存储适配器并承认受控设备等残余威胁；缓存带 schema 和新鲜度，可迁移或失效；离线写用持久命令队列，第一次接受意图时生成稳定幂等键，重试和重启不换键；服务器还要原子去重，才能保证重复传输下业务效果至多一次；409 进入冲突，永久无效命令进入 poison，不无限重试。证据来自取消记录、schema fixture、重启快照和响应丢失后的重复重放计数。越界反例是把安全存储说成绝对安全，或只凭客户端 UUID 宣称 exactly-once。

## 27. 复习与练习

1. 解释为什么 `Future.timeout` 返回 TimeoutException 后，服务器仍可能完成写入。
2. 画出页面、repository、CancelableCall 和 transport 的所有权；页面销毁时哪些工作取消、哪些继续？
3. 为 cache schema v1→v2 写迁移表，再说明遇到 v99 为什么应拒绝而不是猜测。
4. 给命令列出 `commandId/idempotencyKey/accountId/payloadVersion/attempt/nextAttemptAt/state` 的用途。
5. 预测“服务器成功后响应丢失”时客户端状态；重启后为什么必须再次发送原键？
6. 把 401、403、409、422、429、503、socket reset 分类为刷新、冲突、poison 或重试，并说明哪些取决于项目合同。
7. 设计一个日志事件，既能追踪同一命令，又不泄露 token 和敏感 payload。
8. 说明 connectivity 显示 Wi-Fi 时仍不能提前标记同步成功的原因。

## 28. 版本边界与官方资料

检索日期：**2026-07-24**。Flutter 官方文档当前页面标注通常反映 Flutter 3.44.7，Dart API 页面标注 Dart 3.12.2；当前学习机此前记录为 Flutter 3.35.7 / Dart 3.9.2，因此本章没有把需要 3.44.x 的具体插件行为伪装为本机已验证。HTTP 消息、Future 无通用 cancel、稳定幂等键、schema 迁移和 connectivity 只是提示属于跨版本稳定概念；具体 package API、平台 entitlement、后台调度和安全存储选项是版本/平台表面，实施前需按锁定版本重查。

- [Flutter：网络请求 cookbook](https://docs.flutter.dev/cookbook/networking/fetch-data)
- [Flutter：Offline-first support](https://docs.flutter.dev/app-architecture/design-patterns/offline-first)
- [Flutter：应用架构指南](https://docs.flutter.dev/app-architecture/guide)
- [Flutter：Key-value 持久存储架构](https://docs.flutter.dev/app-architecture/design-patterns/key-value-data)
- [Flutter：SQL 持久存储架构](https://docs.flutter.dev/app-architecture/design-patterns/sql)
- [Dart API：Future](https://api.dart.dev/dart-async/Future-class.html)
- [Dart API：HttpClientRequest.abort](https://api.dart.dev/dart-io/HttpClientRequest/abort.html)
- [Android Developers：Android Keystore system](https://developer.android.com/privacy-and-security/keystore)
- [Apple Developer：Keychain services](https://developer.apple.com/documentation/security/keychain-services)

## 29. 已验证、未验证与下一步

本章资产能在本地通过纯 Dart 确定性测试验证抽象合同，并通过一个稳定红练习暴露“重放生成新键”。正文的官方版本表面截至 2026-07-24 已核对。未验证项包括实际 Flutter Widget 生命周期、任一具体 HTTP package 的取消实现、真 Keychain/Keystore 配置、SQLite 崩溃原子性、真实服务端幂等事务、系统杀进程恢复、后台调度、电量与真实网络切换。进入 Week 35 项目验收时，应以同一状态机替换 Fake adapter，并补齐 mock server、真存储和目标平台 T4 证据，而不是把本章脚本数量当作掌握证明。

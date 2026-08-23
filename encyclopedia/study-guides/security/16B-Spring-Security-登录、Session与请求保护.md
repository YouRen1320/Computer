# Spring Security：登录、Session 与请求保护

## 1. Spring Security 解决的是“每个请求能否继续”

一个请求到达 Controller 之前，系统通常要先回答两件事：

1. 请求者是谁；
2. 这个身份能不能做当前操作。

第一件叫**认证（authentication）**，第二件叫**授权（authorization）**。登录只是获得认证状态的一种方式，不等于整个安全系统。

```text
HTTP 请求
  → 读取凭据
  → 验证身份
  → 保存本次请求的身份
  → 检查访问规则
  → Controller
```

Spring Security 的主要价值，是把这条链放在业务代码前面，并让登录、退出、CSRF、Session、异常响应等安全行为采用同一套规则。

## 2. 请求先经过过滤器链，再进入 Controller

Servlet 应用中的请求会先经过一组 Filter。Spring Security 把多个安全 Filter 组织成 `SecurityFilterChain`。

```text
客户端
  ↓
Servlet 容器
  ↓
Security Filter 1 → Filter 2 → Filter 3 → ...
  ↓
DispatcherServlet → Controller → Service
```

不同 Filter 分别处理某个职责，例如：

- 从 Session 恢复认证状态；
- 处理用户名密码登录；
- 检查 CSRF Token；
- 把安全异常变成 401、403 或登录跳转；
- 在进入业务代码前执行访问规则。

因此，Controller 没有执行，不一定是路由错误，也可能是请求已经被安全链拒绝。

## 3. SecurityFilterChain 是一套有匹配范围的规则

常见配置形式如下：

```java
@Bean
SecurityFilterChain webSecurity(HttpSecurity http) throws Exception {
    return http
            .authorizeHttpRequests(auth -> auth
                    .requestMatchers("/login", "/assets/**").permitAll()
                    .requestMatchers("/admin/**").hasRole("ADMIN")
                    .anyRequest().authenticated()
            )
            .formLogin(Customizer.withDefaults())
            .logout(Customizer.withDefaults())
            .build();
}
```

读这段配置时，先看最后的兜底规则：

```java
.anyRequest().authenticated()
```

它表示没有明确公开的请求也必须登录。比起“默认公开，想到哪里再保护哪里”，这种**默认拒绝**更不容易因遗漏新接口而暴露数据。

示例只是说明结构。真实项目还要根据浏览器页面、REST API、认证方式和错误合同调整。

## 4. 多条过滤器链按匹配范围和顺序选择

一个应用可能同时有：

- 浏览器管理端：Session + 表单登录；
- `/api/**`：Bearer Token + JSON 错误；
- 健康检查：只开放少量端点。

可以为这些范围建立不同的 `SecurityFilterChain`。一次请求通常由第一条匹配它的链处理，所以范围过宽或顺序错误，会让后面的链根本没有机会执行。

```text
请求 /api/work-orders
  → 链 1 是否匹配？若匹配，就使用链 1
  → 不匹配时再看链 2
```

常见错误是把第一条链写成“匹配所有请求”，随后为 API 配置的链永远到不了。排查时先确认“哪条链匹配”，再看链内规则。

## 5. SecurityContext 保存当前请求看到的身份

认证成功后，Spring Security 用 `SecurityContext` 保存本次执行上下文中的 `Authentication`。

可以把几个词这样理解：

| 名称 | 通俗意思 |
| --- | --- |
| `SecurityContext` | 当前执行过程的安全信息容器 |
| `Authentication` | 当前身份及其认证状态、权限 |
| `principal` | “这个人或客户端是谁” |
| `credentials` | 用来证明身份的材料，认证后通常不应继续暴露 |
| `authorities` | 当前身份被授予的权限标记 |

```text
SecurityContext
  └── Authentication
        ├── principal = user-123
        ├── authenticated = true
        └── authorities = [WORK_ORDER_READ, WORK_ORDER_ASSIGN]
```

业务代码应使用经过安全链建立的可信身份，不应相信请求体里自报的 `userId` 或 `role`。

## 6. SecurityContext 通常只代表当前执行上下文

在传统 Servlet 请求中，安全上下文经常与当前线程关联。请求结束后必须清理，否则线程池复用线程时可能串身份。

Spring Security 的过滤器会管理正常请求的加载和清理，但手动新建线程、把任务提交到线程池或异步执行时，不能想当然地认为身份自动传过去。

```text
请求线程：用户 A 的 SecurityContext
    └── 手动启动异步任务
          └── 未必自动拥有用户 A 的上下文
```

更重要的问题是：异步任务真的应该继承用户身份吗？后台任务常常需要显式记录“由谁触发”，再用受限的系统身份执行，而不是把 ThreadLocal 偷偷传遍系统。

## 7. 用户名密码登录是一条认证流水线

表单登录大致经历：

```text
提交用户名和密码
  → 登录 Filter 提取凭据
  → AuthenticationManager 协调认证
  → AuthenticationProvider 验证
  → UserDetailsService 等来源加载账号
  → PasswordEncoder 比对密码哈希
  → 成功后建立 Authentication
  → 保存到 SecurityContext / Session
```

这些对象不是为了让项目堆更多类，而是把“从哪里读用户”“怎样验证密码”“认证成功后保存什么”分开。以后换成 LDAP、OIDC 或其他方式时，不必把所有 Controller 重写。

## 8. 密码验证是比较哈希，不是解密密码

注册或修改密码时：

```text
原始密码 → PasswordEncoder.encode → 保存密码哈希
```

登录时：

```text
候选原始密码 + 已保存哈希 → PasswordEncoder.matches → true / false
```

密码哈希不可逆，不存在“把数据库密码解密出来比较”的正常流程。

Spring Security 常用委托式编码器在保存值中记录算法标识，例如概念上形如：

```text
{bcrypt}...
```

这样可以读取旧算法，同时让新密码采用新算法；用户下一次成功登录时还可以升级旧哈希。真正的算法和成本参数要按当时官方安全建议复核，不能永久照抄教程数字。

## 9. Session 登录把后续请求和服务端身份关联起来

第一次登录成功后，服务器通常创建或更新 Session，并通过 Cookie 把不可猜测的 Session ID 交给浏览器。

```text
登录响应：Set-Cookie: SESSION=abc...

后续请求：Cookie: SESSION=abc...
  → 服务端查 Session
  → 恢复 SecurityContext
  → 不必每次重新输入密码
```

Session ID 本身就是临时凭据。谁拿到有效 ID，谁往往就能以该用户身份请求，所以要使用 HTTPS、`Secure`、`HttpOnly`、合适的 `SameSite`、合理的过期策略，并避免写入日志或 URL。

## 10. 登录成功后要更换 Session ID

如果登录前后继续使用攻击者已知的 Session ID，就可能发生 Session fixation（会话固定攻击）。

安全行为是：在登录或权限明显提升时更换 Session 标识，同时按框架策略保留或迁移必要属性。

```text
登录前 Session = old-id
认证成功
登录后 Session = new-unpredictable-id
```

Spring Security 提供 Session fixation 防护；不要因为自定义登录流程而绕开它，也不要仅凭页面跳转判断标识是否真的轮换。

## 11. Session 生命周期需要明确边界

要决定的不只是“是否登录”，还包括：

- 空闲多久过期；
- 最长可持续多久；
- 同一账号允许多少并发 Session；
- 改密码、冻结账号或权限降低后，旧 Session 如何处理；
- 多实例部署中 Session 存在哪里；
- 存储不可用时是拒绝还是降级。

绝对时长和空闲时长解决不同问题。只要用户持续操作就永不过期，可能让被盗 Session 长期有效；过短又会严重影响使用体验。应按风险区分普通浏览和高敏操作，高敏操作可要求近期重新认证。

## 12. 退出必须让服务端认证状态失效

真正的退出通常包含：

1. 使服务端 Session 失效；
2. 清理安全上下文；
3. 删除或过期浏览器 Cookie；
4. 对需要 CSRF 防护的退出请求执行相同保护；
5. 记录必要但脱敏的审计信息。

只让前端跳转到登录页，旧 Cookie 仍可能继续使用。对 OAuth/OIDC 场景，本地退出和身份提供方 Session 退出还可能是两件不同的事。

## 13. CSRF 防护要和 Session 认证一起理解

浏览器会自动携带 Session Cookie，所以恶意站点可能借用户身份发修改请求。Spring Security 默认的 CSRF 保护正是为这类浏览器场景设计。

```text
Cookie：浏览器自动带上
CSRF Token：合法页面取得并显式提交
```

不要因为 API 使用 JSON 就机械关闭 CSRF。真正要看浏览器是否会自动携带用于认证的凭据。如果 REST API 只接受 `Authorization: Bearer ...`，且攻击站点无法让浏览器自动加该 header，威胁模型不同；但如果 Token 又放进 Cookie，CSRF 风险会回来。

## 14. CORS 应在认证失败之前也能正确响应

跨源前端可能先发 `OPTIONS` 预检。若安全链先把预检当作未认证业务请求拒绝，浏览器只会报告 CORS 失败，真正 API 根本没有执行。

合理配置应让受信来源的预检按 CORS 规则处理，同时仍对真实请求执行认证和授权。

```text
预检通过 ≠ 业务请求通过
CORS 允许来源 ≠ 该用户拥有工单权限
```

CORS 是浏览器跨源读取规则，不是服务器 API 的身份验证。

## 15. 401 和 403 表示不同失败

通俗区分：

- **401 Unauthorized**：当前请求没有可接受的认证身份，通常是未登录、Token 缺失或无效；
- **403 Forbidden**：身份已经确认，但没有当前操作权限，或被 CSRF 等访问控制拒绝。

Spring Security 的异常处理链会把不同安全异常交给相应入口：

- `AuthenticationEntryPoint` 处理需要开始认证的情况；
- `AccessDeniedHandler` 处理已认证但访问被拒绝的情况。

浏览器页面可以跳登录页，JSON API 则通常返回稳定的错误结构。不要把所有失败都重定向成 HTML，否则前端 API 调用会得到难以解析的页面。

## 16. URL 规则保护入口，方法规则保护能力

URL 规则能快速保护一组端点：

```java
.requestMatchers(HttpMethod.POST, "/api/work-orders/**")
.hasAuthority("WORK_ORDER_WRITE")
```

但同一个 Service 方法可能从 Controller、消息消费或定时任务调用。方法安全可以把关键能力保护放得更靠近业务入口，例如概念上：

```java
@PreAuthorize("hasAuthority('WORK_ORDER_ASSIGN')")
public void assign(...) { ... }
```

二者不是重复浪费：URL 层尽早拒绝明显非法请求，方法层保护关键能力。不过数据对象级规则不能只靠字符串角色；“能分派工单”不代表能分派任何租户的任何工单。

## 17. 前端隐藏按钮不是授权

前端可以根据权限隐藏“删除”按钮，改善体验，但攻击者可以直接构造 HTTP 请求。

```text
界面控制：告诉正常用户有哪些操作
服务端授权：决定请求是否真的执行
```

服务端必须在可信边界内检查操作、资源、租户和必要的业务状态。浏览器传来的 `disabled=true`、`role=ADMIN` 都只是输入。

## 18. 自定义 Filter 要先判断它是否真的必要

常见误区是遇到安全需求就继承一个 Filter，然后手动解析 Token、捕获异常、设置上下文。这样很容易遗漏：

- Filter 顺序；
- 重复执行；
- 上下文清理；
- 标准异常处理；
- issuer、audience、过期和签名验证；
- 多条链的匹配范围。

框架已有 Session、Bearer Token、OAuth2 Login 等支持时，应优先组合标准能力。确需自定义时，要明确它应在链中哪个行为之前或之后，并给未认证、无权限、异常和重复调度路径留证据。

## 19. 安全日志记录事实，不记录凭据

适合记录：

- 登录成功或失败类别；
- 被拒绝的操作、资源类型和租户；
- Session 建立、轮换、失效；
- 请求/Trace 标识；
- 规则命中结果。

不应记录：

- 原始密码；
- 完整 Session ID；
- 完整 Bearer/Refresh Token；
- CSRF Token；
- 不必要的个人数据。

调试模式可能输出过滤器链，但生产环境不能长期用高噪声和高敏感度日志。日志权限、保留期和脱敏同样属于安全设计。

## 20. 排查安全问题要沿请求链逐层定位

遇到“接口访问不了”，可以按这个顺序：

1. 请求是否到达正确主机和端口；
2. 方法、路径、Origin、Cookie 或 Authorization header 是否符合预期；
3. 哪条 `SecurityFilterChain` 匹配；
4. 身份是否成功建立，principal 和 authorities 是什么；
5. 被 CSRF、CORS、认证还是授权拒绝；
6. 是否进入 Controller；
7. 业务对象级权限是否又拒绝。

不要一看到 403 就关闭 CSRF 或把接口改成 `permitAll()`。那只是移除证据，不是找到原因。

## 21. 安全验证必须包含拒绝路径

正常用户成功访问只能证明一条允许路径。安全边界至少要覆盖：

| 场景 | 期望 |
| --- | --- |
| 未登录访问受保护资源 | 401 或符合页面合同的登录入口 |
| 已登录但无权限 | 403 |
| Session 过期或退出后重放 | 被拒绝 |
| 登录前 Session ID 在登录后重放 | 不能获得已登录身份 |
| 缺少或错误 CSRF Token 的修改请求 | 被拒绝 |
| 新增未配置接口 | 命中默认拒绝 |
| 错误 origin 的跨源请求 | 不获得允许读取的 CORS 响应 |

安全测试的价值在于证明不能做什么，不是机械增加测试数量。

## 22. 这篇的整体地图

```text
请求
  → 选择 SecurityFilterChain
  → Filter 恢复或建立 Authentication
  → SecurityContext 保存当前身份
  → CSRF / CORS / Session 等请求保护
  → URL 与方法授权
  → Controller 和对象级业务权限
  → 正确的 401 / 403 与脱敏记录
```

必须掌握：认证回答“是谁”，授权回答“能做什么”；Session ID 是凭据；默认拒绝比遗漏放行安全；前端隐藏按钮不能代替服务端授权；401、403、CORS 和 CSRF 失败要按请求链区分。

具体 DSL、Filter 类名和高级扩展点属于“需要时查询”。真正学习本章时，应根据当时使用的 Spring Security 官方文档复核配置写法。

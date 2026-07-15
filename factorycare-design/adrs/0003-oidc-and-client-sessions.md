# ADR-0003：外部OIDC与分客户端会话策略

- 状态：Accepted（设计基线）
- 日期：2026-07-11

## 上下文与目标

Vue/Nuxt Web、uni-app与Flutter均需认证。项目重点是业务授权，不应自制密码、找回、MFA和令牌签发系统；浏览器又需要降低token被XSS读取的风险，原生/小程序需要标准授权流程。

## 选项比较

| 选项 | 实现成本 | 迁移成本 | 风险 | 回滚难度 | 长期维护 |
| --- | --- | --- | --- | --- | --- |
| 自建用户名密码/JWT | 表面低、完整实现高 | 切OIDC需账户映射 | 密码、撤销、MFA和密钥轮换易错 | 高 | 安全负担长期存在 |
| 所有端直接保存access token | 中 | Web改BFF/session | 浏览器token受XSS影响 | 中 | 跨端一致但Web风险较高 |
| **外部OIDC；Web服务端会话，移动端Auth Code+PKCE bearer** | 中 | Provider可替换 | 两种客户端模式需清晰测试 | 中 | 符合各端安全特征 |

## 决定

- 生产身份交给支持OIDC的Provider；Java以稳定`issuer + subject`映射`user_account`，业务角色不放在客户端可编辑claim中；
- Web完成OIDC Authorization Code流程后由Java建立`HttpOnly; Secure; SameSite`会话cookie，状态写请求启用CSRF防护；
- Flutter与具备安全能力的小程序使用Authorization Code + PKCE及短时bearer，refresh token仅放平台安全存储；具体小程序Provider桥接在实现周确认；
- `/api/v1/auth/login`仅作为受控本地身份适配器或会话入口设计，生产不能接受仓库内静态密码；
- Java每次重建当前membership、角色与data scope，token有效不代表业务成员仍启用。

## 后果

- OpenAPI同时声明`browserSession`与`mobileBearer`；每个操作共享同一授权语义；
- Web需处理CSRF、session固定攻击、注销和并发会话；移动端需处理系统浏览器回调、PKCE、刷新/吊销和设备清理；
- 日志禁止token、code、cookie和完整subject；OIDC故障不能退化为匿名高权限；
- 本地开发Provider/adapter与生产配置隔离，并有启动保护。

## 迁移与回滚

先以本地受控Provider建立契约，再接生产候选。更换Provider时保留内部`user_account`，通过已验证的subject映射迁移，不能仅按邮箱自动合并。切换失败回到旧issuer并撤销新会话；已建立的新subject映射需审计回退。

## 验证与非目标

- `FC-AUTH-001—003`、CSRF、PKCE/state/nonce、logout与成员禁用测试；
- Cookie与移动token从日志/崩溃报告/本地明文中不可见；
- 本ADR不选择具体Provider，不声称实现企业SSO、SCIM或自研MFA。

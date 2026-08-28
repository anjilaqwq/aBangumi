# 安全说明（aBangumi）

本项目由一个 Flutter 客户端与一个 OAuth BFF（[`server/`](server/)）组成。本文档面向
贡献者与部署者，说明如何负责任地处理漏洞与敏感信息。

## 负责任披露

- 如发现安全漏洞，请**私下联系维护者**，不要先在公开 issue、讨论区或社群里公开
  可被利用的细节（漏洞类型、复现步骤、受影响端点等）。
- 给出清晰、最小化的复现步骤与影响范围即可，避免在报告中粘贴真实密钥、令牌或用户数据。
- 待修复或给足合理响应时间后再公开披露。

## 绝不公开的敏感信息

以下内容**永远不要**写入聊天记录、Git 仓库、GitHub Actions 日志/输出、issue、
commit message、`--dart-define` 或任何公开位置：

- `client_secret`（Bangumi OAuth 客户端密钥）
- access token / refresh token（Bangumi 访问/刷新令牌）
- 不透明会话令牌（`session_token`）、一次性 `ticket`、`state`、授权码（`code`）
- 任何用户凭据或验证码

`client_secret` 与 access/refresh token **只存在于 BFF 服务端环境**，Flutter 客户端
永远不接触它们。

## 已泄露密钥必须立即重置

如果任何密钥或令牌曾被泄露（例如出现在聊天、仓库、Actions 输出、截图或日志中）：

1. **立即在 Bangumi 开发者控制台重置/重新生成**对应的密钥或令牌，使旧值失效。
2. 不要以为「清理提交历史 / 删除日志」就够了——历史记录仍可能被缓存或留存，
   **轮换密钥本身**才是唯一有效的处置。
3. 重置后的新值**绝不要再**粘贴到聊天、仓库或 Actions。

## OAuth 边界

- Bangumi OAuth **没有 PKCE**，授权码与刷新令牌的换取都需要 `client_secret`，
  因此密钥只能放在服务端，不能进客户端。
- BFF 拥有 HTTPS 回调端点 `/auth/bangumi/callback`；授权后浏览器回到的是 **BFF**，
  而不是 `abangumi://` 自定义 scheme，从而避免同设备其他应用窃取回调。
- App 深链只接收一次性 `ticket` + `state`，校验 `state` 绑定后向 BFF 换取
  不透明 `session_token`。
- 之后的 Bangumi API 访问由 BFF 的 `/api/bangumi/*` 代理，并由服务端透明刷新令牌；
  客户端拿不到 access/refresh token。
- 详细协议与加固措施见 [`server/SECURITY.md`](server/SECURITY.md)。

## 本地安全存储与迁移

- 会话/令牌使用 `flutter_secure_storage` 加密保存（Android Keystore / iOS Keychain）。
- 旧版明文 `shared_preferences` 中保存的令牌会在升级时自动迁移到安全存储并删除，
  不在明文持久层留存。

## BFF 生产加固的局限

BFF 当前实现为轻量自托管服务，存在以下生产环境限制，部署前务必知悉：

- **内存存储、单实例**：`state` / `ticket` / `session` 都在进程内存中，重启即全部失效，
  多副本部署时也不共享。生产环境应替换为 Redis 或数据库（见 [`server/SECURITY.md`](server/SECURITY.md)）。
- **明文 HTTP 监听**：BFF 自身监听 HTTP，需在前面放置终结 TLS 的反向代理
  （nginx / Caddy / Cloudflare），并保证 `PUBLIC_BASE_URL` 为 `https://`。
- 建议在生产环境额外加入：对 `/auth/bangumi/start` 与 `/auth/bangumi/claim` 的限流、
  从密钥管理服务注入 `BANGUMI_CLIENT_SECRET`、密钥轮换，以及仅记录 `method + path + status`
  的日志（不记录查询串、请求体或响应头）。

完整清单见 [`server/SECURITY.md`](server/SECURITY.md)。

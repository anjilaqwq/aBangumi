# 安全说明（aBangumi）

本仓库仅包含 Flutter 客户端。本文档面向贡献者，说明如何负责任地处理漏洞与敏感信息。

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

`client_secret` 与 access/refresh token **只存在于私有 OA 服务环境**，Flutter 客户端
永远不接触它们。

## 已泄露密钥必须立即重置

如果任何密钥或令牌曾被泄露（例如出现在聊天、仓库、Actions 输出、截图或日志中）：

1. **立即在 Bangumi 开发者控制台重置/重新生成**对应的密钥或令牌，使旧值失效。
2. 不要以为「清理提交历史 / 删除日志」就够了——历史记录仍可能被缓存或留存，
   **轮换密钥本身**才是唯一有效的处置。
3. 重置后的新值**绝不要再**粘贴到聊天、仓库或 Actions。

## OAuth 边界

- Bangumi OAuth 的密钥只能保存在私有 OA 服务中，不能进入客户端。
- App 只接收一次性登录结果并换取不透明会话凭据。
- Bangumi API 的 OAuth 访问由 OA 服务代理并刷新令牌，客户端拿不到 access/refresh token。

## 本地安全存储与迁移

- 会话/令牌使用 `flutter_secure_storage` 加密保存（Android Keystore / iOS Keychain）。
- 旧版明文 `shared_preferences` 中保存的令牌会在升级时自动迁移到安全存储并删除，
  不在明文持久层留存。

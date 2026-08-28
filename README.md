# aBangumi

基于 [Bangumi API](https://bangumi.github.io/api/) 的第三方 Flutter 客户端（Android）。非官方项目，仅用于学习与个人使用。

## 功能

- **日式极简 UI**：明朝体/宋体衬线、大量留白、黑白主色 + 少量朱红点缀的克制排版（Material 3 主题）。
- **排行榜**：动画 / 书籍 / 游戏 / 音乐 / 三次元 类型切换。
- **每日放送**：按星期浏览在播动画。
- **搜索**：按条目类型过滤，支持搜索历史与结果分页。
- **条目详情**：
  - 评分、收藏状态、信息盒、简介
  - 标签筛选与标签聚合页（分页加载）
  - 相关条目（可展开查看全部）
  - 角色列表（含 CV 声优），可进入角色页 / 声优页
  - 章节列表（本篇），显示每集讨论数
- **收藏**：OAuth 登录（推荐）或手动 Access Token；个人资料、收藏列表（分页 + 类型/状态筛选）、详情页收藏编辑（类型 + 评分 + 评价）
- **观看进度**：单集标记「看过」/ 取消，详情页顶部「已看 X/N」进度条，与章节列表实时联动

## 架构

```text
Flutter 客户端（aBangumi）
  │ ① POST /auth/bangumi/start  →  authorization_url + state
  │ ② 系统浏览器打开授权页，用户授权
  │ ③ Bangumi 302 → https://<BFF>/auth/bangumi/callback（HTTPS 回调）
  │ ④ BFF 服务端用 code 换 access/refresh token，生成一次性 ticket，
  │    302 → abangumi://oauth/callback?ticket=…&state=…
  │ ⑤ App 校验 state，POST /auth/bangumi/claim → 不透明 session_token
  │ ⑥ 之后 API 请求走 /api/bangumi/*，由 BFF 代理并自动刷新
  ▼
Bangumi API（api.bgm.tv）
```

**OAuth 边界**：Bangumi OAuth 无 PKCE、必须使用 `client_secret`，因此 `client_secret`
与 access/refresh token **只存在于 BFF 服务端**；Flutter 客户端只持有不透明会话令牌
（`session_token`），服务端负责代理与刷新。

> ⚠️ **App Secret 绝不属于 Flutter 端**：`client_secret` 永远不要写进客户端代码、
> `--dart-define`、Git 仓库或 GitHub Actions。它是 BFF 专属的服务器环境变量。

## 登录（OAuth，推荐）

OAuth 依赖自行部署的 BFF（[`server/`](server/)），**本项目不提供已部署的实例**。
没有可用 BFF 时无法使用 OAuth，请改用下方「手动令牌」方式。

1. 部署并配置 BFF（详见 [`server/README.md`](server/README.md)），设置服务器环境变量：
   - `BANGUMI_CLIENT_ID`：公开的 OAuth 应用 ID
   - `BANGUMI_CLIENT_SECRET`：密钥，**仅服务器端**，绝不进入 Flutter
   - `PUBLIC_BASE_URL`：BFF 的公开 HTTPS 地址
2. 在 Bangumi 开发者控制台把回调地址设为（把 `PUBLIC_BASE_URL` 替换为你的域名）：

   ```
   https://<你的 BFF 域名>/auth/bangumi/callback
   ```

   回调必须是 HTTPS：浏览器授权后先回到 BFF，再由 BFF 302 跳回 App 深链
   `abangumi://oauth/callback`。
3. 构建时注入 BFF 地址：

   ```bash
   flutter build apk --release \
     --dart-define=ABANGUMI_AUTH_BASE_URL=https://<你的 BFF 域名>
   ```

   可选注入公开的 `ABANGUMI_CLIENT_ID`（不传时使用 App 内置默认值）。

## 登录（手动令牌，回退）

在 [bgm.tv 设置页](https://bgm.tv/dev/app) 生成 Access Token，在 App「我的」页粘贴登录。
此方式不需要 BFF，是 OAuth 不可用时的回退方案。

## 本地存储

凭据使用 `flutter_secure_storage` 加密保存（Android Keystore / iOS Keychain）；
旧版明文 `shared_preferences` 令牌会自动迁移并删除。

## 构建与测试

Flutter：

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

产物：`build/app/outputs/flutter-apk/app-release.apk`

BFF（需 Node.js 20+）：

```bash
cd server
npm test        # node --test，无网络依赖
npm start       # 需先配置环境变量，见 server/README.md
```

## 说明

- 数据与版权归 [Bangumi (bgm.tv)](https://bgm.tv) 所有，本项目仅调用其公开 API。
- release APK 使用 Flutter 模板默认的 debug 签名，仅供个人安装测试。
- 仓库的 release 默认**不注入 BFF 地址**，只包含手动令牌登录；只有配置了仓库变量
  `ABANGUMI_AUTH_BASE_URL` 才会启用 OAuth（见 [.github/workflows/release.yml](.github/workflows/release.yml)）。

## 技术栈

Flutter 3.35 · Material 3 · http · shared_preferences · flutter_secure_storage · app_links · url_launcher · Node.js 20 BFF（无第三方依赖）

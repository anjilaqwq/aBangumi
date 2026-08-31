# aBangumi

基于 [Bangumi API](https://bangumi.github.io/api/) 的第三方 Flutter 客户端（Android）。非官方项目，仅用于学习与个人使用。

## 功能

- **高辨识度响应式 UI**：手机使用可自动收起的底部导航，平板使用左侧控制栏；宽屏列表自动切换为高密度双列。
- **排行榜**：动画 / 书籍 / 游戏 / 音乐 / 三次元类型切换、分页加载与下拉刷新，顶部信息随滚动收起。
- **每日放送**：按星期浏览在播动画，平板双列展示。
- **发现与社区**：热门条目、热门讨论、吐槽和长评；讨论支持分页加载、Markdown、Bangumi 表情与图片。
- **搜索**：支持动画、书籍、游戏、音乐、三次元、角色与人物；登录后自动携带用户会话请求需要认证的条目。
- **条目详情**：
  - 评分、收藏状态、信息盒、简介
  - 标签筛选与标签聚合页（分页加载）
  - 相关条目（可展开查看全部）
  - 角色列表（含 CV 声优），可进入角色页 / 声优页
  - 章节列表（本篇），显示每集讨论数
- **收藏**：OAuth 登录（推荐）或手动 Access Token；个人资料、收藏列表（分页 + 类型/状态筛选）、详情页收藏编辑（类型 + 评分 + 评价）
- **观看进度**：单集标记「看过」/ 取消，详情页顶部「已看 X/N」进度条，与章节列表实时联动
- **性能与图片**：页面动态缓存、受控图片内存缓存；兼容长图、宽图与常规封面，详情封面可展开查看。

## 架构

```text
Flutter 客户端（aBangumi）
  │ ① POST /auth/bangumi/start  →  authorization_url + state
  │ ② 系统浏览器打开授权页，用户授权
  │ ③ Bangumi 302 → https://<BFF>/auth/bangumi/callback（HTTPS 回调）
  │ ④ BFF 服务端用 code 换 access/refresh token，生成一次性 ticket，
  │    302 → abangumi://oauth/callback?ticket=…&state=…
  │ ⑤ App 校验 state，POST /auth/bangumi/claim → 不透明 session_token
  │ ⑥ 官方 API 请求走 /api/bangumi/*，p1 社区请求走
  │    /api/bangumi-p1/*，均由 BFF 代理并自动刷新令牌
  ▼
Bangumi API（api.bgm.tv / next.bgm.tv/p1）
```

**OAuth 边界**：Bangumi OAuth 无 PKCE、必须使用 `client_secret`，因此 `client_secret`
与 access/refresh token **只存在于 BFF 服务端**；Flutter 客户端只持有不透明会话令牌
（`session_token`），服务端负责代理与刷新。

> ⚠️ **App Secret 绝不属于 Flutter 端**：`client_secret` 永远不要写进客户端代码、
> `--dart-define`、Git 仓库或 GitHub Actions。它是 BFF 专属的服务器环境变量。

## 登录（OAuth，推荐）

OAuth 登录服务由项目维护者提供，官方 Release 已完成配置。普通用户安装 APK 后可直接在
“我的”页面选择「使用 Bangumi 账号登录」，无需自行部署服务器或填写 OAuth 参数。

服务端源码仍保留在 [`server/`](server/) 供开发、审计和自建使用；自建版本的环境变量与
部署方式请参阅 [`server/README.md`](server/README.md)。官方服务不可用时仍可使用下方
「手动令牌」方式登录。

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
- GitHub Release 默认注入项目 OA/BFF 地址和公开 Client ID；可使用仓库变量
  `ABANGUMI_AUTH_BASE_URL`、`ABANGUMI_CLIENT_ID` 覆盖（见
  [.github/workflows/release.yml](.github/workflows/release.yml)）。`BANGUMI_CLIENT_SECRET`
  永远只属于服务器部署环境。

## 技术栈

Flutter 3.35 · Material 3 · http · shared_preferences · flutter_secure_storage · app_links · url_launcher · Node.js 20 BFF（无第三方依赖）

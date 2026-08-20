# aBangumi

基于 [Bangumi API](https://bangumi.github.io/api/) 的第三方 Flutter 客户端（Android）。非官方项目，仅用于学习与个人使用。

## 功能

- **排行榜**：动画 / 书籍 / 游戏 / 音乐 / 三次元 类型切换
- **每日放送**：按星期浏览在播动画
- **搜索**：按条目类型过滤
- **条目详情**：
  - 评分、收藏状态、信息盒、简介
  - 标签可点击，进入标签聚合页（分页加载）
  - 相关条目（可展开查看全部）
  - 角色列表（含 CV 声优），可进入角色页 / 声优页（配音角色、参与作品）
  - 章节列表（本篇），显示每集讨论数
- **收藏**：Access Token 登录、个人资料、收藏列表（分页 + 条目类型 / 收藏状态筛选）、详情页收藏编辑（类型 + 评分 + 评价）
- **观看进度**：单集标记「看过」/ 取消，详情页顶部「已看 X/N」进度条，与章节列表实时联动

## 构建

```bash
flutter pub get
flutter build apk --release
```
## 登录

在 [bgm.tv 设置页](https://bgm.tv/dev/app) 生成访问令牌（Access Token），在 App「我的」页粘贴登录。令牌仅保存在本机（shared_preferences）。

## 说明

- 数据与版权归 [Bangumi (bgm.tv)](https://bgm.tv) 所有，本项目仅调用其公开 API。
- release APK 使用 Flutter 模板默认的 debug 签名，仅供个人安装测试。

## 技术栈

Flutter 3.35 · Material 3 · http · shared_preferences

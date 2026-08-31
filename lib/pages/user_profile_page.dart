import 'package:flutter/material.dart';

import '../models/models.dart';
import '../navigation/routes.dart';
import '../store/auth_store.dart';
import '../store/theme_store.dart';
import '../widgets/common/common.dart';

class UserProfilePage extends StatelessWidget {
  final User user;
  final int collectionTotal;

  const UserProfilePage({
    super.key,
    required this.user,
    required this.collectionTotal,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final avatarUrl = user.avatarLarge.isNotEmpty
        ? user.avatarLarge
        : user.avatarMedium;
    return Scaffold(
      appBar: AppBar(title: const Text('个人资料')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 36),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: colors.primary.withValues(alpha: 0.35),
                      width: 2,
                    ),
                  ),
                  child: CoverImage(
                    imageUrl: avatarUrl,
                    width: 88,
                    height: 88,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    borderRadius: 44,
                    placeholder: ColoredBox(
                      color: colors.surface,
                      child: Icon(
                        Icons.person_outline_rounded,
                        size: 36,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.displayName,
                          style: textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '@${user.username}',
                          style: textTheme.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: colors.primaryContainer,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '已连接 Bangumi',
                            style: textTheme.labelSmall?.copyWith(
                              color: colors.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: '收藏条目',
                  value: '$collectionTotal',
                  icon: Icons.collections_bookmark_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  label: '用户编号',
                  value: user.id > 0 ? '#${user.id}' : '—',
                  icon: Icons.badge_outlined,
                ),
              ),
            ],
          ),
          if (user.sign.trim().isNotEmpty) ...[
            const SectionHeader(
              title: '个人签名',
              padding: EdgeInsets.fromLTRB(4, 24, 4, 10),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.outlineVariant),
              ),
              child: Text(
                user.sign.trim(),
                style: textTheme.bodyMedium?.copyWith(height: 1.65),
              ),
            ),
          ],
          const SectionHeader(
            title: '账号资料',
            padding: EdgeInsets.fromLTRB(4, 24, 4, 10),
          ),
          InfoBox(
            keyWidth: 72,
            entries: [
              InfoEntry('昵称', user.displayName),
              InfoEntry('用户名', user.username),
              InfoEntry('用户 ID', user.id > 0 ? '${user.id}' : '暂无'),
            ],
          ),
          const SectionHeader(
            title: '资料与设置',
            padding: EdgeInsets.fromLTRB(4, 24, 4, 10),
          ),
          _ActionTile(
            icon: Icons.open_in_new_rounded,
            title: '打开 Bangumi 个人主页',
            subtitle: '编辑昵称、头像和签名',
            onTap: () => AppRoutes.openUserProfile(context, user),
          ),
          const SizedBox(height: 8),
          _ActionTile(
            icon: Icons.contrast_rounded,
            title: '切换外观',
            subtitle: '在浅色、深色与跟随系统之间切换',
            onTap: ThemeStore.instance.cycleThemeMode,
          ),
          const SizedBox(height: 8),
          _ActionTile(
            icon: Icons.tune_rounded,
            title: '代理设置',
            subtitle: '管理网络连接方式',
            onTap: () => AppRoutes.pushProxySettings(context),
          ),
          const SizedBox(height: 8),
          _ActionTile(
            icon: Icons.logout_rounded,
            title: '退出登录',
            subtitle: '清除本机保存的登录状态',
            destructive: true,
            onTap: () => _confirmLogout(context),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出当前账号吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('退出'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await AuthStore.instance.logout();
    if (context.mounted) Navigator.pop(context);
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label,
                  style: textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool destructive;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = destructive ? colors.error : colors.onSurface;
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: foreground),
        title: Text(
          title,
          style: TextStyle(color: foreground, fontWeight: FontWeight.w800),
        ),
        subtitle: Text(subtitle),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: colors.onSurfaceVariant,
        ),
      ),
    );
  }
}

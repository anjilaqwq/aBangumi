import 'package:flutter/material.dart';

import '../api/bangumi_api.dart';
import '../models/models.dart';
import '../navigation/routes.dart';
import '../store/auth_store.dart';
import '../store/theme_store.dart';
import '../theme/app_colors.dart';
import '../widgets/common/common.dart';

/// 「我的」页：日式极简重设计。
///
/// - 未登录：OAuth 为主，访问令牌为可折叠的次级入口。
/// - 已登录：编辑式资料页头 + 收藏列表（分页、筛选、下拉刷新）。
class MyPage extends StatelessWidget {
  const MyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([
            AuthStore.instance.token,
            AuthStore.instance.user,
            AuthStore.instance.busy,
            AuthStore.instance.error,
          ]),
          builder: (context, _) {
            final token = AuthStore.instance.token.value;
            final user = AuthStore.instance.user.value;
            final loggedIn = token != null && token.isNotEmpty;
            if (!loggedIn) return const _LoginView();
            if (user == null) {
              // token 已就绪、用户信息尚未到达的极短窗口。
              return const LoadingState(message: '正在读取账号信息…');
            }
            return _ProfileView(
              // Never place a credential in widget keys/diagnostics.
              key: ValueKey(user.username),
              user: user,
              token: token,
            );
          },
        ),
      ),
    );
  }
}

// ---------------- 登录 ----------------

class _LoginView extends StatefulWidget {
  const _LoginView();

  @override
  State<_LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<_LoginView> {
  final _controller = TextEditingController();

  bool _manualBusy = false;
  bool _manualExpanded = false;
  String? _manualError;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _beginOAuth() => AuthStore.instance.beginOAuth();

  Future<void> _manualLogin() async {
    if (_manualBusy) return;
    AuthStore.instance.clearError();
    setState(() {
      _manualBusy = true;
      _manualError = null;
    });
    try {
      await AuthStore.instance.login(_controller.text);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _manualBusy = false;
        _manualError = _manualErrorMessage(e);
      });
      return;
    }
    if (!mounted) return;
    setState(() => _manualBusy = false);
  }

  String _manualErrorMessage(Object e) {
    if (e is ApiException) {
      if (e.statusCode == 0) return '请输入访问令牌。';
      if (e.statusCode == 401 || e.statusCode == 403) {
        return '令牌无效或已过期，请重新生成后重试。';
      }
      return '无法连接 Bangumi（HTTP ${e.statusCode}），请检查网络后重试。';
    }
    return '登录失败，请稍后重试。';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final oauthBusy = AuthStore.instance.busy.value;
    final oauthError = AuthStore.instance.error.value;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      children: [
        const PageHeader(
          title: '我的空间',
          eyebrow: 'PERSONAL SPACE',
          icon: Icons.person_rounded,
          subtitle: '连接 Bangumi，同步你的收藏与观看进度',
          showDivider: false,
          padding: EdgeInsets.fromLTRB(4, 18, 4, 16),
        ),
        Row(
          children: [
            Expanded(
              child: _ProfileAction(
                icon: Icons.contrast_rounded,
                label: '切换外观',
                onTap: ThemeStore.instance.cycleThemeMode,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ProfileAction(
                icon: Icons.tune_rounded,
                label: '代理设置',
                onTap: () => AppRoutes.pushProxySettings(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: colors.primary.withValues(alpha: 0.18)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: colors.onPrimary,
                  size: 25,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                '把你的 Bangumi 带在身边',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '使用官方授权登录，无需在应用内输入密码。授权后即可查看收藏、评分与观看进度。',
                style: textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: oauthBusy ? null : _beginOAuth,
                  icon: oauthBusy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.login_rounded, size: 18),
                  label: Text(oauthBusy ? '正在处理登录…' : '使用 Bangumi 账号登录'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '授权服务仅负责安全中转，客户端不会保存你的密码。',
          textAlign: TextAlign.center,
          style: textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
        ),
        if (oauthError != null) ...[
          const SizedBox(height: 20),
          _notice(oauthError),
        ],
        const SizedBox(height: 40),
        _orDivider(),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: () => setState(() => _manualExpanded = !_manualExpanded),
            child: Text(_manualExpanded ? '收起访问令牌登录' : '使用访问令牌登录'),
          ),
        ),
        if (_manualExpanded) ...[
          const SizedBox(height: 4),
          TextField(
            controller: _controller,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            smartDashesType: SmartDashesType.disabled,
            smartQuotesType: SmartQuotesType.disabled,
            keyboardType: TextInputType.visiblePassword,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _manualLogin(),
            decoration: InputDecoration(
              labelText: '访问令牌 (Access Token)',
              hintText: '粘贴你在 bgm.tv 生成的令牌',
              helperText: '令牌仅保存在本机安全存储中。',
              border: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(4)),
                borderSide: BorderSide(color: AppColors.line),
              ),
              enabledBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(4)),
                borderSide: BorderSide(color: AppColors.line),
              ),
            ),
          ),
          if (_manualError != null) ...[
            const SizedBox(height: 12),
            _notice(_manualError!),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _manualBusy ? null : _manualLogin,
              child: _manualBusy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('登录'),
            ),
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _orDivider() {
    return Row(
      children: [
        const Expanded(child: HairlineDivider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('或', style: Theme.of(context).textTheme.labelSmall),
        ),
        const Expanded(child: HairlineDivider()),
      ],
    );
  }

  Widget _notice(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.line),
      ),
      child: Text(
        message,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
      ),
    );
  }
}

// ---------------- 个人资料 + 收藏（分页 + 筛选） ----------------

class _ProfileView extends StatefulWidget {
  final User user;
  final String token;

  const _ProfileView({super.key, required this.user, required this.token});

  @override
  State<_ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<_ProfileView> {
  static const _pageSize = 50;

  final ScrollController _scroll = ScrollController();
  final Set<int> _seenSubjectIds = {};

  int _collectionType = 0; // 0 = 全部（收藏类型）
  int _subjectType = 0; // 0 = 全部（条目类型）
  List<Collection> _items = [];
  int _total = 0;
  int _collectionTotal = 0;
  int _loadedRaw = 0; // 已请求到的原始条数，用于分页 offset 推进
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  /// 请求代号：每次刷新/筛选变更时递增，用于丢弃过期的响应。
  int _requestGen = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<PageData<Collection>> _fetchPage(int offset) {
    return BangumiApi.userCollections(
      widget.token,
      widget.user.username,
      collectionType: _collectionType == 0 ? null : _collectionType,
      subjectType: _subjectType == 0 ? null : _subjectType,
      limit: _pageSize,
      offset: offset,
    );
  }

  Future<void> _load() async {
    final gen = ++_requestGen;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await _fetchPage(0);
      if (!mounted || gen != _requestGen) return;
      setState(() {
        _items = List.of(page.items);
        _total = page.total;
        if (_collectionType == 0 && _subjectType == 0) {
          _collectionTotal = page.total;
        }
        _loadedRaw = page.items.length;
        _seenSubjectIds
          ..clear()
          ..addAll(page.items.map((c) => c.subject.id));
        _loading = false;
      });
    } catch (e) {
      if (!mounted || gen != _requestGen) return;
      setState(() {
        _loading = false;
        _error = _listErrorMessage(e);
      });
    }
  }

  Future<void> _refresh() async {
    final gen = ++_requestGen;
    try {
      final page = await _fetchPage(0);
      if (!mounted || gen != _requestGen) return;
      setState(() {
        _items = List.of(page.items);
        _total = page.total;
        if (_collectionType == 0 && _subjectType == 0) {
          _collectionTotal = page.total;
        }
        _loadedRaw = page.items.length;
        _seenSubjectIds
          ..clear()
          ..addAll(page.items.map((c) => c.subject.id));
        _error = null;
      });
    } catch (e) {
      if (!mounted || gen != _requestGen) return;
      if (_items.isEmpty) {
        setState(() => _error = _listErrorMessage(e));
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_listErrorMessage(e))));
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore) return;
    if (_loadedRaw >= _total) return;
    final gen = _requestGen; // 捕获当前代号，不递增
    setState(() => _loadingMore = true);
    try {
      final page = await _fetchPage(_loadedRaw);
      if (!mounted || gen != _requestGen) return;
      final fresh = page.items
          .where((c) => !_seenSubjectIds.contains(c.subject.id))
          .toList();
      for (final c in fresh) {
        _seenSubjectIds.add(c.subject.id);
      }
      setState(() {
        _items = [..._items, ...fresh];
        _total = page.total;
        _loadedRaw += page.items.length;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted || gen != _requestGen) return;
      setState(() => _loadingMore = false);
    }
  }

  void _selectSubjectType(int t) {
    if (_subjectType == t) return;
    setState(() => _subjectType = t);
    _load();
  }

  void _selectCollectionType(int t) {
    if (_collectionType == t) return;
    setState(() => _collectionType = t);
    _load();
  }

  void _resetFilters() {
    setState(() {
      _subjectType = 0;
      _collectionType = 0;
    });
    _load();
  }

  String _listErrorMessage(Object e) {
    if (e is ApiException) {
      return '加载失败（HTTP ${e.statusCode}），请稍后重试。';
    }
    return '加载失败，请稍后重试。';
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: CustomScrollView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _header()),
          SliverToBoxAdapter(child: _filters()),
          ..._buildSlivers(),
        ],
      ),
    );
  }

  Widget _header() {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final u = widget.user;
    final avatarUrl = u.avatarLarge.isNotEmpty ? u.avatarLarge : u.avatarMedium;
    final wide = MediaQuery.sizeOf(context).width >= 720;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, wide ? 6 : 10, 16, 2),
      child: Material(
        color: colors.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(wide ? 15 : 17),
          side: BorderSide(color: colors.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => AppRoutes.pushUserProfile(
            context,
            user: u,
            collectionTotal: _collectionTotal,
          ),
          child: Padding(
            padding: EdgeInsets.all(wide ? 9 : 12),
            child: Row(
              children: [
                CoverImage(
                  imageUrl: avatarUrl,
                  width: wide ? 46 : 52,
                  height: wide ? 46 : 52,
                  fit: BoxFit.cover,
                  borderRadius: wide ? 23 : 26,
                  alignment: Alignment.topCenter,
                  placeholder: ColoredBox(
                    color: colors.surface,
                    child: Icon(
                      Icons.person_outline_rounded,
                      size: 24,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
                SizedBox(width: wide ? 10 : 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        u.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        u.sign.isNotEmpty ? u.sign : '@${u.username}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _loading && _collectionTotal == 0
                          ? '—'
                          : '$_collectionTotal',
                      style: textTheme.titleSmall?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '收藏',
                      style: textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  color: colors.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _filters() {
    final subjectFilters = <Widget>[
      _filterTag('全部', _subjectType == 0, () => _selectSubjectType(0)),
      ...kSubjectTypes.map(
        (e) => _filterTag(
          e.value,
          _subjectType == e.key,
          () => _selectSubjectType(e.key),
        ),
      ),
    ];
    final collectionFilters = <Widget>[
      _filterTag('全部', _collectionType == 0, () => _selectCollectionType(0)),
      ...collectionTypesForSubjectType(
        _subjectType == 0 ? null : _subjectType,
      ).map(
        (e) => _filterTag(
          e.value,
          _collectionType == e.key,
          () => _selectCollectionType(e.key),
        ),
      ),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 680;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.filter_alt_outlined,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      '筛选收藏',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: wide ? 8 : 12),
                if (wide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _filterRow('条目', subjectFilters)),
                      const SizedBox(width: 14),
                      Expanded(child: _filterRow('状态', collectionFilters)),
                    ],
                  )
                else ...[
                  _filterRow('条目', subjectFilters),
                  const SizedBox(height: 10),
                  _filterRow('状态', collectionFilters),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _filterRow(String label, List<Widget> chips) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 40,
          child: Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Text(label, style: Theme.of(context).textTheme.labelSmall),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: chips),
          ),
        ),
      ],
    );
  }

  Widget _filterTag(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: TagChip(label: label, selected: selected, onTap: onTap),
    );
  }

  List<Widget> _buildSlivers() {
    if (_loading) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: LoadingState(message: '正在加载收藏…'),
        ),
      ];
    }
    if (_error != null) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: ErrorState(message: _error!, onRetry: _load),
        ),
      ];
    }
    if (_items.isEmpty) {
      final filtered = _subjectType != 0 || _collectionType != 0;
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            message: '这里空空如也',
            actionLabel: filtered ? '重置筛选' : null,
            onAction: filtered ? _resetFilters : null,
          ),
        ),
      ];
    }
    final hasMore = _loadedRaw < _total;
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
        sliver: SliverLayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.crossAxisExtent >= 680;
            final delegate = SliverChildBuilderDelegate(
              (context, index) => _collectionRow(_items[index], dense: wide),
              childCount: _items.length,
            );
            if (!wide) return SliverList(delegate: delegate);
            return SliverGrid(
              delegate: delegate,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisExtent: 116,
                crossAxisSpacing: 10,
                mainAxisSpacing: 8,
              ),
            );
          },
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 28),
          child: PagingFooter(
            loading: _loadingMore,
            hasMore: hasMore,
            total: _total,
          ),
        ),
      ),
    ];
  }

  Widget _collectionRow(Collection c, {bool dense = false}) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final s = c.subject;
    return Container(
      margin: EdgeInsets.only(bottom: dense ? 0 : 10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(dense ? 14 : 16),
        border: Border.all(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => AppRoutes.pushSubject(context, s.id),
        child: Padding(
          padding: EdgeInsets.all(dense ? 9 : 11),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CoverImage(
                imageUrl: s.cover,
                width: dense ? 52 : 58,
                height: dense ? 74 : 82,
                borderRadius: dense ? 9 : 10,
              ),
              SizedBox(width: dense ? 10 : 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.title,
                      maxLines: dense ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: dense ? 5 : 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _meta(c.typeLabel),
                        if (c.rate > 0) _meta('评分 ${c.rate}'),
                        if (c.isPrivate)
                          const Icon(
                            Icons.lock_outline,
                            size: 13,
                            color: AppColors.subtle,
                          ),
                        if (c.updatedAt.isNotEmpty)
                          _meta(_shortDate(c.updatedAt)),
                      ],
                    ),
                    if (s.type == 2 && c.type == 2 && s.totalEpisodes > 0) ...[
                      SizedBox(height: dense ? 6 : 10),
                      _animeProgress(c),
                    ],
                    if (c.comment.isNotEmpty) ...[
                      SizedBox(height: dense ? 5 : 8),
                      Text(
                        c.comment,
                        maxLines: dense ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _animeProgress(Collection collection) {
    final total = collection.subject.totalEpisodes;
    final watched = collection.epStatus.clamp(0, total).toInt();
    final progress = total == 0 ? 0.0 : watched / total;
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('观看进度', style: Theme.of(context).textTheme.bodySmall),
            const Spacer(),
            Text(
              '$watched/$total',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 4,
            backgroundColor: colors.outlineVariant,
            color: colors.primary,
          ),
        ),
      ],
    );
  }

  Widget _meta(String text) {
    return Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: AppColors.subtle),
    );
  }

  String _shortDate(String s) => s.length >= 10 ? s.substring(0, 10) : s;
}

class _ProfileAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ProfileAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = colors.onSurfaceVariant;
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(13),
        side: BorderSide(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Column(
            children: [
              Icon(icon, size: 18, color: foreground),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

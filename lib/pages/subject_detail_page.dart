import 'package:flutter/material.dart';

import '../api/bangumi_api.dart';
import '../models/models.dart';
import '../navigation/routes.dart';
import '../store/auth_store.dart';
import '../theme/app_colors.dart';
import '../widgets/common/common.dart';
import '../widgets/subject_community_preview.dart';
import 'character_page.dart';
import 'tag_page.dart';

class SubjectDetailPage extends StatefulWidget {
  final int subjectId;
  const SubjectDetailPage({super.key, required this.subjectId});

  @override
  State<SubjectDetailPage> createState() => _SubjectDetailPageState();
}

class _SubjectDetailPageState extends State<SubjectDetailPage> {
  late Future<Subject> _subjectFuture;
  late Future<List<Character>> _charactersFuture;
  late _EpisodeTracker _tracker;
  String? _authToken;

  @override
  void initState() {
    super.initState();
    _authToken = AuthStore.instance.token.value;
    _subjectFuture = BangumiApi.subject(widget.subjectId, token: _authToken);
    _charactersFuture = BangumiApi.characters(
      widget.subjectId,
      token: _authToken,
    );
    _tracker = _EpisodeTracker(widget.subjectId, token: _authToken);
    AuthStore.instance.token.addListener(_syncTrackerAuth);
    _tracker.updateAuth(_authToken);
  }

  void _syncTrackerAuth() {
    final token = AuthStore.instance.token.value;
    if (token == _authToken) return;
    _authToken = token;
    _tracker.dispose();
    _tracker = _EpisodeTracker(widget.subjectId, token: token);
    _tracker.updateAuth(token);
    setState(() {
      _subjectFuture = BangumiApi.subject(widget.subjectId, token: token);
      _charactersFuture = BangumiApi.characters(widget.subjectId, token: token);
    });
  }

  @override
  void dispose() {
    AuthStore.instance.token.removeListener(_syncTrackerAuth);
    _tracker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('条目详情')),
      body: FutureBuilder<Subject>(
        future: _subjectFuture,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const LoadingState(message: '正在读取条目');
          }
          if (snap.hasError || !snap.hasData) {
            return ErrorState(
              message: '加载失败：${snap.error}',
              onRetry: () => setState(() {
                _subjectFuture = BangumiApi.subject(
                  widget.subjectId,
                  token: _authToken,
                );
              }),
            );
          }
          final s = snap.data!;
          final coverHeroTag = 'subject-cover-${s.id}';
          return AdaptiveContentWidth(
            child: ListView(
              children: [
                DetailHero(
                  coverUrl: s.cover,
                  coverWidth: 116,
                  coverHeight: 164,
                  coverHeroTag: coverHeroTag,
                  onCoverTap: s.cover.isEmpty
                      ? null
                      : () => AppRoutes.pushImagePreview(
                          context,
                          imageUrl: s.cover,
                          title: s.title,
                          heroTag: coverHeroTag,
                        ),
                  title: s.title,
                  subtitle:
                      s.originalTitle.isNotEmpty && s.originalTitle != s.title
                      ? s.originalTitle
                      : null,
                  trailing: s.score > 0
                      ? _Score(score: s.score, total: s.ratingTotal)
                      : null,
                  meta: [
                    TagChip(label: s.typeLabel),
                    if (s.platform.isNotEmpty) TagChip(label: s.platform),
                    if (s.date.isNotEmpty) TagChip(label: s.date),
                    if (s.rank > 0) TagChip(label: 'Rank #${s.rank}'),
                  ],
                ),
                _content(s),
                _RelatedSection(subjectId: s.id, token: _authToken),
                _charactersSection(_charactersFuture),
                SubjectCommunityPreview(subjectId: s.id, subjectType: s.type),
                _EpisodesSection(tracker: _tracker),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _content(Subject s) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CollectionBar(subjectId: s.id, subjectType: s.type),
          const SizedBox(height: 16),
          _EpisodeProgressBar(tracker: _tracker),
          if (s.tags.isNotEmpty) ...[
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: s.tags
                  .take(12)
                  .map(
                    (t) => TagChip(
                      label: t,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => TagPage(tag: t)),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          if (s.infobox.isNotEmpty) ...[
            const SizedBox(height: 24),
            _CollapsibleInfoBox(
              entries: s.infobox.map((e) => InfoEntry(e.key, e.value)).toList(),
            ),
          ],
          if (s.summary.trim().isNotEmpty) ...[
            const SizedBox(height: 28),
            Text('简介', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            _CollapsibleSummary(text: s.summary.trim()),
          ],
        ],
      ),
    );
  }

  Widget _charactersSection(Future<List<Character>> future) {
    return FutureBuilder<List<Character>>(
      future: future,
      builder: (context, snap) {
        final list = snap.data ?? const [];
        if (list.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(title: '角色', count: '${list.length}'),
            SizedBox(
              height: 220,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, i) {
                  final c = list[i];
                  return InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CharacterPage(characterId: c.id),
                      ),
                    ),
                    child: SizedBox(
                      width: 96,
                      child: Column(
                        children: [
                          CoverImage(
                            imageUrl: c.imagesLarge,
                            width: 72,
                            height: 144,
                            alignment: Alignment.topCenter,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            c.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (c.relation.isNotEmpty)
                            Text(
                              c.relation,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.subtle),
                            ),
                          if (c.cvName.isNotEmpty)
                            Text(
                              'CV: ${c.cvName}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.vermilion),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CollapsibleInfoBox extends StatefulWidget {
  final List<InfoEntry> entries;
  const _CollapsibleInfoBox({required this.entries});

  @override
  State<_CollapsibleInfoBox> createState() => _CollapsibleInfoBoxState();
}

class _CollapsibleInfoBoxState extends State<_CollapsibleInfoBox> {
  static const _collapsedCount = 5;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final collapsible = widget.entries.length > _collapsedCount;
    final visible = _expanded || !collapsible
        ? widget.entries
        : widget.entries.take(_collapsedCount).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InfoBox(entries: visible),
        if (collapsible)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => setState(() => _expanded = !_expanded),
              child: Text(_expanded ? '收起详细信息' : '查看全部信息'),
            ),
          ),
      ],
    );
  }
}

class _CollapsibleSummary extends StatefulWidget {
  final String text;
  const _CollapsibleSummary({required this.text});

  @override
  State<_CollapsibleSummary> createState() => _CollapsibleSummaryState();
}

class _CollapsibleSummaryState extends State<_CollapsibleSummary> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final collapsible = widget.text.length > 240;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.text,
          maxLines: _expanded || !collapsible ? null : 6,
          overflow: _expanded || !collapsible
              ? TextOverflow.visible
              : TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (collapsible)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => setState(() => _expanded = !_expanded),
              child: Text(_expanded ? '收起简介' : '展开简介'),
            ),
          ),
      ],
    );
  }
}

class _Score extends StatelessWidget {
  final double score;
  final int total;

  const _Score({required this.score, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          score.toStringAsFixed(1),
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(color: AppColors.vermilion),
        ),
        const SizedBox(width: 8),
        Text(total > 0 ? '$total 人评分' : '评分'),
      ],
    );
  }
}

// ---------------- 收藏栏 ----------------

class _CollectionBar extends StatefulWidget {
  final int subjectId;
  final int subjectType;
  const _CollectionBar({required this.subjectId, required this.subjectType});

  @override
  State<_CollectionBar> createState() => _CollectionBarState();
}

class _CollectionBarState extends State<_CollectionBar> {
  Collection? _col;
  bool _loading = true;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    AuthStore.instance.token.addListener(_handleAuthChanged);
    AuthStore.instance.user.addListener(_handleAuthChanged);
    _load();
  }

  void _handleAuthChanged() => _load();

  @override
  void dispose() {
    AuthStore.instance.token.removeListener(_handleAuthChanged);
    AuthStore.instance.user.removeListener(_handleAuthChanged);
    _loadGeneration++;
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    final token = AuthStore.instance.token.value;
    final user = AuthStore.instance.user.value;
    if (mounted) {
      setState(() {
        _loading = token != null && user != null;
        _col = null;
      });
    }
    if (token == null || user == null) return;
    Collection? collection;
    try {
      collection = await BangumiApi.subjectCollection(
        token,
        user.username,
        widget.subjectId,
      );
    } catch (_) {
      // 忽略错误，按未收藏展示。
    }
    if (mounted && generation == _loadGeneration) {
      setState(() {
        _col = collection;
        _loading = false;
      });
    }
  }

  Future<void> _openEditor() async {
    final token = AuthStore.instance.token.value;
    if (token == null) return;
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CollectionEditorSheet(
        subjectId: widget.subjectId,
        subjectType: widget.subjectType,
        initial: _col,
      ),
    );
    if (changed == true && mounted) {
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('收藏已保存')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: AuthStore.instance.token,
      builder: (context, token, _) {
        final loggedIn = token != null && token.isNotEmpty;
        if (!loggedIn) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.bookmark_border,
                  size: 20,
                  color: AppColors.muted,
                ),
                const SizedBox(width: 8),
                Text(
                  '在「我的」页登录后可管理收藏',
                  style: TextStyle(fontSize: 13, color: AppColors.muted),
                ),
              ],
            ),
          );
        }
        if (_loading) {
          return const SizedBox(
            height: 40,
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final col = _col;
        return InkWell(
          onTap: _openEditor,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  col == null ? Icons.bookmark_add_outlined : Icons.bookmark,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    col == null
                        ? '加入收藏'
                        : '${col.typeLabel}${col.rate > 0 ? ' · 评分 ${col.rate}' : ''}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: AppColors.muted,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ---------------- 收藏编辑弹层 ----------------

class _CollectionEditorSheet extends StatefulWidget {
  final int subjectId;
  final int subjectType;
  final Collection? initial;
  const _CollectionEditorSheet({
    required this.subjectId,
    required this.subjectType,
    this.initial,
  });

  @override
  State<_CollectionEditorSheet> createState() => _CollectionEditorSheetState();
}

class _CollectionEditorSheetState extends State<_CollectionEditorSheet> {
  late int _type;
  late int _rate;
  late TextEditingController _commentController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _type = widget.initial?.type ?? 1;
    _rate = widget.initial?.rate ?? 0;
    _commentController = TextEditingController(
      text: widget.initial?.comment ?? '',
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final token = AuthStore.instance.token.value;
    if (token == null) return;
    setState(() => _saving = true);
    final comment = _commentController.text.trim();
    try {
      await BangumiApi.updateCollection(
        token,
        widget.subjectId,
        type: _type,
        rate: _rate,
        comment: comment.isEmpty ? null : comment,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('保存失败：$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '收藏',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: collectionTypesForSubjectType(widget.subjectType)
                  .map(
                    (e) => ChoiceChip(
                      label: Text(e.value),
                      selected: _type == e.key,
                      onSelected: (_) => setState(() => _type = e.key),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('评分', style: TextStyle(fontSize: 14)),
                Expanded(
                  child: Slider(
                    value: _rate.toDouble(),
                    min: 0,
                    max: 10,
                    divisions: 10,
                    label: _rate == 0 ? '不评分' : '$_rate',
                    onChanged: (v) => setState(() => _rate = v.round()),
                  ),
                ),
                SizedBox(
                  width: 36,
                  child: Text(
                    _rate == 0 ? '—' : '$_rate',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _commentController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: '评价（可选）',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('保存'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- 相关条目（可展开，细化卡片） ----------------

class _RelatedSection extends StatefulWidget {
  final int subjectId;
  final String? token;
  const _RelatedSection({required this.subjectId, this.token});

  @override
  State<_RelatedSection> createState() => _RelatedSectionState();
}

class _RelatedSectionState extends State<_RelatedSection> {
  late Future<List<Subject>> _future;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _future = BangumiApi.relatedSubjects(widget.subjectId, token: widget.token);
  }

  @override
  void didUpdateWidget(covariant _RelatedSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.subjectId == widget.subjectId &&
        oldWidget.token == widget.token) {
      return;
    }
    _future = BangumiApi.relatedSubjects(widget.subjectId, token: widget.token);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Subject>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
        final list = snap.data ?? const [];
        if (list.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '相关条目 (${list.length})',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _expanded = !_expanded),
                    child: Text(
                      _expanded ? '收起' : '查看全部',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              if (!_expanded)
                SizedBox(
                  height: 190,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, i) => _relatedCard(list[i]),
                  ),
                )
              else
                Column(children: [for (final r in list) _relatedTile(r)]),
            ],
          ),
        );
      },
    );
  }

  Widget _relatedCard(Subject r) {
    return InkWell(
      onTap: () => _open(r),
      child: SizedBox(
        width: 96,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: CoverImage(
                    imageUrl: r.cover,
                    width: 96,
                    height: 126,
                    borderRadius: 6,
                  ),
                ),
                if (r.relation.isNotEmpty)
                  Positioned(
                    left: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: const BoxDecoration(
                        color: AppColors.vermilion,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(6),
                          bottomRight: Radius.circular(6),
                        ),
                      ),
                      child: Text(
                        r.relation,
                        style: const TextStyle(
                          fontSize: 9,
                          color: AppColors.paper,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              r.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 2),
            Text(
              r.typeLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, color: AppColors.subtle),
            ),
          ],
        ),
      ),
    );
  }

  Widget _relatedTile(Subject r) {
    return InkWell(
      onTap: () => _open(r),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: CoverImage(
                imageUrl: r.cover,
                width: 44,
                height: 62,
                borderRadius: 4,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (r.relation.isNotEmpty) _tag(r.relation),
                      _tag(r.typeLabel),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.muted),
          ],
        ),
      ),
    );
  }

  Widget _tag(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.secondaryContainer,
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(text, style: const TextStyle(fontSize: 10)),
  );

  void _open(Subject r) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SubjectDetailPage(subjectId: r.id)),
    );
  }
}

// ---------------- 单集观看进度共享状态 ----------------

class _EpisodeTracker {
  final int subjectId;
  final ValueNotifier<Map<int, int>> status = ValueNotifier({});
  final ValueNotifier<bool> statusReady = ValueNotifier(false);
  final ValueNotifier<bool> statusFailed = ValueNotifier(false);
  late final Future<List<Episode>> episodes;
  String? _token;
  int _authGeneration = 0;
  bool _disposed = false;

  _EpisodeTracker(this.subjectId, {String? token}) {
    episodes = BangumiApi.episodes(subjectId, token: token);
  }

  /// 由页面生命周期中的认证监听驱动，避免在 build 中触发请求。
  Future<void> updateAuth(String? token) async {
    final normalized = token == null || token.isEmpty ? null : token;
    if (_token == normalized) return;
    _token = normalized;
    _authGeneration++;
    status.value = {};
    statusReady.value = false;
    statusFailed.value = false;
    if (normalized != null) await _loadStatus(normalized);
  }

  Future<void> retryStatus() async {
    final token = _token;
    if (token != null) await _loadStatus(token);
  }

  Future<void> _loadStatus(String token) async {
    final generation = ++_authGeneration;
    statusReady.value = false;
    statusFailed.value = false;
    try {
      final result = await BangumiApi.episodeStatus(token, subjectId);
      if (!_disposed && generation == _authGeneration && _token == token) {
        status.value = result;
        statusReady.value = true;
      }
    } catch (_) {
      if (!_disposed && generation == _authGeneration && _token == token) {
        statusFailed.value = true;
      }
    }
  }

  /// 切换「看过」：未标记 → 看过 → 取消。返回是否成功（失败时已回滚）。
  Future<bool> toggle(int episodeId) async {
    final token = _token;
    if (token == null || !statusReady.value) return false;
    final current = status.value[episodeId] ?? 0;
    final next = current == 2 ? 0 : 2;
    final before = Map<int, int>.from(status.value);
    final updated = Map<int, int>.from(status.value);
    if (next == 0) {
      updated.remove(episodeId);
    } else {
      updated[episodeId] = next;
    }
    status.value = updated;
    try {
      await BangumiApi.updateEpisode(token, episodeId, next);
      return true;
    } catch (_) {
      if (!_disposed && _token == token && status.value[episodeId] == next) {
        final rolledBack = Map<int, int>.from(status.value);
        final previous = before[episodeId];
        if (previous == null) {
          rolledBack.remove(episodeId);
        } else {
          rolledBack[episodeId] = previous;
        }
        status.value = rolledBack;
      }
      return false;
    }
  }

  void dispose() {
    _disposed = true;
    _authGeneration++;
    status.dispose();
    statusReady.dispose();
    statusFailed.dispose();
  }
}

// ---------------- 顶部观看进度条 ----------------

class _EpisodeProgressBar extends StatelessWidget {
  final _EpisodeTracker tracker;
  const _EpisodeProgressBar({required this.tracker});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: AuthStore.instance.token,
      builder: (context, token, _) {
        if (token == null || token.isEmpty) return const SizedBox.shrink();
        return ValueListenableBuilder<bool>(
          valueListenable: tracker.statusReady,
          builder: (context, ready, _) {
            if (!ready) return const SizedBox.shrink();
            return ValueListenableBuilder<Map<int, int>>(
              valueListenable: tracker.status,
              builder: (context, status, _) {
                return FutureBuilder<List<Episode>>(
                  future: tracker.episodes,
                  builder: (context, snap) {
                    final eps = snap.data ?? const [];
                    if (eps.isEmpty) return const SizedBox.shrink();
                    final watched = eps.where((e) => status[e.id] == 2).length;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              '观看进度',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '已看 $watched/${eps.length}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.vermilion,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: eps.isEmpty ? 0 : watched / eps.length,
                            minHeight: 8,
                            backgroundColor: AppColors.line,
                            color: AppColors.vermilion,
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

// ---------------- 章节列表（单集标记） ----------------

class _EpisodesSection extends StatefulWidget {
  final _EpisodeTracker tracker;
  const _EpisodesSection({required this.tracker});

  @override
  State<_EpisodesSection> createState() => _EpisodesSectionState();
}

class _EpisodesSectionState extends State<_EpisodesSection> {
  final Set<int> _updating = {};

  Future<void> _toggle(Episode e) async {
    if (_updating.contains(e.id)) return;
    setState(() => _updating.add(e.id));
    final ok = await widget.tracker.toggle(e.id);
    if (!mounted) return;
    setState(() => _updating.remove(e.id));
    if (!ok) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('标记失败，请重试')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: AuthStore.instance.token,
      builder: (context, token, _) {
        final loggedIn = token != null && token.isNotEmpty;
        return AnimatedBuilder(
          animation: Listenable.merge([
            widget.tracker.statusReady,
            widget.tracker.statusFailed,
          ]),
          builder: (context, _) {
            final canToggle = loggedIn && widget.tracker.statusReady.value;
            return FutureBuilder<List<Episode>>(
              future: widget.tracker.episodes,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final eps = snap.data ?? const [];
                if (eps.isEmpty) return const SizedBox.shrink();
                return ValueListenableBuilder<Map<int, int>>(
                  valueListenable: widget.tracker.status,
                  builder: (context, status, _) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '章节 (${eps.length})',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (loggedIn &&
                              !widget.tracker.statusReady.value) ...[
                            const SizedBox(height: 6),
                            if (widget.tracker.statusFailed.value)
                              TextButton.icon(
                                onPressed: widget.tracker.retryStatus,
                                icon: const Icon(Icons.refresh, size: 18),
                                label: const Text('单集状态加载失败，点此重试'),
                              )
                            else
                              const LinearProgressIndicator(minHeight: 1),
                          ],
                          const SizedBox(height: 6),
                          Card(
                            child: Column(
                              children: eps
                                  .map(
                                    (e) => _episodeTile(e, canToggle, status),
                                  )
                                  .toList(),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _episodeTile(Episode e, bool loggedIn, Map<int, int> status) {
    final st = status[e.id] ?? 0;
    return ListTile(
      dense: true,
      onTap: loggedIn ? () => _toggle(e) : null,
      leading: CircleAvatar(
        radius: 14,
        child: Text(e.epLabel, style: const TextStyle(fontSize: 12)),
      ),
      title: Text(
        e.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14),
      ),
      subtitle: Text(
        [
          if (e.airdate.isNotEmpty) e.airdate,
          if (e.comment > 0) '${e.comment} 讨论',
        ].join(' · '),
        style: const TextStyle(fontSize: 11, color: AppColors.muted),
      ),
      trailing: loggedIn ? _statusIcon(e, st) : null,
    );
  }

  Widget _statusIcon(Episode e, int st) {
    if (_updating.contains(e.id)) {
      return const SizedBox(
        width: 22,
        height: 22,
        child: Padding(
          padding: EdgeInsets.all(4),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    final (IconData icon, Color color) = switch (st) {
      1 => (Icons.star_rounded, AppColors.vermilion),
      2 => (Icons.check_circle_rounded, AppColors.vermilion),
      3 => (Icons.cancel_rounded, AppColors.muted),
      _ => (Icons.radio_button_unchecked, AppColors.subtle),
    };
    return Icon(icon, color: color, size: 22);
  }
}

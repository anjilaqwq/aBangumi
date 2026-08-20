import 'package:flutter/material.dart';

import '../api/bangumi_api.dart';
import '../models/models.dart';
import '../store/auth_store.dart';
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
  late final _EpisodeTracker _tracker;

  @override
  void initState() {
    super.initState();
    _subjectFuture = BangumiApi.subject(widget.subjectId);
    _charactersFuture = BangumiApi.characters(widget.subjectId);
    _tracker = _EpisodeTracker(widget.subjectId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Subject>(
      future: _subjectFuture,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError || !snap.hasData) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(child: Text('加载失败：${snap.error}')),
          );
        }
        final s = snap.data!;
        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 260,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (s.cover.isNotEmpty)
                        Image.network(
                          s.cover,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const ColoredBox(color: Colors.black12),
                        ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black54],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(child: _content(s)),
              SliverToBoxAdapter(child: _RelatedSection(subjectId: s.id)),
              SliverToBoxAdapter(child: _charactersSection(_charactersFuture)),
              SliverToBoxAdapter(child: _EpisodesSection(tracker: _tracker)),
            ],
          ),
        );
      },
    );
  }

  Widget _content(Subject s) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.title,
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold)),
                    if (s.originalTitle.isNotEmpty &&
                        s.originalTitle != s.title)
                      Text(s.originalTitle,
                          style:
                              const TextStyle(fontSize: 14, color: Colors.grey)),
                  ],
                ),
              ),
              if (s.score > 0)
                Column(
                  children: [
                    Text(
                      s.score.toStringAsFixed(1),
                      style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFE0556E)),
                    ),
                    Text(
                      s.ratingTotal > 0 ? '${s.ratingTotal} 人评分' : '评分',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _chip(s.typeLabel),
              if (s.platform.isNotEmpty) _chip(s.platform),
              if (s.date.isNotEmpty) _chip(s.date),
              if (s.rank > 0) _chip('Rank #${s.rank}'),
            ],
          ),
          const SizedBox(height: 12),
          _CollectionBar(subjectId: s.id),
          const SizedBox(height: 12),
          _EpisodeProgressBar(tracker: _tracker),
          if (s.tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: s.tags
                  .take(12)
                  .map((t) => ActionChip(
                        label: Text(t, style: const TextStyle(fontSize: 12)),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => TagPage(tag: t)),
                        ),
                      ))
                  .toList(),
            ),
          ],
          if (s.infobox.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: s.infobox
                      .map((e) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 76,
                                  child: Text(e.key,
                                      style: const TextStyle(
                                          color: Colors.grey, fontSize: 13)),
                                ),
                                Expanded(
                                  child: Text(e.value,
                                      style: const TextStyle(fontSize: 13)),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ),
            ),
          ],
          if (s.summary.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('简介',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(s.summary.trim(),
                style: const TextStyle(fontSize: 14, height: 1.6)),
          ],
        ],
      ),
    );
  }

  Widget _charactersSection(Future<List<Character>> future) {
    return FutureBuilder<List<Character>>(
      future: future,
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
              Text('角色 (${list.length})',
                  style:
                      const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SizedBox(
                height: 122,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, i) {
                    final c = list[i];
                    return InkWell(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                CharacterPage(characterId: c.id)),
                      ),
                      child: SizedBox(
                        width: 82,
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 30,
                              backgroundImage: c.imagesLarge.isNotEmpty
                                  ? NetworkImage(c.imagesLarge)
                                  : null,
                              child: c.imagesLarge.isEmpty
                                  ? const Icon(Icons.person)
                                  : null,
                            ),
                            const SizedBox(height: 4),
                            Text(c.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11)),
                            if (c.relation.isNotEmpty)
                              Text(c.relation,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 10, color: Colors.grey[500])),
                            if (c.cvName.isNotEmpty)
                              Text('CV: ${c.cvName}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFFE0556E))),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _chip(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(text, style: const TextStyle(fontSize: 12)),
      );
}

// ---------------- 收藏栏 ----------------

class _CollectionBar extends StatefulWidget {
  final int subjectId;
  const _CollectionBar({required this.subjectId});

  @override
  State<_CollectionBar> createState() => _CollectionBarState();
}

class _CollectionBarState extends State<_CollectionBar> {
  Collection? _col;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = AuthStore.instance.token.value;
    final user = AuthStore.instance.user.value;
    if (token == null || user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final c = await BangumiApi.subjectCollection(
          token, user.username, widget.subjectId);
      if (mounted) setState(() => _col = c);
    } catch (_) {
      // 忽略错误，按未收藏展示
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _openEditor() async {
    final token = AuthStore.instance.token.value;
    if (token == null) return;
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CollectionEditorSheet(
        subjectId: widget.subjectId,
        initial: _col,
      ),
    );
    if (changed == true && mounted) {
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('收藏已保存')));
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
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.bookmark_border, size: 20, color: Colors.grey),
                const SizedBox(width: 8),
                Text('在「我的」页登录后可管理收藏',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600])),
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
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
                const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
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
  final Collection? initial;
  const _CollectionEditorSheet({required this.subjectId, this.initial});

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
    _commentController =
        TextEditingController(text: widget.initial?.comment ?? '');
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('保存失败：$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('收藏',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: kCollectionTypes
                  .map((e) => ChoiceChip(
                        label: Text(e.value),
                        selected: _type == e.key,
                        onSelected: (_) => setState(() => _type = e.key),
                      ))
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
                  child: Text(_rate == 0 ? '—' : '$_rate',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold)),
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
  const _RelatedSection({required this.subjectId});

  @override
  State<_RelatedSection> createState() => _RelatedSectionState();
}

class _RelatedSectionState extends State<_RelatedSection> {
  late Future<List<Subject>> _future;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _future = BangumiApi.relatedSubjects(widget.subjectId);
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
                    child: Text('相关条目 (${list.length})',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _expanded = !_expanded),
                    child: Text(_expanded ? '收起' : '查看全部',
                        style: const TextStyle(fontSize: 12)),
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
                  child: r.cover.isNotEmpty
                      ? Image.network(
                          r.cover,
                          width: 96,
                          height: 126,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _ph(96, 126),
                        )
                      : _ph(96, 126),
                ),
                if (r.relation.isNotEmpty)
                  Positioned(
                    left: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: const BoxDecoration(
                        color: Color(0xCCE0556E),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(6),
                          bottomRight: Radius.circular(6),
                        ),
                      ),
                      child: Text(r.relation,
                          style: const TextStyle(
                              fontSize: 9, color: Colors.white)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(r.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 2),
            Text(r.typeLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10, color: Colors.grey[500])),
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
              child: r.cover.isNotEmpty
                  ? Image.network(
                      r.cover,
                      width: 44,
                      height: 62,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _ph(44, 62),
                    )
                  : _ph(44, 62),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
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
            const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
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

  Widget _ph(double w, double h) => Container(
        width: w,
        height: h,
        color: Colors.grey[300],
        child: const Icon(Icons.image, color: Colors.grey),
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
  final ValueNotifier<Map<int, int>> status = ValueNotifier<Map<int, int>>({});
  late final Future<List<Episode>> episodes;
  bool _statusLoading = false;

  _EpisodeTracker(this.subjectId) {
    episodes = BangumiApi.episodes(subjectId);
  }

  /// 登录状态下懒加载单集状态
  void ensureStatus() {
    final token = AuthStore.instance.token.value;
    if (token == null || token.isEmpty) return;
    if (_statusLoading || status.value.isNotEmpty) return;
    _statusLoading = true;
    BangumiApi.episodeStatus(token, subjectId).then((m) {
      status.value = m;
    }).catchError((Object _) {
      // 加载失败保持空
    }).whenComplete(() => _statusLoading = false);
  }

  /// 切换「看过」：未标记 → 看过 → 取消。返回是否成功（失败时已回滚）。
  Future<bool> toggle(int episodeId) async {
    final token = AuthStore.instance.token.value;
    if (token == null || token.isEmpty) return false;
    final current = status.value[episodeId] ?? 0;
    final next = current == 2 ? 0 : 2;
    final before = Map<int, int>.from(status.value);
    final updated = Map<int, int>.from(status.value);
    if (next == 0) {
      updated.remove(episodeId);
    } else {
      updated[episodeId] = next;
    }
    status.value = updated; // 乐观更新
    try {
      await BangumiApi.updateEpisode(token, episodeId, next);
      return true;
    } catch (_) {
      status.value = before; // 回滚
      return false;
    }
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
        tracker.ensureStatus();
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
                        const Text('观看进度',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                        const Spacer(),
                        Text(
                          '已看 $watched/${eps.length}',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2E7D32)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: eps.isEmpty ? 0 : watched / eps.length,
                        minHeight: 8,
                        backgroundColor: Colors.grey[200],
                        color: const Color(0xFF4CAF50),
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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('标记失败，请重试')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: AuthStore.instance.token,
      builder: (context, token, _) {
        final loggedIn = token != null && token.isNotEmpty;
        if (loggedIn) widget.tracker.ensureStatus();
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
                      Text('章节 (${eps.length})',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Card(
                        child: Column(
                          children: eps
                              .map((e) => _episodeTile(e, loggedIn, status))
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
      title: Text(e.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14)),
      subtitle: Text(
        [
          if (e.airdate.isNotEmpty) e.airdate,
          if (e.comment > 0) '${e.comment} 讨论',
        ].join(' · '),
        style: const TextStyle(fontSize: 11, color: Colors.grey),
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
      1 => (Icons.star_rounded, Colors.amber),
      2 => (Icons.check_circle_rounded, const Color(0xFF4CAF50)),
      3 => (Icons.cancel_rounded, Colors.grey),
      _ => (Icons.radio_button_unchecked, Colors.grey[400]!),
    };
    return Icon(icon, color: color, size: 22);
  }
}


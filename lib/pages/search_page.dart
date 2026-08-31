import 'package:flutter/material.dart';

import '../api/bangumi_api.dart';
import '../models/models.dart';
import '../navigation/routes.dart';
import '../store/auth_store.dart';
import '../widgets/common/common.dart';
import '../widgets/subject_card.dart';
import '../widgets/subject_type_selector.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _controller = TextEditingController();
  int _type = 0;
  int _requestGeneration = 0;
  bool _loading = false;
  String _keyword = '';
  List<_SearchResult> _results = [];
  String? _error;

  Future<void> _submitSearch() async {
    final keyword = _controller.text.trim();
    if (keyword.isEmpty) return;
    await _search(keyword, type: _type, commitKeyword: true);
  }

  Future<void> _search(
    String keyword, {
    required int type,
    bool commitKeyword = false,
    bool clearResults = true,
  }) async {
    final generation = ++_requestGeneration;
    setState(() {
      _loading = true;
      _error = null;
      if (clearResults) _results = [];
      if (commitKeyword) _keyword = keyword;
    });

    try {
      final results = await _fetchResults(keyword, type);
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _loading = false;
        _results = results;
      });
    } catch (error) {
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<List<_SearchResult>> _fetchResults(String keyword, int type) async {
    final token = AuthStore.instance.token.value;
    if (type == kSearchPeopleType) {
      final groups = await Future.wait([
        BangumiApi.searchCharacters(
          keyword,
          token: token,
        ).then((page) => page.items.map(_SearchResult.character).toList()),
        BangumiApi.searchPersons(
          keyword,
          token: token,
        ).then((page) => page.items.map(_SearchResult.person).toList()),
      ]);
      return [...groups[1], ...groups[0]];
    }

    final subjects = BangumiApi.searchSubjects(
      keyword,
      token: token,
      type: type == 0 ? null : type,
    ).then((page) => page.items.map(_SearchResult.subject).toList());
    if (type != 0) return subjects;

    // “全部”同时覆盖条目、角色和现实人物；三组请求并行完成。
    final groups = await Future.wait([
      subjects,
      BangumiApi.searchCharacters(
        keyword,
        token: token,
        limit: 10,
      ).then((page) => page.items.map(_SearchResult.character).toList()),
      BangumiApi.searchPersons(
        keyword,
        token: token,
        limit: 10,
      ).then((page) => page.items.map(_SearchResult.person).toList()),
    ]);
    return [...groups[0], ...groups[2], ...groups[1]];
  }

  Future<void> _refresh() {
    if (_keyword.isEmpty) return Future<void>.value();
    return _search(_keyword, type: _type, clearResults: false);
  }

  void _onTypeChanged(int type) {
    if (type == _type) return;
    final keyword = _keyword;
    setState(() => _type = type);
    if (keyword.isNotEmpty) _search(keyword, type: type);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('搜索')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final tablet = constraints.maxWidth >= 720;
          final content = _SearchContent(
            searchField: _searchField(),
            typeSelector: tablet
                ? null
                : SubjectTypeSelector(
                    selected: _type,
                    entries: kSearchTypes,
                    onChanged: _onTypeChanged,
                  ),
            body: _buildBody(),
          );
          if (!tablet) return content;
          return Row(
            children: [
              Material(
                color: Theme.of(context).colorScheme.surface,
                child: SizedBox(
                  width: 118,
                  child: SubjectTypeSelector(
                    selected: _type,
                    entries: kSearchTypes,
                    direction: Axis.vertical,
                    onChanged: _onTypeChanged,
                  ),
                ),
              ),
              VerticalDivider(
                width: 1,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1180),
                    child: content,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _searchField() {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: TextField(
        controller: _controller,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => _submitSearch(),
        decoration: InputDecoration(
          hintText: '搜索条目、角色与人物…',
          prefixIcon: Icon(Icons.search, color: colors.onSurfaceVariant),
          suffixIcon: IconButton(
            icon: const Icon(Icons.arrow_forward_rounded),
            tooltip: '搜索',
            onPressed: _submitSearch,
          ),
          filled: true,
          fillColor: colors.surface,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: colors.outlineVariant),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: colors.primary, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _results.isEmpty) {
      return const LoadingState(message: '正在搜索…');
    }
    if (_error != null) {
      return ErrorState(message: '搜索失败：$_error', onRetry: _refresh);
    }
    if (_keyword.isEmpty) {
      return const EmptyState(
        message: '可搜索动画、书籍、游戏、音乐、三次元、角色与人物',
        icon: Icons.search,
      );
    }
    if (_results.isEmpty) {
      return _refreshableState(
        const EmptyState(message: '没有找到相关内容', icon: Icons.search_off),
      );
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final grid = constraints.maxWidth >= 760;
          if (!grid) {
            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 28),
              itemCount: _results.length,
              itemBuilder: (context, index) => _resultTile(_results[index]),
            );
          }
          return GridView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 560,
              mainAxisExtent: 126,
              crossAxisSpacing: 12,
            ),
            itemCount: _results.length,
            itemBuilder: (context, index) => _resultTile(_results[index]),
          );
        },
      ),
    );
  }

  Widget _resultTile(_SearchResult result) {
    final subject = result.subject;
    if (subject != null) {
      return SubjectCard(
        subject: subject,
        onTap: () => AppRoutes.pushSubject(context, subject.id),
      );
    }
    return _PeopleResultCard(
      result: result,
      onTap: () {
        switch (result.kind) {
          case _SearchResultKind.character:
            AppRoutes.pushCharacter(context, result.id);
            break;
          case _SearchResultKind.person:
            AppRoutes.pushPerson(context, result.id);
            break;
          case _SearchResultKind.subject:
            break;
        }
      },
    );
  }

  Widget _refreshableState(Widget state) {
    return LayoutBuilder(
      builder: (context, constraints) => RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [SizedBox(height: constraints.maxHeight, child: state)],
        ),
      ),
    );
  }
}

class _SearchContent extends StatelessWidget {
  final Widget searchField;
  final Widget? typeSelector;
  final Widget body;

  const _SearchContent({
    required this.searchField,
    required this.typeSelector,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        searchField,
        if (typeSelector != null) typeSelector!,
        Expanded(child: body),
      ],
    );
  }
}

enum _SearchResultKind { subject, character, person }

class _SearchResult {
  final _SearchResultKind kind;
  final int id;
  final String title;
  final String subtitle;
  final String imageUrl;
  final Subject? subject;

  const _SearchResult._({
    required this.kind,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    this.subject,
  });

  factory _SearchResult.subject(Subject subject) => _SearchResult._(
    kind: _SearchResultKind.subject,
    id: subject.id,
    title: subject.title,
    subtitle: subject.typeLabel,
    imageUrl: subject.cover,
    subject: subject,
  );

  factory _SearchResult.character(Character character) => _SearchResult._(
    kind: _SearchResultKind.character,
    id: character.id,
    title: character.title,
    subtitle: [
      '角色',
      if (character.relation.isNotEmpty) character.relation,
      if (character.statCollects > 0) '${character.statCollects} 人收藏',
    ].join(' · '),
    imageUrl: character.imagesLarge,
  );

  factory _SearchResult.person(Person person) => _SearchResult._(
    kind: _SearchResultKind.person,
    id: person.id,
    title: person.name,
    subtitle: [
      '人物',
      if (person.careerText.isNotEmpty) person.careerText,
      if (person.statCollects > 0) '${person.statCollects} 人收藏',
    ].join(' · '),
    imageUrl: person.imagesLarge,
  );
}

class _PeopleResultCard extends StatelessWidget {
  final _SearchResult result;
  final VoidCallback onTap;

  const _PeopleResultCard({required this.result, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(11),
            child: Row(
              children: [
                CoverImage(
                  imageUrl: result.imageUrl,
                  width: 68,
                  height: 94,
                  alignment: Alignment.topCenter,
                  borderRadius: 11,
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        result.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
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
}

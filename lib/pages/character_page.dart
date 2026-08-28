import 'package:flutter/material.dart';

import '../api/bangumi_api.dart';
import '../models/models.dart';
import '../theme/app_colors.dart';
import '../widgets/common/common.dart';
import '../widgets/ref_tiles.dart';
import 'person_page.dart';
import 'subject_detail_page.dart';

class CharacterPage extends StatefulWidget {
  final int characterId;

  const CharacterPage({super.key, required this.characterId});

  @override
  State<CharacterPage> createState() => _CharacterPageState();
}

class _CharacterPageState extends State<CharacterPage> {
  late Future<Character> _charFuture;
  late Future<List<WorkRef>> _subjectsFuture;
  late Future<List<CastRef>> _personsFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _charFuture = BangumiApi.character(widget.characterId);
    _subjectsFuture = BangumiApi.characterSubjects(widget.characterId);
    _personsFuture = BangumiApi.characterPersons(widget.characterId);
  }

  void _reload() => setState(_load);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Character>(
      future: _charFuture,
      builder: (context, snapshot) {
        final character = snapshot.data;
        return Scaffold(
          backgroundColor: AppColors.paper,
          appBar: AppBar(title: Text(character?.title ?? '角色详情')),
          body: _body(snapshot),
        );
      },
    );
  }

  Widget _body(AsyncSnapshot<Character> snapshot) {
    if (snapshot.connectionState != ConnectionState.done) {
      return const LoadingState(message: '正在读取角色资料');
    }
    if (snapshot.hasError || !snapshot.hasData) {
      return ErrorState(
        message: '加载失败：${snapshot.error ?? '未找到角色资料'}',
        onRetry: _reload,
      );
    }

    final character = snapshot.data!;
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        DetailHero(
          coverUrl: character.imagesLarge,
          title: character.title,
          subtitle:
              character.name.isNotEmpty && character.name != character.title
              ? character.name
              : null,
          meta: [
            const TagChip(label: '角色'),
            if (character.gender.isNotEmpty) TagChip(label: character.gender),
            if (character.birthYear.isNotEmpty)
              TagChip(label: '${character.birthYear}年生'),
            if (character.bloodType.isNotEmpty)
              TagChip(label: '${character.bloodType}型'),
            if (character.statCollects > 0)
              TagChip(label: '${character.statCollects} 人收藏'),
          ],
        ),
        if (character.infobox.isNotEmpty) ...[
          const SectionHeader(title: '资料'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: InfoBox(
              entries: character.infobox
                  .map((entry) => InfoEntry(entry.key, entry.value))
                  .toList(),
            ),
          ),
        ],
        if (character.summary.trim().isNotEmpty) ...[
          const SectionHeader(title: '简介'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              character.summary.trim(),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.ink,
                height: 1.8,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: HairlineDivider(),
          ),
        ],
        _subjectsSection(),
        _personsSection(),
      ],
    );
  }

  Widget _subjectsSection() {
    return FutureBuilder<List<WorkRef>>(
      future: _subjectsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const LoadingState(
            message: '正在读取出演作品',
            padding: EdgeInsets.symmetric(vertical: 28),
          );
        }
        final works = snapshot.data ?? const [];
        if (works.isEmpty) return const SizedBox.shrink();
        return _referenceSection(
          title: '出演作品',
          count: works.length,
          children: works
              .map(
                (work) => InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          SubjectDetailPage(subjectId: work.subjectId),
                    ),
                  ),
                  child: WorkTile(work: work),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _personsSection() {
    return FutureBuilder<List<CastRef>>(
      future: _personsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const LoadingState(
            message: '正在读取配音演员',
            padding: EdgeInsets.symmetric(vertical: 28),
          );
        }
        final persons = snapshot.data ?? const [];
        if (persons.isEmpty) return const SizedBox.shrink();
        return _referenceSection(
          title: '配音演员',
          count: persons.length,
          children: persons
              .map(
                (person) => InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PersonPage(personId: person.id),
                    ),
                  ),
                  child: CastTile(cast: person),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _referenceSection({
    required String title,
    required int count,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: title, count: '$count'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const HairlineDivider(),
              for (var index = 0; index < children.length; index++) ...[
                children[index],
                const HairlineDivider(),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

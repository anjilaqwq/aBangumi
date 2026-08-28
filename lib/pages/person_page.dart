import 'package:flutter/material.dart';

import '../api/bangumi_api.dart';
import '../models/models.dart';
import '../theme/app_colors.dart';
import '../widgets/common/common.dart';
import '../widgets/ref_tiles.dart';
import 'character_page.dart';
import 'subject_detail_page.dart';

class PersonPage extends StatefulWidget {
  final int personId;

  const PersonPage({super.key, required this.personId});

  @override
  State<PersonPage> createState() => _PersonPageState();
}

class _PersonPageState extends State<PersonPage> {
  late Future<Person> _personFuture;
  late Future<List<CastRef>> _charactersFuture;
  late Future<List<WorkRef>> _subjectsFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _personFuture = BangumiApi.person(widget.personId);
    _charactersFuture = BangumiApi.personCharacters(widget.personId);
    _subjectsFuture = BangumiApi.personSubjects(widget.personId);
  }

  void _reload() => setState(_load);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Person>(
      future: _personFuture,
      builder: (context, snapshot) {
        final person = snapshot.data;
        return Scaffold(
          backgroundColor: AppColors.paper,
          appBar: AppBar(title: Text(person?.name ?? '人物详情')),
          body: _body(snapshot),
        );
      },
    );
  }

  Widget _body(AsyncSnapshot<Person> snapshot) {
    if (snapshot.connectionState != ConnectionState.done) {
      return const LoadingState(message: '正在读取人物资料');
    }
    if (snapshot.hasError || !snapshot.hasData) {
      return ErrorState(
        message: '加载失败：${snapshot.error ?? '未找到人物资料'}',
        onRetry: _reload,
      );
    }

    final person = snapshot.data!;
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        DetailHero(
          coverUrl: person.imagesLarge,
          title: person.name,
          meta: [
            ...person.career.map(
              (career) => TagChip(label: careerLabel(career)),
            ),
            if (person.gender.isNotEmpty) TagChip(label: person.gender),
            if (person.birthYear.isNotEmpty)
              TagChip(label: '${person.birthYear}年生'),
            if (person.statCollects > 0)
              TagChip(label: '${person.statCollects} 人收藏'),
          ],
        ),
        if (person.infobox.isNotEmpty) ...[
          const SectionHeader(title: '资料'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: InfoBox(
              entries: person.infobox
                  .map((entry) => InfoEntry(entry.key, entry.value))
                  .toList(),
            ),
          ),
        ],
        if (person.summary.trim().isNotEmpty) ...[
          const SectionHeader(title: '简介'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              person.summary.trim(),
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
        _charactersSection(),
        _subjectsSection(),
      ],
    );
  }

  Widget _charactersSection() {
    return FutureBuilder<List<CastRef>>(
      future: _charactersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const LoadingState(
            message: '正在读取配音角色',
            padding: EdgeInsets.symmetric(vertical: 28),
          );
        }
        final characters = snapshot.data ?? const [];
        if (characters.isEmpty) return const SizedBox.shrink();
        return _referenceSection(
          title: '配音角色',
          count: characters.length,
          children: characters
              .map(
                (character) => InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CharacterPage(characterId: character.id),
                    ),
                  ),
                  child: CastTile(cast: character),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _subjectsSection() {
    return FutureBuilder<List<WorkRef>>(
      future: _subjectsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const LoadingState(
            message: '正在读取参与作品',
            padding: EdgeInsets.symmetric(vertical: 28),
          );
        }
        final works = snapshot.data ?? const [];
        if (works.isEmpty) return const SizedBox.shrink();
        return _referenceSection(
          title: '参与作品',
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

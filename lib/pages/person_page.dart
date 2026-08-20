import 'package:flutter/material.dart';

import '../api/bangumi_api.dart';
import '../models/models.dart';
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
    _personFuture = BangumiApi.person(widget.personId);
    _charactersFuture = BangumiApi.personCharacters(widget.personId);
    _subjectsFuture = BangumiApi.personSubjects(widget.personId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Person>(
      future: _personFuture,
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
        final p = snap.data!;
        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 240,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (p.imagesLarge.isNotEmpty)
                        Image.network(
                          p.imagesLarge,
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
              SliverToBoxAdapter(child: _content(p)),
              SliverToBoxAdapter(child: _charactersSection()),
              SliverToBoxAdapter(child: _subjectsSection()),
            ],
          ),
        );
      },
    );
  }

  Widget _content(Person p) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(p.name,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ...p.career.map((c) => _chip(careerLabel(c))),
              if (p.gender.isNotEmpty) _chip(p.gender),
              if (p.birthYear.isNotEmpty) _chip('${p.birthYear}年生'),
              if (p.statCollects > 0) _chip('${p.statCollects} 人收藏'),
            ],
          ),
          if (p.infobox.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: p.infobox
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
          if (p.summary.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('简介',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(p.summary.trim(),
                style: const TextStyle(fontSize: 14, height: 1.6)),
          ],
        ],
      ),
    );
  }

  Widget _charactersSection() {
    return FutureBuilder<List<CastRef>>(
      future: _charactersFuture,
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
              Text('配音角色 (${list.length})',
                  style:
                      const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Card(
                child: Column(
                  children: list
                      .map((c) => InkWell(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      CharacterPage(characterId: c.id)),
                            ),
                            child: CastTile(cast: c),
                          ))
                      .toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _subjectsSection() {
    return FutureBuilder<List<WorkRef>>(
      future: _subjectsFuture,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
        final list = snap.data ?? const [];
        if (list.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('参与作品 (${list.length})',
                  style:
                      const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Card(
                child: Column(
                  children: list
                      .map((w) => InkWell(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => SubjectDetailPage(
                                      subjectId: w.subjectId)),
                            ),
                            child: WorkTile(work: w),
                          ))
                      .toList(),
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

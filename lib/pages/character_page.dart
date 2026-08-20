import 'package:flutter/material.dart';

import '../api/bangumi_api.dart';
import '../models/models.dart';
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
    _charFuture = BangumiApi.character(widget.characterId);
    _subjectsFuture = BangumiApi.characterSubjects(widget.characterId);
    _personsFuture = BangumiApi.characterPersons(widget.characterId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Character>(
      future: _charFuture,
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
        final c = snap.data!;
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
                      if (c.imagesLarge.isNotEmpty)
                        Image.network(
                          c.imagesLarge,
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
              SliverToBoxAdapter(child: _content(c)),
              SliverToBoxAdapter(child: _subjectsSection()),
              SliverToBoxAdapter(child: _personsSection()),
            ],
          ),
        );
      },
    );
  }

  Widget _content(Character c) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(c.title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          if (c.name.isNotEmpty && c.name != c.title)
            Text(c.name, style: const TextStyle(fontSize: 14, color: Colors.grey)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _chip('角色'),
              if (c.gender.isNotEmpty) _chip(c.gender),
              if (c.birthYear.isNotEmpty) _chip('${c.birthYear}年生'),
              if (c.bloodType.isNotEmpty) _chip('${c.bloodType}型'),
              if (c.statCollects > 0) _chip('${c.statCollects} 人收藏'),
            ],
          ),
          if (c.infobox.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: c.infobox
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
          if (c.summary.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('简介',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(c.summary.trim(),
                style: const TextStyle(fontSize: 14, height: 1.6)),
          ],
        ],
      ),
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
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('出演作品 (${list.length})',
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

  Widget _personsSection() {
    return FutureBuilder<List<CastRef>>(
      future: _personsFuture,
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
              Text('配音演员 (${list.length})',
                  style:
                      const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Card(
                child: Column(
                  children: list
                      .map((p) => InkWell(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => PersonPage(personId: p.id)),
                            ),
                            child: CastTile(cast: p),
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

import 'package:flutter/material.dart';

import '../models/models.dart';

class SubjectCard extends StatelessWidget {
  final Subject subject;
  final VoidCallback? onTap;

  const SubjectCard({super.key, required this.subject, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: subject.cover.isNotEmpty
                    ? Image.network(
                        subject.cover,
                        width: 64,
                        height: 90,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholder(),
                      )
                    : _placeholder(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subject.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    if (subject.originalTitle.isNotEmpty &&
                        subject.originalTitle != subject.title)
                      Text(
                        subject.originalTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _meta(subject.typeLabel),
                        if (subject.platform.isNotEmpty) _meta(subject.platform),
                        if (subject.date.isNotEmpty) _meta(subject.date),
                      ],
                    ),
                    if (subject.tags.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          subject.tags.take(3).join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _scoreBadge(subject.score),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
        width: 64,
        height: 90,
        color: Colors.grey[300],
        child: const Icon(Icons.image_not_supported_outlined, color: Colors.grey),
      );

  Widget _meta(String text) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Text(text,
            style: TextStyle(fontSize: 12, color: Colors.grey[500])),
      );

  Widget _scoreBadge(double score) {
    if (score <= 0) return const SizedBox.shrink();
    return Column(
      children: [
        Text(
          score.toStringAsFixed(1),
          style: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFFE0556E)),
        ),
        const Text('评分', style: TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}

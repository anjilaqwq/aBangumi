import 'package:flutter/material.dart';

import '../models/models.dart';

/// 出演作品行（用于角色页/人物页的作品列表）
class WorkTile extends StatelessWidget {
  final WorkRef work;
  const WorkTile({super.key, required this.work});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: work.image.isNotEmpty
            ? Image.network(
                work.image,
                width: 40,
                height: 56,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _ph(),
              )
            : _ph(),
      ),
      title: Text(
        work.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14),
      ),
      subtitle: work.staff.isNotEmpty
          ? Text(
              work.staff,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            )
          : null,
      trailing: work.type != 0
          ? Text(
              subjectTypeLabel(work.type),
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            )
          : null,
    );
  }

  Widget _ph() => Container(
    width: 40,
    height: 56,
    color: Colors.grey[300],
    child: const Icon(Icons.image, size: 16, color: Colors.grey),
  );
}

/// 配音/出演关联行（角色→声优 或 声优→角色）
class CastTile extends StatelessWidget {
  final CastRef cast;
  const CastTile({super.key, required this.cast});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: ClipOval(
        child: SizedBox(
          width: 40,
          height: 40,
          child: cast.imagesLarge.isNotEmpty
              ? Image.network(
                  cast.imagesLarge,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  errorBuilder: (_, __, ___) => _personPlaceholder(context),
                )
              : _personPlaceholder(context),
        ),
      ),
      title: Text(
        cast.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14),
      ),
      subtitle: cast.subjectTitle.isNotEmpty
          ? Text(
              '《${cast.subjectTitle}》${cast.staff.isNotEmpty ? ' · ${cast.staff}' : ''}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            )
          : null,
    );
  }

  Widget _personPlaceholder(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.outlineVariant,
      child: Icon(Icons.person, size: 20, color: colors.onSurfaceVariant),
    );
  }
}

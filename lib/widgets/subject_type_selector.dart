import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_colors.dart';
import 'common/common.dart';

/// 条目类型选择：横向克制的文字标签，选中项以朱红短线标记，底部细线收束。
class SubjectTypeSelector extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;

  /// 是否在最前追加「全部」选项（用于搜索 / 标签等不限类型的场景）。
  final bool includeAll;

  /// 「全部」选项对应的值，默认 0。
  final int allValue;

  const SubjectTypeSelector({
    super.key,
    required this.selected,
    required this.onChanged,
    this.includeAll = false,
    this.allValue = 0,
  });

  @override
  Widget build(BuildContext context) {
    final entries = <MapEntry<int, String>>[
      if (includeAll) MapEntry(allValue, '全部'),
      ...kSubjectTypes,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 44,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                for (var i = 0; i < entries.length; i++) ...[
                  _Tab(
                    label: entries[i].value,
                    active: entries[i].key == selected,
                    onTap: () => onChanged(entries[i].key),
                  ),
                  if (i != entries.length - 1) const SizedBox(width: 22),
                ],
              ],
            ),
          ),
        ),
        const HairlineDivider(),
      ],
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _Tab({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SizedBox(
      height: 44,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: (active ? textTheme.titleSmall : textTheme.bodyMedium)
                  ?.copyWith(
                    color: active ? AppColors.ink : AppColors.muted,
                    fontWeight: active ? FontWeight.w500 : FontWeight.w400,
                  ),
            ),
            const SizedBox(height: 5),
            SizedBox(
              height: 2,
              width: 18,
              child: active ? const ColoredBox(color: AppColors.vermilion) : null,
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../models/models.dart';

class SubjectTypeSelector extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;
  final bool includeAll;
  final int allValue;
  final List<MapEntry<int, String>>? entries;
  final Axis direction;

  const SubjectTypeSelector({
    super.key,
    required this.selected,
    required this.onChanged,
    this.includeAll = false,
    this.allValue = 0,
    this.entries,
    this.direction = Axis.horizontal,
  });

  @override
  Widget build(BuildContext context) {
    final options =
        entries ??
        <MapEntry<int, String>>[
          if (includeAll) MapEntry(allValue, '全部'),
          ...kSubjectTypes,
        ];
    final list = ListView.separated(
      scrollDirection: direction,
      padding: direction == Axis.horizontal
          ? const EdgeInsets.symmetric(horizontal: 14, vertical: 6)
          : const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      itemCount: options.length,
      separatorBuilder: (_, __) => direction == Axis.horizontal
          ? const SizedBox(width: 8)
          : const SizedBox(height: 7),
      itemBuilder: (context, index) {
        final entry = options[index];
        return _TypePill(
          label: entry.value,
          active: entry.key == selected,
          expanded: direction == Axis.vertical,
          onTap: () => onChanged(entry.key),
        );
      },
    );
    return direction == Axis.horizontal
        ? SizedBox(height: 52, child: list)
        : list;
  }
}

class _TypePill extends StatelessWidget {
  final String label;
  final bool active;
  final bool expanded;
  final VoidCallback onTap;

  const _TypePill({
    required this.label,
    required this.active,
    this.expanded = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          width: expanded ? double.infinity : null,
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(
            horizontal: expanded ? 12 : 17,
            vertical: expanded ? 11 : 8,
          ),
          decoration: BoxDecoration(
            color: active ? colors.primary : colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: active ? colors.primary : colors.outlineVariant,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: active ? colors.onPrimary : colors.onSurfaceVariant,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

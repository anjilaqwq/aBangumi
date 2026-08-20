import 'package:flutter/material.dart';

import '../models/models.dart';

class SubjectTypeSelector extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;

  const SubjectTypeSelector(
      {super.key, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        children: kSubjectTypes.map((e) {
          final active = e.key == selected;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: Text(e.value),
              selected: active,
              onSelected: (_) => onChanged(e.key),
            ),
          );
        }).toList(),
      ),
    );
  }
}

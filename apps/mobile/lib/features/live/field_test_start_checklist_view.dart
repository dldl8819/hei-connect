import 'package:flutter/material.dart';

import 'field_test_start_checklist.dart';

class FieldTestStartChecklistView extends StatelessWidget {
  const FieldTestStartChecklistView({
    super.key,
    required this.state,
    required this.onItemChanged,
  });

  final FieldTestStartChecklistState state;
  final void Function(FieldTestStartChecklistItem item, bool checked)
      onItemChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      label: state.talkBackSummary,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('실기기 테스트 시작 전 점검',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(
                '시작 버튼을 누르기 전에 현장 조건을 다시 확인합니다.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                state.progressLabel,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              for (final item in FieldTestStartChecklistState.items)
                _FieldTestStartChecklistTile(
                  item: item,
                  checked: state.contains(item),
                  onChanged: onItemChanged,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldTestStartChecklistTile extends StatelessWidget {
  const _FieldTestStartChecklistTile({
    required this.item,
    required this.checked,
    required this.onChanged,
  });

  final FieldTestStartChecklistItem item;
  final bool checked;
  final void Function(FieldTestStartChecklistItem item, bool checked) onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: item.checkedSemanticsLabel(checked),
      checked: checked,
      child: CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        dense: false,
        title: Text(item.label),
        subtitle: Text(item.detail),
        value: checked,
        onChanged: (value) => onChanged(item, value ?? false),
      ),
    );
  }
}

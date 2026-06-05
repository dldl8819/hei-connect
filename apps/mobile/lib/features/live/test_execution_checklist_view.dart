import 'package:flutter/material.dart';

import 'test_execution_checklist.dart';

class TestExecutionChecklistView extends StatelessWidget {
  const TestExecutionChecklistView({
    super.key,
    required this.state,
    required this.onItemChanged,
  });

  final TestExecutionChecklistState state;
  final void Function(TestExecutionChecklistItem item, bool checked)
      onItemChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      label: state.progressSemanticsLabel,
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
              Text('테스트 실행 체크리스트',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(
                '원격 가이드와 AI는 보조 기능입니다. 통제 경로 + 백업 동행자 기준으로만 확인합니다.',
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
              for (final category in state.categoryLabels) ...[
                Text(
                  category,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 2),
                for (final item in state.itemsInCategory(category))
                  _TestExecutionChecklistTile(
                    item: item,
                    checked: state.contains(item),
                    onChanged: onItemChanged,
                  ),
                const SizedBox(height: 6),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TestExecutionChecklistTile extends StatelessWidget {
  const _TestExecutionChecklistTile({
    required this.item,
    required this.checked,
    required this.onChanged,
  });

  final TestExecutionChecklistItem item;
  final bool checked;
  final void Function(TestExecutionChecklistItem item, bool checked) onChanged;

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

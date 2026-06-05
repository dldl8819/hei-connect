import 'package:flutter/material.dart';

import 'test_status_observer.dart';

class TestStatusObserverView extends StatelessWidget {
  const TestStatusObserverView({
    super.key,
    required this.state,
  });

  final TestStatusObserverState state;

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
              Text('테스트 상태 관찰', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(
                '현재 테스트 진행에 필요한 운영 상태만 표시합니다.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 10),
              for (final item in state.items) ...[
                _TestStatusObserverRow(item: item),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TestStatusObserverRow extends StatelessWidget {
  const _TestStatusObserverRow({required this.item});

  final TestStatusObserverItem item;

  @override
  Widget build(BuildContext context) {
    final color = _levelColor(context, item.level);
    return Semantics(
      label: item.semanticsLabel,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_levelIcon(item.level), color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.label}: ${item.value}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.detail,
                  softWrap: true,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _levelColor(BuildContext context, TestStatusObserverLevel level) {
    final colorScheme = Theme.of(context).colorScheme;
    return switch (level) {
      TestStatusObserverLevel.ready => colorScheme.primary,
      TestStatusObserverLevel.pending => colorScheme.onSurfaceVariant,
      TestStatusObserverLevel.warning => const Color(0xFFB45309),
      TestStatusObserverLevel.blocked => colorScheme.error,
    };
  }

  IconData _levelIcon(TestStatusObserverLevel level) {
    return switch (level) {
      TestStatusObserverLevel.ready => Icons.check_circle,
      TestStatusObserverLevel.pending => Icons.schedule,
      TestStatusObserverLevel.warning => Icons.warning_amber,
      TestStatusObserverLevel.blocked => Icons.lock,
    };
  }
}

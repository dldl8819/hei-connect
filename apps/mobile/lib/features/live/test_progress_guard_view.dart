import 'package:flutter/material.dart';

import 'test_progress_guard.dart';

class TestProgressGuardView extends StatelessWidget {
  const TestProgressGuardView({
    super.key,
    required this.decisions,
    required this.talkBackSummary,
  });

  final List<TestProgressGuardDecision> decisions;
  final String talkBackSummary;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      label: talkBackSummary,
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
              Text('테스트 진행 가드', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(
                '제어된 코스와 백업 보호자 기준으로 순서를 잠그고 이유를 표시합니다.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 8),
              for (final decision in decisions) ...[
                _TestProgressGuardRow(decision: decision),
                const SizedBox(height: 6),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TestProgressGuardRow extends StatelessWidget {
  const _TestProgressGuardRow({required this.decision});

  final TestProgressGuardDecision decision;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = decision.allowed ? colorScheme.primary : colorScheme.error;
    return Semantics(
      label: decision.semanticsLabel,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            decision.allowed ? Icons.check_circle : Icons.lock,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${decision.label}: ${decision.statusLabel}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                Text(
                  decision.reason,
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
}

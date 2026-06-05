import 'package:flutter/material.dart';

import 'test_session_report.dart';

class TestSessionReportView extends StatelessWidget {
  const TestSessionReportView({
    super.key,
    required this.report,
  });

  final TestSessionReport report;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final statusColor = switch (report.status) {
      TestSessionReportStatus.ready => colorScheme.primary,
      TestSessionReportStatus.sensitiveInfoRequired => colorScheme.error,
      TestSessionReportStatus.emptyInput => colorScheme.onSurfaceVariant,
    };

    return Semantics(
      liveRegion: true,
      label: report.talkBackSummary,
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      '테스트 세션 리포트',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  Text(
                    report.statusLabel,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '화면에만 표시하며 서버 업로드나 외부 공유를 하지 않습니다.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
              if (report.status ==
                  TestSessionReportStatus.sensitiveInfoRequired)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '메모를 리포트에 넣으려면 민감정보 제거 확인이 필요합니다.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.error,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              const SizedBox(height: 10),
              for (final row in report.rows) ...[
                _TestSessionReportRowView(row: row),
                const SizedBox(height: 6),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TestSessionReportRowView extends StatelessWidget {
  const _TestSessionReportRowView({required this.row});

  final TestSessionReportRow row;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 104,
          child: Text(
            row.label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        Expanded(
          child: Text(
            row.value,
            softWrap: true,
          ),
        ),
      ],
    );
  }
}

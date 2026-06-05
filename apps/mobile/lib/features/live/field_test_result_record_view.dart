import 'package:flutter/material.dart';

import 'field_test_result_record.dart';

class FieldTestResultRecordView extends StatelessWidget {
  const FieldTestResultRecordView({
    super.key,
    required this.record,
    required this.selectedOutcome,
    required this.stepController,
    required this.observationController,
    required this.nextActionController,
    required this.retestNeeded,
    required this.onOutcomeChanged,
    required this.onRetestNeededChanged,
    required this.onTextChanged,
  });

  final FieldTestResultRecord record;
  final FieldTestResultOutcome? selectedOutcome;
  final TextEditingController stepController;
  final TextEditingController observationController;
  final TextEditingController nextActionController;
  final bool retestNeeded;
  final ValueChanged<FieldTestResultOutcome?> onOutcomeChanged;
  final ValueChanged<bool> onRetestNeededChanged;
  final VoidCallback onTextChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      label: record.talkBackSummary,
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
              Text('실기기 테스트 결과 기록',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(
                '이번 테스트의 판단만 로컬 화면에서 정리합니다. 외부 전송은 하지 않습니다.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<FieldTestResultOutcome>(
                initialValue: selectedOutcome,
                decoration: const InputDecoration(
                  labelText: '전체 결과',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final outcome in FieldTestResultOutcome.values)
                    DropdownMenuItem(
                      value: outcome,
                      child: Text(outcome.label),
                    ),
                ],
                onChanged: onOutcomeChanged,
              ),
              const SizedBox(height: 8),
              _FieldTestResultRecordTextField(
                controller: stepController,
                label: '실패 또는 보류 단계',
                hint: '예: AI 검증 모드',
                onChanged: onTextChanged,
              ),
              _FieldTestResultRecordTextField(
                controller: observationController,
                label: '관찰 현상',
                hint: '예: 정지 cue 뒤 재개 확인이 늦게 표시됨',
                onChanged: onTextChanged,
                minLines: 2,
              ),
              _FieldTestResultRecordTextField(
                controller: nextActionController,
                label: '다음 액션',
                hint: '예: 같은 조건에서 재테스트',
                onChanged: onTextChanged,
                minLines: 2,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('재테스트 필요'),
                subtitle: const Text('다음 실기기 테스트에서 다시 확인할지 표시합니다.'),
                value: retestNeeded,
                onChanged: onRetestNeededChanged,
              ),
              Text(
                record.readinessLabel,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: record.isReady
                          ? colorScheme.primary
                          : colorScheme.error,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                record.blockingReason,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
              if (record.lengthNotice != null) ...[
                const SizedBox(height: 4),
                Text(
                  record.lengthNotice!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFFB45309),
                      ),
                ),
              ],
              if (record.isReady) ...[
                const SizedBox(height: 10),
                for (final row in record.rows) ...[
                  _FieldTestResultRecordRow(row: row),
                  const SizedBox(height: 4),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldTestResultRecordTextField extends StatelessWidget {
  const _FieldTestResultRecordTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.onChanged,
    this.minLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final VoidCallback onChanged;
  final int minLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: controller,
        minLines: minLines,
        maxLines: minLines + 1,
        maxLength: FieldTestResultRecord.maxFieldLength,
        onChanged: (_) => onChanged(),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          helperText: '운영 판단만 입력',
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

class _FieldTestResultRecordRow extends StatelessWidget {
  const _FieldTestResultRecordRow({required this.row});

  final FieldTestResultRecordRow row;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            row.label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        Expanded(child: Text(row.value)),
      ],
    );
  }
}

enum FieldTestResultOutcome {
  passed,
  partialPassed,
  failed,
  onHold,
}

extension FieldTestResultOutcomeText on FieldTestResultOutcome {
  String get label {
    return switch (this) {
      FieldTestResultOutcome.passed => '통과',
      FieldTestResultOutcome.partialPassed => '부분 통과',
      FieldTestResultOutcome.failed => '실패',
      FieldTestResultOutcome.onHold => '보류',
    };
  }

  bool get requiresStep {
    return switch (this) {
      FieldTestResultOutcome.failed || FieldTestResultOutcome.onHold => true,
      FieldTestResultOutcome.passed ||
      FieldTestResultOutcome.partialPassed =>
        false,
    };
  }
}

class FieldTestResultRecordRow {
  const FieldTestResultRecordRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;
}

class FieldTestResultRecord {
  const FieldTestResultRecord._({
    required this.outcome,
    required this.step,
    required this.observation,
    required this.nextAction,
    required this.retestNeeded,
    required this.hasTruncatedInput,
  });

  static const int maxFieldLength = 240;
  static const String emptyValueLabel = '입력 없음';
  static const String notApplicableLabel = '해당 없음';

  factory FieldTestResultRecord.fromInput({
    FieldTestResultOutcome? outcome,
    String step = '',
    String observation = '',
    String nextAction = '',
    bool retestNeeded = false,
  }) {
    final fields = [step, observation, nextAction];
    return FieldTestResultRecord._(
      outcome: outcome,
      step: _normalize(step),
      observation: _normalize(observation),
      nextAction: _normalize(nextAction),
      retestNeeded: retestNeeded,
      hasTruncatedInput: fields.any(_isTooLong),
    );
  }

  static String _normalize(String value) {
    final trimmed = value.trim();
    if (trimmed.length <= maxFieldLength) {
      return trimmed;
    }
    return trimmed.substring(0, maxFieldLength);
  }

  static bool _isTooLong(String value) {
    return value.trim().length > maxFieldLength;
  }

  final FieldTestResultOutcome? outcome;
  final String step;
  final String observation;
  final String nextAction;
  final bool retestNeeded;
  final bool hasTruncatedInput;

  bool get isReady {
    final selectedOutcome = outcome;
    if (selectedOutcome == null) {
      return false;
    }
    if (selectedOutcome.requiresStep && step.isEmpty) {
      return false;
    }
    return observation.isNotEmpty && nextAction.isNotEmpty;
  }

  String get readinessLabel {
    return isReady ? '결과 기록 준비됨' : '결과 기록 준비 안 됨';
  }

  String get blockingReason {
    final selectedOutcome = outcome;
    if (selectedOutcome == null) {
      return '전체 결과를 먼저 선택합니다.';
    }
    if (selectedOutcome.requiresStep && step.isEmpty) {
      return '실패 또는 보류 단계가 필요합니다.';
    }
    if (observation.isEmpty) {
      return '실제로 관찰한 현상을 입력합니다.';
    }
    if (nextAction.isEmpty) {
      return '다음 액션을 입력합니다.';
    }
    return '외부 전송 없이 화면에서 결과 기록을 확인할 수 있습니다.';
  }

  String? get lengthNotice {
    if (!hasTruncatedInput) {
      return null;
    }
    return '긴 입력은 항목당 $maxFieldLength자까지만 화면에 보관합니다.';
  }

  String get talkBackSummary {
    return '실기기 테스트 결과 기록. $readinessLabel. $blockingReason';
  }

  List<FieldTestResultRecordRow> get rows {
    final selectedOutcome = outcome;
    return [
      FieldTestResultRecordRow(
        label: '전체 결과',
        value: selectedOutcome?.label ?? emptyValueLabel,
      ),
      FieldTestResultRecordRow(
        label: '실패 또는 보류 단계',
        value: selectedOutcome?.requiresStep == true
            ? _valueOrEmpty(step)
            : notApplicableLabel,
      ),
      FieldTestResultRecordRow(
        label: '관찰 현상',
        value: _valueOrEmpty(observation),
      ),
      FieldTestResultRecordRow(
        label: '다음 액션',
        value: _valueOrEmpty(nextAction),
      ),
      FieldTestResultRecordRow(
        label: '재테스트',
        value: retestNeeded ? '필요' : '필요 없음',
      ),
    ];
  }

  String get renderedText {
    return [
      readinessLabel,
      blockingReason,
      talkBackSummary,
      for (final row in rows) '${row.label}: ${row.value}',
    ].join('\n');
  }

  String _valueOrEmpty(String value) {
    return value.isEmpty ? emptyValueLabel : value;
  }
}

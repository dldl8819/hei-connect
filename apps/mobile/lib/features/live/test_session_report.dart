import 'field_test_mode.dart';

enum TestSessionReportRole {
  runner,
  guide,
}

extension TestSessionReportRoleLabel on TestSessionReportRole {
  String get label {
    return switch (this) {
      TestSessionReportRole.runner => '러너',
      TestSessionReportRole.guide => '가이드',
    };
  }
}

enum TestSessionReportStatus {
  ready,
  sensitiveInfoRequired,
  emptyInput,
}

extension TestSessionReportStatusLabel on TestSessionReportStatus {
  String get label {
    return switch (this) {
      TestSessionReportStatus.ready => '리포트 준비됨',
      TestSessionReportStatus.sensitiveInfoRequired => '민감정보 제거 필요',
      TestSessionReportStatus.emptyInput => '입력 없음',
    };
  }
}

class TestSessionReportRow {
  const TestSessionReportRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;
}

class TestSessionReport {
  const TestSessionReport({
    required this.role,
    required this.webRtcConnected,
    required this.guideFlowConfirmedCount,
    required this.guideFlowTotalCount,
    required this.aiVerificationChecked,
    required this.actualAiAnalysisChecked,
    required this.stopResumeConfirmed,
    required this.memo,
  });

  static const String purposeLabel = '러닝 가이드 실기기 테스트';
  static const String emptyValueLabel = '입력 없음';
  static const String protectedMemoLabel = '민감정보 제거 확인 필요';

  final TestSessionReportRole role;
  final bool webRtcConnected;
  final int guideFlowConfirmedCount;
  final int guideFlowTotalCount;
  final bool aiVerificationChecked;
  final bool actualAiAnalysisChecked;
  final bool stopResumeConfirmed;
  final FieldTestResultMemo memo;

  TestSessionReportStatus get status {
    if (memo.isEmpty) {
      return TestSessionReportStatus.emptyInput;
    }
    if (!memo.sensitiveInfoRemoved) {
      return TestSessionReportStatus.sensitiveInfoRequired;
    }
    return TestSessionReportStatus.ready;
  }

  bool get isReady => status == TestSessionReportStatus.ready;

  String get statusLabel => status.label;

  String get guideFlowLabel {
    if (guideFlowConfirmedCount == guideFlowTotalCount) {
      return '확인 완료 ($guideFlowConfirmedCount/$guideFlowTotalCount)';
    }
    return '$guideFlowConfirmedCount/$guideFlowTotalCount 확인';
  }

  String get connectionLabel => webRtcConnected ? '연결됨' : '미확인';

  String get aiVerificationLabel => aiVerificationChecked ? '확인됨' : '미확인';

  String get actualAiAnalysisLabel =>
      actualAiAnalysisChecked ? '정지 상태에서 확인됨' : '미확인';

  String get stopResumeLabel => stopResumeConfirmed ? '확인됨' : '미확인';

  String get talkBackSummary {
    return '테스트 세션 리포트. $statusLabel. 역할 ${role.label}. '
        '연결 상태 $connectionLabel. 가이드 흐름 $guideFlowLabel.';
  }

  List<TestSessionReportRow> get rows {
    return [
      TestSessionReportRow(label: '역할', value: role.label),
      const TestSessionReportRow(label: '테스트 목적', value: purposeLabel),
      TestSessionReportRow(label: '연결 상태', value: connectionLabel),
      TestSessionReportRow(label: '가이드 흐름', value: guideFlowLabel),
      TestSessionReportRow(label: 'AI 검증', value: aiVerificationLabel),
      TestSessionReportRow(label: '실제 AI 분석', value: actualAiAnalysisLabel),
      TestSessionReportRow(label: '정지/재개 확인', value: stopResumeLabel),
      TestSessionReportRow(
        label: '실패 단계',
        value: _safeMemoValue(memo.failureStep),
      ),
      TestSessionReportRow(
        label: '기대 결과',
        value: _safeMemoValue(memo.expectedResult),
      ),
      TestSessionReportRow(
        label: '실제 결과',
        value: _safeMemoValue(memo.actualResult),
      ),
      TestSessionReportRow(
        label: '재현 순서',
        value: _safeMemoValue(memo.reproductionSteps),
      ),
    ];
  }

  String _safeMemoValue(String value) {
    if (memo.isEmpty) {
      return emptyValueLabel;
    }
    if (!memo.sensitiveInfoRemoved) {
      return protectedMemoLabel;
    }
    return value.isEmpty ? emptyValueLabel : value;
  }
}

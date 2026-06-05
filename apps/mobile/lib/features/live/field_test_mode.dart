import 'guide_flow_checklist.dart';

class FieldTestModeStartGate {
  const FieldTestModeStartGate({
    required this.isRunningGuide,
    required this.isWorldCamera,
    required this.runnerModeSelected,
  });

  final bool isRunningGuide;
  final bool isWorldCamera;
  final bool runnerModeSelected;

  bool get canStart => isRunningGuide && isWorldCamera && runnerModeSelected;

  String get statusLabel {
    if (canStart) {
      return '현장 테스트 모드를 시작할 수 있습니다.';
    }
    if (!isRunningGuide) {
      return '방 종류에서 러닝 가이드를 선택해 주세요.';
    }
    if (!isWorldCamera) {
      return '방송 소스에서 눈앞 카메라를 선택해 주세요.';
    }
    return '러너 모드를 선택해 주세요.';
  }
}

class FieldTestModeSnapshot {
  const FieldTestModeSnapshot({
    required this.guideFlowState,
    required this.preRunChecklistComplete,
    required this.sessionCreated,
    required this.isLive,
    required this.webRtcConnected,
    required this.webRtcStatusLabel,
    required this.aiAssistStatusLabel,
    required this.aiAssistEnabled,
    required this.aiVerificationMode,
    required this.requiresResumeConfirmation,
    required this.lastSafetyCueLabel,
  });

  final GuideFlowChecklistState guideFlowState;
  final bool preRunChecklistComplete;
  final bool sessionCreated;
  final bool isLive;
  final bool webRtcConnected;
  final String webRtcStatusLabel;
  final String aiAssistStatusLabel;
  final bool aiAssistEnabled;
  final bool aiVerificationMode;
  final bool requiresResumeConfirmation;
  final String lastSafetyCueLabel;

  String get stageLabel {
    if (requiresResumeConfirmation) {
      return '재개 확인';
    }
    if (!preRunChecklistComplete) {
      return '사전 준비';
    }
    if (!sessionCreated || !isLive || !webRtcConnected) {
      return '라이브 연결';
    }
    if (!guideFlowState.allowsAiAssist) {
      return '가이드 흐름';
    }
    if (!aiAssistEnabled || aiVerificationMode) {
      return 'AI 검증';
    }
    return '실제 AI 분석';
  }

  String get nextActionTitle {
    if (requiresResumeConfirmation) {
      return '안전 확인 후 재개';
    }
    if (!preRunChecklistComplete) {
      return '러닝 전 안전 체크';
    }
    if (!sessionCreated) {
      return '라이브 세션 생성';
    }
    if (!isLive) {
      return '라이브 시작';
    }
    if (!webRtcConnected) {
      return '가이드 참여 후 신호 새로고침';
    }
    if (!guideFlowState.allowsAiAssist) {
      return guideFlowState.nextActionTitle;
    }
    if (!aiAssistEnabled) {
      return 'AI 보조 안내 켜기';
    }
    if (aiVerificationMode) {
      return '감속 큐와 정지 큐 테스트';
    }
    return '정지와 재개 흐름 확인';
  }

  String get nextActionDetail {
    if (requiresResumeConfirmation) {
      return '러너가 멈췄고 카메라와 오디오가 안정적일 때만 재개합니다.';
    }
    if (!preRunChecklistComplete) {
      return '통제 경로, 백업 동행자, 카메라 각도, 오디오를 먼저 확인합니다.';
    }
    if (!sessionCreated) {
      return '세션을 만든 뒤 가이드가 참여할 수 있습니다.';
    }
    if (!isLive) {
      return '러너가 정지한 상태에서 카메라와 마이크 권한을 허용합니다.';
    }
    if (!webRtcConnected) {
      return '가이드 기기에서 참여한 뒤 WebRTC가 연결됨으로 바뀌는지 확인합니다.';
    }
    if (!guideFlowState.allowsAiAssist) {
      return guideFlowState.nextActionDetail;
    }
    if (!aiAssistEnabled) {
      return '가이드 흐름 5개 항목 확인 후 AI 보조를 켭니다.';
    }
    if (aiVerificationMode) {
      return '검증 모드는 카메라 분석 없이 TTS와 일시정지 흐름만 확인합니다.';
    }
    return '연결 손실, 정지 cue, 안전 확인 후 재개가 예상대로 동작하는지 확인합니다.';
  }

  String get talkBackStatusLabel {
    return '현장 테스트 모드. 다음 조작은 $nextActionTitle. '
        '${guideFlowState.progressSemanticsLabel} '
        'AI 보조 상태는 $aiAssistStatusLabel. '
        'WebRTC 상태는 $webRtcStatusLabel.';
  }

  FieldTestModeSummary toSummary() {
    return FieldTestModeSummary(
      guideFlowConfirmedCount: guideFlowState.confirmedCount,
      guideFlowTotalCount: guideFlowState.totalCount,
      guideFlowStatusLabel: guideFlowState.statusLabel,
      aiAssistStatusLabel: aiAssistStatusLabel,
      webRtcStatusLabel: webRtcStatusLabel,
      requiresResumeConfirmation: requiresResumeConfirmation,
      lastSafetyCueLabel: lastSafetyCueLabel,
    );
  }
}

class FieldTestModeSummary {
  const FieldTestModeSummary({
    required this.guideFlowConfirmedCount,
    required this.guideFlowTotalCount,
    required this.guideFlowStatusLabel,
    required this.aiAssistStatusLabel,
    required this.webRtcStatusLabel,
    required this.requiresResumeConfirmation,
    required this.lastSafetyCueLabel,
  });

  final int guideFlowConfirmedCount;
  final int guideFlowTotalCount;
  final String guideFlowStatusLabel;
  final String aiAssistStatusLabel;
  final String webRtcStatusLabel;
  final bool requiresResumeConfirmation;
  final String lastSafetyCueLabel;

  String get resumeStatusLabel => requiresResumeConfirmation ? '필요' : '정상';

  List<FieldTestModeSummaryRow> get rows {
    return [
      FieldTestModeSummaryRow(
        label: '가이드 흐름',
        value:
            '$guideFlowStatusLabel ($guideFlowConfirmedCount/$guideFlowTotalCount)',
      ),
      FieldTestModeSummaryRow(label: 'AI 보조', value: aiAssistStatusLabel),
      FieldTestModeSummaryRow(label: 'WebRTC', value: webRtcStatusLabel),
      FieldTestModeSummaryRow(label: '재개 확인', value: resumeStatusLabel),
      FieldTestModeSummaryRow(label: '마지막 안전 cue', value: lastSafetyCueLabel),
    ];
  }
}

class FieldTestModeSummaryRow {
  const FieldTestModeSummaryRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;
}

enum FieldTestDeviceStepStatus {
  completed,
  current,
  pending,
}

extension FieldTestDeviceStepStatusLabel on FieldTestDeviceStepStatus {
  String get label {
    return switch (this) {
      FieldTestDeviceStepStatus.completed => '완료',
      FieldTestDeviceStepStatus.current => '현재',
      FieldTestDeviceStepStatus.pending => '대기',
    };
  }
}

class FieldTestDeviceTestStep {
  const FieldTestDeviceTestStep({
    required this.number,
    required this.title,
    required this.detail,
    required this.status,
  });

  final int number;
  final String title;
  final String detail;
  final FieldTestDeviceStepStatus status;

  String get semanticsLabel {
    return '$number단계 $title, ${status.label}. $detail';
  }
}

class FieldTestDeviceTestOrderState {
  const FieldTestDeviceTestOrderState({
    required this.isRunningGuide,
    required this.runnerModeSelected,
    required this.isWorldCamera,
    required this.preRunChecklistComplete,
    required this.sessionCreated,
    required this.isLive,
    required this.webRtcConnected,
    required this.guideFlowState,
    required this.aiVerificationChecked,
    required this.actualAiAnalysisChecked,
  });

  final bool isRunningGuide;
  final bool runnerModeSelected;
  final bool isWorldCamera;
  final bool preRunChecklistComplete;
  final bool sessionCreated;
  final bool isLive;
  final bool webRtcConnected;
  final GuideFlowChecklistState guideFlowState;
  final bool aiVerificationChecked;
  final bool actualAiAnalysisChecked;

  List<FieldTestDeviceTestStep> get steps {
    const titles = [
      '러닝 가이드 선택',
      '러너 모드 선택',
      '눈앞 카메라 선택',
      '러닝 전 안전 체크 완료',
      '라이브 세션 생성',
      '라이브 시작 및 권한 허용',
      '가이드 참여 및 WebRTC 연결',
      '가이드 흐름 5개 항목 확인',
      'AI 검증 모드 확인',
      '실제 AI 분석은 정지 상태에서만 확인',
    ];
    const details = [
      '방 종류를 러닝 가이드로 맞춥니다.',
      '비시각장애러너, 저시력자, 전맹 중 테스트 대상 모드를 맞춥니다.',
      '방송 소스를 눈앞 카메라로 맞춥니다.',
      '통제 경로와 백업 동행자 기준을 먼저 확인합니다.',
      '세션을 만든 뒤 다음 단계로 갑니다.',
      '러너가 정지한 상태에서 카메라와 마이크 권한을 허용합니다.',
      '가이드가 참여하고 WebRTC 상태가 연결됨인지 확인합니다.',
      '영상, 음성, cue, 채팅 TTS, 정지 후 재개를 모두 확인합니다.',
      '검증 모드에서 감속 큐와 정지 큐 흐름을 확인합니다.',
      '러너가 정지한 상태에서만 지금 분석을 눌러 확인합니다.',
    ];
    final completedFlags = [
      isRunningGuide,
      runnerModeSelected,
      isWorldCamera,
      preRunChecklistComplete,
      sessionCreated,
      isLive,
      webRtcConnected,
      guideFlowState.allowsAiAssist,
      aiVerificationChecked,
      actualAiAnalysisChecked,
    ];

    final result = <FieldTestDeviceTestStep>[];
    var currentAssigned = false;
    for (var index = 0; index < titles.length; index += 1) {
      final status = currentAssigned
          ? FieldTestDeviceStepStatus.pending
          : completedFlags[index]
              ? FieldTestDeviceStepStatus.completed
              : FieldTestDeviceStepStatus.current;
      if (status == FieldTestDeviceStepStatus.current) {
        currentAssigned = true;
      }
      result.add(
        FieldTestDeviceTestStep(
          number: index + 1,
          title: titles[index],
          detail: details[index],
          status: status,
        ),
      );
    }
    return List<FieldTestDeviceTestStep>.unmodifiable(result);
  }

  int get completedCount {
    return steps
        .where((step) => step.status == FieldTestDeviceStepStatus.completed)
        .length;
  }

  bool get isComplete => completedCount == steps.length;

  FieldTestDeviceTestStep get currentStep {
    return steps.firstWhere(
      (step) => step.status == FieldTestDeviceStepStatus.current,
      orElse: () => steps.last,
    );
  }

  String get progressLabel => '$completedCount/${steps.length} 완료';

  String get talkBackSummary {
    if (isComplete) {
      return '실기기 테스트 순서. 모든 단계 완료. 통제 경로와 백업 동행자 기준을 계속 유지합니다.';
    }
    return '실기기 테스트 순서. $progressLabel. 현재 단계는 '
        '${currentStep.number}단계 ${currentStep.title}. ${currentStep.detail}';
  }
}

class FieldTestResultMemo {
  const FieldTestResultMemo._({
    required this.failureStep,
    required this.expectedResult,
    required this.actualResult,
    required this.reproductionSteps,
    required this.sensitiveInfoRemoved,
    required this.hasTruncatedInput,
  });

  static const int maxFieldLength = 240;

  factory FieldTestResultMemo.fromInput({
    String failureStep = '',
    String expectedResult = '',
    String actualResult = '',
    String reproductionSteps = '',
    bool sensitiveInfoRemoved = false,
  }) {
    final fields = [
      failureStep,
      expectedResult,
      actualResult,
      reproductionSteps,
    ];
    return FieldTestResultMemo._(
      failureStep: _normalize(failureStep),
      expectedResult: _normalize(expectedResult),
      actualResult: _normalize(actualResult),
      reproductionSteps: _normalize(reproductionSteps),
      sensitiveInfoRemoved: sensitiveInfoRemoved,
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

  final String failureStep;
  final String expectedResult;
  final String actualResult;
  final String reproductionSteps;
  final bool sensitiveInfoRemoved;
  final bool hasTruncatedInput;

  bool get isEmpty {
    return failureStep.isEmpty &&
        expectedResult.isEmpty &&
        actualResult.isEmpty &&
        reproductionSteps.isEmpty;
  }

  bool get isReadyForLocalReview => !isEmpty && sensitiveInfoRemoved;

  String get safetyStatusLabel {
    if (sensitiveInfoRemoved) {
      return '민감정보 제거 확인 완료';
    }
    return '민감정보 제거 확인 필요';
  }

  String? get lengthNotice {
    if (!hasTruncatedInput) {
      return null;
    }
    return '긴 입력은 항목당 $maxFieldLength자까지만 화면에 보관합니다.';
  }

  List<FieldTestModeSummaryRow> get rows {
    return [
      FieldTestModeSummaryRow(label: '실패 단계', value: failureStep),
      FieldTestModeSummaryRow(label: '기대 결과', value: expectedResult),
      FieldTestModeSummaryRow(label: '실제 결과', value: actualResult),
      FieldTestModeSummaryRow(label: '재현 순서', value: reproductionSteps),
      FieldTestModeSummaryRow(label: '민감정보 제거', value: safetyStatusLabel),
    ];
  }
}

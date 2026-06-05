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

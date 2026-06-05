class TestProgressGuardDecision {
  const TestProgressGuardDecision({
    required this.label,
    required this.allowed,
    required this.reason,
  });

  final String label;
  final bool allowed;
  final String reason;

  String get statusLabel => allowed ? '가능' : '차단';

  String get semanticsLabel => '$label, $statusLabel. $reason';
}

class RunnerTestProgressGuardState {
  const RunnerTestProgressGuardState({
    required this.isLive,
    required this.webRtcConnected,
    required this.guideFlowComplete,
    required this.aiVerificationChecked,
    required this.reportReady,
  });

  final bool isLive;
  final bool webRtcConnected;
  final bool guideFlowComplete;
  final bool aiVerificationChecked;
  final bool reportReady;

  bool get liveConnected => isLive && webRtcConnected;

  TestProgressGuardDecision get guideFlow {
    if (liveConnected) {
      return const TestProgressGuardDecision(
        label: '가이드 흐름 체크',
        allowed: true,
        reason: '라이브와 WebRTC 연결이 확인됐습니다.',
      );
    }
    return const TestProgressGuardDecision(
      label: '가이드 흐름 체크',
      allowed: false,
      reason: '라이브 시작과 WebRTC 연결 후 러너가 정지한 상태에서 확인합니다.',
    );
  }

  TestProgressGuardDecision get aiVerification {
    if (guideFlowComplete) {
      return const TestProgressGuardDecision(
        label: 'AI 검증 모드',
        allowed: true,
        reason: '가이드 흐름 5개 항목이 완료됐습니다.',
      );
    }
    return const TestProgressGuardDecision(
      label: 'AI 검증 모드',
      allowed: false,
      reason: 'WebRTC 영상, 가이드 음성, cue 버튼, 채팅 TTS, 정지/재개를 먼저 확인합니다.',
    );
  }

  TestProgressGuardDecision get actualAiAnalysis {
    if (aiVerificationChecked) {
      return const TestProgressGuardDecision(
        label: '실제 AI 분석',
        allowed: true,
        reason: 'AI 검증 모드 확인 후 정지 상태에서만 진행합니다.',
      );
    }
    return const TestProgressGuardDecision(
      label: '실제 AI 분석',
      allowed: false,
      reason: 'AI 검증 모드에서 감속 cue와 정지 cue를 먼저 확인하고 정지 상태에서만 확인합니다.',
    );
  }

  TestProgressGuardDecision get report {
    if (reportReady) {
      return const TestProgressGuardDecision(
        label: '리포트 준비',
        allowed: true,
        reason: '메모 입력과 민감정보 제거 확인이 완료됐습니다.',
      );
    }
    return const TestProgressGuardDecision(
      label: '리포트 준비',
      allowed: false,
      reason: '메모가 비어 있거나 민감정보 제거 확인이 필요합니다.',
    );
  }

  List<TestProgressGuardDecision> get decisions {
    return [guideFlow, aiVerification, actualAiAnalysis, report];
  }

  String get talkBackSummary {
    final blocked = decisions.where((decision) => !decision.allowed).toList();
    if (blocked.isEmpty) {
      return '테스트 진행 가드. 모든 진행 조건이 충족됐습니다.';
    }
    final next = blocked.first;
    return '테스트 진행 가드. ${next.label} 차단. ${next.reason}';
  }
}

class GuideTestProgressGuardState {
  const GuideTestProgressGuardState({
    required this.webRtcConnected,
    required this.connectionLost,
    required this.stopCueAwaitingResume,
  });

  final bool webRtcConnected;
  final bool connectionLost;
  final bool stopCueAwaitingResume;

  TestProgressGuardDecision get guideFlow {
    if (connectionLost) {
      return const TestProgressGuardDecision(
        label: '가이드 흐름 체크',
        allowed: false,
        reason: '연결 끊김 상태입니다. 먼저 정지와 백업 기준을 확인합니다.',
      );
    }
    if (webRtcConnected) {
      return const TestProgressGuardDecision(
        label: '가이드 흐름 체크',
        allowed: true,
        reason: 'WebRTC 연결이 확인됐습니다.',
      );
    }
    return const TestProgressGuardDecision(
      label: '가이드 흐름 체크',
      allowed: false,
      reason: '방송 연결 후 WebRTC가 연결됨으로 바뀐 뒤 확인합니다.',
    );
  }

  TestProgressGuardDecision get resumeConfirmation {
    if (connectionLost) {
      return const TestProgressGuardDecision(
        label: '재개 확인',
        allowed: false,
        reason: '연결 끊김 상태에서는 재개하지 않고 정지와 백업 기준을 먼저 확인합니다.',
      );
    }
    if (stopCueAwaitingResume) {
      return const TestProgressGuardDecision(
        label: '재개 확인',
        allowed: true,
        reason: '러너가 멈췄고 카메라와 오디오가 안정적인지 확인합니다.',
      );
    }
    return const TestProgressGuardDecision(
      label: '재개 확인',
      allowed: false,
      reason: '정지 cue 이후에만 재개 확인을 표시합니다.',
    );
  }

  TestProgressGuardDecision get holdPaceGuidance {
    if (stopCueAwaitingResume || connectionLost) {
      return const TestProgressGuardDecision(
        label: '유지 안내',
        allowed: false,
        reason: '정지 후 확인 중에는 유지나 재개 관련 행동을 서두르지 않습니다.',
      );
    }
    return const TestProgressGuardDecision(
      label: '유지 안내',
      allowed: true,
      reason: '연결이 안정적일 때만 짧고 명확하게 안내합니다.',
    );
  }

  List<TestProgressGuardDecision> get decisions {
    return [guideFlow, resumeConfirmation, holdPaceGuidance];
  }

  String get talkBackSummary {
    final blocked = decisions.where((decision) => !decision.allowed).toList();
    if (blocked.isEmpty) {
      return '테스트 진행 가드. 모든 가이드 진행 조건이 충족됐습니다.';
    }
    final next = blocked.first;
    return '테스트 진행 가드. ${next.label} 차단. ${next.reason}';
  }
}

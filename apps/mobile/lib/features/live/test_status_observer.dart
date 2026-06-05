import 'guide_flow_checklist.dart';

enum TestStatusObserverLevel {
  ready,
  pending,
  warning,
  blocked,
}

extension TestStatusObserverLevelLabel on TestStatusObserverLevel {
  String get label {
    return switch (this) {
      TestStatusObserverLevel.ready => '준비',
      TestStatusObserverLevel.pending => '대기',
      TestStatusObserverLevel.warning => '주의',
      TestStatusObserverLevel.blocked => '차단',
    };
  }
}

class TestStatusObserverItem {
  const TestStatusObserverItem({
    required this.label,
    required this.value,
    required this.detail,
    required this.level,
  });

  final String label;
  final String value;
  final String detail;
  final TestStatusObserverLevel level;

  String get semanticsLabel => '$label, ${level.label}, $value. $detail';
}

abstract class TestStatusObserverState {
  const TestStatusObserverState();

  List<TestStatusObserverItem> get items;

  TestStatusObserverItem get primaryItem {
    for (final item in items) {
      if (item.level == TestStatusObserverLevel.blocked) {
        return item;
      }
    }
    for (final item in items) {
      if (item.level == TestStatusObserverLevel.warning) {
        return item;
      }
    }
    for (final item in items) {
      if (item.level == TestStatusObserverLevel.pending) {
        return item;
      }
    }
    return items.first;
  }

  String get talkBackSummary {
    final item = primaryItem;
    return '테스트 상태 관찰. ${item.label}, ${item.value}. ${item.detail}';
  }

  String get renderedText {
    return [
      talkBackSummary,
      for (final item in items) item.semanticsLabel,
    ].join('\n');
  }
}

class RunnerTestStatusObserverState extends TestStatusObserverState {
  const RunnerTestStatusObserverState({
    required this.isLive,
    required this.webRtcConnected,
    required this.connectionLost,
    required this.mediaPermissionsReady,
    required this.guideFlowState,
    required this.aiVerificationMode,
    required this.aiVerificationChecked,
    required this.actualAiAnalysisAvailable,
    required this.requiresResumeConfirmation,
  });

  final bool isLive;
  final bool webRtcConnected;
  final bool connectionLost;
  final bool mediaPermissionsReady;
  final GuideFlowChecklistState guideFlowState;
  final bool aiVerificationMode;
  final bool aiVerificationChecked;
  final bool actualAiAnalysisAvailable;
  final bool requiresResumeConfirmation;

  TestStatusObserverItem get live {
    if (connectionLost) {
      return const TestStatusObserverItem(
        label: '라이브 상태',
        value: '정지 우선',
        detail: '연결 끊김이 감지되면 재개보다 정지와 백업 기준을 먼저 확인합니다.',
        level: TestStatusObserverLevel.blocked,
      );
    }
    if (isLive) {
      return const TestStatusObserverItem(
        label: '라이브 상태',
        value: '라이브 중',
        detail: '제어된 코스와 백업 보호자 기준으로만 테스트합니다.',
        level: TestStatusObserverLevel.ready,
      );
    }
    return const TestStatusObserverItem(
      label: '라이브 상태',
      value: '라이브 대기',
      detail: '러너가 정지한 상태에서 카메라와 마이크 권한을 확인한 뒤 시작합니다.',
      level: TestStatusObserverLevel.pending,
    );
  }

  TestStatusObserverItem get webRtc {
    if (connectionLost) {
      return const TestStatusObserverItem(
        label: 'WebRTC',
        value: '연결 끊김',
        detail: '재개보다 정지와 백업 기준을 먼저 확인합니다.',
        level: TestStatusObserverLevel.blocked,
      );
    }
    if (webRtcConnected) {
      return const TestStatusObserverItem(
        label: 'WebRTC',
        value: '연결됨',
        detail: '영상과 음성 연결을 가이드 흐름 체크로 확인합니다.',
        level: TestStatusObserverLevel.ready,
      );
    }
    return const TestStatusObserverItem(
      label: 'WebRTC',
      value: '연결 대기',
      detail: '가이드 참여와 WebRTC 연결 완료 전에는 AI 보조를 진행하지 않습니다.',
      level: TestStatusObserverLevel.pending,
    );
  }

  TestStatusObserverItem get mediaPermissions {
    if (mediaPermissionsReady) {
      return const TestStatusObserverItem(
        label: '카메라/마이크',
        value: '준비됨',
        detail: '권한 요청이 통과한 상태입니다.',
        level: TestStatusObserverLevel.ready,
      );
    }
    return const TestStatusObserverItem(
      label: '카메라/마이크',
      value: '권한 대기',
      detail: '정지 상태에서 권한 요청을 완료한 뒤 테스트합니다.',
      level: TestStatusObserverLevel.pending,
    );
  }

  TestStatusObserverItem get guideFlow {
    if (connectionLost) {
      return const TestStatusObserverItem(
        label: '가이드 흐름',
        value: '차단',
        detail: '연결 끊김 상태에서는 가이드 흐름보다 정지와 백업 기준을 먼저 확인합니다.',
        level: TestStatusObserverLevel.blocked,
      );
    }
    if (!webRtcConnected) {
      return const TestStatusObserverItem(
        label: '가이드 흐름',
        value: '연결 대기',
        detail: 'WebRTC 연결 후 영상, 음성, cue, 채팅 TTS, 정지/재개를 확인합니다.',
        level: TestStatusObserverLevel.blocked,
      );
    }
    if (guideFlowState.isComplete) {
      return const TestStatusObserverItem(
        label: '가이드 흐름',
        value: '5/5 확인',
        detail: 'AI 검증 모드로 넘어갈 수 있습니다.',
        level: TestStatusObserverLevel.ready,
      );
    }
    return TestStatusObserverItem(
      label: '가이드 흐름',
      value: guideFlowState.statusLabel,
      detail: 'AI 보조 전에 5개 항목을 모두 확인합니다.',
      level: TestStatusObserverLevel.pending,
    );
  }

  TestStatusObserverItem get aiVerification {
    if (!guideFlowState.isComplete) {
      return const TestStatusObserverItem(
        label: 'AI 검증',
        value: '차단',
        detail: '가이드 흐름 5개 항목 완료 전에는 AI 검증 모드를 진행하지 않습니다.',
        level: TestStatusObserverLevel.blocked,
      );
    }
    if (aiVerificationChecked) {
      return const TestStatusObserverItem(
        label: 'AI 검증',
        value: '완료',
        detail: '감속 cue와 정지 cue 흐름이 확인됐습니다.',
        level: TestStatusObserverLevel.ready,
      );
    }
    if (aiVerificationMode) {
      return const TestStatusObserverItem(
        label: 'AI 검증',
        value: '검증 중',
        detail: '카메라 분석 없이 감속 cue와 정지 cue를 순서대로 확인합니다.',
        level: TestStatusObserverLevel.warning,
      );
    }
    return const TestStatusObserverItem(
      label: 'AI 검증',
      value: '대기',
      detail: '실제 AI 분석 전에 검증 모드를 먼저 실행합니다.',
      level: TestStatusObserverLevel.pending,
    );
  }

  TestStatusObserverItem get actualAiAnalysis {
    if (!guideFlowState.isComplete) {
      return const TestStatusObserverItem(
        label: '실제 AI 분석',
        value: '차단',
        detail: '가이드 흐름 확인 전에는 실제 AI 분석을 진행하지 않습니다.',
        level: TestStatusObserverLevel.blocked,
      );
    }
    if (!aiVerificationChecked) {
      return const TestStatusObserverItem(
        label: '실제 AI 분석',
        value: '차단',
        detail: 'AI 검증 완료 전에는 실제 AI 분석을 진행하지 않습니다.',
        level: TestStatusObserverLevel.blocked,
      );
    }
    if (actualAiAnalysisAvailable) {
      return const TestStatusObserverItem(
        label: '실제 AI 분석',
        value: '가능',
        detail: '러너가 정지한 상태에서만 통제된 테스트 물체로 확인합니다.',
        level: TestStatusObserverLevel.ready,
      );
    }
    return const TestStatusObserverItem(
      label: '실제 AI 분석',
      value: '대기',
      detail: '정지 상태와 검증 결과를 다시 확인합니다.',
      level: TestStatusObserverLevel.pending,
    );
  }

  TestStatusObserverItem get resumeConfirmation {
    if (requiresResumeConfirmation) {
      return const TestStatusObserverItem(
        label: '정지 후 재개',
        value: '확인 필요',
        detail: '정지 후 카메라와 오디오가 안정적인지 확인하기 전에는 재개하지 않습니다.',
        level: TestStatusObserverLevel.warning,
      );
    }
    return const TestStatusObserverItem(
      label: '정지 후 재개',
      value: '정상',
      detail: '재개 확인 대기 상태가 아닙니다.',
      level: TestStatusObserverLevel.ready,
    );
  }

  TestStatusObserverItem get backupCriteria {
    if (connectionLost) {
      return const TestStatusObserverItem(
        label: '백업 기준',
        value: '필요',
        detail: '연결 끊김 상태입니다. 재개보다 정지와 백업 기준을 먼저 확인합니다.',
        level: TestStatusObserverLevel.blocked,
      );
    }
    if (requiresResumeConfirmation) {
      return const TestStatusObserverItem(
        label: '백업 기준',
        value: '확인 중',
        detail: '정지 상태에서 백업 보호자 기준을 유지합니다.',
        level: TestStatusObserverLevel.warning,
      );
    }
    return const TestStatusObserverItem(
      label: '백업 기준',
      value: '유지',
      detail: '제어된 코스와 백업 보호자 기준을 유지합니다.',
      level: TestStatusObserverLevel.ready,
    );
  }

  @override
  List<TestStatusObserverItem> get items {
    return [
      live,
      webRtc,
      mediaPermissions,
      guideFlow,
      aiVerification,
      actualAiAnalysis,
      resumeConfirmation,
      backupCriteria,
    ];
  }
}

class GuideTestStatusObserverState extends TestStatusObserverState {
  const GuideTestStatusObserverState({
    required this.sessionJoined,
    required this.webRtcConnected,
    required this.connectionLost,
    required this.mediaPermissionsReady,
    required this.guideFlowState,
    required this.aiVerificationChecked,
    required this.actualAiAnalysisChecked,
    required this.stopCueAwaitingResume,
  });

  final bool sessionJoined;
  final bool webRtcConnected;
  final bool connectionLost;
  final bool mediaPermissionsReady;
  final GuideFlowChecklistState guideFlowState;
  final bool aiVerificationChecked;
  final bool actualAiAnalysisChecked;
  final bool stopCueAwaitingResume;

  TestStatusObserverItem get live {
    if (sessionJoined) {
      return const TestStatusObserverItem(
        label: '라이브 상태',
        value: '참여 중',
        detail: '가이드는 제어된 코스와 백업 보호자 기준으로만 안내합니다.',
        level: TestStatusObserverLevel.ready,
      );
    }
    return const TestStatusObserverItem(
      label: '라이브 상태',
      value: '참여 대기',
      detail: '세션 참여 후 권한과 WebRTC 연결을 확인합니다.',
      level: TestStatusObserverLevel.pending,
    );
  }

  TestStatusObserverItem get webRtc {
    if (connectionLost) {
      return const TestStatusObserverItem(
        label: 'WebRTC',
        value: '연결 끊김',
        detail: '재개보다 정지와 백업 기준을 먼저 안내합니다.',
        level: TestStatusObserverLevel.blocked,
      );
    }
    if (webRtcConnected) {
      return const TestStatusObserverItem(
        label: 'WebRTC',
        value: '연결됨',
        detail: '러너 화면과 오디오를 기준으로 가이드 흐름을 확인합니다.',
        level: TestStatusObserverLevel.ready,
      );
    }
    return const TestStatusObserverItem(
      label: 'WebRTC',
      value: '연결 대기',
      detail: 'WebRTC 연결 전에는 가이드 흐름 체크와 AI 확인을 진행하지 않습니다.',
      level: TestStatusObserverLevel.pending,
    );
  }

  TestStatusObserverItem get mediaPermissions {
    if (mediaPermissionsReady) {
      return const TestStatusObserverItem(
        label: '카메라/마이크',
        value: '준비됨',
        detail: '가이드 연결에 필요한 권한 흐름이 통과했습니다.',
        level: TestStatusObserverLevel.ready,
      );
    }
    return const TestStatusObserverItem(
      label: '카메라/마이크',
      value: '권한 대기',
      detail: '방송 연결 중 권한 요청을 완료한 뒤 확인합니다.',
      level: TestStatusObserverLevel.pending,
    );
  }

  TestStatusObserverItem get guideFlow {
    if (connectionLost) {
      return const TestStatusObserverItem(
        label: '가이드 흐름',
        value: '차단',
        detail: '연결 끊김 상태에서는 정지와 백업 기준을 먼저 안내합니다.',
        level: TestStatusObserverLevel.blocked,
      );
    }
    if (!webRtcConnected) {
      return const TestStatusObserverItem(
        label: '가이드 흐름',
        value: '연결 대기',
        detail: 'WebRTC 연결됨 상태로 바뀐 뒤 영상, 음성, cue, 채팅 TTS, 정지/재개를 확인합니다.',
        level: TestStatusObserverLevel.blocked,
      );
    }
    if (guideFlowState.isComplete) {
      return const TestStatusObserverItem(
        label: '가이드 흐름',
        value: '5/5 확인',
        detail: '러너 화면의 AI 검증 상태를 확인할 수 있습니다.',
        level: TestStatusObserverLevel.ready,
      );
    }
    return TestStatusObserverItem(
      label: '가이드 흐름',
      value: guideFlowState.statusLabel,
      detail: '5개 항목이 실제로 확인된 뒤에만 다음 단계로 넘어갑니다.',
      level: TestStatusObserverLevel.pending,
    );
  }

  TestStatusObserverItem get aiVerification {
    if (!guideFlowState.isComplete) {
      return const TestStatusObserverItem(
        label: 'AI 검증',
        value: '차단',
        detail: '가이드 흐름 5개 항목 완료 전에는 AI 검증 결과를 완료로 보지 않습니다.',
        level: TestStatusObserverLevel.blocked,
      );
    }
    if (aiVerificationChecked) {
      return const TestStatusObserverItem(
        label: 'AI 검증',
        value: '완료',
        detail: '러너 화면의 검증 모드 흐름이 확인됐습니다.',
        level: TestStatusObserverLevel.ready,
      );
    }
    return const TestStatusObserverItem(
      label: 'AI 검증',
      value: '러너 화면 확인 필요',
      detail: '러너 화면에서 검증 모드의 감속 cue와 정지 cue를 확인합니다.',
      level: TestStatusObserverLevel.pending,
    );
  }

  TestStatusObserverItem get actualAiAnalysis {
    if (!guideFlowState.isComplete) {
      return const TestStatusObserverItem(
        label: '실제 AI 분석',
        value: '차단',
        detail: '가이드 흐름 확인 전에는 실제 AI 분석을 진행하지 않습니다.',
        level: TestStatusObserverLevel.blocked,
      );
    }
    if (!aiVerificationChecked) {
      return const TestStatusObserverItem(
        label: '실제 AI 분석',
        value: '차단',
        detail: 'AI 검증 완료 전에는 실제 AI 분석을 진행하지 않습니다.',
        level: TestStatusObserverLevel.blocked,
      );
    }
    if (actualAiAnalysisChecked) {
      return const TestStatusObserverItem(
        label: '실제 AI 분석',
        value: '확인됨',
        detail: '정지 상태에서 실제 AI 분석 확인이 완료됐습니다.',
        level: TestStatusObserverLevel.ready,
      );
    }
    return const TestStatusObserverItem(
      label: '실제 AI 분석',
      value: '정지 상태 확인 필요',
      detail: '러너가 정지한 상태에서만 실제 AI 분석을 확인합니다.',
      level: TestStatusObserverLevel.warning,
    );
  }

  TestStatusObserverItem get resumeConfirmation {
    if (connectionLost) {
      return const TestStatusObserverItem(
        label: '정지 후 재개',
        value: '차단',
        detail: '연결 끊김 상태에서는 재개보다 정지와 백업 기준을 먼저 안내합니다.',
        level: TestStatusObserverLevel.blocked,
      );
    }
    if (stopCueAwaitingResume) {
      return const TestStatusObserverItem(
        label: '정지 후 재개',
        value: '확인 필요',
        detail: '러너가 멈췄고 카메라와 오디오가 안정적인지 확인합니다.',
        level: TestStatusObserverLevel.warning,
      );
    }
    return const TestStatusObserverItem(
      label: '정지 후 재개',
      value: '정상',
      detail: '정지 cue 이후 재개 확인 대기 상태가 아닙니다.',
      level: TestStatusObserverLevel.ready,
    );
  }

  TestStatusObserverItem get backupCriteria {
    if (connectionLost) {
      return const TestStatusObserverItem(
        label: '백업 기준',
        value: '필요',
        detail: '연결 끊김 상태입니다. 재개보다 정지와 백업 기준을 먼저 안내합니다.',
        level: TestStatusObserverLevel.blocked,
      );
    }
    if (stopCueAwaitingResume) {
      return const TestStatusObserverItem(
        label: '백업 기준',
        value: '확인 중',
        detail: '정지 상태에서 백업 보호자 기준을 유지합니다.',
        level: TestStatusObserverLevel.warning,
      );
    }
    return const TestStatusObserverItem(
      label: '백업 기준',
      value: '유지',
      detail: '제어된 코스와 백업 보호자 기준을 유지합니다.',
      level: TestStatusObserverLevel.ready,
    );
  }

  @override
  List<TestStatusObserverItem> get items {
    return [
      live,
      webRtc,
      mediaPermissions,
      guideFlow,
      aiVerification,
      actualAiAnalysis,
      resumeConfirmation,
      backupCriteria,
    ];
  }
}

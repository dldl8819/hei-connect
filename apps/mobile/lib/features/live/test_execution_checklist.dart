enum TestExecutionChecklistItem {
  controlledRoute,
  backupPerson,
  battery,
  network,
  audioOutput,
  cameraLens,
  permissions,
  sessionCreated,
  guideJoined,
  webRtcConnected,
  videoAudioConfirmed,
  slowDownCue,
  holdPaceCue,
  stopCue,
  shortChatTts,
  stopResumeConfirmed,
  aiVerificationMode,
  stationaryAiAnalysis,
  reportStatus,
  sensitiveInfoRemoved,
  nextTestDecision,
}

extension TestExecutionChecklistItemText on TestExecutionChecklistItem {
  String get categoryLabel {
    return switch (this) {
      TestExecutionChecklistItem.controlledRoute ||
      TestExecutionChecklistItem.backupPerson ||
      TestExecutionChecklistItem.battery ||
      TestExecutionChecklistItem.network ||
      TestExecutionChecklistItem.audioOutput ||
      TestExecutionChecklistItem.cameraLens ||
      TestExecutionChecklistItem.permissions =>
        '테스트 전',
      TestExecutionChecklistItem.sessionCreated ||
      TestExecutionChecklistItem.guideJoined ||
      TestExecutionChecklistItem.webRtcConnected ||
      TestExecutionChecklistItem.videoAudioConfirmed =>
        '연결',
      TestExecutionChecklistItem.slowDownCue ||
      TestExecutionChecklistItem.holdPaceCue ||
      TestExecutionChecklistItem.stopCue ||
      TestExecutionChecklistItem.shortChatTts ||
      TestExecutionChecklistItem.stopResumeConfirmed =>
        '안내',
      TestExecutionChecklistItem.aiVerificationMode ||
      TestExecutionChecklistItem.stationaryAiAnalysis =>
        'AI',
      TestExecutionChecklistItem.reportStatus ||
      TestExecutionChecklistItem.sensitiveInfoRemoved ||
      TestExecutionChecklistItem.nextTestDecision =>
        '종료',
    };
  }

  String get label {
    return switch (this) {
      TestExecutionChecklistItem.controlledRoute => '통제 경로 확인',
      TestExecutionChecklistItem.backupPerson => '백업 동행자 확인',
      TestExecutionChecklistItem.battery => '배터리 확인',
      TestExecutionChecklistItem.network => '네트워크 확인',
      TestExecutionChecklistItem.audioOutput => '오디오 출력 확인',
      TestExecutionChecklistItem.cameraLens => '카메라 렌즈 확인',
      TestExecutionChecklistItem.permissions => '카메라와 마이크 권한 확인',
      TestExecutionChecklistItem.sessionCreated => '세션 생성 확인',
      TestExecutionChecklistItem.guideJoined => '가이드 입장 확인',
      TestExecutionChecklistItem.webRtcConnected => 'WebRTC 연결 확인',
      TestExecutionChecklistItem.videoAudioConfirmed => '영상과 음성 확인',
      TestExecutionChecklistItem.slowDownCue => '감속 cue 확인',
      TestExecutionChecklistItem.holdPaceCue => '유지 cue 확인',
      TestExecutionChecklistItem.stopCue => '정지 cue 확인',
      TestExecutionChecklistItem.shortChatTts => '짧은 채팅 TTS 확인',
      TestExecutionChecklistItem.stopResumeConfirmed => '정지 후 재개 확인',
      TestExecutionChecklistItem.aiVerificationMode => 'AI 검증 모드 확인',
      TestExecutionChecklistItem.stationaryAiAnalysis => '정지 상태 실제 AI 분석 확인',
      TestExecutionChecklistItem.reportStatus => '리포트 상태 확인',
      TestExecutionChecklistItem.sensitiveInfoRemoved => '민감정보 제거 확인',
      TestExecutionChecklistItem.nextTestDecision => '다음 테스트 진행 판단',
    };
  }

  String get detail {
    return switch (this) {
      TestExecutionChecklistItem.controlledRoute => '통제 가능한 경로 기준으로 테스트합니다.',
      TestExecutionChecklistItem.backupPerson => '비상 대응할 백업 동행자 기준을 확인합니다.',
      TestExecutionChecklistItem.battery => '러너와 가이드 기기 배터리가 충분한지 확인합니다.',
      TestExecutionChecklistItem.network => '모바일 데이터 또는 Wi-Fi 연결이 안정적인지 확인합니다.',
      TestExecutionChecklistItem.audioOutput =>
        '주변 소리를 들을 수 있는 오디오 출력으로 확인합니다.',
      TestExecutionChecklistItem.cameraLens => '눈앞 카메라 렌즈가 가려지지 않았는지 확인합니다.',
      TestExecutionChecklistItem.permissions => '정지 상태에서 카메라와 마이크 권한을 허용합니다.',
      TestExecutionChecklistItem.sessionCreated => '러너 화면에서 테스트 세션을 만듭니다.',
      TestExecutionChecklistItem.guideJoined => '가이드 화면에서 현재 세션에 입장합니다.',
      TestExecutionChecklistItem.webRtcConnected =>
        '양쪽 화면에서 WebRTC가 연결됨인지 확인합니다.',
      TestExecutionChecklistItem.videoAudioConfirmed =>
        '가이드가 영상과 음성을 확인하고 러너가 안내를 들을 수 있는지 확인합니다.',
      TestExecutionChecklistItem.slowDownCue => '감속 cue가 러너에게 안내되는지 확인합니다.',
      TestExecutionChecklistItem.holdPaceCue => '유지 cue가 러너에게 안내되는지 확인합니다.',
      TestExecutionChecklistItem.stopCue => '정지 cue 뒤 러너가 먼저 멈추는지 확인합니다.',
      TestExecutionChecklistItem.shortChatTts =>
        '말하기 어려운 가이드가 짧은 메시지를 보냈을 때 TTS가 들리는지 확인합니다.',
      TestExecutionChecklistItem.stopResumeConfirmed =>
        '정지 후 카메라와 오디오를 확인한 뒤에만 재개합니다.',
      TestExecutionChecklistItem.aiVerificationMode =>
        '카메라 분석 없이 검증 모드에서 cue 흐름을 확인합니다.',
      TestExecutionChecklistItem.stationaryAiAnalysis =>
        '러너가 정지한 상태에서만 실제 AI 분석을 확인합니다.',
      TestExecutionChecklistItem.reportStatus => '로컬 테스트 세션 리포트 상태를 확인합니다.',
      TestExecutionChecklistItem.sensitiveInfoRemoved =>
        '메모에 민감정보를 적지 않았는지 확인합니다.',
      TestExecutionChecklistItem.nextTestDecision =>
        '결과를 보고 다음 테스트로 넘어갈지 판단합니다.',
    };
  }

  String checkedSemanticsLabel(bool checked) {
    return '$categoryLabel, $label, ${checked ? '완료' : '미완료'}. $detail';
  }
}

class TestExecutionChecklistState {
  TestExecutionChecklistState(
      [Iterable<TestExecutionChecklistItem> completedItems = const []])
      : completedItems = Set<TestExecutionChecklistItem>.unmodifiable(
          completedItems,
        );

  static const items = TestExecutionChecklistItem.values;

  final Set<TestExecutionChecklistItem> completedItems;

  int get completedCount => completedItems.length;

  int get totalCount => items.length;

  bool get isComplete => completedCount == totalCount;

  TestExecutionChecklistItem? get nextItem {
    for (final item in items) {
      if (!completedItems.contains(item)) {
        return item;
      }
    }
    return null;
  }

  String get progressLabel => '$totalCount개 중 $completedCount개 완료';

  String get progressSemanticsLabel {
    final next = nextItem;
    if (next == null) {
      return '$totalCount개 중 $completedCount개 완료. 모든 테스트 실행 항목을 완료했습니다.';
    }
    return '$totalCount개 중 $completedCount개 완료. 다음 항목은 ${next.label}입니다. ${next.detail}';
  }

  bool contains(TestExecutionChecklistItem item) {
    return completedItems.contains(item);
  }

  TestExecutionChecklistState updateItem(
    TestExecutionChecklistItem item,
    bool checked,
  ) {
    final nextItems = Set<TestExecutionChecklistItem>.of(completedItems);
    if (checked) {
      nextItems.add(item);
    } else {
      nextItems.remove(item);
    }
    return TestExecutionChecklistState(nextItems);
  }

  List<TestExecutionChecklistItem> itemsInCategory(String categoryLabel) {
    return [
      for (final item in items)
        if (item.categoryLabel == categoryLabel) item,
    ];
  }

  List<String> get categoryLabels {
    final labels = <String>[];
    for (final item in items) {
      if (!labels.contains(item.categoryLabel)) {
        labels.add(item.categoryLabel);
      }
    }
    return List<String>.unmodifiable(labels);
  }
}

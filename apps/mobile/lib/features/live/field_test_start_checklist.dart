enum FieldTestStartChecklistItem {
  controlledRoute,
  backupPerson,
  batteryNetwork,
  audioOutput,
  cameraMounted,
  permissions,
  accessibilityMode,
  stationaryAiAnalysis,
}

extension FieldTestStartChecklistItemText on FieldTestStartChecklistItem {
  String get label {
    return switch (this) {
      FieldTestStartChecklistItem.controlledRoute => '제어된 코스',
      FieldTestStartChecklistItem.backupPerson => '백업 보호자',
      FieldTestStartChecklistItem.batteryNetwork => '배터리/네트워크',
      FieldTestStartChecklistItem.audioOutput => '오디오 출력',
      FieldTestStartChecklistItem.cameraMounted => '카메라 렌즈/고정',
      FieldTestStartChecklistItem.permissions => '카메라/마이크 권한',
      FieldTestStartChecklistItem.accessibilityMode => 'TalkBack 또는 큰 글씨 모드',
      FieldTestStartChecklistItem.stationaryAiAnalysis => '정지 상태 AI 분석 확인',
    };
  }

  String get detail {
    return switch (this) {
      FieldTestStartChecklistItem.controlledRoute =>
        '제어 가능하고 익숙한 짧은 코스에서만 테스트합니다.',
      FieldTestStartChecklistItem.backupPerson =>
        '비상 시 멈춤과 귀가를 도울 백업 보호자 기준을 확인합니다.',
      FieldTestStartChecklistItem.batteryNetwork =>
        '러너와 가이드 기기의 배터리와 네트워크가 충분한지 확인합니다.',
      FieldTestStartChecklistItem.audioOutput =>
        '주변 소리를 들을 수 있는 오디오 출력으로 안내가 들리는지 확인합니다.',
      FieldTestStartChecklistItem.cameraMounted =>
        '눈앞 카메라가 가려지지 않고 휴대폰이 단단히 고정됐는지 확인합니다.',
      FieldTestStartChecklistItem.permissions =>
        '정지 상태에서 카메라와 마이크 권한 요청을 완료합니다.',
      FieldTestStartChecklistItem.accessibilityMode =>
        'TalkBack 또는 큰 글씨 모드에서 주요 상태와 버튼을 확인합니다.',
      FieldTestStartChecklistItem.stationaryAiAnalysis =>
        '실제 AI 분석은 러너가 정지한 상태에서만 확인합니다.',
    };
  }

  String checkedSemanticsLabel(bool checked) {
    return '$label, ${checked ? '완료' : '미완료'}. $detail';
  }
}

class FieldTestStartChecklistState {
  FieldTestStartChecklistState([
    Iterable<FieldTestStartChecklistItem> completedItems = const [],
  ]) : completedItems = Set<FieldTestStartChecklistItem>.unmodifiable(
          completedItems,
        );

  static const items = FieldTestStartChecklistItem.values;

  final Set<FieldTestStartChecklistItem> completedItems;

  int get completedCount => completedItems.length;

  int get totalCount => items.length;

  bool get canStart => completedCount == totalCount;

  FieldTestStartChecklistItem? get nextMissingItem {
    for (final item in items) {
      if (!completedItems.contains(item)) {
        return item;
      }
    }
    return null;
  }

  String get progressLabel => '$completedCount/$totalCount 완료';

  String get startStatusLabel {
    final next = nextMissingItem;
    if (next == null) {
      return '실기기 테스트 모드를 시작할 수 있습니다.';
    }
    return '시작 전 점검 필요: ${next.label}';
  }

  String get blockedReason {
    final next = nextMissingItem;
    if (next == null) {
      return '실기기 테스트 모드를 시작할 수 있습니다.';
    }
    return '${next.label} 항목을 먼저 확인합니다. ${next.detail}';
  }

  String get talkBackSummary {
    final next = nextMissingItem;
    if (next == null) {
      return '실기기 테스트 시작 전 점검. 모든 항목 완료. 시작할 수 있습니다.';
    }
    return '실기기 테스트 시작 전 점검. $progressLabel. 다음 항목은 ${next.label}. ${next.detail}';
  }

  String get renderedText {
    return [
      progressLabel,
      startStatusLabel,
      blockedReason,
      talkBackSummary,
      for (final item in items) ...[
        item.label,
        item.detail,
        item.checkedSemanticsLabel(completedItems.contains(item)),
      ],
    ].join('\n');
  }

  bool contains(FieldTestStartChecklistItem item) {
    return completedItems.contains(item);
  }

  FieldTestStartChecklistState updateItem(
    FieldTestStartChecklistItem item,
    bool checked,
  ) {
    final nextItems = Set<FieldTestStartChecklistItem>.of(completedItems);
    if (checked) {
      nextItems.add(item);
    } else {
      nextItems.remove(item);
    }
    return FieldTestStartChecklistState(nextItems);
  }
}

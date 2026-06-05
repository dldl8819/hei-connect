enum GuideFlowChecklistItem {
  webRtcVideo,
  guideVoice,
  cueButtons,
  shortChatTts,
  stopResume,
}

extension GuideFlowChecklistItemText on GuideFlowChecklistItem {
  String get label {
    return switch (this) {
      GuideFlowChecklistItem.webRtcVideo => 'WebRTC 영상 확인',
      GuideFlowChecklistItem.guideVoice => '가이드 음성',
      GuideFlowChecklistItem.cueButtons => 'cue 버튼',
      GuideFlowChecklistItem.shortChatTts => '짧은 채팅 TTS',
      GuideFlowChecklistItem.stopResume => '정지 큐 후 재개 확인',
    };
  }

  String get detail {
    return switch (this) {
      GuideFlowChecklistItem.webRtcVideo =>
        '가이드 기기에서 눈앞 카메라 영상이 안정적으로 보이는지 확인합니다.',
      GuideFlowChecklistItem.guideVoice =>
        '가이드의 짧은 음성 안내가 러너에게 명확히 들리는지 확인합니다.',
      GuideFlowChecklistItem.cueButtons =>
        '감속, 유지, 정지 같은 cue 버튼 안내가 TTS로 전달되는지 확인합니다.',
      GuideFlowChecklistItem.shortChatTts =>
        '가이드가 짧은 테스트 채팅을 보냈을 때 TTS가 읽어 주는지 확인합니다.',
      GuideFlowChecklistItem.stopResume =>
        '정지 cue 뒤 러너가 멈추고 안전 확인 후에만 재개되는지 확인합니다.',
    };
  }
}

class GuideFlowChecklistState {
  GuideFlowChecklistState(
      [Iterable<GuideFlowChecklistItem> confirmedItems = const []])
      : confirmedItems = Set<GuideFlowChecklistItem>.unmodifiable(
          confirmedItems,
        );

  static const items = GuideFlowChecklistItem.values;

  final Set<GuideFlowChecklistItem> confirmedItems;

  int get confirmedCount => confirmedItems.length;

  int get totalCount => items.length;

  bool get isComplete => confirmedCount == totalCount;

  bool get allowsAiAssist => isComplete;

  String get statusLabel =>
      isComplete ? '확인 완료' : '$confirmedCount/$totalCount 확인';

  GuideFlowChecklistItem? get nextMissingItem {
    for (final item in items) {
      if (!confirmedItems.contains(item)) {
        return item;
      }
    }
    return null;
  }

  bool contains(GuideFlowChecklistItem item) {
    return confirmedItems.contains(item);
  }

  GuideFlowChecklistState updateItem(
    GuideFlowChecklistItem item,
    bool checked,
  ) {
    final nextItems = Set<GuideFlowChecklistItem>.of(confirmedItems);
    if (checked) {
      nextItems.add(item);
    } else {
      nextItems.remove(item);
    }
    return GuideFlowChecklistState(nextItems);
  }
}

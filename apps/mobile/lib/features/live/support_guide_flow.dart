import 'guide_flow_checklist.dart';

enum SupportGuideStatus {
  completed,
  current,
  pending,
  blocked,
}

extension SupportGuideStatusLabel on SupportGuideStatus {
  String get label {
    return switch (this) {
      SupportGuideStatus.completed => '완료',
      SupportGuideStatus.current => '현재',
      SupportGuideStatus.pending => '대기',
      SupportGuideStatus.blocked => '중지',
    };
  }
}

class SupportGuideFlowStatusItem {
  const SupportGuideFlowStatusItem({
    required this.title,
    required this.detail,
    required this.status,
  });

  final String title;
  final String detail;
  final SupportGuideStatus status;

  String get semanticsLabel => '$title, ${status.label}. $detail';
}

class SupportGuideFlowState {
  const SupportGuideFlowState({
    required this.isRunningGuide,
    required this.webRtcConnected,
    required this.connectionLost,
    required this.guideFlowState,
    required this.stopCueAwaitingResume,
  });

  final bool isRunningGuide;
  final bool webRtcConnected;
  final bool connectionLost;
  final GuideFlowChecklistState guideFlowState;
  final bool stopCueAwaitingResume;

  bool get canCheckGuideFlow =>
      isRunningGuide && webRtcConnected && !connectionLost;

  bool get requiresSafetyHold => connectionLost || stopCueAwaitingResume;

  GuideFlowChecklistItem? get nextGuideFlowItem =>
      guideFlowState.nextMissingItem;

  List<String> get safetyActions {
    if (!requiresSafetyHold) {
      return const [];
    }
    return const [
      '러너를 먼저 멈추게 합니다.',
      '백업 동행자와 통제 경로 기준을 확인합니다.',
      '자동으로 계속하지 않습니다.',
    ];
  }

  String get nextActionTitle {
    if (connectionLost) {
      return '러너를 먼저 멈추게 안내';
    }
    if (stopCueAwaitingResume) {
      return '재개 전 안전 확인';
    }
    if (!isRunningGuide) {
      return '러닝 가이드 세션 입장';
    }
    if (!webRtcConnected) {
      return '방송 연결 후 WebRTC 확인';
    }
    final nextItem = nextGuideFlowItem;
    if (nextItem != null) {
      return nextItem.nextActionTitle;
    }
    return '짧고 명확한 안내 유지';
  }

  String get nextActionDetail {
    if (connectionLost) {
      return '연결이 끊기면 먼저 정지 cue를 보내고 백업 동행자 기준을 확인합니다.';
    }
    if (stopCueAwaitingResume) {
      return '러너가 멈췄고 카메라와 오디오가 안정적인지 확인한 뒤 재개 확인을 표시합니다.';
    }
    if (!isRunningGuide) {
      return '러닝 가이드 세션에서만 현장 확인 흐름을 사용합니다.';
    }
    if (!webRtcConnected) {
      return '방송 연결을 누르고 영상과 오디오가 연결됨 상태인지 확인합니다.';
    }
    final nextItem = nextGuideFlowItem;
    if (nextItem != null) {
      return nextItem.detail;
    }
    return '원격 가이드와 AI 보조는 보조 기능입니다. 통제 경로와 백업 동행자 기준을 유지합니다.';
  }

  List<SupportGuideFlowStatusItem> get statusItems {
    if (!isRunningGuide) {
      return [
        for (final item in GuideFlowChecklistState.items)
          SupportGuideFlowStatusItem(
            title: item.label,
            detail: item.detail,
            status: SupportGuideStatus.blocked,
          ),
      ];
    }

    if (!webRtcConnected || connectionLost) {
      return [
        for (final item in GuideFlowChecklistState.items)
          SupportGuideFlowStatusItem(
            title: item.label,
            detail: item.detail,
            status: item == GuideFlowChecklistItem.webRtcVideo
                ? connectionLost
                    ? SupportGuideStatus.blocked
                    : SupportGuideStatus.current
                : SupportGuideStatus.pending,
          ),
      ];
    }

    final items = <SupportGuideFlowStatusItem>[];
    var currentAssigned = false;
    for (final item in GuideFlowChecklistState.items) {
      final checked = guideFlowState.contains(item);
      final status = checked
          ? SupportGuideStatus.completed
          : currentAssigned
              ? SupportGuideStatus.pending
              : SupportGuideStatus.current;
      if (status == SupportGuideStatus.current) {
        currentAssigned = true;
      }
      items.add(
        SupportGuideFlowStatusItem(
          title: item.label,
          detail: item.detail,
          status: status,
        ),
      );
    }
    return List<SupportGuideFlowStatusItem>.unmodifiable(items);
  }

  String get talkBackSummary {
    return '가이드 조작 패널. 다음 행동은 $nextActionTitle. '
        '$nextActionDetail 가이드 흐름은 ${guideFlowState.statusLabel}.';
  }
}

extension _SupportGuideChecklistItemAction on GuideFlowChecklistItem {
  String get nextActionTitle {
    if (label.endsWith('확인')) {
      return label;
    }
    return '$label 확인';
  }
}

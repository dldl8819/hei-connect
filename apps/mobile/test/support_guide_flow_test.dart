import 'package:connect_mobile/features/live/guide_flow_checklist.dart';
import 'package:connect_mobile/features/live/support_guide_flow.dart';
import 'package:test/test.dart';

void main() {
  test('blocks guide checks outside a running guide session', () {
    final state = SupportGuideFlowState(
      isRunningGuide: false,
      webRtcConnected: false,
      connectionLost: false,
      guideFlowState: GuideFlowChecklistState(),
      stopCueAwaitingResume: false,
    );

    expect(state.canCheckGuideFlow, isFalse);
    expect(state.nextActionTitle, '러닝 가이드 세션 입장');
    expect(state.statusItems.first.status, SupportGuideStatus.blocked);
  });

  test('asks for WebRTC confirmation before guide-flow checks', () {
    final state = SupportGuideFlowState(
      isRunningGuide: true,
      webRtcConnected: false,
      connectionLost: false,
      guideFlowState: GuideFlowChecklistState(),
      stopCueAwaitingResume: false,
    );

    expect(state.canCheckGuideFlow, isFalse);
    expect(state.nextActionTitle, '방송 연결 후 WebRTC 확인');
    expect(state.statusItems.first.title, 'WebRTC 영상 확인');
    expect(state.statusItems.first.status, SupportGuideStatus.current);
  });

  test('tracks partial guide-flow status in order', () {
    final state = SupportGuideFlowState(
      isRunningGuide: true,
      webRtcConnected: true,
      connectionLost: false,
      guideFlowState: GuideFlowChecklistState([
        GuideFlowChecklistItem.webRtcVideo,
        GuideFlowChecklistItem.guideVoice,
      ]),
      stopCueAwaitingResume: false,
    );

    expect(state.canCheckGuideFlow, isTrue);
    expect(state.nextActionTitle, 'cue 버튼 확인');
    expect(state.statusItems[0].status, SupportGuideStatus.completed);
    expect(state.statusItems[1].status, SupportGuideStatus.completed);
    expect(state.statusItems[2].status, SupportGuideStatus.current);
    expect(state.statusItems[3].status, SupportGuideStatus.pending);
  });

  test('requires explicit safety hold after a stop cue', () {
    final state = SupportGuideFlowState(
      isRunningGuide: true,
      webRtcConnected: true,
      connectionLost: false,
      guideFlowState: GuideFlowChecklistState(GuideFlowChecklistState.items),
      stopCueAwaitingResume: true,
    );

    expect(state.requiresSafetyHold, isTrue);
    expect(state.nextActionTitle, '재개 전 안전 확인');
    expect(
      state.safetyActions,
      containsAll([
        '러너를 먼저 멈추게 합니다.',
        '백업 동행자와 통제 경로 기준을 확인합니다.',
        '자동으로 계속하지 않습니다.',
      ]),
    );
  });

  test('uses connection-lost safety action before any resume', () {
    final state = SupportGuideFlowState(
      isRunningGuide: true,
      webRtcConnected: false,
      connectionLost: true,
      guideFlowState: GuideFlowChecklistState(),
      stopCueAwaitingResume: false,
    );

    expect(state.requiresSafetyHold, isTrue);
    expect(state.nextActionTitle, '러너를 먼저 멈추게 안내');
    expect(state.statusItems.first.status, SupportGuideStatus.blocked);
  });

  test('guide flow state does not contain sensitive data fields', () {
    final state = SupportGuideFlowState(
      isRunningGuide: true,
      webRtcConnected: true,
      connectionLost: false,
      guideFlowState: GuideFlowChecklistState(GuideFlowChecklistState.items),
      stopCueAwaitingResume: false,
    );
    final rendered = [
      state.nextActionTitle,
      state.nextActionDetail,
      state.talkBackSummary,
      ...state.safetyActions,
      for (final item in state.statusItems) ...[
        item.title,
        item.detail,
        item.semanticsLabel,
      ],
    ].join('\n');

    expect(rendered, isNot(contains('참여 링크')));
    expect(rendered, isNot(contains('세션 코드')));
    expect(rendered, isNot(contains('채팅 원문')));
    expect(rendered, isNot(contains('카메라 원본')));
    expect(rendered, isNot(contains('위치 정보')));
    expect(rendered, isNot(contains('연락처')));
  });
}

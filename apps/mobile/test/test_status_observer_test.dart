import 'package:connect_mobile/features/live/guide_flow_checklist.dart';
import 'package:connect_mobile/features/live/test_status_observer.dart';
import 'package:test/test.dart';

void main() {
  test('runner shows connection waiting before WebRTC connection', () {
    final state = RunnerTestStatusObserverState(
      isLive: true,
      webRtcConnected: false,
      connectionLost: false,
      mediaPermissionsReady: true,
      guideFlowState: GuideFlowChecklistState(),
      aiVerificationMode: false,
      aiVerificationChecked: false,
      actualAiAnalysisAvailable: false,
      requiresResumeConfirmation: false,
    );

    expect(state.webRtc.value, '연결 대기');
    expect(state.talkBackSummary, contains('연결 대기'));
  });

  test('incomplete guide flow blocks AI statuses', () {
    final state = RunnerTestStatusObserverState(
      isLive: true,
      webRtcConnected: true,
      connectionLost: false,
      mediaPermissionsReady: true,
      guideFlowState: GuideFlowChecklistState(),
      aiVerificationMode: false,
      aiVerificationChecked: false,
      actualAiAnalysisAvailable: false,
      requiresResumeConfirmation: false,
    );

    expect(state.guideFlow.level, TestStatusObserverLevel.pending);
    expect(state.aiVerification.level, TestStatusObserverLevel.blocked);
    expect(state.actualAiAnalysis.level, TestStatusObserverLevel.blocked);
    expect(state.aiVerification.detail, contains('가이드 흐름 5개 항목'));
  });

  test('actual AI analysis stays blocked before AI verification', () {
    final state = RunnerTestStatusObserverState(
      isLive: true,
      webRtcConnected: true,
      connectionLost: false,
      mediaPermissionsReady: true,
      guideFlowState: GuideFlowChecklistState(GuideFlowChecklistState.items),
      aiVerificationMode: false,
      aiVerificationChecked: false,
      actualAiAnalysisAvailable: true,
      requiresResumeConfirmation: false,
    );

    expect(state.aiVerification.level, TestStatusObserverLevel.pending);
    expect(state.actualAiAnalysis.level, TestStatusObserverLevel.blocked);
    expect(state.actualAiAnalysis.detail, contains('AI 검증 완료 전'));
  });

  test('connection loss prioritizes stop and backup criteria', () {
    final state = GuideTestStatusObserverState(
      sessionJoined: true,
      webRtcConnected: false,
      connectionLost: true,
      mediaPermissionsReady: true,
      guideFlowState: GuideFlowChecklistState(GuideFlowChecklistState.items),
      aiVerificationChecked: true,
      actualAiAnalysisChecked: false,
      stopCueAwaitingResume: true,
    );

    expect(state.resumeConfirmation.level, TestStatusObserverLevel.blocked);
    expect(state.backupCriteria.level, TestStatusObserverLevel.blocked);
    expect(state.backupCriteria.detail, contains('재개보다 정지와 백업 기준'));
    expect(state.primaryItem.detail, contains('정지'));
  });

  test('observer text does not contain forbidden fields or overclaims', () {
    final states = [
      RunnerTestStatusObserverState(
        isLive: true,
        webRtcConnected: true,
        connectionLost: false,
        mediaPermissionsReady: true,
        guideFlowState: GuideFlowChecklistState(GuideFlowChecklistState.items),
        aiVerificationMode: false,
        aiVerificationChecked: true,
        actualAiAnalysisAvailable: true,
        requiresResumeConfirmation: false,
      ),
      GuideTestStatusObserverState(
        sessionJoined: true,
        webRtcConnected: true,
        connectionLost: false,
        mediaPermissionsReady: true,
        guideFlowState: GuideFlowChecklistState(GuideFlowChecklistState.items),
        aiVerificationChecked: true,
        actualAiAnalysisChecked: true,
        stopCueAwaitingResume: false,
      ),
    ];
    final rendered = states.map((state) => state.renderedText).join('\n');

    expect(rendered, isNot(contains('참여 링크')));
    expect(rendered, isNot(contains('참여 코드')));
    expect(rendered, isNot(contains('세션 코드')));
    expect(rendered, isNot(contains('사용자 식별')));
    expect(rendered, isNot(contains('위치 정보')));
    expect(rendered, isNot(contains('채팅 원문')));
    expect(rendered, isNot(contains('카메라 원본')));
    expect(rendered, isNot(contains('감지 원본')));
    expect(rendered, isNot(contains('토큰')));
    expect(rendered, isNot(contains('비밀값')));
    expect(rendered, isNot(contains('혼자 안전')));
    expect(rendered, isNot(contains('혼자 달릴 수')));
    expect(rendered, isNot(contains('완전 자율')));
  });
}

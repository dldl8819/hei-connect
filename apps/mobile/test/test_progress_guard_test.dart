import 'package:connect_mobile/features/live/test_progress_guard.dart';
import 'package:test/test.dart';

void main() {
  test('runner blocks guide-flow checks before live WebRTC connection', () {
    const guard = RunnerTestProgressGuardState(
      isLive: false,
      webRtcConnected: false,
      guideFlowComplete: false,
      aiVerificationChecked: false,
      reportReady: false,
    );

    expect(guard.guideFlow.allowed, isFalse);
    expect(guard.guideFlow.reason, contains('라이브 시작과 WebRTC 연결 후'));
    expect(guard.talkBackSummary, contains('가이드 흐름 체크 차단'));
  });

  test('runner blocks AI verification before guide flow is complete', () {
    const guard = RunnerTestProgressGuardState(
      isLive: true,
      webRtcConnected: true,
      guideFlowComplete: false,
      aiVerificationChecked: false,
      reportReady: false,
    );

    expect(guard.guideFlow.allowed, isTrue);
    expect(guard.aiVerification.allowed, isFalse);
    expect(guard.aiVerification.reason, contains('정지/재개를 먼저 확인'));
  });

  test('runner blocks actual AI analysis before AI verification', () {
    const guard = RunnerTestProgressGuardState(
      isLive: true,
      webRtcConnected: true,
      guideFlowComplete: true,
      aiVerificationChecked: false,
      reportReady: false,
    );

    expect(guard.aiVerification.allowed, isTrue);
    expect(guard.actualAiAnalysis.allowed, isFalse);
    expect(guard.actualAiAnalysis.reason, contains('감속 cue와 정지 cue'));
    expect(guard.actualAiAnalysis.reason, contains('정지 상태에서만 확인'));
  });

  test('runner blocks report readiness before memo and privacy check', () {
    const guard = RunnerTestProgressGuardState(
      isLive: true,
      webRtcConnected: true,
      guideFlowComplete: true,
      aiVerificationChecked: true,
      reportReady: false,
    );

    expect(guard.report.allowed, isFalse);
    expect(guard.report.reason, contains('메모가 비어 있거나'));
    expect(guard.report.reason, contains('민감정보 제거 확인'));
    expect(guard.report.semanticsLabel, isNot(contains('리포트 준비됨')));
  });

  test('guide blocks guide-flow checks before WebRTC connection', () {
    const guard = GuideTestProgressGuardState(
      webRtcConnected: false,
      connectionLost: false,
      stopCueAwaitingResume: false,
    );

    expect(guard.guideFlow.allowed, isFalse);
    expect(guard.guideFlow.reason, contains('WebRTC가 연결됨'));
  });

  test('guide blocks resume confirmation when connection is lost', () {
    const guard = GuideTestProgressGuardState(
      webRtcConnected: false,
      connectionLost: true,
      stopCueAwaitingResume: true,
    );

    expect(guard.resumeConfirmation.allowed, isFalse);
    expect(guard.resumeConfirmation.reason, contains('재개하지 않고'));
    expect(guard.holdPaceGuidance.allowed, isFalse);
  });

  test('guard text does not contain forbidden data fields or overclaims', () {
    const runnerGuard = RunnerTestProgressGuardState(
      isLive: true,
      webRtcConnected: true,
      guideFlowComplete: true,
      aiVerificationChecked: true,
      reportReady: false,
    );
    const guideGuard = GuideTestProgressGuardState(
      webRtcConnected: true,
      connectionLost: false,
      stopCueAwaitingResume: false,
    );
    final rendered = [
      runnerGuard.talkBackSummary,
      guideGuard.talkBackSummary,
      for (final decision in runnerGuard.decisions) ...[
        decision.label,
        decision.reason,
        decision.semanticsLabel,
      ],
      for (final decision in guideGuard.decisions) ...[
        decision.label,
        decision.reason,
        decision.semanticsLabel,
      ],
    ].join('\n');

    expect(rendered, isNot(contains('참여 링크')));
    expect(rendered, isNot(contains('세션 코드')));
    expect(rendered, isNot(contains('채팅 원문')));
    expect(rendered, isNot(contains('카메라 원본')));
    expect(rendered, isNot(contains('위치 정보')));
    expect(rendered, isNot(contains('연락처')));
    expect(rendered, isNot(contains('사람 얼굴')));
    expect(rendered, isNot(contains('차량번호')));
    expect(rendered, isNot(contains('혼자 안전')));
    expect(rendered, isNot(contains('혼자 달릴 수')));
    expect(rendered, isNot(contains('완전 자율')));
  });
}

import 'package:connect_mobile/features/live/field_test_mode.dart';
import 'package:connect_mobile/features/live/guide_flow_checklist.dart';
import 'package:test/test.dart';

void main() {
  test('summarizes 0 of 5 guide-flow state without enabling AI assist', () {
    final snapshot = FieldTestModeSnapshot(
      guideFlowState: GuideFlowChecklistState(),
      preRunChecklistComplete: true,
      sessionCreated: true,
      isLive: true,
      webRtcConnected: true,
      webRtcStatusLabel: '연결됨',
      aiAssistStatusLabel: 'AI 보조 잠김: 가이드 흐름 0/5 확인',
      aiAssistEnabled: false,
      aiVerificationMode: false,
      requiresResumeConfirmation: false,
      lastSafetyCueLabel: '좋아요 유지',
    );

    expect(snapshot.nextActionTitle, 'WebRTC 영상 확인');
    expect(snapshot.stageLabel, '가이드 흐름');
    expect(snapshot.toSummary().rows[0].value, '0/5 확인 (0/5)');
    expect(snapshot.toSummary().rows[1].value, contains('AI 보조 잠김'));
  });

  test('summarizes completed guide-flow state', () {
    final snapshot = FieldTestModeSnapshot(
      guideFlowState: GuideFlowChecklistState(GuideFlowChecklistState.items),
      preRunChecklistComplete: true,
      sessionCreated: true,
      isLive: true,
      webRtcConnected: true,
      webRtcStatusLabel: '연결됨',
      aiAssistStatusLabel: '꺼짐',
      aiAssistEnabled: false,
      aiVerificationMode: false,
      requiresResumeConfirmation: false,
      lastSafetyCueLabel: '좋아요 유지',
    );

    expect(snapshot.nextActionTitle, 'AI 보조 안내 켜기');
    expect(snapshot.stageLabel, 'AI 검증');
    expect(snapshot.toSummary().rows[0].value, '확인 완료 (5/5)');
    expect(snapshot.toSummary().resumeStatusLabel, '정상');
  });

  test('prioritizes resume confirmation in field-test mode summary', () {
    final snapshot = FieldTestModeSnapshot(
      guideFlowState: GuideFlowChecklistState(GuideFlowChecklistState.items),
      preRunChecklistComplete: true,
      sessionCreated: true,
      isLive: false,
      webRtcConnected: false,
      webRtcStatusLabel: '연결 끊김',
      aiAssistStatusLabel: '꺼짐',
      aiAssistEnabled: false,
      aiVerificationMode: false,
      requiresResumeConfirmation: true,
      lastSafetyCueLabel: '정지',
    );

    expect(snapshot.nextActionTitle, '안전 확인 후 재개');
    expect(snapshot.stageLabel, '재개 확인');
    expect(snapshot.toSummary().resumeStatusLabel, '필요');
    expect(snapshot.toSummary().rows.last.value, '정지');
  });

  test('summary rows do not include sensitive field labels', () {
    final summary = FieldTestModeSnapshot(
      guideFlowState: GuideFlowChecklistState(),
      preRunChecklistComplete: false,
      sessionCreated: false,
      isLive: false,
      webRtcConnected: false,
      webRtcStatusLabel: '대기',
      aiAssistStatusLabel: 'AI 보조 잠김: 가이드 흐름 0/5 확인',
      aiAssistEnabled: false,
      aiVerificationMode: false,
      requiresResumeConfirmation: false,
      lastSafetyCueLabel: '좋아요 유지',
    ).toSummary();
    final renderedRows =
        summary.rows.map((row) => '${row.label}: ${row.value}').join('\n');

    expect(renderedRows, isNot(contains('참여 링크')));
    expect(renderedRows, isNot(contains('세션 코드')));
    expect(renderedRows, isNot(contains('채팅 원문')));
    expect(renderedRows, isNot(contains('카메라 원본')));
    expect(renderedRows, isNot(contains('위치 정보')));
  });

  test('creates an empty local test memo', () {
    final memo = FieldTestResultMemo.fromInput();

    expect(memo.isEmpty, isTrue);
    expect(memo.isReadyForLocalReview, isFalse);
    expect(memo.safetyStatusLabel, '민감정보 제거 확인 필요');
  });

  test('creates a normal local test memo with operational facts only', () {
    final memo = FieldTestResultMemo.fromInput(
      failureStep: '가이드 흐름 확인',
      expectedResult: '짧은 채팅 TTS가 들림',
      actualResult: 'TTS가 들리지 않음',
      reproductionSteps: '라이브 연결 후 짧은 테스트 메시지 전송',
      sensitiveInfoRemoved: true,
    );

    expect(memo.isEmpty, isFalse);
    expect(memo.isReadyForLocalReview, isTrue);
    expect(memo.rows[0].value, '가이드 흐름 확인');
    expect(memo.rows.last.value, '민감정보 제거 확인 완료');
  });

  test('requires sensitive-info removal confirmation before local review', () {
    final memo = FieldTestResultMemo.fromInput(
      failureStep: 'AI 검증',
      expectedResult: '정지 cue 후 재개 확인 필요',
      actualResult: '재개 확인 표시 없음',
      reproductionSteps: '정지 큐 테스트 실행',
      sensitiveInfoRemoved: false,
    );

    expect(memo.isReadyForLocalReview, isFalse);
    expect(memo.safetyStatusLabel, '민감정보 제거 확인 필요');
  });

  test('limits overly long memo input', () {
    final longText = '가' * (FieldTestResultMemo.maxFieldLength + 10);
    final memo = FieldTestResultMemo.fromInput(
      failureStep: longText,
      sensitiveInfoRemoved: true,
    );

    expect(memo.failureStep.length, FieldTestResultMemo.maxFieldLength);
    expect(memo.hasTruncatedInput, isTrue);
    expect(
      memo.lengthNotice,
      '긴 입력은 항목당 ${FieldTestResultMemo.maxFieldLength}자까지만 화면에 보관합니다.',
    );
  });

  test('memo rows do not include forbidden data fields', () {
    final memo = FieldTestResultMemo.fromInput(
      failureStep: '라이브 연결',
      expectedResult: 'WebRTC 연결됨',
      actualResult: '응답 대기',
      reproductionSteps: '신호 새로고침 실행',
      sensitiveInfoRemoved: true,
    );
    final renderedRows =
        memo.rows.map((row) => '${row.label}: ${row.value}').join('\n');

    expect(renderedRows, isNot(contains('참여 링크')));
    expect(renderedRows, isNot(contains('세션 코드')));
    expect(renderedRows, isNot(contains('채팅 원문')));
    expect(renderedRows, isNot(contains('카메라 원본')));
    expect(renderedRows, isNot(contains('위치 정보')));
    expect(renderedRows, isNot(contains('연락처')));
  });

  test('device test order starts at running guide selection', () {
    final order = FieldTestDeviceTestOrderState(
      isRunningGuide: false,
      runnerModeSelected: false,
      isWorldCamera: false,
      preRunChecklistComplete: false,
      sessionCreated: false,
      isLive: false,
      webRtcConnected: false,
      guideFlowState: GuideFlowChecklistState(),
      aiVerificationChecked: false,
      actualAiAnalysisChecked: false,
    );

    expect(order.completedCount, 0);
    expect(order.currentStep.number, 1);
    expect(order.currentStep.title, '러닝 가이드 선택');
    expect(order.steps[0].status, FieldTestDeviceStepStatus.current);
    expect(order.steps[1].status, FieldTestDeviceStepStatus.pending);
  });

  test('device test order marks live start before WebRTC connection', () {
    final order = FieldTestDeviceTestOrderState(
      isRunningGuide: true,
      runnerModeSelected: true,
      isWorldCamera: true,
      preRunChecklistComplete: true,
      sessionCreated: true,
      isLive: false,
      webRtcConnected: false,
      guideFlowState: GuideFlowChecklistState(),
      aiVerificationChecked: false,
      actualAiAnalysisChecked: false,
    );

    expect(order.completedCount, 5);
    expect(order.currentStep.number, 6);
    expect(order.currentStep.title, '라이브 시작 및 권한 허용');
    expect(order.steps[6].status, FieldTestDeviceStepStatus.pending);
  });

  test('device test order waits for partial guide-flow completion', () {
    final order = FieldTestDeviceTestOrderState(
      isRunningGuide: true,
      runnerModeSelected: true,
      isWorldCamera: true,
      preRunChecklistComplete: true,
      sessionCreated: true,
      isLive: true,
      webRtcConnected: true,
      guideFlowState: GuideFlowChecklistState([
        GuideFlowChecklistItem.webRtcVideo,
        GuideFlowChecklistItem.guideVoice,
      ]),
      aiVerificationChecked: false,
      actualAiAnalysisChecked: false,
    );

    expect(order.completedCount, 7);
    expect(order.currentStep.number, 8);
    expect(order.currentStep.title, '가이드 흐름 5개 항목 확인');
    expect(order.progressLabel, '7/10 완료');
  });

  test('device test order waits for AI verification after 5 of 5 guide flow',
      () {
    final order = FieldTestDeviceTestOrderState(
      isRunningGuide: true,
      runnerModeSelected: true,
      isWorldCamera: true,
      preRunChecklistComplete: true,
      sessionCreated: true,
      isLive: true,
      webRtcConnected: true,
      guideFlowState: GuideFlowChecklistState(GuideFlowChecklistState.items),
      aiVerificationChecked: false,
      actualAiAnalysisChecked: false,
    );

    expect(order.completedCount, 8);
    expect(order.currentStep.number, 9);
    expect(order.currentStep.title, 'AI 검증 모드 확인');
    expect(order.steps[9].status, FieldTestDeviceStepStatus.pending);
  });

  test('device test order waits for stationary actual AI analysis', () {
    final order = FieldTestDeviceTestOrderState(
      isRunningGuide: true,
      runnerModeSelected: true,
      isWorldCamera: true,
      preRunChecklistComplete: true,
      sessionCreated: true,
      isLive: true,
      webRtcConnected: true,
      guideFlowState: GuideFlowChecklistState(GuideFlowChecklistState.items),
      aiVerificationChecked: true,
      actualAiAnalysisChecked: false,
    );

    expect(order.completedCount, 9);
    expect(order.currentStep.number, 10);
    expect(order.currentStep.title, '실제 AI 분석은 정지 상태에서만 확인');
    expect(order.talkBackSummary, contains('현재 단계는 10단계'));
  });

  test('device test order structure has no sensitive data labels', () {
    final order = FieldTestDeviceTestOrderState(
      isRunningGuide: true,
      runnerModeSelected: true,
      isWorldCamera: true,
      preRunChecklistComplete: true,
      sessionCreated: true,
      isLive: true,
      webRtcConnected: true,
      guideFlowState: GuideFlowChecklistState(GuideFlowChecklistState.items),
      aiVerificationChecked: true,
      actualAiAnalysisChecked: true,
    );
    final rendered = [
      order.progressLabel,
      order.talkBackSummary,
      for (final step in order.steps) ...[
        step.title,
        step.detail,
        step.semanticsLabel,
      ],
    ].join('\n');

    expect(order.isComplete, isTrue);
    expect(rendered, isNot(contains('참여 링크')));
    expect(rendered, isNot(contains('세션 코드')));
    expect(rendered, isNot(contains('채팅 원문')));
    expect(rendered, isNot(contains('카메라 원본')));
    expect(rendered, isNot(contains('위치 정보')));
    expect(rendered, isNot(contains('연락처')));
  });
}

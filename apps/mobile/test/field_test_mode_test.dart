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
}

import 'package:connect_mobile/features/live/field_test_mode.dart';
import 'package:connect_mobile/features/live/test_session_report.dart';
import 'package:test/test.dart';

void main() {
  test('marks empty memo report as no input', () {
    final report = TestSessionReport(
      role: TestSessionReportRole.runner,
      webRtcConnected: false,
      guideFlowConfirmedCount: 0,
      guideFlowTotalCount: 5,
      aiVerificationChecked: false,
      actualAiAnalysisChecked: false,
      stopResumeConfirmed: false,
      memo: FieldTestResultMemo.fromInput(),
    );

    expect(report.status, TestSessionReportStatus.emptyInput);
    expect(report.statusLabel, '입력 없음');
    expect(report.rows.last.value, TestSessionReport.emptyValueLabel);
    expect(report.isReady, isFalse);
  });

  test('protects memo values until sensitive-info removal is confirmed', () {
    final report = TestSessionReport(
      role: TestSessionReportRole.runner,
      webRtcConnected: true,
      guideFlowConfirmedCount: 5,
      guideFlowTotalCount: 5,
      aiVerificationChecked: true,
      actualAiAnalysisChecked: false,
      stopResumeConfirmed: true,
      memo: FieldTestResultMemo.fromInput(
        failureStep: 'AI 검증',
        expectedResult: '정지 cue 확인',
        actualResult: '확인 미완료',
        reproductionSteps: '검증 모드 실행',
        sensitiveInfoRemoved: false,
      ),
    );
    final renderedRows = report.rows.map((row) => row.value).join('\n');

    expect(report.status, TestSessionReportStatus.sensitiveInfoRequired);
    expect(report.isReady, isFalse);
    expect(renderedRows, isNot(contains('AI 검증')));
    expect(renderedRows, contains(TestSessionReport.protectedMemoLabel));
  });

  test('marks normal sanitized memo report as ready', () {
    final report = TestSessionReport(
      role: TestSessionReportRole.runner,
      webRtcConnected: true,
      guideFlowConfirmedCount: 5,
      guideFlowTotalCount: 5,
      aiVerificationChecked: true,
      actualAiAnalysisChecked: true,
      stopResumeConfirmed: true,
      memo: FieldTestResultMemo.fromInput(
        failureStep: '가이드 흐름 확인',
        expectedResult: '짧은 채팅 TTS가 들림',
        actualResult: 'TTS가 들리지 않음',
        reproductionSteps: '라이브 연결 후 테스트 메시지 전송',
        sensitiveInfoRemoved: true,
      ),
    );

    expect(report.status, TestSessionReportStatus.ready);
    expect(report.isReady, isTrue);
    expect(report.rows[7].value, '가이드 흐름 확인');
    expect(report.rows[10].value, '라이브 연결 후 테스트 메시지 전송');
  });

  test('creates runner report with operating status only', () {
    final report = TestSessionReport(
      role: TestSessionReportRole.runner,
      webRtcConnected: true,
      guideFlowConfirmedCount: 4,
      guideFlowTotalCount: 5,
      aiVerificationChecked: true,
      actualAiAnalysisChecked: false,
      stopResumeConfirmed: false,
      memo: FieldTestResultMemo.fromInput(
        failureStep: '정지 후 재개 확인',
        sensitiveInfoRemoved: true,
      ),
    );
    final rows = {for (final row in report.rows) row.label: row.value};

    expect(rows['역할'], '러너');
    expect(rows['테스트 목적'], TestSessionReport.purposeLabel);
    expect(rows['연결 상태'], '연결됨');
    expect(rows['가이드 흐름'], '4/5 확인');
    expect(rows['AI 검증'], '확인됨');
    expect(rows['실제 AI 분석'], '미확인');
    expect(rows['정지/재개 확인'], '미확인');
  });

  test('creates guide report with operating status only', () {
    final report = TestSessionReport(
      role: TestSessionReportRole.guide,
      webRtcConnected: true,
      guideFlowConfirmedCount: 5,
      guideFlowTotalCount: 5,
      aiVerificationChecked: false,
      actualAiAnalysisChecked: false,
      stopResumeConfirmed: true,
      memo: FieldTestResultMemo.fromInput(),
    );
    final rows = {for (final row in report.rows) row.label: row.value};

    expect(rows['역할'], '가이드');
    expect(rows['가이드 흐름'], '확인 완료 (5/5)');
    expect(rows['AI 검증'], '미확인');
    expect(rows['실제 AI 분석'], '미확인');
    expect(rows['정지/재개 확인'], '확인됨');
  });

  test('report structure does not contain forbidden data fields', () {
    final report = TestSessionReport(
      role: TestSessionReportRole.guide,
      webRtcConnected: true,
      guideFlowConfirmedCount: 5,
      guideFlowTotalCount: 5,
      aiVerificationChecked: true,
      actualAiAnalysisChecked: true,
      stopResumeConfirmed: true,
      memo: FieldTestResultMemo.fromInput(
        failureStep: '가이드 흐름 확인',
        expectedResult: 'TTS 확인',
        actualResult: '정상',
        reproductionSteps: '운영 절차 반복',
        sensitiveInfoRemoved: true,
      ),
    );
    final rendered = [
      report.statusLabel,
      report.talkBackSummary,
      for (final row in report.rows) '${row.label}: ${row.value}',
    ].join('\n');

    expect(rendered, isNot(contains('참여 링크')));
    expect(rendered, isNot(contains('세션 코드')));
    expect(rendered, isNot(contains('채팅 원문')));
    expect(rendered, isNot(contains('카메라 원본')));
    expect(rendered, isNot(contains('위치 정보')));
    expect(rendered, isNot(contains('연락처')));
    expect(rendered, isNot(contains('사람 얼굴')));
    expect(rendered, isNot(contains('차량번호')));
  });
}

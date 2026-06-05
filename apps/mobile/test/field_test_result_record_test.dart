import 'package:connect_mobile/features/live/field_test_result_record.dart';
import 'package:test/test.dart';

void main() {
  test('default record is not ready', () {
    final record = FieldTestResultRecord.fromInput();

    expect(record.isReady, isFalse);
    expect(record.blockingReason, contains('전체 결과'));
  });

  test('record is not ready without an outcome', () {
    final record = FieldTestResultRecord.fromInput(
      observation: 'cue 흐름 확인',
      nextAction: '동일 조건 재테스트',
    );

    expect(record.isReady, isFalse);
    expect(record.blockingReason, contains('전체 결과'));
  });

  test('failed or on-hold record requires a step', () {
    final failed = FieldTestResultRecord.fromInput(
      outcome: FieldTestResultOutcome.failed,
      observation: '정지 cue 뒤 확인 필요',
      nextAction: '가이드 흐름 재테스트',
    );
    final onHold = FieldTestResultRecord.fromInput(
      outcome: FieldTestResultOutcome.onHold,
      observation: '네트워크가 불안정함',
      nextAction: '환경 변경 후 재테스트',
    );

    expect(failed.isReady, isFalse);
    expect(failed.blockingReason, contains('실패 또는 보류 단계'));
    expect(onHold.isReady, isFalse);
    expect(onHold.blockingReason, contains('실패 또는 보류 단계'));
  });

  test(
      'passed and partially passed records require observation and next action',
      () {
    final missingObservation = FieldTestResultRecord.fromInput(
      outcome: FieldTestResultOutcome.passed,
      nextAction: '다음 코스 테스트',
    );
    final missingNextAction = FieldTestResultRecord.fromInput(
      outcome: FieldTestResultOutcome.partialPassed,
      observation: '주요 흐름은 동작함',
    );
    final ready = FieldTestResultRecord.fromInput(
      outcome: FieldTestResultOutcome.partialPassed,
      observation: '가이드 흐름은 통과, AI 확인은 재테스트 필요',
      nextAction: '정지 상태에서 AI 분석 재테스트',
      retestNeeded: true,
    );

    expect(missingObservation.isReady, isFalse);
    expect(missingObservation.blockingReason, contains('관찰한 현상'));
    expect(missingNextAction.isReady, isFalse);
    expect(missingNextAction.blockingReason, contains('다음 액션'));
    expect(ready.isReady, isTrue);
    expect(ready.readinessLabel, '결과 기록 준비됨');
  });

  test('long input is truncated per field', () {
    final longText = '가' * (FieldTestResultRecord.maxFieldLength + 10);
    final record = FieldTestResultRecord.fromInput(
      outcome: FieldTestResultOutcome.failed,
      step: longText,
      observation: longText,
      nextAction: longText,
    );

    expect(record.step.length, FieldTestResultRecord.maxFieldLength);
    expect(record.observation.length, FieldTestResultRecord.maxFieldLength);
    expect(record.nextAction.length, FieldTestResultRecord.maxFieldLength);
    expect(record.hasTruncatedInput, isTrue);
  });

  test('record text does not contain sensitive fields or overclaims', () {
    final record = FieldTestResultRecord.fromInput(
      outcome: FieldTestResultOutcome.partialPassed,
      observation: '정지 cue와 재개 확인 흐름을 확인함',
      nextAction: '제어된 코스와 백업 보호자 기준으로 재테스트',
      retestNeeded: true,
    );
    final rendered = record.renderedText;

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

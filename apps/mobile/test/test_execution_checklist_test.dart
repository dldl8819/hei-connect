import 'package:connect_mobile/features/live/test_execution_checklist.dart';
import 'package:test/test.dart';

void main() {
  test('starts with no completed items and announces next item', () {
    final state = TestExecutionChecklistState();

    expect(state.completedCount, 0);
    expect(state.totalCount, TestExecutionChecklistItem.values.length);
    expect(state.nextItem, TestExecutionChecklistItem.controlledRoute);
    expect(state.progressLabel, '${state.totalCount}개 중 0개 완료');
    expect(state.progressSemanticsLabel, contains('다음 항목은 통제 경로 확인'));
  });

  test('updates item completion without persistence requirements', () {
    final state = TestExecutionChecklistState()
        .updateItem(TestExecutionChecklistItem.controlledRoute, true)
        .updateItem(TestExecutionChecklistItem.backupPerson, true)
        .updateItem(TestExecutionChecklistItem.backupPerson, false);

    expect(state.completedCount, 1);
    expect(state.contains(TestExecutionChecklistItem.controlledRoute), isTrue);
    expect(state.contains(TestExecutionChecklistItem.backupPerson), isFalse);
    expect(state.nextItem, TestExecutionChecklistItem.backupPerson);
  });

  test('keeps checklist grouped by test-day flow', () {
    final state = TestExecutionChecklistState();

    expect(
      state.categoryLabels,
      ['테스트 전', '연결', '안내', 'AI', '종료'],
    );
    expect(
      state.itemsInCategory('테스트 전'),
      containsAll([
        TestExecutionChecklistItem.controlledRoute,
        TestExecutionChecklistItem.backupPerson,
        TestExecutionChecklistItem.battery,
        TestExecutionChecklistItem.network,
        TestExecutionChecklistItem.audioOutput,
        TestExecutionChecklistItem.cameraLens,
        TestExecutionChecklistItem.permissions,
      ]),
    );
    expect(
      state.itemsInCategory('AI'),
      [
        TestExecutionChecklistItem.aiVerificationMode,
        TestExecutionChecklistItem.stationaryAiAnalysis,
      ],
    );
  });

  test('marks all items complete', () {
    final state =
        TestExecutionChecklistState(TestExecutionChecklistItem.values);

    expect(state.isComplete, isTrue);
    expect(state.nextItem, isNull);
    expect(state.progressSemanticsLabel, contains('모든 테스트 실행 항목을 완료'));
  });

  test('item semantics are concrete and accessible', () {
    expect(
      TestExecutionChecklistItem.stopCue.checkedSemanticsLabel(false),
      contains('안내, 정지 cue 확인, 미완료'),
    );
    expect(
      TestExecutionChecklistItem.stationaryAiAnalysis.detail,
      '러너가 정지한 상태에서만 실제 AI 분석을 확인합니다.',
    );
  });

  test('checklist text does not contain forbidden data fields or overclaims',
      () {
    final state = TestExecutionChecklistState();
    final rendered = [
      state.progressLabel,
      state.progressSemanticsLabel,
      for (final item in TestExecutionChecklistItem.values) ...[
        item.categoryLabel,
        item.label,
        item.detail,
        item.checkedSemanticsLabel(false),
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
  });
}

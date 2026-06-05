import 'package:connect_mobile/features/live/field_test_start_checklist.dart';
import 'package:test/test.dart';

void main() {
  test('blocks start when no item is checked', () {
    final state = FieldTestStartChecklistState();

    expect(state.canStart, isFalse);
    expect(state.completedCount, 0);
    expect(state.nextMissingItem, FieldTestStartChecklistItem.controlledRoute);
    expect(state.blockedReason, contains('제어된 코스'));
  });

  test('blocks start when one required item is missing', () {
    final completed = FieldTestStartChecklistState.items.where(
      (item) => item != FieldTestStartChecklistItem.permissions,
    );
    final state = FieldTestStartChecklistState(completed);

    expect(state.canStart, isFalse);
    expect(state.nextMissingItem, FieldTestStartChecklistItem.permissions);
    expect(state.startStatusLabel, contains('카메라/마이크 권한'));
  });

  test('allows start when every item is complete', () {
    final state =
        FieldTestStartChecklistState(FieldTestStartChecklistState.items);

    expect(state.canStart, isTrue);
    expect(state.nextMissingItem, isNull);
    expect(state.startStatusLabel, contains('시작할 수 있습니다'));
  });

  test('TalkBack summary includes the next required item', () {
    final state = FieldTestStartChecklistState([
      FieldTestStartChecklistItem.controlledRoute,
      FieldTestStartChecklistItem.backupPerson,
    ]);

    expect(state.talkBackSummary, contains('다음 항목'));
    expect(state.talkBackSummary, contains('배터리/네트워크'));
  });

  test('checklist text does not contain sensitive fields or overclaims', () {
    final state =
        FieldTestStartChecklistState(FieldTestStartChecklistState.items);
    final rendered = state.renderedText;

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

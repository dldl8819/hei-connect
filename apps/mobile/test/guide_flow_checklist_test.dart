import 'package:connect_mobile/features/live/guide_flow_checklist.dart';
import 'package:test/test.dart';

void main() {
  test('starts at 0 of 5 and blocks AI assist', () {
    final state = GuideFlowChecklistState();

    expect(state.confirmedCount, 0);
    expect(state.totalCount, 5);
    expect(state.statusLabel, '0/5 확인');
    expect(state.nextMissingItem, GuideFlowChecklistItem.webRtcVideo);
    expect(state.allowsAiAssist, isFalse);
  });

  test('tracks partial confirmation and next missing item', () {
    final state = GuideFlowChecklistState([
      GuideFlowChecklistItem.webRtcVideo,
      GuideFlowChecklistItem.guideVoice,
    ]);

    expect(state.confirmedCount, 2);
    expect(state.statusLabel, '2/5 확인');
    expect(state.nextMissingItem, GuideFlowChecklistItem.cueButtons);
    expect(state.allowsAiAssist, isFalse);
  });

  test('allows AI assist only after all guide-flow items are confirmed', () {
    final state = GuideFlowChecklistState(GuideFlowChecklistState.items);

    expect(state.confirmedCount, state.totalCount);
    expect(state.statusLabel, '확인 완료');
    expect(state.nextMissingItem, isNull);
    expect(state.allowsAiAssist, isTrue);
  });

  test('blocks AI assist again when a confirmed item is unchecked', () {
    final complete = GuideFlowChecklistState(GuideFlowChecklistState.items);
    final state = complete.updateItem(
      GuideFlowChecklistItem.shortChatTts,
      false,
    );

    expect(state.confirmedCount, 4);
    expect(state.statusLabel, '4/5 확인');
    expect(state.nextMissingItem, GuideFlowChecklistItem.shortChatTts);
    expect(state.allowsAiAssist, isFalse);
  });
}

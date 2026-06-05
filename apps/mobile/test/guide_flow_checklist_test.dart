import 'package:connect_mobile/features/live/guide_flow_checklist.dart';
import 'package:test/test.dart';

void main() {
  test('starts at 0 of 5 and blocks AI assist', () {
    final state = GuideFlowChecklistState();

    expect(state.confirmedCount, 0);
    expect(state.totalCount, 5);
    expect(state.statusLabel, '0/5 확인');
    expect(state.progressLabel, '가이드 흐름 0/5 확인');
    expect(state.aiAssistGateLabel, 'AI 보조 잠김: 가이드 흐름 0/5 확인');
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
    expect(
      state.progressSemanticsLabel,
      '가이드 흐름 5개 중 2개 확인. AI 보조는 잠겨 있습니다. 다음 확인 항목은 cue 버튼입니다.',
    );
    expect(state.nextActionTitle, 'cue 버튼 확인');
    expect(
      state.nextActionDetail,
      '감속, 유지, 정지 같은 cue 버튼 안내가 TTS로 전달되는지 확인합니다.',
    );
    expect(state.nextMissingItem, GuideFlowChecklistItem.cueButtons);
    expect(state.allowsAiAssist, isFalse);
  });

  test('allows AI assist only after all guide-flow items are confirmed', () {
    final state = GuideFlowChecklistState(GuideFlowChecklistState.items);

    expect(state.confirmedCount, state.totalCount);
    expect(state.statusLabel, '확인 완료');
    expect(state.progressLabel, '가이드 흐름 확인 완료');
    expect(
      state.progressSemanticsLabel,
      '가이드 흐름 5개 항목 모두 확인 완료. AI 보조를 켤 수 있습니다.',
    );
    expect(state.aiAssistGateLabel, 'AI 보조 사용 가능');
    expect(state.nextActionTitle, '가이드 흐름 확인 완료');
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

  test('describes individual checklist items for accessibility', () {
    expect(
      GuideFlowChecklistItem.guideVoice.checkedSemanticsLabel(false),
      '가이드 음성, 미확인',
    );
    expect(
      GuideFlowChecklistItem.guideVoice.checkedSemanticsLabel(true),
      '가이드 음성, 확인됨',
    );
    expect(
      GuideFlowChecklistItem.guideVoice.checkHint,
      '가이드의 짧은 음성 안내가 러너에게 명확히 들리는지 확인합니다. 확인됐을 때만 체크합니다.',
    );
  });
}

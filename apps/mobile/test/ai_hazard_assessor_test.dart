import 'package:connect_mobile/core/safety/voice_cues.dart';
import 'package:connect_mobile/features/ai/ai_hazard_assessor.dart';
import 'package:connect_mobile/features/ai/ai_vision_models.dart';
import 'package:test/test.dart';

void main() {
  const assessor = AiHazardAssessor();

  test('recommends stop for a close object in the forward path', () {
    final decision = assessor.assess(
      const [
        AiDetectedObject(
          label: 'object',
          confidence: 0.72,
          areaRatio: 0.22,
          centerXRatio: 0.5,
          centerYRatio: 0.58,
        ),
      ],
    );

    expect(decision.level, AiHazardLevel.stop);
    expect(decision.cue, VoiceCue.stopNow);
    expect(decision.shouldPauseRunner, isTrue);
  });

  test('recommends caution for a medium object ahead', () {
    final decision = assessor.assess(
      const [
        AiDetectedObject(
          label: 'object',
          confidence: 0.72,
          areaRatio: 0.09,
          centerXRatio: 0.48,
          centerYRatio: 0.45,
        ),
      ],
    );

    expect(decision.level, AiHazardLevel.caution);
    expect(decision.cue, VoiceCue.slowDown);
    expect(decision.shouldPauseRunner, isFalse);
  });

  test('ignores low-confidence detections', () {
    final decision = assessor.assess(
      const [
        AiDetectedObject(
          label: 'person',
          confidence: 0.2,
          areaRatio: 0.4,
          centerXRatio: 0.5,
          centerYRatio: 0.7,
        ),
      ],
    );

    expect(decision.level, AiHazardLevel.clear);
  });

  test('ignores objects outside the forward path', () {
    final decision = assessor.assess(
      const [
        AiDetectedObject(
          label: 'object',
          confidence: 0.8,
          areaRatio: 0.3,
          centerXRatio: 0.94,
          centerYRatio: 0.7,
        ),
      ],
    );

    expect(decision.level, AiHazardLevel.clear);
  });

  test('labels fresh and stale AI decisions by age', () {
    final decidedAt = DateTime(2026, 1, 1, 9);
    final decision = AiHazardDecision.clear(decidedAt: decidedAt);

    expect(
      decision.isStaleAt(decidedAt.add(const Duration(seconds: 9))),
      isFalse,
    );
    expect(
      decision.isStaleAt(decidedAt.add(const Duration(seconds: 11))),
      isTrue,
    );
    expect(
      decision.ageLabelAt(decidedAt.add(const Duration(seconds: 3))),
      '3초 전',
    );
    expect(
      decision.ageLabelAt(decidedAt.add(const Duration(minutes: 2))),
      '2분 전',
    );
  });

  test('does not report negative age when device time moves backwards', () {
    final decidedAt = DateTime(2026, 1, 1, 9);
    final decision = AiHazardDecision.clear(decidedAt: decidedAt);

    expect(
      decision.ageAt(decidedAt.subtract(const Duration(seconds: 5))),
      Duration.zero,
    );
    expect(
      decision.ageLabelAt(decidedAt.subtract(const Duration(seconds: 5))),
      '방금',
    );
  });
}

import '../../core/safety/voice_cues.dart';
import 'ai_vision_models.dart';

class AiHazardAssessor {
  const AiHazardAssessor({
    this.minimumConfidence = 0.45,
    this.cautionAreaRatio = 0.08,
    this.stopAreaRatio = 0.18,
  });

  final double minimumConfidence;
  final double cautionAreaRatio;
  final double stopAreaRatio;

  static const Set<String> _criticalLabels = {
    'person',
    'pedestrian',
    'runner',
    'cyclist',
    'bicycle',
    'bike',
    'motorcycle',
    'motorbike',
    'scooter',
    'car',
    'vehicle',
    'bus',
    'truck',
    'dog',
    'animal',
  };

  static const Set<String> _cautionLabels = {
    'barrier',
    'bench',
    'chair',
    'cone',
    'curb',
    'pole',
    'roadblock',
    'sign',
    'stairs',
    'step',
    'table',
  };

  AiHazardDecision assess(
    List<AiDetectedObject> objects, {
    DateTime? now,
  }) {
    final decidedAt = now ?? DateTime.now();
    final candidates = objects
        .where(
          (object) =>
              object.confidence >= minimumConfidence && object.isInForwardPath,
        )
        .toList()
      ..sort(_compareByRisk);

    if (candidates.isEmpty) {
      return AiHazardDecision.clear(objects: objects, decidedAt: decidedAt);
    }

    final nearest = candidates.first;
    final label = nearest.displayLabel.toLowerCase();
    final critical = _containsAny(label, _criticalLabels);
    final caution = _containsAny(label, _cautionLabels);
    final isLargeAndLow =
        nearest.areaRatio >= stopAreaRatio && nearest.centerYRatio >= 0.48;
    final isVeryLow =
        nearest.areaRatio >= cautionAreaRatio && nearest.centerYRatio >= 0.68;

    if ((critical && nearest.isLowerFrame) || isLargeAndLow || isVeryLow) {
      return AiHazardDecision(
        level: AiHazardLevel.stop,
        cue: VoiceCue.stopNow,
        spokenText: 'AI 보조. 가까운 물체가 있습니다. 잠깐 멈추세요.',
        reason: '${nearest.displayLabel} 감지, 정지 권고',
        objects: candidates,
        decidedAt: decidedAt,
      );
    }

    if (caution ||
        nearest.areaRatio >= cautionAreaRatio ||
        nearest.isLowerFrame) {
      return AiHazardDecision(
        level: AiHazardLevel.caution,
        cue: _cautionCueFor(nearest),
        spokenText: 'AI 보조. 앞쪽을 확인해 주세요. 천천히 가세요.',
        reason: '${nearest.displayLabel} 감지, 감속 권고',
        objects: candidates,
        decidedAt: decidedAt,
      );
    }

    return AiHazardDecision.clear(objects: candidates, decidedAt: decidedAt);
  }

  int _compareByRisk(AiDetectedObject a, AiDetectedObject b) {
    return _riskScore(b).compareTo(_riskScore(a));
  }

  double _riskScore(AiDetectedObject object) {
    final laneWeight = 1 - ((object.centerXRatio - 0.5).abs() * 1.2);
    final labelWeight = _containsAny(
      object.displayLabel.toLowerCase(),
      _criticalLabels,
    )
        ? 0.28
        : 0.0;

    return object.areaRatio +
        (object.centerYRatio * 0.22) +
        (laneWeight.clamp(0.0, 1.0) * 0.08) +
        labelWeight;
  }

  bool _containsAny(String label, Set<String> targets) {
    for (final target in targets) {
      if (label.contains(target)) {
        return true;
      }
    }
    return false;
  }

  VoiceCue _cautionCueFor(AiDetectedObject object) {
    final label = object.displayLabel.toLowerCase();
    if (_containsAny(label, {'curb', 'stairs', 'step'})) {
      return VoiceCue.curbAhead;
    }
    return VoiceCue.slowDown;
  }
}

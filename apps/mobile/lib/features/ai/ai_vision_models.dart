import '../../core/safety/voice_cues.dart';

const aiDecisionFreshnessWindow = Duration(seconds: 10);

enum AiHazardLevel {
  clear,
  caution,
  stop,
}

extension AiHazardLevelLabel on AiHazardLevel {
  String get label {
    return switch (this) {
      AiHazardLevel.clear => '정상',
      AiHazardLevel.caution => '감속',
      AiHazardLevel.stop => '정지',
    };
  }
}

class AiDetectedObject {
  const AiDetectedObject({
    required this.label,
    required this.confidence,
    required this.areaRatio,
    required this.centerXRatio,
    required this.centerYRatio,
  });

  final String label;
  final double confidence;
  final double areaRatio;
  final double centerXRatio;
  final double centerYRatio;

  String get displayLabel {
    final trimmed = label.trim();
    return trimmed.isEmpty ? 'object' : trimmed;
  }

  bool get isInForwardPath {
    return centerXRatio >= 0.18 && centerXRatio <= 0.82;
  }

  bool get isLowerFrame {
    return centerYRatio >= 0.52;
  }
}

class AiHazardDecision {
  const AiHazardDecision({
    required this.level,
    required this.cue,
    required this.spokenText,
    required this.reason,
    required this.objects,
    required this.decidedAt,
  });

  final AiHazardLevel level;
  final VoiceCue cue;
  final String spokenText;
  final String reason;
  final List<AiDetectedObject> objects;
  final DateTime decidedAt;

  bool get shouldSpeak => level != AiHazardLevel.clear;
  bool get shouldPauseRunner => level == AiHazardLevel.stop;

  Duration ageAt(DateTime now) {
    final age = now.difference(decidedAt);
    return age.isNegative ? Duration.zero : age;
  }

  bool isStaleAt(
    DateTime now, {
    Duration maxAge = aiDecisionFreshnessWindow,
  }) {
    return ageAt(now) > maxAge;
  }

  String ageLabelAt(DateTime now) {
    final age = ageAt(now);
    if (age.inSeconds < 2) {
      return '방금';
    }
    if (age.inMinutes < 1) {
      return '${age.inSeconds}초 전';
    }
    if (age.inHours < 1) {
      return '${age.inMinutes}분 전';
    }
    return '${age.inHours}시간 전';
  }

  factory AiHazardDecision.clear({
    List<AiDetectedObject> objects = const [],
    DateTime? decidedAt,
  }) {
    return AiHazardDecision(
      level: AiHazardLevel.clear,
      cue: VoiceCue.holdPace,
      spokenText: '',
      reason: '위험 신호 없음',
      objects: objects,
      decidedAt: decidedAt ?? DateTime.now(),
    );
  }
}

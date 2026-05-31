import 'dart:async';

import 'package:flutter/foundation.dart';

import 'ai_hazard_assessor.dart';
import 'ai_vision_models.dart';
import 'mlkit_object_detector.dart';

typedef AiFrameCapture = Future<Uint8List?> Function();
typedef AiDecisionHandler = void Function(AiHazardDecision decision);

class AiVisionAssistController extends ChangeNotifier {
  AiVisionAssistController({
    required AiFrameCapture captureFrame,
    required AiDecisionHandler onDecision,
    AiHazardAssessor assessor = const AiHazardAssessor(),
    MlkitObjectDetector? detector,
    Duration interval = const Duration(seconds: 2),
    Duration announcementCooldown = const Duration(seconds: 5),
  })  : _captureFrame = captureFrame,
        _onDecision = onDecision,
        _assessor = assessor,
        _detector = detector ?? MlkitObjectDetector(),
        _interval = interval,
        _announcementCooldown = announcementCooldown;

  final AiFrameCapture _captureFrame;
  final AiDecisionHandler _onDecision;
  final AiHazardAssessor _assessor;
  final MlkitObjectDetector _detector;
  final Duration _interval;
  final Duration _announcementCooldown;

  Timer? _timer;
  DateTime? _lastAnnouncementAt;
  AiHazardLevel? _lastAnnouncementLevel;
  bool _disposed = false;

  bool isRunning = false;
  bool isAnalyzing = false;
  String? errorMessage;
  AiHazardDecision? lastDecision;

  void start() {
    if (_disposed || isRunning) {
      return;
    }

    isRunning = true;
    errorMessage = null;
    _notifySafely();
    unawaited(analyzeOnce());
    _timer = Timer.periodic(_interval, (_) {
      unawaited(analyzeOnce());
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    if (!isRunning && !isAnalyzing) {
      return;
    }

    isRunning = false;
    _notifySafely();
  }

  Future<void> analyzeOnce() async {
    if (_disposed || isAnalyzing) {
      return;
    }

    isAnalyzing = true;
    _notifySafely();

    try {
      final frameBytes = await _captureFrame();
      if (frameBytes == null || frameBytes.isEmpty) {
        errorMessage = 'AI 보조가 카메라 프레임을 아직 받을 수 없습니다.';
        return;
      }

      final detectedObjects = await _detector.detect(frameBytes);
      if (_disposed || !isRunning) {
        return;
      }

      final decision = _assessor.assess(detectedObjects);
      lastDecision = decision;
      errorMessage = null;

      if (_shouldAnnounce(decision)) {
        _lastAnnouncementAt = decision.decidedAt;
        _lastAnnouncementLevel = decision.level;
        _onDecision(decision);
      }
    } catch (_) {
      errorMessage = 'AI 보조 분석을 완료하지 못했습니다.';
    } finally {
      isAnalyzing = false;
      _notifySafely();
    }
  }

  bool _shouldAnnounce(AiHazardDecision decision) {
    if (!decision.shouldSpeak) {
      return false;
    }

    final lastAnnouncedAt = _lastAnnouncementAt;
    if (lastAnnouncedAt == null) {
      return true;
    }

    final cooldownActive =
        decision.decidedAt.difference(lastAnnouncedAt) < _announcementCooldown;
    if (!cooldownActive) {
      return true;
    }

    return decision.level != _lastAnnouncementLevel &&
        decision.level == AiHazardLevel.stop;
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    unawaited(_detector.dispose());
    super.dispose();
  }

  void _notifySafely() {
    if (!_disposed) {
      notifyListeners();
    }
  }
}

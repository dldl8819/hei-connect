import 'package:flutter_tts/flutter_tts.dart';

import 'voice_cues.dart';

class CueSpeaker {
  CueSpeaker({FlutterTts? tts}) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;
  bool _initialized = false;
  bool _available = true;

  Future<void> initialize() async {
    if (_initialized || !_available) {
      return;
    }

    try {
      await _tts.setLanguage('ko-KR');
      await _tts.setSpeechRate(0.55);
      await _tts.setPitch(1);
      await _tts.setVolume(1);
      await _tts.awaitSpeakCompletion(false);
      _initialized = true;
    } catch (_) {
      _available = false;
    }
  }

  Future<void> speak(VoiceCue cue) async {
    await speakText(cue.label);
  }

  Future<void> speakText(String text) async {
    await initialize();
    if (!_available) {
      return;
    }

    final normalizedText = text.trim();
    if (normalizedText.isEmpty) {
      return;
    }

    try {
      await _tts.stop();
      await _tts.speak(normalizedText);
    } catch (_) {
      _available = false;
    }
  }

  Future<void> stop() async {
    if (!_available) {
      return;
    }

    try {
      await _tts.stop();
    } catch (_) {
      _available = false;
    }
  }
}

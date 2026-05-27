import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import '../../core/safety/voice_cues.dart';
import 'live_models.dart';
import 'live_signaling_models.dart';

class LiveSessionApi {
  LiveSessionApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<Channel> createChannel({
    required String title,
    required bool supportEnabled,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/v1/channels');
    final response = await _client.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'title': title,
        'support_enabled': supportEnabled,
      }),
    );

    if (response.statusCode != 201) {
      throw LiveSessionApiException(
        '채널 생성에 실패했습니다. 이름을 확인하고 다시 시도해 주세요.',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const FormatException('Channel response must be an object.');
    }

    return Channel.fromJson(Map<String, Object?>.from(decoded));
  }

  Future<Channel> getChannelByCode(String channelCode) async {
    final normalizedChannelCode = channelCode.trim().toUpperCase();
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/v1/channels/code/'
      '${Uri.encodeComponent(normalizedChannelCode)}',
    );
    final response = await _client.get(uri);

    if (response.statusCode != 200) {
      throw LiveSessionApiException(
        '채널 코드를 찾지 못했습니다. 코드를 확인해 주세요.',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const FormatException('Channel response must be an object.');
    }

    return Channel.fromJson(Map<String, Object?>.from(decoded));
  }

  Future<SupportIntent> createSupportIntent({
    String? channelId,
    String? sessionId,
    required SupportTier tier,
    String? message,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/v1/support-intents');
    final response = await _client.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'channel_id': channelId,
        'session_id': sessionId,
        'tier': tier.apiValue,
        'message': message,
      }),
    );

    if (response.statusCode != 201) {
      throw LiveSessionApiException(
        '후원 요청을 만들지 못했습니다. 잠시 후 다시 시도해 주세요.',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const FormatException('Support intent response must be an object.');
    }

    return SupportIntent.fromJson(Map<String, Object?>.from(decoded));
  }

  Future<LiveSession> createLiveSession({
    required LiveSessionPurpose purpose,
    required LiveSourceMode sourceMode,
    RunnerVisionMode? runnerVisionMode,
    String? channelId,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/v1/live-sessions');
    final response = await _client.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'purpose': purpose.apiValue,
        'source_mode': sourceMode.apiValue,
        'runner_vision_mode': runnerVisionMode?.apiValue,
        'channel_id': channelId,
        'host_alias': null,
      }),
    );

    if (response.statusCode != 201) {
      throw LiveSessionApiException(
        '라이브 세션 생성에 실패했습니다. 잠시 후 다시 시도해 주세요.',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const FormatException('Live session response must be an object.');
    }

    return LiveSession.fromJson(Map<String, Object?>.from(decoded));
  }

  Future<LiveSession> getLiveSessionByJoinCode(String joinCode) async {
    final normalizedJoinCode = joinCode.trim().toUpperCase();
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/v1/live-sessions/join-code/'
      '${Uri.encodeComponent(normalizedJoinCode)}',
    );
    final response = await _client.get(uri);

    if (response.statusCode != 200) {
      throw LiveSessionApiException(
        '참여 코드를 찾지 못했습니다. 코드를 확인해 주세요.',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const FormatException('Live session response must be an object.');
    }

    return LiveSession.fromJson(Map<String, Object?>.from(decoded));
  }

  Future<SafetyState> updateSafetyState({
    required String sessionId,
    required SafetyState safetyState,
    String? reason,
  }) async {
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/v1/live-sessions/'
      '${Uri.encodeComponent(sessionId)}/safety',
    );
    final response = await _client.patch(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'safety_state': safetyState.apiValue,
        'reason': reason,
      }),
    );

    if (response.statusCode != 200) {
      throw LiveSessionApiException('안전 상태를 업데이트하지 못했습니다.');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const FormatException('Safety response must be an object.');
    }

    return SafetyStateApiValue.fromApiValue(
      decoded['safety_state'] as String,
    );
  }

  Future<LiveSession> updateSessionStatus({
    required String sessionId,
    required LiveSessionStatus status,
    String? reason,
  }) async {
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/v1/live-sessions/'
      '${Uri.encodeComponent(sessionId)}/status',
    );
    final response = await _client.patch(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'status': status.apiValue,
        'reason': reason,
      }),
    );

    if (response.statusCode != 200) {
      throw LiveSessionApiException('라이브 상태를 업데이트하지 못했습니다.');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const FormatException('Live session response must be an object.');
    }

    return LiveSession.fromJson(Map<String, Object?>.from(decoded));
  }

  Future<GuidanceCueEvent> createGuidanceCue({
    required String sessionId,
    required VoiceCue cue,
    CueSenderRole senderRole = CueSenderRole.supporter,
  }) async {
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/v1/live-sessions/'
      '${Uri.encodeComponent(sessionId)}/cues',
    );
    final response = await _client.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'cue': cue.apiValue,
        'sender_role': senderRole.apiValue,
      }),
    );

    if (response.statusCode != 201) {
      throw LiveSessionApiException('안내 큐를 전송하지 못했습니다.');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const FormatException('Cue response must be an object.');
    }

    return GuidanceCueEvent.fromJson(Map<String, Object?>.from(decoded));
  }

  Future<List<GuidanceCueEvent>> listGuidanceCues(String sessionId) async {
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/v1/live-sessions/'
      '${Uri.encodeComponent(sessionId)}/cues',
    );
    final response = await _client.get(uri);

    if (response.statusCode != 200) {
      throw LiveSessionApiException('안내 큐 기록을 가져오지 못했습니다.');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw const FormatException('Cue list response must be a list.');
    }

    return [
      for (final item in decoded)
        GuidanceCueEvent.fromJson(Map<String, Object?>.from(item as Map)),
    ];
  }

  Future<LiveChatMessage> createChatMessage({
    required String sessionId,
    required ChatSenderRole senderRole,
    required String body,
  }) async {
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/v1/live-sessions/'
      '${Uri.encodeComponent(sessionId)}/messages',
    );
    final response = await _client.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'sender_role': senderRole.apiValue,
        'body': body,
      }),
    );

    if (response.statusCode != 201) {
      throw LiveSessionApiException('채팅 메시지를 전송하지 못했습니다.');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const FormatException('Chat message response must be an object.');
    }

    return LiveChatMessage.fromJson(Map<String, Object?>.from(decoded));
  }

  Future<List<LiveChatMessage>> listChatMessages(String sessionId) async {
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/v1/live-sessions/'
      '${Uri.encodeComponent(sessionId)}/messages',
    );
    final response = await _client.get(uri);

    if (response.statusCode != 200) {
      throw LiveSessionApiException('채팅 메시지를 가져오지 못했습니다.');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw const FormatException('Chat message response must be a list.');
    }

    return [
      for (final item in decoded)
        LiveChatMessage.fromJson(Map<String, Object?>.from(item as Map)),
    ];
  }

  Future<SignalState> getSignalState(String sessionId) async {
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/v1/live-sessions/'
      '${Uri.encodeComponent(sessionId)}/signal',
    );
    final response = await _client.get(uri);

    if (response.statusCode != 200) {
      throw LiveSessionApiException('연결 신호 상태를 가져오지 못했습니다.');
    }

    return _decodeSignalState(response.body);
  }

  Future<SignalState> publishOffer({
    required String sessionId,
    required String sdp,
  }) async {
    return _publishSessionDescription(
      sessionId: sessionId,
      endpoint: 'offer',
      description: SessionDescription(sdpType: SdpType.offer, sdp: sdp),
    );
  }

  Future<SignalState> publishAnswer({
    required String sessionId,
    required String sdp,
  }) async {
    return _publishSessionDescription(
      sessionId: sessionId,
      endpoint: 'answer',
      description: SessionDescription(sdpType: SdpType.answer, sdp: sdp),
    );
  }

  Future<SignalState> addIceCandidate({
    required String sessionId,
    required SignalRole role,
    required IceCandidate candidate,
  }) async {
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/v1/live-sessions/'
      '${Uri.encodeComponent(sessionId)}/signal/ice-candidates',
    );
    final response = await _client.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'role': role.apiValue,
        'candidate': candidate.toJson(),
      }),
    );

    if (response.statusCode != 200) {
      throw LiveSessionApiException('ICE 후보를 등록하지 못했습니다.');
    }

    return _decodeSignalState(response.body);
  }

  Future<SignalState> _publishSessionDescription({
    required String sessionId,
    required String endpoint,
    required SessionDescription description,
  }) async {
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/v1/live-sessions/'
      '${Uri.encodeComponent(sessionId)}/signal/$endpoint',
    );
    final response = await _client.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(description.toJson()),
    );

    if (response.statusCode != 200) {
      throw LiveSessionApiException('연결 신호를 등록하지 못했습니다.');
    }

    return _decodeSignalState(response.body);
  }

  SignalState _decodeSignalState(String responseBody) {
    final decoded = jsonDecode(responseBody);
    if (decoded is! Map) {
      throw const FormatException('Signal state response must be an object.');
    }

    return SignalState.fromJson(Map<String, Object?>.from(decoded));
  }

  void close() {
    _client.close();
  }
}

class LiveSessionApiException implements Exception {
  const LiveSessionApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

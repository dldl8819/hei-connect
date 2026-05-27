import '../../core/safety/voice_cues.dart';

enum ConnectRole {
  host,
  supporter,
}

enum LiveSessionPurpose {
  audioRoom,
  runningGuide,
  dailyHelp,
  conversation,
  broadcast,
}

extension LiveSessionPurposeLabel on LiveSessionPurpose {
  String get label {
    return switch (this) {
      LiveSessionPurpose.audioRoom => 'DJ 라디오',
      LiveSessionPurpose.dailyHelp => '일상 도움',
      LiveSessionPurpose.conversation => '대화',
      LiveSessionPurpose.broadcast => '방송',
      LiveSessionPurpose.runningGuide => '러닝 가이드',
    };
  }

  String get apiValue {
    return switch (this) {
      LiveSessionPurpose.audioRoom => 'audio_room',
      LiveSessionPurpose.runningGuide => 'running_guide',
      LiveSessionPurpose.dailyHelp => 'daily_help',
      LiveSessionPurpose.conversation => 'conversation',
      LiveSessionPurpose.broadcast => 'broadcast',
    };
  }

  static LiveSessionPurpose fromApiValue(String value) {
    return switch (value) {
      'audio_room' => LiveSessionPurpose.audioRoom,
      'running_guide' => LiveSessionPurpose.runningGuide,
      'daily_help' => LiveSessionPurpose.dailyHelp,
      'conversation' => LiveSessionPurpose.conversation,
      'broadcast' => LiveSessionPurpose.broadcast,
      _ => throw FormatException('Unknown live session purpose: $value'),
    };
  }
}

enum LiveSourceMode {
  audioOnly,
  screenShare,
  selfieCamera,
  worldCamera,
}

extension LiveSourceModeLabel on LiveSourceMode {
  String get label {
    return switch (this) {
      LiveSourceMode.audioOnly => '오디오만',
      LiveSourceMode.screenShare => '컴퓨터 화면',
      LiveSourceMode.selfieCamera => '셀카 카메라',
      LiveSourceMode.worldCamera => '눈앞 카메라',
    };
  }

  String get apiValue {
    return switch (this) {
      LiveSourceMode.audioOnly => 'audio_only',
      LiveSourceMode.screenShare => 'screen_share',
      LiveSourceMode.selfieCamera => 'selfie_camera',
      LiveSourceMode.worldCamera => 'world_camera',
    };
  }

  static LiveSourceMode fromApiValue(String value) {
    return switch (value) {
      'audio_only' => LiveSourceMode.audioOnly,
      'screen_share' => LiveSourceMode.screenShare,
      'selfie_camera' => LiveSourceMode.selfieCamera,
      'world_camera' => LiveSourceMode.worldCamera,
      _ => throw FormatException('Unknown live source mode: $value'),
    };
  }
}

enum RunnerVisionMode {
  sighted,
  lowVision,
  blind,
}

extension RunnerVisionModeLabel on RunnerVisionMode {
  String get label {
    return switch (this) {
      RunnerVisionMode.sighted => '비시각장애러너',
      RunnerVisionMode.lowVision => '저시력자',
      RunnerVisionMode.blind => '전맹',
    };
  }

  String get apiValue {
    return switch (this) {
      RunnerVisionMode.sighted => 'sighted',
      RunnerVisionMode.lowVision => 'low_vision',
      RunnerVisionMode.blind => 'blind',
    };
  }

  static RunnerVisionMode fromApiValue(String value) {
    return switch (value) {
      'sighted' => RunnerVisionMode.sighted,
      'low_vision' => RunnerVisionMode.lowVision,
      'blind' => RunnerVisionMode.blind,
      _ => throw FormatException('Unknown runner vision mode: $value'),
    };
  }
}

enum LiveSessionStatus {
  waitingForSupporter,
  connected,
  live,
  paused,
  ended,
}

extension LiveSessionStatusApiValue on LiveSessionStatus {
  String get apiValue {
    return switch (this) {
      LiveSessionStatus.waitingForSupporter => 'waiting_for_supporter',
      LiveSessionStatus.connected => 'connected',
      LiveSessionStatus.live => 'live',
      LiveSessionStatus.paused => 'paused',
      LiveSessionStatus.ended => 'ended',
    };
  }

  static LiveSessionStatus fromApiValue(String value) {
    return switch (value) {
      'waiting_for_supporter' => LiveSessionStatus.waitingForSupporter,
      'connected' => LiveSessionStatus.connected,
      'live' => LiveSessionStatus.live,
      'paused' => LiveSessionStatus.paused,
      'ended' => LiveSessionStatus.ended,
      _ => throw FormatException('Unknown live session status: $value'),
    };
  }
}

enum SafetyState {
  ready,
  checkRequired,
  stopNow,
  connectionLost,
}

extension SafetyStateApiValue on SafetyState {
  String get apiValue {
    return switch (this) {
      SafetyState.ready => 'ready',
      SafetyState.checkRequired => 'check_required',
      SafetyState.stopNow => 'stop_now',
      SafetyState.connectionLost => 'connection_lost',
    };
  }

  static SafetyState fromApiValue(String value) {
    return switch (value) {
      'ready' => SafetyState.ready,
      'check_required' => SafetyState.checkRequired,
      'stop_now' => SafetyState.stopNow,
      'connection_lost' => SafetyState.connectionLost,
      _ => throw FormatException('Unknown safety state: $value'),
    };
  }
}

class Channel {
  const Channel({
    required this.channelId,
    required this.channelCode,
    required this.channelLink,
    required this.title,
    required this.supportEnabled,
  });

  final String channelId;
  final String channelCode;
  final String channelLink;
  final String title;
  final bool supportEnabled;

  factory Channel.fromJson(Map<String, Object?> json) {
    return Channel(
      channelId: json['channel_id'] as String,
      channelCode: json['channel_code'] as String,
      channelLink: json['channel_link'] as String,
      title: json['title'] as String,
      supportEnabled: json['support_enabled'] as bool,
    );
  }
}

enum SupportTier {
  small,
  medium,
  large,
}

extension SupportTierApiValue on SupportTier {
  String get apiValue {
    return switch (this) {
      SupportTier.small => 'small',
      SupportTier.medium => 'medium',
      SupportTier.large => 'large',
    };
  }

  static SupportTier fromApiValue(String value) {
    return switch (value) {
      'small' => SupportTier.small,
      'medium' => SupportTier.medium,
      'large' => SupportTier.large,
      _ => throw FormatException('Unknown support tier: $value'),
    };
  }
}

class SupportIntent {
  const SupportIntent({
    required this.supportId,
    required this.tier,
  });

  final String supportId;
  final SupportTier tier;

  factory SupportIntent.fromJson(Map<String, Object?> json) {
    return SupportIntent(
      supportId: json['support_id'] as String,
      tier: SupportTierApiValue.fromApiValue(json['tier'] as String),
    );
  }
}

enum CueSenderRole {
  supporter,
  system,
}

extension CueSenderRoleApiValue on CueSenderRole {
  String get apiValue {
    return switch (this) {
      CueSenderRole.supporter => 'supporter',
      CueSenderRole.system => 'system',
    };
  }

  static CueSenderRole fromApiValue(String value) {
    return switch (value) {
      'supporter' => CueSenderRole.supporter,
      'system' => CueSenderRole.system,
      _ => throw FormatException('Unknown cue sender role: $value'),
    };
  }
}

class GuidanceCueEvent {
  const GuidanceCueEvent({
    required this.cueEventId,
    required this.sessionId,
    required this.sequence,
    required this.cue,
    required this.senderRole,
  });

  final String cueEventId;
  final String sessionId;
  final int sequence;
  final VoiceCue cue;
  final CueSenderRole senderRole;

  factory GuidanceCueEvent.fromJson(Map<String, Object?> json) {
    return GuidanceCueEvent(
      cueEventId: json['cue_event_id'] as String,
      sessionId: json['session_id'] as String,
      sequence: json['sequence'] as int,
      cue: VoiceCueApiValue.fromApiValue(json['cue'] as String),
      senderRole: CueSenderRoleApiValue.fromApiValue(
        json['sender_role'] as String,
      ),
    );
  }
}

enum ChatSenderRole {
  host,
  supporter,
  system,
}

extension ChatSenderRoleApiValue on ChatSenderRole {
  String get apiValue {
    return switch (this) {
      ChatSenderRole.host => 'host',
      ChatSenderRole.supporter => 'supporter',
      ChatSenderRole.system => 'system',
    };
  }

  static ChatSenderRole fromApiValue(String value) {
    return switch (value) {
      'host' => ChatSenderRole.host,
      'supporter' => ChatSenderRole.supporter,
      'system' => ChatSenderRole.system,
      _ => throw FormatException('Unknown chat sender role: $value'),
    };
  }
}

class LiveChatMessage {
  const LiveChatMessage({
    required this.messageId,
    required this.sessionId,
    required this.sequence,
    required this.senderRole,
    required this.body,
  });

  final String messageId;
  final String sessionId;
  final int sequence;
  final ChatSenderRole senderRole;
  final String body;

  factory LiveChatMessage.fromJson(Map<String, Object?> json) {
    return LiveChatMessage(
      messageId: json['message_id'] as String,
      sessionId: json['session_id'] as String,
      sequence: json['sequence'] as int,
      senderRole: ChatSenderRoleApiValue.fromApiValue(
        json['sender_role'] as String,
      ),
      body: json['body'] as String,
    );
  }
}

class LiveSession {
  const LiveSession({
    required this.sessionId,
    required this.joinCode,
    required this.joinLink,
    required this.channelId,
    required this.purpose,
    required this.sourceMode,
    required this.runnerVisionMode,
    required this.status,
    required this.safetyState,
  });

  final String sessionId;
  final String joinCode;
  final String joinLink;
  final String? channelId;
  final LiveSessionPurpose purpose;
  final LiveSourceMode sourceMode;
  final RunnerVisionMode? runnerVisionMode;
  final LiveSessionStatus status;
  final SafetyState safetyState;

  factory LiveSession.fromJson(Map<String, Object?> json) {
    return LiveSession(
      sessionId: json['session_id'] as String,
      joinCode: json['join_code'] as String,
      joinLink: json['join_link'] as String,
      channelId: json['channel_id'] as String?,
      purpose: LiveSessionPurposeLabel.fromApiValue(json['purpose'] as String),
      sourceMode: LiveSourceModeLabel.fromApiValue(
        json['source_mode'] as String,
      ),
      runnerVisionMode: json['runner_vision_mode'] == null
          ? null
          : RunnerVisionModeLabel.fromApiValue(
              json['runner_vision_mode'] as String,
            ),
      status: LiveSessionStatusApiValue.fromApiValue(json['status'] as String),
      safetyState: SafetyStateApiValue.fromApiValue(
        json['safety_state'] as String,
      ),
    );
  }
}

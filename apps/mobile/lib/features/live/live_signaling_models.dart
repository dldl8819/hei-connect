enum SignalRole {
  host,
  supporter,
}

extension SignalRoleApiValue on SignalRole {
  String get apiValue {
    return switch (this) {
      SignalRole.host => 'host',
      SignalRole.supporter => 'supporter',
    };
  }

  static SignalRole fromApiValue(String value) {
    return switch (value) {
      'host' => SignalRole.host,
      'supporter' => SignalRole.supporter,
      _ => throw FormatException('Unknown signal role: $value'),
    };
  }
}

enum SdpType {
  offer,
  answer,
}

extension SdpTypeApiValue on SdpType {
  String get apiValue {
    return switch (this) {
      SdpType.offer => 'offer',
      SdpType.answer => 'answer',
    };
  }

  static SdpType fromApiValue(String value) {
    return switch (value) {
      'offer' => SdpType.offer,
      'answer' => SdpType.answer,
      _ => throw FormatException('Unknown SDP type: $value'),
    };
  }
}

class SessionDescription {
  const SessionDescription({
    required this.sdpType,
    required this.sdp,
  });

  final SdpType sdpType;
  final String sdp;

  Map<String, Object?> toJson() {
    return {
      'sdp_type': sdpType.apiValue,
      'sdp': sdp,
    };
  }

  factory SessionDescription.fromJson(Map<String, Object?> json) {
    return SessionDescription(
      sdpType: SdpTypeApiValue.fromApiValue(json['sdp_type'] as String),
      sdp: json['sdp'] as String,
    );
  }
}

class IceCandidate {
  const IceCandidate({
    required this.candidate,
    this.sdpMid,
    this.sdpMLineIndex,
    this.usernameFragment,
  });

  final String candidate;
  final String? sdpMid;
  final int? sdpMLineIndex;
  final String? usernameFragment;

  Map<String, Object?> toJson() {
    return {
      'candidate': candidate,
      'sdp_mid': sdpMid,
      'sdp_m_line_index': sdpMLineIndex,
      'username_fragment': usernameFragment,
    };
  }

  factory IceCandidate.fromJson(Map<String, Object?> json) {
    return IceCandidate(
      candidate: json['candidate'] as String,
      sdpMid: json['sdp_mid'] as String?,
      sdpMLineIndex: json['sdp_m_line_index'] as int?,
      usernameFragment: json['username_fragment'] as String?,
    );
  }
}

class SignalState {
  const SignalState({
    required this.sessionId,
    required this.hostIceCandidates,
    required this.supporterIceCandidates,
    this.offer,
    this.answer,
  });

  final String sessionId;
  final SessionDescription? offer;
  final SessionDescription? answer;
  final List<IceCandidate> hostIceCandidates;
  final List<IceCandidate> supporterIceCandidates;

  bool get hasOffer => offer != null;

  bool get hasAnswer => answer != null;

  factory SignalState.fromJson(Map<String, Object?> json) {
    final offerJson = json['offer'];
    final answerJson = json['answer'];

    return SignalState(
      sessionId: json['session_id'] as String,
      offer: offerJson is Map
          ? SessionDescription.fromJson(Map<String, Object?>.from(offerJson))
          : null,
      answer: answerJson is Map
          ? SessionDescription.fromJson(Map<String, Object?>.from(answerJson))
          : null,
      hostIceCandidates: _parseCandidates(json['host_ice_candidates']),
      supporterIceCandidates: _parseCandidates(
        json['supporter_ice_candidates'],
      ),
    );
  }

  static List<IceCandidate> _parseCandidates(Object? value) {
    if (value is! List) {
      return const [];
    }

    return [
      for (final item in value)
        if (item is Map) IceCandidate.fromJson(Map<String, Object?>.from(item)),
    ];
  }
}

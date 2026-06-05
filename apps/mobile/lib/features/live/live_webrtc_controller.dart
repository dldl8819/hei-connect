import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'live_models.dart';
import 'live_session_api.dart';
import 'live_signaling_models.dart' as signal;

enum WebRtcPhase {
  idle,
  starting,
  waitingForAnswer,
  connected,
  connectionLost,
  failed,
  closed,
}

extension WebRtcPhaseLabel on WebRtcPhase {
  String get label {
    return switch (this) {
      WebRtcPhase.idle => '대기',
      WebRtcPhase.starting => '연결 준비',
      WebRtcPhase.waitingForAnswer => '응답 대기',
      WebRtcPhase.connected => '연결됨',
      WebRtcPhase.connectionLost => '연결 끊김',
      WebRtcPhase.failed => '실패',
      WebRtcPhase.closed => '종료',
    };
  }
}

enum _SignalPollingMode {
  host,
  supporter,
}

class LiveWebRtcController extends ChangeNotifier {
  LiveWebRtcController({required LiveSessionApi api}) : _api = api;

  static const Duration _signalPollInterval = Duration(seconds: 2);
  static const int _maxSignalFailuresBeforeStop = 3;
  static const String _transientSignalErrorMessage =
      '신호 상태를 갱신하지 못했습니다. 다시 확인 중입니다.';
  static const String _connectionLostMessage = '연결이 끊겼습니다. 즉시 정지해 주세요.';

  final LiveSessionApi _api;
  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  Timer? _signalPollTimer;
  bool _initialized = false;
  bool _remoteDescriptionSet = false;
  bool _isPollingSignal = false;
  bool _disposed = false;
  int _consecutiveSignalFailures = 0;
  final Set<String> _appliedRemoteCandidates = <String>{};

  WebRtcPhase phase = WebRtcPhase.idle;
  signal.SignalState? signalState;
  String? errorMessage;
  bool safetyStopRequired = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    await localRenderer.initialize();
    await remoteRenderer.initialize();
    _initialized = true;
  }

  Future<void> startHost(LiveSession session) async {
    await initialize();
    await _resetPeerConnection();
    errorMessage = null;
    _setPhase(WebRtcPhase.starting);

    try {
      _localStream = await _createLocalStream(session.sourceMode);
      localRenderer.srcObject = _localStream;

      final peerConnection = await _createPeerConnection(
        sessionId: session.sessionId,
        role: signal.SignalRole.host,
      );
      _peerConnection = peerConnection;

      for (final track in _localStream!.getTracks()) {
        await peerConnection.addTrack(track, _localStream!);
      }

      final offer = await peerConnection.createOffer();
      await peerConnection.setLocalDescription(offer);
      final sdp = offer.sdp;
      if (sdp == null || sdp.trim().isEmpty) {
        throw const LiveWebRtcException('offer SDP를 만들지 못했습니다.');
      }

      signalState = await _api.publishOffer(
        sessionId: session.sessionId,
        sdp: sdp,
      );
      _setPhase(WebRtcPhase.waitingForAnswer);
      _startSignalPolling(session: session, mode: _SignalPollingMode.host);
    } catch (error) {
      await _fail(error);
    }
  }

  Future<void> joinAsSupporter(LiveSession session) async {
    await initialize();
    await _resetPeerConnection();
    errorMessage = null;
    _setPhase(WebRtcPhase.starting);

    try {
      final currentSignalState = await _api.getSignalState(session.sessionId);
      final offer = currentSignalState.offer;
      if (offer == null) {
        throw const LiveWebRtcException('아직 송출자의 offer가 없습니다.');
      }

      final peerConnection = await _createPeerConnection(
        sessionId: session.sessionId,
        role: signal.SignalRole.supporter,
      );
      _peerConnection = peerConnection;

      final audioStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': false,
      });
      _localStream = audioStream;
      for (final track in audioStream.getTracks()) {
        await peerConnection.addTrack(track, audioStream);
      }

      await peerConnection.setRemoteDescription(
        RTCSessionDescription(offer.sdp, offer.sdpType.apiValue),
      );
      _remoteDescriptionSet = true;
      await _applyRemoteCandidates(currentSignalState.hostIceCandidates);

      final answer = await peerConnection.createAnswer();
      await peerConnection.setLocalDescription(answer);
      final sdp = answer.sdp;
      if (sdp == null || sdp.trim().isEmpty) {
        throw const LiveWebRtcException('answer SDP를 만들지 못했습니다.');
      }

      signalState = await _api.publishAnswer(
        sessionId: session.sessionId,
        sdp: sdp,
      );
      _setPhase(WebRtcPhase.connected);
      _startSignalPolling(session: session, mode: _SignalPollingMode.supporter);
    } catch (error) {
      await _fail(error);
    }
  }

  Future<void> refreshHostSignal(LiveSession session) async {
    final peerConnection = _peerConnection;
    if (peerConnection == null) {
      signalState = await _api.getSignalState(session.sessionId);
      _notifySafely();
      return;
    }

    final currentSignalState = await _api.getSignalState(session.sessionId);
    signalState = currentSignalState;

    if (!_remoteDescriptionSet && currentSignalState.answer != null) {
      final answer = currentSignalState.answer!;
      await peerConnection.setRemoteDescription(
        RTCSessionDescription(answer.sdp, answer.sdpType.apiValue),
      );
      _remoteDescriptionSet = true;
      _setPhase(WebRtcPhase.connected);
    }

    await _applyRemoteCandidates(currentSignalState.supporterIceCandidates);
    _notifySafely();
  }

  Future<void> refreshSupporterSignal(LiveSession session) async {
    final currentSignalState = await _api.getSignalState(session.sessionId);
    signalState = currentSignalState;
    await _applyRemoteCandidates(currentSignalState.hostIceCandidates);
    _notifySafely();
  }

  Future<void> stop() async {
    await _resetPeerConnection();
    _setPhase(WebRtcPhase.closed);
  }

  Future<Uint8List?> captureLocalVideoFrame() async {
    final localStream = _localStream;
    if (localStream == null) {
      return null;
    }

    final videoTracks = localStream.getVideoTracks();
    if (videoTracks.isEmpty) {
      return null;
    }

    try {
      final frame = await videoTracks.first.captureFrame();
      return frame.asUint8List();
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _stopSignalPolling();

    final peerConnection = _peerConnection;
    _peerConnection = null;
    if (peerConnection != null) {
      unawaited(peerConnection.close());
    }

    final localStream = _localStream;
    _localStream = null;
    if (localStream != null) {
      for (final track in localStream.getTracks()) {
        unawaited(track.stop());
      }
      unawaited(localStream.dispose());
    }

    if (_initialized) {
      localRenderer.dispose();
      remoteRenderer.dispose();
    }
    super.dispose();
  }

  void _startSignalPolling({
    required LiveSession session,
    required _SignalPollingMode mode,
  }) {
    _stopSignalPolling();
    unawaited(_pollSignal(session: session, mode: mode));
    _signalPollTimer = Timer.periodic(_signalPollInterval, (_) {
      unawaited(_pollSignal(session: session, mode: mode));
    });
  }

  void _stopSignalPolling() {
    _signalPollTimer?.cancel();
    _signalPollTimer = null;
    _isPollingSignal = false;
  }

  Future<void> _pollSignal({
    required LiveSession session,
    required _SignalPollingMode mode,
  }) async {
    if (_disposed ||
        _isPollingSignal ||
        phase == WebRtcPhase.failed ||
        phase == WebRtcPhase.connectionLost ||
        phase == WebRtcPhase.closed) {
      return;
    }

    _isPollingSignal = true;
    try {
      if (mode == _SignalPollingMode.host) {
        await refreshHostSignal(session);
      } else {
        await refreshSupporterSignal(session);
      }
      _consecutiveSignalFailures = 0;
      if (!safetyStopRequired && errorMessage == _transientSignalErrorMessage) {
        errorMessage = null;
        _notifySafely();
      }
    } on LiveSessionApiException catch (error) {
      _handleSignalFailure(error.message);
    } catch (_) {
      _handleSignalFailure(_transientSignalErrorMessage);
    } finally {
      _isPollingSignal = false;
    }
  }

  Future<MediaStream> _createLocalStream(LiveSourceMode sourceMode) {
    return switch (sourceMode) {
      LiveSourceMode.audioOnly => navigator.mediaDevices.getUserMedia({
          'audio': true,
          'video': false,
        }),
      LiveSourceMode.selfieCamera => navigator.mediaDevices.getUserMedia({
          'audio': true,
          'video': {
            'facingMode': 'user',
          },
        }),
      LiveSourceMode.worldCamera => navigator.mediaDevices.getUserMedia({
          'audio': true,
          'video': {
            'facingMode': 'environment',
          },
        }),
      LiveSourceMode.screenShare => navigator.mediaDevices.getDisplayMedia({
          'audio': true,
          'video': true,
        }),
    };
  }

  Future<RTCPeerConnection> _createPeerConnection({
    required String sessionId,
    required signal.SignalRole role,
  }) async {
    final peerConnection = await createPeerConnection({
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ],
    });

    peerConnection.onIceConnectionState = (state) {
      if (!identical(_peerConnection, peerConnection)) {
        return;
      }

      final normalizedState = state.toString().toLowerCase();
      if (normalizedState.contains('disconnected') ||
          normalizedState.contains('failed')) {
        _markConnectionLost(_connectionLostMessage);
        return;
      }

      if (normalizedState.contains('connected') ||
          normalizedState.contains('completed')) {
        if (_remoteDescriptionSet && phase != WebRtcPhase.connected) {
          _setPhase(WebRtcPhase.connected);
        }
        return;
      }

      if (normalizedState.contains('closed') &&
          phase != WebRtcPhase.connectionLost) {
        _setPhase(WebRtcPhase.closed);
      }
    };

    peerConnection.onIceCandidate = (candidate) {
      if (!identical(_peerConnection, peerConnection)) {
        return;
      }

      final rawCandidate = candidate.candidate;
      if (rawCandidate == null || rawCandidate.trim().isEmpty) {
        return;
      }

      unawaited(
        _api
            .addIceCandidate(
          sessionId: sessionId,
          role: role,
          candidate: signal.IceCandidate(
            candidate: rawCandidate,
            sdpMid: candidate.sdpMid,
            sdpMLineIndex: candidate.sdpMLineIndex,
          ),
        )
            .then((state) {
          signalState = state;
          _notifySafely();
        }).catchError((Object error) {
          errorMessage = 'ICE 후보를 전송하지 못했습니다.';
          _notifySafely();
        }),
      );
    };

    peerConnection.onTrack = (event) {
      if (!identical(_peerConnection, peerConnection)) {
        return;
      }

      if (event.streams.isEmpty) {
        return;
      }

      remoteRenderer.srcObject = event.streams.first;
      _notifySafely();
    };

    return peerConnection;
  }

  Future<void> _applyRemoteCandidates(
    List<signal.IceCandidate> candidates,
  ) async {
    final peerConnection = _peerConnection;
    if (peerConnection == null || !_remoteDescriptionSet) {
      return;
    }

    for (final candidate in candidates) {
      final key = '${candidate.candidate}|${candidate.sdpMid}|'
          '${candidate.sdpMLineIndex}';
      if (_appliedRemoteCandidates.contains(key)) {
        continue;
      }

      await peerConnection.addCandidate(
        RTCIceCandidate(
          candidate.candidate,
          candidate.sdpMid,
          candidate.sdpMLineIndex,
        ),
      );
      _appliedRemoteCandidates.add(key);
    }
  }

  Future<void> _resetPeerConnection() async {
    _stopSignalPolling();
    safetyStopRequired = false;
    _consecutiveSignalFailures = 0;

    final peerConnection = _peerConnection;
    _peerConnection = null;
    _remoteDescriptionSet = false;
    _appliedRemoteCandidates.clear();

    if (peerConnection != null) {
      await peerConnection.close();
    }

    final localStream = _localStream;
    _localStream = null;
    if (localStream != null) {
      for (final track in localStream.getTracks()) {
        await track.stop();
      }
      await localStream.dispose();
    }

    localRenderer.srcObject = null;
    remoteRenderer.srcObject = null;
  }

  Future<void> _fail(Object error) async {
    errorMessage = _safeStartErrorMessage(error);
    await _resetPeerConnection();
    _setPhase(WebRtcPhase.failed);
  }

  String _safeStartErrorMessage(Object error) {
    if (error is LiveWebRtcException) {
      return error.message;
    }

    final normalized = error.toString().toLowerCase();
    if (normalized.contains('permission') ||
        normalized.contains('denied') ||
        normalized.contains('notallowed')) {
      return '카메라 또는 마이크 권한을 사용할 수 없습니다. 권한을 확인하고 정지 상태에서 다시 시작해 주세요.';
    }
    if (normalized.contains('camera') ||
        normalized.contains('video') ||
        normalized.contains('notfound')) {
      return '카메라를 시작하지 못했습니다. 다른 앱 사용 여부와 눈앞 카메라 설정을 확인해 주세요.';
    }
    if (normalized.contains('microphone') || normalized.contains('audio')) {
      return '마이크를 시작하지 못했습니다. 마이크 권한과 오디오 입력을 확인해 주세요.';
    }
    if (normalized.contains('display') || normalized.contains('screen')) {
      return '화면 공유를 시작하지 못했습니다. 화면 공유 권한과 소스 선택을 확인해 주세요.';
    }

    return 'WebRTC 연결을 시작하지 못했습니다. 정지 상태에서 권한, 카메라, 마이크를 확인해 주세요.';
  }

  void _handleSignalFailure(String message) {
    _consecutiveSignalFailures += 1;
    if (_consecutiveSignalFailures >= _maxSignalFailuresBeforeStop) {
      _markConnectionLost(_connectionLostMessage);
      return;
    }

    errorMessage = message;
    _notifySafely();
  }

  void _markConnectionLost(String message) {
    if (phase == WebRtcPhase.connectionLost || phase == WebRtcPhase.closed) {
      return;
    }

    safetyStopRequired = true;
    errorMessage = message;
    _stopSignalPolling();
    _setPhase(WebRtcPhase.connectionLost);
  }

  void _setPhase(WebRtcPhase nextPhase) {
    phase = nextPhase;
    _notifySafely();
  }

  void _notifySafely() {
    if (!_disposed) {
      notifyListeners();
    }
  }
}

class LiveWebRtcException implements Exception {
  const LiveWebRtcException(this.message);

  final String message;
}

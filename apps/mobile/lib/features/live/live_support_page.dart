import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../core/safety/screen_awake.dart';
import '../../core/safety/voice_cues.dart';
import 'live_invite_parser.dart';
import 'live_chat_panel.dart';
import 'live_models.dart';
import 'live_session_api.dart';
import 'live_signaling_models.dart';
import 'live_webrtc_controller.dart';

class LiveSupportPage extends StatefulWidget {
  const LiveSupportPage({super.key, this.initialInvite});

  final String? initialInvite;

  @override
  State<LiveSupportPage> createState() => _LiveSupportPageState();
}

class _LiveSupportPageState extends State<LiveSupportPage> {
  final LiveSessionApi _api = LiveSessionApi();
  final TextEditingController _inviteController = TextEditingController();
  final ScreenAwake _screenAwake = ScreenAwake();
  late final LiveWebRtcController _webRtc;
  Timer? _cueHistoryPollTimer;

  bool _isJoining = false;
  bool _isRefreshingSignal = false;
  bool _isConnectingMedia = false;
  bool _isSendingCue = false;
  bool _hasReportedConnectionLoss = false;
  String? _errorMessage;
  Channel? _channel;
  LiveSession? _session;
  SignalState? _signalState;
  List<GuidanceCueEvent> _recentCueEvents = const [];
  VoiceCue _selectedCue = VoiceCue.stopNow;

  @override
  void initState() {
    super.initState();
    _webRtc = LiveWebRtcController(api: _api);
    _webRtc.addListener(_handleWebRtcChanged);
    _prepareInitialInvite();
  }

  @override
  void dispose() {
    _inviteController.dispose();
    _stopCueHistoryPolling();
    unawaited(_screenAwake.allowSleep());
    _webRtc.removeListener(_handleWebRtcChanged);
    _webRtc.dispose();
    _api.close();
    super.dispose();
  }

  void _prepareInitialInvite() {
    final initialInvite = widget.initialInvite?.trim();
    if (initialInvite == null || initialInvite.isEmpty) {
      return;
    }

    _inviteController.text = initialInvite;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_joinFromInput());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasSession = _session != null;

    return Scaffold(
      appBar: AppBar(title: const Text('라이브 참여')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _JoinPanel(
              controller: _inviteController,
              isJoining: _isJoining,
              errorMessage: _errorMessage,
              onJoin: _joinFromInput,
            ),
            const SizedBox(height: 16),
            AnimatedBuilder(
              animation: _webRtc,
              builder: (context, _) {
                return _RemoteVideoPlaceholder(
                  session: _session,
                  controller: _webRtc,
                );
              },
            ),
            const SizedBox(height: 12),
            AnimatedBuilder(
              animation: _webRtc,
              builder: (context, _) => _LiveRoomStatus(
                selectedCue: _selectedCue,
                session: _session,
                channel: _channel,
                signalState: _webRtc.signalState ?? _signalState,
                recentCueEvents: _recentCueEvents,
              ),
            ),
            if (_session != null) ...[
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _isConnectingMedia ? null : _connectMedia,
                child: Text(_isConnectingMedia ? '연결 중' : '방송 연결'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _isRefreshingSignal ? null : _refreshSignalState,
                child: Text(_isRefreshingSignal ? '신호 확인 중' : '신호 새로고침'),
              ),
              const SizedBox(height: 8),
              AnimatedBuilder(
                animation: _webRtc,
                builder: (context, _) => _WebRtcStatus(controller: _webRtc),
              ),
              const SizedBox(height: 8),
              LiveChatPanel(
                api: _api,
                session: _session!,
                senderRole: ChatSenderRole.supporter,
              ),
            ],
            const SizedBox(height: 16),
            _CueGrid(
              enabled: hasSession && !_isSendingCue,
              selectedCue: _selectedCue,
              onSelected: (cue) => unawaited(_sendCue(cue)),
            ),
            if (_isSendingCue) ...[
              const SizedBox(height: 8),
              const Text('큐 전송 중'),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _joinFromInput() async {
    late final InviteTarget target;
    try {
      target = InviteTarget.parse(_inviteController.text);
    } on FormatException {
      setState(() => _errorMessage = '참여 코드나 링크를 입력해 주세요.');
      return;
    }

    setState(() {
      _isJoining = true;
      _errorMessage = null;
    });

    try {
      switch (target.kind) {
        case InviteTargetKind.liveSession:
          final session = await _api.getLiveSessionByJoinCode(target.code);
          if (!mounted) {
            return;
          }

          setState(() {
            _session = session;
            _channel = null;
            _signalState = null;
            _recentCueEvents = const [];
            _hasReportedConnectionLoss = false;
            _errorMessage = null;
            _selectedCue = VoiceCue.holdPace;
          });
          _startCueHistoryPolling(session);
        case InviteTargetKind.channel:
          final channel = await _api.getChannelByCode(target.code);
          if (!mounted) {
            return;
          }

          setState(() {
            _channel = channel;
            _session = null;
            _signalState = null;
            _recentCueEvents = const [];
            _hasReportedConnectionLoss = false;
            _selectedCue = VoiceCue.stopNow;
          });
          _stopCueHistoryPolling();
      }
    } on LiveSessionApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() => _errorMessage = error.message);
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = '초대 정보를 처리하지 못했습니다. 코드를 다시 확인해 주세요.';
      });
    } finally {
      if (mounted) {
        setState(() => _isJoining = false);
      }
    }
  }

  Future<void> _refreshSignalState() async {
    final session = _session;
    if (session == null) {
      return;
    }

    setState(() {
      _isRefreshingSignal = true;
      _errorMessage = null;
    });

    try {
      await _webRtc.refreshSupporterSignal(session);
      if (!mounted) {
        return;
      }

      setState(() => _signalState = _webRtc.signalState);
    } on LiveSessionApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) {
        setState(() => _isRefreshingSignal = false);
      }
    }
  }

  Future<void> _connectMedia() async {
    final session = _session;
    if (session == null) {
      return;
    }

    setState(() {
      _isConnectingMedia = true;
      _errorMessage = null;
      _hasReportedConnectionLoss = false;
    });

    await _screenAwake.keepAwake();
    await _webRtc.joinAsSupporter(session);
    if (!mounted) {
      return;
    }

    final connected = _webRtc.phase != WebRtcPhase.failed &&
        _webRtc.phase != WebRtcPhase.connectionLost &&
        _webRtc.phase != WebRtcPhase.closed;
    if (!connected) {
      unawaited(_screenAwake.allowSleep());
    }

    setState(() {
      _isConnectingMedia = false;
      _signalState = _webRtc.signalState;
      _errorMessage = _webRtc.errorMessage;
      _selectedCue = connected ? VoiceCue.holdPace : VoiceCue.stopNow;
    });
  }

  Future<void> _sendCue(VoiceCue cue) async {
    final session = _session;
    if (session == null) {
      return;
    }

    setState(() {
      _selectedCue = cue;
      _isSendingCue = true;
      _errorMessage = null;
    });

    try {
      final event = await _api.createGuidanceCue(
        sessionId: session.sessionId,
        cue: cue,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _recentCueEvents = _takeRecentCueEvents([
          ..._recentCueEvents,
          event,
        ]);
      });
    } on LiveSessionApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) {
        setState(() => _isSendingCue = false);
      }
    }
  }

  void _startCueHistoryPolling(LiveSession session) {
    _stopCueHistoryPolling();
    unawaited(_pollCueHistory(session));
    _cueHistoryPollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      unawaited(_pollCueHistory(session));
    });
  }

  void _stopCueHistoryPolling() {
    _cueHistoryPollTimer?.cancel();
    _cueHistoryPollTimer = null;
  }

  Future<void> _pollCueHistory(LiveSession session) async {
    if (!mounted) {
      return;
    }

    try {
      final events = await _api.listGuidanceCues(session.sessionId);
      if (!mounted) {
        return;
      }

      setState(() {
        _recentCueEvents = _takeRecentCueEvents(events);
      });
    } on LiveSessionApiException catch (error) {
      if (mounted) {
        setState(() => _errorMessage = error.message);
      }
    }
  }

  List<GuidanceCueEvent> _takeRecentCueEvents(
    List<GuidanceCueEvent> events,
  ) {
    if (events.length <= 5) {
      return List<GuidanceCueEvent>.unmodifiable(events);
    }

    return List<GuidanceCueEvent>.unmodifiable(
      events.sublist(events.length - 5),
    );
  }

  void _handleWebRtcChanged() {
    if (!mounted) {
      return;
    }

    final session = _session;
    if (session == null) {
      return;
    }

    final requiresStop = _webRtc.safetyStopRequired ||
        _webRtc.phase == WebRtcPhase.connectionLost;
    if (!requiresStop) {
      return;
    }

    if (!_hasReportedConnectionLoss) {
      _hasReportedConnectionLoss = true;
      unawaited(_reportConnectionLost(session));
    }

    final nextCue = session.purpose == LiveSessionPurpose.runningGuide
        ? VoiceCue.stopNow
        : _selectedCue;

    if (_selectedCue == nextCue && _errorMessage == _webRtc.errorMessage) {
      return;
    }

    setState(() {
      _selectedCue = nextCue;
      _errorMessage = _webRtc.errorMessage;
    });
    unawaited(_screenAwake.allowSleep());
  }

  Future<void> _reportConnectionLost(LiveSession session) async {
    try {
      await _api.updateSafetyState(
        sessionId: session.sessionId,
        safetyState: SafetyState.connectionLost,
        reason: 'webrtc_connection_lost',
      );
    } on LiveSessionApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() => _errorMessage = error.message);
    }
  }
}

class _JoinPanel extends StatelessWidget {
  const _JoinPanel({
    required this.controller,
    required this.isJoining,
    required this.errorMessage,
    required this.onJoin,
  });

  final TextEditingController controller;
  final bool isJoining;
  final String? errorMessage;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('참여 코드 또는 링크', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              enabled: !isJoining,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: '코드 / 링크',
              ),
              onSubmitted: (_) {
                if (!isJoining) {
                  onJoin();
                }
              },
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 10),
            FilledButton(
              onPressed: isJoining ? null : onJoin,
              child: Text(isJoining ? '입장 중' : '입장'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RemoteVideoPlaceholder extends StatelessWidget {
  const _RemoteVideoPlaceholder({
    required this.session,
    required this.controller,
  });

  final LiveSession? session;
  final LiveWebRtcController controller;

  @override
  Widget build(BuildContext context) {
    final stream = controller.remoteRenderer.srcObject;
    if (stream != null && session?.sourceMode != LiveSourceMode.audioOnly) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: RTCVideoView(
            controller.remoteRenderer,
            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
          ),
        ),
      );
    }

    final label = session == null ? '라이브 화면 대기' : session!.sourceMode.label;

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
        ),
      ),
    );
  }
}

class _WebRtcStatus extends StatelessWidget {
  const _WebRtcStatus({required this.controller});

  final LiveWebRtcController controller;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('WebRTC: ${controller.phase.label}'),
            if (controller.errorMessage != null) ...[
              const SizedBox(height: 6),
              Text(
                controller.errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LiveRoomStatus extends StatelessWidget {
  const _LiveRoomStatus({
    required this.selectedCue,
    required this.session,
    required this.channel,
    required this.signalState,
    required this.recentCueEvents,
  });

  final VoiceCue selectedCue;
  final LiveSession? session;
  final Channel? channel;
  final SignalState? signalState;
  final List<GuidanceCueEvent> recentCueEvents;

  @override
  Widget build(BuildContext context) {
    final roomLabel = session?.purpose.label ?? channel?.title ?? '대기';
    final connectionLabel = session == null ? '대기' : '입장';

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _Metric(label: '연결', value: connectionLabel)),
                Expanded(child: _Metric(label: '방', value: roomLabel)),
                Expanded(child: _Metric(label: '안내', value: selectedCue.label)),
              ],
            ),
            if (session != null) ...[
              const SizedBox(height: 12),
              SelectableText('참여 코드: ${session!.joinCode}'),
              const SizedBox(height: 4),
              SelectableText('참여 링크: ${session!.joinLink}'),
              if (session!.runnerVisionMode != null) ...[
                const SizedBox(height: 4),
                Text('러너 모드: ${session!.runnerVisionMode!.label}'),
              ],
              const SizedBox(height: 4),
              Text(_signalLabel(signalState)),
              const SizedBox(height: 4),
              Text(_iceLabel(signalState)),
              if (recentCueEvents.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('최근 안내', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 6),
                for (final event in recentCueEvents.reversed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 44,
                          child: Text('#${event.sequence}'),
                        ),
                        Expanded(child: Text(event.cue.label)),
                        Text(_senderLabel(event.senderRole)),
                      ],
                    ),
                  ),
              ],
            ] else if (channel != null) ...[
              const SizedBox(height: 12),
              SelectableText('채널 코드: ${channel!.channelCode}'),
              const SizedBox(height: 4),
              SelectableText('채널 링크: ${channel!.channelLink}'),
            ],
          ],
        ),
      ),
    );
  }

  String _signalLabel(SignalState? signalState) {
    if (signalState == null) {
      return '신호: 미확인';
    }

    final offer = signalState.hasOffer ? 'offer 있음' : 'offer 없음';
    final answer = signalState.hasAnswer ? 'answer 있음' : 'answer 없음';
    return '신호: $offer / $answer';
  }

  String _iceLabel(SignalState? signalState) {
    if (signalState == null) {
      return 'ICE: 미확인';
    }

    return 'ICE: 송출자 ${signalState.hostIceCandidates.length} / 참여자 ${signalState.supporterIceCandidates.length}';
  }

  String _senderLabel(CueSenderRole senderRole) {
    return switch (senderRole) {
      CueSenderRole.supporter => '가이드',
      CueSenderRole.system => '시스템',
    };
  }
}

class _CueGrid extends StatelessWidget {
  const _CueGrid({
    required this.enabled,
    required this.selectedCue,
    required this.onSelected,
  });

  final bool enabled;
  final VoiceCue selectedCue;
  final ValueChanged<VoiceCue> onSelected;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 2.6,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (final cue in VoiceCue.values)
          _CueButton(
            cue: cue,
            isSelected: cue == selectedCue,
            onPressed: enabled ? () => onSelected(cue) : null,
          ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    );
  }
}

class _CueButton extends StatelessWidget {
  const _CueButton({
    required this.cue,
    required this.isSelected,
    required this.onPressed,
  });

  final VoiceCue cue;
  final bool isSelected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isStop = cue == VoiceCue.stopNow;
    final foreground = isStop ? Theme.of(context).colorScheme.error : null;

    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: foreground,
        backgroundColor: isSelected
            ? Theme.of(context).colorScheme.secondaryContainer
            : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: onPressed,
      child: Text(cue.label, textAlign: TextAlign.center),
    );
  }
}

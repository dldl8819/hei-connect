import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../core/safety/cue_speaker.dart';
import '../../core/safety/screen_awake.dart';
import '../../core/safety/voice_cues.dart';
import '../ai/ai_vision_assist_controller.dart';
import '../ai/ai_vision_models.dart';
import 'guide_flow_accessibility_widgets.dart';
import 'guide_flow_checklist.dart';
import 'live_chat_panel.dart';
import 'live_session_api.dart';
import 'live_models.dart';
import 'live_signaling_models.dart';
import 'live_webrtc_controller.dart';

class LiveHostPage extends StatefulWidget {
  const LiveHostPage({super.key});

  @override
  State<LiveHostPage> createState() => _LiveHostPageState();
}

class _LiveHostPageState extends State<LiveHostPage> {
  final LiveSessionApi _api = LiveSessionApi();
  final TextEditingController _channelTitleController = TextEditingController();
  final CueSpeaker _cueSpeaker = CueSpeaker();
  final ScreenAwake _screenAwake = ScreenAwake();
  late final LiveWebRtcController _webRtc;
  late final AiVisionAssistController _aiAssist;
  Timer? _cuePollTimer;
  Timer? _statusTicker;

  bool _isLive = false;
  bool _isCreating = false;
  bool _isRefreshingSignal = false;
  bool _isStartingMedia = false;
  bool _supportEnabled = false;
  bool _aiAssistEnabled = false;
  bool _aiVisionVerificationMode = false;
  bool _hasReportedConnectionLoss = false;
  bool _requiresResumeConfirmation = false;
  String? _errorMessage;
  Channel? _channel;
  LiveSession? _session;
  SignalState? _signalState;
  DateTime _statusNow = DateTime.now();
  AiHazardDecision? _lastAiVerificationDecision;
  final Set<_PreRunChecklistItem> _confirmedPreRunItems =
      <_PreRunChecklistItem>{};
  final Set<GuideFlowChecklistItem> _confirmedGuideFlowItems =
      <GuideFlowChecklistItem>{};
  List<GuidanceCueEvent> _recentCueEvents = const [];
  int _lastCueSequence = 0;
  VoiceCue _lastCue = VoiceCue.stopNow;
  LiveSessionPurpose _purpose = LiveSessionPurpose.dailyHelp;
  LiveSourceMode _sourceMode = LiveSourceMode.worldCamera;
  RunnerVisionMode _runnerVisionMode = RunnerVisionMode.blind;

  @override
  void initState() {
    super.initState();
    _webRtc = LiveWebRtcController(api: _api);
    _aiAssist = AiVisionAssistController(
      captureFrame: _webRtc.captureLocalVideoFrame,
      onDecision: _handleAiVisionDecision,
    );
    _webRtc.addListener(_handleWebRtcChanged);
    unawaited(_cueSpeaker.initialize());
    _statusTicker = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        setState(() => _statusNow = DateTime.now());
      }
    });
  }

  @override
  void dispose() {
    _channelTitleController.dispose();
    _stopCuePolling();
    _statusTicker?.cancel();
    unawaited(_cueSpeaker.stop());
    unawaited(_screenAwake.allowSleep());
    _aiAssist.dispose();
    _webRtc.removeListener(_handleWebRtcChanged);
    _webRtc.dispose();
    _api.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('라이브 열기')),
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onLongPress: _session == null
              ? null
              : () {
                  unawaited(_requestEmergencyStop());
                },
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              AnimatedBuilder(
                animation: _webRtc,
                builder: (context, _) {
                  return _CameraPreviewPlaceholder(
                    isLive: _isLive,
                    sourceMode: _sourceMode,
                    controller: _webRtc,
                  );
                },
              ),
              const SizedBox(height: 16),
              _PurposeSelector(
                selectedPurpose: _purpose,
                enabled: _session == null && !_isCreating,
                onSelected: (purpose) {
                  setState(() {
                    _purpose = purpose;
                    _confirmedPreRunItems.clear();
                    _clearGuideFlowChecks();
                    if (purpose == LiveSessionPurpose.runningGuide) {
                      _sourceMode = LiveSourceMode.worldCamera;
                    } else {
                      _aiAssistEnabled = false;
                      _aiVisionVerificationMode = false;
                      _aiAssist.stop();
                    }
                  });
                },
              ),
              if (_showsPreRunChecklist) ...[
                const SizedBox(height: 16),
                _RunnerVisionModeSelector(
                  selectedMode: _runnerVisionMode,
                  enabled: _session == null && !_isCreating,
                  onSelected: (mode) {
                    setState(() {
                      _runnerVisionMode = mode;
                      _confirmedPreRunItems.clear();
                      _clearGuideFlowChecks();
                    });
                  },
                ),
              ],
              const SizedBox(height: 16),
              _SourceModeSelector(
                selectedSourceMode: _sourceMode,
                enabled: _session == null && !_isCreating,
                onSelected: (sourceMode) {
                  setState(() {
                    _sourceMode = sourceMode;
                    _clearGuideFlowChecks();
                    if (_purpose == LiveSessionPurpose.runningGuide) {
                      _confirmedPreRunItems.clear();
                    }
                    if (sourceMode != LiveSourceMode.worldCamera) {
                      _aiAssistEnabled = false;
                      _aiVisionVerificationMode = false;
                      _aiAssist.stop();
                    }
                  });
                },
              ),
              if (_showsPreRunChecklist) ...[
                const SizedBox(height: 16),
                _PreRunChecklistPanel(
                  runnerVisionMode: _runnerVisionMode,
                  sourceMode: _sourceMode,
                  confirmedItems: _confirmedPreRunItems,
                  enabled: !_isLive && !_isCreating && !_isStartingMedia,
                  onChanged: _setPreRunChecklistItem,
                ),
              ],
              if (_showsPreRunChecklist) ...[
                const SizedBox(height: 16),
                AnimatedBuilder(
                  animation: _aiAssist,
                  builder: (context, _) {
                    return _AiVisionAssistPanel(
                      enabled: _aiAssistEnabled,
                      canUse: _canUseAiVisionAssist,
                      isLive: _isLive,
                      controller: _aiAssist,
                      now: _statusNow,
                      guideFlowState: _guideFlowState,
                      verificationModeEnabled: _aiVisionVerificationMode,
                      verificationDecision: _lastAiVerificationDecision,
                      onEnabledChanged: _setAiAssistEnabled,
                      onVerificationModeChanged: _setAiVisionVerificationMode,
                      onAnalyzeNow: _isLive &&
                              _aiAssistEnabled &&
                              !_aiVisionVerificationMode
                          ? () {
                              unawaited(_aiAssist.analyzeOnce());
                            }
                          : null,
                      onSimulateSlowDown: _isLive &&
                              _aiAssistEnabled &&
                              _aiVisionVerificationMode
                          ? () {
                              unawaited(
                                _runAiVisionVerificationCue(
                                  level: AiHazardLevel.caution,
                                  cue: VoiceCue.slowDown,
                                ),
                              );
                            }
                          : null,
                      onSimulateStop: _isLive &&
                              _aiAssistEnabled &&
                              _aiVisionVerificationMode
                          ? () {
                              unawaited(
                                _runAiVisionVerificationCue(
                                  level: AiHazardLevel.stop,
                                  cue: VoiceCue.stopNow,
                                ),
                              );
                            }
                          : null,
                    );
                  },
                ),
              ],
              if (_showsPreRunChecklist) ...[
                const SizedBox(height: 16),
                AnimatedBuilder(
                  animation: _webRtc,
                  builder: (context, _) {
                    return AnimatedBuilder(
                      animation: _aiAssist,
                      builder: (context, _) {
                        return _FieldTestStatusPanel(
                          session: _session,
                          purpose: _purpose,
                          sourceMode: _sourceMode,
                          runnerVisionMode: _runnerVisionMode,
                          isCreating: _isCreating,
                          isStartingMedia: _isStartingMedia,
                          isLive: _isLive,
                          preRunChecklistComplete: _isPreRunChecklistComplete,
                          requiresResumeConfirmation:
                              _requiresResumeConfirmation,
                          webRtcPhase: _webRtc.phase,
                          fieldErrorMessage:
                              _errorMessage ?? _webRtc.errorMessage,
                          confirmedGuideFlowItems: _confirmedGuideFlowItems,
                          onGuideFlowChecklistItemChanged:
                              _setGuideFlowChecklistItem,
                          aiAssistEnabled: _aiAssistEnabled,
                          aiVerificationMode: _aiVisionVerificationMode,
                          canUseAiVisionAssist: _canUseAiVisionAssist,
                          aiController: _aiAssist,
                          now: _statusNow,
                          verificationDecision: _lastAiVerificationDecision,
                        );
                      },
                    );
                  },
                ),
              ],
              const SizedBox(height: 16),
              _ChannelPanel(
                controller: _channelTitleController,
                channel: _channel,
                supportEnabled: _supportEnabled,
                enabled: _channel == null && _session == null && !_isCreating,
                onSupportEnabledChanged: (value) {
                  setState(() => _supportEnabled = value);
                },
                onCreateChannel: _createChannel,
              ),
              const SizedBox(height: 16),
              AnimatedBuilder(
                animation: _webRtc,
                builder: (context, _) => _StatusPanel(
                  lastCue: _lastCue,
                  channel: _channel,
                  session: _session,
                  runnerVisionMode: _runnerVisionMode,
                  signalState: _webRtc.signalState ?? _signalState,
                  errorMessage: _errorMessage ?? _webRtc.errorMessage,
                  requiresResumeConfirmation: _requiresResumeConfirmation,
                  recentCueEvents: _recentCueEvents,
                ),
              ),
              if (_session != null) ...[
                const SizedBox(height: 12),
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
                  senderRole: ChatSenderRole.host,
                  onNewMessages: _speakGuideChatMessages,
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(64),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _isCreating || _isStartingMedia
                    ? null
                    : _handlePrimaryAction,
                child: Text(_primaryButtonLabel),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(64),
                  foregroundColor: Theme.of(context).colorScheme.error,
                  side: BorderSide(color: Theme.of(context).colorScheme.error),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () async {
                  await _requestEmergencyStop();
                },
                child: const Text('비상 정지 요청'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _primaryButtonLabel {
    if (_isCreating) {
      return '생성 중';
    }

    if (_isStartingMedia) {
      return '연결 준비 중';
    }

    if (_session == null) {
      return '라이브 세션 생성';
    }

    if (_requiresResumeConfirmation) {
      return '안전 확인 후 재개';
    }

    return _isLive ? '일시정지' : '라이브 시작';
  }

  bool get _showsPreRunChecklist {
    return _purpose == LiveSessionPurpose.runningGuide ||
        _session?.purpose == LiveSessionPurpose.runningGuide;
  }

  bool get _canUseAiVisionAssist {
    final purpose = _session?.purpose ?? _purpose;
    final sourceMode = _session?.sourceMode ?? _sourceMode;
    return purpose == LiveSessionPurpose.runningGuide &&
        sourceMode == LiveSourceMode.worldCamera;
  }

  bool get _isPreRunChecklistComplete {
    return _sourceMode == LiveSourceMode.worldCamera &&
        _confirmedPreRunItems.length == _PreRunChecklistItem.values.length;
  }

  GuideFlowChecklistState get _guideFlowState {
    return GuideFlowChecklistState(_confirmedGuideFlowItems);
  }

  bool get _isGuideFlowConfirmed => _guideFlowState.allowsAiAssist;

  bool get _canConfirmGuideFlowChecks {
    return _isLive &&
        _webRtc.phase == WebRtcPhase.connected &&
        !_requiresResumeConfirmation;
  }

  void _setPreRunChecklistItem(_PreRunChecklistItem item, bool checked) {
    setState(() {
      if (checked) {
        _confirmedPreRunItems.add(item);
      } else {
        _confirmedPreRunItems.remove(item);
      }
    });
  }

  void _setGuideFlowChecklistItem(
    GuideFlowChecklistItem item,
    bool checked,
  ) {
    if (checked &&
        (!_canConfirmGuideFlowChecks ||
            _session?.purpose != LiveSessionPurpose.runningGuide)) {
      setState(() {
        _confirmedGuideFlowItems.remove(item);
        _errorMessage = '라이브 연결 후 가이드 흐름 5개 항목을 정지 상태에서 확인해 주세요.';
      });
      return;
    }

    setState(() {
      final nextGuideFlowState = _guideFlowState.updateItem(item, checked);
      _confirmedGuideFlowItems
        ..clear()
        ..addAll(nextGuideFlowState.confirmedItems);
      if (!nextGuideFlowState.allowsAiAssist) {
        _aiAssistEnabled = false;
        _aiVisionVerificationMode = false;
        _aiAssist.stop();
      }
      _errorMessage = null;
    });
    _syncAiAssistWithLiveState();
  }

  void _clearGuideFlowChecks() {
    _confirmedGuideFlowItems.clear();
    _aiAssistEnabled = false;
    _aiVisionVerificationMode = false;
    _aiAssist.stop();
  }

  Future<void> _createChannel() async {
    final title = _channelTitleController.text.trim();
    if (title.isEmpty) {
      setState(() => _errorMessage = '채널 이름을 입력해 주세요.');
      return;
    }

    setState(() {
      _isCreating = true;
      _errorMessage = null;
    });

    try {
      final channel = await _api.createChannel(
        title: title,
        supportEnabled: _supportEnabled,
      );
      if (!mounted) {
        return;
      }

      setState(() => _channel = channel);
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
        _errorMessage = '채널 응답을 처리하지 못했습니다.';
      });
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  Future<void> _handlePrimaryAction() async {
    if (_session == null) {
      await _createSession();
      return;
    }

    final session = _session!;
    if (_requiresResumeConfirmation) {
      final canResume = await _prepareResumeIfNeeded(session);
      if (!canResume) {
        return;
      }

      if (_isLive) {
        await _markLiveAfterResume(session);
        return;
      }
    }

    if (_isLive) {
      await _stopBroadcast();
      return;
    }

    await _startBroadcast();
  }

  Future<void> _createSession() async {
    setState(() {
      _isCreating = true;
      _errorMessage = null;
    });

    try {
      final session = await _api.createLiveSession(
        purpose: _purpose,
        sourceMode: _sourceMode,
        runnerVisionMode: _purpose == LiveSessionPurpose.runningGuide
            ? _runnerVisionMode
            : null,
        channelId: _channel?.channelId,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _session = session;
        _signalState = null;
        _hasReportedConnectionLoss = false;
        _requiresResumeConfirmation = false;
        _clearGuideFlowChecks();
        _recentCueEvents = const [];
        _lastCueSequence = 0;
        _lastCue = VoiceCue.holdPace;
      });
      _startCuePolling(session);
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
        _errorMessage = '응답을 처리하지 못했습니다. 앱과 서버 버전을 확인해 주세요.';
      });
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
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
      await _webRtc.refreshHostSignal(session);
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

  Future<void> _startBroadcast() async {
    final session = _session;
    if (session == null) {
      return;
    }

    final canStart = await _preparePreRunIfNeeded(session);
    if (!canStart) {
      return;
    }

    setState(() {
      _isStartingMedia = true;
      _errorMessage = null;
      _hasReportedConnectionLoss = false;
    });

    await _screenAwake.keepAwake();
    await _webRtc.startHost(session);
    if (!mounted) {
      return;
    }

    final requiresResumeConfirmation =
        session.purpose == LiveSessionPurpose.runningGuide &&
            (_webRtc.safetyStopRequired ||
                _webRtc.phase == WebRtcPhase.connectionLost);
    final isLive = _webRtc.phase != WebRtcPhase.failed &&
        _webRtc.phase != WebRtcPhase.connectionLost &&
        _webRtc.phase != WebRtcPhase.closed;
    LiveSession updatedSession = session;
    String? statusError;
    if (isLive) {
      try {
        updatedSession = await _api.updateSessionStatus(
          sessionId: session.sessionId,
          status: LiveSessionStatus.live,
          reason: 'host_started',
        );
      } on LiveSessionApiException catch (error) {
        statusError = error.message;
      }
    } else {
      unawaited(_screenAwake.allowSleep());
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _session = updatedSession;
      _isStartingMedia = false;
      _isLive = isLive;
      _signalState = _webRtc.signalState;
      _errorMessage = statusError ?? _webRtc.errorMessage;
      _requiresResumeConfirmation = requiresResumeConfirmation;
      _lastCue = _isLive && !requiresResumeConfirmation
          ? VoiceCue.holdPace
          : VoiceCue.stopNow;
    });
    _syncAiAssistWithLiveState();
  }

  Future<bool> _preparePreRunIfNeeded(LiveSession session) async {
    if (session.purpose != LiveSessionPurpose.runningGuide) {
      return true;
    }

    if (_isPreRunChecklistComplete) {
      return true;
    }

    setState(() {
      _lastCue = VoiceCue.stopNow;
      _errorMessage = _sourceMode == LiveSourceMode.worldCamera
          ? '러닝 가이드 시작 전 안전 체크를 모두 완료해 주세요.'
          : '러닝 가이드는 눈앞 카메라 모드가 필요합니다.';
    });
    unawaited(_cueSpeaker.speak(VoiceCue.stopNow));

    try {
      await _api.updateSafetyState(
        sessionId: session.sessionId,
        safetyState: SafetyState.checkRequired,
        reason: 'pre_run_check_required',
      );
    } on LiveSessionApiException catch (error) {
      if (mounted) {
        setState(() => _errorMessage = error.message);
      }
    }

    return false;
  }

  void _startCuePolling(LiveSession session) {
    _stopCuePolling();
    unawaited(_pollGuidanceCues(session));
    _cuePollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      unawaited(_pollGuidanceCues(session));
    });
  }

  void _stopCuePolling() {
    _cuePollTimer?.cancel();
    _cuePollTimer = null;
  }

  Future<void> _pollGuidanceCues(LiveSession session) async {
    if (!mounted) {
      return;
    }

    try {
      final events = await _api.listGuidanceCues(session.sessionId);
      final unseenEvents =
          events.where((event) => event.sequence > _lastCueSequence).toList();
      if (unseenEvents.isEmpty || !mounted) {
        return;
      }

      final latest = unseenEvents.last;
      final recentEvents =
          events.length <= 5 ? events : events.sublist(events.length - 5);
      setState(() {
        _lastCueSequence = latest.sequence;
        _lastCue = latest.cue;
        _recentCueEvents = recentEvents;
      });
      unawaited(_cueSpeaker.speak(latest.cue));
    } on LiveSessionApiException catch (error) {
      if (mounted) {
        setState(() => _errorMessage = error.message);
      }
    }
  }

  void _speakGuideChatMessages(List<LiveChatMessage> messages) {
    unawaited(_speakGuideChatMessagesInOrder(messages));
  }

  Future<void> _speakGuideChatMessagesInOrder(
    List<LiveChatMessage> messages,
  ) async {
    final speakableMessages = messages.where(
      (message) =>
          message.senderRole == ChatSenderRole.supporter ||
          message.senderRole == ChatSenderRole.system,
    );

    for (final message in speakableMessages) {
      final prefix = message.senderRole == ChatSenderRole.supporter
          ? '가이드 메시지'
          : '시스템 메시지';
      final body = message.body.trim();
      if (body.isEmpty) {
        continue;
      }

      await _cueSpeaker.speakText('$prefix. $body');
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

  void _setAiAssistEnabled(bool enabled) {
    if (enabled && !_canUseAiVisionAssist) {
      setState(() {
        _aiAssistEnabled = false;
        _errorMessage = 'AI 보조는 러닝 가이드의 전방 카메라 모드에서만 사용할 수 있습니다.';
      });
      _aiAssist.stop();
      return;
    }

    if (enabled && _showsPreRunChecklist && !_isGuideFlowConfirmed) {
      setState(() {
        _aiAssistEnabled = false;
        _errorMessage =
            'AI 보조 전에 WebRTC 영상, 가이드 음성, cue 버튼, 채팅 TTS, 정지/재개를 모두 확인해 주세요.';
      });
      _aiAssist.stop();
      return;
    }

    setState(() {
      _aiAssistEnabled = enabled;
      if (!enabled) {
        _aiVisionVerificationMode = false;
      }
      _errorMessage = null;
    });
    _syncAiAssistWithLiveState();
  }

  void _setAiVisionVerificationMode(bool enabled) {
    setState(() {
      _aiVisionVerificationMode = enabled;
      _errorMessage = null;
    });
    _syncAiAssistWithLiveState();
  }

  void _syncAiAssistWithLiveState() {
    if (_aiAssistEnabled &&
        _isLive &&
        _canUseAiVisionAssist &&
        (!_showsPreRunChecklist || _isGuideFlowConfirmed) &&
        !_aiVisionVerificationMode &&
        !_requiresResumeConfirmation) {
      _aiAssist.start();
      return;
    }

    _aiAssist.stop();
  }

  void _handleAiVisionDecision(AiHazardDecision decision) {
    unawaited(_applyAiVisionDecision(decision));
  }

  Future<void> _runAiVisionVerificationCue({
    required AiHazardLevel level,
    required VoiceCue cue,
  }) {
    final decision = AiHazardDecision(
      level: level,
      cue: cue,
      spokenText: level == AiHazardLevel.stop
          ? 'AI 검증. 정지 안내 흐름을 확인합니다. 잠깐 멈추세요.'
          : 'AI 검증. 감속 안내 흐름을 확인합니다. 천천히 가세요.',
      reason: level == AiHazardLevel.stop ? '검증 모드 정지 큐' : '검증 모드 감속 큐',
      objects: const [],
      decidedAt: DateTime.now(),
    );
    if (mounted) {
      setState(() {
        _statusNow = decision.decidedAt;
        _lastAiVerificationDecision = decision;
      });
    }
    return _applyAiVisionDecision(decision);
  }

  Future<void> _applyAiVisionDecision(AiHazardDecision decision) async {
    final session = _session;
    if (session == null ||
        !_aiAssistEnabled ||
        !_isLive ||
        session.purpose != LiveSessionPurpose.runningGuide ||
        !decision.shouldSpeak) {
      return;
    }

    unawaited(_cueSpeaker.speakText(decision.spokenText));

    LiveSession? updatedSession;
    GuidanceCueEvent? cueEvent;
    String? aiError;
    try {
      if (decision.shouldPauseRunner) {
        await _api.updateSafetyState(
          sessionId: session.sessionId,
          safetyState: SafetyState.stopNow,
          reason: 'ai_vision_stop',
        );
      }

      cueEvent = await _api.createGuidanceCue(
        sessionId: session.sessionId,
        cue: decision.cue,
        senderRole: CueSenderRole.system,
      );

      if (decision.shouldPauseRunner) {
        updatedSession = await _api.updateSessionStatus(
          sessionId: session.sessionId,
          status: LiveSessionStatus.paused,
          reason: 'ai_vision_stop',
        );
      }
    } on LiveSessionApiException catch (error) {
      aiError = error.message;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      if (updatedSession != null) {
        _session = updatedSession;
      }
      if (cueEvent != null) {
        _recentCueEvents = _takeRecentCueEvents([
          ..._recentCueEvents,
          cueEvent,
        ]);
        _lastCueSequence = cueEvent.sequence;
      }
      _lastCue = decision.cue;
      if (decision.shouldPauseRunner) {
        _requiresResumeConfirmation = true;
      }
      _errorMessage = aiError;
    });

    if (decision.shouldPauseRunner) {
      _aiAssist.stop();
    }
  }

  Future<void> _requestEmergencyStop() async {
    final session = _session;
    _aiAssist.stop();
    setState(() {
      _lastCue = VoiceCue.stopNow;
      _clearGuideFlowChecks();
      _requiresResumeConfirmation =
          session?.purpose == LiveSessionPurpose.runningGuide;
      _errorMessage = null;
    });
    unawaited(_cueSpeaker.speak(VoiceCue.stopNow));

    if (session == null) {
      return;
    }

    LiveSession? updatedSession;
    GuidanceCueEvent? stopCue;
    String? stopError;
    try {
      await _api.updateSafetyState(
        sessionId: session.sessionId,
        safetyState: SafetyState.stopNow,
        reason: 'runner_emergency_stop',
      );
      stopCue = await _api.createGuidanceCue(
        sessionId: session.sessionId,
        cue: VoiceCue.stopNow,
        senderRole: CueSenderRole.system,
      );
      updatedSession = await _api.updateSessionStatus(
        sessionId: session.sessionId,
        status: LiveSessionStatus.paused,
        reason: 'runner_emergency_stop',
      );
    } on LiveSessionApiException catch (error) {
      stopError = error.message;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      if (updatedSession != null) {
        _session = updatedSession;
      }
      if (stopCue != null) {
        _recentCueEvents = _takeRecentCueEvents([
          ..._recentCueEvents,
          stopCue,
        ]);
        _lastCueSequence = stopCue.sequence;
      }
      _lastCue = VoiceCue.stopNow;
      _clearGuideFlowChecks();
      _requiresResumeConfirmation =
          session.purpose == LiveSessionPurpose.runningGuide;
      _errorMessage = stopError;
    });
  }

  Future<void> _stopBroadcast() async {
    final session = _session;
    _aiAssist.stop();
    await _webRtc.stop();
    await _screenAwake.allowSleep();
    if (!mounted) {
      return;
    }

    LiveSession? updatedSession;
    String? statusError;
    if (session != null) {
      try {
        updatedSession = await _api.updateSessionStatus(
          sessionId: session.sessionId,
          status: LiveSessionStatus.paused,
          reason: 'host_paused',
        );
      } on LiveSessionApiException catch (error) {
        statusError = error.message;
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      if (updatedSession != null) {
        _session = updatedSession;
      }
      _isLive = false;
      _lastCue = VoiceCue.stopNow;
      _clearGuideFlowChecks();
      _requiresResumeConfirmation =
          session?.purpose == LiveSessionPurpose.runningGuide;
      _errorMessage = statusError ?? _webRtc.errorMessage;
    });
    unawaited(_cueSpeaker.speak(VoiceCue.stopNow));
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
    final requiresResumeConfirmation = _requiresResumeConfirmation ||
        (session.purpose == LiveSessionPurpose.runningGuide && requiresStop);
    final connectionEnded = requiresStop ||
        _webRtc.phase == WebRtcPhase.failed ||
        _webRtc.phase == WebRtcPhase.closed;

    if (requiresStop && !_hasReportedConnectionLoss) {
      _hasReportedConnectionLoss = true;
      unawaited(_reportConnectionLost(session));
    }

    if (!connectionEnded) {
      return;
    }

    final nextCue =
        session.purpose == LiveSessionPurpose.runningGuide && requiresStop
            ? VoiceCue.stopNow
            : _lastCue;

    if (!_isLive &&
        _lastCue == nextCue &&
        _errorMessage == _webRtc.errorMessage &&
        _requiresResumeConfirmation == requiresResumeConfirmation) {
      return;
    }

    _aiAssist.stop();
    setState(() {
      _isLive = false;
      _lastCue = nextCue;
      _errorMessage = _webRtc.errorMessage;
      if (connectionEnded) {
        _clearGuideFlowChecks();
      }
      _requiresResumeConfirmation = requiresResumeConfirmation;
    });
    if (nextCue == VoiceCue.stopNow) {
      unawaited(_cueSpeaker.speak(VoiceCue.stopNow));
    }
  }

  Future<bool> _prepareResumeIfNeeded(LiveSession session) async {
    if (!_requiresResumeConfirmation) {
      return true;
    }

    final confirmed = await _showResumeConfirmationDialog();
    if (!confirmed) {
      return false;
    }

    try {
      await _api.updateSafetyState(
        sessionId: session.sessionId,
        safetyState: SafetyState.ready,
        reason: 'resume_confirmed',
      );
    } on LiveSessionApiException catch (error) {
      if (mounted) {
        setState(() => _errorMessage = error.message);
      }
      return false;
    }

    if (!mounted) {
      return false;
    }

    setState(() {
      _requiresResumeConfirmation = false;
      _lastCue = VoiceCue.holdPace;
      _errorMessage = null;
    });
    return true;
  }

  Future<void> _markLiveAfterResume(LiveSession session) async {
    try {
      final updatedSession = await _api.updateSessionStatus(
        sessionId: session.sessionId,
        status: LiveSessionStatus.live,
        reason: 'resume_confirmed',
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _session = updatedSession;
        _lastCue = VoiceCue.holdPace;
        _errorMessage = null;
      });
      _syncAiAssistWithLiveState();
    } on LiveSessionApiException catch (error) {
      if (mounted) {
        setState(() => _errorMessage = error.message);
      }
    }
  }

  Future<bool> _showResumeConfirmationDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('안전 확인'),
          content: const Text(
            '러너가 멈췄고 카메라와 오디오가 안정적인 상태에서만 재개합니다.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('재개'),
            ),
          ],
        );
      },
    );

    return result ?? false;
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

class _AiVisionAssistPanel extends StatelessWidget {
  const _AiVisionAssistPanel({
    required this.enabled,
    required this.canUse,
    required this.isLive,
    required this.controller,
    required this.now,
    required this.guideFlowState,
    required this.verificationModeEnabled,
    required this.verificationDecision,
    required this.onEnabledChanged,
    required this.onVerificationModeChanged,
    required this.onAnalyzeNow,
    required this.onSimulateSlowDown,
    required this.onSimulateStop,
  });

  final bool enabled;
  final bool canUse;
  final bool isLive;
  final AiVisionAssistController controller;
  final DateTime now;
  final GuideFlowChecklistState guideFlowState;
  final bool verificationModeEnabled;
  final AiHazardDecision? verificationDecision;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<bool> onVerificationModeChanged;
  final VoidCallback? onAnalyzeNow;
  final VoidCallback? onSimulateSlowDown;
  final VoidCallback? onSimulateStop;

  @override
  Widget build(BuildContext context) {
    final decision = controller.lastDecision;
    final visibleDecision =
        verificationModeEnabled ? verificationDecision : decision;
    final colorScheme = Theme.of(context).colorScheme;
    final statusColor = switch (visibleDecision?.level) {
      AiHazardLevel.stop => colorScheme.error,
      AiHazardLevel.caution => const Color(0xFFB45309),
      AiHazardLevel.clear => colorScheme.primary,
      null => colorScheme.onSurfaceVariant,
    };
    final decisionIsStale =
        !verificationModeEnabled && decision != null && decision.isStaleAt(now);
    final objectSummary = decision == null || decision.objects.isEmpty
        ? null
        : decision.objects
            .take(3)
            .map((object) => object.displayLabel)
            .join(', ');

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AiAssistGateSwitchTile(
              enabled: enabled,
              canUse: canUse,
              isLive: isLive,
              guideFlowState: guideFlowState,
              verificationModeEnabled: verificationModeEnabled,
              isAnalyzing: controller.isAnalyzing,
              isRunning: controller.isRunning,
              onChanged: onEnabledChanged,
            ),
            if (enabled) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _AiStatusBadge(
                    icon: verificationModeEnabled
                        ? Icons.science
                        : Icons.camera_alt,
                    label: verificationModeEnabled ? '검증 모드' : '실제 분석 모드',
                    color: verificationModeEnabled
                        ? const Color(0xFFB45309)
                        : colorScheme.primary,
                  ),
                  if (visibleDecision != null)
                    _AiStatusBadge(
                      icon: Icons.schedule,
                      label:
                          '${verificationModeEnabled ? '최근 검증' : '최근 판단'} ${visibleDecision.ageLabelAt(now)}',
                      color: decisionIsStale
                          ? const Color(0xFFB45309)
                          : colorScheme.onSurfaceVariant,
                    ),
                  if (decisionIsStale)
                    const _AiStatusBadge(
                      icon: Icons.warning_amber,
                      label: '판단 오래됨',
                      color: Color(0xFFB45309),
                    ),
                ],
              ),
              if (visibleDecision != null) ...[
                const SizedBox(height: 8),
                Text(
                  '${visibleDecision.level.label} · ${visibleDecision.reason}',
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (!verificationModeEnabled && objectSummary != null) ...[
                  const SizedBox(height: 4),
                  Text('감지: $objectSummary'),
                ],
              ],
            ],
            if (controller.errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                controller.errorMessage!,
                style: TextStyle(color: colorScheme.error),
              ),
            ],
            if (enabled) ...[
              const SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.science),
                title: const Text('검증 모드'),
                subtitle: const Text('카메라 분석 없이 안내 흐름만 확인합니다.'),
                value: verificationModeEnabled,
                onChanged: onVerificationModeChanged,
              ),
              if (verificationModeEnabled) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: onSimulateSlowDown,
                      icon: const Icon(Icons.directions_walk),
                      label: const Text('감속 큐 테스트'),
                    ),
                    OutlinedButton.icon(
                      onPressed: onSimulateStop,
                      icon: const Icon(Icons.report),
                      label: const Text('정지 큐 테스트'),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: onAnalyzeNow,
                icon: const Icon(Icons.refresh),
                label: const Text('지금 분석'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AiStatusBadge extends StatelessWidget {
  const _AiStatusBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 5),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _FieldTestStatusState {
  ready,
  pending,
  warning,
  blocked,
}

extension _GuideFlowChecklistItemIcon on GuideFlowChecklistItem {
  IconData get icon {
    return switch (this) {
      GuideFlowChecklistItem.webRtcVideo => Icons.videocam,
      GuideFlowChecklistItem.guideVoice => Icons.record_voice_over,
      GuideFlowChecklistItem.cueButtons => Icons.touch_app,
      GuideFlowChecklistItem.shortChatTts => Icons.chat,
      GuideFlowChecklistItem.stopResume => Icons.pause_circle,
    };
  }
}

class _FieldTestStatusItem {
  const _FieldTestStatusItem({
    required this.label,
    required this.value,
    required this.state,
  });

  final String label;
  final String value;
  final _FieldTestStatusState state;
}

class _FieldTestStageItem {
  const _FieldTestStageItem({
    required this.title,
    required this.detail,
    required this.icon,
    required this.state,
  });

  final String title;
  final String detail;
  final IconData icon;
  final _FieldTestStatusState state;
}

class _FieldTestFailureGuide {
  const _FieldTestFailureGuide({
    required this.title,
    required this.detail,
    required this.icon,
    required this.state,
    required this.actions,
  });

  final String title;
  final String detail;
  final IconData icon;
  final _FieldTestStatusState state;
  final List<String> actions;
}

class _FieldTestNextAction {
  const _FieldTestNextAction({
    required this.title,
    required this.detail,
    required this.icon,
    required this.state,
  });

  final String title;
  final String detail;
  final IconData icon;
  final _FieldTestStatusState state;
}

class _FieldTestStatusPanel extends StatelessWidget {
  const _FieldTestStatusPanel({
    required this.session,
    required this.purpose,
    required this.sourceMode,
    required this.runnerVisionMode,
    required this.isCreating,
    required this.isStartingMedia,
    required this.isLive,
    required this.preRunChecklistComplete,
    required this.requiresResumeConfirmation,
    required this.webRtcPhase,
    required this.fieldErrorMessage,
    required this.confirmedGuideFlowItems,
    required this.onGuideFlowChecklistItemChanged,
    required this.aiAssistEnabled,
    required this.aiVerificationMode,
    required this.canUseAiVisionAssist,
    required this.aiController,
    required this.now,
    required this.verificationDecision,
  });

  final LiveSession? session;
  final LiveSessionPurpose purpose;
  final LiveSourceMode sourceMode;
  final RunnerVisionMode runnerVisionMode;
  final bool isCreating;
  final bool isStartingMedia;
  final bool isLive;
  final bool preRunChecklistComplete;
  final bool requiresResumeConfirmation;
  final WebRtcPhase webRtcPhase;
  final String? fieldErrorMessage;
  final Set<GuideFlowChecklistItem> confirmedGuideFlowItems;
  final void Function(GuideFlowChecklistItem item, bool checked)
      onGuideFlowChecklistItemChanged;
  final bool aiAssistEnabled;
  final bool aiVerificationMode;
  final bool canUseAiVisionAssist;
  final AiVisionAssistController aiController;
  final DateTime now;
  final AiHazardDecision? verificationDecision;

  GuideFlowChecklistState get _guideFlowState {
    return GuideFlowChecklistState(confirmedGuideFlowItems);
  }

  bool get guideFlowConfirmed => _guideFlowState.allowsAiAssist;

  String get _guideFlowStatusLabel => _guideFlowState.statusLabel;

  GuideFlowChecklistItem? get _nextMissingGuideFlowItem =>
      _guideFlowState.nextMissingItem;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sessionPurpose = session?.purpose ?? purpose;
    final sessionSourceMode = session?.sourceMode ?? sourceMode;
    final sessionRunnerMode = session?.runnerVisionMode ?? runnerVisionMode;
    final runningGuideReady =
        sessionPurpose == LiveSessionPurpose.runningGuide &&
            sessionSourceMode == LiveSourceMode.worldCamera &&
            preRunChecklistComplete;
    final stageItems = _stageItems(runningGuideReady);
    final items = <_FieldTestStatusItem>[
      _FieldTestStatusItem(
        label: '안전 기준',
        value: runningGuideReady ? '통제 경로 + 백업 확인' : '체크리스트 완료 필요',
        state: runningGuideReady
            ? _FieldTestStatusState.ready
            : _FieldTestStatusState.pending,
      ),
      _FieldTestStatusItem(
        label: '러너 모드',
        value: sessionRunnerMode.label,
        state: _FieldTestStatusState.ready,
      ),
      _FieldTestStatusItem(
        label: '세션',
        value: session != null ? '생성됨' : (isCreating ? '생성 중' : '아직 없음'),
        state: session != null
            ? _FieldTestStatusState.ready
            : _FieldTestStatusState.pending,
      ),
      _FieldTestStatusItem(
        label: '라이브',
        value: _liveStatusLabel,
        state: _liveStatusState,
      ),
      _FieldTestStatusItem(
        label: 'WebRTC',
        value: webRtcPhase.label,
        state: _webRtcStatusState,
      ),
      _FieldTestStatusItem(
        label: '가이드 흐름',
        value: _guideFlowStatusLabel,
        state: guideFlowConfirmed
            ? _FieldTestStatusState.ready
            : _FieldTestStatusState.pending,
      ),
      _FieldTestStatusItem(
        label: 'AI 보조',
        value: _aiStatusLabel,
        state: _aiStatusState,
      ),
      _FieldTestStatusItem(
        label: '재개 확인',
        value: requiresResumeConfirmation ? '필요' : '정상',
        state: requiresResumeConfirmation
            ? _FieldTestStatusState.blocked
            : _FieldTestStatusState.ready,
      ),
    ];
    final nextAction = _nextAction;
    final failureGuide = _failureGuide;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('현장 테스트 상태', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              '통제 경로 + 백업 동행자 기준으로만 확인합니다.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Text('테스트 단계', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            for (final stage in stageItems) ...[
              _FieldTestStageRow(
                stage: stage,
                color: _stateColor(context, stage.state),
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 4),
            Text('상세 상태', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            for (final item in items) ...[
              _FieldTestStatusRow(item: item),
              const SizedBox(height: 8),
            ],
            GuideFlowChecklistSection(
              state: _guideFlowState,
              enabled: _canConfirmGuideFlow,
              onItemChanged: onGuideFlowChecklistItemChanged,
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: _stateColor(context, nextAction.state).withValues(
                  alpha: 0.08,
                ),
                border: Border.all(
                  color: _stateColor(context, nextAction.state),
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      nextAction.icon,
                      color: _stateColor(context, nextAction.state),
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '다음 조작: ${nextAction.title}',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: _stateColor(
                                    context,
                                    nextAction.state,
                                  ),
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(nextAction.detail),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (failureGuide != null) ...[
              const SizedBox(height: 12),
              Text('문제 대응', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              _FieldTestFailureGuidePanel(
                guide: failureGuide,
                color: _stateColor(context, failureGuide.state),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              '상태는 화면에만 표시하며 원본 카메라, 채팅 원문, 개인 정보는 저장하지 않습니다.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  String get _liveStatusLabel {
    if (requiresResumeConfirmation) {
      return '정지 후 확인 필요';
    }
    if (isStartingMedia) {
      return '연결 준비';
    }
    if (isLive) {
      return '송출 중';
    }
    if (session?.status == LiveSessionStatus.paused) {
      return '일시정지';
    }
    return '대기';
  }

  _FieldTestStatusState get _liveStatusState {
    if (requiresResumeConfirmation) {
      return _FieldTestStatusState.blocked;
    }
    if (isLive) {
      return _FieldTestStatusState.ready;
    }
    if (isStartingMedia) {
      return _FieldTestStatusState.pending;
    }
    if (session?.status == LiveSessionStatus.paused) {
      return _FieldTestStatusState.warning;
    }
    return _FieldTestStatusState.pending;
  }

  _FieldTestStatusState get _webRtcStatusState {
    return switch (webRtcPhase) {
      WebRtcPhase.connected => _FieldTestStatusState.ready,
      WebRtcPhase.connectionLost ||
      WebRtcPhase.failed =>
        _FieldTestStatusState.blocked,
      WebRtcPhase.closed => _FieldTestStatusState.warning,
      WebRtcPhase.starting ||
      WebRtcPhase.waitingForAnswer ||
      WebRtcPhase.idle =>
        _FieldTestStatusState.pending,
    };
  }

  bool get _canConfirmGuideFlow {
    final sessionPurpose = session?.purpose ?? purpose;
    return isLive &&
        sessionPurpose == LiveSessionPurpose.runningGuide &&
        webRtcPhase == WebRtcPhase.connected &&
        !requiresResumeConfirmation;
  }

  List<_FieldTestStageItem> _stageItems(bool runningGuideReady) {
    return [
      _FieldTestStageItem(
        title: '사전 준비',
        detail: runningGuideReady
            ? '통제 경로, 백업 동행자, 오디오, 눈앞 카메라 각도 확인 완료'
            : '러닝 전 안전 체크와 눈앞 카메라 각도를 먼저 확인',
        icon: Icons.checklist,
        state: runningGuideReady
            ? _FieldTestStatusState.ready
            : _FieldTestStatusState.pending,
      ),
      _FieldTestStageItem(
        title: '라이브 연결',
        detail: _liveStageDetail,
        icon: Icons.video_call,
        state: _liveStageState,
      ),
      _FieldTestStageItem(
        title: '가이드 흐름',
        detail: guideFlowConfirmed
            ? 'WebRTC 영상, 가이드 음성, cue, 채팅 TTS, 정지/재개 확인 완료'
            : 'AI 보조 전에 가이드 흐름 5개 항목 확인 필요',
        icon: Icons.record_voice_over,
        state: guideFlowConfirmed
            ? _FieldTestStatusState.ready
            : _guideFlowStageState,
      ),
      _FieldTestStageItem(
        title: 'AI 검증',
        detail: _aiVerificationStageDetail,
        icon: Icons.science,
        state: _aiVerificationStageState,
      ),
      _FieldTestStageItem(
        title: '실제 AI 분석',
        detail: _aiAnalysisStageDetail,
        icon: Icons.visibility,
        state: _aiAnalysisStageState,
      ),
    ];
  }

  String get _liveStageDetail {
    if (requiresResumeConfirmation) {
      return '정지 후 안전 확인이 필요합니다.';
    }
    if (session == null) {
      return '세션 생성 전입니다.';
    }
    if (isStartingMedia) {
      return '카메라와 마이크 권한을 허용하고 있습니다.';
    }
    if (!isLive) {
      return '라이브 시작 전입니다. 권한 요청은 라이브 시작 후 표시됩니다.';
    }
    if (webRtcPhase == WebRtcPhase.connected) {
      return '가이드 기기와 WebRTC 연결 완료';
    }
    return '가이드 참여와 WebRTC 연결 확인 필요';
  }

  _FieldTestStatusState get _liveStageState {
    if (requiresResumeConfirmation) {
      return _FieldTestStatusState.blocked;
    }
    if (isLive && webRtcPhase == WebRtcPhase.connected) {
      return _FieldTestStatusState.ready;
    }
    if (isLive || isStartingMedia) {
      return _FieldTestStatusState.warning;
    }
    return _FieldTestStatusState.pending;
  }

  _FieldTestStatusState get _guideFlowStageState {
    if (requiresResumeConfirmation) {
      return _FieldTestStatusState.blocked;
    }
    if (_canConfirmGuideFlow) {
      return _FieldTestStatusState.pending;
    }
    return _FieldTestStatusState.warning;
  }

  String get _aiVerificationStageDetail {
    if (!guideFlowConfirmed) {
      return '가이드 흐름 5개 항목 확인 후 시작';
    }
    if (!aiAssistEnabled) {
      return 'AI 보조 안내 스위치를 켠 뒤 검증 모드를 사용';
    }
    if (!aiVerificationMode) {
      return '검증 모드를 켜고 감속/정지 큐 흐름 확인';
    }
    final decision = verificationDecision;
    if (decision == null) {
      return '감속 큐 테스트와 정지 큐 테스트를 순서대로 실행';
    }
    return '최근 검증 ${decision.level.label} ${decision.ageLabelAt(now)}';
  }

  _FieldTestStatusState get _aiVerificationStageState {
    if (!guideFlowConfirmed) {
      return _FieldTestStatusState.pending;
    }
    if (!aiAssistEnabled) {
      return _FieldTestStatusState.pending;
    }
    if (!aiVerificationMode) {
      return _FieldTestStatusState.pending;
    }
    return verificationDecision == null
        ? _FieldTestStatusState.warning
        : _FieldTestStatusState.ready;
  }

  String get _aiAnalysisStageDetail {
    if (!guideFlowConfirmed) {
      return '가이드 흐름 5개 항목과 AI 검증 후 정지 상태에서만 진행';
    }
    if (!aiAssistEnabled) {
      return 'AI 보조가 꺼져 있습니다.';
    }
    if (aiVerificationMode) {
      return '검증 모드에서는 실제 카메라 분석을 하지 않습니다.';
    }
    if (aiController.errorMessage != null) {
      return 'AI 분석 상태 확인 필요';
    }
    final decision = aiController.lastDecision;
    if (decision == null) {
      return '정지 상태에서 지금 분석 버튼으로 확인';
    }
    if (decision.isStaleAt(now)) {
      return '최근 판단이 오래됐습니다. 정지 상태에서 다시 분석';
    }
    return '최근 실제 분석 ${decision.level.label} ${decision.ageLabelAt(now)}';
  }

  _FieldTestStatusState get _aiAnalysisStageState {
    if (!guideFlowConfirmed || !aiAssistEnabled) {
      return _FieldTestStatusState.pending;
    }
    if (aiVerificationMode || aiController.errorMessage != null) {
      return _FieldTestStatusState.warning;
    }
    final decision = aiController.lastDecision;
    if (decision == null || decision.isStaleAt(now)) {
      return _FieldTestStatusState.warning;
    }
    return _FieldTestStatusState.ready;
  }

  String get _aiStatusLabel {
    if (!canUseAiVisionAssist) {
      return '전방 카메라 필요';
    }
    if (!aiAssistEnabled) {
      if (!guideFlowConfirmed) {
        return '가이드 흐름 5개 항목 먼저';
      }
      return '꺼짐';
    }
    if (aiVerificationMode) {
      final decision = verificationDecision;
      return decision == null
          ? '검증 모드 대기'
          : '검증 ${decision.level.label} ${decision.ageLabelAt(now)}';
    }
    final errorMessage = aiController.errorMessage;
    if (errorMessage != null) {
      return '확인 필요';
    }
    if (aiController.isAnalyzing) {
      return '분석 중';
    }
    if (aiController.isRunning) {
      final decision = aiController.lastDecision;
      if (decision == null) {
        return '실시간 보조';
      }

      final freshnessLabel = decision.isStaleAt(now) ? '오래된 판단' : '최근 판단';
      return '$freshnessLabel ${decision.level.label} ${decision.ageLabelAt(now)}';
    }
    return isLive ? '대기' : '라이브 후 대기';
  }

  _FieldTestStatusState get _aiStatusState {
    if (!canUseAiVisionAssist) {
      return _FieldTestStatusState.blocked;
    }
    if (!aiAssistEnabled) {
      return _FieldTestStatusState.pending;
    }
    if (aiVerificationMode) {
      return _FieldTestStatusState.warning;
    }
    if (aiController.errorMessage != null) {
      return _FieldTestStatusState.warning;
    }
    final decision = aiController.lastDecision;
    if (decision != null && decision.isStaleAt(now)) {
      return _FieldTestStatusState.warning;
    }
    if (aiController.isRunning) {
      return _FieldTestStatusState.ready;
    }
    return _FieldTestStatusState.pending;
  }

  _FieldTestNextAction get _nextAction {
    final sessionPurpose = session?.purpose ?? purpose;
    final sessionSourceMode = session?.sourceMode ?? sourceMode;

    if (requiresResumeConfirmation) {
      return const _FieldTestNextAction(
        title: '안전 확인 후 재개 버튼',
        detail: '러너가 멈췄고 카메라와 오디오가 안정적인 상태에서만 재개합니다.',
        icon: Icons.restart_alt,
        state: _FieldTestStatusState.blocked,
      );
    }
    if (sessionPurpose != LiveSessionPurpose.runningGuide) {
      return const _FieldTestNextAction(
        title: '방 종류에서 러닝 가이드 선택',
        detail: '러닝 테스트는 러닝 가이드 방에서만 진행합니다.',
        icon: Icons.directions_run,
        state: _FieldTestStatusState.pending,
      );
    }
    if (sessionSourceMode != LiveSourceMode.worldCamera) {
      return const _FieldTestNextAction(
        title: '방송 소스에서 눈앞 카메라 선택',
        detail: '가이드와 AI 보조가 전방 화면을 확인할 수 있어야 합니다.',
        icon: Icons.camera_alt,
        state: _FieldTestStatusState.pending,
      );
    }
    if (!preRunChecklistComplete) {
      return const _FieldTestNextAction(
        title: '러닝 전 안전 체크 완료',
        detail: '통제 경로, 백업 동행자, 카메라 각도, 오디오를 먼저 확인합니다.',
        icon: Icons.checklist,
        state: _FieldTestStatusState.pending,
      );
    }
    if (session == null) {
      return const _FieldTestNextAction(
        title: '라이브 세션 생성 버튼',
        detail: '세션을 만든 뒤 가이드가 참여할 수 있습니다.',
        icon: Icons.add_circle_outline,
        state: _FieldTestStatusState.pending,
      );
    }
    if (!isLive) {
      return const _FieldTestNextAction(
        title: '라이브 시작 버튼',
        detail: '러너는 정지한 상태에서 카메라와 마이크 권한을 허용합니다.',
        icon: Icons.play_circle,
        state: _FieldTestStatusState.pending,
      );
    }
    if (webRtcPhase != WebRtcPhase.connected) {
      return const _FieldTestNextAction(
        title: '가이드 참여 후 신호 새로고침',
        detail: '가이드 기기에서 참여한 뒤 WebRTC가 연결됨으로 바뀌는지 확인합니다.',
        icon: Icons.sync,
        state: _FieldTestStatusState.warning,
      );
    }
    if (!guideFlowConfirmed) {
      final missingItem = _nextMissingGuideFlowItem;
      return _FieldTestNextAction(
        title: missingItem == null ? '가이드 흐름 확인' : '${missingItem.label} 확인',
        detail: missingItem == null
            ? 'WebRTC 영상, 가이드 음성, cue 버튼, 짧은 채팅 TTS, 정지 후 재개를 모두 확인합니다.'
            : missingItem.detail,
        icon: missingItem?.icon ?? Icons.record_voice_over,
        state: _FieldTestStatusState.pending,
      );
    }
    if (!aiAssistEnabled) {
      return const _FieldTestNextAction(
        title: 'AI 보조 안내 스위치',
        detail: '가이드 흐름 5개 항목이 모두 확인된 상태에서만 AI 보조를 켭니다.',
        icon: Icons.visibility,
        state: _FieldTestStatusState.pending,
      );
    }
    if (aiVerificationMode) {
      return const _FieldTestNextAction(
        title: '감속 큐 테스트, 정지 큐 테스트',
        detail: '검증 모드는 카메라 분석 없이 TTS와 일시정지 흐름만 확인합니다.',
        icon: Icons.science,
        state: _FieldTestStatusState.warning,
      );
    }
    final decision = aiController.lastDecision;
    if (decision == null || decision.isStaleAt(now)) {
      return const _FieldTestNextAction(
        title: '지금 분석 버튼',
        detail: '러너를 정지시킨 뒤 안전한 테스트 물체로 실제 분석 상태를 확인합니다.',
        icon: Icons.refresh,
        state: _FieldTestStatusState.warning,
      );
    }
    return const _FieldTestNextAction(
      title: '정지와 재개 흐름 확인',
      detail: '연결 손실, 정지 큐, 안전 확인 후 재개가 예상대로 동작하는지 확인합니다.',
      icon: Icons.task_alt,
      state: _FieldTestStatusState.ready,
    );
  }

  _FieldTestFailureGuide? get _failureGuide {
    if (requiresResumeConfirmation) {
      return const _FieldTestFailureGuide(
        title: '정지 후 재개 확인 필요',
        detail: '연결 끊김 또는 정지 큐 이후에는 자동으로 계속하지 않습니다.',
        icon: Icons.pause_circle,
        state: _FieldTestStatusState.blocked,
        actions: [
          '러너 이동을 먼저 멈춥니다.',
          '백업 동행자가 가까이 있는지 확인합니다.',
          '카메라와 오디오가 안정적일 때만 안전 확인 후 재개합니다.',
          '재개 후 가이드 흐름 5개 항목을 다시 확인합니다.',
        ],
      );
    }

    final normalizedError = fieldErrorMessage?.toLowerCase();
    if (normalizedError != null) {
      if (normalizedError.contains('권한')) {
        return const _FieldTestFailureGuide(
          title: '권한 확인 필요',
          detail: '카메라 또는 마이크 권한을 사용할 수 없습니다.',
          icon: Icons.lock,
          state: _FieldTestStatusState.blocked,
          actions: [
            '러너를 정지 상태로 유지합니다.',
            'Android 앱 설정에서 카메라와 마이크 권한만 허용합니다.',
            '앱을 다시 열고 안전 체크부터 반복합니다.',
            '리포트에는 권한 거부 여부만 기록합니다.',
          ],
        );
      }
      if (normalizedError.contains('카메라') || normalizedError.contains('프레임')) {
        return const _FieldTestFailureGuide(
          title: '카메라 확인 필요',
          detail: '눈앞 카메라 preview 또는 AI 분석 프레임을 사용할 수 없습니다.',
          icon: Icons.videocam_off,
          state: _FieldTestStatusState.warning,
          actions: [
            '러너를 정지 상태로 유지합니다.',
            '방송 소스가 눈앞 카메라인지 확인합니다.',
            '다른 앱이 카메라를 사용 중인지 확인합니다.',
            'preview가 보인 뒤 카메라 각도를 다시 확인합니다.',
          ],
        );
      }
      if (normalizedError.contains('마이크') || normalizedError.contains('오디오')) {
        return const _FieldTestFailureGuide(
          title: '마이크 또는 오디오 확인 필요',
          detail: '가이드 음성 또는 마이크 시작 상태를 확인해야 합니다.',
          icon: Icons.mic_off,
          state: _FieldTestStatusState.warning,
          actions: [
            '러너를 정지 상태로 유지합니다.',
            '마이크 권한과 오디오 입력을 확인합니다.',
            '오픈이어, 한쪽 이어폰, 또는 스피커 출력으로 주변 소리를 유지합니다.',
            '가이드 음성이 들리기 전에는 가이드 음성 항목을 체크하지 않습니다.',
          ],
        );
      }
      if (normalizedError.contains('ai') || normalizedError.contains('분석')) {
        return const _FieldTestFailureGuide(
          title: 'AI 분석 확인 필요',
          detail: 'AI 보조는 실제 카메라 분석 전에 다시 확인해야 합니다.',
          icon: Icons.visibility_off,
          state: _FieldTestStatusState.warning,
          actions: [
            '러너를 정지 상태로 유지합니다.',
            '검증 모드가 꺼져 있는지 확인합니다.',
            '눈앞 카메라 preview와 각도를 확인합니다.',
            '지금 분석은 통제된 테스트 물체로만 실행합니다.',
          ],
        );
      }
    }

    if (webRtcPhase == WebRtcPhase.connectionLost ||
        webRtcPhase == WebRtcPhase.failed) {
      return const _FieldTestFailureGuide(
        title: 'WebRTC 연결 확인 필요',
        detail: '영상 또는 음성 연결이 안정적이지 않습니다.',
        icon: Icons.wifi_off,
        state: _FieldTestStatusState.blocked,
        actions: [
          '러너 이동을 먼저 멈춥니다.',
          '가이드가 현재 세션에 참여했는지 확인합니다.',
          '신호 새로고침을 누릅니다.',
          '계속 실패하면 세션을 새로 만들고 처음부터 확인합니다.',
        ],
      );
    }

    if (isLive && webRtcPhase == WebRtcPhase.waitingForAnswer) {
      return const _FieldTestFailureGuide(
        title: '가이드 연결 대기',
        detail: '가이드 기기와 WebRTC 연결이 아직 완료되지 않았습니다.',
        icon: Icons.sync,
        state: _FieldTestStatusState.warning,
        actions: [
          '러너를 정지 상태로 유지합니다.',
          '가이드가 현재 세션에 참여했는지 확인합니다.',
          '필요하면 신호 새로고침을 누릅니다.',
          '연결됨 상태 전에는 WebRTC 영상 확인 항목을 체크하지 않습니다.',
        ],
      );
    }

    if (isLive && webRtcPhase == WebRtcPhase.connected && !guideFlowConfirmed) {
      final missingItem = _nextMissingGuideFlowItem;
      return _FieldTestFailureGuide(
        title: '가이드 흐름 확인 필요',
        detail: missingItem == null
            ? 'AI 보조 전에 가이드 흐름 5개 항목을 모두 확인합니다.'
            : '${missingItem.label}: ${missingItem.detail}',
        icon: missingItem?.icon ?? Icons.record_voice_over,
        state: _FieldTestStatusState.pending,
        actions: [
          '러너를 정지 상태로 유지합니다.',
          'WebRTC 영상 확인, 가이드 음성, cue 버튼, 짧은 채팅 TTS, 정지 큐 후 재개 확인을 각각 체크합니다.',
          '누락된 항목은 실제로 확인된 뒤에만 체크합니다.',
          '5개 항목이 모두 확인되기 전에는 AI 보조를 켜지 않습니다.',
        ],
      );
    }

    if (aiAssistEnabled && aiVerificationMode && verificationDecision == null) {
      return const _FieldTestFailureGuide(
        title: 'AI 검증 모드 대기',
        detail: '검증 모드는 카메라 분석 없이 안내 흐름만 확인합니다.',
        icon: Icons.science,
        state: _FieldTestStatusState.warning,
        actions: [
          '러너를 정지 상태로 유지합니다.',
          '감속 큐 테스트를 먼저 누릅니다.',
          '정지 큐 테스트 후 재개 확인이 필요한지 확인합니다.',
          '검증 실패 시 실제 AI 분석을 진행하지 않습니다.',
        ],
      );
    }

    return null;
  }

  Color _stateColor(BuildContext context, _FieldTestStatusState state) {
    final colorScheme = Theme.of(context).colorScheme;
    return switch (state) {
      _FieldTestStatusState.ready => colorScheme.primary,
      _FieldTestStatusState.pending => colorScheme.onSurfaceVariant,
      _FieldTestStatusState.warning => const Color(0xFFB45309),
      _FieldTestStatusState.blocked => colorScheme.error,
    };
  }
}

class _FieldTestStatusRow extends StatelessWidget {
  const _FieldTestStatusRow({required this.item});

  final _FieldTestStatusItem item;

  @override
  Widget build(BuildContext context) {
    final color = _stateColor(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(_stateIcon, color: color, size: 18),
        const SizedBox(width: 8),
        SizedBox(
          width: 86,
          child: Text(
            item.label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        Expanded(
          child: Text(
            item.value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ],
    );
  }

  IconData get _stateIcon {
    return switch (item.state) {
      _FieldTestStatusState.ready => Icons.check_circle,
      _FieldTestStatusState.pending => Icons.radio_button_unchecked,
      _FieldTestStatusState.warning => Icons.warning_amber,
      _FieldTestStatusState.blocked => Icons.error,
    };
  }

  Color _stateColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return switch (item.state) {
      _FieldTestStatusState.ready => colorScheme.primary,
      _FieldTestStatusState.pending => colorScheme.onSurfaceVariant,
      _FieldTestStatusState.warning => const Color(0xFFB45309),
      _FieldTestStatusState.blocked => colorScheme.error,
    };
  }
}

class _FieldTestFailureGuidePanel extends StatelessWidget {
  const _FieldTestFailureGuidePanel({
    required this.guide,
    required this.color,
  });

  final _FieldTestFailureGuide guide;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(guide.icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        guide.title,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: color,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 3),
                      Text(guide.detail),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final action in guide.actions)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.arrow_right, color: color, size: 18),
                    const SizedBox(width: 4),
                    Expanded(child: Text(action)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FieldTestStageRow extends StatelessWidget {
  const _FieldTestStageRow({
    required this.stage,
    required this.color,
  });

  final _FieldTestStageItem stage;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(stage.icon, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stage.title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 3),
                  Text(stage.detail),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PurposeSelector extends StatelessWidget {
  const _PurposeSelector({
    required this.selectedPurpose,
    required this.enabled,
    required this.onSelected,
  });

  final LiveSessionPurpose selectedPurpose;
  final bool enabled;
  final ValueChanged<LiveSessionPurpose> onSelected;

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
            Text('방 종류', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final purpose in LiveSessionPurpose.values)
                  ChoiceChip(
                    label: Text(purpose.label),
                    selected: purpose == selectedPurpose,
                    onSelected: enabled ? (_) => onSelected(purpose) : null,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RunnerVisionModeSelector extends StatelessWidget {
  const _RunnerVisionModeSelector({
    required this.selectedMode,
    required this.enabled,
    required this.onSelected,
  });

  final RunnerVisionMode selectedMode;
  final bool enabled;
  final ValueChanged<RunnerVisionMode> onSelected;

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
            Text('러너 모드', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final mode in RunnerVisionMode.values)
                  ChoiceChip(
                    label: Text(mode.label),
                    selected: mode == selectedMode,
                    onSelected: enabled ? (_) => onSelected(mode) : null,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              selectedMode.guidanceLabel,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

extension _RunnerVisionModeGuidance on RunnerVisionMode {
  String get guidanceLabel {
    return switch (this) {
      RunnerVisionMode.sighted => '화면 조작이 가능하지만 원격 가이드와 안전 체크를 유지합니다.',
      RunnerVisionMode.lowVision => '큰 화면 요소와 음성 안내를 함께 사용합니다.',
      RunnerVisionMode.blind => '화면 버튼에 의존하지 않고 길게 누르기와 음성 안내를 기본으로 사용합니다.',
    };
  }
}

class _SourceModeSelector extends StatelessWidget {
  const _SourceModeSelector({
    required this.selectedSourceMode,
    required this.enabled,
    required this.onSelected,
  });

  final LiveSourceMode selectedSourceMode;
  final bool enabled;
  final ValueChanged<LiveSourceMode> onSelected;

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
            Text('방송 소스', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final sourceMode in LiveSourceMode.values)
                  ChoiceChip(
                    label: Text(sourceMode.label),
                    selected: sourceMode == selectedSourceMode,
                    onSelected: enabled ? (_) => onSelected(sourceMode) : null,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChannelPanel extends StatelessWidget {
  const _ChannelPanel({
    required this.controller,
    required this.channel,
    required this.supportEnabled,
    required this.enabled,
    required this.onSupportEnabledChanged,
    required this.onCreateChannel,
  });

  final TextEditingController controller;
  final Channel? channel;
  final bool supportEnabled;
  final bool enabled;
  final ValueChanged<bool> onSupportEnabledChanged;
  final VoidCallback onCreateChannel;

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
            Text('채널', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            if (channel == null) ...[
              TextField(
                controller: controller,
                enabled: enabled,
                maxLength: 40,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: '채널 이름',
                  counterText: '',
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('후원 받기'),
                value: supportEnabled,
                onChanged: enabled ? onSupportEnabledChanged : null,
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: enabled ? onCreateChannel : null,
                child: const Text('채널 만들기'),
              ),
            ] else ...[
              Text(channel!.title),
              const SizedBox(height: 4),
              Text('채널 코드: ${channel!.channelCode}'),
              const SizedBox(height: 4),
              SelectableText('채널 링크: ${channel!.channelLink}'),
              const SizedBox(height: 4),
              Text(channel!.supportEnabled ? '후원 가능' : '후원 꺼짐'),
            ],
          ],
        ),
      ),
    );
  }
}

enum _PreRunChecklistItem {
  controlledRoute,
  phoneMounted,
  cameraAngle,
  emergencyStopGesture,
  audioReady,
  guideVisibility,
  networkBattery,
  backupReady,
}

extension _PreRunChecklistItemLabel on _PreRunChecklistItem {
  String get label {
    return switch (this) {
      _PreRunChecklistItem.controlledRoute => '통제되고 익숙한 경로입니다.',
      _PreRunChecklistItem.phoneMounted => '휴대폰이 앞을 보도록 단단히 고정됐습니다.',
      _PreRunChecklistItem.cameraAngle => '화면에 전방 주로와 발밑 가장자리가 함께 보입니다.',
      _PreRunChecklistItem.emergencyStopGesture =>
        '화면 아무 곳이나 길게 누르면 정지 요청이 됩니다.',
      _PreRunChecklistItem.audioReady => '오픈이어 또는 이어폰 출력이 연결됐습니다.',
      _PreRunChecklistItem.guideVisibility => '가이드가 바닥과 전방을 볼 수 있습니다.',
      _PreRunChecklistItem.networkBattery => '네트워크와 배터리가 충분합니다.',
      _PreRunChecklistItem.backupReady => '비상 정지와 백업 동행자를 확인했습니다.',
    };
  }
}

class _PreRunChecklistPanel extends StatelessWidget {
  const _PreRunChecklistPanel({
    required this.runnerVisionMode,
    required this.sourceMode,
    required this.confirmedItems,
    required this.enabled,
    required this.onChanged,
  });

  final RunnerVisionMode runnerVisionMode;
  final LiveSourceMode sourceMode;
  final Set<_PreRunChecklistItem> confirmedItems;
  final bool enabled;
  final void Function(_PreRunChecklistItem item, bool checked) onChanged;

  @override
  Widget build(BuildContext context) {
    final cameraReady = sourceMode == LiveSourceMode.worldCamera;
    final allChecked =
        confirmedItems.length == _PreRunChecklistItem.values.length;
    final ready = cameraReady && allChecked;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(
          color: ready
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outlineVariant,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('러닝 전 안전 체크', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('러너 모드: ${runnerVisionMode.label}'),
            const SizedBox(height: 8),
            Text(
              cameraReady ? '카메라: 눈앞 카메라' : '카메라: 눈앞 카메라로 변경 필요',
              style: TextStyle(
                color: cameraReady
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            for (final item in _PreRunChecklistItem.values)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(item.label),
                value: confirmedItems.contains(item),
                onChanged:
                    enabled ? (value) => onChanged(item, value ?? false) : null,
              ),
          ],
        ),
      ),
    );
  }
}

class _CameraPreviewPlaceholder extends StatelessWidget {
  const _CameraPreviewPlaceholder({
    required this.isLive,
    required this.sourceMode,
    required this.controller,
  });

  final bool isLive;
  final LiveSourceMode sourceMode;
  final LiveWebRtcController controller;

  @override
  Widget build(BuildContext context) {
    final stream = controller.localRenderer.srcObject;
    if (stream != null && sourceMode != LiveSourceMode.audioOnly) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              RTCVideoView(
                controller.localRenderer,
                mirror: sourceMode == LiveSourceMode.selfieCamera,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              ),
              if (sourceMode == LiveSourceMode.worldCamera)
                const _RunningCameraGuideOverlay(),
            ],
          ),
        ),
      );
    }

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            isLive && sourceMode == LiveSourceMode.audioOnly
                ? '오디오 방송 중'
                : isLive
                    ? '라이브 송출 중'
                    : '카메라 대기',
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
        ),
      ),
    );
  }
}

class _RunningCameraGuideOverlay extends StatelessWidget {
  const _RunningCameraGuideOverlay();

  @override
  Widget build(BuildContext context) {
    const lineColor = Color(0xE6FFFFFF);
    const shadowColor = Color(0x99000000);

    return IgnorePointer(
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _RunningCameraGuidePainter()),
          ),
          const Positioned(
            top: 10,
            left: 12,
            child: _OverlayLabel(
              text: '전방',
              lineColor: lineColor,
              shadowColor: shadowColor,
            ),
          ),
          const Positioned(
            left: 12,
            bottom: 12,
            child: _OverlayLabel(
              text: '발밑',
              lineColor: lineColor,
              shadowColor: shadowColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _RunningCameraGuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final centerX = size.width / 2;
    final horizonY = size.height * 0.42;
    final footY = size.height * 0.78;
    canvas.drawLine(Offset(0, horizonY), Offset(size.width, horizonY), paint);
    canvas.drawLine(Offset(0, footY), Offset(size.width, footY), paint);
    canvas.drawLine(Offset(centerX, 0), Offset(centerX, size.height), paint);

    final pathPaint = Paint()
      ..color = const Color(0x660F766E)
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(size.width * 0.42, horizonY)
      ..lineTo(size.width * 0.58, horizonY)
      ..lineTo(size.width * 0.78, size.height)
      ..lineTo(size.width * 0.22, size.height)
      ..close();
    canvas.drawPath(path, pathPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _OverlayLabel extends StatelessWidget {
  const _OverlayLabel({
    required this.text,
    required this.lineColor,
    required this.shadowColor,
  });

  final String text;
  final Color lineColor;
  final Color shadowColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: shadowColor,
        border: Border.all(color: lineColor),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
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

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    required this.lastCue,
    required this.channel,
    required this.session,
    required this.runnerVisionMode,
    required this.signalState,
    required this.errorMessage,
    required this.requiresResumeConfirmation,
    required this.recentCueEvents,
  });

  final VoiceCue lastCue;
  final Channel? channel;
  final LiveSession? session;
  final RunnerVisionMode runnerVisionMode;
  final SignalState? signalState;
  final String? errorMessage;
  final bool requiresResumeConfirmation;
  final List<GuidanceCueEvent> recentCueEvents;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('라이브 상태', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (session == null)
              const Text('세션을 생성하면 참여 코드가 표시됩니다.')
            else ...[
              Text('참여 코드: ${session!.joinCode}'),
              const SizedBox(height: 4),
              SelectableText('참여 링크: ${session!.joinLink}'),
              const SizedBox(height: 4),
              Text('방 종류: ${session!.purpose.label}'),
              const SizedBox(height: 4),
              Text('방송 소스: ${session!.sourceMode.label}'),
              if (session!.purpose == LiveSessionPurpose.runningGuide) ...[
                const SizedBox(height: 4),
                Text(
                  '러너 모드: ${(session!.runnerVisionMode ?? runnerVisionMode).label}',
                ),
              ],
              const SizedBox(height: 4),
              Text('서버 상태: ${_statusLabel(session!.status)}'),
              if (channel != null) ...[
                const SizedBox(height: 4),
                Text('채널: ${channel!.title}'),
              ],
              const SizedBox(height: 4),
              Text(_signalLabel(signalState)),
              const SizedBox(height: 4),
              Text(_iceLabel(signalState)),
              const SizedBox(height: 12),
            ],
            Text(
              lastCue.label,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
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
            if (requiresResumeConfirmation) ...[
              const SizedBox(height: 8),
              Text(
                '재개 전 안전 확인 필요',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
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

  String _statusLabel(LiveSessionStatus status) {
    return switch (status) {
      LiveSessionStatus.waitingForSupporter => '참여 대기',
      LiveSessionStatus.connected => '연결됨',
      LiveSessionStatus.live => '라이브',
      LiveSessionStatus.paused => '일시정지',
      LiveSessionStatus.ended => '종료',
    };
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../core/safety/cue_speaker.dart';
import '../../core/safety/screen_awake.dart';
import '../../core/safety/voice_cues.dart';
import '../ai/ai_vision_assist_controller.dart';
import '../ai/ai_vision_models.dart';
import 'field_test_mode.dart';
import 'field_test_result_record.dart';
import 'field_test_result_record_view.dart';
import 'field_test_start_checklist.dart';
import 'field_test_start_checklist_view.dart';
import 'guide_flow_accessibility_widgets.dart';
import 'guide_flow_checklist.dart';
import 'live_chat_panel.dart';
import 'live_session_api.dart';
import 'live_models.dart';
import 'live_signaling_models.dart';
import 'live_webrtc_controller.dart';
import 'test_execution_checklist.dart';
import 'test_execution_checklist_view.dart';
import 'test_progress_guard.dart';
import 'test_progress_guard_view.dart';
import 'test_status_observer.dart';
import 'test_status_observer_view.dart';
import 'test_session_report.dart';
import 'test_session_report_view.dart';

class LiveHostPage extends StatefulWidget {
  const LiveHostPage({super.key});

  @override
  State<LiveHostPage> createState() => _LiveHostPageState();
}

class _LiveHostPageState extends State<LiveHostPage> {
  final LiveSessionApi _api = LiveSessionApi();
  final TextEditingController _channelTitleController = TextEditingController();
  final TextEditingController _fieldTestFailureStepController =
      TextEditingController();
  final TextEditingController _fieldTestExpectedResultController =
      TextEditingController();
  final TextEditingController _fieldTestActualResultController =
      TextEditingController();
  final TextEditingController _fieldTestReproductionStepsController =
      TextEditingController();
  final TextEditingController _fieldTestResultStepController =
      TextEditingController();
  final TextEditingController _fieldTestResultObservationController =
      TextEditingController();
  final TextEditingController _fieldTestResultNextActionController =
      TextEditingController();
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
  bool _fieldTestModeActive = false;
  bool _fieldTestSensitiveInfoRemoved = false;
  bool _fieldTestResultRetestNeeded = false;
  bool _requiresResumeConfirmation = false;
  String? _errorMessage;
  Channel? _channel;
  LiveSession? _session;
  SignalState? _signalState;
  DateTime _statusNow = DateTime.now();
  AiHazardDecision? _lastAiVerificationDecision;
  FieldTestModeSummary? _lastFieldTestSummary;
  FieldTestResultOutcome? _fieldTestResultOutcome;
  final Set<_PreRunChecklistItem> _confirmedPreRunItems =
      <_PreRunChecklistItem>{};
  final Set<GuideFlowChecklistItem> _confirmedGuideFlowItems =
      <GuideFlowChecklistItem>{};
  final Set<TestExecutionChecklistItem> _completedTestExecutionItems =
      <TestExecutionChecklistItem>{};
  final Set<FieldTestStartChecklistItem> _completedFieldTestStartItems =
      <FieldTestStartChecklistItem>{};
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
    _fieldTestFailureStepController.dispose();
    _fieldTestExpectedResultController.dispose();
    _fieldTestActualResultController.dispose();
    _fieldTestReproductionStepsController.dispose();
    _fieldTestResultStepController.dispose();
    _fieldTestResultObservationController.dispose();
    _fieldTestResultNextActionController.dispose();
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
                    _clearFieldTestModeState();
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
                      _clearFieldTestModeState();
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
                    _clearFieldTestModeState();
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
                  animation: _webRtc,
                  builder: (context, _) {
                    return AnimatedBuilder(
                      animation: _aiAssist,
                      builder: (context, _) {
                        return TestStatusObserverView(
                          state: _runnerTestStatusObserverState,
                        );
                      },
                    );
                  },
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
                      verificationModeBlockedReason:
                          _runnerTestProgressGuardState.aiVerification.allowed
                              ? null
                              : _runnerTestProgressGuardState
                                  .aiVerification.reason,
                      actualAnalysisBlockedReason:
                          _runnerTestProgressGuardState.actualAiAnalysis.allowed
                              ? null
                              : _runnerTestProgressGuardState
                                  .actualAiAnalysis.reason,
                      onEnabledChanged: _setAiAssistEnabled,
                      onVerificationModeChanged: _setAiVisionVerificationMode,
                      onAnalyzeNow: _isLive &&
                              _aiAssistEnabled &&
                              !_aiVisionVerificationMode &&
                              _runnerTestProgressGuardState
                                  .actualAiAnalysis.allowed
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
                          guideFlowDisabledHint:
                              _runnerTestProgressGuardState.guideFlow.reason,
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
              if (_showsPreRunChecklist) ...[
                const SizedBox(height: 16),
                AnimatedBuilder(
                  animation: _webRtc,
                  builder: (context, _) {
                    return AnimatedBuilder(
                      animation: _aiAssist,
                      builder: (context, _) {
                        return _FieldTestModePanel(
                          gate: _fieldTestModeStartGate,
                          snapshot: _fieldTestModeSnapshot,
                          testOrderState: _fieldTestDeviceTestOrderState,
                          executionChecklistState: _testExecutionChecklistState,
                          onExecutionChecklistItemChanged:
                              _setTestExecutionChecklistItem,
                          startChecklistState: _fieldTestStartChecklistState,
                          onStartChecklistItemChanged:
                              _setFieldTestStartChecklistItem,
                          progressGuardState: _runnerTestProgressGuardState,
                          report: _fieldTestSessionReport,
                          active: _fieldTestModeActive,
                          lastSummary: _lastFieldTestSummary,
                          memo: _fieldTestResultMemo,
                          failureStepController:
                              _fieldTestFailureStepController,
                          expectedResultController:
                              _fieldTestExpectedResultController,
                          actualResultController:
                              _fieldTestActualResultController,
                          reproductionStepsController:
                              _fieldTestReproductionStepsController,
                          sensitiveInfoRemoved: _fieldTestSensitiveInfoRemoved,
                          onSensitiveInfoRemovedChanged:
                              _setFieldTestSensitiveInfoRemoved,
                          onMemoChanged: _refreshFieldTestMemoPreview,
                          resultRecord: _fieldTestResultRecord,
                          selectedResultOutcome: _fieldTestResultOutcome,
                          resultStepController: _fieldTestResultStepController,
                          resultObservationController:
                              _fieldTestResultObservationController,
                          resultNextActionController:
                              _fieldTestResultNextActionController,
                          resultRetestNeeded: _fieldTestResultRetestNeeded,
                          onResultOutcomeChanged: _setFieldTestResultOutcome,
                          onResultRetestNeededChanged:
                              _setFieldTestResultRetestNeeded,
                          onResultTextChanged:
                              _refreshFieldTestResultRecordPreview,
                          onStart: _startFieldTestMode,
                          onEnd: _endFieldTestMode,
                          onDismissSummary: _dismissFieldTestSummary,
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

  FieldTestModeStartGate get _fieldTestModeStartGate {
    final purpose = _session?.purpose ?? _purpose;
    final sourceMode = _session?.sourceMode ?? _sourceMode;
    return FieldTestModeStartGate(
      isRunningGuide: purpose == LiveSessionPurpose.runningGuide,
      isWorldCamera: sourceMode == LiveSourceMode.worldCamera,
      runnerModeSelected: true,
    );
  }

  FieldTestModeSnapshot get _fieldTestModeSnapshot {
    return FieldTestModeSnapshot(
      guideFlowState: _guideFlowState,
      preRunChecklistComplete: _isPreRunChecklistComplete,
      sessionCreated: _session != null,
      isLive: _isLive,
      webRtcConnected: _webRtc.phase == WebRtcPhase.connected,
      webRtcStatusLabel: _webRtc.phase.label,
      aiAssistStatusLabel: _fieldTestAiAssistStatusLabel,
      aiAssistEnabled: _aiAssistEnabled,
      aiVerificationMode: _aiVisionVerificationMode,
      requiresResumeConfirmation: _requiresResumeConfirmation,
      lastSafetyCueLabel: _lastCue.label,
    );
  }

  FieldTestDeviceTestOrderState get _fieldTestDeviceTestOrderState {
    final purpose = _session?.purpose ?? _purpose;
    final sourceMode = _session?.sourceMode ?? _sourceMode;
    return FieldTestDeviceTestOrderState(
      isRunningGuide: purpose == LiveSessionPurpose.runningGuide,
      runnerModeSelected: true,
      isWorldCamera: sourceMode == LiveSourceMode.worldCamera,
      preRunChecklistComplete: _isPreRunChecklistComplete,
      sessionCreated: _session != null,
      isLive: _isLive,
      webRtcConnected: _webRtc.phase == WebRtcPhase.connected,
      guideFlowState: _guideFlowState,
      aiVerificationChecked: _lastAiVerificationDecision != null,
      actualAiAnalysisChecked:
          !_aiVisionVerificationMode && _aiAssist.lastDecision != null,
    );
  }

  FieldTestResultMemo get _fieldTestResultMemo {
    return FieldTestResultMemo.fromInput(
      failureStep: _fieldTestFailureStepController.text,
      expectedResult: _fieldTestExpectedResultController.text,
      actualResult: _fieldTestActualResultController.text,
      reproductionSteps: _fieldTestReproductionStepsController.text,
      sensitiveInfoRemoved: _fieldTestSensitiveInfoRemoved,
    );
  }

  FieldTestResultRecord get _fieldTestResultRecord {
    return FieldTestResultRecord.fromInput(
      outcome: _fieldTestResultOutcome,
      step: _fieldTestResultStepController.text,
      observation: _fieldTestResultObservationController.text,
      nextAction: _fieldTestResultNextActionController.text,
      retestNeeded: _fieldTestResultRetestNeeded,
    );
  }

  TestExecutionChecklistState get _testExecutionChecklistState {
    return TestExecutionChecklistState(_completedTestExecutionItems);
  }

  FieldTestStartChecklistState get _fieldTestStartChecklistState {
    return FieldTestStartChecklistState(_completedFieldTestStartItems);
  }

  RunnerTestProgressGuardState get _runnerTestProgressGuardState {
    return RunnerTestProgressGuardState(
      isLive: _isLive,
      webRtcConnected: _webRtc.phase == WebRtcPhase.connected,
      guideFlowComplete: _guideFlowState.allowsAiAssist,
      aiVerificationChecked: _lastAiVerificationDecision != null,
      reportReady: _fieldTestSessionReport.isReady,
    );
  }

  RunnerTestStatusObserverState get _runnerTestStatusObserverState {
    final connectionLost = _webRtc.safetyStopRequired ||
        _webRtc.phase == WebRtcPhase.connectionLost ||
        _webRtc.phase == WebRtcPhase.failed;
    final actualAiAnalysisAvailable =
        _runnerTestProgressGuardState.actualAiAnalysis.allowed &&
            _isLive &&
            _aiAssistEnabled &&
            !_aiVisionVerificationMode &&
            !_requiresResumeConfirmation &&
            !connectionLost;
    return RunnerTestStatusObserverState(
      isLive: _isLive,
      webRtcConnected: _webRtc.phase == WebRtcPhase.connected,
      connectionLost: connectionLost,
      mediaPermissionsReady: _isLive || _webRtc.phase == WebRtcPhase.connected,
      guideFlowState: _guideFlowState,
      aiVerificationMode: _aiVisionVerificationMode,
      aiVerificationChecked: _lastAiVerificationDecision != null,
      actualAiAnalysisAvailable: actualAiAnalysisAvailable,
      requiresResumeConfirmation: _requiresResumeConfirmation,
    );
  }

  TestSessionReport get _fieldTestSessionReport {
    return TestSessionReport(
      role: TestSessionReportRole.runner,
      webRtcConnected: _webRtc.phase == WebRtcPhase.connected,
      guideFlowConfirmedCount: _guideFlowState.confirmedCount,
      guideFlowTotalCount: _guideFlowState.totalCount,
      aiVerificationChecked: _lastAiVerificationDecision != null,
      actualAiAnalysisChecked:
          !_aiVisionVerificationMode && _aiAssist.lastDecision != null,
      stopResumeConfirmed:
          _guideFlowState.contains(GuideFlowChecklistItem.stopResume) &&
              !_requiresResumeConfirmation,
      memo: _fieldTestResultMemo,
    );
  }

  String get _fieldTestAiAssistStatusLabel {
    if (!_canUseAiVisionAssist) {
      return '전방 카메라 필요';
    }
    if (!_isGuideFlowConfirmed) {
      return _guideFlowState.aiAssistGateLabel;
    }
    if (_aiAssistEnabled) {
      return _aiVisionVerificationMode ? '검증 모드' : '켜짐';
    }
    return '꺼짐';
  }

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

  void _setTestExecutionChecklistItem(
    TestExecutionChecklistItem item,
    bool checked,
  ) {
    setState(() {
      final nextState = _testExecutionChecklistState.updateItem(item, checked);
      _completedTestExecutionItems
        ..clear()
        ..addAll(nextState.completedItems);
    });
  }

  void _setFieldTestStartChecklistItem(
    FieldTestStartChecklistItem item,
    bool checked,
  ) {
    setState(() {
      final nextState = _fieldTestStartChecklistState.updateItem(item, checked);
      _completedFieldTestStartItems
        ..clear()
        ..addAll(nextState.completedItems);
      _errorMessage = null;
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
        _lastAiVerificationDecision = null;
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
    _lastAiVerificationDecision = null;
    _aiAssist.stop();
  }

  void _clearFieldTestModeState() {
    _fieldTestModeActive = false;
    _lastFieldTestSummary = null;
    _completedFieldTestStartItems.clear();
    _clearFieldTestMemo();
    _clearFieldTestResultRecord();
  }

  void _clearFieldTestMemo() {
    _fieldTestFailureStepController.clear();
    _fieldTestExpectedResultController.clear();
    _fieldTestActualResultController.clear();
    _fieldTestReproductionStepsController.clear();
    _fieldTestSensitiveInfoRemoved = false;
  }

  void _clearFieldTestResultRecord() {
    _fieldTestResultOutcome = null;
    _fieldTestResultStepController.clear();
    _fieldTestResultObservationController.clear();
    _fieldTestResultNextActionController.clear();
    _fieldTestResultRetestNeeded = false;
  }

  void _startFieldTestMode() {
    final gate = _fieldTestModeStartGate;
    if (!gate.canStart) {
      setState(() => _errorMessage = gate.statusLabel);
      return;
    }

    final startChecklistState = _fieldTestStartChecklistState;
    if (!startChecklistState.canStart) {
      setState(() => _errorMessage = startChecklistState.blockedReason);
      return;
    }

    setState(() {
      _fieldTestModeActive = true;
      _lastFieldTestSummary = null;
      _clearFieldTestResultRecord();
      _errorMessage = null;
    });
  }

  void _endFieldTestMode() {
    setState(() {
      _fieldTestModeActive = false;
      _lastFieldTestSummary = _fieldTestModeSnapshot.toSummary();
      _completedFieldTestStartItems.clear();
      _clearFieldTestMemo();
      _errorMessage = null;
    });
  }

  void _dismissFieldTestSummary() {
    setState(() {
      _lastFieldTestSummary = null;
      _clearFieldTestMemo();
      _clearFieldTestResultRecord();
    });
  }

  void _setFieldTestSensitiveInfoRemoved(bool checked) {
    setState(() => _fieldTestSensitiveInfoRemoved = checked);
  }

  void _setFieldTestResultOutcome(FieldTestResultOutcome? outcome) {
    setState(() {
      _fieldTestResultOutcome = outcome;
      _errorMessage = null;
    });
  }

  void _setFieldTestResultRetestNeeded(bool checked) {
    setState(() {
      _fieldTestResultRetestNeeded = checked;
      _errorMessage = null;
    });
  }

  void _refreshFieldTestMemoPreview() {
    setState(() {});
  }

  void _refreshFieldTestResultRecordPreview() {
    setState(() {});
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
    final guard = _runnerTestProgressGuardState.aiVerification;
    if (enabled && !guard.allowed) {
      setState(() {
        _aiVisionVerificationMode = false;
        _errorMessage = guard.reason;
      });
      _syncAiAssistWithLiveState();
      return;
    }

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
    required this.verificationModeBlockedReason,
    required this.actualAnalysisBlockedReason,
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
  final String? verificationModeBlockedReason;
  final String? actualAnalysisBlockedReason;
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
                onChanged: verificationModeEnabled ||
                        verificationModeBlockedReason == null
                    ? onVerificationModeChanged
                    : null,
              ),
              if (!verificationModeEnabled &&
                  verificationModeBlockedReason != null) ...[
                const SizedBox(height: 8),
                Semantics(
                  liveRegion: true,
                  label: 'AI 검증 모드 차단. $verificationModeBlockedReason',
                  child: Text(
                    verificationModeBlockedReason!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.error,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
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
              if (!verificationModeEnabled &&
                  actualAnalysisBlockedReason != null) ...[
                Semantics(
                  liveRegion: true,
                  label: '지금 분석 차단. $actualAnalysisBlockedReason',
                  child: Text(
                    actualAnalysisBlockedReason!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.error,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
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
    required this.guideFlowDisabledHint,
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
  final String guideFlowDisabledHint;
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
              disabledHint: guideFlowDisabledHint,
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

class _FieldTestModePanel extends StatelessWidget {
  const _FieldTestModePanel({
    required this.gate,
    required this.snapshot,
    required this.testOrderState,
    required this.executionChecklistState,
    required this.onExecutionChecklistItemChanged,
    required this.startChecklistState,
    required this.onStartChecklistItemChanged,
    required this.progressGuardState,
    required this.report,
    required this.active,
    required this.lastSummary,
    required this.memo,
    required this.failureStepController,
    required this.expectedResultController,
    required this.actualResultController,
    required this.reproductionStepsController,
    required this.sensitiveInfoRemoved,
    required this.onSensitiveInfoRemovedChanged,
    required this.onMemoChanged,
    required this.resultRecord,
    required this.selectedResultOutcome,
    required this.resultStepController,
    required this.resultObservationController,
    required this.resultNextActionController,
    required this.resultRetestNeeded,
    required this.onResultOutcomeChanged,
    required this.onResultRetestNeededChanged,
    required this.onResultTextChanged,
    required this.onStart,
    required this.onEnd,
    required this.onDismissSummary,
  });

  final FieldTestModeStartGate gate;
  final FieldTestModeSnapshot snapshot;
  final FieldTestDeviceTestOrderState testOrderState;
  final TestExecutionChecklistState executionChecklistState;
  final void Function(TestExecutionChecklistItem item, bool checked)
      onExecutionChecklistItemChanged;
  final FieldTestStartChecklistState startChecklistState;
  final void Function(FieldTestStartChecklistItem item, bool checked)
      onStartChecklistItemChanged;
  final RunnerTestProgressGuardState progressGuardState;
  final TestSessionReport report;
  final bool active;
  final FieldTestModeSummary? lastSummary;
  final FieldTestResultMemo memo;
  final TextEditingController failureStepController;
  final TextEditingController expectedResultController;
  final TextEditingController actualResultController;
  final TextEditingController reproductionStepsController;
  final bool sensitiveInfoRemoved;
  final ValueChanged<bool> onSensitiveInfoRemovedChanged;
  final VoidCallback onMemoChanged;
  final FieldTestResultRecord resultRecord;
  final FieldTestResultOutcome? selectedResultOutcome;
  final TextEditingController resultStepController;
  final TextEditingController resultObservationController;
  final TextEditingController resultNextActionController;
  final bool resultRetestNeeded;
  final ValueChanged<FieldTestResultOutcome?> onResultOutcomeChanged;
  final ValueChanged<bool> onResultRetestNeededChanged;
  final VoidCallback onResultTextChanged;
  final VoidCallback onStart;
  final VoidCallback onEnd;
  final VoidCallback onDismissSummary;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
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
            Text('현장 테스트 모드', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              '통제 경로 + 백업 동행자 기준으로만 실행합니다.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            _FieldTestDeviceOrderView(order: testOrderState),
            const SizedBox(height: 12),
            TestExecutionChecklistView(
              state: executionChecklistState,
              onItemChanged: onExecutionChecklistItemChanged,
            ),
            const SizedBox(height: 12),
            TestProgressGuardView(
              decisions: progressGuardState.decisions,
              talkBackSummary: progressGuardState.talkBackSummary,
            ),
            const SizedBox(height: 12),
            if (active)
              _ActiveFieldTestModeSummary(snapshot: snapshot, onEnd: onEnd)
            else ...[
              FieldTestStartChecklistView(
                state: startChecklistState,
                onItemChanged: onStartChecklistItemChanged,
              ),
              const SizedBox(height: 12),
              _FieldTestModeStartArea(
                gate: gate,
                startChecklistState: startChecklistState,
                onStart: onStart,
              ),
            ],
            if (!active && lastSummary != null) ...[
              const SizedBox(height: 12),
              _FieldTestModeSummaryView(
                summary: lastSummary!,
                memo: memo,
                report: report,
                failureStepController: failureStepController,
                expectedResultController: expectedResultController,
                actualResultController: actualResultController,
                reproductionStepsController: reproductionStepsController,
                sensitiveInfoRemoved: sensitiveInfoRemoved,
                onSensitiveInfoRemovedChanged: onSensitiveInfoRemovedChanged,
                onMemoChanged: onMemoChanged,
                onDismiss: onDismissSummary,
              ),
              const SizedBox(height: 12),
              FieldTestResultRecordView(
                record: resultRecord,
                selectedOutcome: selectedResultOutcome,
                stepController: resultStepController,
                observationController: resultObservationController,
                nextActionController: resultNextActionController,
                retestNeeded: resultRetestNeeded,
                onOutcomeChanged: onResultOutcomeChanged,
                onRetestNeededChanged: onResultRetestNeededChanged,
                onTextChanged: onResultTextChanged,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FieldTestDeviceOrderView extends StatelessWidget {
  const _FieldTestDeviceOrderView({required this.order});

  final FieldTestDeviceTestOrderState order;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      label: order.talkBackSummary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  '실기기 테스트 순서',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Text(
                    order.progressLabel,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final step in order.steps) ...[
            _FieldTestDeviceOrderStepRow(step: step),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}

class _FieldTestDeviceOrderStepRow extends StatelessWidget {
  const _FieldTestDeviceOrderStepRow({required this.step});

  final FieldTestDeviceTestStep step;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = _statusColor(context);
    return Semantics(
      label: step.semanticsLabel,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _statusBackgroundColor(context),
              border: Border.all(color: color),
            ),
            alignment: Alignment.center,
            child: Text(
              '${step.number}',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight:
                            step.status == FieldTestDeviceStepStatus.current
                                ? FontWeight.w800
                                : FontWeight.w700,
                      ),
                ),
                Text(
                  step.detail,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            step.status.label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return switch (step.status) {
      FieldTestDeviceStepStatus.completed => colorScheme.primary,
      FieldTestDeviceStepStatus.current => const Color(0xFFB45309),
      FieldTestDeviceStepStatus.pending => colorScheme.onSurfaceVariant,
    };
  }

  Color _statusBackgroundColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return switch (step.status) {
      FieldTestDeviceStepStatus.completed => colorScheme.primaryContainer,
      FieldTestDeviceStepStatus.current => const Color(0xFFFFF7ED),
      FieldTestDeviceStepStatus.pending => colorScheme.surface,
    };
  }
}

class _FieldTestModeStartArea extends StatelessWidget {
  const _FieldTestModeStartArea({
    required this.gate,
    required this.startChecklistState,
    required this.onStart,
  });

  final FieldTestModeStartGate gate;
  final FieldTestStartChecklistState startChecklistState;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final canStart = gate.canStart && startChecklistState.canStart;
    final statusLabel = canStart
        ? '실기기 테스트 모드를 시작할 수 있습니다.'
        : gate.canStart
            ? startChecklistState.blockedReason
            : gate.statusLabel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          liveRegion: true,
          label: statusLabel,
          child: Text(
            statusLabel,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: canStart
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: canStart ? onStart : null,
          icon: const Icon(Icons.play_circle),
          label: const Text('현장 테스트 모드 시작'),
        ),
      ],
    );
  }
}

class _ActiveFieldTestModeSummary extends StatelessWidget {
  const _ActiveFieldTestModeSummary({
    required this.snapshot,
    required this.onEnd,
  });

  final FieldTestModeSnapshot snapshot;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      label: snapshot.talkBackStatusLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '현재 단계: ${snapshot.stageLabel}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            '다음 조작',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          Text(
            snapshot.nextActionTitle,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(snapshot.nextActionDetail),
          const SizedBox(height: 12),
          _FieldTestModeStatusLine(
            label: '가이드 흐름',
            value: snapshot.guideFlowState.statusLabel,
          ),
          _FieldTestModeStatusLine(
            label: 'AI 보조',
            value: snapshot.aiAssistStatusLabel,
          ),
          _FieldTestModeStatusLine(
            label: 'WebRTC',
            value: snapshot.webRtcStatusLabel,
          ),
          if (snapshot.requiresResumeConfirmation)
            const _FieldTestModeStatusLine(label: '재개 확인', value: '필요'),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: onEnd,
            icon: const Icon(Icons.stop_circle),
            label: const Text('현장 테스트 모드 종료'),
          ),
        ],
      ),
    );
  }
}

class _FieldTestModeSummaryView extends StatelessWidget {
  const _FieldTestModeSummaryView({
    required this.summary,
    required this.memo,
    required this.report,
    required this.failureStepController,
    required this.expectedResultController,
    required this.actualResultController,
    required this.reproductionStepsController,
    required this.sensitiveInfoRemoved,
    required this.onSensitiveInfoRemovedChanged,
    required this.onMemoChanged,
    required this.onDismiss,
  });

  final FieldTestModeSummary summary;
  final FieldTestResultMemo memo;
  final TestSessionReport report;
  final TextEditingController failureStepController;
  final TextEditingController expectedResultController;
  final TextEditingController actualResultController;
  final TextEditingController reproductionStepsController;
  final bool sensitiveInfoRemoved;
  final ValueChanged<bool> onSensitiveInfoRemovedChanged;
  final VoidCallback onMemoChanged;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('테스트 요약', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          '화면에만 표시하며 참여 링크, 세션 코드, 채팅 원문, 카메라 원본, 위치 정보는 포함하지 않습니다.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 8),
        for (final row in summary.rows) ...[
          _FieldTestModeStatusLine(label: row.label, value: row.value),
          const SizedBox(height: 4),
        ],
        const SizedBox(height: 12),
        Text('테스트 결과 메모', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          '운영상 필요한 사실만 적으세요. 정확한 장소, 링크, 코드, 채팅 원문, 사람 얼굴/차량번호 설명은 적지 마세요.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 8),
        _FieldTestMemoTextField(
          controller: failureStepController,
          label: '실패 단계',
          hint: '예: 가이드 흐름 확인',
          onChanged: onMemoChanged,
        ),
        _FieldTestMemoTextField(
          controller: expectedResultController,
          label: '기대 결과',
          hint: '예: 짧은 채팅 TTS가 들림',
          onChanged: onMemoChanged,
        ),
        _FieldTestMemoTextField(
          controller: actualResultController,
          label: '실제 결과',
          hint: '예: TTS가 들리지 않음',
          onChanged: onMemoChanged,
        ),
        _FieldTestMemoTextField(
          controller: reproductionStepsController,
          label: '재현 순서',
          hint: '예: 라이브 연결 후 짧은 테스트 메시지 전송',
          onChanged: onMemoChanged,
          minLines: 2,
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('민감정보 제거 확인'),
          subtitle: const Text('링크, 코드, 채팅 원문, 카메라 원본, 위치 정보, 연락처를 적지 않았습니다.'),
          value: sensitiveInfoRemoved,
          onChanged: (value) => onSensitiveInfoRemovedChanged(value ?? false),
        ),
        Text(
          memo.safetyStatusLabel,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: memo.sensitiveInfoRemoved
                    ? colorScheme.primary
                    : colorScheme.error,
                fontWeight: FontWeight.w700,
              ),
        ),
        if (memo.lengthNotice != null) ...[
          const SizedBox(height: 4),
          Text(
            memo.lengthNotice!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFFB45309),
                ),
          ),
        ],
        if (!memo.isEmpty) ...[
          const SizedBox(height: 8),
          Text(
            memo.isReadyForLocalReview
                ? '메모가 화면에만 보관됩니다.'
                : '민감정보 제거 확인을 체크해야 합니다.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: memo.isReadyForLocalReview
                      ? colorScheme.onSurfaceVariant
                      : colorScheme.error,
                ),
          ),
        ],
        const SizedBox(height: 8),
        TestSessionReportView(report: report),
        const SizedBox(height: 8),
        TextButton(onPressed: onDismiss, child: const Text('요약 닫기')),
      ],
    );
  }
}

class _FieldTestMemoTextField extends StatelessWidget {
  const _FieldTestMemoTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.onChanged,
    this.minLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final VoidCallback onChanged;
  final int minLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: controller,
        minLines: minLines,
        maxLines: minLines + 1,
        maxLength: FieldTestResultMemo.maxFieldLength,
        onChanged: (_) => onChanged(),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          helperText: '운영 사실만 입력',
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

class _FieldTestModeStatusLine extends StatelessWidget {
  const _FieldTestModeStatusLine({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 96,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    );
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

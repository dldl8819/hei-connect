import 'package:flutter/material.dart';

import 'guide_flow_checklist.dart';

class AiAssistGateSwitchTile extends StatelessWidget {
  const AiAssistGateSwitchTile({
    super.key,
    required this.enabled,
    required this.canUse,
    required this.isLive,
    required this.guideFlowState,
    required this.verificationModeEnabled,
    required this.isAnalyzing,
    required this.isRunning,
    required this.onChanged,
  });

  final bool enabled;
  final bool canUse;
  final bool isLive;
  final GuideFlowChecklistState guideFlowState;
  final bool verificationModeEnabled;
  final bool isAnalyzing;
  final bool isRunning;
  final ValueChanged<bool> onChanged;

  bool get _canToggle => canUse && guideFlowState.allowsAiAssist;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'AI 보조 안내',
      hint: _statusText,
      enabled: _canToggle,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.visibility),
          title: const Text('AI 보조 안내'),
          subtitle: Text(_statusText),
          value: enabled,
          onChanged: _canToggle ? onChanged : null,
        ),
      ),
    );
  }

  String get _statusText {
    if (!canUse) {
      return '러닝 가이드의 전방 카메라 모드에서만 사용할 수 있습니다.';
    }
    if (!guideFlowState.allowsAiAssist) {
      return guideFlowState.aiAssistGateLabel;
    }
    if (!enabled) {
      return 'AI 보조 사용 가능. 통제 경로와 백업 동행자 기준을 유지합니다.';
    }
    if (verificationModeEnabled) {
      return '검증 모드입니다. 카메라 분석 없이 큐 흐름만 확인합니다.';
    }
    if (isAnalyzing) {
      return '분석 중';
    }
    if (isRunning && isLive) {
      return '실시간 보조 중';
    }
    return '라이브 시작 후 자동으로 동작합니다.';
  }
}

class GuideFlowChecklistSection extends StatelessWidget {
  const GuideFlowChecklistSection({
    super.key,
    required this.state,
    required this.enabled,
    required this.onItemChanged,
  });

  final GuideFlowChecklistState state;
  final bool enabled;
  final void Function(GuideFlowChecklistItem item, bool checked) onItemChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('가이드 흐름 세부 확인', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Semantics(
          liveRegion: true,
          label: state.progressSemanticsLabel,
          child: Text(
            state.progressLabel,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '러너가 정지한 상태에서 각 항목을 따로 확인합니다.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 4),
        for (final item in GuideFlowChecklistState.items)
          _GuideFlowChecklistTile(
            item: item,
            checked: state.contains(item),
            enabled: enabled,
            onChanged: onItemChanged,
          ),
      ],
    );
  }
}

class GuideFlowNextActionSummary extends StatelessWidget {
  const GuideFlowNextActionSummary({
    super.key,
    required this.state,
  });

  final GuideFlowChecklistState state;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: '${state.nextActionTitle}. ${state.nextActionDetail}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(state.nextActionTitle),
          Text(state.nextActionDetail),
        ],
      ),
    );
  }
}

class _GuideFlowChecklistTile extends StatelessWidget {
  const _GuideFlowChecklistTile({
    required this.item,
    required this.checked,
    required this.enabled,
    required this.onChanged,
  });

  final GuideFlowChecklistItem item;
  final bool checked;
  final bool enabled;
  final void Function(GuideFlowChecklistItem item, bool checked) onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: item.checkedSemanticsLabel(checked),
      hint: enabled ? item.checkHint : '라이브와 WebRTC 연결 후 확인할 수 있습니다.',
      checked: checked,
      enabled: enabled,
      child: CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        dense: false,
        secondary: Icon(item.icon),
        title: Text(item.label),
        subtitle: Text(item.detail),
        value: checked,
        onChanged: enabled ? (value) => onChanged(item, value ?? false) : null,
      ),
    );
  }
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

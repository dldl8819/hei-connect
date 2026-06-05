import 'dart:async';

import 'package:flutter/material.dart';

import 'live_models.dart';
import 'live_session_api.dart';

class LiveChatPanel extends StatefulWidget {
  const LiveChatPanel({
    super.key,
    required this.api,
    required this.session,
    required this.senderRole,
    this.onNewMessages,
    this.onMessageSent,
    this.title = '채팅',
    this.description,
    this.emptyText = '아직 메시지가 없습니다.',
    this.inputLabel = '짧은 메시지',
  });

  final LiveSessionApi api;
  final LiveSession session;
  final ChatSenderRole senderRole;
  final ValueChanged<List<LiveChatMessage>>? onNewMessages;
  final ValueChanged<LiveChatMessage>? onMessageSent;
  final String title;
  final String? description;
  final String emptyText;
  final String inputLabel;

  @override
  State<LiveChatPanel> createState() => _LiveChatPanelState();
}

class _LiveChatPanelState extends State<LiveChatPanel> {
  final TextEditingController _messageController = TextEditingController();
  Timer? _pollTimer;

  bool _isSending = false;
  String? _errorMessage;
  List<LiveChatMessage> _messages = const [];
  int _lastDeliveredSequence = 0;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void didUpdateWidget(covariant LiveChatPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session.sessionId != widget.session.sessionId) {
      _messages = const [];
      _lastDeliveredSequence = 0;
      _errorMessage = null;
      _messageController.clear();
      _startPolling();
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _messageController.dispose();
    super.dispose();
  }

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
            Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
            if (widget.description != null) ...[
              const SizedBox(height: 4),
              Text(
                widget.description!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
            const SizedBox(height: 8),
            if (_messages.isEmpty)
              Text(widget.emptyText)
            else
              for (final message in _messages.reversed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 56,
                        child: Text(_senderLabel(message.senderRole)),
                      ),
                      Expanded(child: Text(message.body)),
                    ],
                  ),
                ),
            const SizedBox(height: 8),
            TextField(
              controller: _messageController,
              enabled: !_isSending,
              maxLength: 280,
              minLines: 1,
              maxLines: 3,
              textInputAction: TextInputAction.send,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                counterText: '',
              ).copyWith(labelText: widget.inputLabel),
              onSubmitted: (_) {
                if (!_isSending) {
                  unawaited(_sendMessage());
                }
              },
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 6),
              Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _isSending ? null : _sendMessage,
              child: Text(_isSending ? '전송 중' : '전송'),
            ),
          ],
        ),
      ),
    );
  }

  void _startPolling() {
    _pollTimer?.cancel();
    unawaited(_pollMessages());
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      unawaited(_pollMessages());
    });
  }

  Future<void> _pollMessages() async {
    if (!mounted) {
      return;
    }

    try {
      final messages = await widget.api.listChatMessages(
        widget.session.sessionId,
      );
      if (!mounted) {
        return;
      }

      final newMessages = messages
          .where((message) => message.sequence > _lastDeliveredSequence)
          .toList(growable: false);
      if (messages.isNotEmpty) {
        _lastDeliveredSequence = messages.last.sequence;
      }
      if (newMessages.isNotEmpty) {
        widget.onNewMessages?.call(newMessages);
      }

      setState(() {
        _messages = _takeRecentMessages(messages);
      });
    } on LiveSessionApiException catch (error) {
      if (mounted) {
        setState(() => _errorMessage = error.message);
      }
    }
  }

  Future<void> _sendMessage() async {
    final body = _messageController.text.trim();
    if (body.isEmpty) {
      setState(() => _errorMessage = '메시지를 입력해 주세요.');
      return;
    }

    setState(() {
      _isSending = true;
      _errorMessage = null;
    });

    try {
      final message = await widget.api.createChatMessage(
        sessionId: widget.session.sessionId,
        senderRole: widget.senderRole,
        body: body,
      );
      if (!mounted) {
        return;
      }

      _messageController.clear();
      _lastDeliveredSequence = message.sequence;
      widget.onMessageSent?.call(message);
      setState(() {
        _messages = _takeRecentMessages([..._messages, message]);
      });
    } on LiveSessionApiException catch (error) {
      if (mounted) {
        setState(() => _errorMessage = error.message);
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  List<LiveChatMessage> _takeRecentMessages(List<LiveChatMessage> messages) {
    if (messages.length <= 20) {
      return List<LiveChatMessage>.unmodifiable(messages);
    }

    return List<LiveChatMessage>.unmodifiable(
      messages.sublist(messages.length - 20),
    );
  }

  String _senderLabel(ChatSenderRole senderRole) {
    return switch (senderRole) {
      ChatSenderRole.host => '호스트',
      ChatSenderRole.supporter => '가이드',
      ChatSenderRole.system => '시스템',
    };
  }
}

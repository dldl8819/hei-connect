enum InviteTargetKind {
  liveSession,
  channel,
}

class InviteTarget {
  const InviteTarget({
    required this.kind,
    required this.code,
  });

  final InviteTargetKind kind;
  final String code;

  static InviteTarget? tryParseLink(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    return _tryParseStructuredLink(trimmed);
  }

  static InviteTarget parse(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Invite code or link is required.');
    }

    final target = _tryParseStructuredLink(trimmed);
    if (target != null) {
      return target;
    }

    return InviteTarget(
      kind: InviteTargetKind.liveSession,
      code: _normalizeCode(trimmed),
    );
  }

  static InviteTarget? _tryParseStructuredLink(String input) {
    final uri = Uri.tryParse(input);
    final pathParts = <String>[
      if (uri != null && uri.host.isNotEmpty) uri.host,
      if (uri != null) ...uri.pathSegments,
    ];
    final markerParts = [
      for (final part in pathParts) part.toLowerCase(),
    ];

    final liveIndex = _indexOfSequence(markerParts, ['join', 'live']);
    if (liveIndex != -1 && liveIndex + 2 < pathParts.length) {
      return InviteTarget(
        kind: InviteTargetKind.liveSession,
        code: _normalizeCode(pathParts[liveIndex + 2]),
      );
    }

    final channelIndex = markerParts.indexOf('channels');
    if (channelIndex != -1 && channelIndex + 1 < pathParts.length) {
      return InviteTarget(
        kind: InviteTargetKind.channel,
        code: _normalizeCode(pathParts[channelIndex + 1]),
      );
    }

    return null;
  }

  static int _indexOfSequence(List<String> parts, List<String> sequence) {
    for (var index = 0; index <= parts.length - sequence.length; index += 1) {
      var matched = true;
      for (var offset = 0; offset < sequence.length; offset += 1) {
        if (parts[index + offset] != sequence[offset]) {
          matched = false;
          break;
        }
      }

      if (matched) {
        return index;
      }
    }

    return -1;
  }

  static String _normalizeCode(String value) {
    final code = Uri.decodeComponent(value).trim().toUpperCase();
    if (code.isEmpty) {
      throw const FormatException('Invite code is empty.');
    }

    return code;
  }
}

enum VoiceCue {
  stopNow('정지'),
  slowDown('천천히'),
  keepStraight('직진'),
  leftSmall('왼쪽 조금'),
  rightSmall('오른쪽 조금'),
  obstacleAhead('앞에 장애물'),
  personAhead('앞에 사람'),
  curbAhead('앞에 턱'),
  narrowPath('길 좁아짐'),
  holdPace('좋아요 유지');

  const VoiceCue(this.label);

  final String label;
}

extension VoiceCueApiValue on VoiceCue {
  String get apiValue {
    return switch (this) {
      VoiceCue.stopNow => 'stop_now',
      VoiceCue.slowDown => 'slow_down',
      VoiceCue.keepStraight => 'keep_straight',
      VoiceCue.leftSmall => 'left_small',
      VoiceCue.rightSmall => 'right_small',
      VoiceCue.obstacleAhead => 'obstacle_ahead',
      VoiceCue.personAhead => 'person_ahead',
      VoiceCue.curbAhead => 'curb_ahead',
      VoiceCue.narrowPath => 'narrow_path',
      VoiceCue.holdPace => 'hold_pace',
    };
  }

  static VoiceCue fromApiValue(String value) {
    return switch (value) {
      'stop_now' => VoiceCue.stopNow,
      'slow_down' => VoiceCue.slowDown,
      'keep_straight' => VoiceCue.keepStraight,
      'left_small' => VoiceCue.leftSmall,
      'right_small' => VoiceCue.rightSmall,
      'obstacle_ahead' => VoiceCue.obstacleAhead,
      'person_ahead' => VoiceCue.personAhead,
      'curb_ahead' => VoiceCue.curbAhead,
      'narrow_path' => VoiceCue.narrowPath,
      'hold_pace' => VoiceCue.holdPace,
      _ => throw FormatException('Unknown voice cue: $value'),
    };
  }
}

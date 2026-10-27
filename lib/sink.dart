class VBotSink {
  final String name;
  final String state;
  final bool isIncoming;
  final bool isMute;
  final bool onHold;

  final String? endedReason;
  final String? endedBy;
  final String? message;

  VBotSink({
    required this.name,
    required this.state,
    required this.isIncoming,
    required this.isMute,
    required this.onHold,
    this.endedReason,
    this.endedBy,
    this.message,
  });

  factory VBotSink.fromMap(Map<String, dynamic> map) {
    return VBotSink(
      name: map['name'] as String? ?? '',
      state: map['state'] as String? ?? '',
      isIncoming: map['isIncoming'] as bool? ?? false,
      isMute: map['isMute'] as bool? ?? false,
      onHold: map['onHold'] as bool? ?? false,
      endedReason: map['endedReason'] as String?,
      endedBy: map['endedBy'] as String?,
      message: map['message'] as String?,
    );
  }

  @override
  String toString() {
    return 'VBotSink(name: $name, state: $state, isIncoming: $isIncoming, isMute: $isMute, onHold: $onHold, endedReason: $endedReason, endedBy: $endedBy, message: $message)';
  }
}


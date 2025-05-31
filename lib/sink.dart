import 'package:flutter/foundation.dart';

@immutable 
class VBotSink {
  final String name;
  final String state;
  final bool isIncoming;
  final bool isMute;
  final bool onHold;

  const VBotSink({ 
    required this.name,
    required this.state,
    required this.isIncoming,
    required this.isMute,
    required this.onHold,
  });

  factory VBotSink.fromMap(Map<String, dynamic> map) {
    return VBotSink(
      name: map['name'] as String? ?? '',
      state: map['state'] as String? ?? '',
      isIncoming: map['isIncoming'] as bool? ?? false,
      isMute: map['isMute'] as bool? ?? false,
      onHold: map['onHold'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'state': state,
      'isIncoming': isIncoming,
      'isMute': isMute,
      'onHold': onHold,
    };
  }

 VBotSink copyWith({
    String? name,
    String? state,
    bool? isIncoming,
    bool? isMute,
    bool? onHold,
  }) {
    return VBotSink(
      name: name ?? this.name,
      state: state ?? this.state,
      isIncoming: isIncoming ?? this.isIncoming,
      isMute: isMute ?? this.isMute,
      onHold: onHold ?? this.onHold,
    );
  }

  @override
  String toString() {
    return 'VBotSink(name: $name, state: $state, isIncoming: $isIncoming, isMute: $isMute, onHold: $onHold)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is VBotSink &&
      other.name == name &&
      other.state == state &&
      other.isIncoming == isIncoming &&
      other.isMute == isMute &&
      other.onHold == onHold;
  }

  @override
  int get hashCode {
    return name.hashCode ^
      state.hashCode ^
      isIncoming.hashCode ^
      isMute.hashCode ^
      onHold.hashCode;
  }
}
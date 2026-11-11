/// 효과음과 진동. 소리 파일은 tool/gen_sfx.py 로 직접 합성한 것(assets/audio).
library;

import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/services.dart';

enum Haptic { light, medium, heavy, tick }

class Sfx {
  Sfx({int volumeLevel = defaultVolumeLevel, this.haptics = true})
      : volumeLevel = volumeLevel.clamp(0, maxVolumeLevel);

  static const maxVolumeLevel = 5;
  static const defaultVolumeLevel = 3;

  /// 소리 크기 단계(0 = 끔, 5 = 최대).
  int volumeLevel;

  /// 진동 사용 여부.
  bool haptics;

  /// 음소거를 풀 때 돌아갈 단계.
  int _lastLevel = defaultVolumeLevel;

  bool get muted => volumeLevel == 0;

  void setVolumeLevel(int level) {
    volumeLevel = level.clamp(0, maxVolumeLevel);
    if (volumeLevel > 0) _lastLevel = volumeLevel;
  }

  /// 스피커 아이콘을 눌렀을 때: 끄거나, 끄기 전 크기로 되돌린다.
  void toggleMute() => setVolumeLevel(muted ? _lastLevel : 0);

  static const names = [
    'click', 'pour', 'early', 'good', 'topping', 'serve', 'bonus', 'burnt', 'full', 'lost',
    'rush', 'vip', 'buy', 'start', 'win', 'fail',
    'perfect0', 'perfect1', 'perfect2', 'perfect3', 'perfect4', 'perfect5',
  ];

  /// 처음 재생할 때 끊기지 않도록 미리 읽어 둔다. 실패해도 게임은 계속된다.
  Future<void> preload() async {
    try {
      await FlameAudio.audioCache.loadAll([for (final n in names) '$n.wav']);
    } catch (_) {}
  }

  /// [volume] 은 이 소리만의 상대 크기(0~1). 실제 크기는 여기에 전체 음량 단계가 곱해진다.
  void play(String name, {double volume = 1.0}) {
    if (muted) return;
    volume = volume * volumeLevel / maxVolumeLevel;
    // 소리를 낼 수 없는 환경(테스트, 자동재생 차단 등)에서도 조용히 넘어간다.
    try {
      FlameAudio.play('$name.wav', volume: volume).catchError((Object _) => AudioPlayer());
    } catch (_) {}
  }

  /// 콤보가 이어질수록 높은 음의 퍼펙트 소리.
  void perfect(int combo) => play('perfect${(combo - 1).clamp(0, 5)}');

  void haptic(Haptic kind) {
    if (!haptics) return;
    switch (kind) {
      case Haptic.light:
        HapticFeedback.lightImpact();
      case Haptic.medium:
        HapticFeedback.mediumImpact();
      case Haptic.heavy:
        HapticFeedback.heavyImpact();
      case Haptic.tick:
        HapticFeedback.selectionClick();
    }
  }
}

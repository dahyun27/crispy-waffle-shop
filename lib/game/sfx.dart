/// 효과음과 진동. 소리 파일은 tool/gen_sfx.py 로 직접 합성한 것(assets/audio).
library;

import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/services.dart';

enum Haptic { light, medium, heavy, tick }

class Sfx {
  Sfx({this.enabled = true});

  /// 소리와 진동을 함께 켜고 끈다.
  bool enabled;

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

  void play(String name, {double volume = 0.6}) {
    if (!enabled) return;
    // 소리를 낼 수 없는 환경(테스트, 자동재생 차단 등)에서도 조용히 넘어간다.
    try {
      FlameAudio.play('$name.wav', volume: volume).catchError((Object _) => AudioPlayer());
    } catch (_) {}
  }

  /// 콤보가 이어질수록 높은 음의 퍼펙트 소리.
  void perfect(int combo) => play('perfect${(combo - 1).clamp(0, 5)}');

  void haptic(Haptic kind) {
    if (!enabled) return;
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

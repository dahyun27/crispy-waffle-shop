// 와플 도트 그림을 PPM 이미지로 뽑아 확인하는 도구.
// 실행: flutter test tool/dump_waffles_test.dart --dart-define=OUT=/경로/waffles.ppm
import 'dart:io';
import 'dart:typed_data';

import 'package:crispy_waffle_shop/game/config.dart';
import 'package:crispy_waffle_shop/game/sprites.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dump', () {
    const out = String.fromEnvironment('OUT');
    if (out.isEmpty) return;
    const scale = 8, pad = 16, n = waffleSize;
    final sprites = [
      for (final t in Topping.values) waffleSprite(waffleGoldenStep, t),
      for (final s in [0, 3, 9, waffleBurntStep]) waffleSprite(s),
    ];
    final w = sprites.length * (n * scale + pad) + pad, h = n * scale + pad * 2;
    final data = Uint8List(w * h * 3);
    for (var i = 0; i < w * h; i++) {
      data.setRange(i * 3, i * 3 + 3, [0x2E, 0x30, 0x38]);
    }
    for (final (i, sp) in sprites.indexed) {
      for (var y = 0; y < n * scale; y++) {
        for (var x = 0; x < n * scale; x++) {
          final c = sp.pixels[(y ~/ scale) * n + x ~/ scale];
          if (c == null) continue;
          final o = ((pad + y) * w + pad + i * (n * scale + pad) + x) * 3;
          final v = c.toARGB32();
          data[o] = (v >> 16) & 255;
          data[o + 1] = (v >> 8) & 255;
          data[o + 2] = v & 255;
        }
      }
    }
    File(out).writeAsBytesSync([...'P6\n$w $h\n255\n'.codeUnits, ...data]);
  });
}

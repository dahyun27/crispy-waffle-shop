// 손님·직원 도트 그림을 PPM 이미지로 뽑아 확인하는 도구.
// 실행: flutter test tool/dump_people_test.dart --dart-define=OUT=/경로/people.ppm
import 'dart:io';
import 'dart:typed_data';

import 'package:crispy_waffle_shop/game/config.dart';
import 'package:crispy_waffle_shop/game/people.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dump', () {
    const out = String.fromEnvironment('OUT');
    if (out.isEmpty) return;
    const scale = 5, pad = 10, cols = 9;
    final sprites = [
      for (var i = 0; i < 15; i++) customerSprite(i * 7 + i, Mood.values[i % 3]),
      for (final id in StaffId.values) staffSprites[id]!,
    ];
    final rows = (sprites.length / cols).ceil();
    final cw = personW * scale + pad, ch = personH * scale + pad;
    final w = cols * cw + pad, h = rows * ch + pad;
    final data = Uint8List(w * h * 3);
    for (var i = 0; i < w * h; i++) {
      data.setRange(i * 3, i * 3 + 3, [0xC8, 0xE0, 0xF0]);
    }
    for (final (i, sp) in sprites.indexed) {
      final ox = pad + (i % cols) * cw, oy = pad + (i ~/ cols) * ch;
      for (var y = 0; y < personH * scale; y++) {
        for (var x = 0; x < personW * scale; x++) {
          final c = sp.pixels[(y ~/ scale) * personW + x ~/ scale];
          if (c == null) continue;
          final o = ((oy + y) * w + ox + x) * 3;
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

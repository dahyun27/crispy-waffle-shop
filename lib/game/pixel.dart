/// 도트 그림 엔진: 글자로 그린 그림(문자열 배열)을 작은 이미지로 구워 두고,
/// 확대해도 뭉개지지 않게(FilterQuality.none) 그린다.
library;

import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

final _pixelPaint = Paint()..isAntiAlias = false;
final _imagePaint = Paint()
  ..filterQuality = FilterQuality.none
  ..isAntiAlias = false;

/// 계단 현상 그대로의 사각형(도트 느낌의 기본 단위).
void px(Canvas c, num x, num y, num w, num h, Color color) {
  c.drawRect(Rect.fromLTWH(x.toDouble(), y.toDouble(), w.toDouble(), h.toDouble()),
      _pixelPaint..color = color);
}

/// 모서리가 한 칸 깎인 도트풍 상자.
void pixelBox(Canvas c, Rect r, Color fill,
    {Color border = const Color(0xFF3A2416), Color? hi, Color? lo}) {
  px(c, r.left + 2, r.top, r.width - 4, r.height, border);
  px(c, r.left, r.top + 2, r.width, r.height - 4, border);
  final i = r.deflate(2);
  px(c, i.left, i.top, i.width, i.height, fill);
  if (hi != null) px(c, i.left, i.top, i.width, 2, hi);
  if (lo != null) px(c, i.left, i.bottom - 2, i.width, 2, lo);
}

class PixelSprite {
  /// [rows] 의 글자 하나가 점 하나. [palette] 에 없는 글자는 투명.
  PixelSprite(List<String> rows, Map<String, Color> palette)
      : w = rows.first.length,
        h = rows.length,
        pixels = [
          for (final row in rows)
            for (var x = 0; x < row.length; x++) palette[row[x]]
        ];

  PixelSprite.fromPixels(this.w, this.h, this.pixels);

  final int w;
  final int h;
  final List<Color?> pixels;
  ui.Image? _image;

  ui.Image get image => _image ??= _bake();

  ui.Image _bake() {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final col = pixels[y * w + x];
        if (col != null) px(c, x, y, 1, 1, col);
      }
    }
    return rec.endRecording().toImageSync(w, h);
  }

  /// 왼쪽 위 (x, y) 에 [scale] 배로 그린다. [rows] 를 주면 위에서부터 그 줄 수만 그린다.
  void draw(Canvas c, double x, double y, {double scale = 2, int? rows, double opacity = 1}) {
    final hh = rows ?? h;
    _imagePaint.color = Color.fromRGBO(255, 255, 255, opacity);
    c.drawImageRect(image, Rect.fromLTWH(0, 0, w.toDouble(), hh.toDouble()),
        Rect.fromLTWH(x, y, w * scale, hh * scale), _imagePaint);
  }
}

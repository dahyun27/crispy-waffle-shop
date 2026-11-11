/// 도트 그림 엔진: 글자로 그린 그림(문자열 배열)을 작은 이미지로 구워 두고,
/// 확대해도 뭉개지지 않게(FilterQuality.none) 그린다.
library;

import 'dart:math';
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

/// 점 단위로 그림을 그려 [PixelSprite] 로 만드는 작은 도화지.
class PixelCanvas {
  PixelCanvas(this.w, this.h) : pixels = List<Color?>.filled(w * h, null);

  final int w;
  final int h;
  final List<Color?> pixels;

  Color? at(int x, int y) => (x < 0 || y < 0 || x >= w || y >= h) ? null : pixels[y * w + x];

  void dot(int x, int y, Color color) {
    if (x >= 0 && y >= 0 && x < w && y < h) pixels[y * w + x] = color;
  }

  void rect(int x, int y, int rw, int rh, Color color) {
    for (var yy = y; yy < y + rh; yy++) {
      for (var xx = x; xx < x + rw; xx++) {
        dot(xx, yy, color);
      }
    }
  }

  /// 타원. [shade] 는 (가로 -1~1, 세로 -1~1, 중심 거리 0~1)로 색을 정하고, null 이면 칠하지 않는다.
  void ellipse(double cx, double cy, double rx, double ry, Color? Function(double, double, double) shade) {
    for (var y = (cy - ry).floor(); y <= (cy + ry).ceil(); y++) {
      for (var x = (cx - rx).floor(); x <= (cx + rx).ceil(); x++) {
        final dx = (x - cx) / rx, dy = (y - cy) / ry;
        final d = sqrt(dx * dx + dy * dy);
        if (d > 1) continue;
        final col = shade(dx, dy, d);
        if (col != null) dot(x, y, col);
      }
    }
  }

  /// 칠해진 부분의 바깥 한 줄을 [color] 로 둘러 외곽선을 만든다.
  void outline(Color color) {
    final edge = <int>[];
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        if (pixels[y * w + x] != null) continue;
        if (at(x - 1, y) != null || at(x + 1, y) != null || at(x, y - 1) != null || at(x, y + 1) != null) {
          edge.add(y * w + x);
        }
      }
    }
    for (final i in edge) {
      pixels[i] = color;
    }
  }

  PixelSprite toSprite() => PixelSprite.fromPixels(w, h, pixels);
}

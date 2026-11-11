/// 화면 배치 좌표. 가상 해상도 360x640 기준이며, 그리기와 터치 판정이 같은 값을 쓴다.
library;

import 'dart:ui';

class Layout {
  static const width = 360.0;
  static const height = 640.0;

  static const hud = Rect.fromLTWH(0, 0, width, 56);
  static const scene = Rect.fromLTWH(0, 56, width, 166);
  static const counter = Rect.fromLTWH(0, 222, width, 28);
  static const kitchen = Rect.fromLTWH(54, 340, 292, 292);

  /// 손님 자리. [count] 는 가게 단계에 따른 자리 수(2~4).
  static Rect customer(int i, int count) {
    final w = count <= 2 ? 120.0 : (count == 3 ? 108.0 : 86.0);
    final left = (width - w * count) / 2;
    return Rect.fromLTWH(left + i * w, 96, w, 130);
  }

  /// 진열대 칸(토핑 순서대로 0~3)
  static Rect tray(int i) => Rect.fromLTWH(12 + i * 85.0, 256, 80, 72);

  /// 와플판 칸(0~8, 3x3)
  static Rect griddle(int i) =>
      Rect.fromLTWH(60 + (i % 3) * 96.0, 346 + (i ~/ 3) * 96.0, 88, 88);

  /// 직원 표시 칸(0~2, 와플판 왼쪽)
  static Rect staff(int i) => Rect.fromLTWH(6, 346 + i * 96.0, 44, 88);
}

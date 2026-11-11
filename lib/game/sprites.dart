/// 게임에 쓰이는 도트 그림 데이터. 모두 이 프로젝트를 위해 새로 그린 것.
/// 글자 하나가 점 하나이며, 색은 팔레트로 바꿔 끼울 수 있다.
library;

import 'dart:math';
import 'dart:ui';

import 'config.dart';
import 'pixel.dart';

export 'people.dart';

const ink = Color(0xFF3A2416);

// ── 와플 (13x13, 굽기 단계와 토핑에 따라 생성) ─────────────

const toppingColors = {
  Topping.plain: Color(0xFFE9A93B),
  Topping.choco: Color(0xFF5A3219),
  Topping.berry: Color(0xFFE5486B),
  Topping.cream: Color(0xFFFFFBF2),
};

const waffleGoldenStep = 7;
const waffleBurntStep = 12;
final _waffleCache = <int, PixelSprite>{};

/// [step] 0=막 부은 반죽 … 7=노릇노릇 … 12=탐.
PixelSprite waffleSprite(int step, [Topping topping = Topping.plain]) {
  step = step.clamp(0, waffleBurntStep);
  return _waffleCache[step * 4 + topping.index] ??= _makeWaffle(step, topping);
}

/// 와플 한 변의 점 개수.
const waffleSize = 24;

PixelSprite _makeWaffle(int step, Topping topping) {
  const raw = Color(0xFFFFF0BE), golden = Color(0xFFF2B441), burnt = Color(0xFF35221A);
  final base = step <= waffleGoldenStep
      ? Color.lerp(raw, golden, step / waffleGoldenStep)!
      : Color.lerp(golden, burnt, (step - waffleGoldenStep) / (waffleBurntStep - waffleGoldenStep))!;
  Color dk(double t) => Color.lerp(base, const Color(0xFF3A1E08), t)!;
  Color lt(double t) => Color.lerp(base, const Color(0xFFFFFFFF), t)!;
  const n = waffleSize;
  final p = List<Color?>.filled(n * n, null);
  void dot(int x, int y, Color col) {
    if (x >= 0 && y >= 0 && x < n && y < n) p[y * n + x] = col;
  }

  // 몸통: 둥근 모서리, 테두리, 빛 받는 윗면/왼면, 5칸 홈 + 2칸 살.
  for (var y = 0; y < n; y++) {
    for (var x = 0; x < n; x++) {
      final ex = min(x, n - 1 - x), ey = min(y, n - 1 - y);
      if (ex + ey < 2) continue;
      if (ex == 0 || ey == 0 || ex + ey == 2) {
        dot(x, y, dk(0.7));
      } else if (ex == 1 || ey == 1) {
        final lit = ey == 1 ? y < n / 2 : x < n / 2;
        dot(x, y, lit ? lt(0.45) : dk(0.25));
      } else {
        final cx = (x - 2) % 7, cy = (y - 2) % 7;
        if (cx >= 5 || cy >= 5) {
          final edge = (cy == 5 && cx < 5) || (cx == 5 && cy < 5);
          dot(x, y, edge ? lt(0.35) : lt(0.12));
        } else if (cy == 0) {
          dot(x, y, dk(0.55));
        } else if (cx == 0) {
          dot(x, y, dk(0.45));
        } else if (cx == 3 && cy == 3) {
          dot(x, y, lt(0.1));
        } else {
          dot(x, y, (cy == 4 || cx == 4) ? dk(0.16) : dk(0.3));
        }
      }
    }
  }

  /// 타원을 칠한다. [shade] 는 (가로 위치 -1~1, 세로 위치 -1~1, 중심에서의 거리 0~1)로 색을 정한다.
  void ellipse(double cx, double cy, double rx, double ry, Color Function(double, double, double) shade) {
    for (var y = (cy - ry).floor(); y <= (cy + ry).ceil(); y++) {
      for (var x = (cx - rx).floor(); x <= (cx + rx).ceil(); x++) {
        final dx = (x - cx) / rx, dy = (y - cy) / ry;
        final d = sqrt(dx * dx + dy * dy);
        if (d <= 1) dot(x, y, shade(dx, dy, d));
      }
    }
  }

  void stamp(int left, int top, List<String> rows, Map<String, Color> colors) {
    for (var y = 0; y < rows.length; y++) {
      for (var x = 0; x < rows[y].length; x++) {
        final col = colors[rows[y][x]];
        if (col != null) dot(left + x, top + y, col);
      }
    }
  }

  /// 반짝이는 십자 빛.
  void sparkle(int x, int y) {
    const w = Color(0xFFFFFFFF);
    dot(x, y, w);
    for (final (dx, dy) in [(-1, 0), (1, 0), (0, -1), (0, 1)]) {
      final under = p[(y + dy) * n + x + dx];
      if (under != null) dot(x + dx, y + dy, Color.lerp(under, w, 0.65)!);
    }
  }

  const sprinkles = [
    Color(0xFFFF8FB8), Color(0xFFFFE066), Color(0xFF8FE3C0), Color(0xFFFFFFFF), Color(0xFF8FC4FF),
  ];

  switch (topping) {
    case Topping.plain:
      break;

    case Topping.choco:
      // 위에서 부어 흘러내리는 초코 글레이즈 + 화이트 초코 지그재그 + 스프링클 + 초코 조각.
      const glint = Color(0xFFE0A874), top = Color(0xFF8A4E24), body = Color(0xFF5E3014);
      const deep = Color(0xFF3A1B08), white = Color(0xFFFFF1D0);
      final glaze = <int>{};
      for (var x = 2; x <= 21; x++) {
        var edge = (10.5 + 2.0 * sin(x * 0.8 + 0.4)).round();
        if (x == 5 || x == 6) edge += 5;
        if (x == 12 || x == 13) edge += 7;
        if (x == 18 || x == 19) edge += 4;
        edge = min(edge, 21);
        for (var y = 2; y <= edge; y++) {
          dot(x, y, y == edge ? deep : (y == edge - 1 ? body : (y <= 3 ? top : body)));
          if (y < edge - 1) glaze.add(y * n + x);
        }
      }
      for (final (x, y) in [(3, 4), (4, 3), (5, 3), (6, 3), (14, 3), (15, 3), (16, 4), (5, 13), (12, 15), (18, 12)]) {
        dot(x, y, glint);
      }
      for (var x = 3; x <= 20; x++) {
        final k = x % 6;
        final y = 5 + (k < 3 ? k : 6 - k);
        if (glaze.contains(y * n + x)) dot(x, y, white);
      }
      for (final (i, (x, y)) in [(3, 9), (8, 10), (11, 9), (16, 10), (20, 8), (9, 4), (19, 4), (13, 12), (6, 11)].indexed) {
        if (!glaze.contains(y * n + x)) continue;
        dot(x, y, sprinkles[i % sprinkles.length]);
        if (i.isEven && glaze.contains(y * n + x + 1)) dot(x + 1, y, sprinkles[i % sprinkles.length]);
      }
      const chunk = ['hhh.', 'hccd', 'hccd', '.ddd'];
      const chunkColors = {'h': Color(0xFFA86838), 'c': Color(0xFF6B3A1A), 'd': Color(0xFF2E1406)};
      stamp(8, 17, chunk, chunkColors);
      stamp(15, 18, chunk, chunkColors);
      sparkle(17, 6);

    case Topping.berry:
      // 딸기 시럽 웅덩이 + 딸기 세 조각 + 블루베리 + 민트 + 슈가파우더.
      const rim = Color(0xFFA81E40), sauce = Color(0xFFE8456A), sauceLight = Color(0xFFF7799A);
      for (final (x, y) in [(3, 3), (20, 3), (3, 20), (20, 20), (18, 2), (4, 5), (2, 17), (21, 16), (19, 21), (5, 21)]) {
        dot(x, y, const Color(0xFFFFFFFF));
      }
      for (var y = 2; y <= 21; y++) {
        for (var x = 2; x <= 21; x++) {
          final dx = x - 11.5, dy = y - 11.8;
          final d = sqrt(dx * dx + dy * dy);
          final r = 7.6 + 1.3 * sin(atan2(dy, dx) * 5 + 0.6);
          if (d > r) continue;
          dot(x, y, d > r - 1 ? rim : (dx + dy < -4 ? sauceLight : sauce));
        }
      }
      const slice = ['..gg..', '.rrrr.', 'rrpprr', 'rpwwpr', 'drpprd', '.drrd.', '..dd..'];
      const sliceColors = {
        'g': Color(0xFF4FA35A),
        'r': Color(0xFFF0424F),
        'p': Color(0xFFFFA8A8),
        'w': Color(0xFFFFE6DC),
        'd': Color(0xFF9C1830),
      };
      stamp(5, 5, slice, sliceColors);
      stamp(13, 6, slice, sliceColors);
      stamp(9, 12, slice, sliceColors);
      const blueberry = ['.bb.', 'bhbb', 'bbbd', '.dd.'];
      const blueColors = {'b': Color(0xFF4456B8), 'h': Color(0xFFA8B8FF), 'd': Color(0xFF252E70)};
      stamp(4, 13, blueberry, blueColors);
      stamp(16, 14, blueberry, blueColors);
      stamp(11, 7, const ['.bb', 'bhb', 'bbd'], blueColors);
      const mint = ['l..l', 'lmml', '.mm.'];
      stamp(10, 3, mint, const {'l': Color(0xFF8FD98A), 'm': Color(0xFF3E8A4A)});
      sparkle(18, 5);

    case Topping.cream:
      // 세 단 생크림 + 캐러멜 시럽 + 스프링클 + 초코 스틱 + 체리.
      const line = Color(0xFF8E97BD), white = Color(0xFFFFFFFF);
      const soft = Color(0xFFE9ECF8), shade = Color(0xFFCBD1E8);
      const caramel = Color(0xFFF0A030), caramelDeep = Color(0xFFB8681A);
      // 와플 위에 먼저 깔리는 캐러멜 시럽
      for (var x = 2; x <= 21; x++) {
        final y = (18.5 + 1.4 * sin(x * 0.9)).round();
        dot(x, y, caramel);
        dot(x, y + 1, caramelDeep);
      }
      final creamArea = <int>{};
      Color cream(double dx, double dy, double d) {
        if (d > 0.8) return line;
        if (dy > 0.35 || dx > 0.55) return shade;
        return dx + dy > 0.1 ? soft : white;
      }
      void tier(double cy, double rx, double ry) {
        ellipse(11.5, cy, rx, ry, cream);
        for (var y = (cy - ry * 0.75).ceil(); y <= (cy + ry * 0.75).floor(); y++) {
          for (var x = (11.5 - rx * 0.75).ceil(); x <= (11.5 + rx * 0.75).floor(); x++) {
            creamArea.add(y * n + x);
          }
        }
      }
      tier(15.2, 8.2, 5.0);
      tier(11.4, 6.2, 4.0);
      tier(8.0, 4.0, 3.0);
      // 크림 위로 흐르는 캐러멜 줄
      for (var y = 6; y <= 18; y++) {
        for (var x = 4; x <= 19; x++) {
          if ((x * 2 + y * 3) % 13 == 0 && creamArea.contains(y * n + x)) {
            dot(x, y, caramel);
            if (creamArea.contains((y + 1) * n + x)) dot(x, y + 1, caramelDeep);
          }
        }
      }
      for (final (i, (x, y)) in [(6, 14), (9, 16), (14, 15), (16, 13), (9, 11), (13, 9), (11, 13)].indexed) {
        dot(x, y, sprinkles[(i * 2) % 3]);
      }
      // 비스듬히 꽂힌 초코 스틱
      for (var k = 0; k <= 8; k++) {
        final x = (15 + k * 0.7).round(), y = (12 - k * 1.2).round();
        final biscuit = k >= 7;
        dot(x, y, biscuit ? const Color(0xFFF0CC88) : const Color(0xFF6B3A1A));
        dot(x + 1, y, biscuit ? const Color(0xFFC89A50) : const Color(0xFF3A1B08));
      }
      ellipse(11.5, 4.6, 2.6, 2.4, (dx, dy, d) {
        if (d > 0.82) return const Color(0xFF8E1426);
        return dx + dy > 0.3 ? const Color(0xFFC92436) : const Color(0xFFF0424F);
      });
      dot(10, 4, const Color(0xFFFFC2C2));
      dot(13, 2, const Color(0xFF3E7A3A));
      dot(14, 1, const Color(0xFF3E7A3A));
      dot(15, 1, const Color(0xFF4FA35A));
      sparkle(5, 8);
  }
  return PixelSprite.fromPixels(n, n, p);
}

// ── 아이콘 ─────────────────────────────────────────────────

const _iconPalette = {
  'o': ink,
  'y': Color(0xFFFFD23F),
  'Y': Color(0xFFFFF3A8),
  'w': Color(0xFFFFFFFF),
  'g': Color(0xFF9A9DA8),
  'b': Color(0xFF6BB8F2),
  'r': Color(0xFFE5484D),
  'd': Color(0xFF5A5148),
};

final coinSprite = PixelSprite([
  '..ooo..',
  '.oyyyo.',
  'oyyYyyo',
  'oyyYyyo',
  'oyyYyyo',
  '.oyyyo.',
  '..ooo..',
], _iconPalette);

const _starRows = [
  '....o....',
  '...oyo...',
  'oooyyyooo',
  'oyyyyyyyo',
  '.oyyyyyo.',
  '..oyyyo..',
  '.oyyoyyo.',
  '.oyo.oyo.',
  '.oo...oo.',
];
final starSprite = PixelSprite(_starRows, _iconPalette);
final starEmptySprite = PixelSprite(_starRows, {..._iconPalette, 'y': const Color(0xFF5A5148)});

final lockSprite = PixelSprite([
  '...ooo...',
  '..o...o..',
  '..o...o..',
  '.ooooooo.',
  '.ogggggo.',
  '.oggoggo.',
  '.oggoggo.',
  '.ogggggo.',
  '.ooooooo.',
], _iconPalette);

final weatherSprites = {
  Weather.sunny: PixelSprite([
    '....y....',
    '.y..y..y.',
    '..yyyyy..',
    '..yYYYy..',
    'yyyYYYyyy',
    '..yYYYy..',
    '..yyyyy..',
    '.y..y..y.',
    '....y....',
  ], _iconPalette),
  Weather.rain: PixelSprite([
    '..www....',
    '.wwwwww..',
    'wwwwwwww.',
    'wwwwwwwww',
    '.wwwwwww.',
    '.........',
    '.b..b..b.',
    'b..b..b..',
    '.........',
  ], _iconPalette),
  Weather.festival: PixelSprite([
    'r...y...b',
    '..b...r..',
    '.y..r...y',
    '...y..b..',
    'b....r...',
    '..r....y.',
    '.....b...',
    'y..r....b',
    '..b..y...',
  ], _iconPalette),
};

/// 테스트에서 줄 길이를 검사할 수 있게 문자열 그림을 모아 둔다.
List<List<String>> get allSpriteRows => [_starRows];

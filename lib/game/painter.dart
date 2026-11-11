/// 화면의 모든 그림을 그리는 파일. 도트 그림(sprites.dart)과 사각형만으로 장면을 구성한다.
library;

import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/text.dart';
import 'package:flutter/painting.dart';

import 'config.dart';
import 'layout.dart';
import 'pixel.dart';
import 'session.dart';
import 'sprites.dart';

const _white = Color(0xFFFFFFFF);
const _cream = Color(0xFFFFF3DC);

final _paints = <String, TextPaint>{};

/// 도트 글꼴(Galmuri11)로 글자를 그린다. [outline] 을 주면 테두리가 생겨 배경 위에서도 잘 보인다.
void drawText(Canvas c, String text, double x, double y,
    {double size = 12, Color color = ink, Anchor anchor = Anchor.center, bool bold = false, Color? outline}) {
  TextPaint paint(Color col) => _paints['$size-${col.toARGB32()}-$bold'] ??= TextPaint(
        style: TextStyle(
          fontFamily: 'Galmuri11',
          fontSize: size,
          color: col,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
        ),
      );
  if (outline != null) {
    final o = paint(outline);
    final d = size >= 20 ? 2.0 : 1.0;
    for (final (dx, dy) in [(-d, 0.0), (d, 0.0), (0.0, -d), (0.0, d), (-d, -d), (d, d), (-d, d), (d, -d)]) {
      o.render(c, text, Vector2(x + dx, y + dy), anchor: anchor);
    }
  }
  paint(color).render(c, text, Vector2(x, y), anchor: anchor);
}

// ── 배경 ───────────────────────────────────────────────────

class _StageLook {
  const _StageLook(this.awningA, this.awningB, this.post, this.buildings, this.pavement,
      this.counterTop, this.counterBody, this.counterLine);
  final Color awningA, awningB, post, pavement, counterTop, counterBody, counterLine;
  final List<Color> buildings;
}

const _looks = [
  _StageLook(Color(0xFFE5484D), Color(0xFFFFF8EC), Color(0xFF8A5A3C),
      [Color(0xFFF2C6A0), Color(0xFFE8A9A0), Color(0xFFC9D8A8), Color(0xFFF0DFA8)],
      Color(0xFFE6D5B5), Color(0xFFD99A62), Color(0xFFA86B3C), Color(0xFF8A5530)),
  _StageLook(Color(0xFF3E9B6B), Color(0xFFFFF8EC), Color(0xFFB5654A),
      [Color(0xFFA8CBE8), Color(0xFFF2D6A0), Color(0xFFE8B0B8), Color(0xFFB8DCC8)],
      Color(0xFFD9D4C8), Color(0xFF4FB8A8), Color(0xFFF5F1E6), Color(0xFFD0C9B8)),
  _StageLook(Color(0xFF34406B), Color(0xFFF2C94C), Color(0xFF2B2F4A),
      [Color(0xFFC8B8E8), Color(0xFFF2B8A0), Color(0xFFA8D8E8), Color(0xFFF2E0A8)],
      Color(0xFFCFC6D8), Color(0xFF4A3550), Color(0xFFECE6F0), Color(0xFFCFC4D8)),
];

void drawScene(Canvas c, Session s, double time) {
  final look = _looks[s.progress.stage];
  final sc = Layout.scene;
  // 하늘
  final (skyA, skyB) = switch (s.weather) {
    Weather.rain => (const Color(0xFF8799AB), const Color(0xFFA9B8C6)),
    Weather.festival => (const Color(0xFFFFB98A), const Color(0xFFFFE2B8)),
    Weather.sunny => (const Color(0xFF86CDF5), const Color(0xFFC2E8FB)),
  };
  px(c, 0, sc.top, sc.width, 56, skyA);
  px(c, 0, sc.top + 56, sc.width, 50, skyB);
  if (s.weather != Weather.rain) {
    for (final (x, y, w) in [(40.0, 86.0, 44.0), (210.0, 80.0, 60.0), (300.0, 96.0, 36.0)]) {
      final dx = (x + time * 4) % (sc.width + 80) - 60;
      px(c, dx, y, w, 8, _white);
      px(c, dx + 8, y - 6, w - 20, 6, _white);
    }
  }
  // 건물
  const heights = [46.0, 66.0, 38.0, 58.0, 72.0, 42.0, 60.0];
  const ground = 160.0;
  for (var i = 0; i < 7; i++) {
    final x = i * 54.0 - 8, h = heights[i];
    final col = look.buildings[i % look.buildings.length];
    px(c, x, ground - h, 52, h, col);
    px(c, x, ground - h, 52, 4, Color.lerp(col, ink, 0.35)!);
    px(c, x + 48, ground - h, 4, h, Color.lerp(col, ink, 0.18)!);
    for (var wy = ground - h + 12; wy < ground - 16; wy += 18) {
      for (final wx in [8.0, 28.0]) {
        px(c, x + wx, wy, 12, 10, Color.lerp(col, ink, 0.45)!);
        px(c, x + wx + 2, wy + 2, 8, 6,
            s.weather == Weather.rain ? const Color(0xFFFFE9A0) : const Color(0xFFDDF2FF));
      }
    }
  }
  // 길
  px(c, 0, ground, sc.width, sc.bottom - ground, look.pavement);
  px(c, 0, ground, sc.width, 4, Color.lerp(look.pavement, ink, 0.3)!);
  final line = Color.lerp(look.pavement, ink, 0.12)!;
  for (var y = ground + 20; y < sc.bottom; y += 20) {
    px(c, 0, y, sc.width, 2, line);
  }
  for (var i = 0; i < 12; i++) {
    px(c, i * 34.0 + 6, ground + 4, 2, 16, line);
    px(c, i * 34.0 + 22, ground + 22, 2, 18, line);
    px(c, i * 34.0 + 6, ground + 42, 2, 20, line);
  }
  // 가로수와 가로등
  void tree(double x) {
    px(c, x + 12, ground - 22, 8, 28, const Color(0xFF7A5234));
    px(c, x, ground - 50, 32, 22, const Color(0xFF4FA35A));
    px(c, x + 6, ground - 60, 20, 10, const Color(0xFF4FA35A));
    px(c, x + 4, ground - 46, 10, 6, const Color(0xFF7CC47A));
    px(c, x + 2, ground - 32, 28, 4, const Color(0xFF3A8046));
  }

  tree(22);
  if (s.progress.stage > 0) tree(304);
  px(c, 286, ground - 64, 4, 70, const Color(0xFF4A5670));
  px(c, 278, ground - 70, 20, 8, const Color(0xFF4A5670));
  px(c, 282, ground - 62, 12, 6, const Color(0xFFFFE9A0));
  // 비
  if (s.weather == Weather.rain) {
    for (var i = 0; i < 46; i++) {
      final x = (i * 53.0 + time * 60) % sc.width;
      final y = sc.top + (i * 37.0 + time * 260) % sc.height;
      px(c, x, y, 2, 8, const Color(0xAADDEEFF));
    }
  }
}

/// 손님 앞을 가리는 계산대와 천막(손님을 그린 뒤에 그린다).
void drawShopFront(Canvas c, Session s) {
  final look = _looks[s.progress.stage];
  final sc = Layout.scene;
  // 기둥
  for (final x in [0.0, sc.width - 10]) {
    px(c, x, sc.top, 10, sc.height, look.post);
    px(c, x + 6, sc.top, 4, sc.height, Color.lerp(look.post, ink, 0.3)!);
  }
  // 천막
  for (var i = 0; i < 18; i++) {
    final col = i.isEven ? look.awningA : look.awningB;
    px(c, i * 20.0, sc.top, 20, 16, col);
    px(c, i * 20.0 + 2, sc.top + 16, 16, 6, col);
    px(c, i * 20.0 + 4, sc.top + 22, 12, 2, col);
  }
  px(c, 0, sc.top, sc.width, 2, Color.lerp(look.awningA, ink, 0.5)!);
  // 축제 깃발
  if (s.weather == Weather.festival) {
    const flags = [Color(0xFFE5484D), Color(0xFFFFD23F), Color(0xFF5B8DEF), Color(0xFF58B77A)];
    for (var i = 0; i < 16; i++) {
      final x = 14 + i * 21.0, y = sc.top + 28 + (i % 2) * 2.0;
      px(c, x, y, 12, 4, flags[i % 4]);
      px(c, x + 2, y + 4, 8, 4, flags[i % 4]);
      px(c, x + 4, y + 8, 4, 4, flags[i % 4]);
    }
  }
  // 계산대
  final ct = Layout.counter;
  px(c, 0, ct.top, ct.width, ct.height, look.counterBody);
  px(c, 0, ct.top, ct.width, 8, look.counterTop);
  px(c, 0, ct.top, ct.width, 2, Color.lerp(look.counterTop, _white, 0.35)!);
  px(c, 0, ct.top + 8, ct.width, 2, ink);
  for (var x = 30.0; x < ct.width; x += 60) {
    px(c, x, ct.top + 10, 2, ct.height - 10, look.counterLine);
  }
  px(c, 0, ct.bottom - 2, ct.width, 2, ink);
}

void drawKitchenBackground(Canvas c) {
  px(c, 0, Layout.counter.bottom, Layout.width, Layout.height - Layout.counter.bottom, _cream);
  for (var y = Layout.counter.bottom + 14; y < Layout.height; y += 16) {
    px(c, 0, y, Layout.width, 2, const Color(0xFFF5E4C4));
  }
  pixelBox(c, Layout.kitchen, const Color(0xFF7A7F8C),
      hi: const Color(0xFF9CA1AE), lo: const Color(0xFF5A5F6B));
}

// ── 상단 정보 ──────────────────────────────────────────────

void drawHud(Canvas c, Session s) {
  px(c, 0, 0, Layout.width, Layout.hud.height, ink);
  px(c, 0, Layout.hud.height - 2, Layout.width, 2, const Color(0xFF1E120A));
  drawText(c, '${s.day}일차', 10, 15, size: 16, color: _white, anchor: Anchor.centerLeft, bold: true);
  weatherSprites[s.weather]!.draw(c, 78, 6);
  drawText(c, s.weatherDef.name, 100, 15, color: const Color(0xFFCDBBA8), anchor: Anchor.centerLeft);
  drawText(c, '목표 ${s.goal}원', Layout.width / 2 + 30, 15, color: const Color(0xFFFFD66B));
  final low = s.timeLeft <= 10;
  drawText(c, '${s.timeLeft.ceil()}초', Layout.width - 10, 15,
      size: 16, color: low ? const Color(0xFFFF7A6B) : _white, anchor: Anchor.centerRight, bold: true);
  // 매출과 별 진행 막대
  coinSprite.draw(c, 10, 31);
  drawText(c, '${s.earned}', 30, 39, size: 16, color: const Color(0xFFFFE14D), anchor: Anchor.centerLeft, bold: true);
  const bar = Rect.fromLTWH(104, 33, 236, 12);
  pixelBox(c, bar, const Color(0xFF1E120A), border: const Color(0xFF6B4A30));
  final full = s.goal * Balance.star3;
  final ratio = (s.earned / full).clamp(0.0, 1.0);
  final inner = bar.deflate(2);
  px(c, inner.left, inner.top, (inner.width * ratio / 2).floor() * 2, inner.height,
      s.rushing ? const Color(0xFFFF7A6B) : const Color(0xFFFFB636));
  final marks = [1 / Balance.star3, Balance.star2 / Balance.star3, 1.0];
  for (var i = 0; i < 3; i++) {
    final x = bar.left + bar.width * marks[i] - 9;
    (s.stars > i ? starSprite : starEmptySprite).draw(c, x.roundToDouble(), 30);
  }
}

// ── 손님 ───────────────────────────────────────────────────

void drawCustomer(Canvas c, Rect r, Customer cu, Session s, double time) {
  final mood = cu.ratio > 0.55 ? Mood.happy : (cu.ratio > 0.28 ? Mood.neutral : Mood.angry);
  final wobble = mood == Mood.angry ? (sin(time * 22) * 2).roundToDouble() : 0.0;
  final enter = ((1 - cu.age / 0.25).clamp(0.0, 1.0) * 24).roundToDouble();
  final x = (r.center.dx - 32 + wobble).roundToDouble();
  final y = 148.0 + enter;
  customerSprite(cu.look, mood).draw(c, x, y);
  if (cu.vip) {
    // 큰손 손님의 왕관
    const gold = Color(0xFFFFD23F);
    px(c, x + 16, y - 6, 32, 8, gold);
    for (final dx in [16.0, 28.0, 40.0]) {
      px(c, x + dx, y - 14, 8, 8, gold);
    }
    px(c, x + 28, y - 4, 8, 4, const Color(0xFFE5484D));
  }
  // 주문 말풍선
  final bubble = Rect.fromLTWH(r.center.dx - 29, 90, cu.qty > 1 ? 84 : 58, 56);
  final shifted = bubble.shift(Offset(cu.qty > 1 ? -13 : 0, 0));
  pixelBox(c, shifted, cu.vip ? const Color(0xFFFFEFA8) : _white,
      border: cu.vip ? const Color(0xFFB8860B) : ink);
  px(c, r.center.dx - 4, shifted.bottom - 2, 8, 4, cu.vip ? const Color(0xFFFFEFA8) : _white);
  px(c, r.center.dx - 2, shifted.bottom + 2, 4, 2, cu.vip ? const Color(0xFFB8860B) : ink);
  waffleSprite(waffleGoldenStep, cu.order).draw(c, shifted.left + 5, shifted.top + 4);
  if (cu.qty > 1) {
    drawText(c, 'x${cu.remaining}', shifted.right - 8, shifted.center.dy,
        size: 16, anchor: Anchor.centerRight, bold: true);
  }
  if (cu.vip) drawText(c, 'x3', shifted.right + 2, shifted.top - 2, color: const Color(0xFFFFE14D), outline: ink, bold: true);
}

/// 계산대 위에 그리는 인내심 막대.
void drawPatience(Canvas c, Rect r, Customer cu) {
  final bar = Rect.fromLTWH(r.center.dx - 30, Layout.counter.top + 13, 60, 10);
  pixelBox(c, bar, const Color(0xFF2B1A0E));
  final inner = bar.deflate(2);
  px(c, inner.left, inner.top, (inner.width * cu.ratio / 2).ceil() * 2, inner.height,
      cu.ratio > 0.55
          ? const Color(0xFF6BD08A)
          : (cu.ratio > 0.28 ? const Color(0xFFFFD23F) : const Color(0xFFFF5A4D)));
}

// ── 진열대 ─────────────────────────────────────────────────

/// [bump] 은 방금 와플이 들어온 칸의 튀어오름 정도(1 → 0).
void drawTray(Canvas c, Session s, [Map<Topping, double> bump = const {}]) {
  for (final t in Topping.values) {
    final r = Layout.tray(t.index);
    final unlocked = s.progress.isUnlocked(t);
    final count = s.tray[t]!;
    pixelBox(c, r, unlocked ? _white : const Color(0xFFD9CFC0),
        hi: unlocked ? null : const Color(0xFFE6DDD0), lo: const Color(0xFFE0D2B8));
    if (!unlocked) {
      lockSprite.draw(c, r.center.dx - 13, r.top + 14, scale: 3, opacity: 0.6);
    } else {
      final hop = (sin((bump[t] ?? 0) * pi) * 4).round() * 2.0;
      waffleSprite(waffleGoldenStep, t).draw(c, r.center.dx - 24, r.top + 4 - hop, opacity: count > 0 ? 1 : 0.3);
      final badge = Rect.fromLTWH(r.right - 26, r.top - 4, 26, 20);
      pixelBox(c, badge, count > 0 ? const Color(0xFFE5484D) : const Color(0xFFB8AC9A));
      drawText(c, '$count', badge.center.dx, badge.center.dy, color: _white, bold: true);
    }
    drawText(c, toppingLabels[t]!, r.center.dx, r.bottom - 10,
        color: unlocked ? ink : const Color(0xFF8A7B68));
  }
  drawText(c, '진열대 ${s.trayCount}/${s.progress.trayCapacity}', Layout.width - 14, 341,
      color: s.trayFull ? const Color(0xFFE5484D) : const Color(0xFF8A6A4A), anchor: Anchor.bottomRight);
}

// ── 와플판 ─────────────────────────────────────────────────

void drawGriddles(Canvas c, Session s, double time) {
  final bake = s.progress.bakeTime;
  const doneSpan = Balance.burnAfter - Balance.perfectWindow;
  for (var i = 0; i < Balance.griddleSlots; i++) {
    final r = Layout.griddle(i);
    final open = s.isGriddleOpen(i);
    if (!open) {
      pixelBox(c, r, const Color(0xFF666A76), border: const Color(0xFF4A4E59));
      lockSprite.draw(c, r.center.dx - 13, r.center.dy - 14, scale: 3, opacity: 0.45);
      continue;
    }
    final g = s.griddles[i];
    final phase = s.phaseOf(i);
    final blink = phase == BakePhase.perfect && (time * 8).floor().isEven;
    pixelBox(c, r, const Color(0xFF2E3038),
        border: phase == BakePhase.perfect ? (blink ? const Color(0xFFFFE14D) : const Color(0xFFFFA91F)) : ink,
        hi: const Color(0xFF454956), lo: const Color(0xFF1F2026));
    // 철판 격자
    for (var k = 1; k < 3; k++) {
      px(c, r.left + 4 + k * 26.0, r.top + 6, 2, 64, const Color(0xFF3A3D48));
      px(c, r.left + 12, r.top + k * 24.0, 64, 2, const Color(0xFF3A3D48));
    }
    if (phase == BakePhase.empty) {
      px(c, r.center.dx - 2, r.center.dy - 12, 4, 24, const Color(0xFF6E727D));
      px(c, r.center.dx - 12, r.center.dy - 2, 24, 4, const Color(0xFF6E727D));
      continue;
    }
    final after = g.t - bake - Balance.perfectWindow;
    final step = switch (phase) {
      BakePhase.baking => (g.t / bake * (waffleGoldenStep - 1)).floor(),
      BakePhase.perfect => waffleGoldenStep,
      BakePhase.done => waffleGoldenStep + 1 + (after / doneSpan * 3).floor(),
      _ => waffleBurntStep,
    };
    waffleSprite(step).draw(c, r.left + 8, r.top + 3, scale: 3);
    final bar = Rect.fromLTWH(r.left + 10, r.bottom - 12, 68, 10);
    switch (phase) {
      case BakePhase.baking:
        pixelBox(c, bar, const Color(0xFF1F2026));
        px(c, bar.left + 2, bar.top + 2, (64 * g.t / bake / 2).floor() * 2, 6, _white);
      case BakePhase.perfect:
        drawText(c, '지금!', r.center.dx, r.center.dy - 8, size: 24, color: _white, outline: ink, bold: true);
        pixelBox(c, bar, const Color(0xFFFFE14D));
      case BakePhase.done:
        pixelBox(c, bar, const Color(0xFF1F2026));
        px(c, bar.left + 2, bar.top + 2, (64 * (1 - after / doneSpan) / 2).ceil() * 2, 6,
            const Color(0xFFFF8A3D));
      case BakePhase.burnt:
        for (var k = 0; k < 3; k++) {
          final rise = (time * 18 + k * 9) % 26;
          px(c, r.left + 22 + k * 18.0, r.top + 30 - rise, 8, 8, Color.fromRGBO(190, 190, 200, 1 - rise / 26));
        }
        drawText(c, '탔어요', r.center.dx, r.center.dy, color: const Color(0xFFFF8A8A), outline: ink);
      case BakePhase.empty:
        break;
    }
  }
}

// ── 직원 ───────────────────────────────────────────────────

void drawStaff(Canvas c, Session s, Map<StaffId, double> flash) {
  for (final id in StaffId.values) {
    if (!s.progress.isWorking(id)) continue;
    final r = Layout.staff(id.index);
    final active = (flash[id] ?? 0) > 0;
    pixelBox(c, r, active ? const Color(0xFFFFF3A8) : _white, lo: const Color(0xFFE0D2B8));
    staffSprites[id]!.draw(c, r.left + 6, r.top + 5 - (active ? 2 : 0), scale: 1);
    drawText(c, staffDefs[id]!.name, r.center.dx, r.top + 54);
    drawText(c, 'Lv${s.progress.staffLevel(id)}', r.center.dx, r.top + 70,
        color: const Color(0xFFB5682E), bold: true);
    final st = s.progress.staff[id]!;
    px(c, r.left + 6, r.bottom - 10, 32, 4, const Color(0xFFD9CFC0));
    px(c, r.left + 6, r.bottom - 10, (32 * st.levelProgress / 2).floor() * 2, 4, const Color(0xFF58B77A));
  }
}

/// 화면 가운데 큰 알림(날씨, 러시 등).
void drawBanner(Canvas c, String title, String sub, double alpha) {
  final a = alpha.clamp(0.0, 1.0);
  px(c, 0, 108, Layout.width, 58, Color.fromRGBO(30, 18, 10, 0.78 * a));
  px(c, 0, 108, Layout.width, 2, Color.fromRGBO(255, 210, 63, a));
  px(c, 0, 164, Layout.width, 2, Color.fromRGBO(255, 210, 63, a));
  drawText(c, title, Layout.width / 2, 127, size: 24, color: Color.fromRGBO(255, 225, 77, a), bold: true);
  drawText(c, sub, Layout.width / 2, 151, color: Color.fromRGBO(255, 255, 255, a));
}

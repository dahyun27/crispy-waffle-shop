/// Flame 게임 본체: 매 프레임 로직을 진행시키고, 그리고, 터치를 로직에 전달한다.
library;

import 'dart:math';

import 'package:flame/components.dart' show Anchor;
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/painting.dart';

import 'config.dart';
import 'layout.dart';
import 'painter.dart';
import 'progress.dart';
import 'session.dart';
import 'sprites.dart';

class _Floater {
  _Floater(this.text, this.pos, this.color);
  final String text;
  final Offset pos;
  final Color color;
  double age = 0;
}

class WaffleGame extends FlameGame with TapCallbacks {
  WaffleGame(this.progress, {required this.onSave});

  final Progress progress;
  final void Function() onSave;
  Session? session;
  final List<_Floater> _floaters = [];
  final Map<StaffId, double> _staffFlash = {};

  double _scale = 1;
  Offset _origin = Offset.zero;
  double _time = 0;
  String _bannerTitle = '', _bannerSub = '';
  double _bannerLeft = 0;

  @override
  Color backgroundColor() => const Color(0xFF1E120A);

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    // 가상 해상도 360x640을 화면에 비율 유지로 맞춘다.
    _scale = min(size.x / Layout.width, size.y / Layout.height);
    _origin = Offset((size.x - Layout.width * _scale) / 2, (size.y - Layout.height * _scale) / 2);
  }

  void startDay() {
    final s = session = Session(progress);
    _floaters.clear();
    overlays.remove('title');
    overlays.remove('dayEnd');
    _banner('${s.day}일차 · ${s.weatherDef.name}', s.weatherDef.desc, 2.4);
  }

  void resetAll() {
    final fresh = Progress();
    progress
      ..money = fresh.money
      ..day = fresh.day
      ..stage = fresh.stage
      ..stars = fresh.stars;
    progress.levels.updateAll((_, _) => 0);
    for (final st in progress.staff.values) {
      st
        ..hired = false
        ..xp = 0;
    }
    session = null;
    onSave();
  }

  void _banner(String title, String sub, double seconds) {
    _bannerTitle = title;
    _bannerSub = sub;
    _bannerLeft = seconds;
  }

  void _endDay(Session s) {
    progress.money += s.earned + s.starBonus;
    progress.stars += s.stars;
    if (s.success) progress.day++;
    onSave();
    overlays.add('dayEnd');
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
    _bannerLeft -= dt;
    for (final f in _floaters) {
      f.age += dt;
    }
    _floaters.removeWhere((f) => f.age > 1);
    _staffFlash.updateAll((_, v) => v - dt);
    final s = session;
    if (s == null || s.finished) return;
    s.update(min(dt, 0.1));
    _consumeEvents(s);
    if (s.finished) _endDay(s);
  }

  void _consumeEvents(Session s) {
    for (final e in s.events) {
      if (e.type == FxType.staff) {
        _staffFlash[e.staff!] = 0.35;
        continue;
      }
      if (e.type == FxType.rush) {
        _banner('단체 손님 등장!', '10초 동안 판매가 1.5배', 1.8);
        continue;
      }
      if (e.type == FxType.vip) {
        _banner('큰손 손님 등장!', '값을 3배로 쳐주지만 오래 기다리지 않아요', 1.8);
        continue;
      }
      final at = e.griddle != null
          ? Layout.griddle(e.griddle!).center
          : Layout.customer(e.slot!, s.customers.length).center + const Offset(0, -10);
      final (text, color) = switch (e.type) {
        FxType.perfect => (e.amount > 1 ? '퍼펙트 x${e.amount}' : '퍼펙트!', const Color(0xFFFFE14D)),
        FxType.good => ('완성', const Color(0xFFFFFFFF)),
        FxType.tooEarly => ('아직!', const Color(0xFFCFD3DC)),
        FxType.burnt => ('-${e.amount}원', const Color(0xFFFF8A8A)),
        FxType.trayFull => ('진열대 가득!', const Color(0xFFFFB36B)),
        FxType.served => ('+${e.amount}', const Color(0xFF8CF0A0)),
        FxType.setBonus => ('세트 +${e.amount}', const Color(0xFFFFE14D)),
        FxType.lost => ('가버렸어요', const Color(0xFFFF8A8A)),
        FxType.noStock => ('와플이 없어요', const Color(0xFFFFB36B)),
        _ => ('', const Color(0xFFFFFFFF)),
      };
      final stacked = e.type == FxType.setBonus ? const Offset(0, -18) : Offset.zero;
      // 같은 자리에서 같은 글자가 연달아 뜨면 겹쳐 보이므로 하나만 남긴다.
      final pos = at + stacked;
      if (_floaters.any((f) => f.text == text && f.pos == pos && f.age < 0.5)) continue;
      _floaters.add(_Floater(text, pos, color));
    }
    s.events.clear();
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    canvas.save();
    canvas.translate(_origin.dx, _origin.dy);
    canvas.scale(_scale);
    canvas.clipRect(const Rect.fromLTWH(0, 0, Layout.width, Layout.height));
    final s = session ?? (_preview ??= Session(progress, autoSpawn: false, weather: Weather.sunny));
    drawScene(canvas, s, _time);
    final count = s.customers.length;
    for (var i = 0; i < count; i++) {
      final cu = s.customers[i];
      if (cu != null) drawCustomer(canvas, Layout.customer(i, count), cu, s, _time);
    }
    drawShopFront(canvas, s);
    for (var i = 0; i < count; i++) {
      final cu = s.customers[i];
      if (cu != null) drawPatience(canvas, Layout.customer(i, count), cu);
    }
    drawKitchenBackground(canvas);
    drawHud(canvas, s);
    drawTray(canvas, s);
    drawGriddles(canvas, s, _time);
    drawStaff(canvas, s, _staffFlash);
    if (s.combo > 1) {
      drawText(canvas, '콤보 x${s.combo}', 16, 96,
          size: 16, color: const Color(0xFFFFE14D), anchor: Anchor.centerLeft, outline: ink, bold: true);
    }
    if (s.rushing) {
      drawText(canvas, '단체 손님! 1.5배', Layout.width - 16, 96,
          color: const Color(0xFFFF9C8A), anchor: Anchor.centerRight, outline: ink, bold: true);
    }
    for (final f in _floaters) {
      final alpha = (1.4 - f.age * 1.4).clamp(0.0, 1.0);
      drawText(canvas, f.text, f.pos.dx.clamp(50, Layout.width - 50), (f.pos.dy - 24 - f.age * 28).roundToDouble(),
          size: 16,
          color: f.color.withValues(alpha: alpha),
          outline: ink.withValues(alpha: alpha),
          bold: true);
    }
    if (_bannerLeft > 0 && session != null) {
      drawBanner(canvas, _bannerTitle, _bannerSub, _bannerLeft * 3);
    }
    canvas.restore();
  }

  Session? _preview; // 시작 화면 뒤에 보이는 빈 가게

  @override
  void onTapDown(TapDownEvent event) {
    final s = session;
    if (s == null || s.finished) return;
    final p = (event.canvasPosition.toOffset() - _origin) / _scale;
    for (var i = 0; i < Balance.griddleSlots; i++) {
      if (Layout.griddle(i).contains(p)) return s.tapGriddle(i);
    }
    for (final t in Topping.values) {
      if (Layout.tray(t.index).inflate(3).contains(p)) {
        s.applyTopping(t);
        return;
      }
    }
    for (var i = 0; i < s.customers.length; i++) {
      if (Layout.customer(i, s.customers.length).contains(p)) {
        s.serve(i);
        return;
      }
    }
  }
}

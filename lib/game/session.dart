/// 하루 영업의 규칙 전체. 화면(Flame)과 분리된 순수 로직이라 테스트와 시뮬레이션을 하기 쉽다.
library;

import 'dart:math';

import 'config.dart';
import 'progress.dart';

enum BakePhase { empty, baking, perfect, done, burnt }

class Griddle {
  bool hasBatter = false;
  double t = 0;
  Topping flavor = Topping.plain; // 반죽을 부을 때 정해지고, 굽는 동안에는 바꿀 수 없다.

  BakePhase phase(double bakeTime) {
    if (!hasBatter) return BakePhase.empty;
    if (t < bakeTime) return BakePhase.baking;
    if (t < bakeTime + Balance.perfectWindow) return BakePhase.perfect;
    if (t < bakeTime + Balance.burnAfter) return BakePhase.done;
    return BakePhase.burnt;
  }

  void clear() {
    hasBatter = false;
    t = 0;
  }
}

class Customer {
  Customer(this.order, this.qty, this.maxPatience, this.look, {this.vip = false})
      : patience = maxPatience;
  final Topping order;
  final int qty; // 주문 개수(1 또는 2)
  final double maxPatience;
  final int look; // 그림 구분용
  final bool vip;
  int delivered = 0;
  double patience;
  double age = 0;
  double get ratio => (patience / maxPatience).clamp(0, 1);
  int get remaining => qty - delivered;
}

enum FxType { perfect, good, tooEarly, burnt, trayFull, served, setBonus, lost, rush, vip, noStock, staff, mission }

/// 화면 연출(떠오르는 글자 등)을 위해 로직이 남기는 사건 기록.
class Fx {
  Fx(this.type, {this.griddle, this.slot, this.amount = 0, this.staff, this.topping});
  final FxType type;
  final int? griddle;
  final int? slot;
  final int amount;
  final StaffId? staff;
  final Topping? topping; // 진열대로 옮겨진 와플의 맛
}

/// 하루에 하나 주어지는 추가 목표. 달성하면 정산 때 보너스를 받는다.
class Mission {
  Mission(this.type, this.target, this.reward);
  final MissionType type;
  final int target;
  final int reward;

  String get title => switch (type) {
        MissionType.perfects => '퍼펙트 $target번',
        MissionType.serves => '와플 $target개 판매',
        MissionType.combo => '콤보 $target 달성',
        MissionType.noBurn => '하나도 태우지 않기',
        MissionType.noLost => '손님 놓치지 않기',
      };

  /// 영업 중 화면에 보이는 짧은 진행 표시.
  String progressLabel(Session s) => switch (type) {
        MissionType.perfects => '퍼펙트 ${s.perfects}/$target',
        MissionType.serves => '판매 ${s.served}/$target',
        MissionType.combo => '콤보 ${s.bestCombo}/$target',
        MissionType.noBurn => s.burnt == 0 ? '안 태우기' : '태웠어요',
        MissionType.noLost => s.lost == 0 ? '손님 지키기' : '놓쳤어요',
      };

  /// 횟수를 채우는 미션은 채우는 즉시, 지키는 미션은 영업이 끝났을 때 달성된다.
  bool done(Session s) => switch (type) {
        MissionType.perfects => s.perfects >= target,
        MissionType.serves => s.served >= target,
        MissionType.combo => s.bestCombo >= target,
        MissionType.noBurn => s.finished && s.burnt == 0 && s.served >= target,
        MissionType.noLost => s.finished && s.lost == 0 && s.served >= target,
      };

  bool failed(Session s) => switch (type) {
        MissionType.noBurn => s.burnt > 0,
        MissionType.noLost => s.lost > 0,
        _ => false,
      };
}

class Session {
  Session(this.progress, {Random? random, this.autoSpawn = true, Weather? weather})
      : rng = random ?? Random(),
        day = progress.day,
        goal = Balance.goalForDay(progress.day) {
    this.weather = weather ?? _rollWeather();
    customers = List<Customer?>.filled(progress.stageDef.customerSlots, null);
    mission = _rollMission();
    rushAt = progress.day >= 2 ? 15 + rng.nextDouble() * 25 : -1;
    vipAt = progress.day >= 3 ? 8 + rng.nextDouble() * 40 : -1;
    spawnTimer = 1.0;
  }

  final Progress progress;
  final Random rng;
  final bool autoSpawn;
  final int day; // 이 영업이 시작된 날짜
  final int goal;
  late final Weather weather;
  late final Mission mission;
  bool _missionAnnounced = false;

  final griddles = List.generate(Balance.griddleSlots, (_) => Griddle());
  late final List<Customer?> customers;
  final tray = {for (final t in Topping.values) t: 0};

  /// 지금 고른 맛. 빈 와플판을 누르면 이 맛으로 굽기 시작한다.
  Topping selected = Topping.plain;
  final List<Fx> events = [];
  final _staffTimer = {for (final id in StaffId.values) id: 0.0};

  double timeLeft = Balance.dayLength;
  int earned = 0;
  int combo = 0;
  int bestCombo = 0;
  int served = 0;
  int lost = 0;
  int burnt = 0;
  int perfects = 0;
  late double rushAt;
  late double vipAt;
  bool _vipPending = false;
  double rushLeft = 0;
  late double spawnTimer;

  WeatherDef get weatherDef => weatherDefs[weather]!;
  bool get finished => timeLeft <= 0;
  bool get success => earned >= goal;
  int get stars => earned >= goal * Balance.star3
      ? 3
      : earned >= goal * Balance.star2
          ? 2
          : (success ? 1 : 0);
  int get starBonus => switch (stars) {
        3 => (goal * Balance.star3Bonus).round(),
        2 => (goal * Balance.star2Bonus).round(),
        _ => 0,
      };
  int get missionBonus => mission.done(this) ? mission.reward : 0;

  /// 예상 손님 수에 맞춰 무리 없는 목표치를 정한다.
  Mission _rollMission() {
    final reward = (goal * missionRewardRatio / 10).round() * 10;
    final customers = Balance.dayLength / spawnInterval;
    final type = day == 1 ? MissionType.serves : MissionType.values[rng.nextInt(MissionType.values.length)];
    final target = switch (type) {
      MissionType.perfects => (customers * 0.45).round().clamp(4, 30),
      MissionType.serves => (customers * 0.75).round().clamp(5, 60),
      MissionType.combo => (4 + progress.stage * 2 + day ~/ 10).clamp(4, 12),
      // 지키는 미션은 가만히 있어서 달성되지 않도록 최소 판매량을 둔다.
      MissionType.noBurn || MissionType.noLost => (customers * 0.4).round().clamp(4, 30),
    };
    return Mission(type, target, reward);
  }

  bool get rushing => rushLeft > 0;
  int get trayCount => tray.values.fold(0, (a, b) => a + b);
  bool get trayFull => trayCount >= progress.trayCapacity;
  bool isGriddleOpen(int i) => i < progress.griddleCount;
  BakePhase phaseOf(int i) => griddles[i].phase(progress.bakeTime);
  double get spawnInterval =>
      Balance.baseSpawn * progress.spawnFactor * weatherDef.spawnFactor * Balance.wordOfMouth(day);

  Weather _rollWeather() {
    if (progress.day < 3) return Weather.sunny;
    final r = rng.nextDouble();
    return r < 0.6 ? Weather.sunny : (r < 0.8 ? Weather.rain : Weather.festival);
  }

  // ── 플레이어 조작 ──

  /// 진열대의 맛 칸 탭: 다음에 구울 맛을 고른다. 이미 굽고 있는 와플에는 영향이 없다.
  bool selectFlavor(Topping t) {
    if (finished || !progress.isUnlocked(t)) return false;
    selected = t;
    return true;
  }

  /// 빈 와플판에 [flavor] 맛 반죽을 붓는다.
  bool pour(int i, Topping flavor) {
    if (finished || !isGriddleOpen(i) || !progress.isUnlocked(flavor)) return false;
    final g = griddles[i];
    if (g.hasBatter) return false;
    g
      ..hasBatter = true
      ..t = 0
      ..flavor = flavor;
    return true;
  }

  /// 와플판 탭: 빈 칸이면 고른 맛으로 반죽 붓기, 다 구워졌으면 꺼내기, 탔으면 버리기.
  void tapGriddle(int i) {
    if (finished || !isGriddleOpen(i)) return;
    final g = griddles[i];
    final flavor = g.flavor;
    switch (phaseOf(i)) {
      case BakePhase.empty:
        pour(i, selected);
      case BakePhase.baking:
        events.add(Fx(FxType.tooEarly, griddle: i));
      case BakePhase.perfect:
        if (_toTray(i)) {
          combo++;
          perfects++;
          bestCombo = max(bestCombo, combo);
          events.add(Fx(FxType.perfect, griddle: i, amount: combo, topping: flavor));
        }
      case BakePhase.done:
        if (_toTray(i)) {
          combo = 0;
          events.add(Fx(FxType.good, griddle: i, topping: flavor));
        }
      case BakePhase.burnt:
        g.clear();
    }
  }

  bool _toTray(int i) {
    if (trayFull) {
      events.add(Fx(FxType.trayFull, griddle: i));
      return false;
    }
    final flavor = griddles[i].flavor;
    tray[flavor] = tray[flavor]! + 1;
    griddles[i].clear();
    return true;
  }

  /// 손님 탭: 주문한 와플이 진열대에 있으면 한 개 건넨다.
  bool serve(int slot) {
    if (finished || slot >= customers.length) return false;
    final c = customers[slot];
    if (c == null) return false;
    if (tray[c.order]! <= 0) {
      events.add(Fx(FxType.noStock, slot: slot));
      return false;
    }
    tray[c.order] = tray[c.order]! - 1;
    final pay = priceFor(c);
    earned += pay;
    served++;
    c.delivered++;
    events.add(Fx(FxType.served, slot: slot, amount: pay));
    if (c.remaining <= 0) {
      if (c.qty > 1) {
        final bonus = (basePrice(c.order) * c.qty * Balance.setBonus).round();
        earned += bonus;
        events.add(Fx(FxType.setBonus, slot: slot, amount: bonus));
      }
      customers[slot] = null;
    }
    return true;
  }

  double basePrice(Topping t) =>
      toppingPrices[t]! * progress.priceMultiplier * weatherDef.priceFactor;

  /// 판매가 = 기본가 × 콤보 × (러시) × (VIP) + 빨리 줬을 때 팁.
  int priceFor(Customer c) {
    final base = basePrice(c.order);
    final comboBonus = 1 + min(combo, Balance.comboCap) * Balance.comboStep;
    final rush = rushing ? Balance.rushPay : 1.0;
    final vip = c.vip ? Balance.vipPay : 1.0;
    final tip = c.ratio > 0.5 ? base * Balance.tipRatio : 0;
    return (base * comboBonus * rush * vip + tip).round();
  }

  bool addCustomer(Topping order, {int qty = 1, bool vip = false}) {
    final i = customers.indexOf(null);
    if (i < 0) return false;
    var patience = (Balance.patienceForDay(progress.day) + progress.patienceBonus) *
        weatherDef.patienceFactor;
    if (qty > 1) patience *= 1.25;
    if (vip) patience *= Balance.vipPatience;
    customers[i] = Customer(order, qty, patience, rng.nextInt(1000), vip: vip);
    if (vip) events.add(Fx(FxType.vip, slot: i));
    return true;
  }

  // ── 시간 흐름 ──

  void update(double dt) {
    if (finished) return;
    timeLeft = max(0, timeLeft - dt);
    final elapsed = Balance.dayLength - timeLeft;

    // 돌발 이벤트 1: 단체 손님 러시
    if (rushLeft > 0) {
      rushLeft = max(0, rushLeft - dt);
    } else if (rushAt >= 0 && elapsed >= rushAt) {
      rushAt = -1;
      rushLeft = Balance.rushLength;
      events.add(Fx(FxType.rush));
    }
    // 돌발 이벤트 2: 큰손 손님(VIP). 자리가 날 때까지 기다렸다 등장.
    if (vipAt >= 0 && elapsed >= vipAt) {
      vipAt = -1;
      _vipPending = true;
    }
    if (_vipPending && autoSpawn) {
      final options = progress.unlockedToppings;
      if (addCustomer(options.last, vip: true)) _vipPending = false;
    }

    _updateGriddles(dt);
    _updateCustomers(dt);
    _updateStaff(dt);
    if (!_missionAnnounced && mission.done(this)) {
      _missionAnnounced = true;
      events.add(Fx(FxType.mission, amount: mission.reward));
    }
  }

  void _updateGriddles(double dt) {
    final bake = progress.bakeTime;
    final hasBaker = progress.isWorking(StaffId.baker);
    for (var i = 0; i < progress.griddleCount; i++) {
      final g = griddles[i];
      if (!g.hasBatter) continue;
      final before = g.phase(bake);
      g.t += dt;
      final after = g.phase(bake);
      if (after == BakePhase.burnt && before != BakePhase.burnt) {
        burnt++;
        combo = 0;
        earned = max(0, earned - Balance.burnPenalty);
        events.add(Fx(FxType.burnt, griddle: i, amount: Balance.burnPenalty));
      }
      // 굽기 담당: 다 구워지고 일정 시간이 지나면 대신 꺼낸다(콤보에는 영향 없음).
      if (hasBaker && !trayFull && after != BakePhase.burnt &&
          g.t >= bake + progress.staffValue(StaffId.baker)) {
        final flavor = g.flavor;
        tray[flavor] = tray[flavor]! + 1;
        g.clear();
        _staffWorked(StaffId.baker, griddle: i, topping: flavor);
      }
    }
  }

  void _updateCustomers(double dt) {
    for (var i = 0; i < customers.length; i++) {
      final c = customers[i];
      if (c == null) continue;
      c.age += dt;
      c.patience -= dt;
      if (c.patience <= 0) {
        customers[i] = null;
        lost++;
        combo = 0;
        events.add(Fx(FxType.lost, slot: i));
      }
    }
    if (!autoSpawn) return;
    spawnTimer -= dt * (rushing ? 2 : 1);
    if (spawnTimer <= 0) {
      spawnTimer = spawnInterval * (0.8 + rng.nextDouble() * 0.4);
      final options = progress.unlockedToppings;
      final qty = rng.nextDouble() < progress.stageDef.doubleOrderChance ? 2 : 1;
      addCustomer(options[rng.nextInt(options.length)], qty: qty);
    }
  }

  void _updateStaff(double dt) {
    // 반죽 담당: 기다리는 주문에 비해 모자란 맛을 골라 빈 판에 부어 준다.
    if (progress.isWorking(StaffId.topper) && _tick(StaffId.topper, dt)) {
      final short = shortage();
      final empty = [for (var i = 0; i < progress.griddleCount; i++) if (!griddles[i].hasBatter) i];
      if (empty.isNotEmpty) {
        for (final t in Topping.values.reversed) {
          if (short[t]! > 0 && pour(empty.first, t)) {
            _staffWorked(StaffId.topper, griddle: empty.first);
            break;
          }
        }
      }
    }
    // 서빙 담당: 줄 수 있는 손님 중 가장 급한 손님에게 건넨다.
    if (progress.isWorking(StaffId.server) && _tick(StaffId.server, dt)) {
      int? best;
      for (var i = 0; i < customers.length; i++) {
        final c = customers[i];
        if (c == null || tray[c.order]! <= 0) continue;
        if (best == null || c.patience < customers[best]!.patience) best = i;
      }
      if (best != null && serve(best)) _staffWorked(StaffId.server);
    }
  }

  /// 직원 행동 간격 타이머. 준비가 되면 true 를 돌려주고, 실제로 일했을 때만 초기화된다.
  bool _tick(StaffId id, double dt) {
    _staffTimer[id] = _staffTimer[id]! + dt;
    return _staffTimer[id]! >= progress.staffValue(id);
  }

  void _staffWorked(StaffId id, {int? griddle, Topping? topping}) {
    _staffTimer[id] = 0;
    progress.staff[id]!.xp++;
    events.add(Fx(FxType.staff, staff: id, griddle: griddle, topping: topping));
  }

  /// 맛별로 '기다리는 주문 - (진열대 + 굽는 중)'. 0보다 크면 그만큼 더 구워야 한다.
  Map<Topping, int> shortage() {
    final short = {for (final t in Topping.values) t: -tray[t]!};
    for (final c in customers) {
      if (c != null) short[c.order] = short[c.order]! + c.remaining;
    }
    for (var i = 0; i < progress.griddleCount; i++) {
      final g = griddles[i];
      if (g.hasBatter && phaseOf(i) != BakePhase.burnt) short[g.flavor] = short[g.flavor]! - 1;
    }
    return short;
  }
}

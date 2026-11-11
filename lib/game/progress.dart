/// 날짜가 바뀌어도 유지되는 진행 상황(돈, 날짜, 가게 단계, 업그레이드, 직원)과 저장/불러오기.
library;

import 'dart:convert';
import 'dart:math';

import 'config.dart';

class StaffState {
  bool hired = false;
  int xp = 0;

  int get level {
    var lv = 1;
    for (var i = 1; i < staffXpTable.length; i++) {
      if (xp >= staffXpTable[i]) lv = i + 1;
    }
    return lv;
  }

  /// 다음 레벨까지 진행도(0~1). 최대 레벨이면 1.
  double get levelProgress {
    final lv = level;
    if (lv >= staffMaxLevel) return 1;
    final from = staffXpTable[lv - 1], to = staffXpTable[lv];
    return (xp - from) / (to - from);
  }
}

class Progress {
  int money = 0;
  int day = 1;
  int stage = 0;
  int stars = 0;
  final Map<UpgradeId, int> levels = {for (final id in UpgradeId.values) id: 0};
  final Map<StaffId, StaffState> staff = {for (final id in StaffId.values) id: StaffState()};

  int level(UpgradeId id) => levels[id] ?? 0;
  StageDef get stageDef => stageDefs[stage];

  // ── 업그레이드가 실제 수치에 주는 효과 ──
  double get bakeTime => Balance.baseBakeTime * pow(0.9, level(UpgradeId.heat));
  int get griddleCount =>
      min(Balance.startGriddles + level(UpgradeId.griddle), stageDef.griddleCap);
  int get trayCapacity => 4 + 2 * level(UpgradeId.tray);
  double get priceMultiplier => 1 + 0.1 * level(UpgradeId.batter);
  double get patienceBonus => 2.0 * level(UpgradeId.decor);
  double get spawnFactor => stageDef.spawnFactor * pow(0.92, level(UpgradeId.sign));

  bool isUnlocked(Topping t) => switch (t) {
        Topping.plain || Topping.choco => true,
        Topping.honey => level(UpgradeId.honey) > 0,
        Topping.berry => level(UpgradeId.berry) > 0,
        Topping.matcha => level(UpgradeId.matcha) > 0,
        Topping.cream => level(UpgradeId.cream) > 0,
      };

  List<Topping> get unlockedToppings => Topping.values.where(isUnlocked).toList();

  // ── 업그레이드 구매 ──
  bool isMaxed(UpgradeId id) => level(id) >= upgradeDefs[id]!.maxLevel;
  int costOf(UpgradeId id) => upgradeDefs[id]!.cost(level(id));

  /// 살 수 없는 이유(살 수 있으면 null). 상점 버튼 문구에도 쓰인다.
  String? blockReason(UpgradeId id) {
    if (isMaxed(id)) return '최대';
    if (stage < upgradeDefs[id]!.minStage) return '${upgradeDefs[id]!.minStage + 1}단계 필요';
    if (id == UpgradeId.griddle &&
        Balance.startGriddles + level(id) >= stageDef.griddleCap) {
      return stage < stageDefs.length - 1 ? '확장 필요' : '최대';
    }
    return null;
  }

  bool canBuy(UpgradeId id) => blockReason(id) == null && money >= costOf(id);

  bool buy(UpgradeId id) {
    if (!canBuy(id)) return false;
    money -= costOf(id);
    levels[id] = level(id) + 1;
    return true;
  }

  // ── 가게 확장 ──
  bool get hasNextStage => stage < stageDefs.length - 1;
  int get nextStageCost => stageDefs[stage + 1].cost;
  bool get canExpand => hasNextStage && money >= nextStageCost;

  bool expand() {
    if (!canExpand) return false;
    money -= nextStageCost;
    stage++;
    return true;
  }

  // ── 직원 ──
  bool isWorking(StaffId id) => staff[id]!.hired;
  int staffLevel(StaffId id) => staff[id]!.level;
  double staffValue(StaffId id) => staffDefs[id]!.byLevel[staffLevel(id) - 1];
  bool canHire(StaffId id) =>
      !staff[id]!.hired && stage >= staffDefs[id]!.minStage && money >= staffDefs[id]!.hireCost;

  bool hire(StaffId id) {
    if (!canHire(id)) return false;
    money -= staffDefs[id]!.hireCost;
    staff[id]!.hired = true;
    return true;
  }

  int trainCostOf(StaffId id) => Balance.trainCost(staffLevel(id));
  bool canTrain(StaffId id) =>
      staff[id]!.hired && staffLevel(id) < staffMaxLevel && money >= trainCostOf(id);

  bool train(StaffId id) {
    if (!canTrain(id)) return false;
    money -= trainCostOf(id);
    staff[id]!.xp += Balance.trainXp;
    return true;
  }

  // ── 저장 ──
  String encode() => jsonEncode({
        'money': money,
        'day': day,
        'stage': stage,
        'stars': stars,
        'levels': {for (final e in levels.entries) e.key.name: e.value},
        'staff': {
          for (final e in staff.entries) e.key.name: {'hired': e.value.hired, 'xp': e.value.xp}
        },
      });

  static Progress decode(String? raw) {
    final p = Progress();
    if (raw == null) return p;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      p.money = map['money'] as int? ?? 0;
      p.day = map['day'] as int? ?? 1;
      p.stage = (map['stage'] as int? ?? 0).clamp(0, stageDefs.length - 1);
      p.stars = map['stars'] as int? ?? 0;
      final lv = map['levels'] as Map<String, dynamic>? ?? {};
      for (final id in UpgradeId.values) {
        p.levels[id] = (lv[id.name] as int? ?? 0).clamp(0, upgradeDefs[id]!.maxLevel);
      }
      final st = map['staff'] as Map<String, dynamic>? ?? {};
      for (final id in StaffId.values) {
        final s = st[id.name] as Map<String, dynamic>?;
        if (s == null) continue;
        p.staff[id]!
          ..hired = s['hired'] as bool? ?? false
          ..xp = s['xp'] as int? ?? 0;
      }
    } catch (_) {
      return Progress();
    }
    return p;
  }
}

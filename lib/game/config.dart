/// 게임 밸런스와 고정 데이터(토핑, 업그레이드, 가게 단계, 직원, 날씨)를 모아둔 파일.
/// 숫자만 바꿔도 난이도를 조절할 수 있고, tool/balance_sim.dart 로 결과를 확인할 수 있다.
library;

import 'dart:math';

enum Topping { plain, choco, berry, cream }

const toppingLabels = {
  Topping.plain: '기본',
  Topping.choco: '초코',
  Topping.berry: '딸기',
  Topping.cream: '크림',
};

const toppingPrices = {
  Topping.plain: 20,
  Topping.choco: 34,
  Topping.berry: 50,
  Topping.cream: 64,
};

// ── 가게 단계 ──────────────────────────────────────────────

class StageDef {
  const StageDef(this.name, this.desc, this.cost, this.customerSlots, this.griddleCap,
      this.spawnFactor, this.doubleOrderChance);
  final String name;
  final String desc;
  final int cost; // 이 단계로 확장하는 비용
  final int customerSlots; // 동시에 서 있는 손님 수
  final int griddleCap; // 와플판 최대 개수
  final double spawnFactor; // 손님 등장 간격 배율(작을수록 손님이 많다)
  final double doubleOrderChance; // 2개 주문 확률
}

const stageDefs = [
  StageDef('골목 수레', '작은 수레에서 시작해요', 0, 2, 4, 1.0, 0),
  StageDef('동네 가게', '손님 자리 3칸 · 2개 주문 등장 · 딸기 토핑 가능', 2200, 3, 6, 0.72, 0.3),
  StageDef('와플 카페', '손님 자리 4칸 · 와플판 9칸 · 크림 토핑 가능', 6000, 4, 9, 0.6, 0.35),
];

// ── 업그레이드 ─────────────────────────────────────────────

enum UpgradeId { heat, griddle, tray, batter, decor, sign, berry, cream }

class UpgradeDef {
  const UpgradeDef(this.name, this.desc, this.maxLevel, this.baseCost, this.growth,
      {this.minStage = 0});
  final String name;
  final String desc;
  final int maxLevel;
  final int baseCost;
  final double growth;
  final int minStage;

  int cost(int level) => (baseCost * pow(growth, level) / 10).round() * 10;
}

const upgradeDefs = {
  UpgradeId.griddle: UpgradeDef('와플판 추가', '굽는 칸이 하나 늘어나요', 7, 160, 2.0),
  UpgradeId.heat: UpgradeDef('화력 강화', '굽는 시간 -10%', 5, 240, 2.1),
  UpgradeId.sign: UpgradeDef('간판 홍보', '손님이 더 자주 와요', 5, 280, 1.8),
  UpgradeId.batter: UpgradeDef('고급 반죽', '모든 와플 가격 +10%', 5, 320, 2.0),
  UpgradeId.tray: UpgradeDef('진열대 확장', '보관 칸 +2', 4, 150, 1.9),
  UpgradeId.decor: UpgradeDef('가게 꾸미기', '손님이 2초 더 기다려요', 4, 220, 1.9),
  UpgradeId.berry: UpgradeDef('딸기 토핑', '딸기 와플 주문을 받아요', 1, 700, 1, minStage: 1),
  UpgradeId.cream: UpgradeDef('크림 토핑', '크림 와플 주문을 받아요', 1, 5000, 1, minStage: 2),
};

// ── 직원 ───────────────────────────────────────────────────

enum StaffId { baker, topper, server }

class StaffDef {
  const StaffDef(this.name, this.role, this.desc, this.hireCost, this.minStage, this.byLevel);
  final String name;
  final String role;
  final String desc;
  final int hireCost;
  final int minStage;

  /// 레벨별 수치(초). 굽기 담당은 '다 구워진 뒤 꺼내기까지', 나머지는 '행동 간격'.
  final List<double> byLevel;
}

const staffDefs = {
  StaffId.baker: StaffDef('밀', '굽기 담당', '다 구워진 와플을 타기 전에 꺼내줘요', 500, 0,
      [2.6, 2.1, 1.6, 1.1, 0.5]),
  StaffId.topper: StaffDef('라즈', '토핑 담당', '주문에 맞춰 토핑을 올려줘요', 1400, 1,
      [3.6, 3.0, 2.4, 1.9, 1.4]),
  StaffId.server: StaffDef('모카', '서빙 담당', '준비된 와플을 손님께 건네줘요', 6000, 2,
      [3.8, 3.2, 2.6, 2.1, 1.6]),
};

const staffMaxLevel = 5;

/// 레벨 2,3,4,5 가 되는 데 필요한 누적 경험치(일한 횟수 + 훈련).
const staffXpTable = [0, 60, 180, 400, 800];

// ── 날씨 ───────────────────────────────────────────────────

enum Weather { sunny, rain, festival }

class WeatherDef {
  const WeatherDef(this.name, this.desc, this.spawnFactor, this.priceFactor, this.patienceFactor);
  final String name;
  final String desc;
  final double spawnFactor;
  final double priceFactor;
  final double patienceFactor;
}

const weatherDefs = {
  Weather.sunny: WeatherDef('맑음', '평범한 하루', 1.0, 1.0, 1.0),
  Weather.rain: WeatherDef('비', '손님은 적지만 따뜻한 와플이 30% 비싸게 팔려요', 1.3, 1.3, 1.15),
  Weather.festival: WeatherDef('축제', '손님이 몰려오지만 성격이 급해요', 0.72, 1.0, 0.85),
};

// ── 수치 ───────────────────────────────────────────────────

class Balance {
  static const dayLength = 60.0;
  static const baseBakeTime = 5.0;
  static const perfectWindow = 0.9; // 다 구워진 직후 '퍼펙트' 판정 시간(초)
  static const burnAfter = 3.2; // 다 구워진 뒤 이 시간이 지나면 탄다
  static const burnPenalty = 10;
  static const comboStep = 0.04; // 콤보 1당 가격 +4%
  static const comboCap = 10;
  static const tipRatio = 0.2; // 인내심이 절반 넘게 남았을 때 팁
  static const setBonus = 0.3; // 2개 주문을 모두 채웠을 때 보너스
  static const rushLength = 10.0;
  static const rushPay = 1.5;
  static const vipPay = 3.0;
  static const vipPatience = 0.65;
  static const basePatience = 15.0;
  static const baseSpawn = 4.2;
  static const maxCustomerSlots = 4;
  static const griddleSlots = 9;
  static const startGriddles = 2;
  static const star2 = 1.35;
  static const star3 = 1.75;
  static const star2Bonus = 0.1; // 목표 금액 대비 보너스
  static const star3Bonus = 0.25;

  /// 하루 목표 매출의 기준점 (날짜, 목표). 사이 날짜는 직선으로 잇는다.
  /// 시뮬레이션(tool/balance_sim.dart)의 '보통 플레이어' 매출 ÷ 1.5 근처로 맞췄고,
  /// 동네 가게에서 수입이 잠시 정체되는 9~16일차는 완만하게 올린다.
  static const goalAnchors = [
    (1, 150), (5, 480), (9, 850), (13, 1050), (16, 1250),
    (20, 1900), (25, 2700), (30, 3500), (35, 4300), (40, 4800),
  ];

  static int goalForDay(int day) {
    if (day >= goalAnchors.last.$1) return goalAnchors.last.$2;
    for (var i = 1; i < goalAnchors.length; i++) {
      final (d0, g0) = goalAnchors[i - 1];
      final (d1, g1) = goalAnchors[i];
      if (day <= d1) return ((g0 + (g1 - g0) * (day - d0) / (d1 - d0)) / 10).round() * 10;
    }
    return goalAnchors.last.$2;
  }

  /// 날짜가 지날수록 손님이 조금씩 급해진다.
  static double patienceForDay(int day) => max(8.0, basePatience - min(day * 0.2, 4.0));

  /// 입소문: 날이 갈수록 손님이 조금씩 늘어난다(등장 간격 배율, 하루 1.2%씩 최대 25%).
  static double wordOfMouth(int day) => max(0.75, 1 - 0.012 * (day - 1));

  static int trainCost(int level) => 150 * level;
  static const trainXp = 25;
}

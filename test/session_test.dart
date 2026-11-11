import 'dart:math';

import 'package:crispy_waffle_shop/game/config.dart';
import 'package:crispy_waffle_shop/game/progress.dart';
import 'package:crispy_waffle_shop/game/session.dart';
import 'package:crispy_waffle_shop/game/sfx.dart';
import 'package:crispy_waffle_shop/game/sprites.dart';
import 'package:flutter_test/flutter_test.dart';

Session newSession([Progress? p]) =>
    Session(p ?? Progress(), random: Random(1), autoSpawn: false, weather: Weather.sunny);

void main() {
  test('퍼펙트로 꺼내면 콤보가 오르고 진열대에 쌓인다', () {
    final s = newSession();
    s.tapGriddle(0);
    s.update(Balance.baseBakeTime + 0.1);
    expect(s.phaseOf(0), BakePhase.perfect);
    s.tapGriddle(0);
    expect(s.combo, 1);
    expect(s.tray[Topping.plain], 1);
    expect(s.phaseOf(0), BakePhase.empty);
  });

  test('늦게 꺼내면 콤보가 끊기고, 방치하면 타서 벌금', () {
    final s = newSession()..combo = 3;
    s.tapGriddle(0);
    s.update(Balance.baseBakeTime + Balance.perfectWindow + 0.1);
    s.tapGriddle(0);
    expect(s.combo, 0);
    s.earned = 50;
    s.tapGriddle(1);
    s.update(Balance.baseBakeTime + Balance.burnAfter + 0.1);
    expect(s.phaseOf(1), BakePhase.burnt);
    expect(s.earned, 50 - Balance.burnPenalty);
    s.tapGriddle(1);
    expect(s.phaseOf(1), BakePhase.empty);
  });

  test('토핑을 올려 주문에 맞게 판매하면 돈을 번다', () {
    final s = newSession();
    s.tray[Topping.plain] = 1;
    s.addCustomer(Topping.choco);
    expect(s.serve(0), isFalse); // 초코 와플이 아직 없음
    expect(s.applyTopping(Topping.choco), isTrue);
    expect(s.serve(0), isTrue);
    expect(s.earned, 41); // 34 + 팁 20%
    expect(s.customers[0], isNull);
  });

  test('2개 주문은 두 번 건네야 끝나고 세트 보너스를 준다', () {
    final s = newSession();
    s.tray[Topping.plain] = 2;
    s.addCustomer(Topping.plain, qty: 2);
    s.serve(0);
    expect(s.customers[0]!.remaining, 1);
    s.serve(0);
    expect(s.customers[0], isNull);
    expect(s.earned, 24 + 24 + 12); // (20 + 팁) x2 + 세트 30%
  });

  test('큰손 손님은 3배를 낸다', () {
    final s = newSession();
    s.tray[Topping.plain] = 1;
    s.addCustomer(Topping.plain, vip: true);
    s.serve(0);
    expect(s.earned, 64); // 20 x 3 + 팁 4
  });

  test('잠긴 토핑·와플판·단계 제한', () {
    final p = Progress()..money = 99999;
    final s = newSession(p);
    s.tray[Topping.plain] = 1;
    expect(s.applyTopping(Topping.cream), isFalse);
    s.tapGriddle(8);
    expect(s.phaseOf(8), BakePhase.empty);
    expect(s.customers.length, 2);
    expect(p.buy(UpgradeId.berry), isFalse); // 동네 가게부터 가능
    expect(p.buy(UpgradeId.griddle), isTrue);
    expect(p.buy(UpgradeId.griddle), isTrue);
    expect(p.buy(UpgradeId.griddle), isFalse); // 수레는 4칸까지
    expect(p.expand(), isTrue);
    expect(p.buy(UpgradeId.berry), isTrue);
    expect(newSession(p).customers.length, 3);
  });

  test('기다리다 지친 손님은 떠난다', () {
    final s = newSession();
    s.addCustomer(Topping.plain);
    s.update(30);
    expect(s.lost, 1);
    expect(s.customers[0], isNull);
  });

  test('직원: 굽기 담당은 타기 전에 꺼내고 경험치를 얻는다', () {
    final p = Progress()..money = 1000;
    expect(p.hire(StaffId.baker), isTrue);
    final s = newSession(p);
    s.tapGriddle(0);
    for (var i = 0; i < 90; i++) {
      s.update(0.1);
    }
    expect(s.tray[Topping.plain], 1);
    expect(s.burnt, 0);
    expect(p.staff[StaffId.baker]!.xp, 1);
  });

  test('직원: 토핑·서빙 담당이 주문을 스스로 처리한다', () {
    final p = Progress()
      ..stage = 2
      ..money = 99999;
    p.hire(StaffId.topper);
    p.hire(StaffId.server);
    final s = newSession(p);
    s.tray[Topping.plain] = 1;
    s.addCustomer(Topping.choco);
    for (var i = 0; i < 80; i++) {
      s.update(0.1);
    }
    expect(s.served, 1);
    expect(s.earned, greaterThan(0));
  });

  test('훈련으로 직원 레벨이 오른다', () {
    final p = Progress()..money = 99999;
    p.hire(StaffId.baker);
    while (p.canTrain(StaffId.baker)) {
      p.train(StaffId.baker);
    }
    expect(p.staffLevel(StaffId.baker), staffMaxLevel);
  });

  test('별: 목표의 1.35배, 1.75배에서 2개, 3개', () {
    final s = newSession();
    s.earned = s.goal;
    expect(s.stars, 1);
    s.earned = (s.goal * Balance.star2).ceil();
    expect(s.stars, 2);
    s.earned = (s.goal * Balance.star3).ceil();
    expect(s.stars, 3);
    expect(s.starBonus, greaterThan(0));
  });

  test('새 토핑: 허니버터는 수레에서, 말차는 카페에서 열린다', () {
    final p = Progress()..money = 99999;
    expect(p.buy(UpgradeId.honey), isTrue);
    expect(p.buy(UpgradeId.matcha), isFalse);
    p.expand();
    p.expand();
    expect(p.buy(UpgradeId.matcha), isTrue);
    final s = newSession(p);
    s.tray[Topping.plain] = 2;
    expect(s.applyTopping(Topping.honey), isTrue);
    expect(s.applyTopping(Topping.matcha), isTrue);
    s.addCustomer(Topping.matcha);
    expect(s.serve(0), isTrue);
  });

  test('미션: 횟수를 채우면 즉시 달성되고 보너스가 붙는다', () {
    final s = newSession();
    expect(s.mission.type, MissionType.serves); // 1일차는 항상 판매 미션
    expect(s.missionBonus, 0);
    s.served = s.mission.target;
    s.update(0.1);
    expect(s.missionBonus, s.mission.reward);
    expect(s.events.any((e) => e.type == FxType.mission), isTrue);
  });

  test('미션: 지키는 미션은 영업이 끝나야 달성되고, 어기면 실패한다', () {
    final s = newSession();
    final keep = Mission(MissionType.noBurn, 3, 50);
    s.served = 3;
    expect(keep.done(s), isFalse); // 아직 영업 중
    s.timeLeft = 0;
    expect(keep.done(s), isTrue);
    s.burnt = 1;
    expect(keep.done(s), isFalse);
    expect(keep.failed(s), isTrue);
  });

  test('저장/불러오기', () {
    final p = Progress()..money = 5000;
    p.expand();
    p.buy(UpgradeId.berry);
    p.hire(StaffId.baker);
    p.staff[StaffId.baker]!.xp = 70;
    final q = Progress.decode(p.encode());
    expect(q.money, p.money);
    expect(q.stage, 1);
    expect(q.isUnlocked(Topping.berry), isTrue);
    expect(q.staffLevel(StaffId.baker), 2);
  });

  test('목표 금액은 날짜가 갈수록 오르고 상한이 있다', () {
    for (var d = 1; d < 60; d++) {
      expect(Balance.goalForDay(d + 1), greaterThanOrEqualTo(Balance.goalForDay(d)));
    }
    expect(Balance.goalForDay(1), 150);
    expect(Balance.goalForDay(100), Balance.goalAnchors.last.$2);
  });

  test('소리 설정: 크기 단계, 음소거와 되돌리기, 진동은 따로', () {
    final sfx = Sfx();
    expect(sfx.volumeLevel, Sfx.defaultVolumeLevel);
    sfx.setVolumeLevel(5);
    sfx.toggleMute();
    expect(sfx.muted, isTrue);
    expect(sfx.haptics, isTrue); // 소리를 꺼도 진동은 그대로
    sfx.toggleMute();
    expect(sfx.volumeLevel, 5); // 끄기 전 크기로 복귀
    sfx.setVolumeLevel(99);
    expect(sfx.volumeLevel, Sfx.maxVolumeLevel);
  });

  test('도트 그림의 모든 줄은 길이가 같다', () {
    for (final rows in allSpriteRows) {
      for (final row in rows) {
        expect(row.length, rows.first.length, reason: row);
      }
    }
  });
}

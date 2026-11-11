// ignore_for_file: avoid_print
// 밸런스 확인용 자동 플레이. 실행: dart run tool/balance_sim.dart
// 실력이 다른 가상의 플레이어가 40일을 플레이했을 때 매출/목표/별/성장 속도를 표로 보여준다.
import 'dart:math';

import 'package:crispy_waffle_shop/game/config.dart';
import 'package:crispy_waffle_shop/game/progress.dart';
import 'package:crispy_waffle_shop/game/session.dart';

class Bot {
  Bot(this.name, this.tapsPerSec, this.perfectRate, this.seed);
  final String name;
  final double tapsPerSec; // 초당 유효 터치 수
  final double perfectRate; // 퍼펙트 타이밍을 맞출 확률
  final int seed;
}

void playDay(Session s, Bot bot, Random rng) {
  const dt = 0.1;
  var budget = 0.0;
  final wantPerfect = List.filled(Balance.griddleSlots, false);
  while (!s.finished) {
    s.update(dt);
    s.events.clear();
    budget = min(budget + bot.tapsPerSec * dt, 2);
    while (budget >= 1) {
      if (!_act(s, bot, rng, wantPerfect)) break;
      budget -= 1;
    }
  }
}

bool _act(Session s, Bot bot, Random rng, List<bool> wantPerfect) {
  final p = s.progress;
  // 1) 팔 수 있으면 판다
  for (var i = 0; i < s.customers.length; i++) {
    final c = s.customers[i];
    if (c != null && s.tray[c.order]! > 0) return s.serve(i);
  }
  // 2) 다 구워진 와플 꺼내기 / 탄 와플 치우기
  for (var i = 0; i < p.griddleCount; i++) {
    final ph = s.phaseOf(i);
    if (ph == BakePhase.burnt) {
      s.tapGriddle(i);
      return true;
    }
    if (s.trayFull) continue;
    if ((ph == BakePhase.perfect && wantPerfect[i]) || ph == BakePhase.done) {
      s.tapGriddle(i);
      return true;
    }
  }
  // 3) 필요한 토핑 올리기
  final need = {for (final t in Topping.values) t: 0};
  for (final c in s.customers) {
    if (c != null) need[c.order] = need[c.order]! + c.remaining;
  }
  for (final t in Topping.values) {
    if (t != Topping.plain && need[t]! > s.tray[t]! && s.tray[Topping.plain]! > 0) {
      return s.applyTopping(t);
    }
  }
  // 4) 빈 판에 반죽 붓기(진열대가 넘치지 않을 만큼만)
  final baking = [for (var i = 0; i < p.griddleCount; i++) if (s.griddles[i].hasBatter) i].length;
  if (s.trayCount + baking < p.trayCapacity) {
    for (var i = 0; i < p.griddleCount; i++) {
      if (s.phaseOf(i) == BakePhase.empty) {
        s.tapGriddle(i);
        wantPerfect[i] = rng.nextDouble() < bot.perfectRate;
        return true;
      }
    }
  }
  return false;
}

/// 상점에서 살 수 있는 것 중 가장 싼 것부터 산다(가게 확장은 돈이 모이면 최우선).
void shop(Progress p) {
  while (true) {
    if (p.canExpand) {
      p.expand();
      continue;
    }
    // 확장이 가까우면(70% 이상 모았으면) 돈을 아낀다.
    final saving = p.hasNextStage && p.money >= p.nextStageCost * 0.7;
    final options = <(int, void Function())>[];
    for (final id in UpgradeId.values) {
      if (p.canBuy(id)) options.add((p.costOf(id), () => p.buy(id)));
    }
    for (final id in StaffId.values) {
      if (p.canHire(id)) options.add((staffDefs[id]!.hireCost, () => p.hire(id)));
    }
    for (final id in StaffId.values) {
      if (p.canTrain(id)) options.add((p.trainCostOf(id), () => p.train(id)));
    }
    if (options.isEmpty || saving) return;
    options.sort((a, b) => a.$1.compareTo(b.$1));
    options.first.$2();
  }
}

void main(List<String> args) {
  final days = args.isNotEmpty ? int.parse(args[0]) : 40;
  final bots = [
    Bot('느긋한 플레이어', 1.6, 0.35, 11),
    Bot('보통 플레이어', 2.4, 0.6, 22),
    Bot('숙련 플레이어', 3.5, 0.85, 33),
  ];
  for (final bot in bots) {
    final rng = Random(bot.seed);
    final p = Progress();
    var attempts = 0, fails = 0, starSum = 0;
    print('\n=== ${bot.name} (초당 ${bot.tapsPerSec}회, 퍼펙트 ${(bot.perfectRate * 100).round()}%) ===');
    print('시도  일차  단계  매출   목표  별  손님(판매/놓침)  보유금');
    while (p.day <= days && attempts < days * 3) {
      attempts++;
      final day = p.day;
      final s = Session(p, random: rng);
      playDay(s, bot, rng);
      p.money += s.earned + s.starBonus;
      if (s.success) {
        p.day++;
      } else {
        fails++;
      }
      starSum += s.stars;
      final line = '${'$attempts'.padLeft(3)}  ${'$day'.padLeft(4)}  ${'${p.stage}'.padLeft(4)}'
          '  ${'${s.earned}'.padLeft(5)}  ${'${s.goal}'.padLeft(5)}  ${'★' * s.stars}${'·' * (3 - s.stars)}'
          '  ${'${s.served}/${s.lost}'.padLeft(8)}       ${p.money}';
      if (const bool.fromEnvironment('ALL') || day <= 12 || day % 4 == 0 || !s.success) print(line);
      shop(p);
    }
    print('→ $attempts번 영업, 실패 $fails번, 평균 별 ${(starSum / attempts).toStringAsFixed(2)}, '
        '최종 ${p.day - 1}일 클리어, 단계 ${stageDefs[p.stage].name}');
  }
}

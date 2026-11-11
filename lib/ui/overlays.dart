/// 게임 위에 겹쳐지는 Flutter 화면들: 시작 화면, 하루 정산 + 상점(업그레이드/직원/가게 확장).
library;

import 'package:flutter/material.dart';

import '../game/config.dart';
import '../game/progress.dart';
import '../game/waffle_game.dart';

const _ink = Color(0xFF3A2416);
const _cream = Color(0xFFFFF3DC);
const _pink = Color(0xFFE5486B);
const _gold = Color(0xFFFFB636);
const _green = Color(0xFF2E9E5B);

TextStyle _t(double size, {Color color = _ink, bool bold = false}) => TextStyle(
    fontSize: size, color: color, fontWeight: bold ? FontWeight.w700 : FontWeight.w400, height: 1.3);

/// 도트풍 상자: 굵은 테두리와 아래쪽 그림자.
class PixelPanel extends StatelessWidget {
  const PixelPanel({super.key, required this.child, this.color = _cream, this.padding = const EdgeInsets.all(14)});
  final Widget child;
  final Color color;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: _ink, width: 3),
          boxShadow: const [BoxShadow(color: Color(0x66000000), offset: Offset(0, 5))],
        ),
        child: child,
      );
}

class PixelButton extends StatelessWidget {
  const PixelButton(this.label, {super.key, this.onTap, this.color = _pink, this.big = false, this.width});
  final String label;
  final VoidCallback? onTap;
  final Color color;
  final bool big;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(vertical: big ? 12 : 7, horizontal: 8),
        decoration: BoxDecoration(
          color: enabled ? color : const Color(0xFFCDBFA8),
          border: Border.all(color: enabled ? _ink : const Color(0xFF9A8B74), width: 3),
          boxShadow: enabled ? const [BoxShadow(color: _ink, offset: Offset(0, 3))] : null,
        ),
        child: Text(label,
            textAlign: TextAlign.center,
            style: _t(big ? 20 : 12, color: enabled ? Colors.white : const Color(0xFF8A7B68), bold: true)),
      ),
    );
  }
}

Widget _screen(Widget child) => Container(
      color: const Color(0x99000000),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(14),
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 380), child: child),
    );

class TitleOverlay extends StatefulWidget {
  const TitleOverlay(this.game, {super.key});
  final WaffleGame game;

  @override
  State<TitleOverlay> createState() => _TitleOverlayState();
}

class _TitleOverlayState extends State<TitleOverlay> {
  bool _confirmReset = false;

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final p = game.progress;
    return _screen(PixelPanel(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('바삭 와플 가게', style: _t(30, bold: true)),
        const SizedBox(height: 4),
        Text('${p.stageDef.name} · ${p.day}일차 · ${p.money}원 · 별 ${p.stars}개', style: _t(12)),
        const SizedBox(height: 12),
        PixelPanel(
          color: Colors.white,
          padding: const EdgeInsets.all(10),
          child: Text(
            '1. 와플판을 눌러 반죽을 붓고\n   「지금!」일 때 꺼내면 퍼펙트\n'
            '2. 진열대의 토핑 칸을 눌러 토핑 올리기\n'
            '3. 손님을 눌러 주문한 와플 건네기\n'
            '퍼펙트를 이으면 콤보로 값이 올라요.\n'
            '번 돈으로 가게를 키우고 직원을 길러요.',
            style: _t(12),
          ),
        ),
        const SizedBox(height: 14),
        PixelButton('영업 시작', big: true, width: double.infinity, onTap: game.startDay),
        const SizedBox(height: 10),
        PixelButton(
          game.sfx.enabled ? '소리·진동 켜짐' : '소리·진동 꺼짐',
          color: game.sfx.enabled ? const Color(0xFF3E9B6B) : const Color(0xFF8A7B68),
          onTap: () => setState(() {
            game.sfx.enabled = !game.sfx.enabled;
            game.sfx.play('click');
            game.onSave();
          }),
        ),
        if (p.day > 1 || p.money > 0) ...[
          const SizedBox(height: 10),
          PixelButton(
            _confirmReset ? '정말 지울까요? 한 번 더 누르면 처음부터' : '처음부터 다시',
            color: const Color(0xFF8A7B68),
            onTap: () => setState(() {
              if (_confirmReset) game.resetAll();
              _confirmReset = !_confirmReset;
            }),
          ),
        ],
      ]),
    ));
  }
}

class DayEndOverlay extends StatefulWidget {
  const DayEndOverlay(this.game, {super.key});
  final WaffleGame game;

  @override
  State<DayEndOverlay> createState() => _DayEndOverlayState();
}

class _DayEndOverlayState extends State<DayEndOverlay> {
  int _tab = 0;
  bool _ready = false; // 영업이 끝난 직후의 연타로 다음 날이 바로 시작되지 않게 잠깐 막는다.

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _ready = true);
    });
  }

  void _do(bool Function() action) => setState(() {
        if (action()) {
          widget.game.sfx.play('buy');
          widget.game.onSave();
        }
      });

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final s = game.session!;
    final p = game.progress;
    return _screen(PixelPanel(
      padding: const EdgeInsets.all(12),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(s.success ? '${s.day}일차 목표 달성!' : '${s.day}일차 목표 미달',
            style: _t(22, color: s.success ? _green : const Color(0xFFC4302B), bold: true)),
        Text('★' * s.stars + '☆' * (3 - s.stars), style: _t(26, color: _gold, bold: true)),
        Text(
            '매출 ${s.earned}원 / 목표 ${s.goal}원'
            '${s.starBonus > 0 ? '  (별 보너스 +${s.starBonus}원)' : ''}',
            style: _t(12, bold: true)),
        Text('판매 ${s.served} · 놓침 ${s.lost} · 태움 ${s.burnt} · 퍼펙트 ${s.perfects} · 최고 콤보 ${s.bestCombo}',
            style: _t(11)),
        const SizedBox(height: 10),
        Row(children: [
          for (final (i, label) in ['업그레이드', '직원', '가게 확장'].indexed)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: i == 0 ? 0 : 6),
                child: PixelButton(label,
                    color: _tab == i ? _gold : const Color(0xFF8A7B68),
                    onTap: () => setState(() {
                      _tab = i;
                      game.sfx.play('click');
                    })),
              ),
            ),
        ]),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: Text('보유 ${p.money}원', style: _t(14, bold: true)),
        ),
        const SizedBox(height: 4),
        Flexible(
          child: SingleChildScrollView(
            child: Column(children: switch (_tab) {
              0 => [for (final id in upgradeDefs.keys) _upgradeRow(p, id)],
              1 => [for (final id in StaffId.values) _staffRow(p, id)],
              _ => _stageRows(p),
            }),
          ),
        ),
        const SizedBox(height: 12),
        PixelButton(s.success ? '${p.day}일차 영업 시작' : '${p.day}일차 다시 도전',
            big: true, width: double.infinity, onTap: _ready ? game.startDay : null),
      ]),
    ));
  }

  Widget _row({required String title, required String desc, required Widget action, double? progress}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: PixelPanel(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: _t(13, bold: true)),
                Text(desc, style: _t(11, color: const Color(0xFF6B5340))),
                if (progress != null)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    height: 6,
                    color: const Color(0xFFD9CFC0),
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(widthFactor: progress, child: Container(color: _green)),
                  ),
              ]),
            ),
            const SizedBox(width: 8),
            action,
          ]),
        ),
      );

  Widget _upgradeRow(Progress p, UpgradeId id) {
    final def = upgradeDefs[id]!;
    final block = p.blockReason(id);
    return _row(
      title: '${def.name}  Lv${p.level(id)}/${def.maxLevel}',
      desc: def.desc,
      action: PixelButton(block ?? '${p.costOf(id)}원',
          width: 96, color: _green, onTap: p.canBuy(id) ? () => _do(() => p.buy(id)) : null),
    );
  }

  Widget _staffRow(Progress p, StaffId id) {
    final def = staffDefs[id]!;
    final st = p.staff[id]!;
    if (!st.hired) {
      final locked = p.stage < def.minStage;
      return _row(
        title: '${def.name} · ${def.role}',
        desc: def.desc,
        action: PixelButton(locked ? '${def.minStage + 1}단계 필요' : '고용 ${def.hireCost}원',
            width: 96, color: _pink, onTap: p.canHire(id) ? () => _do(() => p.hire(id)) : null),
      );
    }
    final maxed = st.level >= staffMaxLevel;
    final value = p.staffValue(id).toStringAsFixed(1);
    return _row(
      title: '${def.name} · ${def.role}  Lv${st.level}/$staffMaxLevel',
      desc: id == StaffId.baker ? '구워진 뒤 $value초에 꺼내요' : '$value초마다 일해요',
      progress: st.levelProgress,
      action: PixelButton(maxed ? '최대' : '훈련 ${p.trainCostOf(id)}원',
          width: 96, color: _green, onTap: p.canTrain(id) ? () => _do(() => p.train(id)) : null),
    );
  }

  List<Widget> _stageRows(Progress p) => [
        for (final (i, def) in stageDefs.indexed)
          _row(
            title: '${i + 1}단계 · ${def.name}',
            desc: def.desc,
            action: PixelButton(
              i <= p.stage ? (i == p.stage ? '현재' : '완료') : (i == p.stage + 1 ? '${def.cost}원' : '잠김'),
              width: 96,
              color: _pink,
              onTap: i == p.stage + 1 && p.canExpand ? () => _do(p.expand) : null,
            ),
          ),
      ];
}

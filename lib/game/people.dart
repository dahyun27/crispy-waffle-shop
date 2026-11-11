/// 손님과 직원 도트 그림(32x40). 문자열로 찍는 대신 규칙으로 그려서
/// 머리 모양·옷·표정 조합을 자유롭게 만들고, 명암과 외곽선을 자동으로 넣는다.
library;

import 'dart:ui';

import 'config.dart';
import 'pixel.dart';

const _ink = Color(0xFF3A2416);
const _white = Color(0xFFFFFFFF);

enum Mood { happy, neutral, angry }

const personW = 32;
const personH = 40;

const _skins = [Color(0xFFFFDDBF), Color(0xFFF3C7A0), Color(0xFFD9A47C)];
const _hairs = [
  Color(0xFF4A3020), Color(0xFF2B2B38), Color(0xFFB5682E),
  Color(0xFFE2B84A), Color(0xFF8A4B6B), Color(0xFF7A8090),
];
const _shirts = [
  Color(0xFF5B8DEF), Color(0xFF58B77A), Color(0xFFEF7B5B), Color(0xFF9B6BDF),
  Color(0xFFE2B33C), Color(0xFF4FB8C4), Color(0xFFF08FB0),
];
const _caps = [Color(0xFFE5484D), Color(0xFF3E6FB8), Color(0xFF3E9B6B)];

/// 머리 모양: 0 짧은 머리, 1 단발, 2 모자, 3 양갈래 묶음, 4 긴 머리, 5 삐죽 머리
const hairStyleCount = 6;

class PersonLook {
  const PersonLook({
    required this.hairStyle,
    required this.skin,
    required this.hair,
    required this.shirt,
    this.cap = const Color(0xFFE5484D),
    this.shirtStyle = 0,
    this.glasses = false,
    this.chef = false,
  });

  /// 숫자 하나로 다양한 조합을 만든다(손님용).
  factory PersonLook.fromSeed(int seed) => PersonLook(
        hairStyle: seed % hairStyleCount,
        skin: _skins[(seed ~/ 3) % _skins.length],
        hair: _hairs[(seed ~/ 5) % _hairs.length],
        shirt: _shirts[(seed ~/ 13) % _shirts.length],
        cap: _caps[(seed ~/ 7) % _caps.length],
        shirtStyle: (seed ~/ 11) % 4,
        glasses: seed % 9 == 0,
      );

  final int hairStyle;
  final Color skin, hair, shirt, cap;
  final int shirtStyle; // 0 민무늬, 1 줄무늬, 2 주머니, 3 후드
  final bool glasses;
  final bool chef; // 조리 모자와 앞치마
}

Color _dark(Color c, [double t = 0.25]) => Color.lerp(c, const Color(0xFF2A1408), t)!;
Color _light(Color c, [double t = 0.3]) => Color.lerp(c, _white, t)!;

PixelSprite drawPerson(PersonLook look, Mood mood) {
  final g = PixelCanvas(personW, personH);
  final skin = look.skin, skinShade = _dark(look.skin, 0.16);
  final hair = look.hair, hairLight = _light(look.hair), hairDark = _dark(look.hair);
  final shirt = look.shirt, shirtLight = _light(look.shirt), shirtDark = _dark(look.shirt, 0.22);

  // 1) 뒷머리
  if (look.hairStyle == 1) g.rect(5, 12, 22, 15, hairDark);
  if (look.hairStyle == 4) g.rect(5, 12, 22, 21, hairDark);

  // 2) 몸
  const pants = Color(0xFF4A5670);
  g.rect(11, 36, 4, 3, pants);
  g.rect(17, 36, 4, 3, pants);
  g.rect(10, 39, 5, 1, _ink);
  g.rect(17, 39, 5, 1, _ink);
  g.rect(10, 26, 12, 1, shirt);
  g.rect(9, 27, 14, 10, shirt);
  g.rect(6, 27, 3, 4, shirt); // 소매
  g.rect(23, 27, 3, 4, shirt);
  g.rect(6, 31, 3, 4, skin); // 팔
  g.rect(23, 31, 3, 4, skin);
  g.rect(23, 34, 3, 1, skinShade);
  g.rect(6, 34, 3, 1, skinShade);
  g.rect(21, 27, 2, 10, shirtDark); // 오른쪽 그림자
  g.rect(9, 36, 14, 1, shirtDark);
  g.rect(9, 28, 1, 7, shirtDark); // 팔과 몸통 사이
  g.rect(22, 28, 1, 7, _dark(look.shirt, 0.4));
  g.rect(25, 27, 1, 4, shirtDark);
  g.rect(10, 27, 3, 1, shirtLight);
  g.rect(13, 25, 6, 1, skinShade); // 목
  g.rect(14, 26, 4, 1, skin);
  g.dot(13, 26, shirtLight);
  g.dot(18, 26, shirtLight);
  switch (look.shirtStyle) {
    case 1:
      g.rect(9, 30, 12, 1, shirtLight);
      g.rect(9, 33, 12, 1, shirtLight);
    case 2:
      g.rect(16, 30, 4, 3, shirtLight);
      g.rect(16, 30, 4, 1, _white);
    case 3:
      g.rect(14, 27, 1, 3, _white);
      g.rect(17, 27, 1, 3, _white);
      g.rect(12, 33, 8, 1, shirtDark);
      g.rect(12, 34, 1, 2, shirtDark);
      g.rect(19, 34, 1, 2, shirtDark);
  }
  if (look.chef) {
    const apron = Color(0xFFFFF8EC), apronShade = Color(0xFFDDD3C0);
    g.rect(11, 28, 10, 9, apron);
    g.rect(19, 28, 2, 9, apronShade);
    g.rect(11, 36, 10, 1, apronShade);
    g.rect(11, 26, 1, 2, apron);
    g.rect(20, 26, 1, 2, apron);
    g.rect(13, 32, 6, 1, apronShade);
    g.rect(13, 33, 1, 2, apronShade);
    g.rect(18, 33, 1, 2, apronShade);
  }

  // 3) 얼굴
  g.ellipse(15.5, 15, 10.5, 10, (dx, dy, d) => (dx > 0.62 || dy > 0.82) ? skinShade : skin);
  g.rect(4, 16, 1, 3, skin); // 귀
  g.rect(27, 16, 1, 3, skinShade);

  // 4) 앞머리
  final capped = look.hairStyle == 2 && !look.chef;
  g.ellipse(15.5, 14.2, 11.4, 10.8, (dx, dy, d) {
    final x = (15.5 + dx * 11.4).round(), y = (14.2 + dy * 10.8).round();
    final side = (x - 15.5).abs() > 8.5;
    var line = switch (look.hairStyle) {
      1 || 4 => 11 + ((x ~/ 2).isEven ? 1 : 0), // 가지런한 앞머리
      5 => 9 + (x % 3 == 0 ? 2 : 0),
      3 => 10 + ((x - 15.5).abs() < 2 ? -2 : 0), // 가운데 가르마
      _ => 10 + (x % 5 < 2 ? 1 : 0),
    };
    if (side) line = (look.hairStyle == 1 || look.hairStyle == 4) ? 40 : 15;
    if (y > line) return null;
    if (capped && y <= 10) return dx > 0.5 ? _dark(look.cap) : look.cap;
    if (dx > 0.6) return hairDark;
    return (y >= 5 && y <= 6 && x >= 8 && x <= 14) ? hairLight : hair;
  });
  if (capped) {
    g.rect(3, 10, 26, 2, _dark(look.cap, 0.35)); // 모자 챙
    g.rect(3, 10, 26, 1, look.cap);
    g.rect(13, 5, 5, 3, _light(look.cap, 0.5)); // 모자 무늬
  }
  if (look.hairStyle == 3) {
    for (final cx in [5.5, 25.5]) {
      g.ellipse(cx, 5.5, 3.8, 3.8, (dx, dy, d) => dx + dy < -0.5 ? hairLight : (dx > 0.4 ? hairDark : hair));
    }
    g.rect(8, 7, 2, 1, const Color(0xFFFF8FB8)); // 머리끈
    g.rect(22, 7, 2, 1, const Color(0xFFFF8FB8));
  }
  if (look.hairStyle == 5) {
    for (final x in [8, 12, 16, 20]) {
      g.rect(x, 3, 3, 1, hair);
      g.rect(x + 1, 2, 2, 1, hair);
      g.dot(x + 1, 1, hair);
    }
  }
  if (look.chef) {
    const hat = Color(0xFFFFFFFF), hatShade = Color(0xFFD5DAEA);
    g.ellipse(15.5, 5.5, 9.5, 4.6, (dx, dy, d) => (dx > 0.5 || dy > 0.6) ? hatShade : hat);
    g.rect(8, 8, 16, 4, hat);
    g.rect(21, 8, 3, 4, hatShade);
    g.rect(8, 11, 16, 1, hatShade);
    g.rect(12, 3, 1, 4, hatShade);
    g.rect(18, 3, 1, 4, hatShade);
  }

  // 5) 표정
  const mouth = Color(0xFF8A3B2E);
  for (final x in [10, 19]) {
    g.rect(x, 16, 2, 3, _ink);
    g.dot(x, 16, _white);
  }
  switch (mood) {
    case Mood.happy:
      g.dot(13, 21, mouth);
      g.dot(18, 21, mouth);
      g.rect(14, 22, 4, 1, mouth);
      g.rect(7, 20, 2, 1, const Color(0xFFFF9C9C));
      g.rect(22, 20, 2, 1, const Color(0xFFFF9C9C));
    case Mood.neutral:
      g.rect(14, 22, 4, 1, mouth);
    case Mood.angry:
      g.rect(14, 21, 4, 1, mouth);
      g.dot(13, 22, mouth);
      g.dot(18, 22, mouth);
      g.dot(9, 13, _ink); // 찌푸린 눈썹
      g.rect(10, 14, 2, 1, _ink);
      g.dot(22, 13, _ink);
      g.rect(19, 14, 2, 1, _ink);
      g.rect(24, 9, 1, 3, const Color(0xFFE5484D)); // 화남 표시
      g.rect(23, 10, 3, 1, const Color(0xFFE5484D));
  }
  if (look.glasses) {
    const frame = Color(0xFF3B4A6B);
    for (final x in [8, 17]) {
      g.rect(x, 15, 6, 1, frame);
      g.rect(x, 19, 6, 1, frame);
      g.rect(x, 15, 1, 5, frame);
      g.rect(x + 5, 15, 1, 5, frame);
    }
    g.rect(14, 16, 3, 1, frame);
  }

  g.outline(_ink);
  return g.toSprite();
}

final _customerCache = <int, PixelSprite>{};

/// 손님 그림. [look] 값으로 머리 모양과 색 조합이 정해진다.
PixelSprite customerSprite(int look, Mood mood) =>
    _customerCache[look * 3 + mood.index] ??= drawPerson(PersonLook.fromSeed(look), mood);

const staffLooks = {
  StaffId.baker: PersonLook(
      hairStyle: 0, skin: Color(0xFFFFDDBF), hair: Color(0xFFB5682E), shirt: Color(0xFFE9A93B), chef: true),
  StaffId.topper: PersonLook(
      hairStyle: 1, skin: Color(0xFFF3C7A0), hair: Color(0xFF8A4B6B), shirt: Color(0xFFE5486B), chef: true),
  StaffId.server: PersonLook(
      hairStyle: 0, skin: Color(0xFFD9A47C), hair: Color(0xFF2B2B38), shirt: Color(0xFF8A5A3C), chef: true, glasses: true),
};

final staffSprites = {
  for (final e in staffLooks.entries) e.key: drawPerson(e.value, Mood.happy),
};

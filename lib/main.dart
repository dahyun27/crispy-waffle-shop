/// 앱 시작점: 저장 데이터를 불러오고 게임과 겹침 화면(overlay)을 연결한다.
library;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game/progress.dart';
import 'game/sfx.dart';
import 'game/waffle_game.dart';
import 'ui/overlays.dart';

const _saveKey = 'crispy_waffle_save_v1';
const _soundKey = 'crispy_waffle_sound'; // 예전 설정(소리와 진동을 함께 켜고 끄던 값)
const _volumeKey = 'crispy_waffle_volume';
const _hapticsKey = 'crispy_waffle_haptics';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final prefs = await SharedPreferences.getInstance();
  final progress = Progress.decode(prefs.getString(_saveKey));
  // 예전에 '끔'으로 저장해 둔 사람은 새 설정에서도 꺼진 상태로 시작한다.
  final legacyOn = prefs.getBool(_soundKey) ?? true;
  final sfx = Sfx(
    volumeLevel: prefs.getInt(_volumeKey) ?? (legacyOn ? Sfx.defaultVolumeLevel : 0),
    haptics: prefs.getBool(_hapticsKey) ?? legacyOn,
  );
  sfx.preload();
  final game = WaffleGame(
    progress,
    sfx: sfx,
    onSave: () {
      prefs.setString(_saveKey, progress.encode());
      prefs.setInt(_volumeKey, sfx.volumeLevel);
      prefs.setBool(_hapticsKey, sfx.haptics);
    },
  );

  runApp(MaterialApp(
    title: '바삭 와플 가게',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(colorSchemeSeed: const Color(0xFFE9A93B), useMaterial3: true, fontFamily: 'Galmuri11'),
    home: Scaffold(
      backgroundColor: const Color(0xFF1E120A),
      body: SafeArea(
        child: GameWidget<WaffleGame>(
          game: game,
          initialActiveOverlays: const ['title'],
          overlayBuilderMap: {
            'title': (_, g) => TitleOverlay(g),
            'dayEnd': (_, g) => DayEndOverlay(g),
          },
        ),
      ),
    ),
  ));
}

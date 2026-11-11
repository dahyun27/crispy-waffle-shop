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
const _soundKey = 'crispy_waffle_sound';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final prefs = await SharedPreferences.getInstance();
  final progress = Progress.decode(prefs.getString(_saveKey));
  final sfx = Sfx(enabled: prefs.getBool(_soundKey) ?? true);
  sfx.preload();
  final game = WaffleGame(
    progress,
    sfx: sfx,
    onSave: () {
      prefs.setString(_saveKey, progress.encode());
      prefs.setBool(_soundKey, sfx.enabled);
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

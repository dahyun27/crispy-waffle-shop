# 바삭 와플 가게

Flutter + Flame으로 만든 오리지널 와플 가게 운영 타이쿤 (iOS / Android / Web).
그림은 모두 코드로 그린 도트 그림이며, 글꼴은 Galmuri11(OFL 라이선스, `assets/fonts/OFL.md`)을 씁니다.

## 실행

```bash
flutter pub get
flutter run                      # 연결된 기기/시뮬레이터
flutter run -d chrome            # 브라우저
flutter test                     # 규칙 테스트
dart run tool/balance_sim.dart   # 밸런스 시뮬레이션(가상 플레이어 3명이 40일 플레이)
```

## 구조

| 파일 | 역할 |
| --- | --- |
| `lib/main.dart` | 앱 시작, 저장 데이터 로드, 화면 연결 |
| `lib/game/config.dart` | 가격·시간·업그레이드·가게 단계·직원·날씨 등 모든 밸런스 수치 |
| `lib/game/progress.dart` | 돈·날짜·단계·업그레이드·직원(저장되는 데이터) |
| `lib/game/session.dart` | 하루 영업 규칙(굽기·토핑·판매·손님·이벤트·직원 행동) |
| `lib/game/layout.dart` | 화면 배치 좌표 |
| `lib/game/pixel.dart` | 도트 그림 엔진 |
| `lib/game/sprites.dart` | 도트 그림 데이터(손님·직원·와플·아이콘) |
| `lib/game/painter.dart` | 배경·손님·진열대·와플판 등 화면 그리기 |
| `lib/game/waffle_game.dart` | Flame 게임 루프와 터치 처리, 조각·흔들림 연출 |
| `lib/game/sfx.dart` | 효과음과 진동 |
| `lib/ui/overlays.dart` | 시작 화면, 정산·상점 화면 |
| `test/session_test.dart` | 규칙 테스트 |
| `tool/balance_sim.dart` | 밸런스 시뮬레이션 |
| `tool/gen_sfx.py` | 효과음 합성기(`assets/audio` 생성) |
| `tool/dump_waffles_test.dart` | 와플 도트 그림 미리보기 |

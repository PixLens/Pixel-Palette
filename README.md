# PixelLens

Flutter로 만든 픽셀 아트 드로잉 앱입니다. 그리드 기반 캔버스에서 픽셀 단위로 그림을 그리고, 내보낼 수 있습니다.

---

## 주요 기능

- 픽셀 그리드 캔버스 (8×8 ~ 64×64)
- 색상 팔레트 및 커스텀 색상 선택
- 펜 / 지우개 / 페인트 버킷 / 스포이드 도구
- 실행 취소(Undo) / 다시 실행(Redo)
- PNG로 내보내기
- 작업 자동 저장

---

## 요구 사항

| 항목                      | 버전           |
| ------------------------- | -------------- |
| Flutter SDK               | 3.22 이상      |
| Dart SDK                  | 3.4 이상       |
| Android Studio 또는 Xcode | 최신 안정 버전 |
| CocoaPods (macOS/iOS)     | 1.14 이상      |

---

## 의존성 설치

### 1. Flutter SDK 설치

```bash
# Homebrew로 설치 (macOS)
brew install --cask flutter

# 설치 확인
flutter doctor
```

> `flutter doctor` 출력에서 체크되지 않은 항목이 있으면 안내에 따라 해결하세요.

### 2. 프로젝트 클론 및 패키지 설치

```bash
git clone <repository-url>
cd PixelLens

# pub 패키지 설치
flutter pub get
```

### 3. iOS 의존성 설치 (macOS만 해당)

```bash
cd ios
pod install
cd ..
```

### 4. 앱 실행

```bash
# 연결된 기기 확인
flutter devices

# 플랫폼 별 파일 생성하기
flutter create . --platforms=macos

# 실행 (기기 선택)
flutter run

# 특정 기기로 실행
flutter run -d <device-id>
```

---

## pubspec.yaml 의존성 목록

```yaml
dependencies:
  flutter:
    sdk: flutter

  # 색상 선택기
  flutter_colorpicker: ^1.1.0

  # 이미지 저장 및 갤러리 공유
  image_gallery_saver: ^2.0.3
  permission_handler: ^11.3.1

  # 파일 공유 (내보내기)
  share_plus: ^9.0.0

  # 로컬 저장소 (자동 저장)
  shared_preferences: ^2.2.3

  # PNG 인코딩
  image: ^4.2.0
```

패키지 추가 후 반드시 `flutter pub get`을 실행하세요.

---

## 프로젝트 구조

```
lib/
├── main.dart                  # 앱 진입점
├── app.dart                   # MaterialApp 설정
├── models/
│   ├── canvas_model.dart      # 픽셀 데이터 및 캔버스 상태
│   └── tool_model.dart        # 현재 선택 도구 상태
├── screens/
│   └── editor_screen.dart     # 메인 에디터 화면
├── widgets/
│   ├── pixel_canvas.dart      # 그리드 캔버스 위젯
│   ├── tool_bar.dart          # 도구 선택 바
│   ├── color_palette.dart     # 색상 팔레트
│   └── canvas_size_dialog.dart# 캔버스 크기 설정 다이얼로그
└── utils/
    ├── export_helper.dart     # PNG 내보내기
    └── fill_algorithm.dart    # 페인트 버킷 알고리즘
```

---

## 지원 플랫폼

- Android 6.0 (API 23) 이상
- iOS 13.0 이상
- macOS (데스크탑)

---

## 라이선스

MIT License

---

## Flutter 코딩 패턴

### 1. 상태 관리

| 패턴     | 사용량 | 특징                 |
| -------- | ------ | -------------------- |
| Riverpod | ★★★★★  | 현재 사실상 표준     |
| Bloc     | ★★★★☆  | 대규모 기업 프로젝트 |
| Provider | ★★★☆☆  | 구형 프로젝트        |
| GetX     | ★★☆☆☆  | 호불호 강함          |
| MobX     | ★☆☆☆☆  | 거의 안 씀           |

```
Flutter
 └─ Riverpod
     └─ StateNotifier / AsyncNotifier
```

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Install dependencies
flutter pub get

# Run on connected device/emulator
flutter run

# Run in release mode
flutter run --release

# Build Android APK
flutter build apk

# Run tests
flutter test

# Run a single test file
flutter test test/widget_test.dart

# Lint / analyze
flutter analyze
```

## Architecture

This is a Flutter voice expense tracker app (`voice_expense_app`) that records audio, transcribes it via a local on-device Whisper model (C++/JNI), and parses the transcript for expense entries.

### Data Flow

1. User taps Record → `AudioController` calls `AudioService` → records 16kHz mono WAV to app Documents dir
2. User taps Stop → `AudioController` calls `NativeService.transcribe(modelPath, audioPath)` via MethodChannel `"whisper"`
3. Native Android (Kotlin/JNI) invokes `native-lib.cpp` which runs Whisper inference on the WAV file
4. Transcript returned to Dart → `ExpenseParser.parse()` uses regex to extract expense entries
5. Parsed expenses and transcript surface in `HomeScreen` via `ListenableBuilder` on `AudioController`

### Key Layers

- **`lib/ui/`** — Single screen (`HomeScreen`, StatefulWidget). Observes `AudioController` via `ListenableBuilder`.
- **`lib/features/audio/`** — `AudioController` (ChangeNotifier, coordinates state) + `AudioService` (record package wrapper).
- **`lib/features/stt/`** — `NativeService`: thin Dart wrapper around MethodChannel `"whisper"` (methods: `transcribe`, `test`).
- **`lib/features/expenses/`** — `Expense` model + `ExpenseParser` (regex: detects "spent/paid/cost/bought $X on Y" patterns).
- **`lib/features/model/`** — `ModelService`: downloads the ~148 MB Whisper GGML model from HuggingFace on first launch, stored in Documents dir.

### Native (Android-only)

- **`android/app/src/main/kotlin/.../MainActivity.kt`** — registers MethodChannel, dispatches to `WhisperBridge`
- **`android/app/src/main/kotlin/.../WhisperBridge.kt`** — JNI bridge to C++
- **`android/app/src/main/cpp/native-lib.cpp`** — loads GGML model, runs `whisper_full()`, returns transcript string
- **`android/app/src/main/cpp/CMakeLists.txt`** — builds `native-lib` and links `whisper.cpp` + `ggml`
- NDK version: `28.2.13676358`, configured in `build.gradle.kts`

iOS, macOS, Linux, Windows, and Web targets exist but have no Whisper native bridge — transcription is Android-only.

### Whisper Model

- Downloaded from HuggingFace (`ggml-base.en.bin`, English-only, ~148 MB)
- Stored in the app's Documents directory on first launch
- English-only inference (`language = "en"` in C++ code)

### Key Dependencies (pubspec.yaml)

| Package | Purpose |
|---|---|
| `record ^6.2.0` | Audio capture (16kHz mono WAV) |
| `path_provider ^2.1.2` | Resolves Documents directory |
| `permission_handler ^11.3.0` | Microphone permission |
| `dio ^5.4.1` | HTTP download of Whisper model |

### Tests

The `test/widget_test.dart` is a placeholder smoke test (checks for a counter widget that no longer exists). Tests need to be updated to reflect actual `HomeScreen` behavior.

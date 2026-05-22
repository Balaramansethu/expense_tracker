import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_recognition_error.dart';

class SpeechService {
  final SpeechToText _stt = SpeechToText();
  bool _isInitialized = false;

  bool get isAvailable => _isInitialized;
  bool get isListening => _stt.isListening;

  /// Initialize speech recognition. Returns true if available.
  /// [onError] receives error messages from the speech engine.
  /// [onStatus] receives status changes ("listening", "notListening", "done").
  Future<bool> initialize({
    void Function(String error)? onError,
    void Function(String status)? onStatus,
  }) async {
    if (_isInitialized) return true;

    try {
      _isInitialized = await _stt.initialize(
        onError: (SpeechRecognitionError error) {
          onError?.call(error.errorMsg);
        },
        onStatus: (String status) {
          onStatus?.call(status);
        },
      );
    } catch (e) {
      _isInitialized = false;
    }

    return _isInitialized;
  }

  /// Force re-initialization (e.g. after permission grant or engine recovery).
  Future<bool> reinitialize({
    void Function(String error)? onError,
    void Function(String status)? onStatus,
  }) async {
    _isInitialized = false;
    return initialize(onError: onError, onStatus: onStatus);
  }

  /// Start listening for speech input.
  /// Returns true if listening started successfully, false otherwise.
  Future<bool> startListening({
    required void Function(String text, bool isFinal) onResult,
    void Function(String error)? onError,
  }) async {
    if (!_isInitialized) {
      onError?.call('Speech recognition not initialized');
      return false;
    }

    try {
      await _stt.listen(
        onResult: (SpeechRecognitionResult result) {
          try {
            onResult(result.recognizedWords, result.finalResult);
          } catch (e) {
            // Callback error — don't let it crash the speech engine
            onError?.call('Error processing result: $e');
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.dictation,
          onDevice: true,
          partialResults: true,
        ),
      );
      return true;
    } catch (e) {
      onError?.call('Failed to start listening: $e');
      return false;
    }
  }

  /// Stop listening gracefully. Safe to call even when not listening.
  Future<void> stopListening() async {
    if (!_stt.isListening) return;
    try {
      await _stt.stop();
    } catch (_) {
      // Swallow — best-effort stop
    }
  }

  /// Cancel listening. Safe to call even when not listening.
  Future<void> cancelListening() async {
    try {
      await _stt.cancel();
    } catch (_) {
      // Swallow — best-effort cancel
    }
  }
}

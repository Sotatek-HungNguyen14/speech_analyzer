import 'speech_analyzer_platform_interface.dart';

export 'speech_analyzer_platform_interface.dart'
    show
        SpeechRecognitionWords,
        SpeechRecognitionResult,
        SpeechRecognitionError,
        SpeechAnalyzerStatus,
        OnTextRecognition,
        OnStatusChange,
        OnError,
        OnSoundLevelChange;

/// Main class for Live Translation plugin
///
/// This plugin provides real-time speech-to-text functionality using Apple's latest
/// SpeechAnalyzer API (iOS 18+) with on-device processing for privacy and performance.
class SpeechAnalyzer {
  static final SpeechAnalyzerPlatform _platform =
      SpeechAnalyzerPlatform.instance;

  // State management
  static bool _isListening = false;
  static bool _isInitialized = false;

  /// Check if the plugin has necessary permissions (microphone only)
  ///
  /// Returns true if microphone permission is granted.
  /// Note: Speech recognition permission is not required for the new API.
  static Future<bool> hasPermission() {
    return _platform.hasPermission();
  }

  /// Initialize the speech analyzer
  ///
  /// This must be called before using any other speech recognition features.
  /// It will request microphone permission if not already granted.
  ///
  /// Returns true if initialization was successful.
  static Future<bool> initialize() async {
    final result = await _platform.initialize();
    _isInitialized = result;
    return result;
  }

  /// Start listening for speech
  ///
  /// [localeId] - Optional locale identifier (e.g., 'en-US', 'vi-VN')
  /// [partialResults] - Whether to receive partial (non-final) results
  ///
  /// Returns true if listening started successfully.
  static Future<bool> startListening({
    String? localeId,
    bool partialResults = true,
  }) async {
    if (!_isInitialized) {
      throw StateError(
          'SpeechAnalyzer must be initialized before use. Call initialize() first.');
    }

    if (_isListening) {
      return false; // Already listening
    }

    final result = await _platform.listen(
      localeId: localeId,
      partialResults: partialResults,
    );

    if (result) {
      _isListening = true;
    }

    return result;
  }

  /// Stop listening for speech
  ///
  /// This will finish the current recognition session and return final results.
  /// Returns true if stopping was successful.
  static Future<bool> stopListening() async {
    if (!_isListening) {
      return false; // Not listening
    }

    final result = await _platform.stop();

    if (result) {
      _isListening = false;
    }

    return result;
  }

  /// Cancel listening for speech
  ///
  /// This will immediately cancel the current recognition session without
  /// waiting for final results.
  /// Returns true if cancellation was successful.
  static Future<bool> cancelListening() async {
    if (!_isListening) {
      return false; // Not listening
    }

    final result = await _platform.cancel();

    if (result) {
      _isListening = false;
    }

    return result;
  }

  /// Get list of supported locales
  ///
  /// Returns a list of locale identifiers in "localeId:localeName" format.
  /// Example: ["en-US:English (United States)", "vi-VN:Vietnamese (Vietnam)"]
  static Future<List<String>> getSupportedLocales() {
    return _platform.getLocales();
  }

  /// Get parsed locale information
  ///
  /// Returns a map of locale ID to display name for easier use.
  static Future<Map<String, String>> getLocalesMap() async {
    final locales = await getSupportedLocales();
    final Map<String, String> localesMap = {};

    for (final locale in locales) {
      final parts = locale.split(':');
      if (parts.length == 2) {
        localesMap[parts[0]] = parts[1];
      }
    }

    return localesMap;
  }

  /// Set callbacks for speech recognition events
  ///
  /// [onTextRecognition] - Called when text is recognized (partial or final)
  /// [onStatusChange] - Called when recognition status changes
  /// [onError] - Called when an error occurs
  /// [onSoundLevelChange] - Called when microphone sound level changes
  static void setCallbacks({
    OnTextRecognition? onTextRecognition,
    OnStatusChange? onStatusChange,
    OnError? onError,
    OnSoundLevelChange? onSoundLevelChange,
  }) {
    _platform.setCallbacks(
      onTextRecognition: onTextRecognition,
      onStatusChange: (status) {
        // Update internal state based on status
        switch (status) {
          case SpeechAnalyzerStatus.listening:
            _isListening = true;
            break;
          case SpeechAnalyzerStatus.done:
          case SpeechAnalyzerStatus.doneNoResult:
          case SpeechAnalyzerStatus.notListening:
            _isListening = false;
            break;
          default:
            break;
        }
        onStatusChange?.call(status);
      },
      onError: onError,
      onSoundLevelChange: onSoundLevelChange,
    );
  }

  /// Remove all callbacks
  static void removeCallbacks() {
    _platform.removeCallbacks();
  }

  /// Check if currently listening
  static bool get isListening => _isListening;

  /// Check if initialized
  static bool get isInitialized => _isInitialized;

  // Convenience methods

  /// Quick start with default settings
  ///
  /// This is a convenience method that initializes the plugin and starts
  /// listening with default settings if not already done.
  ///
  /// [locale] - Optional locale, defaults to system locale
  /// [onResult] - Callback for final text recognition results
  /// [onPartialResult] - Optional callback for partial results
  /// [onError] - Optional error callback
  static Future<bool> quickStart({
    String? locale,
    required OnTextRecognition onResult,
    OnTextRecognition? onPartialResult,
    OnError? onError,
  }) async {
    // Set up callbacks
    setCallbacks(
      onTextRecognition: (result) {
        if (result.isFinal) {
          onResult(result);
        } else {
          onPartialResult?.call(result);
        }
      },
      onError: onError,
    );

    // Initialize if needed
    if (!_isInitialized) {
      final initResult = await initialize();
      if (!initResult) {
        return false;
      }
    }

    // Start listening
    return await startListening(
      localeId: locale,
      partialResults: onPartialResult != null,
    );
  }

  /// Get the current text from a recognition result
  ///
  /// Returns final text if the result is final, otherwise volatile text.
  static String getResultText(SpeechRecognitionResult result) {
    return result.isFinal ? result.finalResult : result.volatileResult;
  }

  /// Get the confidence score from a recognition result
  ///
  /// Returns 1.0 for the new SpeechAnalyzer API (confidence always high).
  static double getResultConfidence(SpeechRecognitionResult result) {
    return 1.0; // New API provides high-confidence results
  }
}

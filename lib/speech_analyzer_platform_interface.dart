import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'speech_analyzer_method_channel.dart';

/// Data models for Speech Analyzer

/// Represents a speech recognition result with confidence score
class SpeechRecognitionWords {
  final String recognizedWords;
  final double confidence;

  const SpeechRecognitionWords({
    required this.recognizedWords,
    required this.confidence,
  });

  factory SpeechRecognitionWords.fromJson(Map<String, dynamic> json) {
    return SpeechRecognitionWords(
      recognizedWords: json['recognizedWords'] as String,
      confidence: (json['confidence'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'recognizedWords': recognizedWords,
      'confidence': confidence,
    };
  }
}

/// Represents the complete speech recognition result
class SpeechRecognitionResult {
  final String finalResult;
  final String volatileResult;
  final bool isFinal;

  const SpeechRecognitionResult({
    required this.finalResult,
    required this.volatileResult,
    required this.isFinal,
  });

  factory SpeechRecognitionResult.fromJson(Map<String, dynamic> json) {
    return SpeechRecognitionResult(
      finalResult: json['finalResult'] as String,
      volatileResult: json['volatileResult'] as String,
      isFinal: json['isFinal'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'finalResult': finalResult,
      'volatileResult': volatileResult,
      'isFinal': isFinal,
    };
  }

  // Legacy compatibility methods
  @Deprecated('Use finalResult and volatileResult directly')
  List<SpeechRecognitionWords> get alternates {
    final text = isFinal ? finalResult : volatileResult;
    if (text.isEmpty) return [];

    return [
      SpeechRecognitionWords(
        recognizedWords: text,
        confidence: 1.0, // Default confidence for new API
      )
    ];
  }

  @Deprecated('Use isFinal instead')
  bool get isFinalized => isFinal;
}

/// Represents a speech recognition error
class SpeechRecognitionError {
  final String errorMsg;
  final bool permanent;

  const SpeechRecognitionError({
    required this.errorMsg,
    required this.permanent,
  });

  factory SpeechRecognitionError.fromJson(Map<String, dynamic> json) {
    return SpeechRecognitionError(
      errorMsg: json['errorMsg'] as String,
      permanent: json['permanent'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'errorMsg': errorMsg,
      'permanent': permanent,
    };
  }
}

/// Enum for Live Translation status
enum SpeechAnalyzerStatus {
  listening,
  notListening,
  unavailable,
  available,
  done,
  doneNoResult;

  static SpeechAnalyzerStatus fromString(String value) {
    switch (value) {
      case 'listening':
        return SpeechAnalyzerStatus.listening;
      case 'notListening':
        return SpeechAnalyzerStatus.notListening;
      case 'unavailable':
        return SpeechAnalyzerStatus.unavailable;
      case 'available':
        return SpeechAnalyzerStatus.available;
      case 'done':
        return SpeechAnalyzerStatus.done;
      case 'doneNoResult':
        return SpeechAnalyzerStatus.doneNoResult;
      default:
        return SpeechAnalyzerStatus.unavailable;
    }
  }
}

/// Callback types for Live Translation events
typedef OnTextRecognition = void Function(SpeechRecognitionResult result);
typedef OnStatusChange = void Function(SpeechAnalyzerStatus status);
typedef OnError = void Function(SpeechRecognitionError error);
typedef OnSoundLevelChange = void Function(double level);

/// Platform interface for Speech Analyzer plugin
abstract class SpeechAnalyzerPlatform extends PlatformInterface {
  /// Constructs a SpeechAnalyzerPlatform.
  SpeechAnalyzerPlatform() : super(token: _token);

  static final Object _token = Object();

  static SpeechAnalyzerPlatform _instance = MethodChannelSpeechAnalyzer();

  /// The default instance of [SpeechAnalyzerPlatform] to use.
  ///
  /// Defaults to [MethodChannelSpeechAnalyzer].
  static SpeechAnalyzerPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [SpeechAnalyzerPlatform] when
  /// they register themselves.
  static set instance(SpeechAnalyzerPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Check if the plugin has necessary permissions
  Future<bool> hasPermission() {
    throw UnimplementedError('hasPermission() has not been implemented.');
  }

  /// Initialize the speech analyzer
  Future<bool> initialize() {
    throw UnimplementedError('initialize() has not been implemented.');
  }

  /// Start listening for speech with optional locale and partial results
  Future<bool> listen({
    String? localeId,
    bool partialResults = true,
  }) {
    throw UnimplementedError('listen() has not been implemented.');
  }

  /// Stop listening for speech
  Future<bool> stop() {
    throw UnimplementedError('stop() has not been implemented.');
  }

  /// Cancel listening for speech
  Future<bool> cancel() {
    throw UnimplementedError('cancel() has not been implemented.');
  }

  /// Get list of supported locales
  Future<List<String>> getLocales() {
    throw UnimplementedError('getLocales() has not been implemented.');
  }

  /// Set callbacks for speech recognition events
  void setCallbacks({
    OnTextRecognition? onTextRecognition,
    OnStatusChange? onStatusChange,
    OnError? onError,
    OnSoundLevelChange? onSoundLevelChange,
  }) {
    throw UnimplementedError('setCallbacks() has not been implemented.');
  }

  /// Remove all callbacks
  void removeCallbacks() {
    throw UnimplementedError('removeCallbacks() has not been implemented.');
  }
}

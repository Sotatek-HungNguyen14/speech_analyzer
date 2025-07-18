import 'package:flutter_test/flutter_test.dart';
import 'package:speech_analyzer/speech_analyzer.dart';
import 'package:speech_analyzer/speech_analyzer_platform_interface.dart';
import 'package:speech_analyzer/speech_analyzer_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockSpeechAnalyzerPlatform
    with MockPlatformInterfaceMixin
    implements SpeechAnalyzerPlatform {
  bool _hasPermission = true;
  bool _isInitialized = false;
  bool _isListening = false;
  final List<String> _supportedLocales = [
    'en-US:English (United States)',
    'en-GB:English (United Kingdom)',
    'vi-VN:Vietnamese (Vietnam)',
    'fr-FR:French (France)',
  ];

  // Callback storage
  OnTextRecognition? _onTextRecognition;
  OnStatusChange? _onStatusChange;
  OnError? _onError;
  OnSoundLevelChange? _onSoundLevelChange;

  Future<String?> getPlatformVersion() => Future.value('42');

  @override
  Future<bool> hasPermission() async {
    return _hasPermission;
  }

  @override
  Future<bool> initialize() async {
    if (_hasPermission) {
      _isInitialized = true;
      return true;
    }
    return false;
  }

  @override
  Future<bool> listen({String? localeId, bool partialResults = true}) async {
    if (!_isInitialized) return false;
    _isListening = true;
    _onStatusChange?.call(SpeechAnalyzerStatus.listening);
    return true;
  }

  @override
  Future<bool> stop() async {
    if (!_isListening) return false;
    _isListening = false;
    _onStatusChange?.call(SpeechAnalyzerStatus.done);
    return true;
  }

  @override
  Future<bool> cancel() async {
    if (!_isListening) return false;
    _isListening = false;
    _onStatusChange?.call(SpeechAnalyzerStatus.notListening);
    return true;
  }

  @override
  Future<List<String>> getLocales() async {
    return _supportedLocales;
  }

  @override
  void setCallbacks({
    OnTextRecognition? onTextRecognition,
    OnStatusChange? onStatusChange,
    OnError? onError,
    OnSoundLevelChange? onSoundLevelChange,
  }) {
    _onTextRecognition = onTextRecognition;
    _onStatusChange = onStatusChange;
    _onError = onError;
    _onSoundLevelChange = onSoundLevelChange;
  }

  @override
  void removeCallbacks() {
    _onTextRecognition = null;
    _onStatusChange = null;
    _onError = null;
    _onSoundLevelChange = null;
  }

  // Test helper methods
  void simulatePermissionDenied() {
    _hasPermission = false;
  }

  void simulateError(String message, bool permanent) {
    _onError?.call(SpeechRecognitionError(
      errorMsg: message,
      permanent: permanent,
    ));
  }

  void simulateTextRecognition(String text, bool isFinal) {
    _onTextRecognition?.call(SpeechRecognitionResult(
      finalResult: isFinal ? text : '',
      volatileResult: !isFinal ? text : '',
      isFinal: isFinal,
    ));
  }

  void simulateSoundLevel(double level) {
    _onSoundLevelChange?.call(level);
  }
}

void main() {
  late MockSpeechAnalyzerPlatform mockPlatform;

  setUp(() {
    mockPlatform = MockSpeechAnalyzerPlatform();
    SpeechAnalyzerPlatform.instance = mockPlatform;
  });

  group('Platform Instance Tests', () {
    test('MethodChannelSpeechAnalyzer is the default instance', () {
      final SpeechAnalyzerPlatform initialPlatform =
          SpeechAnalyzerPlatform.instance;
      // Reset to default for this test
      SpeechAnalyzerPlatform.instance = MethodChannelSpeechAnalyzer();
      expect(SpeechAnalyzerPlatform.instance,
          isInstanceOf<MethodChannelSpeechAnalyzer>());
      // Restore mock for other tests
      SpeechAnalyzerPlatform.instance = initialPlatform;
    });
  });

  group('Permission Tests', () {
    test('hasPermission returns true when permission granted', () async {
      final result = await SpeechAnalyzer.hasPermission();
      expect(result, isTrue);
    });

    test('hasPermission returns false when permission denied', () async {
      mockPlatform.simulatePermissionDenied();
      final result = await SpeechAnalyzer.hasPermission();
      expect(result, isFalse);
    });
  });

  group('Initialization Tests', () {
    test('initialize succeeds with permission', () async {
      final result = await SpeechAnalyzer.initialize();
      expect(result, isTrue);
      expect(SpeechAnalyzer.isInitialized, isTrue);
    });

    test('initialize fails without permission', () async {
      mockPlatform.simulatePermissionDenied();
      final result = await SpeechAnalyzer.initialize();
      expect(result, isFalse);
      expect(SpeechAnalyzer.isInitialized, isFalse);
    });
  });

  group('Listening Control Tests', () {
    setUp(() async {
      await SpeechAnalyzer.initialize();
    });

    test('startListening succeeds after initialization', () async {
      final result = await SpeechAnalyzer.startListening();
      expect(result, isTrue);
      expect(SpeechAnalyzer.isListening, isTrue);
    });

    test('startListening with locale and partial results', () async {
      final result = await SpeechAnalyzer.startListening(
        localeId: 'en-US',
        partialResults: true,
      );
      expect(result, isTrue);
      expect(SpeechAnalyzer.isListening, isTrue);
    });

    test('startListening fails when not initialized', () async {
      // Create a fresh instance without initialization
      SpeechAnalyzerPlatform.instance = MockSpeechAnalyzerPlatform();

      expect(
        () async => await SpeechAnalyzer.startListening(),
        throwsA(isA<StateError>()),
      );
    });

    test('startListening returns false when already listening', () async {
      await SpeechAnalyzer.startListening();
      final result = await SpeechAnalyzer.startListening();
      expect(result, isFalse);
    });

    test('stopListening succeeds when listening', () async {
      await SpeechAnalyzer.startListening();
      final result = await SpeechAnalyzer.stopListening();
      expect(result, isTrue);
      expect(SpeechAnalyzer.isListening, isFalse);
    });

    test('stopListening returns false when not listening', () async {
      final result = await SpeechAnalyzer.stopListening();
      expect(result, isFalse);
    });

    test('cancelListening succeeds when listening', () async {
      await SpeechAnalyzer.startListening();
      final result = await SpeechAnalyzer.cancelListening();
      expect(result, isTrue);
      expect(SpeechAnalyzer.isListening, isFalse);
    });

    test('cancelListening returns false when not listening', () async {
      final result = await SpeechAnalyzer.cancelListening();
      expect(result, isFalse);
    });
  });

  group('Locale Tests', () {
    test('getSupportedLocales returns list of locales', () async {
      final locales = await SpeechAnalyzer.getSupportedLocales();
      expect(locales, isA<List<String>>());
      expect(locales.length, greaterThan(0));
      expect(locales.first, contains(':'));
    });

    test('getLocalesMap returns properly parsed map', () async {
      final localesMap = await SpeechAnalyzer.getLocalesMap();
      expect(localesMap, isA<Map<String, String>>());
      expect(localesMap['en-US'], equals('English (United States)'));
      expect(localesMap['vi-VN'], equals('Vietnamese (Vietnam)'));
    });
  });

  group('Callback Tests', () {
    bool textRecognitionCalled = false;
    // ignore: unused_local_variable
    bool statusChangeCalled = false;
    bool errorCalled = false;
    bool soundLevelCalled = false;

    setUp(() {
      textRecognitionCalled = false;
      statusChangeCalled = false;
      errorCalled = false;
      soundLevelCalled = false;
    });

    test('setCallbacks registers callbacks correctly', () async {
      SpeechAnalyzer.setCallbacks(
        onTextRecognition: (result) => textRecognitionCalled = true,
        onStatusChange: (status) => statusChangeCalled = true,
        onError: (error) => errorCalled = true,
        onSoundLevelChange: (level) => soundLevelCalled = true,
      );

      // Simulate callbacks
      mockPlatform.simulateTextRecognition('test', false);
      mockPlatform.simulateError('test error', false);
      mockPlatform.simulateSoundLevel(0.5);

      expect(textRecognitionCalled, isTrue);
      expect(errorCalled, isTrue);
      expect(soundLevelCalled, isTrue);
    });

    test('removeCallbacks clears all callbacks', () {
      SpeechAnalyzer.setCallbacks(
        onTextRecognition: (result) => textRecognitionCalled = true,
        onStatusChange: (status) => statusChangeCalled = true,
        onError: (error) => errorCalled = true,
        onSoundLevelChange: (level) => soundLevelCalled = true,
      );

      SpeechAnalyzer.removeCallbacks();

      // Simulate callbacks after removal
      mockPlatform.simulateTextRecognition('test', false);
      mockPlatform.simulateError('test error', false);
      mockPlatform.simulateSoundLevel(0.5);

      expect(textRecognitionCalled, isFalse);
      expect(errorCalled, isFalse);
      expect(soundLevelCalled, isFalse);
    });
  });

  group('Convenience Methods Tests', () {
    test('quickStart initializes and starts listening', () async {
      // Reset to uninitialized state
      SpeechAnalyzerPlatform.instance = MockSpeechAnalyzerPlatform();

      // ignore: unused_local_variable
      bool resultReceived = false;
      // ignore: unused_local_variable
      bool partialReceived = false;
      // ignore: unused_local_variable
      bool errorReceived = false;

      final result = await SpeechAnalyzer.quickStart(
        locale: 'en-US',
        onResult: (result) => resultReceived = true,
        onPartialResult: (result) => partialReceived = true,
        onError: (error) => errorReceived = true,
      );

      expect(result, isTrue);
      expect(SpeechAnalyzer.isInitialized, isTrue);
      expect(SpeechAnalyzer.isListening, isTrue);
    });

    test('getResultText returns correct text', () {
      const finalResult = SpeechRecognitionResult(
        finalResult: 'final text',
        volatileResult: 'volatile text',
        isFinal: true,
      );

      const partialResult = SpeechRecognitionResult(
        finalResult: 'final text',
        volatileResult: 'volatile text',
        isFinal: false,
      );

      expect(SpeechAnalyzer.getResultText(finalResult), equals('final text'));
      expect(
          SpeechAnalyzer.getResultText(partialResult), equals('volatile text'));
    });

    test('getResultConfidence always returns 1.0', () {
      const result = SpeechRecognitionResult(
        finalResult: 'test',
        volatileResult: 'test',
        isFinal: true,
      );

      expect(SpeechAnalyzer.getResultConfidence(result), equals(1.0));
    });
  });

  group('Platform Interface Test', () {
    test('getPlatformVersion from platform interface', () async {
      MockSpeechAnalyzerPlatform fakePlatform = MockSpeechAnalyzerPlatform();
      SpeechAnalyzerPlatform.instance = fakePlatform;

      expect(await fakePlatform.getPlatformVersion(), '42');
    });
  });
}

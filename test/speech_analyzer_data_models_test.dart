import 'package:flutter_test/flutter_test.dart';
import 'package:speech_analyzer/speech_analyzer_platform_interface.dart';

void main() {
  group('SpeechRecognitionWords Tests', () {
    test('constructor creates instance with correct properties', () {
      const words = SpeechRecognitionWords(
        recognizedWords: 'hello world',
        confidence: 0.95,
      );

      expect(words.recognizedWords, equals('hello world'));
      expect(words.confidence, equals(0.95));
    });

    test('fromJson creates instance from JSON map', () {
      final json = {
        'recognizedWords': 'test phrase',
        'confidence': 0.85,
      };

      final words = SpeechRecognitionWords.fromJson(json);

      expect(words.recognizedWords, equals('test phrase'));
      expect(words.confidence, equals(0.85));
    });

    test('fromJson handles different numeric types for confidence', () {
      final jsonInt = {
        'recognizedWords': 'test',
        'confidence': 1, // int
      };

      final jsonDouble = {
        'recognizedWords': 'test',
        'confidence': 0.75, // double
      };

      final wordsFromInt = SpeechRecognitionWords.fromJson(jsonInt);
      final wordsFromDouble = SpeechRecognitionWords.fromJson(jsonDouble);

      expect(wordsFromInt.confidence, equals(1.0));
      expect(wordsFromDouble.confidence, equals(0.75));
    });

    test('toJson creates correct JSON map', () {
      const words = SpeechRecognitionWords(
        recognizedWords: 'testing',
        confidence: 0.90,
      );

      final json = words.toJson();

      expect(json['recognizedWords'], equals('testing'));
      expect(json['confidence'], equals(0.90));
    });
  });

  group('SpeechRecognitionResult Tests', () {
    test('constructor creates instance with correct properties', () {
      const result = SpeechRecognitionResult(
        finalResult: 'final text',
        volatileResult: 'partial text',
        isFinal: true,
      );

      expect(result.finalResult, equals('final text'));
      expect(result.volatileResult, equals('partial text'));
      expect(result.isFinal, isTrue);
    });

    test('fromJson creates instance from JSON map', () {
      final json = {
        'finalResult': 'complete sentence',
        'volatileResult': 'incomplete',
        'isFinal': false,
      };

      final result = SpeechRecognitionResult.fromJson(json);

      expect(result.finalResult, equals('complete sentence'));
      expect(result.volatileResult, equals('incomplete'));
      expect(result.isFinal, isFalse);
    });

    test('toJson creates correct JSON map', () {
      const result = SpeechRecognitionResult(
        finalResult: 'done',
        volatileResult: 'processing',
        isFinal: true,
      );

      final json = result.toJson();

      expect(json['finalResult'], equals('done'));
      expect(json['volatileResult'], equals('processing'));
      expect(json['isFinal'], isTrue);
    });

    group('Legacy Compatibility', () {
      test('alternates returns correct SpeechRecognitionWords for final result',
          () {
        const result = SpeechRecognitionResult(
          finalResult: 'hello world',
          volatileResult: 'hello',
          isFinal: true,
        );

        // ignore: deprecated_member_use_from_same_package
        final alternates = result.alternates;

        expect(alternates, hasLength(1));
        expect(alternates.first.recognizedWords, equals('hello world'));
        expect(alternates.first.confidence, equals(1.0));
      });

      test(
          'alternates returns correct SpeechRecognitionWords for partial result',
          () {
        const result = SpeechRecognitionResult(
          finalResult: 'hello world',
          volatileResult: 'hello',
          isFinal: false,
        );

        // ignore: deprecated_member_use_from_same_package
        final alternates = result.alternates;

        expect(alternates, hasLength(1));
        expect(alternates.first.recognizedWords, equals('hello'));
        expect(alternates.first.confidence, equals(1.0));
      });

      test('alternates returns empty list for empty text', () {
        const result = SpeechRecognitionResult(
          finalResult: '',
          volatileResult: '',
          isFinal: true,
        );

        // ignore: deprecated_member_use_from_same_package
        final alternates = result.alternates;

        expect(alternates, isEmpty);
      });

      test('isFinalized returns correct value', () {
        const finalResult = SpeechRecognitionResult(
          finalResult: 'test',
          volatileResult: 'test',
          isFinal: true,
        );

        const partialResult = SpeechRecognitionResult(
          finalResult: 'test',
          volatileResult: 'test',
          isFinal: false,
        );

        // ignore: deprecated_member_use_from_same_package
        expect(finalResult.isFinalized, isTrue);
        // ignore: deprecated_member_use_from_same_package
        expect(partialResult.isFinalized, isFalse);
      });
    });
  });

  group('SpeechRecognitionError Tests', () {
    test('constructor creates instance with correct properties', () {
      const error = SpeechRecognitionError(
        errorMsg: 'Permission denied',
        permanent: true,
      );

      expect(error.errorMsg, equals('Permission denied'));
      expect(error.permanent, isTrue);
    });

    test('fromJson creates instance from JSON map', () {
      final json = {
        'errorMsg': 'Network error',
        'permanent': false,
      };

      final error = SpeechRecognitionError.fromJson(json);

      expect(error.errorMsg, equals('Network error'));
      expect(error.permanent, isFalse);
    });

    test('toJson creates correct JSON map', () {
      const error = SpeechRecognitionError(
        errorMsg: 'Audio error',
        permanent: true,
      );

      final json = error.toJson();

      expect(json['errorMsg'], equals('Audio error'));
      expect(json['permanent'], isTrue);
    });
  });

  group('SpeechAnalyzerStatus Tests', () {
    test('fromString returns correct status for valid strings', () {
      expect(
        SpeechAnalyzerStatus.fromString('listening'),
        equals(SpeechAnalyzerStatus.listening),
      );
      expect(
        SpeechAnalyzerStatus.fromString('notListening'),
        equals(SpeechAnalyzerStatus.notListening),
      );
      expect(
        SpeechAnalyzerStatus.fromString('unavailable'),
        equals(SpeechAnalyzerStatus.unavailable),
      );
      expect(
        SpeechAnalyzerStatus.fromString('available'),
        equals(SpeechAnalyzerStatus.available),
      );
      expect(
        SpeechAnalyzerStatus.fromString('done'),
        equals(SpeechAnalyzerStatus.done),
      );
      expect(
        SpeechAnalyzerStatus.fromString('doneNoResult'),
        equals(SpeechAnalyzerStatus.doneNoResult),
      );
    });

    test('fromString returns unavailable for invalid strings', () {
      expect(
        SpeechAnalyzerStatus.fromString('invalid'),
        equals(SpeechAnalyzerStatus.unavailable),
      );
      expect(
        SpeechAnalyzerStatus.fromString(''),
        equals(SpeechAnalyzerStatus.unavailable),
      );
      expect(
        SpeechAnalyzerStatus.fromString('unknown'),
        equals(SpeechAnalyzerStatus.unavailable),
      );
    });

    test('enum values are correctly defined', () {
      expect(SpeechAnalyzerStatus.values, hasLength(6));
      expect(SpeechAnalyzerStatus.values,
          contains(SpeechAnalyzerStatus.listening));
      expect(SpeechAnalyzerStatus.values,
          contains(SpeechAnalyzerStatus.notListening));
      expect(SpeechAnalyzerStatus.values,
          contains(SpeechAnalyzerStatus.unavailable));
      expect(SpeechAnalyzerStatus.values,
          contains(SpeechAnalyzerStatus.available));
      expect(SpeechAnalyzerStatus.values, contains(SpeechAnalyzerStatus.done));
      expect(SpeechAnalyzerStatus.values,
          contains(SpeechAnalyzerStatus.doneNoResult));
    });
  });

  group('Callback Types Tests', () {
    test('OnTextRecognition callback type works correctly', () {
      bool callbackInvoked = false;
      const result = SpeechRecognitionResult(
        finalResult: 'test',
        volatileResult: 'test',
        isFinal: true,
      );

      callback(SpeechRecognitionResult result) {
        callbackInvoked = true;
        expect(result.finalResult, equals('test'));
      }

      callback(result);
      expect(callbackInvoked, isTrue);
    });

    test('OnStatusChange callback type works correctly', () {
      bool callbackInvoked = false;
      SpeechAnalyzerStatus? receivedStatus;

      callback(SpeechAnalyzerStatus status) {
        callbackInvoked = true;
        receivedStatus = status;
      }

      callback(SpeechAnalyzerStatus.listening);
      expect(callbackInvoked, isTrue);
      expect(receivedStatus, equals(SpeechAnalyzerStatus.listening));
    });

    test('OnError callback type works correctly', () {
      bool callbackInvoked = false;
      const error = SpeechRecognitionError(
        errorMsg: 'test error',
        permanent: false,
      );

      callback(SpeechRecognitionError error) {
        callbackInvoked = true;
        expect(error.errorMsg, equals('test error'));
      }

      callback(error);
      expect(callbackInvoked, isTrue);
    });

    test('OnSoundLevelChange callback type works correctly', () {
      bool callbackInvoked = false;
      double? receivedLevel;

      callback(double level) {
        callbackInvoked = true;
        receivedLevel = level;
      }

      callback(0.75);
      expect(callbackInvoked, isTrue);
      expect(receivedLevel, equals(0.75));
    });
  });
}

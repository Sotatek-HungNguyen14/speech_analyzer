import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speech_analyzer/speech_analyzer_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelSpeechAnalyzer platform = MethodChannelSpeechAnalyzer();
  const MethodChannel channel = MethodChannel('speech_analyzer');

  // Test response storage
  Map<String, dynamic> methodCallResponses = {};
  List<MethodCall> recordedMethodCalls = [];

  setUp(() {
    recordedMethodCalls.clear();
    methodCallResponses.clear();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        recordedMethodCalls.add(methodCall);

        // Return predefined responses based on method name
        if (methodCallResponses.containsKey(methodCall.method)) {
          return methodCallResponses[methodCall.method];
        }

        // Default responses for each method
        switch (methodCall.method) {
          case 'has_permission':
            return true;
          case 'initialize':
            return true;
          case 'listen':
            return true;
          case 'stop':
            return true;
          case 'cancel':
            return true;
          case 'locales':
            return [
              'en-US:English (United States)',
              'en-GB:English (United Kingdom)',
              'vi-VN:Vietnamese (Vietnam)',
            ];
          default:
            return null;
        }
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('Basic Platform Methods', () {
    test('hasPermission calls correct method', () async {
      final result = await platform.hasPermission();
      expect(result, isTrue);
      expect(recordedMethodCalls.last.method, equals('has_permission'));
    });

    test('hasPermission handles false response', () async {
      methodCallResponses['has_permission'] = false;
      final result = await platform.hasPermission();
      expect(result, isFalse);
    });

    test('initialize calls correct method', () async {
      final result = await platform.initialize();
      expect(result, isTrue);
      expect(recordedMethodCalls.last.method, equals('initialize'));
    });

    test('initialize handles false response', () async {
      methodCallResponses['initialize'] = false;
      final result = await platform.initialize();
      expect(result, isFalse);
    });
  });

  group('Listening Control Methods', () {
    test('listen calls correct method with default parameters', () async {
      final result = await platform.listen();
      expect(result, isTrue);

      final methodCall = recordedMethodCalls.last;
      expect(methodCall.method, equals('listen'));
      expect(methodCall.arguments['localeId'], isNull);
      expect(methodCall.arguments['partialResults'], isTrue);
    });

    test('listen calls correct method with custom parameters', () async {
      final result = await platform.listen(
        localeId: 'en-US',
        partialResults: false,
      );
      expect(result, isTrue);

      final methodCall = recordedMethodCalls.last;
      expect(methodCall.method, equals('listen'));
      expect(methodCall.arguments['localeId'], equals('en-US'));
      expect(methodCall.arguments['partialResults'], isFalse);
    });

    test('listen handles false response', () async {
      methodCallResponses['listen'] = false;
      final result = await platform.listen();
      expect(result, isFalse);
    });

    test('stop calls correct method', () async {
      final result = await platform.stop();
      expect(result, isTrue);
      expect(recordedMethodCalls.last.method, equals('stop'));
    });

    test('stop handles false response', () async {
      methodCallResponses['stop'] = false;
      final result = await platform.stop();
      expect(result, isFalse);
    });

    test('cancel calls correct method', () async {
      final result = await platform.cancel();
      expect(result, isTrue);
      expect(recordedMethodCalls.last.method, equals('cancel'));
    });

    test('cancel handles false response', () async {
      methodCallResponses['cancel'] = false;
      final result = await platform.cancel();
      expect(result, isFalse);
    });
  });

  group('Locale Methods', () {
    test('getLocales returns list of locales', () async {
      final result = await platform.getLocales();
      expect(result, isA<List<String>>());
      expect(result.length, equals(3));
      expect(result.first, equals('en-US:English (United States)'));
      expect(recordedMethodCalls.last.method, equals('locales'));
    });

    test('getLocales handles empty response', () async {
      methodCallResponses['locales'] = <String>[];
      final result = await platform.getLocales();
      expect(result, isEmpty);
    });

    test('getLocales handles null response', () async {
      methodCallResponses['locales'] = null;
      final result = await platform.getLocales();
      expect(result, isEmpty);
    });
  });

  group('Callback Management', () {
    test('setCallbacks does not throw', () {
      expect(() {
        platform.setCallbacks(
          onTextRecognition: (result) {},
          onStatusChange: (status) {},
          onError: (error) {},
          onSoundLevelChange: (level) {},
        );
      }, returnsNormally);
    });

    test('setCallbacks with null callbacks does not throw', () {
      expect(() {
        platform.setCallbacks();
      }, returnsNormally);
    });

    test('setCallbacks with partial callbacks does not throw', () {
      expect(() {
        platform.setCallbacks(
          onTextRecognition: (result) {},
          onError: (error) {},
        );
      }, returnsNormally);
    });

    test('removeCallbacks does not throw', () {
      expect(() {
        platform.removeCallbacks();
      }, returnsNormally);
    });
  });

  group('Error Handling', () {
    test('handles PlatformException correctly', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        channel,
        (MethodCall methodCall) async {
          throw PlatformException(
            code: 'PERMISSION_DENIED',
            message: 'Microphone permission denied',
            details: null,
          );
        },
      );

      expect(
        () async => await platform.hasPermission(),
        throwsA(isA<PlatformException>()),
      );
    });

    test('handles method not implemented correctly', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        channel,
        (MethodCall methodCall) async {
          throw MissingPluginException('No implementation found');
        },
      );

      expect(
        () async => await platform.hasPermission(),
        throwsA(isA<MissingPluginException>()),
      );
    });

        test('handles unexpected response types gracefully', () async {
      methodCallResponses['has_permission'] = 'unexpected_string';
      
      // Should handle type conversion gracefully
      expect(
        () async => await platform.hasPermission(),
        throwsA(isA<TypeError>()),
      );
    });
  });

  group('Method Call Arguments Validation', () {
    test('listen method passes null locale correctly', () async {
      await platform.listen(localeId: null);

      final methodCall = recordedMethodCalls.last;
      expect(methodCall.arguments['localeId'], isNull);
    });

    test('listen method passes empty locale string correctly', () async {
      await platform.listen(localeId: '');

      final methodCall = recordedMethodCalls.last;
      expect(methodCall.arguments['localeId'], equals(''));
    });

    test('listen method validates partialResults parameter', () async {
      await platform.listen(partialResults: false);

      final methodCall = recordedMethodCalls.last;
      expect(methodCall.arguments['partialResults'], isFalse);
    });
  });

  group('Multiple Method Calls', () {
    test('multiple hasPermission calls work correctly', () async {
      await platform.hasPermission();
      await platform.hasPermission();
      await platform.hasPermission();

      expect(recordedMethodCalls.length, equals(3));
      expect(
          recordedMethodCalls.every((call) => call.method == 'hasPermission'),
          isTrue);
    });

    test('sequence of calls works correctly', () async {
      await platform.hasPermission();
      await platform.initialize();
      await platform.listen();
      await platform.stop();

      expect(recordedMethodCalls.length, equals(4));
      expect(recordedMethodCalls[0].method, equals('hasPermission'));
      expect(recordedMethodCalls[1].method, equals('initialize'));
      expect(recordedMethodCalls[2].method, equals('listen'));
      expect(recordedMethodCalls[3].method, equals('stop'));
    });
  });

  group('Response Type Validation', () {
    test('boolean methods handle various true responses', () async {
      // Test different representations of true
      methodCallResponses['hasPermission'] = true;
      expect(await platform.hasPermission(), isTrue);

      methodCallResponses['hasPermission'] = 1;
      expect(() async => await platform.hasPermission(),
          throwsA(isA<TypeError>()));
    });

    test('list methods handle various response types', () async {
      // Test proper list response
      methodCallResponses['getLocales'] = ['en-US:English'];
      final result1 = await platform.getLocales();
      expect(result1, equals(['en-US:English']));

      // Test null response
      methodCallResponses['getLocales'] = null;
      final result2 = await platform.getLocales();
      expect(result2, isEmpty);
    });
  });
}

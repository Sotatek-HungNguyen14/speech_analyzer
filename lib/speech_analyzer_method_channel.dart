import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'speech_analyzer_platform_interface.dart';

/// An implementation of [SpeechAnalyzerPlatform] that uses method channels.
class MethodChannelSpeechAnalyzer extends SpeechAnalyzerPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel =
      const MethodChannel('plugin.SpeechAnalyzer.com/speech_analyzer');

  // Callback storage
  OnTextRecognition? _onTextRecognition;
  OnStatusChange? _onStatusChange;
  OnError? _onError;
  OnSoundLevelChange? _onSoundLevelChange;

  bool _callbacksInitialized = false;

  /// Initialize callbacks if not already done
  void _initializeCallbacks() {
    if (_callbacksInitialized) return;

    methodChannel.setMethodCallHandler(_handleMethodCall);
    _callbacksInitialized = true;
  }

  /// Handle method calls from native platform
  Future<void> _handleMethodCall(MethodCall call) async {
    try {
      switch (call.method) {
        case 'textRecognition':
          if (_onTextRecognition != null && call.arguments != null) {
            final jsonString = call.arguments as String;
            final jsonData = json.decode(jsonString) as Map<String, dynamic>;
            final result = SpeechRecognitionResult.fromJson(jsonData);
            _onTextRecognition!(result);
          }
          break;

        case 'notifyStatus':
          if (_onStatusChange != null && call.arguments != null) {
            final statusString = call.arguments as String;
            final status = SpeechAnalyzerStatus.fromString(statusString);
            _onStatusChange!(status);
          }
          break;

        case 'notifyError':
          if (_onError != null && call.arguments != null) {
            final jsonString = call.arguments as String;
            final jsonData = json.decode(jsonString) as Map<String, dynamic>;
            final error = SpeechRecognitionError.fromJson(jsonData);
            _onError!(error);
          }
          break;

        case 'soundLevelChange':
          if (_onSoundLevelChange != null && call.arguments != null) {
            final level = (call.arguments as num).toDouble();
            _onSoundLevelChange!(level);
          }
          break;

        default:
          if (kDebugMode) {
            print('Unknown method call: ${call.method}');
          }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error handling method call ${call.method}: $e');
      }
    }
  }

  @override
  Future<bool> hasPermission() async {
    try {
      final result = await methodChannel.invokeMethod<bool>('has_permission');
      return result ?? false;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking permission: $e');
      }
      return false;
    }
  }

  @override
  Future<bool> initialize() async {
    try {
      _initializeCallbacks();
      final result = await methodChannel.invokeMethod<bool>('initialize');
      return result ?? false;
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing: $e');
      }
      return false;
    }
  }

  @override
  Future<bool> listen({
    String? localeId,
    bool partialResults = true,
  }) async {
    try {
      final arguments = <String, dynamic>{
        'partialResults': partialResults,
      };

      if (localeId != null) {
        arguments['localeId'] = localeId;
      }

      final result =
          await methodChannel.invokeMethod<bool>('listen', arguments);
      return result ?? false;
    } catch (e) {
      if (kDebugMode) {
        print('Error starting to listen: $e');
      }
      return false;
    }
  }

  @override
  Future<bool> stop() async {
    try {
      final result = await methodChannel.invokeMethod<bool>('stop');
      return result ?? false;
    } catch (e) {
      if (kDebugMode) {
        print('Error stopping: $e');
      }
      return false;
    }
  }

  @override
  Future<bool> cancel() async {
    try {
      final result = await methodChannel.invokeMethod<bool>('cancel');
      return result ?? false;
    } catch (e) {
      if (kDebugMode) {
        print('Error canceling: $e');
      }
      return false;
    }
  }

  @override
  Future<List<String>> getLocales() async {
    try {
      final result = await methodChannel.invokeMethod<List<dynamic>>('locales');
      return result?.cast<String>() ?? [];
    } catch (e) {
      if (kDebugMode) {
        print('Error getting locales: $e');
      }
      return [];
    }
  }

  @override
  void setCallbacks({
    OnTextRecognition? onTextRecognition,
    OnStatusChange? onStatusChange,
    OnError? onError,
    OnSoundLevelChange? onSoundLevelChange,
  }) {
    _initializeCallbacks();

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
}

import 'package:flutter_test/flutter_test.dart';
import 'package:speech_analyzer/speech_analyzer.dart';
import 'package:speech_analyzer/speech_analyzer_platform_interface.dart';
import 'package:speech_analyzer/speech_analyzer_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockSpeechAnalyzerPlatform
    with MockPlatformInterfaceMixin
    implements SpeechAnalyzerPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final SpeechAnalyzerPlatform initialPlatform = SpeechAnalyzerPlatform.instance;

  test('$MethodChannelSpeechAnalyzer is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelSpeechAnalyzer>());
  });

  test('getPlatformVersion', () async {
    SpeechAnalyzer speechAnalyzerPlugin = SpeechAnalyzer();
    MockSpeechAnalyzerPlatform fakePlatform = MockSpeechAnalyzerPlatform();
    SpeechAnalyzerPlatform.instance = fakePlatform;

    expect(await speechAnalyzerPlugin.getPlatformVersion(), '42');
  });
}

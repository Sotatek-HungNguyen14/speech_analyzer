#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint speech_analyzer.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'speech_analyzer'
  s.version          = '0.0.1'
  s.summary          = 'A Flutter plugin for speech transcription using iOS SpeechAnalyzer (iOS 26+) with fallback to Speech framework.'
  s.description      = <<-DESC
A Flutter plugin that provides live speech transcription capabilities using iOS 26+ SpeechAnalyzer framework with fallback to Speech framework for older iOS versions.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Nguyen Thanh Hung' => 'hung10220002@gmail.com' }

  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES'}
  s.swift_version = '5.0'
  s.ios.deployment_target = '13.0'
  s.frameworks = 'Speech', 'AVFoundation'
end

#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint speech_analyzer.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'speech_analyzer'
  s.version          = '0.0.1'
  s.summary          = 'A Flutter plugin for live speech transcription using iOS 26+ SpeechAnalyzer.'
  s.description      = <<-DESC
A Flutter plugin that provides live speech transcription and file transcription capabilities using iOS 26+ SpeechAnalyzer framework.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '16.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # Require iOS 26+ for SpeechAnalyzer framework
  s.ios.deployment_target = '16.0'
  
  # Add required frameworks for SpeechAnalyzer
  s.frameworks = 'SpeechAnalyzer', 'AVFoundation', 'Speech'
  
  # Add frameworks required for SpeechAnalyzer
  s.frameworks = ['AVFoundation', 'Speech']

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'speech_analyzer_privacy' => ['Resources/PrivacyInfo.xcprivacy']}
end

# Speech Analyzer

[![pub package](https://img.shields.io/pub/v/speech_analyzer.svg)](https://pub.dev/packages/speech_analyzer)

Speech recognition for Flutter using Apple's latest SpeechAnalyzer API (iOS 18+). This plugin provides real-time speech-to-text functionality with on-device processing for enhanced privacy and performance.

## Features

- **Real-time speech recognition**: Get live transcription as you speak
- **On-device processing**: Enhanced privacy with local speech recognition
- **Multiple language support**: Support for various locales and languages
- **Partial results**: Receive intermediate results while speaking
- **Sound level monitoring**: Get microphone input level feedback
- **Simple API**: Easy-to-use interface with comprehensive callbacks
- **iOS 18+ optimized**: Uses Apple's latest SpeechAnalyzer framework

## Platform Support

| Platform | Supported        |
| -------- | ---------------- |
| iOS      | ✅ (iOS 18+)     |
| Android  | ❌ (Coming soon) |
| Web      | ❌               |
| macOS    | ❌               |
| Windows  | ❌               |
| Linux    | ❌               |

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  speech_analyzer: ^0.0.1
```

Run the following command:

```bash
flutter pub get
```

## Permissions

### iOS

Add the following to your `ios/Runner/Info.plist`:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>This app needs access to microphone for speech recognition</string>
```

**Note**: Unlike traditional speech recognition, the new SpeechAnalyzer API only requires microphone permission. Speech recognition permission is no longer needed.

## Quick Start

Here's a simple example to get you started:

```dart
import 'package:flutter/material.dart';
import 'package:speech_analyzer/speech_analyzer.dart';

class SpeechDemo extends StatefulWidget {
  @override
  _SpeechDemoState createState() => _SpeechDemoState();
}

class _SpeechDemoState extends State<SpeechDemo> {
  String _recognizedText = '';
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _initializeSpeech();
  }

  void _initializeSpeech() async {
    bool available = await SpeechAnalyzer.initialize();
    if (available) {
      SpeechAnalyzer.setCallbacks(
        onTextRecognition: (result) {
          setState(() {
            _recognizedText = SpeechAnalyzer.getResultText(result);
          });
        },
        onStatusChange: (status) {
          setState(() {
            _isListening = status == SpeechAnalyzerStatus.listening;
          });
        },
        onError: (error) {
          print('Speech recognition error: ${error.errorMsg}');
        },
      );
    }
  }

  void _toggleListening() async {
    if (!_isListening) {
      await SpeechAnalyzer.startListening();
    } else {
      await SpeechAnalyzer.stopListening();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Speech Analyzer Demo')),
      body: Column(
        children: [
          Expanded(
            child: Container(
              padding: EdgeInsets.all(16),
              child: Text(
                _recognizedText.isEmpty
                  ? 'Tap the microphone to start listening...'
                  : _recognizedText,
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
          FloatingActionButton(
            onPressed: _toggleListening,
            backgroundColor: _isListening ? Colors.red : Colors.blue,
            child: Icon(_isListening ? Icons.mic : Icons.mic_none),
          ),
          SizedBox(height: 20),
        ],
      ),
    );
  }
}
```

## API Reference

### Core Methods

#### `initialize()`

Initialize the speech analyzer. Must be called before using any other methods.

```dart
bool initialized = await SpeechAnalyzer.initialize();
```

#### `hasPermission()`

Check if microphone permission is granted.

```dart
bool hasPermission = await SpeechAnalyzer.hasPermission();
```

#### `startListening()`

Start listening for speech with optional parameters.

```dart
bool started = await SpeechAnalyzer.startListening(
  localeId: 'en-US',        // Optional: specify language
  partialResults: true,     // Optional: receive partial results
);
```

#### `stopListening()`

Stop listening and get final results.

```dart
bool stopped = await SpeechAnalyzer.stopListening();
```

#### `cancelListening()`

Cancel listening without waiting for results.

```dart
bool cancelled = await SpeechAnalyzer.cancelListening();
```

### Locales and Languages

#### `getSupportedLocales()`

Get list of supported locales.

```dart
List<String> locales = await SpeechAnalyzer.getSupportedLocales();
// Returns: ["en-US:English (United States)", "vi-VN:Vietnamese (Vietnam)", ...]
```

#### `getLocalesMap()`

Get locales as a map for easier usage.

```dart
Map<String, String> localesMap = await SpeechAnalyzer.getLocalesMap();
// Returns: {"en-US": "English (United States)", "vi-VN": "Vietnamese (Vietnam)", ...}
```

### Callbacks

Set up callbacks to handle speech recognition events:

```dart
SpeechAnalyzer.setCallbacks(
  onTextRecognition: (SpeechRecognitionResult result) {
    String text = SpeechAnalyzer.getResultText(result);
    bool isFinal = result.isFinal;
    // Handle recognized text
  },
  onStatusChange: (SpeechAnalyzerStatus status) {
    // Handle status changes
    switch (status) {
      case SpeechAnalyzerStatus.listening:
        print('Listening...');
        break;
      case SpeechAnalyzerStatus.done:
        print('Recognition completed');
        break;
      // ... handle other statuses
    }
  },
  onError: (SpeechRecognitionError error) {
    print('Error: ${error.errorMsg}');
    bool isPermanent = error.permanent;
  },
  onSoundLevelChange: (double level) {
    // Handle microphone sound level (0.0 to 1.0)
    print('Sound level: $level');
  },
);
```

### Convenience Methods

#### `quickStart()`

Quick setup with minimal configuration:

```dart
bool started = await SpeechAnalyzer.quickStart(
  locale: 'en-US',
  onResult: (result) {
    print('Final result: ${SpeechAnalyzer.getResultText(result)}');
  },
  onPartialResult: (result) {
    print('Partial: ${SpeechAnalyzer.getResultText(result)}');
  },
  onError: (error) {
    print('Error: ${error.errorMsg}');
  },
);
```

### State Properties

```dart
bool isListening = SpeechAnalyzer.isListening;
bool isInitialized = SpeechAnalyzer.isInitialized;
```

## Data Models

### `SpeechRecognitionResult`

```dart
class SpeechRecognitionResult {
  final String finalResult;      // Final transcribed text
  final String volatileResult;   // Partial/interim text
  final bool isFinal;           // Whether this is a final result
}
```

### `SpeechRecognitionError`

```dart
class SpeechRecognitionError {
  final String errorMsg;    // Error description
  final bool permanent;     // Whether error is permanent
}
```

### `SpeechAnalyzerStatus`

```dart
enum SpeechAnalyzerStatus {
  listening,      // Currently listening for speech
  notListening,   // Not listening
  unavailable,    // Speech recognition unavailable
  available,      // Ready to start
  done,          // Recognition completed with results
  doneNoResult   // Recognition completed without results
}
```

## Advanced Usage

### Language Selection

```dart
// Get available languages
Map<String, String> locales = await SpeechAnalyzer.getLocalesMap();

// Let user select language
String selectedLocale = 'vi-VN'; // Vietnamese

// Start listening with selected language
await SpeechAnalyzer.startListening(localeId: selectedLocale);
```

### Handling Errors

```dart
SpeechAnalyzer.setCallbacks(
  onError: (error) {
    if (error.permanent) {
      // Handle permanent errors (e.g., no permission)
      print('Permanent error: ${error.errorMsg}');
      // Maybe show settings dialog
    } else {
      // Handle temporary errors (e.g., network issues)
      print('Temporary error: ${error.errorMsg}');
      // Maybe retry
    }
  },
);
```

### Sound Level Monitoring

Create a visual microphone indicator:

```dart
double _soundLevel = 0.0;

SpeechAnalyzer.setCallbacks(
  onSoundLevelChange: (level) {
    setState(() {
      _soundLevel = level;
    });
  },
);

// In your widget build method:
Container(
  width: 200,
  height: 20,
  child: LinearProgressIndicator(
    value: _soundLevel,
    backgroundColor: Colors.grey[300],
    valueColor: AlwaysStoppedAnimation<Color>(
      _soundLevel > 0.5 ? Colors.red : Colors.green
    ),
  ),
)
```

## Requirements

- **iOS**: 18.0 or later
- **Flutter**: 3.3.0 or later
- **Dart**: 3.6.2 or later

## Privacy

This plugin uses on-device speech recognition, which means:

- ✅ Speech data stays on the device
- ✅ No internet connection required for recognition
- ✅ Enhanced privacy and security
- ✅ Faster response times
- ✅ Works offline

## Troubleshooting

### Common Issues

**Q: Speech recognition is not working**

- Ensure you're running on iOS 18+ device/simulator
- Check microphone permissions in device settings
- Verify `NSMicrophoneUsageDescription` is in Info.plist

**Q: No partial results**

- Make sure `partialResults: true` is set in `startListening()`
- Check that your callback is set up correctly

**Q: Recognition stops unexpectedly**

- Check error callbacks for error messages
- Verify device has sufficient resources
- Ensure app is in foreground (background recognition may be limited)

### Performance Tips

- Call `initialize()` early in your app lifecycle
- Reuse the same SpeechAnalyzer instance
- Remove callbacks when not needed to prevent memory leaks
- Use appropriate locale for better accuracy

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for a detailed list of changes.

## Support

If you have any questions or issues, please [open an issue](https://github.com/your-repo/speech_analyzer/issues) on GitHub.

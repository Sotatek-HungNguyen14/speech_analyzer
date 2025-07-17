import 'package:flutter/material.dart';
import 'package:speech_analyzer/speech_analyzer.dart';
import 'dart:math' as math;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Live Translation Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const LiveTranslationDemo(),
    );
  }
}

class LiveTranslationDemo extends StatefulWidget {
  const LiveTranslationDemo({super.key});

  @override
  State<LiveTranslationDemo> createState() => _LiveTranslationDemoState();
}

class _LiveTranslationDemoState extends State<LiveTranslationDemo>
    with TickerProviderStateMixin {
  // State variables
  bool _isInitialized = false;
  bool _hasPermission = false;
  String _selectedLocale = 'en-US';
  Map<String, String> _availableLocales = {};

  // Transcript data
  String _currentTranscript = '';
  String _finalTranscript = '';
  double _confidence = 0.0;
  bool _isListening = false;
  SpeechAnalyzerStatus _status = SpeechAnalyzerStatus.notListening;

  // Sound level
  double _soundLevel = -160.0; // Start with silence

  // Error handling
  String? _errorMessage;

  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _soundController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _soundAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializePlugin();
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _soundController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _soundAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _soundController, curve: Curves.easeOut),
    );
  }

  Future<void> _initializePlugin() async {
    setState(() {
      _errorMessage = null;
    });

    try {
      // Check permissions
      final hasPermission = await SpeechAnalyzer.hasPermission();
      setState(() {
        _hasPermission = hasPermission;
      });

      // Initialize plugin
      final initialized = await SpeechAnalyzer.initialize();
      setState(() {
        _isInitialized = initialized;
      });

      if (initialized) {
        // Get supported locales
        await _loadSupportedLocales();

        // Setup callbacks
        _setupCallbacks();

        _showSnackBar('Plugin initialized successfully!', Colors.green);
      } else {
        _showSnackBar('Failed to initialize plugin', Colors.red);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Initialization error: $e';
      });
      _showSnackBar('Error: $e', Colors.red);
    }
  }

  Future<void> _loadSupportedLocales() async {
    try {
      final localesMap = await SpeechAnalyzer.getLocalesMap();
      setState(() {
        _availableLocales = localesMap;

        // Priority order for default locale selection:
        // 1. Keep current selection if available
        // 2. Fallback to en-US if current not available but en-US exists
        // 3. Fallback to first available locale
        if (!_availableLocales.containsKey(_selectedLocale) &&
            _availableLocales.isNotEmpty) {
          if (_availableLocales.containsKey('en-US')) {
            _selectedLocale = 'en-US';
          } else {
            _selectedLocale = _availableLocales.keys.first;
          }
        }
      });
    } catch (e) {
      print('Error loading locales: $e');
    }
  }

  void _setupCallbacks() {
    SpeechAnalyzer.setCallbacks(
      onTextRecognition: (result) {
        setState(() {
          _confidence = SpeechAnalyzer.getResultConfidence(result);

          if (result.isFinal) {
            _finalTranscript = result.finalResult;
            _currentTranscript = '';
          } else {
            _currentTranscript = result.volatileResult;
          }
        });
      },
      onStatusChange: (status) {
        setState(() {
          _status = status;
          _isListening = status == SpeechAnalyzerStatus.listening;
        });

        if (_isListening) {
          _pulseController.repeat(reverse: true);
        } else {
          _pulseController.stop();
          _pulseController.reset();
        }
      },
      onError: (error) {
        setState(() {
          _errorMessage = error.errorMsg;
        });
        _showSnackBar('Error: ${error.errorMsg}', Colors.red);
      },
      onSoundLevelChange: (level) {
        setState(() {
          _soundLevel = level;
        });

        // Animate sound level
        final normalizedLevel =
            math.max(0.0, (level + 60) / 60); // Normalize -60dB to 0dB
        _soundController.animateTo(normalizedLevel.clamp(0.0, 1.0));
      },
    );
  }

  Future<void> _startListening() async {
    if (!_isInitialized) {
      _showSnackBar('Plugin not initialized', Colors.orange);
      return;
    }

    try {
      final success = await SpeechAnalyzer.startListening(
        localeId: _selectedLocale,
        partialResults: true,
      );

      if (!success) {
        _showSnackBar('Failed to start listening', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Error starting: $e', Colors.red);
    }
  }

  Future<void> _stopListening() async {
    try {
      await SpeechAnalyzer.stopListening();
    } catch (e) {
      _showSnackBar('Error stopping: $e', Colors.red);
    }
  }

  Future<void> _cancelListening() async {
    try {
      await SpeechAnalyzer.cancelListening();
    } catch (e) {
      _showSnackBar('Error canceling: $e', Colors.red);
    }
  }

  void _clearTranscript() {
    setState(() {
      _finalTranscript = '';
      _currentTranscript = '';
      _confidence = 0.0;
      _errorMessage = null;
    });
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Translation Demo'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusCard(),
            const SizedBox(height: 16),
            _buildLocaleSelector(),
            const SizedBox(height: 16),
            _buildControlButtons(),
            const SizedBox(height: 16),
            _buildSoundLevelIndicator(),
            const SizedBox(height: 16),
            _buildTranscriptDisplay(),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              _buildErrorCard(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (_status) {
      case SpeechAnalyzerStatus.listening:
        statusColor = Colors.green;
        statusIcon = Icons.mic;
        statusText = 'Listening...';
        break;
      case SpeechAnalyzerStatus.available:
        statusColor = Colors.blue;
        statusIcon = Icons.check_circle;
        statusText = 'Ready';
        break;
      case SpeechAnalyzerStatus.unavailable:
        statusColor = Colors.red;
        statusIcon = Icons.error;
        statusText = 'Unavailable';
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.pause_circle;
        statusText = 'Not Listening';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _isListening ? _pulseAnimation.value : 1.0,
                  child: Icon(
                    statusIcon,
                    color: statusColor,
                    size: 32,
                  ),
                );
              },
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    statusText,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Text(
                    'Initialized: ${_isInitialized ? "✓" : "✗"} | '
                    'Permission: ${_hasPermission ? "✓" : "✗"}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocaleSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Language Selection',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            if (_availableLocales.isNotEmpty)
              DropdownButtonFormField<String>(
                value: _selectedLocale,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Select Language',
                ),
                items: _availableLocales.entries.map((entry) {
                  return DropdownMenuItem(
                    value: entry.key,
                    child: Row(
                      children: [
                        Expanded(child: Text(entry.value)),
                        if (entry.key == _selectedLocale)
                          const Icon(Icons.check,
                              color: Colors.green, size: 20),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: _isListening
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() {
                            _selectedLocale = value;
                          });
                        }
                      },
              )
            else
              const Text('Loading languages...'),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButtons() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Controls',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isListening ? null : _startListening,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isListening ? _stopListening : null,
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isListening ? _cancelListening : null,
                    icon: const Icon(Icons.cancel),
                    label: const Text('Cancel'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _clearTranscript,
                icon: const Icon(Icons.clear_all),
                label: const Text('Clear Transcript'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSoundLevelIndicator() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sound Level',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.volume_up, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: AnimatedBuilder(
                    animation: _soundAnimation,
                    builder: (context, child) {
                      return LinearProgressIndicator(
                        value: _soundAnimation.value,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _soundAnimation.value > 0.8
                              ? Colors.red
                              : _soundAnimation.value > 0.5
                                  ? Colors.orange
                                  : Colors.green,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Text('${_soundLevel.toStringAsFixed(1)} dB'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTranscriptDisplay() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Transcript',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const Spacer(),
                    if (_confidence > 0)
                      Chip(
                        label:
                            Text('${(_confidence * 100).toStringAsFixed(1)}%'),
                        backgroundColor: _confidence > 0.8
                            ? Colors.green
                            : _confidence > 0.5
                                ? Colors.orange
                                : Colors.red,
                        labelStyle:
                            const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                  ],
                ),
                if (_finalTranscript.isNotEmpty ||
                    _currentTranscript.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: Colors.black,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text('Final',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(width: 16),
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.blue[600],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text('Current',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_finalTranscript.isNotEmpty ||
                      _currentTranscript.isNotEmpty)
                    RichText(
                      text: TextSpan(
                        children: [
                          if (_finalTranscript.isNotEmpty)
                            TextSpan(
                              text: _finalTranscript,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(
                                    color: Colors.black,
                                    fontWeight: FontWeight.normal,
                                  ),
                            ),
                          if (_currentTranscript.isNotEmpty)
                            TextSpan(
                              text: _currentTranscript,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(
                                    color: Colors.blue[600],
                                    fontWeight: FontWeight.w500,
                                    fontStyle: FontStyle.italic,
                                  ),
                            ),
                        ],
                      ),
                    ),
                  if (_finalTranscript.isEmpty && _currentTranscript.isEmpty)
                    Text(
                      'Press "Start" and speak to see transcript here...',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Card(
      color: Colors.red[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(Icons.error, color: Colors.red[700]),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Error',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Colors.red[700],
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Text(
                    _errorMessage!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.red[600],
                        ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () {
                setState(() {
                  _errorMessage = null;
                });
              },
              icon: const Icon(Icons.close),
              color: Colors.red[700],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _soundController.dispose();
    SpeechAnalyzer.removeCallbacks();
    super.dispose();
  }
}

import Foundation
import AVFoundation
import os
import Flutter
import UIKit

#if canImport(Speech)
import Speech
#endif

// MARK: - Enums for Plugin Methods and Status

public enum SpeechAnalyzerMethods: String {
    case hasPermission = "has_permission"
    case initialize = "initialize"
    case listen = "listen"
    case stop = "stop"
    case cancel = "cancel"
    case locales = "locales"
    case unknown = "unknown"
}

public enum SpeechAnalyzerCallbackMethods: String {
    case textRecognition = "textRecognition"
    case notifyStatus = "notifyStatus"
    case notifyError = "notifyError"
    case soundLevelChange = "soundLevelChange"
}

public enum SpeechAnalyzerStatus: String {
    case listening = "listening"
    case notListening = "notListening"
    case unavailable = "unavailable"
    case available = "available"
    case done = "done"
    case doneNoResult = "doneNoResult"
}

public enum SpeechAnalyzerErrors: String {
    case unsupportedOS = "unsupportedOS"
    case transcriptionFailed = "transcriptionFailed"
    case failedToSetupTranscriber = "failedToSetupTranscriber"
    case localeNotSupported = "localeNotSupported"
    case missingOrInvalidArg = "missingOrInvalidArg"
    case listenFailedError = "listenFailedError"
}

// MARK: - Data Structures

struct SpeechRecognitionWords: Codable {
    let recognizedWords: String
    let confidence: Decimal
}

struct SpeechRecognitionResult: Codable {
    let finalResult: String
    let volatileResult: String
    let isFinal: Bool
}

struct SpeechRecognitionError: Codable {
    let errorMsg: String
    let permanent: Bool
}

// MARK: - Future Speaker Identification Support

struct SpeakerInfo: Codable {
    let speakerId: String?
    let confidence: Double?
    let startTime: Double?
    let endTime: Double?
}

struct SpeechSegment: Codable {
    let text: String
    let speaker: SpeakerInfo?
    let confidence: Double
    let isFinal: Bool
}

// MARK: - Audio Buffer Converter

@available(iOS 26.0, *)
class AudioBufferConverter {
    private let converter: AVAudioConverter
    private let outputFormat: AVAudioFormat
    
    init(inputFormat: AVAudioFormat, outputFormat: AVAudioFormat) throws {
        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            throw SpeechAnalyzerPluginError.failedToSetupAudioEngine
        }
        self.converter = converter
        self.outputFormat = outputFormat
    }
    
    func convertBuffer(_ buffer: AVAudioPCMBuffer, to format: AVAudioFormat) throws -> AVAudioPCMBuffer {
        // Calculate proper frame capacity for different sample rates
        let ratio = format.sampleRate / buffer.format.sampleRate
        let outputFrameCapacity = AVAudioFrameCount(Double(buffer.frameCapacity) * ratio)
        
        guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: outputFrameCapacity) else {
            throw SpeechAnalyzerPluginError.failedToSetupAudioEngine
        }
        
        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }
        
        let status = converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)
        
        if let error = error {
            throw error
        }
        
        guard status == .haveData else {
            throw SpeechAnalyzerPluginError.failedToSetupAudioEngine
        }
        
        return convertedBuffer
    }
}

// MARK: - Main Plugin Class

@available(iOS 26.0, *)
public class SpeechAnalyzerPlugin: NSObject, FlutterPlugin {
    
    // MARK: - Properties
    
    private var channel: FlutterMethodChannel
    private var registrar: FlutterPluginRegistrar
    private let logger = Logger(subsystem: "com.example.SpeechAnalyzer", category: "SpeechAnalyzerPlugin")
    
    // Speech Analysis Components
    private var transcriber: SpeechTranscriber?
    private var analyzer: SpeechAnalyzer?
    private var recognizerTask: Task<(), Error>?
    private var inputSequence: AsyncStream<AnalyzerInput>?
    private var inputBuilder: AsyncStream<AnalyzerInput>.Continuation?
    private var analyzerFormat: AVAudioFormat?
    
    // Audio Components
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var bufferConverter: AudioBufferConverter?
    private let busForNodeTap = 0
    private let speechBufferSize: AVAudioFrameCount = 4096
    
    // State Management
    private var listening = false
    private var stopping = false
    private var returnPartialResults = true
    private var currentLocale: Locale = Locale.current
    private var downloadProgress: Progress?
    
    // Audio Session Management
    #if os(iOS)
    private var rememberedAudioCategory: AVAudioSession.Category?
    private var rememberedAudioCategoryOptions: AVAudioSession.CategoryOptions?
    private let audioSession = AVAudioSession.sharedInstance()
    #endif
    
    // Result Processing
    // Using AttributedString to leverage Apple's new SpeechAnalyzer API capabilities
    // This allows access to rich metadata like confidence scores, timing, and speaker identification
    private var volatileTranscript: AttributedString = ""
    private var finalizedTranscript: AttributedString = ""
    private let jsonEncoder = JSONEncoder()
    
    // MARK: - Plugin Registration
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        var channel: FlutterMethodChannel
        #if os(OSX)
        channel = FlutterMethodChannel(
            name: "plugin.SpeechAnalyzer.com/speech_analyzer", 
            binaryMessenger: registrar.messenger)
        #else
        channel = FlutterMethodChannel(
            name: "plugin.SpeechAnalyzer.com/speech_analyzer", 
            binaryMessenger: registrar.messenger())
        #endif
        
        let instance = SpeechAnalyzerPlugin(channel, registrar: registrar)
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    init(_ channel: FlutterMethodChannel, registrar: FlutterPluginRegistrar) {
        self.channel = channel
        self.registrar = registrar
        super.init()
    }
    
    // MARK: - Flutter Method Handler
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard #available(iOS 26.0, *) else {
            result(FlutterError(
                code: SpeechAnalyzerErrors.unsupportedOS.rawValue,
                message: "SpeechAnalyzer requires iOS 26.0 or later",
                details: nil))
            return
        }
        
        switch call.method {
        case SpeechAnalyzerMethods.hasPermission.rawValue:
            hasPermission(result)
            
        case SpeechAnalyzerMethods.initialize.rawValue:
            Task {
                await initialize(result)
            }
            
        case SpeechAnalyzerMethods.listen.rawValue:
            guard let argsArr = call.arguments as? [String: AnyObject],
                  let partialResults = argsArr["partialResults"] as? Bool else {
                result(FlutterError(
                    code: SpeechAnalyzerErrors.missingOrInvalidArg.rawValue,
                    message: "Missing required arguments",
                    details: nil))
                return
            }
            
            let localeStr = argsArr["localeId"] as? String
            
            Task {
                await listenForSpeech(result, localeStr: localeStr, partialResults: partialResults)
            }
            
        case SpeechAnalyzerMethods.stop.rawValue:
            Task {
                await stopSpeech(result)
            }
            
        case SpeechAnalyzerMethods.cancel.rawValue:
            Task {
                await cancelSpeech(result)
            }
            
        case SpeechAnalyzerMethods.locales.rawValue:
            Task {
                await getLocales(result)
            }
            
        default:
            logger.error("Unrecognized method: \(call.method)")
            result(FlutterMethodNotImplemented)
        }
    }
    
    // MARK: - Permission Methods
    
    private func hasPermission(_ result: @escaping FlutterResult) {
        var hasPermission = true 
        
        #if os(iOS)
        hasPermission = audioSession.recordPermission == .granted
        #else
        hasPermission = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        #endif
        
        DispatchQueue.main.async {
            result(hasPermission)
        }
    }
    
    @available(iOS 26.0, *)
    private func initialize(_ result: @escaping FlutterResult) async {
        // SpeechAnalyzer API không cần SFSpeechRecognizer permission
        // Chỉ cần audio permission
        await requestAudioPermission(result)
    }
    

    @available(iOS 26.0, *)
    private func requestAudioPermission(_ result: @escaping FlutterResult) async {
        #if os(iOS)
        await withCheckedContinuation { continuation in
            audioSession.requestRecordPermission { granted in
                Task {
                    if granted {
                        await self.setupSpeechAnalyzer(result)
                    } else {
                        self.sendBoolResult(false, result)
                    }
                    continuation.resume()
                }
            }
        }
        #else
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                Task {
                    if granted {
                        await self.setupSpeechAnalyzer(result)
                    } else {
                        self.sendBoolResult(false, result)
                    }
                    continuation.resume()
                }
            }
        }
        #endif
    }
    
    // MARK: - Speech Analyzer Setup
    
    @available(iOS 26.0, *)
    private func setupSpeechAnalyzer(_ result: @escaping FlutterResult) async {
        do {
            // Create transcriber with current locale
            let transcriber = SpeechTranscriber(
                locale: currentLocale,
                transcriptionOptions: [],
                reportingOptions: [.volatileResults],
                attributeOptions: [.audioTimeRange]
            )
            
            self.transcriber = transcriber
            
            // Create analyzer
            analyzer = SpeechAnalyzer(modules: [transcriber])
            
            // Get best audio format
            analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])
            
            // Ensure model is available
            try await ensureModel(for: transcriber, locale: currentLocale)
            
            logger.notice("Speech analyzer setup completed successfully")
            sendBoolResult(true, result)
            
        } catch {
            logger.error("Failed to setup speech analyzer: \(error.localizedDescription)")
            sendBoolResult(false, result)
        }
    }
    
    // MARK: - Speech Recognition Methods
    
    @available(iOS 26.0, *)
    private func listenForSpeech(_ result: @escaping FlutterResult, localeStr: String?, partialResults: Bool) async {
        if listening {
            sendBoolResult(false, result)
            return
        }
        
        do {
            // Reset transcripts for new session
            resetTranscripts()
            
            // Update locale if specified
            if let localeStr = localeStr {
                currentLocale = Locale(identifier: localeStr)
                try await setupTranscriberForLocale(currentLocale)
            }
            
            returnPartialResults = partialResults
            
            // Setup audio session
            try setupAudioSession()
            
            // Setup audio engine
            try setupAudioEngine()
            
            // Start speech analysis
            try await startSpeechAnalysis()
            
            listening = true
            invokeFlutter(.notifyStatus, arguments: SpeechAnalyzerStatus.listening.rawValue)
            sendBoolResult(true, result)
            
        } catch {
            logger.error("Failed to start listening: \(error.localizedDescription)")
            await stopCurrentSession()
            sendBoolResult(false, result)
            
            let speechError = SpeechRecognitionError(errorMsg: "Failed to start listening", permanent: false)
            sendError(speechError)
        }
    }
    
    @available(iOS 26.0, *)
    private func stopSpeech(_ result: @escaping FlutterResult) async {
        if !listening {
            sendBoolResult(false, result)
            return
        }
        
        stopping = true
        await stopCurrentSession()
        sendBoolResult(true, result)
    }
    
    @available(iOS 26.0, *)
    private func cancelSpeech(_ result: @escaping FlutterResult) async {
        if !listening {
            sendBoolResult(false, result)
            return
        }
        
        stopping = true
        recognizerTask?.cancel()
        await stopCurrentSession()
        sendBoolResult(true, result)
    }
    
    // MARK: - Audio Session and Engine Setup
    
    private func setupAudioSession() throws {
        #if os(iOS)
        rememberedAudioCategory = audioSession.category
        rememberedAudioCategoryOptions = audioSession.categoryOptions
        
        try audioSession.setCategory(.playAndRecord, mode: .spokenAudio)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        #endif
    }
    
    private func setupAudioEngine() throws {
        audioEngine = AVAudioEngine()
        inputNode = audioEngine?.inputNode
        
        guard let inputNode = inputNode else {
            throw SpeechAnalyzerPluginError.failedToSetupAudioEngine
        }
        
        guard inputNode.inputFormat(forBus: 0).channelCount > 0 else {
            throw SpeechAnalyzerPluginError.noAudioInput
        }
    }
    
    @available(iOS 26.0, *)
    private func startSpeechAnalysis() async throws {
        guard let transcriber = transcriber,
              let analyzer = analyzer else {
            throw SpeechAnalyzerPluginError.failedToSetupTranscriber
        }
        
        // Validate audio format compatibility
        guard let analyzerFormat = analyzerFormat else {
            throw SpeechAnalyzerPluginError.failedToSetupAudioEngine
        }
        
        logger.notice("Starting speech analysis with format: \(analyzerFormat)")
        
        // Create input stream
        (inputSequence, inputBuilder) = AsyncStream<AnalyzerInput>.makeStream()
        
        guard let inputSequence = inputSequence else {
            throw SpeechAnalyzerPluginError.failedToCreateInputStream
        }
        
        // Start analyzer with timeout
        do {
            try await analyzer.start(inputSequence: inputSequence)
            logger.notice("Speech analyzer started successfully")
        } catch {
            logger.error("Failed to start analyzer: \(error.localizedDescription)")
            throw error
        }
        
        // Setup audio tap
        try setupAudioTap()
        
        // Start audio engine with validation
        audioEngine?.prepare()
        
        do {
            try audioEngine?.start()
            logger.notice("Audio engine started successfully")
        } catch {
            logger.error("Failed to start audio engine: \(error.localizedDescription)")
            // Cleanup on failure
            inputBuilder?.finish()
            throw error
        }
        
        // Start processing results
        startProcessingResults(transcriber: transcriber)
    }
    
    @available(iOS 26.0, *)
    private func setupAudioTap() throws {
        guard let inputNode = inputNode,
              let analyzerFormat = analyzerFormat else {
            throw SpeechAnalyzerPluginError.failedToSetupAudioEngine
        }
        
        // Use input node's output format as Apple recommends
        let inputFormat = inputNode.outputFormat(forBus: busForNodeTap)
        
        // Create converter for input to analyzer format
        do {
            bufferConverter = try AudioBufferConverter(inputFormat: inputFormat, outputFormat: analyzerFormat)
            logger.notice("Audio converter created: \(inputFormat) → \(analyzerFormat)")
        } catch {
            logger.error("Failed to create audio converter: \(error.localizedDescription)")
            throw error
        }
        
        inputNode.installTap(
            onBus: busForNodeTap,
            bufferSize: speechBufferSize,
            format: inputFormat  // Use input node's natural format
        ) { [weak self] buffer, _ in
            guard let self = self,
                  let inputBuilder = self.inputBuilder,
                  let converter = self.bufferConverter,
                  buffer.frameLength > 0 else { 
                self?.logger.debug("Skipping buffer - missing requirements")
                return 
            }
            
            do {
                // Convert buffer to analyzer format
                let convertedBuffer = try converter.convertBuffer(buffer, to: self.analyzerFormat!)
                let analyzerInput = AnalyzerInput(buffer: convertedBuffer)
                inputBuilder.yield(analyzerInput)
                
                // Update sound level using original buffer
                self.updateSoundLevel(buffer: buffer)
            } catch {
                self.logger.error("Audio conversion failed: \(error.localizedDescription)")
            }
        }
    }
    


    
    @available(iOS 26.0, *)
    private func startProcessingResults(transcriber: SpeechTranscriber) {
        recognizerTask = Task {
            do {
                for try await case let result in transcriber.results {
                    let text = result.text
                    
                    if result.isFinal {
                        self.logger.notice("Final text: '\(text)'")
                        
                        // // For final results, treat as complete replacement of volatile content
                        // // Only append if this is truly new content (not already in finalized)
                        // let newFinalText = self.attributedStringToString(text)
                        // let currentVolatile = self.attributedStringToString(self.volatileTranscript)
                        
                        // // Replace volatile with final and clear volatile
                        // if !currentVolatile.isEmpty && newFinalText.contains(currentVolatile) {
                        //     // This final result includes our volatile text, so just replace
                        //     self.finalizedTranscript += text
                        // } else if !newFinalText.isEmpty {
                        //     // This is new final content
                        //     self.finalizedTranscript += text
                        // }
                        self.finalizedTranscript += text

                        self.volatileTranscript = AttributedString()
                        
                        let speechResult = SpeechRecognitionResult(
                            finalResult: self.attributedStringToString(self.finalizedTranscript),
                            volatileResult: "",
                            isFinal: true
                        )
                        self.sendRecognitionResult(speechResult)
                        self.logger.notice("Final result: '\(self.finalizedTranscript)'")
                    } else {
                        // For partial results, replace volatile transcript (don't append)
                        self.volatileTranscript = text
                        self.logger.notice("Volatile text: '\(self.volatileTranscript)'")
                        
                        let speechResult = SpeechRecognitionResult(
                            finalResult: self.attributedStringToString(self.finalizedTranscript),
                            volatileResult: self.attributedStringToString(self.volatileTranscript),
                            isFinal: false
                        )
                        
                        // Only send partial results if requested
                        if self.returnPartialResults {
                            self.sendRecognitionResult(speechResult)
                        }
                    }
                }
            } catch {
                self.logger.error("Speech recognition failed: \(error.localizedDescription)")
                await self.handleRecognitionError(error)
            }
        }
    }
    
    
    @available(iOS 26.0, *)
    private func handleRecognitionError(_ error: Error) async {
        let speechError = SpeechRecognitionError(errorMsg: error.localizedDescription, permanent: false)
        self.sendError(speechError)
        await self.stopCurrentSession()
    }
    
    // MARK: - Session Management
    
    private func resetTranscripts() {
        volatileTranscript = AttributedString()
        finalizedTranscript = AttributedString()
        logger.debug("Transcripts reset for new session")
    }
    
    // MARK: - AttributedString Helpers
    
    /// Convert AttributedString to String safely while preserving structure
    private func attributedStringToString(_ attributedString: AttributedString) -> String {
        return String(attributedString.characters)
    }
    
    /// Extract speaker identification information from AttributedString metadata if available
    private func extractSpeakerInfo(_ attributedString: AttributedString) -> [String: Any]? {
        // Future implementation for speaker identification
        // The SpeechAnalyzer API may provide speaker metadata in AttributedString attributes
        // For now, return nil as this feature requires additional setup
        return nil
    }
    
    /// Extract confidence information from AttributedString metadata if available
    private func extractConfidenceFromAttributedString(_ attributedString: AttributedString) -> Double {
        // Future implementation to extract confidence scores from metadata
        // For now, return default high confidence since SpeechAnalyzer provides high-quality results
        return 1.0
    }
    
    /// Get text segments with speaker information for future multi-speaker scenarios
    private func getTextSegmentsWithSpeakers(_ attributedString: AttributedString) -> [(text: String, speakerId: String?)] {
        // Future implementation for speaker-segmented transcription
        // This will be useful for meetings, conversations, etc.
        let plainText = String(attributedString.characters)
        return [(text: plainText, speakerId: nil)]
    }
    
    @available(iOS 26.0, *)
    private func stopCurrentSession() async {
        // Stop async stream and recognition task first
        self.inputBuilder?.finish()
        self.inputBuilder = nil
        
        self.recognizerTask?.cancel()
        self.recognizerTask = nil
        
        // Finalize analyzer to ensure clean shutdown
        do {
            try await analyzer?.finalizeAndFinishThroughEndOfInput()
            logger.notice("Speech analyzer finalized successfully")
        } catch {
            logger.error("Error finalizing analyzer: \(error.localizedDescription)")
        }
        
        // Stop audio engine and remove taps
        self.audioEngine?.stop()
        self.inputNode?.removeTap(onBus: self.busForNodeTap)
        self.audioEngine = nil
        self.inputNode = nil
        
        #if os(iOS)
        do {
            if let rememberedAudioCategory = self.rememberedAudioCategory,
               let rememberedAudioCategoryOptions = self.rememberedAudioCategoryOptions {
                try self.audioSession.setCategory(rememberedAudioCategory, options: rememberedAudioCategoryOptions)
            }
            try self.audioSession.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            self.logger.error("Error restoring audio session: \(error.localizedDescription)")
        }
        #endif
        
        // Clear state
        self.listening = false
        self.stopping = false
        self.inputSequence = nil
        self.bufferConverter = nil
        
        // Reset transcripts when session ends
        self.resetTranscripts()
        
        self.invokeFlutter(.notifyStatus, arguments: SpeechAnalyzerStatus.done.rawValue)
        
        logger.notice("Session cleanup completed")
    }
    
    // MARK: - Locale and Model Management
    
    @available(iOS 26.0, *)
    private func setupTranscriberForLocale(_ locale: Locale) async throws {
        let transcriber = SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            reportingOptions: [.volatileResults],
            attributeOptions: [.audioTimeRange]
        )
        
        self.transcriber = transcriber
        analyzer = SpeechAnalyzer(modules: [transcriber])
        analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])
        
        try await ensureModel(for: transcriber, locale: locale)
    }
    
    @available(iOS 26.0, *)
    private func getLocales(_ result: @escaping FlutterResult) async {
        let supportedLocales = await SpeechTranscriber.supportedLocales
        let localeStrings = supportedLocales.map { locale in
            let name = Locale.current.localizedString(forIdentifier: locale.identifier) ?? locale.identifier
            return "\(locale.identifier):\(name)"
        }
        
        DispatchQueue.main.async {
            result(localeStrings)
        }
    }
    
    @available(iOS 26.0, *)
    private func ensureModel(for transcriber: SpeechTranscriber, locale: Locale) async throws {
        // Check if locale is supported
        let supportedLocales = await SpeechTranscriber.supportedLocales
        guard supportedLocales.contains(where: { $0.identifier == locale.identifier }) else {
            logger.error("Locale not supported: \(locale.identifier)")
            throw SpeechAnalyzerPluginError.localeNotSupported
        }
        
        // Check if model is installed
        let installedLocales = await SpeechTranscriber.installedLocales
        if installedLocales.contains(where: { $0.identifier == locale.identifier }) {
            logger.notice("Model already installed for locale: \(locale.identifier)")
            return
        }
        
        // Download model if needed
        logger.notice("Downloading model for locale: \(locale.identifier)")
        try await downloadModel(for: transcriber)
    }
    
    @available(iOS 26.0, *)
    private func downloadModel(for transcriber: SpeechTranscriber) async throws {
        if let downloader = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            downloadProgress = downloader.progress
            logger.notice("Starting model download...")
            try await downloader.downloadAndInstall()
            logger.notice("Model download completed")
        }
    }
    
    // MARK: - Audio Level Monitoring
    
    private func updateSoundLevel(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        
        let channelDataValue = channelData.pointee
        let channelDataValueArray = stride(
            from: 0,
            to: Int(buffer.frameLength),
            by: buffer.stride
        ).map { channelDataValue[$0] }
        
        let frameLength = Float(buffer.frameLength)
        let rms = sqrt(channelDataValueArray.map { $0 * $0 }.reduce(0, +) / frameLength)
        let avgPower = 20 * log10(rms)
        
        invokeFlutter(.soundLevelChange, arguments: avgPower)
    }
    
    // MARK: - Flutter Communication
    
    private func sendRecognitionResult(_ result: SpeechRecognitionResult) {
        do {
            let jsonData = try jsonEncoder.encode(result)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                invokeFlutter(.textRecognition, arguments: jsonString)
            }
        } catch {
            logger.error("Failed to encode recognition result: \(error.localizedDescription)")
        }
    }
    
    private func sendError(_ error: SpeechRecognitionError) {
        do {
            let jsonData = try jsonEncoder.encode(error)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                invokeFlutter(.notifyError, arguments: jsonString)
            }
        } catch {
            logger.error("Failed to encode error: \(error.localizedDescription)")
        }
    }
    
    private func sendBoolResult(_ value: Bool, _ result: @escaping FlutterResult) {
        DispatchQueue.main.async {
            result(value)
        }
    }
    
    private func invokeFlutter(_ method: SpeechAnalyzerCallbackMethods, arguments: Any?) {
        DispatchQueue.main.async {
            self.channel.invokeMethod(method.rawValue, arguments: arguments)
        }
    }
}

// MARK: - Custom Errors

enum SpeechAnalyzerPluginError: Error, LocalizedError {
    case failedToSetupTranscriber
    case failedToSetupAudioEngine
    case noAudioInput
    case failedToCreateInputStream
    case localeNotSupported
    
    var errorDescription: String? {
        switch self {
        case .failedToSetupTranscriber:
            return "Failed to setup speech transcriber"
        case .failedToSetupAudioEngine:
            return "Failed to setup audio engine"
        case .noAudioInput:
            return "No audio input available"
        case .failedToCreateInputStream:
            return "Failed to create input stream"
        case .localeNotSupported:
            return "Locale not supported"
        }
    }
}

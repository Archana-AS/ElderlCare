import 'package:speech_to_text/speech_to_text.dart';
import 'dart:developer';

// This service is responsible for initializing and running the STT listener
// and handling the continuous restart logic.
class VoiceService {
  final SpeechToText _speechToText = SpeechToText();
  bool _isListening = false;
  bool _isInitializing = false; // Prevent multiple init attempts
  bool _isDisposed = false; // Flag to prevent restarts after stop

  bool get isListening => _isListening;

  // A simple way to get a unique identifier for logging
  String get _instanceId => hashCode.toString();

  // 1. Initialization
  Future<bool> initialize() async {
    if (_isInitializing) return _speechToText.isAvailable;
    _isInitializing = true;
    _isDisposed = false;

    // Check if initialization has already happened
    if (_speechToText.isAvailable) {
      _isInitializing = false;
      return true;
    }

    // Initialize the STT engine. The listener parameters were removed here too.
    var available = await _speechToText.initialize();

    if (available) {
      log("VoiceService ($_instanceId): STT initialized successfully.");
      _isInitializing = false;
      return true;
    } else {
      log("VoiceService ($_instanceId): The user has denied the use of speech recognition.");
      _isInitializing = false;
      return false;
    }
  }

  // 2. Start Continuous Listening
  void startContinuousListening({required Function(String) onTranscript}) async {
    if (_isDisposed) return;
    if (!await initialize()) {
      log("VoiceService ($_instanceId): Cannot start listening: STT not initialized.");
      return;
    }

    if (_isListening) {
      log("VoiceService ($_instanceId): Already listening, skipping start.");
      return;
    }

    // --- FIX 1 & 2: Use the statusListener and errorListener properties ---
    // These properties are the modern, correct way to handle the STT lifecycle
    // for continuous operation, outside of the listen() method parameters.

    _speechToText.statusListener = (status) {
      log('VoiceService ($_instanceId) Status: $status');

      if (_isDisposed) return; // Stop if disposed

      // Correctly reference the enum for comparison
      if (status == SpeechToText.notListeningStatus) {
        _isListening = false;
        // CRITICAL RESTART LOGIC: Re-call startContinuousListening to restart the mic
        Future.delayed(const Duration(milliseconds: 200), () {
          // Ensure we only restart if we are not manually stopped or disposed
          if (!_isDisposed && !_speechToText.isListening) {
            log('VoiceService ($_instanceId) Restarting due to status: notListening');
            startContinuousListening(onTranscript: onTranscript);
          }
        });
      } else if (status == SpeechToText.listeningStatus) {
        _isListening = true;
      }
    };

    _speechToText.errorListener = (error) {
      log('VoiceService ($_instanceId) Error: ${error.errorMsg}');
      // Restart on most errors as well
      if (!_isDisposed && !_speechToText.isListening) {
        log('VoiceService ($_instanceId) Restarting due to error: ${error.errorMsg}');
        startContinuousListening(onTranscript: onTranscript);
      }
    };

    log('VoiceService ($_instanceId): Attempting to start continuous listening...');

    // The listen method now only requires the onResult callback.
    _speechToText.listen(
      // Set the result listener to send recognized words back to the Provider
      onResult: (result) {
        // Pass the transcription back to the provider/UI
        onTranscript(result.recognizedWords);

        // If the recognition is final, log it
        if (result.finalResult) {
          log('VoiceService ($_instanceId) Final Transcript: ${result.recognizedWords}');
        }
      },
      listenMode: ListenMode.confirmation, // Recommended for continuous use
    );
    _isListening = true;
    log('VoiceService ($_instanceId): Continuous listening started.');
  }

  // 3. Stop Listening and prevent future restarts
  void stopListening() {
    if (_isListening) {
      _speechToText.stop();
      _isListening = false;
      _isDisposed = true; // Prevents the continuous restart loop
      log('VoiceService ($_instanceId): Stopped listening and prevented restart.');
    }
  }
}

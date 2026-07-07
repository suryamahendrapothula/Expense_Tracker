import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';

class VoiceService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  bool _isSpeechAvailable = false;

  Future<void> init() async {
    try {
      _isSpeechAvailable = await _speech.initialize(
        onError: (val) => print('Speech initialization error: $val'),
        onStatus: (val) => print('Speech status: $val'),
      );
      
      await _tts.setLanguage("en-IN");
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
    } catch (e) {
      _isSpeechAvailable = false;
      print('VoiceService init error: $e');
    }
  }

  bool get isSpeechAvailable => _isSpeechAvailable;

  // Speech to Text (Listen)
  Future<void> startListening({
    required Function(String) onResult,
    required Function(bool) onSoundLevelChange,
  }) async {
    if (!_isSpeechAvailable) {
      // Re-try initialization once
      await init();
    }
    
    if (_isSpeechAvailable) {
      await _speech.listen(
        onResult: (result) {
          onResult(result.recognizedWords);
        },
        listenFor: const Duration(seconds: 15),
        pauseFor: const Duration(seconds: 4),
        cancelOnError: true,
        partialResults: true,
      );
    } else {
      print('Speech recognition is not available on this device.');
    }
  }

  Future<void> stopListening() async {
    if (_isSpeechAvailable) {
      await _speech.stop();
    }
  }

  // Text to Speech (Speak)
  Future<void> speak(String text) async {
    try {
      await _tts.speak(text);
    } catch (e) {
      print('TTS Error: $e');
    }
  }

  Future<void> stopSpeaking() async {
    await _tts.stop();
  }
}

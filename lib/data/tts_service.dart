import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal();

  final FlutterTts _tts = FlutterTts();
  bool _inited = false;

  Future<void> _init() async {
    if (_inited) return;
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.45); // 语速 0.0~1.0
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      _inited = true;
    } catch (_) {
      // 忽略初始化错误
    }
  }

  /// 朗读单词
  Future<void> speak(String text) async {
    await _init();
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {
      // 静默失败
    }
  }

  /// 停止朗读
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal();

  static const String _rateKey = 'tts_rate';

  final FlutterTts _tts = FlutterTts();
  bool _inited = false;
  double _rate = 0.6;

  /// 当前语速（用于设置页面显示）
  double get rate => _rate;

  /// 不同平台的默认语速（0.0 ~ 1.0）
  /// 各平台对同一数值的解释差别很大，需要分别调
  static double _defaultRateForPlatform() {
    if (kIsWeb) return 0.75;              // 浏览器普遍偏慢
    try {
      if (Platform.isAndroid) return 0.55; // 安卓 / 鸿蒙
      if (Platform.isIOS) return 0.6;
      if (Platform.isWindows) return 0.85; // Windows SAPI 明显偏慢
      if (Platform.isMacOS) return 0.7;
      if (Platform.isLinux) return 0.7;
    } catch (_) {
      // Platform 在部分平台可能不可用
    }
    return 0.6;
  }

  Future<void> _init() async {
    if (_inited) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _rate = prefs.getDouble(_rateKey) ?? _defaultRateForPlatform();
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(_rate);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      _inited = true;
    } catch (_) {
      // 初始化失败时保持默认值，speak 时会再试一次
    }
  }

  /// 更新语速并保存到本地
  Future<void> setRate(double rate) async {
    _rate = rate;
    await _init();
    try {
      await _tts.setSpeechRate(rate);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_rateKey, rate);
    } catch (_) {}
  }

  /// 朗读文本
  Future<void> speak(String text) async {
    await _init();
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {}
  }

  /// 停止朗读
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}
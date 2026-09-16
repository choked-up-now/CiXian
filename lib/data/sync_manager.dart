import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/word.dart';
import 'cloud_sync.dart';
import 'wrong_words_storage.dart';
import 'tts_service.dart';

class SyncManager {
  static const _userIdKey = 'cloud_user_id';
  static const _syncCodeKey = 'cloud_sync_code';
  static const _enabledKey = 'cloud_sync_enabled';

  static Timer? _debounceTimer;

  /// 是否已开启云同步
  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }

  /// 获取当前同步码
  static Future<String?> getSyncCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_syncCodeKey);
  }

  /// 开启云同步并注册新账号，返回同步码
  static Future<String> enableAndRegister() async {
    final result = await CloudSync.register();
    final userId = result['user_id'] as String;
    final syncCode = result['sync_code'] as String;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userIdKey, userId);
    await prefs.setString(_syncCodeKey, syncCode);
    await prefs.setBool(_enabledKey, true);

    // 注册后立刻上传当前本地数据
    await uploadNow();
    return syncCode;
  }

  /// 用同步码恢复账号（换设备时用）
  static Future<void> bindWithCode(String syncCode) async {
    final code = syncCode.trim().toUpperCase();
    final result = await CloudSync.bind(code);
    final userId = result['user_id'] as String;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userIdKey, userId);
    await prefs.setString(_syncCodeKey, code);
    await prefs.setBool(_enabledKey, true);

    // 下载云端数据覆盖本地
    await downloadAndApply();
  }

  /// 关闭云同步（本地数据保留）
  static Future<void> disable() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, false);
  }

  /// 触发防抖上传（数据变化后 5 秒再传）
  static void scheduleUpload() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 5), () {
      uploadNow();
    });
  }

  /// 立即上传
  static Future<void> uploadNow() async {
    if (!await isEnabled()) return;
    final syncCode = await getSyncCode();
    if (syncCode == null) return;

    try {
      final data = await _collectData();
      await CloudSync.upload(syncCode, data);
    } catch (_) {
      // 静默失败，下次再试
    }
  }

  /// 下载并应用到本地
  static Future<void> downloadAndApply() async {
    if (!await isEnabled()) return;
    final syncCode = await getSyncCode();
    if (syncCode == null) return;

    try {
      final data = await CloudSync.download(syncCode);
      if (data == null) return;
      await _applyData(data);
    } catch (_) {
      // 静默失败
    }
  }

  /// 收集本地数据
  static Future<Map<String, dynamic>> _collectData() async {
    final wrongWords = await WrongWordsStorage.loadWrongWords();
    return {
      'wrong_words': wrongWords
          .map((w) => {
                'word': w.word,
                'phonetic': w.phonetic,
                'pos': w.pos,
                'meaning': w.meaning,
                'example': w.example,
              })
          .toList(),
      'tts_rate': TtsService().rate,
    };
  }

  /// 应用云端数据到本地
  static Future<void> _applyData(Map<String, dynamic> data) async {
    // 错题本：以云端为准
    final cloudWrong = (data['wrong_words'] as List<dynamic>?) ?? [];
    final words = cloudWrong
        .map((e) => Word.fromJson(e as Map<String, dynamic>))
        .toList();
    await WrongWordsStorage.saveAll(words);

    // 语速
    final ttsRate = data['tts_rate'];
    if (ttsRate is num) {
      await TtsService().setRate(ttsRate.toDouble());
    }
  }
}

import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'my_words_storage.dart';
import 'cloud_sync.dart';
import 'tts_service.dart';

class SyncManager {
  static const _userIdKey = 'cloud_user_id';
  static const _syncCodeKey = 'cloud_sync_code';
  static const _enabledKey = 'cloud_sync_enabled';
  static const _lastSyncKey = 'cloud_last_sync';

  static Timer? _debounceTimer;

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }

  static Future<String?> getSyncCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_syncCodeKey);
  }

  static Future<int?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_lastSyncKey);
  }

  static Future<String> enableAndRegister() async {
    final result = await CloudSync.register();
    final userId = result['user_id'] as String;
    final syncCode = result['sync_code'] as String;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userIdKey, userId);
    await prefs.setString(_syncCodeKey, syncCode);
    await prefs.setBool(_enabledKey, true);

    await uploadNow();
    return syncCode;
  }

  static Future<void> bindWithCode(String syncCode) async {
    final code = syncCode.trim().toUpperCase();
    final result = await CloudSync.bind(code);
    final userId = result['user_id'] as String;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userIdKey, userId);
    await prefs.setString(_syncCodeKey, code);
    await prefs.setBool(_enabledKey, true);

    await downloadAndApply();
  }

  static Future<void> disable() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, false);
  }

  static void scheduleUpload() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 5), () {
      uploadNow();
    });
  }

  static Future<bool> uploadNow() async {
    if (!await isEnabled()) return false;
    final syncCode = await getSyncCode();
    if (syncCode == null) return false;

    try {
      final data = await _collectData();
      await CloudSync.upload(syncCode, data);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastSyncKey, DateTime.now().millisecondsSinceEpoch);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> downloadAndApply() async {
    if (!await isEnabled()) return false;
    final syncCode = await getSyncCode();
    if (syncCode == null) return false;

    try {
      final data = await CloudSync.download(syncCode);
      if (data == null) return false;
      await _applyData(data);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastSyncKey, DateTime.now().millisecondsSinceEpoch);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, dynamic>> _collectData() async {
    final myWords = await MyWordsStorage.exportAll();
    return {
      'my_words': myWords,
      'tts_rate': TtsService().rate,
    };
  }

  static Future<void> _applyData(Map<String, dynamic> data) async {
    final mw = data['my_words'] as Map<String, dynamic>?;
    if (mw != null) {
      await MyWordsStorage.importAll(mw);
    }

    final ttsRate = data['tts_rate'];
    if (ttsRate is num) {
      await TtsService().setRate(ttsRate.toDouble());
    }
  }
}

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/word.dart';

class WrongWordsStorage {
  static const _key = 'wrong_words';

  // 添加错词（自动去重）
  static Future<void> addWrongWord(Word word) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    List<dynamic> list = raw != null ? jsonDecode(raw) as List<dynamic> : [];

    final exists =
        list.any((e) => (e as Map<String, dynamic>)['word'] == word.word);
    if (!exists) {
      list.add({
        'word': word.word,
        'phonetic': word.phonetic,
        'pos': word.pos,
        'meaning': word.meaning,
        'example': word.example,
      });
      await prefs.setString(_key, jsonEncode(list));
    }
  }

  // 读取全部错词
  static Future<List<Word>> loadWrongWords() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => Word.fromJson(e as Map<String, dynamic>)).toList();
  }

  // 移除某个错词
  static Future<void> removeWord(String word) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return;
    final list = jsonDecode(raw) as List<dynamic>;
    list.removeWhere((e) => (e as Map<String, dynamic>)['word'] == word);
    await prefs.setString(_key, jsonEncode(list));
  }

  // 清空错题本
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/word.dart';

class WordbookStorage {
  static const _key = 'custom_wordbook';

  // 保存词书（覆盖）
  static Future<void> saveWordbook(List<Word> words) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = words
        .map((e) => {
              'word': e.word,
              'phonetic': e.phonetic,
              'pos': e.pos,
              'meaning': e.meaning,
              'example': e.example,
            })
        .toList();
    await prefs.setString(_key, jsonEncode(jsonList));
  }

  // 读取词书，如果没有则返回 null
  static Future<List<Word>?> loadWordbook() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => Word.fromJson(e as Map<String, dynamic>)).toList();
  }

  // 清空自定义词书
  static Future<void> clearWordbook() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

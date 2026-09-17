import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/word.dart';

class Wordbook {
  final String id;
  final String name;
  final List<Word> words;

  Wordbook({required this.id, required this.name, required this.words});
}

/// 多词书管理：添加、删除、重命名、切换
class WordbookStorage {
  static const _key = 'wordbooks_v2';
  static const _currentKey = 'current_book_id';
  static const String defaultBookId = 'waiyan_9_upper';

  /// 首次启动时从 assets 加载默认词书
  static Future<void> ensureDefaultBook() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) return;

    final data =
        await rootBundle.loadString('assets/wordbooks/waiyan_9_upper.json');
    final list = jsonDecode(data) as List<dynamic>;
    final words = list.map((e) => (e as Map<String, dynamic>)).toList();

    final all = {
      defaultBookId: {
        'name': '外研版九上',
        'words': words,
      }
    };
    await prefs.setString(_key, jsonEncode(all));
    await prefs.setString(_currentKey, defaultBookId);
  }

  /// 读取全部词书（只含元数据 + 单词，不含学习进度）
  static Future<Map<String, Map<String, dynamic>>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return {};
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return map.map((k, v) => MapEntry(k, Map<String, dynamic>.from(v as Map)));
  }

  /// 当前词书 ID
  static Future<String> currentId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_currentKey) ?? defaultBookId;
  }

  /// 切换当前词书
  static Future<void> setCurrent(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentKey, id);
  }

  /// 加载当前词书（含 index）
  static Future<Wordbook> loadCurrent() async {
    await ensureDefaultBook();
    final all = await loadAll();
    final id = await currentId();
    final book = all[id];
    if (book == null) {
      // 当前 ID 失效，回退到默认
      await setCurrent(defaultBookId);
      return loadCurrent();
    }
    final list = book['words'] as List<dynamic>;
    final words = <Word>[];
    for (int i = 0; i < list.length; i++) {
      final w = Word.fromJson(list[i] as Map<String, dynamic>);
      words.add(w.copyWith(index: i));
    }
    return Wordbook(id: id, name: book['name'] as String, words: words);
  }

  /// 添加新词书，返回新 ID
  static Future<String> addBook(
      String name, List<Map<String, dynamic>> rawWords) async {
    final all = await loadAll();
    final id = 'book_${DateTime.now().millisecondsSinceEpoch}_${_rand(4)}';
    all[id] = {
      'name': name,
      'words': rawWords,
    };
    await _saveAll(all);
    return id;
  }

  /// 删除词书（默认词书不可删）
  static Future<void> deleteBook(String id) async {
    if (id == defaultBookId) {
      throw Exception('默认词书不能删除');
    }
    final all = await loadAll();
    all.remove(id);
    await _saveAll(all);

    final current = await currentId();
    if (current == id) {
      await setCurrent(defaultBookId);
    }
  }

  /// 重命名词书
  static Future<void> renameBook(String id, String newName) async {
    final all = await loadAll();
    final book = all[id];
    if (book == null) return;
    book['name'] = newName;
    await _saveAll(all);
  }

  static Future<void> _saveAll(Map<String, Map<String, dynamic>> all) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(all));
  }

  static String _rand(int len) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final seed = DateTime.now().microsecondsSinceEpoch;
    final buf = StringBuffer();
    for (int i = 0; i < len; i++) {
      buf.write(chars[(seed + i * 31) % chars.length]);
    }
    return buf.toString();
  }
}

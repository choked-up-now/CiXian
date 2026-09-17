import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 学习进度：按词书分块存储
/// 记录格式："F YYYYMMDD N,R,W"（无空格）
///   F: 是否收藏 0/1
///   YYYYMMDD: 上次复习日期
///   N: 单词在词书里的序号
///   R: 复习次数
///   W: 错误过次数
///
/// 状态推导：
///   错题    = W > 0
///   已掌握  = W == 0 且 R > 0
///   收藏    = F == 1
class MyWordsStorage {
  static const _key = 'my_words_v2';

  /// 读取某本词书全部记录
  static Future<List<WordRecord>> loadRecords(String bookId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    final all = raw != null
        ? jsonDecode(raw) as Map<String, dynamic>
        : <String, dynamic>{};
    final list = (all[bookId] as List<dynamic>?) ?? [];
    return list.map((e) => WordRecord.parse(e as String)).toList();
  }

  /// 保存某本词书全部记录
  static Future<void> saveRecords(
      String bookId, List<WordRecord> records) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    final all = raw != null
        ? jsonDecode(raw) as Map<String, dynamic>
        : <String, dynamic>{};
    all[bookId] = records.map((r) => r.serialize()).toList();
    await prefs.setString(_key, jsonEncode(all));
  }

  /// 记录答错
  static Future<void> recordWrong(String bookId, int index) async {
    final records = await loadRecords(bookId);
    final today = _todayInt();
    final i = records.indexWhere((r) => r.index == index);
    if (i >= 0) {
      final r = records[i];
      records[i] = r.copyWith(
        lastReview: today,
        reviewCount: r.reviewCount + 1,
        wrongCount: r.wrongCount + 1,
      );
    } else {
      records.add(WordRecord(
        favorite: false,
        lastReview: today,
        index: index,
        reviewCount: 1,
        wrongCount: 1,
      ));
    }
    await saveRecords(bookId, records);
  }

  /// 记录答对
  static Future<void> recordCorrect(String bookId, int index) async {
    final records = await loadRecords(bookId);
    final today = _todayInt();
    final i = records.indexWhere((r) => r.index == index);
    if (i >= 0) {
      final r = records[i];
      records[i] = r.copyWith(
        lastReview: today,
        reviewCount: r.reviewCount + 1,
      );
    } else {
      records.add(WordRecord(
        favorite: false,
        lastReview: today,
        index: index,
        reviewCount: 1,
        wrongCount: 0,
      ));
    }
    await saveRecords(bookId, records);
  }

  /// 标记已掌握：只更新 lastReview 为今天，跳过当日复习
  static Future<void> markMastered(String bookId, int index) async {
    final records = await loadRecords(bookId);
    final today = _todayInt();
    final i = records.indexWhere((r) => r.index == index);
    if (i >= 0) {
      records[i] = records[i].copyWith(lastReview: today);
    } else {
      records.add(WordRecord(
        favorite: false,
        lastReview: today,
        index: index,
        reviewCount: 0,
        wrongCount: 0,
      ));
    }
    await saveRecords(bookId, records);
  }

  /// 切换收藏
  static Future<bool> toggleFavorite(String bookId, int index) async {
    final records = await loadRecords(bookId);
    final i = records.indexWhere((r) => r.index == index);
    if (i >= 0) {
      final newFav = !records[i].favorite;
      records[i] = records[i].copyWith(favorite: newFav);
      await saveRecords(bookId, records);
      return newFav;
    } else {
      records.add(WordRecord(
        favorite: true,
        lastReview: 0,
        index: index,
        reviewCount: 0,
        wrongCount: 0,
      ));
      await saveRecords(bookId, records);
      return true;
    }
  }

  /// 移除某条记录
  static Future<void> removeRecord(String bookId, int index) async {
    final records = await loadRecords(bookId);
    records.removeWhere((r) => r.index == index);
    await saveRecords(bookId, records);
  }

  /// 清空某本词书全部记录
  static Future<void> clearBook(String bookId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return;
    final all = jsonDecode(raw) as Map<String, dynamic>;
    all.remove(bookId);
    await prefs.setString(_key, jsonEncode(all));
  }

  /// 云同步：导出全部
  static Future<Map<String, dynamic>> exportAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return {};
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  /// 云同步：整体替换
  static Future<void> importAll(Map<String, dynamic> all) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(all));
  }

  static int _todayInt() {
    final now = DateTime.now();
    return now.year * 10000 + now.month * 100 + now.day;
  }
}

/// 单词学习记录
class WordRecord {
  final bool favorite;
  final int lastReview; // YYYYMMDD，0 表示从未复习
  final int index;
  final int reviewCount;
  final int wrongCount;

  WordRecord({
    required this.favorite,
    required this.lastReview,
    required this.index,
    required this.reviewCount,
    required this.wrongCount,
  });

  /// 解析 "F YYYYMMDD N,R,W"，如 "0202609175,3,2"
  factory WordRecord.parse(String s) {
    final clean = s.replaceAll(' ', '');
    final favorite = clean[0] == '1';
    final dateStr = clean.substring(1, 9);
    final rest = clean.substring(9);
    final parts = rest.split(',');
    return WordRecord(
      favorite: favorite,
      lastReview: int.parse(dateStr),
      index: int.parse(parts[0]),
      reviewCount: int.parse(parts[1]),
      wrongCount: int.parse(parts[2]),
    );
  }

  String serialize() {
    final dateStr = lastReview.toString().padLeft(8, '0');
    return '${favorite ? '1' : '0'}$dateStr$index,$reviewCount,$wrongCount';
  }

  WordRecord copyWith({
    bool? favorite,
    int? lastReview,
    int? index,
    int? reviewCount,
    int? wrongCount,
  }) {
    return WordRecord(
      favorite: favorite ?? this.favorite,
      lastReview: lastReview ?? this.lastReview,
      index: index ?? this.index,
      reviewCount: reviewCount ?? this.reviewCount,
      wrongCount: wrongCount ?? this.wrongCount,
    );
  }

  bool get isWrong => wrongCount > 0;
  bool get isMastered => wrongCount == 0 && reviewCount > 0;
  bool get isFavorite => favorite;
}

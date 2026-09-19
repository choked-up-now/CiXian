import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/word.dart';

/// 存储格式（按词书分块）：
/// ```json
/// {
///   "waiyan_9_up": { "1": ["1202607183,7", ...] },
///   "yilin_9_up":  { "0": ["1,1202607183,7", ...] }
/// }
/// ```
///
/// 模式 0（兼容，带序号，只存学过的词）：
///   "N,F YYYYMMDD R,W"   例如 "1,1202607183,7"
///
/// 模式 1（紧凑，无序号用下标，全量预填充）：
///   "F YYYYMMDD R,W"     例如 "1202607183,7"
///
/// 字段：
///   F: 是否收藏 0/1
///   YYYYMMDD: 上次复习日期（0 表示从未复习）
///   N: 单词在词书里的序号（仅模式 0）
///   R: 复习次数
///   W: 错误次数
///
/// 状态推导：
///   错题   = W > 0
///   已掌握 = W == 0 且 R > 0
///   收藏   = F == 1
class MyWordsStorage {
  static const _key = 'my_words_v3';
  static const _legacyKey = 'my_words_v2';

  /// 首次访问时迁移 v2 数据
  static Future<void> _ensureMigrated() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_key) != null) return;
    final old = prefs.getString(_legacyKey);
    if (old == null) return;
    final data = jsonDecode(old) as Map<String, dynamic>;
    final migrated = <String, dynamic>{};
    data.forEach((bookId, list) {
      migrated[bookId] = {'0': list};
    });
    await prefs.setString(_key, jsonEncode(migrated));
  }

  // ============ 模式管理 ============

  /// 获取某本词书的存储模式（0 或 1），默认 0
  static Future<int> getMode(String bookId) async {
    await _ensureMigrated();
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return 0;
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final book = data[bookId] as Map<String, dynamic>?;
    if (book == null) return 0;
    if (book.containsKey('1')) return 1;
    return 0;
  }

  /// 切换存储模式（自动做数据转换）
  static Future<void> switchMode(
      String bookId, int newMode, List<Word> allWords) async {
    await _ensureMigrated();
    final oldMode = await getMode(bookId);
    if (oldMode == newMode) return;

    final oldRecords = await loadRecords(bookId);

    List<WordRecord> newRecords;
    if (newMode == 1) {
      // 0 → 1：全量预填充
      final map = {for (var r in oldRecords) r.index: r};
      newRecords = <WordRecord>[];
      for (int i = 0; i < allWords.length; i++) {
        newRecords.add(map[i] ?? WordRecord.empty(i));
      }
    } else {
      // 1 → 0：只保留学过的
      newRecords = oldRecords
          .where((r) => r.reviewCount > 0 || r.wrongCount > 0 || r.favorite)
          .toList();
    }

    await _saveWithMode(bookId, newMode, newRecords);
  }

  /// 计算两种模式的字符数
  /// 返回 {0: 兼容模式字符数, 1: 紧凑模式字符数}
  static Future<Map<int, int>> calcSizes(
      String bookId, List<Word> allWords) async {
    final records = await loadRecords(bookId);

    // 模式 0：只算学过的
    final mode0Records = records
        .where((r) => r.reviewCount > 0 || r.wrongCount > 0 || r.favorite)
        .toList();
    final mode0Size = mode0Records.fold<int>(
        0, (sum, r) => sum + r.serialize(mode: 0).length);

    // 模式 1：全量
    final map = {for (var r in records) r.index: r};
    int mode1Size = 0;
    for (int i = 0; i < allWords.length; i++) {
      final r = map[i] ?? WordRecord.empty(i);
      mode1Size += r.serialize(mode: 1).length;
    }

    return {0: mode0Size, 1: mode1Size};
  }

  /// 自动选择字符数更少的模式
  static Future<int> autoChooseMode(String bookId, List<Word> allWords) async {
    final sizes = await calcSizes(bookId, allWords);
    return sizes[0]! <= sizes[1]! ? 0 : 1;
  }

  // ============ 读写 ============

  /// 读取某本词书全部记录（按当前模式解析）
  static Future<List<WordRecord>> loadRecords(String bookId) async {
    await _ensureMigrated();
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final book = data[bookId] as Map<String, dynamic>?;
    if (book == null) return [];

    if (book.containsKey('1')) {
      final list = book['1'] as List<dynamic>;
      final records = <WordRecord>[];
      for (int i = 0; i < list.length; i++) {
        records.add(
            WordRecord.parse(list[i] as String, mode: 1, fallbackIndex: i));
      }
      return records;
    } else if (book.containsKey('0')) {
      final list = book['0'] as List<dynamic>;
      return list.map((e) => WordRecord.parse(e as String, mode: 0)).toList();
    }
    return [];
  }

  /// 保存记录（沿用当前模式）
  static Future<void> saveRecords(
      String bookId, List<WordRecord> records) async {
    final mode = await getMode(bookId);
    await _saveWithMode(bookId, mode, records);
  }

  static Future<void> _saveWithMode(
      String bookId, int mode, List<WordRecord> records) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    final data = raw != null
        ? jsonDecode(raw) as Map<String, dynamic>
        : <String, dynamic>{};

    final list = records.map((r) => r.serialize(mode: mode)).toList();
    data[bookId] = {mode.toString(): list};
    await prefs.setString(_key, jsonEncode(data));
  }

  // ============ 学习记录操作 ============

  /// 记录答错
  static Future<void> recordWrong(String bookId, int index) async {
    final records = await loadRecords(bookId);
    final today = _todayInt();
    _upsert(
        records,
        index,
        (r) => r.copyWith(
              lastReview: today,
              reviewCount: r.reviewCount + 1,
              wrongCount: r.wrongCount + 1,
            ));
    await saveRecords(bookId, records);
  }

  /// 记录答对
  static Future<void> recordCorrect(String bookId, int index) async {
    final records = await loadRecords(bookId);
    final today = _todayInt();
    _upsert(
        records,
        index,
        (r) => r.copyWith(
              lastReview: today,
              reviewCount: r.reviewCount + 1,
            ));
    await saveRecords(bookId, records);
  }

  /// 标记已掌握（只更新 lastReview，跳过当日复习）
  static Future<void> markMastered(String bookId, int index) async {
    final records = await loadRecords(bookId);
    final today = _todayInt();
    _upsert(records, index, (r) => r.copyWith(lastReview: today));
    await saveRecords(bookId, records);
  }

  /// 切换收藏
  static Future<bool> toggleFavorite(String bookId, int index) async {
    final records = await loadRecords(bookId);
    final i = records.indexWhere((r) => r.index == index);
    bool newFav;
    if (i >= 0) {
      newFav = !records[i].favorite;
      records[i] = records[i].copyWith(favorite: newFav);
    } else {
      newFav = true;
      records.add(WordRecord(
        favorite: true,
        lastReview: 0,
        index: index,
        reviewCount: 0,
        wrongCount: 0,
      ));
    }
    await saveRecords(bookId, records);
    return newFav;
  }

  /// 移除记录
  static Future<void> removeRecord(String bookId, int index) async {
    final records = await loadRecords(bookId);
    records.removeWhere((r) => r.index == index);
    await saveRecords(bookId, records);
  }

  /// 清空某本词书
  static Future<void> clearBook(String bookId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return;
    final all = jsonDecode(raw) as Map<String, dynamic>;
    all.remove(bookId);
    await prefs.setString(_key, jsonEncode(all));
  }

  // ============ 云同步 ============

  static Future<Map<String, dynamic>> exportAll() async {
    await _ensureMigrated();
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return {};
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  static Future<void> importAll(Map<String, dynamic> all) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(all));
  }

  // ============ 工具 ============

  static void _upsert(List<WordRecord> records, int index,
      WordRecord Function(WordRecord) update) {
    final i = records.indexWhere((r) => r.index == index);
    if (i >= 0) {
      records[i] = update(records[i]);
    } else {
      records.add(update(WordRecord.empty(index)));
    }
  }

  static int _todayInt() {
    final now = DateTime.now();
    return now.year * 10000 + now.month * 100 + now.day;
  }
}

/// ============================================================
///  单词学习记录
/// ============================================================
class WordRecord {
  final bool favorite;
  final int lastReview;
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

  factory WordRecord.empty(int index) => WordRecord(
        favorite: false,
        lastReview: 0,
        index: index,
        reviewCount: 0,
        wrongCount: 0,
      );

  /// mode 0: "N,F YYYYMMDD R,W"
  /// mode 1: "F YYYYMMDD R,W"
  factory WordRecord.parse(String s,
      {required int mode, int fallbackIndex = -1}) {
    if (mode == 0) {
      final commaIdx = s.indexOf(',');
      if (commaIdx <= 0) {
        throw FormatException('mode 0 格式错误: $s');
      }
      final indexStr = s.substring(0, commaIdx);
      final rest = s.substring(commaIdx + 1);
      return WordRecord._parseBody(rest, int.parse(indexStr));
    }
    return WordRecord._parseBody(s, fallbackIndex);
  }

  factory WordRecord._parseBody(String s, int index) {
    if (s.length < 10) throw FormatException('记录长度不足: $s');
    final favorite = s[0] == '1';
    final dateStr = s.substring(1, 9);
    final rest = s.substring(9);
    final parts = rest.split(',');
    if (parts.length != 2) throw FormatException('格式错误: $s');
    return WordRecord(
      favorite: favorite,
      lastReview: int.parse(dateStr),
      index: index,
      reviewCount: int.parse(parts[0]),
      wrongCount: int.parse(parts[1]),
    );
  }

  String serialize({required int mode}) {
    final dateStr = lastReview.toString().padLeft(8, '0');
    final body = '${favorite ? '1' : '0'}$dateStr$reviewCount,$wrongCount';
    if (mode == 0) return '$index,$body';
    return body;
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

// Copyright 2026 choked-up-now
// SPDX-License-Identifier: Apache-2.0

import 'package:shared_preferences/shared_preferences.dart';

/// 题型枚举
enum QuestionType {
  enToZh, // 英选中：看英文，选中文释义
  zhToEn, // 中选英：看中文，选英文单词
  zhToSpell, // 看中译英：看中文，拼写英文
  listenToZh, // 听音选意：听发音，选中文释义
  listenToEn, // 听音选词：听发音，选英文单词
}

extension QuestionTypeExt on QuestionType {
  String get label {
    switch (this) {
      case QuestionType.enToZh:
        return '英选中';
      case QuestionType.zhToEn:
        return '中选英';
      case QuestionType.zhToSpell:
        return '看中译英';
      case QuestionType.listenToZh:
        return '听音选意';
      case QuestionType.listenToEn:
        return '听音选词';
    }
  }

  String get description {
    switch (this) {
      case QuestionType.enToZh:
        return '看英文，选中文释义';
      case QuestionType.zhToEn:
        return '看中文，选英文单词';
      case QuestionType.zhToSpell:
        return '看中文，拼写英文';
      case QuestionType.listenToZh:
        return '听发音，选中文释义';
      case QuestionType.listenToEn:
        return '听发音，选英文单词';
    }
  }
}

class UserSettings {
  static const _dailyNewKey = 'daily_new_count';
  static const _dailyReviewKey = 'daily_review_count';
  static const _enabledTypesKey = 'enabled_question_types';

  static Future<int> dailyNew() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_dailyNewKey) ?? 10;
  }

  static Future<int> dailyReview() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_dailyReviewKey) ?? 10;
  }

  static Future<void> setDailyNew(int n) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_dailyNewKey, n);
  }

  static Future<void> setDailyReview(int n) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_dailyReviewKey, n);
  }

  /// 获取启用的题型集合，默认全开
  static Future<Set<QuestionType>> enabledTypes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_enabledTypesKey);
    if (raw == null) return QuestionType.values.toSet();

    final result = <QuestionType>{};
    for (final name in raw) {
      for (final t in QuestionType.values) {
        if (t.name == name) result.add(t);
      }
    }
    if (result.isEmpty) result.add(QuestionType.enToZh);
    return result;
  }

  /// 保存启用的题型，至少保留一种
  static Future<void> setEnabledTypes(Set<QuestionType> types) async {
    if (types.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _enabledTypesKey,
      types.map((t) => t.name).toList(),
    );
  }
}

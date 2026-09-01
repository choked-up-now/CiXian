import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../models/word.dart';

class WordbookLoader {
  static Future<List<Word>> loadWordbook(String assetPath) async {
    final data = await rootBundle.loadString(assetPath);
    final list = json.decode(data) as List<dynamic>;
    return list.map((e) => Word.fromJson(e as Map<String, dynamic>)).toList();
  }
}
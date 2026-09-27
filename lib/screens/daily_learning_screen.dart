// Copyright 2026 choked-up-now
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'dart:math';

import '../data/ebbinghaus.dart';
import '../data/wordbook_storage.dart';
import '../data/my_words_storage.dart';
import '../data/sync_manager.dart';
import '../data/tts_service.dart';
import '../data/user_settings.dart';
import '../models/word.dart';

class DailyLearningScreen extends StatefulWidget {
  final Wordbook book;

  const DailyLearningScreen({Key? key, required this.book}) : super(key: key);

  @override
  State<DailyLearningScreen> createState() => _DailyLearningScreenState();
}

class _DailyLearningScreenState extends State<DailyLearningScreen> {
  late List<_Question> _questions;
  int _currentIndex = 0;
  int _score = 0;
  bool _answered = false;
  int? _selectedOption;
  String? _errorMessage;

  final TextEditingController _spellCtrl = TextEditingController();
  bool _spellCorrect = false;
  bool _spellSubmitted = false;

  @override
  void initState() {
    super.initState();
    _prepareQuestions();
  }

  @override
  void dispose() {
    _spellCtrl.dispose();
    super.dispose();
  }

  Future<void> _prepareQuestions() async {
    final words = widget.book.words;
    if (words.length < 4) {
      setState(() {
        _errorMessage = '词书单词太少（至少需要4个）。';
      });
      return;
    }

    final records = await MyWordsStorage.loadRecords(widget.book.id);
    final recordMap = {for (final r in records) r.index: r};
    final today = _todayInt();

    final newCount = await UserSettings.dailyNew();
    final reviewCount = await UserSettings.dailyReview();

    final newIndexes = <int>[];
    for (int i = 0; i < words.length; i++) {
      final r = recordMap[i];
      if (r == null || r.lastReview == 0) {
        newIndexes.add(i);
        if (newIndexes.length >= newCount) break;
      }
    }

    final candidates = <int>[];
    final weights = <double>[];
    for (int i = 0; i < words.length; i++) {
      final r = recordMap[i];
      if (r == null) continue;
      if (r.lastReview == 0) continue;
      if (r.lastReview >= today) continue;
      final days = _daysBetween(r.lastReview, today);
      final y = Ebbinghaus.retention(days);
      final m = r.reviewCount;
      final n = r.wrongCount;
      final w = m == 0 ? 1 + 0.5 * (1 - y) : 1 + 0.5 * (1 - y) + n / m;
      candidates.add(i);
      weights.add(w);
    }
    final reviewIndexes = _weightedSample(candidates, weights, reviewCount);

    final selected = <int>{};
    selected.addAll(newIndexes);
    selected.addAll(reviewIndexes);
    if (selected.length < newCount + reviewCount) {
      final random = Random();
      final all = List<int>.generate(words.length, (i) => i)..shuffle(random);
      for (final i in all) {
        if (selected.length >= newCount + reviewCount) break;
        selected.add(i);
      }
    }

    final enabledTypes = (await UserSettings.enabledTypes()).toList();
    final random = Random();
    final uniqueMeanings = words.map((e) => e.meaning).toSet().toList();
    final uniqueWords = words.map((e) => e.word).toSet().toList();

    _questions = selected.map((idx) {
      final word = words[idx];
      final type = enabledTypes[random.nextInt(enabledTypes.length)];

      if (type == QuestionType.zhToSpell) {
        return _Question(
          word: word,
          wordIndex: idx,
          type: type,
          options: const [],
          correctIndex: -1,
        );
      }

      String correct;
      List<String> pool;

      switch (type) {
        case QuestionType.enToZh:
        case QuestionType.listenToZh:
          correct = word.meaning;
          pool = uniqueMeanings.where((m) => m != correct).toList();
          break;
        case QuestionType.zhToEn:
        case QuestionType.listenToEn:
          correct = word.word;
          pool = uniqueWords.where((w) => w != correct).toList();
          break;
        default:
          correct = word.meaning;
          pool = uniqueMeanings.where((m) => m != correct).toList();
      }

      pool.shuffle(random);
      final options = [correct, ...pool.take(3)]..shuffle(random);
      return _Question(
        word: word,
        wordIndex: idx,
        type: type,
        options: options,
        correctIndex: options.indexOf(correct),
      );
    }).toList();

    if (_questions.isEmpty) {
      setState(() {
        _errorMessage = '暂时没有可学习的单词。';
      });
      return;
    }

    setState(() {});
    _autoPlayIfListen();
  }

  void _autoPlayIfListen() {
    final q = _questions[_currentIndex];
    if (q.type == QuestionType.listenToZh ||
        q.type == QuestionType.listenToEn) {
      TtsService().speak(q.word.word);
    }
  }

  List<int> _weightedSample(
      List<int> candidates, List<double> weights, int count) {
    final result = <int>[];
    final pool = List<int>.from(candidates);
    final w = List<double>.from(weights);
    final random = Random();

    for (int k = 0; k < count && pool.isNotEmpty; k++) {
      final total = w.fold<double>(0, (a, b) => a + b);
      if (total <= 0) break;
      double r = random.nextDouble() * total;
      int pick = pool.length - 1;
      for (int i = 0; i < pool.length; i++) {
        r -= w[i];
        if (r <= 0) {
          pick = i;
          break;
        }
      }
      result.add(pool[pick]);
      pool.removeAt(pick);
      w.removeAt(pick);
    }
    return result;
  }

  Future<void> _answer(int index) async {
    if (_answered) return;
    final q = _questions[_currentIndex];
    final isCorrect = index == q.correctIndex;
    setState(() {
      _answered = true;
      _selectedOption = index;
      if (isCorrect) _score++;
    });

    if (isCorrect) {
      await MyWordsStorage.recordCorrect(widget.book.id, q.wordIndex);
    } else {
      await MyWordsStorage.recordWrong(widget.book.id, q.wordIndex);
    }
    SyncManager.scheduleUpload();
  }

  Future<void> _submitSpell() async {
    if (_answered) return;
    final q = _questions[_currentIndex];
    final input = _normalize(_spellCtrl.text);
    final correct = _normalize(q.word.word);
    final isCorrect = input == correct;

    setState(() {
      _answered = true;
      _spellSubmitted = true;
      _spellCorrect = isCorrect;
      if (isCorrect) _score++;
    });

    if (isCorrect) {
      await MyWordsStorage.recordCorrect(widget.book.id, q.wordIndex);
    } else {
      await MyWordsStorage.recordWrong(widget.book.id, q.wordIndex);
    }
    SyncManager.scheduleUpload();
  }

  String _normalize(String s) => s.trim().toLowerCase();

  void _next() {
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _answered = false;
        _selectedOption = null;
        _spellSubmitted = false;
        _spellCorrect = false;
        _spellCtrl.clear();
      });
      _autoPlayIfListen();
    } else {
      _showResult();
    }
  }

  void _showResult() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('学习完成'),
        content: Text('答对 $_score / ${_questions.length} 题'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('返回'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('每日学习')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, color: Colors.red),
            ),
          ),
        ),
      );
    }

    if (_questions.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final q = _questions[_currentIndex];
    return Scaffold(
      appBar: AppBar(
        title: Text('每日学习 (${_currentIndex + 1}/${_questions.length})'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LinearProgressIndicator(
              value: (_currentIndex + 1) / _questions.length,
              minHeight: 8,
              backgroundColor: Colors.grey[300],
            ),
            const SizedBox(height: 8),
            Text(
              q.type.label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _buildPrompt(q),
            const SizedBox(height: 32),
            Expanded(
              child: SingleChildScrollView(
                child: q.type == QuestionType.zhToSpell
                    ? _buildSpellInput(q)
                    : _buildOptions(q),
              ),
            ),
            if (_answered)
              ElevatedButton(
                onPressed: _next,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blue,
                ),
                child: Text(
                  _currentIndex < _questions.length - 1 ? '下一题' : '查看结果',
                  style: const TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrompt(_Question q) {
    switch (q.type) {
      case QuestionType.enToZh:
        return Text(
          q.word.word,
          style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        );
      case QuestionType.zhToEn:
      case QuestionType.zhToSpell:
        return Text(
          q.word.meaning,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        );
      case QuestionType.listenToZh:
      case QuestionType.listenToEn:
        return Column(
          children: [
            IconButton(
              icon: const Icon(Icons.volume_up, size: 72, color: Colors.blue),
              onPressed: () => TtsService().speak(q.word.word),
            ),
            const Text('点击喇叭重听',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        );
    }
  }

  Widget _buildOptions(_Question q) {
    return Column(
      children: List.generate(q.options.length, (index) {
        final option = q.options[index];
        final isCorrect = index == q.correctIndex;
        final isSelected = _selectedOption == index;

        Color buttonColor;
        IconData? icon;
        if (!_answered) {
          buttonColor = Colors.white;
        } else if (isCorrect) {
          buttonColor = Colors.green.withValues(alpha: 0.3);
          icon = Icons.check;
        } else if (isSelected && !isCorrect) {
          buttonColor = Colors.red.withValues(alpha: 0.3);
          icon = Icons.close;
        } else {
          buttonColor = Colors.white;
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ElevatedButton(
            onPressed: () => _answer(index),
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(option, style: const TextStyle(fontSize: 18)),
                ),
                if (icon != null) Icon(icon),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildSpellInput(_Question q) {
    return Column(
      children: [
        TextField(
          controller: _spellCtrl,
          enabled: !_spellSubmitted,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submitSpell(),
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            hintText: '输入对应的英文单词',
            filled: true,
            fillColor: _spellSubmitted
                ? (_spellCorrect
                    ? Colors.green.withValues(alpha: 0.15)
                    : Colors.red.withValues(alpha: 0.15))
                : Colors.white,
            suffixIcon: _spellSubmitted
                ? Icon(
                    _spellCorrect ? Icons.check : Icons.close,
                    color: _spellCorrect ? Colors.green : Colors.red,
                  )
                : null,
          ),
          style: const TextStyle(fontSize: 20),
        ),
        const SizedBox(height: 16),
        if (!_spellSubmitted)
          ElevatedButton(
            onPressed: _submitSpell,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: Colors.blue,
            ),
            child: const Text('提交', style: TextStyle(color: Colors.white)),
          ),
        if (_spellSubmitted && !_spellCorrect)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                const Text('正确答案：', style: TextStyle(fontSize: 14)),
                const SizedBox(height: 4),
                Text(
                  q.word.word,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  static int _todayInt() {
    final now = DateTime.now();
    return now.year * 10000 + now.month * 100 + now.day;
  }

  static int _daysBetween(int from, int to) {
    final d1 = DateTime(from ~/ 10000, (from ~/ 100) % 100, from % 100);
    final d2 = DateTime(to ~/ 10000, (to ~/ 100) % 100, to % 100);
    return d2.difference(d1).inDays;
  }
}

class _Question {
  final Word word;
  final int wordIndex;
  final QuestionType type;
  final List<String> options;
  final int correctIndex;

  _Question({
    required this.word,
    required this.wordIndex,
    required this.type,
    required this.options,
    required this.correctIndex,
  });
}

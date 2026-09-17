import 'package:flutter/material.dart';
import 'dart:math';

import '../data/wordbook_storage.dart';
import '../data/my_words_storage.dart';
import '../data/sync_manager.dart';
import '../data/tts_service.dart';
import '../models/word.dart';

class DailyLearningScreen extends StatefulWidget {
  final Wordbook book;

  const DailyLearningScreen({Key? key, required this.book}) : super(key: key);

  @override
  State<DailyLearningScreen> createState() => _DailyLearningScreenState();
}

class _DailyLearningScreenState extends State<DailyLearningScreen> {
  static const int _targetCount = 10;

  late List<_Question> _questions;
  int _currentIndex = 0;
  int _score = 0;
  bool _answered = false;
  int? _selectedOption;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _prepareQuestions();
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
    final needReview = <int>[]; // 错题优先复习
    final unseen = <int>[]; // 没学过的
    final others = <int>[]; // 学过的、今天还没复习

    for (int i = 0; i < words.length; i++) {
      final r = recordMap[i];
      if (r == null) {
        unseen.add(i);
      } else if (r.lastReview < today) {
        if (r.wrongCount > 0) {
          needReview.add(i);
        } else {
          others.add(i);
        }
      }
    }

    // 排序：错题按 lastReview 升序（越早越先），others 同理
    needReview.sort((a, b) {
      final ra = recordMap[a]!.lastReview;
      final rb = recordMap[b]!.lastReview;
      return ra.compareTo(rb);
    });
    others.sort((a, b) {
      final ra = recordMap[a]!.lastReview;
      final rb = recordMap[b]!.lastReview;
      return ra.compareTo(rb);
    });

    // 组合：错题 → 未学 → 其他
    final selected = <int>[];
    selected.addAll(needReview.take(_targetCount));
    if (selected.length < _targetCount) {
      selected.addAll(unseen.take(_targetCount - selected.length));
    }
    if (selected.length < _targetCount) {
      selected.addAll(others.take(_targetCount - selected.length));
    }
    // 还凑不够就用随机从词书里补
    if (selected.length < _targetCount) {
      final random = Random();
      final allIndexes = List<int>.generate(words.length, (i) => i)
        ..shuffle(random);
      for (final i in allIndexes) {
        if (selected.length >= _targetCount) break;
        if (!selected.contains(i)) selected.add(i);
      }
    }

    // 生成题目
    final random = Random();
    final uniqueMeanings = words.map((e) => e.meaning).toSet().toList();
    _questions = selected.map((idx) {
      final word = words[idx];
      final wrongMeanings = uniqueMeanings
          .where((m) => m != word.meaning)
          .toList()
        ..shuffle(random);
      final options = [word.meaning, ...wrongMeanings.take(3)]..shuffle(random);
      return _Question(
        word: word,
        wordIndex: idx,
        options: options,
        correctIndex: options.indexOf(word.meaning),
      );
    }).toList();

    setState(() {});
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

    // 记录
    if (isCorrect) {
      await MyWordsStorage.recordCorrect(widget.book.id, q.wordIndex);
    } else {
      await MyWordsStorage.recordWrong(widget.book.id, q.wordIndex);
    }
    SyncManager.scheduleUpload();
  }

  void _next() {
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _answered = false;
        _selectedOption = null;
      });
      TtsService().speak(_questions[_currentIndex].word.word);
    } else {
      _showResult();
    }
  }

  void _showResult() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('学习完成！'),
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

    final question = _questions[_currentIndex];
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
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  question.word.word,
                  style: const TextStyle(
                      fontSize: 36, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.volume_up, size: 32),
                  onPressed: () {
                    TtsService().speak(question.word.word);
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              question.word.phonetic,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ...List.generate(question.options.length, (index) {
              final option = question.options[index];
              final isCorrect = index == question.correctIndex;
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
                        child:
                            Text(option, style: const TextStyle(fontSize: 18)),
                      ),
                      if (icon != null) Icon(icon),
                    ],
                  ),
                ),
              );
            }),
            const Spacer(),
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

  static int _todayInt() {
    final now = DateTime.now();
    return now.year * 10000 + now.month * 100 + now.day;
  }
}

class _Question {
  final Word word;
  final int wordIndex;
  final List<String> options;
  final int correctIndex;

  _Question({
    required this.word,
    required this.wordIndex,
    required this.options,
    required this.correctIndex,
  });
}

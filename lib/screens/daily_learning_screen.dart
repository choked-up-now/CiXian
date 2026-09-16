import 'package:flutter/material.dart';
import 'dart:math';

import '../models/word.dart';
import '../data/wrong_words_storage.dart';
import '../data/sync_manager.dart';
import '../data/tts_service.dart';

class DailyLearningScreen extends StatefulWidget {
  final List<Word> allWords;
  final List<Word>? poolWords;

  const DailyLearningScreen({
    Key? key,
    required this.allWords,
    this.poolWords,
  }) : super(key: key);

  @override
  State<DailyLearningScreen> createState() => _DailyLearningScreenState();
}

class _DailyLearningScreenState extends State<DailyLearningScreen> {
  static const int _targetCount = 10;

  late List<Word> _studyWords;
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

  void _prepareQuestions() {
    final random = Random();
    final pool = widget.poolWords ?? widget.allWords;

    final uniqueMeanings = pool.map((e) => e.meaning).toSet().toList();
    if (uniqueMeanings.length < 4) {
      setState(() {
        _errorMessage = '词库单词太少，无法生成四选一题目（至少需要4个不同释义）。';
      });
      return;
    }

    final shuffled = List<Word>.from(widget.allWords)..shuffle(random);
    _studyWords = shuffled.take(min(_targetCount, shuffled.length)).toList();

    _questions = _studyWords.map((word) {
      final wrongMeanings = uniqueMeanings
          .where((m) => m != word.meaning)
          .toList()
        ..shuffle(random);
      final selectedWrong = wrongMeanings.take(3).toList();
      final options = [word.meaning, ...selectedWrong]..shuffle(random);
      return _Question(
        word: word,
        options: options,
        correctIndex: options.indexOf(word.meaning),
      );
    }).toList();
  }

  void _answer(int index) async {
    if (_answered) return;
    final isCorrect = index == _questions[_currentIndex].correctIndex;
    setState(() {
      _answered = true;
      _selectedOption = index;
      if (isCorrect) _score++;
    });

    if (!isCorrect) {
      await WrongWordsStorage.addWrongWord(_questions[_currentIndex].word);
      // 触发云同步（防抖）
      SyncManager.scheduleUpload();
    }
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
                  tooltip: '朗读',
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
}

class _Question {
  final Word word;
  final List<String> options;
  final int correctIndex;

  _Question({
    required this.word,
    required this.options,
    required this.correctIndex,
  });
}

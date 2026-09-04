import 'package:flutter/material.dart';
import 'dart:math';

import '../models/word.dart';

class DailyLearningScreen extends StatefulWidget {
  final List<Word> allWords;

  const DailyLearningScreen({Key? key, required this.allWords})
      : super(key: key);

  @override
  State<DailyLearningScreen> createState() => _DailyLearningScreenState();
}

class _DailyLearningScreenState extends State<DailyLearningScreen> {
  // 本次学习目标单词数量（可后续设置）
  static const int _targetCount = 10;

  late List<Word> _studyWords; // 本次要考的单词
  late List<_Question> _questions; // 生成的题目列表
  int _currentIndex = 0; // 当前题号
  int _score = 0; // 答对数量
  bool _answered = false; // 当前题目是否已作答
  int? _selectedOption; // 用户选择的选项索引

  @override
  void initState() {
    super.initState();
    _prepareQuestions();
  }

  // 随机抽词并生成题目
  void _prepareQuestions() {
    final random = Random();
    // 从所有词中随机选出 targetCount 个（不够则全用）
    final shuffled = List<Word>.from(widget.allWords)..shuffle(random);
    _studyWords = shuffled.take(min(_targetCount, shuffled.length)).toList();

    // 为每个单词生成四选一题目
    _questions = _studyWords.map((word) {
      // 生成三个干扰项（从其他单词的释义中随机选，确保不重复）
      final wrongMeanings = <String>{};
      while (wrongMeanings.length < 3) {
        final candidate =
            widget.allWords[random.nextInt(widget.allWords.length)].meaning;
        if (candidate != word.meaning) {
          wrongMeanings.add(candidate);
        }
      }
      // 合并正确选项和干扰选项，打乱顺序
      final options = [word.meaning, ...wrongMeanings]..shuffle(random);
      return _Question(
        word: word,
        options: options,
        correctIndex: options.indexOf(word.meaning),
      );
    }).toList();
  }

  void _answer(int index) {
    if (_answered) return;
    setState(() {
      _answered = true;
      _selectedOption = index;
      if (index == _questions[_currentIndex].correctIndex) {
        _score++;
      }
    });
  }

  void _next() {
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _answered = false;
        _selectedOption = null;
      });
    } else {
      // 完成所有题目，显示结果对话框
      _showResult();
    }
  }

  void _showResult() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('今日学习完成！'),
        content: Text('答对 $_score / ${_questions.length} 题'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // 返回主页
            },
            child: const Text('返回'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
            // 进度条
            LinearProgressIndicator(
              value: (_currentIndex + 1) / _questions.length,
              minHeight: 8,
              backgroundColor: Colors.grey[300],
            ),
            const SizedBox(height: 24),
            // 题干：英文单词
            Text(
              question.word.word,
              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              question.word.phonetic,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            // 选项列表
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
                          child: Text(option,
                              style: const TextStyle(fontSize: 18))),
                      if (icon != null) Icon(icon),
                    ],
                  ),
                ),
              );
            }),
            const Spacer(),
            // 下一题按钮（答完才显示）
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

// 题目数据结构
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

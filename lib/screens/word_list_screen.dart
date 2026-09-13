import 'package:flutter/material.dart';
import '../models/word.dart';
import '../data/tts_service.dart';
import 'daily_learning_screen.dart';
import 'wordbook_manager_screen.dart';
import 'settings_screen.dart';
import 'wrong_book_screen.dart';

class WordListScreen extends StatelessWidget {
  final List<Word> words;
  final void Function(List<Word>) onWordsChanged;

  const WordListScreen({
    Key? key,
    required this.words,
    required this.onWordsChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('词冼 · 九上外研版'),
        actions: [
          IconButton(
            icon: const Icon(Icons.book),
            tooltip: '错题本',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => WrongBookScreen(allWords: words),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: '设置',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SettingsScreen(
                    currentWords: words,
                    onWordsChanged: onWordsChanged,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.menu_book),
            tooltip: '词书管理',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => WordbookManagerScreen(
                    currentWords: words,
                    onWordsChanged: onWordsChanged,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: words.length,
        itemBuilder: (context, index) {
          final word = words[index];
          return ListTile(
            title: Text(
              word.word,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(word.meaning),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Row(
                    children: [
                      Expanded(child: Text(word.word)),
                      IconButton(
                        icon: const Icon(Icons.volume_up),
                        tooltip: '朗读',
                        onPressed: () {
                          TtsService().speak(word.word);
                        },
                      ),
                    ],
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (word.phonetic.isNotEmpty)
                        Text('音标: ${word.phonetic}'),
                      if (word.pos.isNotEmpty) Text('词性: ${word.pos}'),
                      Text('释义: ${word.meaning}'),
                      if (word.example.isNotEmpty) Text('例句: ${word.example}'),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('关闭'),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DailyLearningScreen(allWords: words),
            ),
          );
        },
        icon: const Icon(Icons.school),
        label: const Text('开始今日学习'),
      ),
    );
  }
}

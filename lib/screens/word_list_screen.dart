import 'package:flutter/material.dart';
import '../data/wordbook_storage.dart';
import '../data/tts_service.dart';
import '../data/my_words_storage.dart';
import '../data/sync_manager.dart';
import 'daily_learning_screen.dart';
import 'my_words_screen.dart';
import 'settings_screen.dart';
import 'wordbook_manager_screen.dart';

class WordListScreen extends StatefulWidget {
  final Wordbook book;
  final Future<void> Function() onBookChanged;

  const WordListScreen({
    Key? key,
    required this.book,
    required this.onBookChanged,
  }) : super(key: key);

  @override
  State<WordListScreen> createState() => _WordListScreenState();
}

class _WordListScreenState extends State<WordListScreen> {
  // 收藏状态缓存：word -> isFavorite
  Map<String, bool> _favorites = {};

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final records = await MyWordsStorage.loadRecords(widget.book.id);
    final map = <String, bool>{};
    for (final r in records) {
      if (r.index >= 0 && r.index < widget.book.words.length) {
        map[widget.book.words[r.index].word] = r.favorite;
      }
    }
    if (mounted) setState(() => _favorites = map);
  }

  Future<void> _toggleFavorite(int index) async {
    final word = widget.book.words[index];
    final newValue = await MyWordsStorage.toggleFavorite(widget.book.id, index);
    setState(() => _favorites[word.word] = newValue);
    // 触发云同步
    SyncManager.scheduleUpload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('词冼 · ${widget.book.name}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.star),
            tooltip: '我的单词',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MyWordsScreen(book: widget.book),
                ),
              );
              _loadFavorites();
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: '设置',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.menu_book),
            tooltip: '词书管理',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const WordbookManagerScreen(),
                ),
              );
              await widget.onBookChanged();
              _loadFavorites();
            },
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: widget.book.words.length,
        itemBuilder: (context, index) {
          final word = widget.book.words[index];
          final isFav = _favorites[word.word] ?? false;
          return ListTile(
            title: Text(
              word.word,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(word.meaning),
            trailing: IconButton(
              icon: Icon(
                isFav ? Icons.star : Icons.star_border,
                color: isFav ? Colors.amber : null,
              ),
              onPressed: () => _toggleFavorite(index),
            ),
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
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DailyLearningScreen(book: widget.book),
            ),
          );
          _loadFavorites();
        },
        icon: const Icon(Icons.school),
        label: const Text('开始今日学习'),
      ),
    );
  }
}

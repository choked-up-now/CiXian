import 'package:flutter/material.dart';
import '../models/word.dart';
import '../data/wrong_words_storage.dart';
import 'daily_learning_screen.dart';

class WrongBookScreen extends StatefulWidget {
  final List<Word> allWords; // 用于生成干扰项的完整词库

  const WrongBookScreen({Key? key, required this.allWords}) : super(key: key);

  @override
  State<WrongBookScreen> createState() => _WrongBookScreenState();
}

class _WrongBookScreenState extends State<WrongBookScreen> {
  List<Word> _wrongWords = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final words = await WrongWordsStorage.loadWrongWords();
    setState(() {
      _wrongWords = words;
      _loading = false;
    });
  }

  Future<void> _remove(Word word) async {
    await WrongWordsStorage.removeWord(word.word);
    _load();
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空错题本'),
        content: const Text('确定要清空所有错题吗？此操作不可撤销。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('确定清空')),
        ],
      ),
    );
    if (confirmed == true) {
      await WrongWordsStorage.clearAll();
      _load();
    }
  }

  void _startReview() {
    if (_wrongWords.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DailyLearningScreen(
          allWords: _wrongWords,
          poolWords: widget.allWords, // 用完整词库生成干扰项
        ),
      ),
    ).then((_) => _load()); // 复习返回后刷新错题本
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('错题本 (${_wrongWords.length})'),
        actions: [
          if (_wrongWords.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: '清空错题本',
              onPressed: _clearAll,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _wrongWords.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      '错题本是空的，继续加油！\n答错的单词会自动出现在这里。',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: _wrongWords.length,
                  itemBuilder: (context, index) {
                    final word = _wrongWords[index];
                    return ListTile(
                      title: Text(word.word,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(word.meaning),
                      trailing: IconButton(
                        icon: const Icon(Icons.check_circle_outline,
                            color: Colors.green),
                        tooltip: '标记为已掌握',
                        onPressed: () => _remove(word),
                      ),
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text(word.word),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (word.phonetic.isNotEmpty)
                                  Text('音标: ${word.phonetic}'),
                                if (word.pos.isNotEmpty)
                                  Text('词性: ${word.pos}'),
                                Text('释义: ${word.meaning}'),
                                if (word.example.isNotEmpty)
                                  Text('例句: ${word.example}'),
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
      floatingActionButton: _wrongWords.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _startReview,
              icon: const Icon(Icons.replay),
              label: const Text('复习错题'),
            ),
    );
  }
}

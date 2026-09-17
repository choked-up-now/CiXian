import 'package:flutter/material.dart';
import '../data/wordbook_storage.dart';
import '../data/my_words_storage.dart';
import '../data/sync_manager.dart';
import '../models/word.dart';
import 'daily_learning_screen.dart';

class MyWordsScreen extends StatefulWidget {
  final Wordbook book;

  const MyWordsScreen({Key? key, required this.book}) : super(key: key);

  @override
  State<MyWordsScreen> createState() => _MyWordsScreenState();
}

class _MyWordsScreenState extends State<MyWordsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<WordRecord> _records = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final records = await MyWordsStorage.loadRecords(widget.book.id);
    setState(() {
      _records = records;
      _loading = false;
    });
  }

  Word? _wordAt(int index) {
    if (index < 0 || index >= widget.book.words.length) return null;
    return widget.book.words[index];
  }

  List<WordRecord> get _wrong => _records.where((r) => r.isWrong).toList()
    ..sort((a, b) => b.wrongCount.compareTo(a.wrongCount));

  List<WordRecord> get _mastered =>
      _records.where((r) => r.isMastered).toList();

  List<WordRecord> get _favorites =>
      _records.where((r) => r.isFavorite).toList();

  Future<void> _markMastered(WordRecord r) async {
    await MyWordsStorage.markMastered(widget.book.id, r.index);
    SyncManager.scheduleUpload();
    await _load();
  }

  Future<void> _remove(WordRecord r) async {
    await MyWordsStorage.removeRecord(widget.book.id, r.index);
    SyncManager.scheduleUpload();
    await _load();
  }

  Future<void> _toggleFavorite(WordRecord r) async {
    await MyWordsStorage.toggleFavorite(widget.book.id, r.index);
    SyncManager.scheduleUpload();
    await _load();
  }

  Future<void> _startReview(List<WordRecord> source) async {
    final words = <Word>[];
    for (final r in source) {
      final w = _wordAt(r.index);
      if (w != null) words.add(w);
    }
    if (words.isEmpty) return;
    final tempBook = Wordbook(
      id: widget.book.id,
      name: widget.book.name,
      words: words,
    );
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DailyLearningScreen(book: tempBook),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('我的单词 (${_records.length})'),
        bottom: TabBar(
          controller: _tab,
          tabs: [
            Tab(text: '错题 ${_wrong.length}'),
            Tab(text: '已掌握 ${_mastered.length}'),
            Tab(text: '收藏 ${_favorites.length}'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tab,
              children: [
                _buildList(_wrong, empty: '还没有错题，继续加油！', showMastered: true),
                _buildList(_mastered, empty: '还没有已掌握的单词', showMastered: false),
                _buildList(_favorites, empty: '还没有收藏的单词', showMastered: false),
              ],
            ),
    );
  }

  Widget _buildList(List<WordRecord> list,
      {required String empty, required bool showMastered}) {
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(empty,
              style: const TextStyle(color: Colors.grey, fontSize: 16)),
        ),
      );
    }
    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (context, i) {
        final r = list[i];
        final w = _wordAt(r.index);
        if (w == null) return const SizedBox.shrink();
        return ListTile(
          title:
              Text(w.word, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(w.meaning),
          leading:
              r.isFavorite ? const Icon(Icons.star, color: Colors.amber) : null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showMastered)
                IconButton(
                  icon: const Icon(Icons.check_circle_outline,
                      color: Colors.green),
                  tooltip: '标记已掌握',
                  onPressed: () => _markMastered(r),
                ),
              IconButton(
                icon: Icon(
                  r.isFavorite ? Icons.star : Icons.star_border,
                  color: r.isFavorite ? Colors.amber : null,
                ),
                tooltip: '收藏',
                onPressed: () => _toggleFavorite(r),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: '移除',
                onPressed: () => _remove(r),
              ),
            ],
          ),
          onTap: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(w.word),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (w.phonetic.isNotEmpty) Text('音标: ${w.phonetic}'),
                    if (w.pos.isNotEmpty) Text('词性: ${w.pos}'),
                    Text('释义: ${w.meaning}'),
                    if (w.example.isNotEmpty) Text('例句: ${w.example}'),
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
    );
  }
}

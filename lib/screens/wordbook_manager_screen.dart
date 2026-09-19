import 'package:flutter/material.dart';
import 'dart:convert';
import '../data/wordbook_storage.dart';
import '../data/my_words_storage.dart';
import '../models/word.dart';

class WordbookManagerScreen extends StatefulWidget {
  const WordbookManagerScreen({Key? key}) : super(key: key);

  @override
  State<WordbookManagerScreen> createState() => _WordbookManagerScreenState();
}

class _WordbookManagerScreenState extends State<WordbookManagerScreen> {
  Map<String, Map<String, dynamic>> _books = {};
  String _currentId = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final books = await WordbookStorage.loadAll();
    final current = await WordbookStorage.currentId();
    setState(() {
      _books = books;
      _currentId = current;
      _loading = false;
    });
  }

  Future<List<Word>> _getBookWords(String bookId) async {
    final book = _books[bookId];
    if (book == null) return [];
    final raw = book['words'] as List<dynamic>? ?? [];
    return raw.map((e) => Word.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> _switchTo(String id) async {
    await WordbookStorage.setCurrent(id);
    _load();
  }

  Future<void> _addBook() async {
    final nameCtrl = TextEditingController();
    final jsonCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加词书'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                    labelText: '词书名称', hintText: '如：人教版七上'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: jsonCtrl,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'JSON 内容',
                  hintText: '[{"word":"hello","meaning":"你好"}]',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('添加')),
        ],
      ),
    );

    if (ok != true) return;
    final name = nameCtrl.text.trim();
    if (name.isEmpty) return;

    try {
      final raw = jsonCtrl.text.trim();
      final list = jsonDecode(raw) as List<dynamic>;
      final words =
          list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (words.isEmpty) throw Exception('词书为空');
      await WordbookStorage.addBook(name, words);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('添加成功')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('添加失败：$e')),
        );
      }
    }
  }

  Future<void> _deleteBook(String id) async {
    if (id == WordbookStorage.defaultBookId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('默认词书不能删除')),
      );
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除词书'),
        content: const Text('删除后该词书将不可恢复。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('删除')),
        ],
      ),
    );
    if (confirm != true) return;
    await WordbookStorage.deleteBook(id);
    await _load();
  }

  Future<void> _renameBook(String id, String oldName) async {
    final ctrl = TextEditingController(text: oldName);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重命名词书'),
        content: TextField(controller: ctrl),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('保存')),
        ],
      ),
    );
    if (ok != true) return;
    final newName = ctrl.text.trim();
    if (newName.isEmpty) return;
    await WordbookStorage.renameBook(id, newName);
    await _load();
  }

  /// 存储模式对话框
  Future<void> _showModeDialog(String bookId) async {
    final words = await _getBookWords(bookId);
    final currentMode = await MyWordsStorage.getMode(bookId);
    final sizes = await MyWordsStorage.calcSizes(bookId, words);

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('存储模式'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _modeOption(
              title: '紧凑模式',
              size: sizes[1]!,
              desc: '无序号，全量填充。适合学得较多的词书。',
              selected: currentMode == 1,
            ),
            const SizedBox(height: 12),
            _modeOption(
              title: '兼容模式',
              size: sizes[0]!,
              desc: '带序号，只存学过的。适合刚起步的词书。',
              selected: currentMode == 0,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final best = await MyWordsStorage.autoChooseMode(bookId, words);
              await MyWordsStorage.switchMode(bookId, best, words);
              if (mounted) {
                Navigator.pop(context);
                _load();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('已自动切换到${best == 1 ? '紧凑' : '兼容'}模式')),
                );
              }
            },
            child: const Text('自动优化'),
          ),
          TextButton(
            onPressed: () async {
              await MyWordsStorage.switchMode(bookId, 1, words);
              if (mounted) {
                Navigator.pop(context);
                _load();
              }
            },
            child: const Text('用紧凑'),
          ),
          TextButton(
            onPressed: () async {
              await MyWordsStorage.switchMode(bookId, 0, words);
              if (mounted) {
                Navigator.pop(context);
                _load();
              }
            },
            child: const Text('用兼容'),
          ),
        ],
      ),
    );
  }

  Widget _modeOption({
    required String title,
    required int size,
    required String desc,
    required bool selected,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
          color: selected ? Colors.blue : Colors.grey.shade300,
          width: selected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (selected)
                const Icon(Icons.check_circle, color: Colors.blue, size: 18),
              if (selected) const SizedBox(width: 6),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              Text('$size 字符', style: const TextStyle(color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 4),
          Text(desc, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('词书管理')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                for (final entry in _books.entries)
                  _buildBookTile(entry.key, entry.value),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton.icon(
                    onPressed: _addBook,
                    icon: const Icon(Icons.add),
                    label: const Text('添加新词书'),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildBookTile(String id, Map<String, dynamic> book) {
    final name = book['name'] as String? ?? '未命名';
    final words = book['words'] as List<dynamic>? ?? [];
    final isCurrent = id == _currentId;

    return FutureBuilder<int>(
      future: MyWordsStorage.getMode(id),
      builder: (context, snapshot) {
        final mode = snapshot.data ?? 0;
        final modeLabel = mode == 1 ? '紧凑模式' : '兼容模式';
        return ListTile(
          leading: Icon(
            isCurrent ? Icons.check_circle : Icons.menu_book,
            color: isCurrent ? Colors.blue : null,
          ),
          title: Text(name),
          subtitle: Text('${words.length} 个单词 · $modeLabel'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isCurrent)
                TextButton(
                  onPressed: () => _switchTo(id),
                  child: const Text('切换'),
                ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'rename') _renameBook(id, name);
                  if (v == 'delete') _deleteBook(id);
                  if (v == 'mode') _showModeDialog(id);
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'mode', child: Text('存储模式')),
                  const PopupMenuItem(value: 'rename', child: Text('重命名')),
                  if (id != WordbookStorage.defaultBookId)
                    const PopupMenuItem(value: 'delete', child: Text('删除')),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

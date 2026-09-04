import 'package:flutter/material.dart';
import 'dart:convert';
import '../models/word.dart';
import '../data/wordbook_storage.dart';

class WordbookManagerScreen extends StatefulWidget {
  final List<Word> currentWords;
  final Function(List<Word>) onWordsChanged;

  const WordbookManagerScreen(
      {Key? key, required this.currentWords, required this.onWordsChanged})
      : super(key: key);

  @override
  State<WordbookManagerScreen> createState() => _WordbookManagerScreenState();
}

class _WordbookManagerScreenState extends State<WordbookManagerScreen> {
  late List<Word> _words = List.from(widget.currentWords);

  void _updateParent() {
    widget.onWordsChanged(_words);
    WordbookStorage.saveWordbook(_words); // 自动保存
  }

  // 手动添加单词
  void _addWordDialog() {
    final wordCtrl = TextEditingController();
    final phoneticCtrl = TextEditingController();
    final posCtrl = TextEditingController();
    final meaningCtrl = TextEditingController();
    final exampleCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加单词'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: wordCtrl,
                  decoration: const InputDecoration(labelText: '单词 *')),
              TextField(
                  controller: phoneticCtrl,
                  decoration: const InputDecoration(labelText: '音标')),
              TextField(
                  controller: posCtrl,
                  decoration: const InputDecoration(labelText: '词性')),
              TextField(
                  controller: meaningCtrl,
                  decoration: const InputDecoration(labelText: '释义 *')),
              TextField(
                  controller: exampleCtrl,
                  decoration: const InputDecoration(labelText: '例句')),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(
            onPressed: () {
              final word = wordCtrl.text.trim();
              final meaning = meaningCtrl.text.trim();
              if (word.isEmpty || meaning.isEmpty) return;
              final newWord = Word(
                word: word,
                phonetic: phoneticCtrl.text.trim(),
                pos: posCtrl.text.trim(),
                meaning: meaning,
                example: exampleCtrl.text.trim(),
              );
              setState(() {
                _words.add(newWord);
                _updateParent();
              });
              Navigator.pop(context);
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  // 导入 JSON
  void _importJson() {
    final jsonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导入 JSON'),
        content: TextField(
          controller: jsonCtrl,
          maxLines: 8,
          decoration: const InputDecoration(
              hintText: '粘贴 JSON 数组，例如 [{"word":"hello","meaning":"你好"}]'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(
            onPressed: () {
              try {
                final raw = jsonCtrl.text.trim();
                final list = jsonDecode(raw) as List<dynamic>;
                final imported = list
                    .map((e) => Word.fromJson(e as Map<String, dynamic>))
                    .toList();
                setState(() {
                  _words.addAll(imported);
                  _updateParent();
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('导入成功！')));
              } catch (e) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('JSON 格式错误')));
              }
            },
            child: const Text('导入'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('词书管理')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _addWordDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('添加单词'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _importJson,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('导入 JSON'),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: _words.isEmpty
                ? const Center(child: Text('暂无单词，请添加'))
                : ListView.builder(
                    itemCount: _words.length,
                    itemBuilder: (context, index) {
                      final word = _words[index];
                      return ListTile(
                        title: Text(word.word),
                        subtitle: Text(word.meaning),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () {
                            setState(() {
                              _words.removeAt(index);
                              _updateParent();
                            });
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

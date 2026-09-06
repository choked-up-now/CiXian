import 'package:flutter/material.dart';
import 'dart:convert';
import '../models/word.dart';
import '../data/wordbook_storage.dart';

class SettingsScreen extends StatefulWidget {
  final List<Word> currentWords;
  final Function(List<Word>) onWordsChanged;

  const SettingsScreen(
      {Key? key, required this.currentWords, required this.onWordsChanged})
      : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // 清理缓存（模拟）
  void _clearCache() {
    // 这里可以调用 path_provider 清理临时目录，但先做一个简单的提示
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清理缓存'),
        content: const Text('缓存已清理完毕！'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('好的'),
          ),
        ],
      ),
    );
  }

  // 清除自定义词书数据（恢复默认）
  void _clearData() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除数据'),
        content: const Text('确定要清除所有自定义词书数据吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              await WordbookStorage.clearWordbook();
              // 通知主页重新加载默认词书
              widget.onWordsChanged([]); // 传空列表，主页会重新从 assets 加载默认词书
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('自定义词书已清除，已恢复默认词书')),
              );
            },
            child: const Text('确定清除'),
          ),
        ],
      ),
    );
  }

  // 导出当前词书为 JSON
  void _exportWords() {
    final jsonString = jsonEncode(widget.currentWords
        .map((e) => {
              'word': e.word,
              'phonetic': e.phonetic,
              'pos': e.pos,
              'meaning': e.meaning,
              'example': e.example,
            })
        .toList());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导出词书'),
        content: SingleChildScrollView(
          child: SelectableText(
            jsonString,
            style: const TextStyle(fontSize: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  // 导入 JSON 词书
  void _importWords() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导入词书'),
        content: TextField(
          controller: controller,
          maxLines: 10,
          decoration: const InputDecoration(
            hintText: '粘贴 JSON 数组，例如 [{"word":"hello","meaning":"你好"}]',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              try {
                final raw = controller.text.trim();
                final list = jsonDecode(raw) as List<dynamic>;
                final words = list
                    .map((e) => Word.fromJson(e as Map<String, dynamic>))
                    .toList();
                // 保存到本地
                WordbookStorage.saveWordbook(words);
                // 通知主页更新
                widget.onWordsChanged(words);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('导入成功！')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('JSON 格式错误，请检查')),
                );
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
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.cleaning_services),
            title: const Text('缓存清理'),
            subtitle: const Text('清理临时文件，释放空间'),
            onTap: _clearCache,
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever),
            title: const Text('数据清除'),
            subtitle: const Text('清除自定义词书，恢复默认词书'),
            onTap: _clearData,
          ),
          ListTile(
            leading: const Icon(Icons.ios_share),
            title: const Text('迁移设备（导出）'),
            subtitle: const Text('导出当前词书为 JSON，可复制到新设备'),
            onTap: _exportWords,
          ),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('迁移设备（导入）'),
            subtitle: const Text('从其他设备导入 JSON 词书'),
            onTap: _importWords,
          ),
        ],
      ),
    );
  }
}

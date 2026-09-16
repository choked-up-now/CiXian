import 'package:flutter/material.dart';
import 'data/wordbook_loader.dart';
import 'data/wordbook_storage.dart';
import 'data/sync_manager.dart';
import 'models/word.dart';
import 'screens/word_list_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '词冼',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Word> _words = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // 云同步：如果已开启，启动时下载云端数据
    try {
      await SyncManager.downloadAndApply();
    } catch (_) {}

    await _loadWords();
  }

  Future<List<Word>> _loadWordsHelper() async {
    final custom = await WordbookStorage.loadWordbook();
    if (custom != null && custom.isNotEmpty) return custom;
    return await WordbookLoader.loadWordbook(
        'assets/wordbooks/waiyan_9_upper.json');
  }

  Future<void> _loadWords() async {
    final words = await _loadWordsHelper();
    setState(() {
      _words = words;
      _loading = false;
    });
  }

  void _updateWords(List<Word> newWords) {
    setState(() {
      if (newWords.isEmpty) {
        _loadWords();
      } else {
        _words = newWords;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return WordListScreen(words: _words, onWordsChanged: _updateWords);
  }
}

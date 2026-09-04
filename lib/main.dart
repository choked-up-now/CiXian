import 'package:flutter/material.dart';
import 'data/wordbook_loader.dart';
import 'data/wordbook_storage.dart';
import 'models/word.dart';
import 'screens/word_list_screen.dart';
import 'screens/wordbook_manager_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '词冼',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
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
    _loadWords();
  }

  Future<List<Word>> _loadWordsHelper() async {
    // 尝试加载自定义词书
    final custom = await WordbookStorage.loadWordbook();
    if (custom != null && custom.isNotEmpty) {
      return custom;
    }
    // 否则加载内置默认词书
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
      _words = newWords;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return WordListScreen(
      words: _words,
      onWordsChanged: _updateWords,
    );
  }
}

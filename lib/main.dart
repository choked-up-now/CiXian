import 'package:flutter/material.dart';
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
  Wordbook? _book;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // 云同步：如果已开启，启动时下载
    try {
      await SyncManager.downloadAndApply();
    } catch (_) {}

    await _loadBook();
  }

  Future<void> _loadBook() async {
    await WordbookStorage.ensureDefaultBook();
    final book = await WordbookStorage.loadCurrent();
    setState(() {
      _book = book;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _book == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return WordListScreen(
      book: _book!,
      onBookChanged: () async {
        await _loadBook();
      },
    );
  }
}

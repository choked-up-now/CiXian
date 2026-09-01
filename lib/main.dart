import 'package:flutter/material.dart';
import 'data/wordbook_loader.dart';
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
  late Future<List<Word>> _wordsFuture;

  @override
  void initState() {
    super.initState();
    // 加载默认词书（外研版九上）
    _wordsFuture = WordbookLoader.loadWordbook('assets/wordbooks/waiyan_9_upper.json');
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Word>>(
      future: _wordsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        } else if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('加载词书失败: ${snapshot.error}')),
          );
        } else {
          return WordListScreen(words: snapshot.data!);
        }
      },
    );
  }
}
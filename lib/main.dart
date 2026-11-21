// Copyright 2026 choked-up-now
// SPDX-License-Identifier: MulanPSL-2.0

import 'package:flutter/material.dart';
import 'data/wordbook_storage.dart';
import 'data/sync_manager.dart';
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
    // 云同步：失败或超时都不能阻塞进入首页
    try {
      await SyncManager.downloadAndApply()
          .timeout(const Duration(seconds: 12));
    } catch (_) {
      // 下次启动或手动同步会重试
    }
    if (!mounted) return;
    await _loadBook();
  }

  Future<void> _loadBook() async {
    await WordbookStorage.ensureDefaultBook();
    final book = await WordbookStorage.loadCurrent();
    if (!mounted) return;
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

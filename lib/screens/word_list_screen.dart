import 'package:flutter/material.dart';
import '../models/word.dart';

class WordListScreen extends StatelessWidget {
  final List<Word> words;

  const WordListScreen({Key? key, required this.words}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('词冼 · 九上外研版'),
      ),
      body: ListView.builder(
        itemCount: words.length,
        itemBuilder: (context, index) {
          final word = words[index];
          return ListTile(
            title: Text(
              word.word,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(word.meaning),
            trailing: const Icon(Icons.chevron_right),
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
    );
  }
}
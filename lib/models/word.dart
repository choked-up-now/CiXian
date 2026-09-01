class Word {
  final String word;
  final String phonetic;
  final String pos;
  final String meaning;
  final String example;

  Word({
    required this.word,
    this.phonetic = '',
    this.pos = '',
    required this.meaning,
    this.example = '',
  });

  factory Word.fromJson(Map<String, dynamic> json) {
    return Word(
      word: json['word'] as String,
      phonetic: json['phonetic'] ?? '',
      pos: json['pos'] ?? '',
      meaning: json['meaning'] as String,
      example: json['example'] ?? '',
    );
  }
}
class Word {
  final String word;
  final String phonetic;
  final String pos;
  final String meaning;
  final String example;
  final int index; // 在所属词书中的位置，-1 表示未知

  Word({
    required this.word,
    this.phonetic = '',
    this.pos = '',
    required this.meaning,
    this.example = '',
    this.index = -1,
  });

  factory Word.fromJson(Map<String, dynamic> json) {
    return Word(
      word: json['word'] as String,
      phonetic: json['phonetic'] ?? '',
      pos: json['pos'] ?? '',
      meaning: json['meaning'] as String,
      example: json['example'] ?? '',
      index: json['index'] ?? -1,
    );
  }

  Map<String, dynamic> toJson() => {
        'word': word,
        'phonetic': phonetic,
        'pos': pos,
        'meaning': meaning,
        'example': example,
      };

  Word copyWith({
    String? word,
    String? phonetic,
    String? pos,
    String? meaning,
    String? example,
    int? index,
  }) {
    return Word(
      word: word ?? this.word,
      phonetic: phonetic ?? this.phonetic,
      pos: pos ?? this.pos,
      meaning: meaning ?? this.meaning,
      example: example ?? this.example,
      index: index ?? this.index,
    );
  }
}

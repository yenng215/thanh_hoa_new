class QAPair {
  final String question;
  final String answer;

  QAPair({required this.question, required this.answer});

  factory QAPair.fromJson(Map<String, dynamic> json) {
    return QAPair(
      question: json['question'],
      answer: json['answer'],
    );
  }
}

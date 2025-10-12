class Question {
  String id;
  String text;
  String? imageUrl;
  String answer;

  Question({
    required this.id,
    required this.text,
    this.imageUrl,
    required this.answer,
  });
}

import 'package:acm_activity_comic_game_admin/models/question.dart';

class QuestionSet {
  String id;
  String title;
  List<Question> questions;

  QuestionSet({required this.id, required this.title, required this.questions});
}

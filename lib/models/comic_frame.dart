import 'package:acm_activity_comic_game_admin/models/comic_element.dart';

class ComicFrame {
  String id;
  int index;
  String imageUrl;
  List<ComicElement> elements;
  String audioUrl;

  ComicFrame({
    required this.id,
    required this.index,
    required this.imageUrl,
    required this.elements,
    required this.audioUrl,
  });
}

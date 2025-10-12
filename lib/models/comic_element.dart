import 'dart:ui';

import 'package:acm_activity_comic_game_admin/models/comic_animation.dart';

class ComicElement {
  String imageUrl;
  Offset position;
  List<ComicAnimation> animation;

  ComicElement({
    required this.imageUrl,
    required this.position,
    required this.animation,
  });
}

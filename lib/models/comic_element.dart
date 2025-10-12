import 'dart:ui';

import 'package:acm_activity_comic_game_admin/models/comic_animation.dart';

class ComicElement {
  String imageUrl;
  Offset position;
  double scale; // relative to frame size (0..1)
  List<ComicAnimation> animation;

  ComicElement({
    required this.imageUrl,
    required this.position,
    required this.scale,
    required this.animation,
  });
}

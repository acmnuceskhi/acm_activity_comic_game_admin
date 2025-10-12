import 'package:flutter/material.dart';

class ComicAnimation {
  List<Matrix4> transforms;
  List<double> durations; // in seconds

  ComicAnimation({required this.transforms, required this.durations});
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4;

class AnimationPlayerPage extends StatefulWidget {
  final String frameImageUrl;
  final Map<String, dynamic> element;

  const AnimationPlayerPage({
    super.key,
    required this.frameImageUrl,
    required this.element,
  });

  @override
  State<AnimationPlayerPage> createState() => _AnimationPlayerPageState();
}

class _AnimationPlayerPageState extends State<AnimationPlayerPage>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _animations = [];
  int _index = 0;
  late AnimationController _controller;
  Matrix4 _current = Matrix4.identity();
  Matrix4 _start = Matrix4.identity();
  Matrix4 _target = Matrix4.identity();
  final GlobalKey _frameKey = GlobalKey();
  double _frameW = 0, _frameH = 0, _frameLeft = 0, _frameTop = 0;
  double? _elemIntrinsicW;
  double? _elemIntrinsicH;

  @override
  void initState() {
    super.initState();
    final raw = widget.element['animation'];
    if (raw is List) {
      _animations = raw
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    _controller = AnimationController(vsync: this);
    _resolveElementIntrinsic();
    if (_animations.isNotEmpty) {
      _playNext();
    }
  }

  Matrix4 _matrixFromList(List<dynamic> l) {
    final nums = l.map((e) => (e as num).toDouble()).toList();
    return Matrix4(
      nums[0],
      nums[1],
      nums[2],
      nums[3],
      nums[4],
      nums[5],
      nums[6],
      nums[7],
      nums[8],
      nums[9],
      nums[10],
      nums[11],
      nums[12],
      nums[13],
      nums[14],
      nums[15],
    );
  }

  void _playNext() {
    if (_index >= _animations.length) return;
    final a = _animations[_index];
    final dur = (a['duration'] is num)
        ? (a['duration'] as num).toDouble()
        : ((a['seconds'] is num) ? (a['seconds'] as num).toDouble() : 1.0);
    final matRaw = a['matrix'];
    // translation values are stored as fractions of the displayed frame width/height
    final txFrac = (a['translateX'] is num)
        ? (a['translateX'] as num).toDouble()
        : 0.0;
    final tyFrac = (a['translateY'] is num)
        ? (a['translateY'] as num).toDouble()
        : 0.0;
    // if translation exists but we haven't measured the displayed frame size yet, wait a bit
    if ((txFrac != 0.0 || tyFrac != 0.0) && (_frameW == 0 || _frameH == 0)) {
      // schedule a retry after the next frame; measurement code in build will set _frameW/_frameH
      Future.delayed(const Duration(milliseconds: 40), _playNext);
      return;
    }
    final imgW = (_frameW > 0) ? _frameW : 320.0;
    final imgH = (_frameH > 0) ? _frameH : 320.0;
    final tx = txFrac * imgW;
    final ty = tyFrac * imgH;

    if (matRaw is List && matRaw.length == 16) {
      _start = _current.clone();
      _target = _matrixFromList(matRaw);
      // apply translation on top of the provided matrix so authored translateX/translateY are respected
      if (tx != 0.0 || ty != 0.0) {
        _target.translate(tx, ty);
      }

      _controller.duration = Duration(milliseconds: (dur * 1000).round());
      _controller.reset();
      _controller.addListener(_tick);
      _controller.forward().whenComplete(() {
        _controller.removeListener(_tick);
        _current = _target.clone();
        _index++;
        if (_index < _animations.length) {
          Future.delayed(const Duration(milliseconds: 100), _playNext);
        }
      });
    } else if ((tx != 0.0 || ty != 0.0)) {
      // no matrix provided but translation exists -> animate a pure translation
      _start = _current.clone();
      _target = Matrix4.identity();
      _target.translate(tx, ty);
      _controller.duration = Duration(milliseconds: (dur * 1000).round());
      _controller.reset();
      _controller.addListener(_tick);
      _controller.forward().whenComplete(() {
        _controller.removeListener(_tick);
        _current = _target.clone();
        _index++;
        if (_index < _animations.length) {
          Future.delayed(const Duration(milliseconds: 100), _playNext);
        }
      });
    } else {
      _index++;
      if (_index < _animations.length)
        Future.delayed(const Duration(milliseconds: 100), _playNext);
    }
  }

  void _tick() {
    final t = _controller.value;
    setState(() {
      _current = Matrix4.identity();
      // simple linear interpolation per entry
      for (var r = 0; r < 4; r++) {
        for (var c = 0; c < 4; c++) {
          final s = _start.entry(r, c);
          final e = _target.entry(r, c);
          _current.setEntry(r, c, s + (e - s) * t);
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Animation Player')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 320,
              height: 320,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final w = constraints.maxWidth;
                  final h = constraints.maxHeight;
                  // measure displayed frame image (BoxFit.contain)
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    final ctx = _frameKey.currentContext;
                    if (ctx != null) {
                      final size = ctx.size;
                      if (size != null) {
                        final newW = size.width;
                        final newH = size.height;
                        final newLeft = (w - newW) / 2.0;
                        final newTop = (h - newH) / 2.0;
                        if (newW != _frameW ||
                            newH != _frameH ||
                            newLeft != _frameLeft ||
                            newTop != _frameTop) {
                          setState(() {
                            _frameW = newW;
                            _frameH = newH;
                            _frameLeft = newLeft;
                            _frameTop = newTop;
                          });
                        }
                      }
                    }
                  });

                  // compute element display size based on element.scale and intrinsic aspect
                  final pos =
                      widget.element['position'] as Map<String, dynamic>? ??
                      {'x': 0.5, 'y': 0.5};
                  final nx = (pos['x'] is num)
                      ? (pos['x'] as num).toDouble()
                      : 0.5;
                  final ny = (pos['y'] is num)
                      ? (pos['y'] as num).toDouble()
                      : 0.5;
                  final elemScale = (widget.element['scale'] is num)
                      ? (widget.element['scale'] as num).toDouble()
                      : 0.2;

                  final base = (_frameW > 0 && _frameH > 0)
                      ? (_frameW < _frameH ? _frameW : _frameH)
                      : (w < h ? w : h);
                  final maxDim = (elemScale * base).clamp(8.0, base);

                  double elemW, elemH;
                  if (_elemIntrinsicW != null &&
                      _elemIntrinsicH != null &&
                      _elemIntrinsicW! > 0 &&
                      _elemIntrinsicH! > 0) {
                    final aspect = _elemIntrinsicW! / _elemIntrinsicH!;
                    if (aspect >= 1.0) {
                      elemW = maxDim;
                      elemH = maxDim / aspect;
                    } else {
                      elemH = maxDim;
                      elemW = maxDim * aspect;
                    }
                  } else {
                    elemW = maxDim;
                    elemH = maxDim;
                  }

                  // compute center-based pixel positions inside displayed frame image
                  final imgW = (_frameW > 0) ? _frameW : w;
                  final imgH = (_frameH > 0) ? _frameH : h;
                  final centerX = (nx * imgW).clamp(
                    elemW / 2.0,
                    imgW - elemW / 2.0,
                  );
                  final centerY = (ny * imgH).clamp(
                    elemH / 2.0,
                    imgH - elemH / 2.0,
                  );
                  final left = _frameLeft + centerX - elemW / 2.0;
                  final top = _frameTop + centerY - elemH / 2.0;

                  return Stack(
                    children: [
                      // frame image measured by key
                      Positioned.fill(
                        child: Center(
                          child: Image.network(
                            widget.frameImageUrl,
                            key: _frameKey,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      // transformed element positioned using saved normalized position and scale
                      Positioned(
                        left: left,
                        top: top,
                        width: elemW,
                        height: elemH,
                        child: Transform(
                          transform: _current,
                          alignment: Alignment.center,
                          child: Image.network(
                            widget.element['imageUrl'] as String? ?? '',
                            width: elemW,
                            height: elemH,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Playing ${_animations.length} animations, index: ${_index + 1}/${_animations.length}',
            ),
          ],
        ),
      ),
    );
  }

  void _resolveElementIntrinsic() {
    final imgUrl = widget.element['imageUrl'] as String?;
    if (imgUrl == null || imgUrl.isEmpty) return;
    final provider = NetworkImage(imgUrl);
    final stream = provider.resolve(const ImageConfiguration());
    stream.addListener(
      ImageStreamListener(
        (info, _) {
          final iw = info.image.width.toDouble();
          final ih = info.image.height.toDouble();
          if (_elemIntrinsicW != iw || _elemIntrinsicH != ih) {
            if (mounted)
              setState(() {
                _elemIntrinsicW = iw;
                _elemIntrinsicH = ih;
              });
          }
        },
        onError: (e, s) =>
            debugPrint('Failed to resolve element image size: $e'),
      ),
    );
  }
}

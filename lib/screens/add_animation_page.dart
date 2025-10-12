import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart' show Matrix4;

class AddAnimationPage extends StatefulWidget {
  final Map<String, dynamic>? existing;
  final String? previewImageUrl; // element image
  final String? frameImageUrl; // background frame image to show context
  final double? elemX; // normalized center x (0..1)
  final double? elemY; // normalized center y (0..1)
  final double? elemScale; // normalized scale used in AddElementPage

  const AddAnimationPage({
    super.key,
    this.existing,
    this.previewImageUrl,
    this.frameImageUrl,
    this.elemX,
    this.elemY,
    this.elemScale,
  });

  @override
  State<AddAnimationPage> createState() => _AddAnimationPageState();
}

class _AddAnimationPageState extends State<AddAnimationPage> {
  double _rotationDeg = 0.0;
  double _scale = 1.0;
  double _skewXDeg = 0.0;
  double _skewYDeg = 0.0;
  double _duration = 1.0;
  double _translateX = 0.0; // fraction of frame width (-0.5..0.5)
  double _translateY = 0.0; // fraction of frame height

  double? _frameIntrinsicW;
  double? _frameIntrinsicH;
  double? _elemIntrinsicW;
  double? _elemIntrinsicH;

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    if (ex != null) {
      if (ex['rotation'] is num) _rotationDeg = (ex['rotation'] as num).toDouble();
      if (ex['scale'] is num) _scale = (ex['scale'] as num).toDouble();
      if (ex['skewX'] is num) _skewXDeg = (ex['skewX'] as num).toDouble();
      if (ex['skewY'] is num) _skewYDeg = (ex['skewY'] as num).toDouble();
      if (ex['duration'] is num) _duration = (ex['duration'] as num).toDouble();
      if (ex['translateX'] is num) _translateX = (ex['translateX'] as num).toDouble();
      if (ex['translateY'] is num) _translateY = (ex['translateY'] as num).toDouble();
    }
    // resolve intrinsic sizes for frame and element images so we can place element accurately
    _resolveFrameIntrinsic();
    _resolveElemIntrinsic();
  }

  Matrix4 _computeMatrix() {
    final rotRad = _rotationDeg * (math.pi / 180.0);
    final skewXRad = _skewXDeg * (math.pi / 180.0);
    final skewYRad = _skewYDeg * (math.pi / 180.0);

    final skew = Matrix4.identity();
    // set skew entries using tangent of skew angle
    skew.setEntry(0, 1, math.tan(skewXRad));
    skew.setEntry(1, 0, math.tan(skewYRad));

    final m = Matrix4.identity();
    m.multiply(skew); // apply skew first
    m.rotateZ(rotRad);
    m.scale(_scale, _scale, 1.0);
  // translation will be applied later in the preview where we have pixel sizes
    return m;
  }

  @override
  Widget build(BuildContext context) {
    final m = _computeMatrix();
  // matrix list generated on save
    return Scaffold(
      appBar: AppBar(title: Text(widget.existing != null ? 'Edit Animation' : 'Add Animation')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(children: [
          // show frame as background with element positioned at its saved normalized center
          SizedBox(
            height: 220,
            child: LayoutBuilder(builder: (context, constraints) {
              final containerW = constraints.maxWidth;
              final containerH = constraints.maxHeight;

              // compute displayed frame size (BoxFit.contain) using intrinsic aspect when available
              double frameDispW = containerW;
              double frameDispH = containerH;
              if (_frameIntrinsicW != null && _frameIntrinsicH != null && _frameIntrinsicW! > 0 && _frameIntrinsicH! > 0) {
                final imgAspect = _frameIntrinsicW! / _frameIntrinsicH!;
                final contAspect = containerW / containerH;
                if (imgAspect > contAspect) {
                  // image is wider, limit by container width
                  frameDispW = containerW;
                  frameDispH = containerW / imgAspect;
                } else {
                  frameDispH = containerH;
                  frameDispW = containerH * imgAspect;
                }
              } else {
                // fallback: fit to container
                frameDispW = containerW;
                frameDispH = containerH;
              }

              final frameLeft = (containerW - frameDispW) / 2.0;
              final frameTop = (containerH - frameDispH) / 2.0;

              // compute element displayed size (preserve intrinsic aspect if available)
              final base = (frameDispW < frameDispH) ? frameDispW : frameDispH;
              final elemBase = (widget.elemScale ?? 0.2) * base;
              double elemW = elemBase;
              double elemH = elemBase;
              if (_elemIntrinsicW != null && _elemIntrinsicH != null && _elemIntrinsicW! > 0 && _elemIntrinsicH! > 0) {
                final aspect = _elemIntrinsicW! / _elemIntrinsicH!;
                if (aspect >= 1.0) {
                  elemW = elemBase;
                  elemH = elemBase / aspect;
                } else {
                  elemH = elemBase;
                  elemW = elemBase * aspect;
                }
              }

              // compute element center inside frame from normalized coords
              final nx = (widget.elemX ?? 0.5).clamp(0.0, 1.0);
              final ny = (widget.elemY ?? 0.5).clamp(0.0, 1.0);
              final centerX = (nx * frameDispW).clamp(elemW / 2.0, frameDispW - elemW / 2.0);
              final centerY = (ny * frameDispH).clamp(elemH / 2.0, frameDispH - elemH / 2.0);
              final left = frameLeft + centerX - elemW / 2.0;
              final top = frameTop + centerY - elemH / 2.0;

              // compute pixel translation from fraction sliders
              final tx = _translateX * frameDispW;
              final ty = _translateY * frameDispH;

              // apply translation after rotation/scale/skew so movement is in parent's coordinates
              final m2 = _computeMatrix().clone();
              m2.translate(tx, ty);

              return Stack(children: [
                // frame
                Positioned.fill(child: Center(child: widget.frameImageUrl != null ? Image.network(widget.frameImageUrl!, fit: BoxFit.contain) : const SizedBox.shrink())),
                // element at saved position with transform applied
                if (widget.previewImageUrl != null)
                  Positioned(left: left, top: top, width: elemW, height: elemH, child: Transform(transform: m2, alignment: Alignment.center, child: Image.network(widget.previewImageUrl!, fit: BoxFit.contain))),
              ]);
            }),
          ),

          const SizedBox(height: 12),
          Row(children: [const Text('Rotation'), Expanded(child: Slider(value: _rotationDeg, min: -180, max: 180, onChanged: (v) => setState(() => _rotationDeg = v))), Text('${_rotationDeg.toStringAsFixed(0)}\\u00b0')]),
          Row(children: [const Text('Scale'), Expanded(child: Slider(value: _scale, min: 0.1, max: 3.0, onChanged: (v) => setState(() => _scale = v))), Text(_scale.toStringAsFixed(2))]),
          Row(children: [const Text('Skew X'), Expanded(child: Slider(value: _skewXDeg, min: -45, max: 45, onChanged: (v) => setState(() => _skewXDeg = v))), Text('${_skewXDeg.toStringAsFixed(0)}\\u00b0')]),
          Row(children: [const Text('Skew Y'), Expanded(child: Slider(value: _skewYDeg, min: -45, max: 45, onChanged: (v) => setState(() => _skewYDeg = v))), Text('${_skewYDeg.toStringAsFixed(0)}\\u00b0')]),
          Row(children: [const Text('Translate X'), Expanded(child: Slider(value: _translateX, min: -0.5, max: 0.5, onChanged: (v) => setState(() => _translateX = v))), Text(_translateX.toStringAsFixed(2))]),
          Row(children: [const Text('Translate Y'), Expanded(child: Slider(value: _translateY, min: -0.5, max: 0.5, onChanged: (v) => setState(() => _translateY = v))), Text(_translateY.toStringAsFixed(2))]),
          Row(children: [const Text('Duration (s)'), Expanded(child: Slider(value: _duration, min: 0.05, max: 10.0, onChanged: (v) => setState(() => _duration = v))), Text(_duration.toStringAsFixed(2))]),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: () {
            // return matrix list + duration + meta
            final ml = List<double>.generate(16, (i) => m.storage[i]);
            Navigator.of(context).pop({
              'matrix': ml,
              'duration': _duration,
              'rotation': _rotationDeg,
              'scale': _scale,
              'skewX': _skewXDeg,
              'skewY': _skewYDeg,
              'translateX': _translateX,
              'translateY': _translateY,
            });
          }, child: const Text('Save')),
        ]),
      ),
    );
  }

  void _resolveFrameIntrinsic() {
    final url = widget.frameImageUrl;
    if (url == null || url.isEmpty) return;
    final provider = NetworkImage(url);
    final stream = provider.resolve(const ImageConfiguration());
    stream.addListener(ImageStreamListener((info, _) {
      final iw = info.image.width.toDouble();
      final ih = info.image.height.toDouble();
      if (_frameIntrinsicW != iw || _frameIntrinsicH != ih) {
        if (mounted) setState(() {
          _frameIntrinsicW = iw;
          _frameIntrinsicH = ih;
        });
      }
    }, onError: (e, s) => debugPrint('Failed to resolve frame image size: $e')));
  }

  void _resolveElemIntrinsic() {
    final url = widget.previewImageUrl;
    if (url == null || url.isEmpty) return;
    final provider = NetworkImage(url);
    final stream = provider.resolve(const ImageConfiguration());
    stream.addListener(ImageStreamListener((info, _) {
      final iw = info.image.width.toDouble();
      final ih = info.image.height.toDouble();
      if (_elemIntrinsicW != iw || _elemIntrinsicH != ih) {
        if (mounted) setState(() {
          _elemIntrinsicW = iw;
          _elemIntrinsicH = ih;
        });
      }
    }, onError: (e, s) => debugPrint('Failed to resolve element image size: $e')));
  }
}

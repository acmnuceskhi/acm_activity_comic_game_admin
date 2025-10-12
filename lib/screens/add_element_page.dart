import 'dart:typed_data';

import 'package:acm_activity_comic_game_admin/services/storage_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'animation_player_page.dart';
import 'add_animation_page.dart';
import 'package:flutter/material.dart';

class AddElementPage extends StatefulWidget {
  final String frameId;
  final String frameImageUrl;
  final Map<String, dynamic>? existingElement;

  const AddElementPage({
    super.key,
    required this.frameId,
    required this.frameImageUrl,
    this.existingElement,
  });

  @override
  State<AddElementPage> createState() => _AddElementPageState();
}

class _AddElementPageState extends State<AddElementPage> {
  final _storage = StorageService();
  Uint8List? _bytes;
  String? _filename;
  String? _uploadedImageUrl;
  double _x = 0.5;
  double _y = 0.5;
  double _scale = 0.2;
  bool _busy = false;
  final GlobalKey _imageKey = GlobalKey();
  double _imageW = 0;
  double _imageH = 0;
  double _imageLeft = 0;
  double _imageTop = 0;
  double? _elemIntrinsicW;
  double? _elemIntrinsicH;
  List<Map<String, dynamic>> _animations = [];

  Future<void> _pickElementImage() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (res == null || res.files.isEmpty) return;
    final f = res.files.first;
    setState(() {
      _bytes = f.bytes;
      _filename = f.name;
      _uploadedImageUrl = null;
    });
    _resolveElementIntrinsic();
  }

  Future<void> _uploadAndSave() async {
    setState(() => _busy = true);
    try {
      String imageUrl;
      String storagePath;

      if (_bytes == null && widget.existingElement != null) {
        // reuse existing image if user didn't pick a new one
        imageUrl = widget.existingElement!['imageUrl'] as String? ?? '';
        storagePath =
            widget.existingElement!['imageStoragePath'] as String? ?? '';
      } else {
        if (_bytes == null || _filename == null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Pick an image first')));
          if (mounted) setState(() => _busy = false);
          return;
        }
        final up = await _storage.uploadTempImage(
          bytes: _bytes!,
          filename: _filename!,
        );
        imageUrl = up['downloadUrl']!;
        storagePath = up['storagePath']!;
      }

      // create element object
      final element = {
        'imageUrl': imageUrl,
        'imageStoragePath': storagePath,
        'position': {'x': _x, 'y': _y},
        'scale': _scale,
        'animation': _animations,
      };

      final frameRef = FirebaseFirestore.instance
          .collection('comic_game')
          .doc('frames')
          .collection('frames')
          .doc(widget.frameId);

      if (widget.existingElement != null) {
        // remove old element and add updated one
        await frameRef.update({
          'elements': FieldValue.arrayRemove([widget.existingElement]),
        });
        await frameRef.update({
          'elements': FieldValue.arrayUnion([element]),
        });
      } else {
        await frameRef.update({
          'elements': FieldValue.arrayUnion([element]),
        });
      }

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void initState() {
    super.initState();
    final ex = widget.existingElement;
    if (ex != null) {
      debugPrint('AddElementPage.initState received existingElement: $ex');
      // parse safely without assuming exact types from Firestore
      final img = ex['imageUrl'];
      if (img is String) _uploadedImageUrl = img;

      final posRaw = ex['position'];
      if (posRaw is Map) {
        final px = posRaw['x'];
        final py = posRaw['y'];
        if (px is num) _x = px.toDouble();
        if (py is num) _y = py.toDouble();
      }

      final sc = ex['scale'];
      if (sc is num) _scale = sc.toDouble();
      _resolveElementIntrinsic();
      final rawAn = ex['animation'];
      if (rawAn is List) {
        _animations = rawAn.map((e) {
          if (e is Map) return Map<String, dynamic>.from(e);
          return <String, dynamic>{};
        }).toList();
      }
    }
  }

  // animations are now edited via AddAnimationPage

  void _resolveElementIntrinsic() {
    ImageProvider? provider;
    if (_bytes != null) {
      provider = MemoryImage(_bytes!);
    } else if (_uploadedImageUrl != null && _uploadedImageUrl!.isNotEmpty) {
      provider = NetworkImage(_uploadedImageUrl!);
    }
    if (provider == null) return;
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
        onError: (err, stack) {
          debugPrint('Failed to resolve element image intrinsic size: $err');
        },
      ),
    );
  }

  Map<String, dynamic> _buildPreviewElementWithAnimations() {
    return {
      'imageUrl':
          _uploadedImageUrl ??
          (widget.existingElement != null
              ? (widget.existingElement!['imageUrl'] as String? ?? '')
              : ''),
      'imageStoragePath': widget.existingElement != null
          ? (widget.existingElement!['imageStoragePath'] as String? ?? '')
          : '',
      'position': {'x': _x, 'y': _y},
      'scale': _scale,
      'animation': _animations,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existingElement != null ? 'Edit Element' : 'Add Element',
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            if (widget.frameImageUrl.isNotEmpty)
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final w = constraints.maxWidth;
                    final h = constraints.maxHeight;

                    // measure displayed image size (BoxFit.contain) via _imageKey after layout
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      final ctx = _imageKey.currentContext;
                      if (ctx != null) {
                        final size = ctx.size;
                        if (size != null) {
                          final newW = size.width;
                          final newH = size.height;
                          final newLeft = (w - newW) / 2.0;
                          final newTop = (h - newH) / 2.0;
                          if (newW != _imageW ||
                              newH != _imageH ||
                              newLeft != _imageLeft ||
                              newTop != _imageTop) {
                            setState(() {
                              _imageW = newW;
                              _imageH = newH;
                              _imageLeft = newLeft;
                              _imageTop = newTop;
                            });
                          }
                        }
                      }
                    });

                    // element size will be relative to the smaller dimension of the displayed image
                    final base = (_imageW > 0 && _imageH > 0)
                        ? (_imageW < _imageH ? _imageW : _imageH)
                        : (w < h ? w : h);
                    final maxDim = (_scale * base).clamp(8.0, base);

                    // determine element width/height preserving intrinsic aspect ratio when available
                    double elemW, elemH;
                    if (_elemIntrinsicW != null &&
                        _elemIntrinsicH != null &&
                        _elemIntrinsicW! > 0 &&
                        _elemIntrinsicH! > 0) {
                      final aspect = _elemIntrinsicW! / _elemIntrinsicH!; // w/h
                      if (aspect >= 1.0) {
                        // width is the limiting dimension
                        elemW = maxDim;
                        elemH = maxDim / aspect;
                      } else {
                        // height is the limiting dimension
                        elemH = maxDim;
                        elemW = maxDim * aspect;
                      }
                    } else {
                      // fallback to square element if intrinsic unknown
                      elemW = maxDim;
                      elemH = maxDim;
                    }

                    // compute center-based placement: sliders represent center normalized (0..1)
                    final imgW = (_imageW > 0) ? _imageW : w;
                    final imgH = (_imageH > 0) ? _imageH : h;

                    final minCenterX = elemW / 2.0;
                    final maxCenterX = (imgW - elemW / 2.0).clamp(
                      minCenterX,
                      imgW,
                    );
                    var centerX = (_x * imgW).clamp(minCenterX, maxCenterX);

                    final minCenterY = elemH / 2.0;
                    final maxCenterY = (imgH - elemH / 2.0).clamp(
                      minCenterY,
                      imgH,
                    );
                    var centerY = (_y * imgH).clamp(minCenterY, maxCenterY);

                    // if clamped, update normalized _x/_y so saved values reflect actual clamped center
                    final newX = (imgW > 0) ? (centerX / imgW) : _x;
                    final newY = (imgH > 0) ? (centerY / imgH) : _y;
                    if ((newX - _x).abs() > 0.0001 ||
                        (newY - _y).abs() > 0.0001) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted)
                          setState(() {
                            _x = newX;
                            _y = newY;
                          });
                      });
                    }

                    final left = _imageLeft + centerX - elemW / 2.0;
                    final top = _imageTop + centerY - elemH / 2.0;

                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // center the image in the available area and give it the key to measure actual display size
                        Positioned.fill(
                          child: Center(
                            child: Image.network(
                              widget.frameImageUrl,
                              key: _imageKey,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        if (_uploadedImageUrl != null)
                          Positioned(
                            left: left,
                            top: top,
                            width: elemW,
                            height: elemH,
                            child: Image.network(
                              _uploadedImageUrl!,
                              fit: BoxFit.contain,
                            ),
                          ),
                        if (_uploadedImageUrl == null && _bytes != null)
                          Positioned(
                            left: left,
                            top: top,
                            width: elemW,
                            height: elemH,
                            child: Image.memory(_bytes!, fit: BoxFit.contain),
                          ),
                      ],
                    );
                  },
                ),
              )
            else
              const SizedBox.shrink(),

            const SizedBox(height: 12),

            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _pickElementImage,
                  icon: const Icon(Icons.image),
                  label: const Text('Pick image'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _filename ??
                        (_uploadedImageUrl != null
                            ? 'Using existing image'
                            : 'No element picked'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Animations manager
            if (_animations.isNotEmpty) ...[
              const Text(
                'Animations',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 120,
                child: ListView.builder(
                  itemCount: _animations.length,
                  itemBuilder: (c, ai) {
                    final a = _animations[ai];
                    final dur = a['duration'] ?? a['seconds'] ?? 1;
                    return ListTile(
                      title: Text('Animation #${ai + 1} - ${dur}s'),
                      subtitle: Text(
                        (a['matrix'] is List) ? 'matrix[16]' : 'invalid',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.play_arrow),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => AnimationPlayerPage(
                                    frameImageUrl: widget.frameImageUrl,
                                    element:
                                        _buildPreviewElementWithAnimations(),
                                  ),
                                ),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () async {
                              final previewUrl =
                                  _uploadedImageUrl ??
                                  (widget.existingElement != null
                                      ? (widget.existingElement!['imageUrl']
                                                as String? ??
                                            '')
                                      : '');
                              final res = await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => AddAnimationPage(
                                    existing: a,
                                    previewImageUrl: previewUrl,
                                    frameImageUrl: widget.frameImageUrl,
                                    elemX: _x,
                                    elemY: _y,
                                    elemScale: _scale,
                                  ),
                                ),
                              );
                              if (res != null && res is Map<String, dynamic>)
                                setState(() => _animations[ai] = res);
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () =>
                                setState(() => _animations.removeAt(ai)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],

            Row(
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add animation'),
                  onPressed: () async {
                    final previewUrl =
                        _uploadedImageUrl ??
                        (widget.existingElement != null
                            ? (widget.existingElement!['imageUrl'] as String? ??
                                  '')
                            : '');
                    final res = await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AddAnimationPage(
                          previewImageUrl: previewUrl,
                          frameImageUrl: widget.frameImageUrl,
                          elemX: _x,
                          elemY: _y,
                          elemScale: _scale,
                        ),
                      ),
                    );
                    if (res != null && res is Map<String, dynamic>)
                      setState(() => _animations.add(res));
                  },
                ),
              ],
            ),

            const SizedBox(height: 12),

            Column(
              children: [
                Row(
                  children: [
                    const Text('X:'),
                    Expanded(
                      child: Slider(
                        value: _x,
                        onChanged: (v) => setState(() => _x = v),
                        min: 0,
                        max: 1,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Text('Y:'),
                    Expanded(
                      child: Slider(
                        value: _y,
                        onChanged: (v) => setState(() => _y = v),
                        min: 0,
                        max: 1,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Text('Scale:'),
                    Expanded(
                      child: Slider(
                        value: _scale,
                        onChanged: (v) => setState(() => _scale = v),
                        min: 0.02,
                        max: 1.0,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),
            if (_busy) const CircularProgressIndicator(),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _busy ? null : _uploadAndSave,
                    child: Text(
                      widget.existingElement != null
                          ? 'Save Element'
                          : 'Add Element',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:acm_activity_comic_game_admin/services/storage_service.dart';
import 'package:acm_activity_comic_game_admin/utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'elements_manager_page.dart';

class FramePage extends StatefulWidget {
  final String frameId;

  const FramePage({super.key, required this.frameId});

  @override
  State<FramePage> createState() => _FramePageState();
}

class _FramePageState extends State<FramePage> {
  final _framesRef = FirebaseFirestore.instance
      .collection('comic_game')
      .doc('frames')
      .collection('frames');
  final _musicRef = FirebaseFirestore.instance
      .collection('comic_game')
      .doc('music')
      .collection('music');
  final _storage = StorageService();
  final _player = AudioPlayer();
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _player.onPlayerComplete.listen((_) {
      setState(() => _isPlaying = false);
    });
  }

  Future<void> _showQuestionPicker(BuildContext context, String frameId) async {
    final setsRef = FirebaseFirestore.instance
        .collection('comic_game')
        .doc('questions')
        .collection('sets');
    await showDialog<void>(
      context: context,
      builder: (c) {
        return AlertDialog(
          title: const Text('Select a question set to assign to this frame'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: StreamBuilder<QuerySnapshot>(
              stream: setsRef.orderBy('title').snapshots(),
              builder: (context, snap) {
                if (snap.hasError)
                  return Center(child: Text('Error: ${snap.error}'));
                if (!snap.hasData)
                  return const Center(child: CircularProgressIndicator());
                final docs = snap.data!.docs;
                if (docs.isEmpty)
                  return const Center(child: Text('No question sets'));

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, si) {
                    final setDoc = docs[si];
                    final setData = setDoc.data() as Map<String, dynamic>;
                    final title = setData['title'] as String? ?? 'Untitled';
                    final questions = (setData['questions'] as List?) ?? [];
                    return ListTile(
                      title: Text(title),
                      subtitle: Text('${questions.length} questions'),
                      trailing: ElevatedButton.icon(
                        icon: const Icon(Icons.layers),
                        label: const Text('Assign set'),
                        onPressed: () async {
                          await _framesRef.doc(frameId).set({
                            'questionSetId': setDoc.id,
                            'assignedQuestion': FieldValue.delete(),
                          }, SetOptions(merge: true));
                          if (!mounted) return;
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Question set assigned to frame'),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(c).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Frame')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _framesRef.doc(widget.frameId).snapshots(),
        builder: (context, frameSnap) {
          if (frameSnap.hasError)
            return Center(child: Text('Error: ${frameSnap.error}'));
          if (!frameSnap.hasData)
            return const Center(child: CircularProgressIndicator());
          final data = frameSnap.data!.data() as Map<String, dynamic>?;
          if (data == null) return const Center(child: Text('Frame not found'));

          final currentAudioUrl = data['audioUrl'] as String? ?? '';
          final currentImageUrl = data['imageUrl'] as String? ?? '';

          return Padding(
            padding: EdgeInsets.symmetric(
              horizontal:
                  MediaQuery.of(context).size.width *
                  (isLandscape(context) ? 0.2 : 0.1),
              vertical: 16,
            ),
            child: Column(
              children: [
                if (currentImageUrl.isNotEmpty)
                  Image.network(
                    currentImageUrl,
                    height: MediaQuery.of(context).size.height * 0.4,
                    fit: BoxFit.cover,
                  ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.photo_camera_back),
                      label: const Text('Change image'),
                      onPressed: () async {
                        final res = await FilePicker.platform.pickFiles(
                          type: FileType.image,
                          withData: true,
                        );
                        if (res == null || res.files.isEmpty) return;
                        final f = res.files.first;
                        final bytes = f.bytes;
                        final name = f.name;
                        if (bytes == null) return;
                        // upload image and set imageUrl
                        try {
                          final up = await _storage.uploadTempImage(
                            bytes: bytes,
                            filename: name,
                          );
                          final imageUrl = up['downloadUrl']!;
                          final storagePath = up['storagePath']!;
                          await _framesRef.doc(widget.frameId).set({
                            'imageUrl': imageUrl,
                            'imageStoragePath': storagePath,
                          }, SetOptions(merge: true));
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Image updated')),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Upload error: $e')),
                          );
                        }
                      },
                    ),
                  ],
                ),
                Builder(
                  builder: (context) {
                    final musicId = data['musicId'] as String?;
                    if (musicId == null || musicId.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          currentAudioUrl.isNotEmpty
                              ? currentAudioUrl
                              : 'No music selected.',
                        ),
                      );
                    }

                    return FutureBuilder(
                      future: _musicRef.doc(musicId).get(),
                      builder: (ctx, musSnap) {
                        if (musSnap.hasError)
                          return Text('Error: ${musSnap.error}');
                        if (!musSnap.hasData) return const Text('Loading...');
                        final mdata =
                            musSnap.data!.data() as Map<String, dynamic>?;
                        final mTitle = mdata?['title'] as String? ?? 'Untitled';
                        final mUrl =
                            mdata?['audioUrl'] as String? ?? currentAudioUrl;

                        return ListTile(
                          title: Text(
                            mTitle,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            mUrl,
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  _isPlaying ? Icons.pause : Icons.play_arrow,
                                ),
                                onPressed: currentAudioUrl.isEmpty
                                    ? null
                                    : () async {
                                        if (_isPlaying) {
                                          await _player.pause();
                                          setState(() => _isPlaying = false);
                                        } else {
                                          try {
                                            await _player.play(
                                              UrlSource(currentAudioUrl),
                                            );
                                            setState(() => _isPlaying = true);
                                          } catch (e) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Play error: $e',
                                                  ),
                                                ),
                                              );
                                            }
                                          }
                                        }
                                      },
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.library_music),
                        label: const Text('Select music'),
                        onPressed: () =>
                            _showMusicPicker(context, currentAudioUrl),
                      ),
                      const SizedBox(width: 12),
                      TextButton(
                        onPressed: () async {
                          // remove assigned music
                          await _framesRef.doc(widget.frameId).set({
                            'audioUrl': '',
                            'audioStoragePath': '',
                            'musicId': FieldValue.delete(),
                          }, SetOptions(merge: true));
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Music removed')),
                          );
                        },
                        child: const Text('Remove assigned music'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add_box),
                        label: const Text('Manage elements'),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  ElementsManagerPage(frameId: widget.frameId),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Assigned question set card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Builder(
                              builder: (context) {
                                final qSetId = data['questionSetId'] as String?;
                                if (qSetId == null || qSetId.isEmpty) {
                                  return const Text('No question set assigned');
                                }
                                final setsRef = FirebaseFirestore.instance
                                    .collection('comic_game')
                                    .doc('questions')
                                    .collection('sets');
                                return FutureBuilder<DocumentSnapshot>(
                                  future: setsRef.doc(qSetId).get(),
                                  builder: (ctx, snap) {
                                    if (snap.hasError)
                                      return const Text('Error');
                                    if (!snap.hasData)
                                      return const Text('Loading...');
                                    final sdata =
                                        snap.data!.data()
                                            as Map<String, dynamic>?;
                                    final title =
                                        sdata?['title'] as String? ??
                                        'Untitled set';
                                    final questions =
                                        (sdata?['questions'] as List?) ?? [];
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Assigned question set: $title',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text('${questions.length} questions'),
                                      ],
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ElevatedButton(
                                onPressed: () => _showQuestionPicker(
                                  context,
                                  widget.frameId,
                                ),
                                child: const Text('Replace'),
                              ),
                              const SizedBox(height: 6),
                              TextButton(
                                onPressed: () async {
                                  await _removeQuestionSet(widget.frameId);
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Question set removed from frame',
                                      ),
                                    ),
                                  );
                                },
                                child: const Text('Remove'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _showMusicPicker(
    BuildContext context,
    String currentAudioUrl,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (c) {
        return AlertDialog(
          title: const Text('Select music'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: StreamBuilder<QuerySnapshot>(
              stream: _musicRef.orderBy('index').snapshots(),
              builder: (context, musSnap) {
                if (musSnap.hasError)
                  return Center(child: Text('Error: ${musSnap.error}'));
                if (!musSnap.hasData)
                  return const Center(child: CircularProgressIndicator());
                final docs = musSnap.data!.docs;
                if (docs.isEmpty)
                  return const Center(child: Text('No music available'));

                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final m = docs[i].data() as Map<String, dynamic>;
                    final title = m['title'] as String? ?? 'Untitled';
                    final audioUrl = m['audioUrl'] as String? ?? '';
                    final storagePath = m['storagePath'] as String? ?? '';
                    final id = docs[i].id;

                    final selected = audioUrl == currentAudioUrl;

                    return ListTile(
                      title: Text(title),
                      subtitle: Text(audioUrl),
                      trailing: selected ? const Icon(Icons.check) : null,
                      onTap: () async {
                        // if there is existing audio assigned, consider leaving it (or deleting in later change)
                        await _framesRef.doc(widget.frameId).set({
                          'audioUrl': audioUrl,
                          'audioStoragePath': storagePath,
                          'musicId': id,
                        }, SetOptions(merge: true));
                        if (!mounted) return;
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Assigned')),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(c).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _removeQuestionSet(String frameId) async {
    await _framesRef.doc(frameId).set({
      'questionSetId': FieldValue.delete(),
      'assignedQuestion': FieldValue.delete(),
    }, SetOptions(merge: true));
  }

  @override
  void dispose() {
    _player.stop();
    _player.dispose();
    super.dispose();
  }
}

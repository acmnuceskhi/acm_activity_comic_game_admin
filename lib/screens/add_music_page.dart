import 'dart:typed_data';

import 'package:acm_activity_comic_game_admin/services/storage_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class AddMusicPage extends StatefulWidget {
  final String? existingId;
  final String? existingTitle;
  final String? existingAudioUrl;
  final String? existingStoragePath;

  const AddMusicPage({
    super.key,
    this.existingId,
    this.existingTitle,
    this.existingAudioUrl,
    this.existingStoragePath,
  });

  @override
  State<AddMusicPage> createState() => _AddMusicPageState();
}

class _AddMusicPageState extends State<AddMusicPage> {
  final _titleCtl = TextEditingController();
  Uint8List? _bytes;
  String? _filename;
  bool _busy = false;
  final _storage = StorageService();

  @override
  void initState() {
    super.initState();
    _titleCtl.text = widget.existingTitle ?? '';
  }

  @override
  void dispose() {
    _titleCtl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'ogg', 'm4a'],
      withData: true,
    );
    if (res == null || res.files.isEmpty) return;
    final f = res.files.first;
    setState(() {
      _bytes = f.bytes;
      _filename = f.name;
    });
    debugPrint('AddMusicPage: picked file ${f.name} size=${f.size}');
  }

  Future<void> _save() async {
    final title = _titleCtl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter a title')));
      return;
    }

    setState(() => _busy = true);
    try {
      String audioUrl = widget.existingAudioUrl ?? '';
      String storagePath = widget.existingStoragePath ?? '';

      if (_bytes != null && _filename != null) {
        final up = await _storage.uploadTempAudio(
          bytes: _bytes!,
          filename: _filename!,
        );
        audioUrl = up['downloadUrl']!;
        storagePath = up['storagePath']!;
      }

      if (widget.existingId != null) {
        // update existing doc
        final docRef = FirebaseFirestore.instance
            .collection('comic_game')
            .doc('music')
            .collection('music')
            .doc(widget.existingId);
        await docRef.set({
          'title': title,
          'audioUrl': audioUrl,
          'storagePath': storagePath,
        }, SetOptions(merge: true));
      } else {
        await _storage.createMusicDoc(
          title: title,
          audioUrl: audioUrl,
          storagePath: storagePath,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e, st) {
      debugPrint('AddMusicPage._save: ERROR -> $e\n$st');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final existing =
        widget.existingAudioUrl != null && widget.existingAudioUrl!.isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: Text(existing ? 'Edit Music' : 'Add Music')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            TextField(
              controller: _titleCtl,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _pickFile,
                  icon: const Icon(Icons.audiotrack),
                  label: const Text('Pick audio'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _filename ??
                        (existing
                            ? 'Using existing audio'
                            : 'No file selected'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_busy) const CircularProgressIndicator(),
            const Spacer(),
            ElevatedButton(
              onPressed: _busy ? null : _save,
              child: Text(existing ? 'Save' : 'Add Music'),
            ),
          ],
        ),
      ),
    );
  }
}

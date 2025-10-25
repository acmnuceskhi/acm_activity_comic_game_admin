import 'dart:typed_data';

import 'package:acm_activity_comic_game_admin/services/storage_service.dart';
import 'package:acm_activity_comic_game_admin/utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class AddQuestionPage extends StatefulWidget {
  final Map<String, dynamic>? existing;
  final String setId;

  const AddQuestionPage({super.key, this.existing, required this.setId});

  @override
  State<AddQuestionPage> createState() => _AddQuestionPageState();
}

class _AddQuestionPageState extends State<AddQuestionPage> {
  final _textCtrl = TextEditingController();
  final _answerCtrl = TextEditingController();
  Uint8List? _bytes;
  String? _filename;
  String? _uploadedImageUrl;
  bool _busy = false;
  final _storage = StorageService();

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    if (ex != null) {
      _textCtrl.text = ex['text'] as String? ?? '';
      _answerCtrl.text = ex['answer'] as String? ?? '';
      final img = ex['imageUrl'] as String?;
      if (img != null && img.isNotEmpty) _uploadedImageUrl = img;
    }
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _answerCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
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
  }

  Future<void> _save() async {
    final text = _textCtrl.text.trim();
    final answer = _answerCtrl.text.trim();
    if (text.isEmpty || answer.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Question text and answer required')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      String imageUrl = _uploadedImageUrl ?? '';
      String storagePath = '';
      if (_bytes != null && _filename != null) {
        final up = await _storage.uploadTempImage(
          bytes: _bytes!,
          filename: _filename!,
        );
        imageUrl = up['downloadUrl']!;
        storagePath = up['storagePath']!;
      }

      final question = {
        'id': widget.existing != null
            ? (widget.existing!['id'] as String? ?? '')
            : DateTime.now().microsecondsSinceEpoch.toString(),
        'text': text,
        'imageUrl': imageUrl,
        'imageStoragePath': storagePath,
        'answer': answer,
      };

      final setRef = FirebaseFirestore.instance
          .collection('comic_game')
          .doc('questions')
          .collection('sets')
          .doc(widget.setId);
      final snap = await setRef.get();
      if (!snap.exists) throw 'Question set not found';
      final data = snap.data() as Map<String, dynamic>;
      final qs = List<Map<String, dynamic>>.from(
        (data['questions'] as List? ?? []).map(
          (e) => Map<String, dynamic>.from(e as Map),
        ),
      );

      if (widget.existing != null) {
        // replace by id
        final id = widget.existing!['id'] as String? ?? '';
        final found = qs.indexWhere((e) => (e['id'] as String? ?? '') == id);
        if (found != -1) qs[found] = question;
      } else {
        qs.add(question);
      }

      await setRef.update({'questions': qs});
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing != null ? 'Edit Question' : 'Add Question'),
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(
          horizontal:
              MediaQuery.of(context).size.width *
              (isLandscape(context) ? 0.2 : 0.1),
          vertical: 16,
        ),

        child: Column(
          children: [
            TextField(
              controller: _textCtrl,
              maxLines: null,
              decoration: const InputDecoration(labelText: 'Question text'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.image),
                  label: const Text('Pick Image'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _filename ??
                        (_uploadedImageUrl != null
                            ? 'Using existing image'
                            : 'No image'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _answerCtrl,
              decoration: const InputDecoration(labelText: 'Answer'),
            ),
            const SizedBox(height: 12),
            if (_busy) const CircularProgressIndicator(),
            ElevatedButton(
              onPressed: _busy ? null : _save,
              child: Text(widget.existing != null ? 'Save' : 'Add'),
            ),
          ],
        ),
      ),
    );
  }
}

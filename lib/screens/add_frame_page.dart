import 'dart:typed_data';

import 'package:acm_activity_comic_game_admin/services/storage_service.dart';
import 'package:acm_activity_comic_game_admin/utils.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class AddFramePage extends StatefulWidget {
  const AddFramePage({super.key});

  @override
  State<AddFramePage> createState() => _AddFramePageState();
}

class _AddFramePageState extends State<AddFramePage> {
  Uint8List? _bytes;
  String? _filename;
  // preview url not required for now
  bool _busy = false;

  final _storage = StorageService();

  Future<void> _pickFile() async {
    final res = await FilePicker.platform.pickFiles(
      withData: true,
      allowMultiple: false,
      type: FileType.any,
    );
    if (res == null || res.files.isEmpty) return;
    final f = res.files.first;
    if (f.bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selected file has no bytes')),
      );
      return;
    }
    setState(() {
      _bytes = f.bytes;
      _filename = f.name;
    });
    debugPrint(
      'AddFramePage._pickFile: selected file name=${_filename} bytes=${_bytes?.length}',
    );
  }

  Future<void> _addFrame() async {
    if (_bytes == null || _filename == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Pick an image first')));
      return;
    }

    setState(() => _busy = true);
    try {
      debugPrint(
        'AddFramePage._addFrame: starting upload filename=$_filename bytes=${_bytes?.length}',
      );
      // upload image with random uid in storage
      final res = await _storage.uploadTempImage(
        bytes: _bytes!,
        filename: _filename!,
      );
      debugPrint('AddFramePage._addFrame: uploadTempImage returned $res');
      final downloadUrl = res['downloadUrl'];
      // create the frame doc
      await _storage.createFrameDoc(imageUrl: downloadUrl!);
      debugPrint(
        'AddFramePage._addFrame: createFrameDoc succeeded for url=$downloadUrl',
      );

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Frame added')));
      Navigator.of(context).pop();
    } catch (e) {
      debugPrint('AddFramePage._addFrame: ERROR -> $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to add frame: $e')));
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Frame')),
      body: Padding(
        padding: EdgeInsets.symmetric(
          horizontal:
              MediaQuery.of(context).size.width *
              (isLandscape(context) ? 0.2 : 0.1),
          vertical: 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (_bytes != null) ...[
              Center(
                child: Image.memory(_bytes!, height: 280, fit: BoxFit.contain),
              ),
              const SizedBox(height: 12),
              Text('File: ${_filename ?? ''}'),
            ] else
              Container(
                height: 280,
                color: Colors.grey[200],
                child: Center(
                  child: Text(
                    'No image selected',
                    style: TextStyle(color: Colors.grey[900]),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _busy ? null : _pickFile,
              icon: const Icon(Icons.photo_library),
              label: const Text('Select Image'),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _busy ? null : _addFrame,
              icon: const Icon(Icons.add),
              label: _busy ? const Text('Adding...') : const Text('Add Frame'),
            ),
          ],
        ),
      ),
    );
  }
}

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
  // Support multiple selected files
  List<Uint8List> _bytesList = [];
  List<String> _filenames = [];
  // preview url not required for now
  bool _busy = false;

  final _storage = StorageService();

  Future<void> _pickFile() async {
    final res = await FilePicker.platform.pickFiles(
      withData: true,
      allowMultiple: true,
      type: FileType.any,
    );
    if (res == null || res.files.isEmpty) return;

    final files = res.files.where((f) => f.bytes != null).toList();
    if (files.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selected files have no bytes')),
      );
      return;
    }

    setState(() {
      _bytesList = files.map((f) => f.bytes!).toList();
      _filenames = files.map((f) => f.name).toList();
    });

    debugPrint(
      'AddFramePage._pickFile: selected ${_filenames.length} files, first=${_filenames.first} bytes=${_bytesList.first.length}',
    );
  }

  Future<void> _addFrame() async {
    if (_bytesList.isEmpty || _filenames.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Pick one or more images first')));
      return;
    }

    setState(() => _busy = true);
    try {
      debugPrint('AddFramePage._addFrame: starting batch upload of ${_filenames.length} files');

      for (var i = 0; i < _bytesList.length; i++) {
        final bytes = _bytesList[i];
        final filename = _filenames[i];
        debugPrint('Uploading file ${i + 1}/${_filenames.length}: $filename bytes=${bytes.length}');

        final res = await _storage.uploadTempImage(bytes: bytes, filename: filename);
        debugPrint('uploadTempImage returned $res for $filename');
        final downloadUrl = res['downloadUrl'];
        if (downloadUrl == null) {
          throw Exception('upload did not return downloadUrl for $filename');
        }

        await _storage.createFrameDoc(imageUrl: downloadUrl);
        debugPrint('createFrameDoc succeeded for url=$downloadUrl');
      }

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Frames added')));
      Navigator.of(context).pop();
    } catch (e) {
      debugPrint('AddFramePage._addFrame: ERROR -> $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to add frames: $e')));
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
            if (_bytesList.isNotEmpty) ...[
              SizedBox(
                height: 280,
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    childAspectRatio: 1,
                  ),
                  itemCount: _bytesList.length,
                  itemBuilder: (context, idx) {
                    return Image.memory(_bytesList[idx], fit: BoxFit.cover);
                  },
                ),
              ),
              const SizedBox(height: 12),
              Text('Files: ${_filenames.join(', ')}'),
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
              label: const Text('Select Images'),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _busy ? null : _addFrame,
              icon: const Icon(Icons.add),
              label: _busy
                  ? const Text('Adding...')
                  : Text(_filenames.length > 1 ? 'Add Frames' : 'Add Frame'),
            ),
          ],
        ),
      ),
    );
  }
}

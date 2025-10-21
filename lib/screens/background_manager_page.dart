import 'dart:typed_data';

import 'package:acm_activity_comic_game_admin/services/storage_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Background manager UI
/// - Manages two independent resources stored in `comic_game/config`:
///   - backgroundImageUrl / backgroundImageStoragePath
///   - backgroundVideoUrl / backgroundVideoStoragePath
class BackgroundManagerPage extends StatefulWidget {
  const BackgroundManagerPage({super.key});

  @override
  State<BackgroundManagerPage> createState() => _BackgroundManagerPageState();
}

class _BackgroundManagerPageState extends State<BackgroundManagerPage> {
  final StorageService _storage = StorageService();
  final DocumentReference _configDoc = FirebaseFirestore.instance
      .collection('comic_game')
      .doc('config');

  // Current values from Firestore
  String? _imageUrl;
  String? _imageStoragePath;
  String? _videoUrl;
  String? _videoStoragePath;

  // Picked but not yet uploaded
  Uint8List? _pickedImageBytes;
  String? _pickedImageName;
  Uint8List? _pickedVideoBytes;
  String? _pickedVideoName;

  // Busy flags
  bool _imageBusy = false;
  bool _videoBusy = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final snap = await _configDoc.get();
    if (!snap.exists) return;
    final data = snap.data() as Map<String, dynamic>;
    setState(() {
      _imageUrl = (data['backgroundImageUrl'] as String?)?.trim();
      _imageStoragePath = (data['backgroundImageStoragePath'] as String?)
          ?.trim();
      _videoUrl = (data['backgroundVideoUrl'] as String?)?.trim();
      _videoStoragePath = (data['backgroundVideoStoragePath'] as String?)
          ?.trim();
    });
  }

  Future<void> _pickImage() async {
    final res = await FilePicker.platform.pickFiles(
      withData: true,
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg', 'gif'],
    );
    if (res == null || res.files.isEmpty) return;
    final f = res.files.first;
    if (f.bytes == null) return;
    setState(() {
      _pickedImageBytes = f.bytes;
      _pickedImageName = f.name;
    });
  }

  Future<void> _pickVideo() async {
    final res = await FilePicker.platform.pickFiles(
      withData: true,
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: ['mp4', 'mov', 'webm'],
    );
    if (res == null || res.files.isEmpty) return;
    final f = res.files.first;
    if (f.bytes == null) return;
    setState(() {
      _pickedVideoBytes = f.bytes;
      _pickedVideoName = f.name;
    });
  }

  Future<void> _uploadImage() async {
    if (_pickedImageBytes == null || _pickedImageName == null) return;
    setState(() => _imageBusy = true);
    try {
      final res = await _storage.uploadTempImage(
        bytes: _pickedImageBytes!,
        filename: _pickedImageName!,
      );
      final downloadUrl = res['downloadUrl'];
      final storagePath = res['storagePath'];
      if (downloadUrl == null || storagePath == null)
        throw Exception('Upload failed');

      // Save fields
      await _configDoc.set({
        'backgroundImageUrl': downloadUrl,
        'backgroundImageStoragePath': storagePath,
      }, SetOptions(merge: true));

      // Delete previous image storage (best-effort)
      if (_imageStoragePath != null && _imageStoragePath!.isNotEmpty) {
        try {
          await _storage.deleteFile(_imageStoragePath!);
        } catch (_) {}
      }

      setState(() {
        _imageUrl = downloadUrl;
        _imageStoragePath = storagePath;
        _pickedImageBytes = null;
        _pickedImageName = null;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Image uploaded')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Image upload failed: $e')));
    } finally {
      setState(() => _imageBusy = false);
    }
  }

  Future<void> _uploadVideo() async {
    if (_pickedVideoBytes == null || _pickedVideoName == null) return;
    setState(() => _videoBusy = true);
    try {
      final res = await _storage.uploadTempVideo(
        bytes: _pickedVideoBytes!,
        filename: _pickedVideoName!,
      );
      final downloadUrl = res['downloadUrl'];
      final storagePath = res['storagePath'];
      if (downloadUrl == null || storagePath == null)
        throw Exception('Upload failed');

      await _configDoc.set({
        'backgroundVideoUrl': downloadUrl,
        'backgroundVideoStoragePath': storagePath,
      }, SetOptions(merge: true));

      if (_videoStoragePath != null && _videoStoragePath!.isNotEmpty) {
        try {
          await _storage.deleteFile(_videoStoragePath!);
        } catch (_) {}
      }

      setState(() {
        _videoUrl = downloadUrl;
        _videoStoragePath = storagePath;
        _pickedVideoBytes = null;
        _pickedVideoName = null;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Video uploaded')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Video upload failed: $e')));
    } finally {
      setState(() => _videoBusy = false);
    }
  }

  Future<void> _removeImage() async {
    setState(() => _imageBusy = true);
    try {
      await _configDoc.set({
        'backgroundImageUrl': FieldValue.delete(),
        'backgroundImageStoragePath': FieldValue.delete(),
      }, SetOptions(merge: true));
      if (_imageStoragePath != null && _imageStoragePath!.isNotEmpty) {
        try {
          await _storage.deleteFile(_imageStoragePath!);
        } catch (_) {}
      }
      setState(() {
        _imageUrl = null;
        _imageStoragePath = null;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Image removed')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Remove image failed: $e')));
    } finally {
      setState(() => _imageBusy = false);
    }
  }

  Future<void> _removeVideo() async {
    setState(() => _videoBusy = true);
    try {
      await _configDoc.set({
        'backgroundVideoUrl': FieldValue.delete(),
        'backgroundVideoStoragePath': FieldValue.delete(),
      }, SetOptions(merge: true));
      if (_videoStoragePath != null && _videoStoragePath!.isNotEmpty) {
        try {
          await _storage.deleteFile(_videoStoragePath!);
        } catch (_) {}
      }
      setState(() {
        _videoUrl = null;
        _videoStoragePath = null;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Video removed')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Remove video failed: $e')));
    } finally {
      setState(() => _videoBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Background Manager')),
      body: RefreshIndicator(
        onRefresh: _loadConfig,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Image Background',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_imageUrl != null) ...[
                        SizedBox(
                          height: 180,
                          child: Image.network(_imageUrl!, fit: BoxFit.cover),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: _imageBusy
                                  ? null
                                  : () async {
                                      await Clipboard.setData(
                                        ClipboardData(text: _imageUrl ?? ''),
                                      );
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('Image URL copied'),
                                        ),
                                      );
                                    },
                              icon: const Icon(Icons.copy),
                              label: const Text('Copy URL'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: _imageBusy ? null : _removeImage,
                              icon: const Icon(Icons.delete),
                              label: const Text('Remove Image'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        Container(
                          height: 180,
                          color: Colors.grey[200],
                          child: const Center(child: Text('No image set')),
                        ),
                      ],
                      const SizedBox(height: 8),
                      if (_pickedImageBytes != null) ...[
                        SizedBox(
                          height: 140,
                          child: Image.memory(
                            _pickedImageBytes!,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text('Selected: ${_pickedImageName ?? ''}'),
                        const SizedBox(height: 8),
                      ],
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: _imageBusy ? null : _pickImage,
                            icon: const Icon(Icons.photo_library),
                            label: const Text('Choose Image'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed:
                                (_pickedImageBytes != null && !_imageBusy)
                                ? _uploadImage
                                : null,
                            icon: const Icon(Icons.upload_file),
                            label: _imageBusy
                                ? const Text('Working...')
                                : const Text('Upload Image'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Video Background',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_videoUrl != null) ...[
                        SizedBox(
                          height: 120,
                          child: Container(
                            color: Colors.black12,
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.videocam, size: 36),
                                  const SizedBox(height: 8),
                                  const Text('Background video set'),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: _videoBusy
                                  ? null
                                  : () async {
                                      await Clipboard.setData(
                                        ClipboardData(text: _videoUrl ?? ''),
                                      );
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('Video URL copied'),
                                        ),
                                      );
                                    },
                              icon: const Icon(Icons.copy),
                              label: const Text('Copy URL'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: _videoBusy ? null : _removeVideo,
                              icon: const Icon(Icons.delete),
                              label: const Text('Remove Video'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        Container(
                          height: 120,
                          color: Colors.grey[200],
                          child: const Center(child: Text('No video set')),
                        ),
                      ],
                      const SizedBox(height: 8),
                      if (_pickedVideoBytes != null) ...[
                        SizedBox(
                          height: 100,
                          child: Container(
                            color: Colors.black12,
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.videocam, size: 36),
                                  const SizedBox(height: 8),
                                  Text('Selected: ${_pickedVideoName ?? ''}'),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: _videoBusy ? null : _pickVideo,
                            icon: const Icon(Icons.video_library),
                            label: const Text('Choose Video'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed:
                                (_pickedVideoBytes != null && !_videoBusy)
                                ? _uploadVideo
                                : null,
                            icon: const Icon(Icons.upload_file),
                            label: _videoBusy
                                ? const Text('Working...')
                                : const Text('Upload Video'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class StorageService {
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  /// Upload bytes to Storage immediately under: /comic_game/frames/<randomId><ext>
  /// Returns a map with keys: 'storagePath' and 'downloadUrl'.
  Future<Map<String, String>> uploadTempImage({
    required Uint8List bytes,
    required String filename,
    void Function(double progress)? onProgress,
  }) async {
    debugPrint(
      'StorageService.uploadTempImage: start filename=$filename bytes=${bytes.length}',
    );

    // generate a random id (not tied to the eventual frame doc id)
    final randomId =
        '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${identityHashCode(Object()).toRadixString(36)}';
    final ext = _extensionFromFilename(filename);
    final storagePath = 'comic_game/frames/$randomId$ext';

    final uploadTask = _storage.ref().child(storagePath).putData(bytes);

    try {
      final snapshot = await uploadTask;
      final url = await snapshot.ref.getDownloadURL();
      debugPrint(
        'StorageService.uploadTempImage: uploaded -> storagePath=$storagePath downloadUrl=$url',
      );
      return {'storagePath': storagePath, 'downloadUrl': url};
    } catch (e, st) {
      debugPrint(
        'StorageService.uploadTempImage: ERROR uploading to $storagePath -> $e\n$st',
      );
      rethrow;
    }
  }

  /// Delete a storage file at the given storage path (e.g. 'comic_game/frames/abc.png')
  Future<void> deleteFile(String storagePath) async {
    try {
      debugPrint('StorageService.deleteFile: deleting $storagePath');
      await _storage.ref().child(storagePath).delete();
      debugPrint('StorageService.deleteFile: deleted $storagePath');
    } catch (e, st) {
      debugPrint(
        'StorageService.deleteFile: error deleting $storagePath -> $e\n$st',
      );
      // ignore not-found or permission errors for best-effort cleanup
    }
  }

  /// Create a frame document under comic_game/frames/frames with the provided imageUrl.
  /// Uses a transaction to increment parent's lastIndex to assign a stable index.
  Future<void> createFrameDoc({required String imageUrl}) async {
    final parentDoc = _firestore.collection('comic_game').doc('frames');
    final framesCol = parentDoc.collection('frames');
    final newDocRef = framesCol.doc();
    debugPrint(
      'StorageService.createFrameDoc: creating frame doc for imageUrl=$imageUrl',
    );
    try {
      await _firestore.runTransaction((tx) async {
        final parentSnap = await tx.get(parentDoc);
        int lastIndex = -1;
        if (parentSnap.exists) {
          final data = parentSnap.data() as Map<String, dynamic>;
          lastIndex = (data['lastIndex'] is int)
              ? data['lastIndex'] as int
              : int.tryParse('${data['lastIndex']}') ?? -1;
        }
        final nextIndex = lastIndex + 1;

        debugPrint(
          'StorageService.createFrameDoc: nextIndex=$nextIndex newDocId=${newDocRef.id}',
        );

        tx.set(newDocRef, {
          'imageUrl': imageUrl,
          'index': nextIndex,
          'elements': [],
          'audioUrl': '',
        });

        tx.set(parentDoc, {'lastIndex': nextIndex}, SetOptions(merge: true));
      });
      debugPrint(
        'StorageService.createFrameDoc: successfully created frame doc',
      );
    } catch (e, st) {
      debugPrint('StorageService.createFrameDoc: ERROR -> $e\n$st');
      rethrow;
    }
  }

  /// Upload bytes for audio files under: /comic_game/music/<randomId><ext>
  /// Returns a map with keys: 'storagePath' and 'downloadUrl'.
  Future<Map<String, String>> uploadTempAudio({
    required Uint8List bytes,
    required String filename,
    void Function(double progress)? onProgress,
  }) async {
    debugPrint(
      'StorageService.uploadTempAudio: start filename=$filename bytes=${bytes.length}',
    );

    final randomId =
        '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${identityHashCode(Object()).toRadixString(36)}';
    final ext = _extensionFromFilename(filename);
    final storagePath = 'comic_game/music/$randomId$ext';

    final uploadTask = _storage.ref().child(storagePath).putData(bytes);

    try {
      final snapshot = await uploadTask;
      final url = await snapshot.ref.getDownloadURL();
      debugPrint(
        'StorageService.uploadTempAudio: uploaded -> storagePath=$storagePath downloadUrl=$url',
      );
      return {'storagePath': storagePath, 'downloadUrl': url};
    } catch (e, st) {
      debugPrint(
        'StorageService.uploadTempAudio: ERROR uploading to $storagePath -> $e\n$st',
      );
      rethrow;
    }
  }

  /// Create a music document under comic_game/music/music with the provided title and audioUrl.
  /// Stores storagePath as well so it can be cleaned up later. Uses a transaction to increment lastIndex.
  Future<void> createMusicDoc({
    required String title,
    required String audioUrl,
    required String storagePath,
  }) async {
    final parentDoc = _firestore.collection('comic_game').doc('music');
    final musicCol = parentDoc.collection('music');
    final newDocRef = musicCol.doc();
    debugPrint(
      'StorageService.createMusicDoc: creating music doc for title=$title audioUrl=$audioUrl',
    );
    try {
      await _firestore.runTransaction((tx) async {
        final parentSnap = await tx.get(parentDoc);
        int lastIndex = -1;
        if (parentSnap.exists) {
          final data = parentSnap.data() as Map<String, dynamic>;
          lastIndex = (data['lastIndex'] is int)
              ? data['lastIndex'] as int
              : int.tryParse('${data['lastIndex']}') ?? -1;
        }
        final nextIndex = lastIndex + 1;

        debugPrint(
          'StorageService.createMusicDoc: nextIndex=$nextIndex newDocId=${newDocRef.id}',
        );

        tx.set(newDocRef, {
          'title': title,
          'audioUrl': audioUrl,
          'storagePath': storagePath,
          'index': nextIndex,
          'id': newDocRef.id,
        });

        tx.set(parentDoc, {'lastIndex': nextIndex}, SetOptions(merge: true));
      });
      debugPrint('StorageService.createMusicDoc: successfully created music doc');
    } catch (e, st) {
      debugPrint('StorageService.createMusicDoc: ERROR -> $e\n$st');
      rethrow;
    }
  }

  /// Delete a music doc and optionally its storage file (if storagePath provided).
  Future<void> deleteMusicDoc({
    required String docId,
    String? storagePath,
  }) async {
    final parentDoc = _firestore.collection('comic_game').doc('music');
    final musicCol = parentDoc.collection('music');
    final docRef = musicCol.doc(docId);
    try {
      debugPrint('StorageService.deleteMusicDoc: deleting doc $docId');
      await docRef.delete();
      if (storagePath != null && storagePath.isNotEmpty) {
        await deleteFile(storagePath);
      }
      debugPrint('StorageService.deleteMusicDoc: deleted doc $docId');
    } catch (e, st) {
      debugPrint('StorageService.deleteMusicDoc: ERROR -> $e\n$st');
      rethrow;
    }
  }

  String _extensionFromFilename(String name) {
    final idx = name.lastIndexOf('.');
    if (idx == -1) return '';
    return name.substring(idx);
  }
}

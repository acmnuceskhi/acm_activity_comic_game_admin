import 'package:acm_activity_comic_game_admin/services/storage_service.dart';
import 'package:acm_activity_comic_game_admin/utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'add_music_page.dart';

class MusicManagerPage extends StatefulWidget {
  const MusicManagerPage({super.key});

  @override
  State<MusicManagerPage> createState() => _MusicManagerPageState();
}

class _MusicManagerPageState extends State<MusicManagerPage> {
  final _musicCol = FirebaseFirestore.instance
      .collection('comic_game')
      .doc('music')
      .collection('music');
  final _storage = StorageService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Music Manager')),
      body: StreamBuilder<QuerySnapshot>(
        stream: _musicCol.orderBy('index').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return Center(child: Text('Error: ${snapshot.error}'));
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('No music added'));

          return Padding(
            padding: EdgeInsets.symmetric(
              horizontal:
                  MediaQuery.of(context).size.width *
                  (isLandscape(context) ? 0.2 : 0.1),
              vertical: 16,
            ),
            child: ListView.builder(
              itemCount: docs.length,
              itemBuilder: (context, i) {
                final data = docs[i].data() as Map<String, dynamic>;
                final title = data['title'] as String? ?? 'Untitled';
                final audioUrl = data['audioUrl'] as String? ?? '';
                final storagePath = data['storagePath'] as String? ?? '';
                final docId = docs[i].id;

                return ListTile(
                  title: Text(title),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () async {
                          // navigate to add/edit page with existing values
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => AddMusicPage(
                                existingId: docId,
                                existingTitle: title,
                                existingAudioUrl: audioUrl,
                                existingStoragePath: storagePath,
                              ),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (c) => AlertDialog(
                              title: const Text('Delete music?'),
                              content: Text(
                                'Delete "$title"? This will also remove the audio file.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(c).pop(false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(c).pop(true),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );
                          if (ok == true) {
                            try {
                              await _storage.deleteMusicDoc(
                                docId: docId,
                                storagePath: storagePath,
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Deleted')),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error deleting: $e')),
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () async {
          await Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const AddMusicPage()));
        },
      ),
    );
  }
}

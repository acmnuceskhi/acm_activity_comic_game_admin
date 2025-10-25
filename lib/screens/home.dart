import 'package:acm_activity_comic_game_admin/screens/background_manager_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:acm_activity_comic_game_admin/screens/add_frame_page.dart';
import 'package:acm_activity_comic_game_admin/screens/frame_page.dart';
import 'package:acm_activity_comic_game_admin/screens/music_manager_page.dart';
import 'package:acm_activity_comic_game_admin/screens/questions_manager_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _framesCollection = FirebaseFirestore.instance
      .collection('comic_game')
      .doc('frames')
      .collection('frames');

  // no local upload state here; AddFramePage handles uploads
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ACM Activity Comic Game Admin'),
        actions: [
          IconButton(
            tooltip: 'Music Manager',
            icon: const Icon(Icons.music_note),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MusicManagerPage()),
              );
            },
          ),
          IconButton(
            tooltip: 'Background',
            icon: const Icon(Icons.wallpaper),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const BackgroundManagerPage(),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Questions Manager',
            icon: const Icon(Icons.question_answer),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const QuestionsManagerPage()),
              );
            },
          ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              try {
                await FirebaseAuth.instance.signOut();
                // return to first route (AuthGate should be mounted at app root)
                Navigator.of(context).popUntil((r) => r.isFirst);
              } catch (e) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Logout failed: $e')));
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _framesCollection.orderBy('index').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            return const Center(child: Text('No frames yet'));
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('No frames yet'));
          }

          // show frames in a reorderable grid
          final items = docs;
          return Padding(
            padding: const EdgeInsets.all(12),
            child: ReorderableGridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final doc = items[index];
                final data = doc.data() as Map<String, dynamic>;
                final imageUrl = data['imageUrl'] as String? ?? '';
                final idx = data['index'] as int? ?? index;
                final docId = doc.id;

                return Card(
                  key: ValueKey(docId),
                  child: InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => FramePage(frameId: docId),
                        ),
                      );
                    },
                    child: Builder(
                      builder: (context) {
                        final maybe =
                            data['questionSetId'] ??
                            data['questionSet'] ??
                            data['setId'];
                        final hasQuestion =
                            maybe != null && maybe.toString().trim().isNotEmpty;
                        return Column(
                          children: [
                            Expanded(
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: imageUrl.isNotEmpty
                                        ? Image.network(
                                            imageUrl,
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                            loadingBuilder:
                                                (
                                                  context,
                                                  child,
                                                  loadingProgress,
                                                ) {
                                                  if (loadingProgress == null)
                                                    return child;
                                                  return const Center(
                                                    child:
                                                        CircularProgressIndicator(),
                                                  );
                                                },
                                          )
                                        : Container(color: Colors.grey[200]),
                                  ),
                                  // delete button (top-left)
                                  Positioned(
                                    top: 6,
                                    left: 6,
                                    child: CircleAvatar(
                                      radius: 15,
                                      backgroundColor: Colors.red,
                                      child: IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        iconSize: 20,
                                        color: Colors.white,
                                        icon: const Icon(Icons.delete),
                                        onPressed: () async {
                                          final confirm = await showDialog<bool?>(
                                            context: context,
                                            builder: (c) => AlertDialog(
                                              title: const Text('Delete frame'),
                                              content: const Text(
                                                'Are you sure you want to delete this frame? This cannot be undone.',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.of(
                                                    c,
                                                  ).pop(false),
                                                  child: const Text('Cancel'),
                                                ),
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.of(c).pop(true),
                                                  child: const Text('Delete'),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (confirm == true) {
                                            try {
                                              await _framesCollection
                                                  .doc(docId)
                                                  .delete();
                                              if (mounted)
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Frame deleted',
                                                    ),
                                                  ),
                                                );
                                            } catch (e) {
                                              if (mounted)
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'Delete failed: $e',
                                                    ),
                                                  ),
                                                );
                                            }
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                  if (hasQuestion)
                                    Positioned(
                                      top: 6,
                                      right: 6,
                                      child: CircleAvatar(
                                        radius: 15,
                                        backgroundColor: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        child: Icon(
                                          Icons.help_outline,
                                          size: 25,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(6.0),
                              child: Text('Index: $idx'),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                );
              },
              onReorder: (oldIndex, newIndex) async {
                // normalize newIndex when moving down
                if (newIndex > oldIndex) newIndex -= 1;
                final list = List<QueryDocumentSnapshot>.from(items);
                final moved = list.removeAt(oldIndex);
                list.insert(newIndex, moved);

                final batch = FirebaseFirestore.instance.batch();
                try {
                  for (var i = 0; i < list.length; i++) {
                    final doc = list[i];
                    final ref = _framesCollection.doc(doc.id);
                    batch.update(ref, {'index': i});
                  }
                  await batch.commit();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Frames reordered')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to reorder: $e')),
                    );
                  }
                }
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const AddFramePage()));
        },
        label: const Text('Add Frame'),
        icon: const Icon(Icons.add_a_photo),
      ),
    );
  }
}

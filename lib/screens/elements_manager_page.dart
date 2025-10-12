import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'add_element_page.dart';
import 'animation_player_page.dart';

class ElementsManagerPage extends StatelessWidget {
  final String frameId;

  const ElementsManagerPage({super.key, required this.frameId});

  @override
  Widget build(BuildContext context) {
    final elementsRef = FirebaseFirestore.instance.collection('comic_game').doc('frames').collection('frames').doc(frameId);

    return Scaffold(
      appBar: AppBar(title: const Text('Elements')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: elementsRef.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final data = snap.data!.data() as Map<String, dynamic>?;
          final elements = (data != null && data['elements'] is List) ? List.from(data['elements'] as List) : [];

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: elements.length,
                  itemBuilder: (context, i) {
                    final el = elements[i] as Map<String, dynamic>;
                    final imageUrl = el['imageUrl'] as String? ?? '';
                    final pos = el['position'] as Map<String, dynamic>? ?? {'x': 0.5, 'y': 0.5};
                    final scale = el['scale']?.toString() ?? '';
                    return ListTile(
                      leading: imageUrl.isNotEmpty ? Image.network(imageUrl, width: 48, height: 48, fit: BoxFit.cover) : null,
                      title: Text('Element #${i + 1}'),
                      subtitle: Text('x:${pos['x']}, y:${pos['y']}, s:$scale'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () async {
                              try {
                                final frameSnap = await elementsRef.get();
                                final frameData = frameSnap.data();
                                final imageUrl = frameData?['imageUrl'] as String? ?? '';
                                // ensure we pass a Map<String, dynamic>
                final typed = Map<String, dynamic>.from(el);
                debugPrint('ElementsManager: opening editor for element: $typed');
                await Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => AddElementPage(frameId: frameId, frameImageUrl: imageUrl, existingElement: typed)));
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open editor: $e')));
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.movie),
                            tooltip: 'Animations',
                            onPressed: () async {
                              try {
                                final frameSnap = await elementsRef.get();
                                final frameData = frameSnap.data();
                                final imageUrl = frameData?['imageUrl'] as String? ?? '';
                                // open bottom sheet to manage animations for this element
                                await showModalBottomSheet<void>(context: context, builder: (ctx) {
                                  final animations = (el['animation'] is List) ? List.from(el['animation'] as List) : [];
                                  return Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                                      Text('Animations (${animations.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 8),
                                      SizedBox(
                                        height: 160,
                                        child: ListView.builder(
                                          itemCount: animations.length,
                                          itemBuilder: (c, ai) {
                                            final a = animations[ai] as Map<String, dynamic>;
                                            final dur = a['duration'] ?? a['seconds'] ?? 1;
                                            return ListTile(
                                              title: Text('Animation #${ai + 1} - ${dur}s'),
                                              subtitle: Text((a['matrix'] is List) ? 'matrix[16]' : 'invalid'),
                                              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                                                IconButton(icon: const Icon(Icons.play_arrow), onPressed: () {
                                                  Navigator.of(ctx).pop();
                                                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => AnimationPlayerPage(frameImageUrl: imageUrl, element: Map<String, dynamic>.from(el))));
                                                }),
                                              ]),
                                            );
                                          },
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      ElevatedButton.icon(
                                        icon: const Icon(Icons.add),
                                        label: const Text('Add animation'),
                                        onPressed: () async {
                                          // open dialog to enter matrix (16 comma-separated) and duration
                                          final result = await showDialog<Map<String, dynamic>>(context: ctx, builder: (dctx) {
                                            final matController = TextEditingController();
                                            final durController = TextEditingController(text: '1');
                                            return AlertDialog(
                                              title: const Text('Add animation'),
                                              content: Column(mainAxisSize: MainAxisSize.min, children: [
                                                TextField(controller: durController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Duration (seconds)')),
                                                const SizedBox(height: 8),
                                                TextField(controller: matController, maxLines: 4, decoration: const InputDecoration(labelText: 'Matrix (16 comma-separated numbers)')),
                                              ]),
                                              actions: [
                                                TextButton(onPressed: () => Navigator.of(dctx).pop(), child: const Text('Cancel')),
                                                TextButton(onPressed: () {
                                                  final matText = matController.text.trim();
                                                  final durText = durController.text.trim();
                                                  double? dur = double.tryParse(durText);
                                                  if (dur == null || dur <= 0) dur = 1.0;
                                                  final parts = matText.split(RegExp('[,\s]+')).where((s) => s.isNotEmpty).toList();
                                                  if (parts.length != 16) {
                                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter 16 numbers for the matrix')));
                                                    return;
                                                  }
                                                  final nums = parts.map((p) => double.tryParse(p)).toList();
                                                  if (nums.any((n) => n == null)) {
                                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Matrix must contain valid numbers')));
                                                    return;
                                                  }
                                                  Navigator.of(dctx).pop({'matrix': nums.map((n) => n!).toList(), 'duration': dur});
                                                }, child: const Text('Add'))
                                              ],
                                            );
                                          });
                                          if (result != null) {
                                            // append animation to element and update doc (remove old and add updated)
                                            final newAnimations = List.from( (el['animation'] is List) ? el['animation'] as List : [] );
                                            newAnimations.add(result);
                                            final updated = Map<String, dynamic>.from(el);
                                            updated['animation'] = newAnimations;
                                            await elementsRef.update({'elements': FieldValue.arrayRemove([el])});
                                            await elementsRef.update({'elements': FieldValue.arrayUnion([updated])});
                                            Navigator.of(ctx).pop();
                                          }
                                        },
                                      ),
                                      const SizedBox(height: 8),
                                      ElevatedButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close'))
                                    ]),
                                  );
                                });
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open animations: $e')));
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () async {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (c) => AlertDialog(
                                  title: const Text('Delete element?'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Cancel')),
                                    TextButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('Delete')),
                                  ],
                                ),
                              );
                              if (ok == true) {
                                await elementsRef.update({
                                  'elements': FieldValue.arrayRemove([el])
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add element'),
                  onPressed: () async {
                    // fetch current frame image to pass to AddElementPage
                    final frameSnap = await elementsRef.get();
                    final frameData = frameSnap.data();
                    final imageUrl = frameData?['imageUrl'] as String? ?? '';
                    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => AddElementPage(frameId: frameId, frameImageUrl: imageUrl)));
                  },
                ),
              )
            ],
          );
        },
      ),
    );
  }
}

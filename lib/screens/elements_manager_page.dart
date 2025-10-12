import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'add_element_page.dart';

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

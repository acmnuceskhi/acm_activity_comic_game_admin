import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:acm_activity_comic_game_admin/screens/add_frame_page.dart';
import 'package:acm_activity_comic_game_admin/screens/frame_page.dart';
import 'package:acm_activity_comic_game_admin/screens/music_manager_page.dart';
import 'package:acm_activity_comic_game_admin/screens/questions_manager_page.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final imageUrl = data['imageUrl'] as String? ?? '';
              final idx = data['index'] as int? ?? index;
              final docId = docs[index].id;

              return InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => FramePage(frameId: docId),
                    ),
                  );
                },
                child: Card(
                  child: Column(
                    children: [
                      Expanded(
                        child: imageUrl.isNotEmpty
                            ? Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                width: double.infinity,
                              )
                            : Container(color: Colors.grey[200]),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(6.0),
                        child: Text('Index: $idx'),
                      ),
                    ],
                  ),
                ),
              );
            },
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

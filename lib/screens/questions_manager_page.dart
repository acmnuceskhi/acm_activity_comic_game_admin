import 'package:acm_activity_comic_game_admin/utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'add_question_set_page.dart';
import 'add_question_page.dart';

class QuestionsManagerPage extends StatefulWidget {
  const QuestionsManagerPage({super.key});

  @override
  State<QuestionsManagerPage> createState() => _QuestionsManagerPageState();
}

class _QuestionsManagerPageState extends State<QuestionsManagerPage> {
  final _setsRef = FirebaseFirestore.instance
      .collection('comic_game')
      .doc('questions')
      .collection('sets');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Questions Manager')),
      body: StreamBuilder<QuerySnapshot>(
        stream: _setsRef.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
          if (!snap.hasData)
            return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          if (docs.isEmpty)
            return const Center(child: Text('No question sets'));
          return Padding(
            padding: EdgeInsets.symmetric(
              horizontal:
                  MediaQuery.of(context).size.width *
                  (isLandscape(context) ? 0.2 : 0.1),
              vertical: 16,
            ),
            child: ListView.builder(
              itemCount: docs.length,
              itemBuilder: (c, i) {
                final d = docs[i];
                final data = d.data() as Map<String, dynamic>;
                final title = data['title'] as String? ?? 'Untitled';
                // final idx = data['index'] as int? ?? i;
                final questions = (data['questions'] as List?) ?? [];
                return Card(
                  child: ListTile(
                    title: Text('$title'),
                    subtitle: Text('${questions.length} questions'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => AddQuestionSetPage(
                                  existingId: d.id,
                                  existingData: data,
                                ),
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () async {
                            await _setsRef.doc(d.id).delete();
                          },
                        ),
                      ],
                    ),
                    onTap: () async {
                      // open questions list
                      await showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) =>
                            QuestionsListSheet(setId: d.id, setData: data),
                      );
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const AddQuestionSetPage()));
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Set'),
      ),
    );
  }
}

class QuestionsListSheet extends StatefulWidget {
  final String setId;
  final Map<String, dynamic> setData;

  const QuestionsListSheet({
    super.key,
    required this.setId,
    required this.setData,
  });

  @override
  State<QuestionsListSheet> createState() => _QuestionsListSheetState();
}

class _QuestionsListSheetState extends State<QuestionsListSheet> {
  late CollectionReference _setsRef;

  @override
  void initState() {
    super.initState();
    _setsRef = FirebaseFirestore.instance
        .collection('comic_game')
        .doc('questions')
        .collection('sets');
  }

  @override
  Widget build(BuildContext context) {
    final questions = (widget.setData['questions'] as List?) ?? [];
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            AppBar(
              title: Text(widget.setData['title'] as String? ?? 'Questions'),
              automaticallyImplyLeading: false,
            ),
            Expanded(
              child: ListView.builder(
                itemCount: questions.length,
                itemBuilder: (c, i) {
                  final q = Map<String, dynamic>.from(
                    questions[i] as Map? ?? {},
                  );
                  return ListTile(
                    title: Text(q['text'] as String? ?? ''),
                    subtitle: Text('Answer: ${q['answer'] ?? ''}'),
                    leading: q['imageUrl'] != null
                        ? Image.network(
                            q['imageUrl'],
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                          )
                        : null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () async {
                            final res = await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => AddQuestionPage(
                                  existing: q,
                                  setId: widget.setId,
                                ),
                              ),
                            );
                            if (res == true) Navigator.of(context).pop();
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () async {
                            // remove by index
                            final list = List.from(questions);
                            list.removeAt(i);
                            await _setsRef.doc(widget.setId).update({
                              'questions': list,
                            });
                            setState(() {});
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
              child: Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () async {
                      final res = await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AddQuestionPage(setId: widget.setId),
                        ),
                      );
                      if (res == true) Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add Question'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

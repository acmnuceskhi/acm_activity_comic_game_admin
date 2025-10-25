import 'package:acm_activity_comic_game_admin/utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AddQuestionSetPage extends StatefulWidget {
  final String? existingId;
  final Map<String, dynamic>? existingData;

  const AddQuestionSetPage({super.key, this.existingId, this.existingData});

  @override
  State<AddQuestionSetPage> createState() => _AddQuestionSetPageState();
}

class _AddQuestionSetPageState extends State<AddQuestionSetPage> {
  final _titleCtrl = TextEditingController();
  // index removed - question sets no longer have an index
  bool _busy = false;

  CollectionReference get _setsRef => FirebaseFirestore.instance
      .collection('comic_game')
      .doc('questions')
      .collection('sets');

  @override
  void initState() {
    super.initState();
    final ex = widget.existingData;
    if (ex != null) {
      _titleCtrl.text = ex['title'] as String? ?? '';
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    // index removed
    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter a title')));
      return;
    }
    setState(() => _busy = true);
    try {
      if (widget.existingId != null) {
        await _setsRef.doc(widget.existingId).update({'title': title});
      } else {
        await _setsRef.add({'title': title, 'questions': []});
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existingId != null ? 'Edit Question Set' : 'Add Question Set',
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal:
                MediaQuery.of(context).size.width *
                (isLandscape(context) ? 0.2 : 0.1),
            vertical: 16,
          ),
          child: Column(
            children: [
              TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 12),
              if (_busy) const CircularProgressIndicator(),
              ElevatedButton(
                onPressed: _busy ? null : _save,
                child: Text(widget.existingId != null ? 'Save' : 'Add'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class NewLabelDialog extends StatefulWidget {
  @override
  _NewLabelDialogState createState() => _NewLabelDialogState();
}

class _NewLabelDialogState extends State<NewLabelDialog> {
  final TextEditingController _labelController = TextEditingController();

  Future<void> _createLabel() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final labelName = _labelController.text.trim();

    if (uid == null || labelName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You must be logged in and enter a label name.')),
      );
      return;
    }

    try {
      final DatabaseReference dbRef = FirebaseDatabase.instance.ref();
      final newLabelRef = dbRef.child('users/$uid/labels').push();

      await newLabelRef.set({
        'name': labelName,
        'parent': null, // No longer nesting
        'createdAt': DateTime.now().toIso8601String(),
      });

      Navigator.of(context).pop(); // Close dialog after creation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Label created successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create label: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('New Label'),
      content: TextField(
        controller: _labelController,
        decoration: InputDecoration(
          labelText: 'Enter a name for the new label:',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _createLabel,
          child: Text('Create'),
        ),
      ],
    );
  }
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../components/dialog.dart';

// import 'package:firebase_storage/firebase_storage.dart'; 

class ComposeEmailPage extends StatefulWidget {
  const ComposeEmailPage({super.key});

  @override
  State<ComposeEmailPage> createState() => _ComposeEmailPageState();
}

class _ComposeEmailPageState extends State<ComposeEmailPage> {
  final TextEditingController fromController = TextEditingController();
  final TextEditingController toController = TextEditingController();
  final TextEditingController subjectController = TextEditingController();
  final TextEditingController bodyController = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  List<XFile> _attachedImages = [];

  @override
  void initState() {
    super.initState();
    _loadCurrentUserName();
  }

  Future<void> _loadCurrentUserName() async {
    final auth = FirebaseAuth.instance;
    final database = FirebaseDatabase.instance.ref();

    final currentUser = auth.currentUser;
    if (currentUser != null) {
      final userSnapshot = await database.child('users').child(currentUser.uid).get();
      final username = userSnapshot.child('username').value?.toString() ?? currentUser.email!;
      setState(() {
        fromController.text = username;
      });
    }
  }

  Future<void> _pickImages() async {
    final List<XFile>? pickedImages = await _picker.pickMultiImage();
    if (pickedImages != null && pickedImages.isNotEmpty) {
      setState(() {
        _attachedImages = pickedImages;
      });
    }
  }

  Future<void> _sendEmail() async {
    final database = FirebaseDatabase.instance.ref();
    // final storage = FirebaseStorage.instance; // Tạm thời không dùng
    final auth = FirebaseAuth.instance;

    final fromEmail = fromController.text.trim();
    final toPhone = toController.text.trim();
    final subject = subjectController.text.trim();
    final body = bodyController.text.trim();
    final timestamp = DateTime.now().toIso8601String();

    final fromUid = auth.currentUser?.uid ?? 'anonymous';

    // Tìm UID người nhận theo số điện thoại
    final usersSnapshot = await database.child('users').get();
    String? recipientUid;
    for (var user in usersSnapshot.children) {
      if (user.child('phone_number').value == toPhone) {
        recipientUid = user.key;
        break;
      }
    }

    if (recipientUid == null) {
      CustomDialog.show(
        context,
        title: "Error",
        content: "Recipient does not exist!",
        icon: Icons.error_outline,
      );
      return;
    }

    // Gửi thư
    final messageRef = database.child('internal_messages').push();
    final messageId = messageRef.key!;

    await messageRef.set({
      'sender_id': fromUid,
      'subject': subject,
      'body': body,
      'sent_at': timestamp,
      'is_draft': false,
      'is_starred': false,
      'is_read': false,
      'is_trashed': false,
    });

    // Lưu người nhận
    await database
        .child('internal_message_recipients')
        .child(messageId)
        .child(recipientUid)
        .set({'recipient_type': 'TO',
        'is_draft_recip': false,
        'is_starred_recip': false,
        'is_read_recip': false,
        'is_trashed_recip': false,
      });

    // // Upload file đính kèm lên Firebase Storage (TẠM THỜI BỎ)
    // for (var image in _attachedImages) {
    //   final fileName = image.name;
    //   final file = File(image.path);
    //   final storageRef = storage.ref().child('attachments/$messageId/$fileName');
    //   final uploadTask = await storageRef.putFile(file);
    //   final downloadUrl = await storageRef.getDownloadURL();

    //   await database.child('attachments').child(messageId).push().set({
    //     'file_path': downloadUrl,
    //   });
    // }

    // Xóa form sau khi gửi
    toController.clear();
    subjectController.clear();
    bodyController.clear();
    setState(() => _attachedImages.clear());

    CustomDialog.show(
      context,
      title: "Success",
      content: "Send mail successfully!",
      icon: Icons.check_circle_outline,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Compose Email'),
        backgroundColor: Colors.black,
        titleTextStyle: const TextStyle(
          color: Color(0xFFffcad4),
          fontWeight: FontWeight.bold,
          fontSize: 24,
        ),
      ),
      backgroundColor: Colors.black,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: fromController,
              decoration: const InputDecoration(
                labelText: 'From',
                labelStyle: TextStyle(color: Colors.white),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white),
                ),
              ),
              style: const TextStyle(color: Colors.white),
              readOnly: true,
            ),
            TextField(
              controller: toController,
              decoration: const InputDecoration(
                labelText: 'To (Phone Number)',
                labelStyle: TextStyle(color: Colors.white),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white),
                ),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            TextField(
              controller: subjectController,
              decoration: const InputDecoration(
                labelText: 'Subject',
                labelStyle: TextStyle(color: Colors.white),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white),
                ),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            Expanded(
              child: TextField(
                controller: bodyController,
                decoration: const InputDecoration(
                  labelText: 'Content',
                  labelStyle: TextStyle(color: Colors.white),
                  border: InputBorder.none,
                ),
                style: const TextStyle(color: Colors.white),
                maxLines: null,
              ),
            ),
            if (_attachedImages.isNotEmpty)
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _attachedImages.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Image.file(
                        File(_attachedImages[index].path),
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                      ),
                    );
                  },
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.image, color: Color(0xFFF4538A)),
                    label: const Text(
                      'Add Files',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    onPressed: _pickImages,
                    style: ElevatedButton.styleFrom(
                      foregroundColor: const Color(0xFFF4538A),
                      backgroundColor: const Color(0xFFffcad4),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _sendEmail,
                    icon: const Icon(Icons.send, color: Color(0xFFF4538A)),
                    label: const Text(
                      'Send',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: const Color(0xFFF4538A),
                      backgroundColor: const Color(0xFFffcad4),
                    ),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}

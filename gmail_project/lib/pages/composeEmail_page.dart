import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../components/dialog.dart';
import '../services/message_service.dart';

class ComposeEmailPage extends StatefulWidget {
  final String? draftId;
  final String? initialTo;
  final String? initialSubject;
  final String? initialBody;
  
  const ComposeEmailPage({
    super.key,
    this.draftId,
    this.initialTo,
    this.initialSubject,
    this.initialBody,
  });

  @override
  State<ComposeEmailPage> createState() => _ComposeEmailPageState();
}

class _ComposeEmailPageState extends State<ComposeEmailPage> {
  final TextEditingController fromController = TextEditingController();
  final TextEditingController toController = TextEditingController();
  final TextEditingController subjectController = TextEditingController();
  final TextEditingController bodyController = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  
  List<XFile> _attachedImages = [];
  List<Map<String, String>> _uploadedAttachments = []; // Lưu thông tin file đã upload
  final MessageService _messageService = MessageService();
  
  bool _hasUnsavedChanges = false;
  bool _isUploading = false;
  String? _currentDraftId;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserName();
    _initializeFields();
    _setupChangeListeners();
  }

  void _initializeFields() {
    if (widget.draftId != null) {
      _currentDraftId = widget.draftId;
    }
    
    toController.text = widget.initialTo ?? '';
    subjectController.text = widget.initialSubject ?? '';
    bodyController.text = widget.initialBody ?? '';
  }

  void _setupChangeListeners() {
    toController.addListener(_onContentChanged);
    subjectController.addListener(_onContentChanged);
    bodyController.addListener(_onContentChanged);
  }

  void _onContentChanged() {
    if (!_hasUnsavedChanges) {
      setState(() {
        _hasUnsavedChanges = true;
      });
    }
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
        _hasUnsavedChanges = true;
      });
    }
  }

  // Upload tất cả attachments lên Firebase Storage
  Future<List<Map<String, String>>> _uploadAttachments() async {
    if (_attachedImages.isEmpty) return [];

    setState(() {
      _isUploading = true;
    });

    List<Map<String, String>> uploadedFiles = [];
    final auth = FirebaseAuth.instance;
    final currentUser = auth.currentUser;
    
    if (currentUser == null) return [];

    try {
      for (int i = 0; i < _attachedImages.length; i++) {
        final file = _attachedImages[i];
        
        // Tạo tên file unique
        final fileName = 'attachment_${currentUser.uid}_${DateTime.now().millisecondsSinceEpoch}_$i.${file.path.split('.').last}';
        final ref = _storage.ref().child('message_attachments/$fileName');

        // Upload file
        final uploadTask = ref.putFile(File(file.path));
        final snapshot = await uploadTask;
        
        // Lấy download URL
        final downloadUrl = await snapshot.ref.getDownloadURL();
        
        // Lưu thông tin file
        uploadedFiles.add({
          'name': file.name,
          'url': downloadUrl,
          'size': (await File(file.path).length()).toString(),
          'type': file.path.split('.').last.toLowerCase(),
        });
      }
    } catch (e) {
      CustomDialog.show(
        context,
        title: "Error",
        content: "Failed to upload attachments: $e",
        icon: Icons.error_outline,
      );
      return [];
    } finally {
      setState(() {
        _isUploading = false;
      });
    }

    return uploadedFiles;
  }

  Future<void> _saveDraft() async {
    final auth = FirebaseAuth.instance;
    final currentUser = auth.currentUser;
    if (currentUser == null) return;

    final toPhone = toController.text.trim();
    final subject = subjectController.text.trim();
    final body = bodyController.text.trim();

    // Chỉ lưu draft nếu có nội dung
    if (toPhone.isEmpty && subject.isEmpty && body.isEmpty && _attachedImages.isEmpty) {
      return;
    }

    try {
      // Upload attachments nếu có
      List<Map<String, String>> attachments = [];
      if (_attachedImages.isNotEmpty) {
        attachments = await _uploadAttachments();
        if (attachments.isNotEmpty) {
          _uploadedAttachments = attachments;
          _attachedImages.clear(); // Clear local images after upload
        }
      }

      final draftId = await _messageService.saveDraft(
        senderId: currentUser.uid,
        recipientPhone: toPhone,
        subject: subject,
        body: body,
        draftId: _currentDraftId,
        attachments: _uploadedAttachments, // Thêm attachments vào draft
      );

      if (_currentDraftId == null) {
        _currentDraftId = draftId;
      }

      setState(() {
        _hasUnsavedChanges = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Draft saved successfully'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      CustomDialog.show(
        context,
        title: "Error",
        content: "Failed to save draft: $e",
        icon: Icons.error_outline,
      );
    }
  }

  Future<void> _sendEmail() async {
    if (_isUploading) {
      CustomDialog.show(
        context,
        title: "Please wait",
        content: "Files are still uploading...",
        icon: Icons.info_outline,
      );
      return;
    }

    final database = FirebaseDatabase.instance.ref();
    final auth = FirebaseAuth.instance;

    final fromEmail = fromController.text.trim();
    final toPhone = toController.text.trim();
    final subject = subjectController.text.trim();
    final body = bodyController.text.trim();
    final timestamp = DateTime.now().toIso8601String();

    final fromUid = auth.currentUser?.uid ?? 'anonymous';

    print('=== DEBUG: Starting _sendEmail ===');
    print('From: $fromEmail, To: $toPhone, Subject: $subject');
    print('Sender UID: $fromUid');

    // Tìm UID người nhận theo số điện thoại
    final usersSnapshot = await database.child('users').get();
    String? recipientUid;
    for (var user in usersSnapshot.children) {
      if (user.child('phone_number').value == toPhone) {
        recipientUid = user.key;
        break;
      }
    }

    print('Recipient UID found: $recipientUid');

    if (recipientUid == null) {
      CustomDialog.show(
        context,
        title: "Error",
        content: "Recipient does not exist!",
        icon: Icons.error_outline,
      );
      return;
    }

    try {
      // Upload attachments trước khi gửi
      List<Map<String, String>> finalAttachments = List.from(_uploadedAttachments);
      if (_attachedImages.isNotEmpty) {
        final newAttachments = await _uploadAttachments();
        finalAttachments.addAll(newAttachments);
      }

      // Gửi thư
      final messageRef = database.child('internal_messages').push();
      final messageId = messageRef.key!;

      print('Creating message with ID: $messageId');

      // Tạo message data với attachments
      Map<String, dynamic> messageData = {
        'sender_id': fromUid,
        'subject': subject,
        'body': body,
        'sent_at': timestamp,
        'is_draft': false,
        'is_starred': false,
        'is_read': false,
        'is_trashed': false,
      };

      // Thêm attachments nếu có
      if (finalAttachments.isNotEmpty) {
        messageData['attachments'] = finalAttachments;
      }

      await messageRef.set(messageData);

      print('Message created successfully with ${finalAttachments.length} attachments');

      // Lưu người nhận
      await database
          .child('internal_message_recipients')
          .child(messageId)
          .child(recipientUid)
          .set({
        'recipient_type': 'TO',
        'is_draft_recip': false,
        'is_starred_recip': false,
        'is_read_recip': false,
        'is_trashed_recip': false,
      });

      print('Recipient data saved successfully');

      // Kiểm tra xem message đã được đọc chưa trước khi tạo notification
      final recipientSnapshot = await database
          .child('internal_message_recipients')
          .child(messageId)
          .child(recipientUid)
          .get();

      final isMessageRead = recipientSnapshot.child('is_read_recip').value as bool? ?? false;
      print('Is message read: $isMessageRead');

      // Chỉ tạo notification nếu message chưa được đọc
      if (!isMessageRead) {
        print('Creating notification for recipient: $recipientUid');
        
        final notificationRef = database.child('notifications').child(recipientUid).push();
        final notificationData = {
          'title': 'You have a new message',
          'body': 'From: $fromEmail\nSubject: $subject${finalAttachments.isNotEmpty ? '\n📎 ${finalAttachments.length} attachment(s)' : ''}',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'sender_id': fromUid,
          'message_id': messageId,
          'is_read': false,
        };
        
        print('Notification data: $notificationData');
        
        await notificationRef.set(notificationData);
        print('Notification created successfully with key: ${notificationRef.key}');
        
        // Thêm log để verify notification đã được lưu
        final verifyNotification = await notificationRef.get();
        print('Notification verification: ${verifyNotification.exists}');
        if (verifyNotification.exists) {
          print('Notification content: ${verifyNotification.value}');
        }
      } else {
        print('Message already read, skipping notification creation');
      }

      // Xóa draft nếu có
      if (_currentDraftId != null) {
        await _messageService.deleteDraft(_currentDraftId!);
        print('Draft deleted: $_currentDraftId');
      }

      // Xóa form sau khi gửi
      toController.clear();
      subjectController.clear();
      bodyController.clear();
      setState(() {
        _attachedImages.clear();
        _uploadedAttachments.clear();
        _hasUnsavedChanges = false;
      });

      print('Form cleared successfully');

      CustomDialog.show(
        context,
        title: "Success",
        content: "Send mail successfully!",
        icon: Icons.check_circle_outline,
      );

      print('Success dialog shown');

      // Quay lại trang trước
      Navigator.pop(context, true);
    } catch (e) {
      print('ERROR in _sendEmail: $e');
      CustomDialog.show(
        context,
        title: "Error",
        content: "Failed to send email: $e",
        icon: Icons.error_outline,
      );
    }
  }

  void _removeAttachment(int index) {
    setState(() {
      if (index < _attachedImages.length) {
        _attachedImages.removeAt(index);
      } else {
        _uploadedAttachments.removeAt(index - _attachedImages.length);
      }
      _hasUnsavedChanges = true;
    });
  }

  Widget _buildAttachmentsSection() {
    final allAttachments = [
      ..._attachedImages.map((file) => {'type': 'local', 'data': file}),
      ..._uploadedAttachments.map((file) => {'type': 'uploaded', 'data': file}),
    ];

    if (allAttachments.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Attachments:',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: allAttachments.length,
            itemBuilder: (context, index) {
              final attachment = allAttachments[index];
              final isLocal = attachment['type'] == 'local';
              
              return Container(
                width: 100,
                margin: const EdgeInsets.only(right: 8),
                child: Stack(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white54),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: isLocal
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                File((attachment['data'] as XFile).path),
                                fit: BoxFit.cover,
                              ),
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _getFileIcon((attachment['data'] as Map<String, String>)['type'] ?? ''),
                                    color: Colors.white,
                                    size: 30,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    (attachment['data'] as Map<String, String>)['name'] ?? '',
                                    style: const TextStyle(color: Colors.white, fontSize: 10),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                    ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: GestureDetector(
                        onTap: () => _removeAttachment(index),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 12,
                          ),
                        ),
                      ),
                    ),
                    if (isLocal && _isUploading)
                      const Positioned.fill(
                        child: Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFFffcad4),
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  IconData _getFileIcon(String fileType) {
    switch (fileType.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Icons.image;
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'mp4':
      case 'avi':
      case 'mov':
        return Icons.video_file;
      case 'mp3':
      case 'wav':
        return Icons.audio_file;
      default:
        return Icons.insert_drive_file;
    }
  }

  Future<bool> _onWillPop() async {
    if (_hasUnsavedChanges) {
      final result = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF2C2C2C),
          title: const Text('Save Draft?', style: TextStyle(color: Colors.white)),
          content: const Text(
            'Do you want to save this email as draft before leaving?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'discard'),
              child: const Text('Discard', style: TextStyle(color: Colors.red)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'save'),
              child: const Text('Save Draft', style: TextStyle(color: Colors.blue)),
            ),
          ],
        ),
      );

      if (result == 'save') {
        await _saveDraft();
        return true;
      } else if (result == 'discard') {
        return true;
      } else {
        return false; // User cancelled
      }
    }
    return true;
  }

  @override
  void dispose() {
    toController.removeListener(_onContentChanged);
    subjectController.removeListener(_onContentChanged);
    bodyController.removeListener(_onContentChanged);
    
    toController.dispose();
    subjectController.dispose();
    bodyController.dispose();
    fromController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_currentDraftId != null ? 'Edit Draft' : 'Compose Email'),
          backgroundColor: Colors.black,
          titleTextStyle: const TextStyle(
            color: Color(0xFFffcad4),
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
          actions: [
            if (_hasUnsavedChanges)
              IconButton(
                icon: const Icon(Icons.save, color: Color(0xFFffcad4)),
                onPressed: _saveDraft,
                tooltip: 'Save Draft',
              ),
          ],
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
                child: Column(
                  children: [
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
                    _buildAttachmentsSection(),
                  ],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: _isUploading 
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                color: Color(0xFFF4538A),
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.image, color: Color(0xFFF4538A)),
                      label: Text(
                        _isUploading ? 'Uploading...' : 'Add Files',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      onPressed: _isUploading ? null : _pickImages,
                      style: ElevatedButton.styleFrom(
                        foregroundColor: const Color(0xFFF4538A),
                        backgroundColor: const Color(0xFFffcad4),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isUploading ? null : _sendEmail,
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
      ),
    );
  }
}
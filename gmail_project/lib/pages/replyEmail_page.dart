import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../components/dialog.dart';
import '../services/message_service.dart';

class ReplyEmailPage extends StatefulWidget {
  final String originalMessageId;
  final String originalSubject;
  final String originalBody;
  final String originalSenderName;
  final String originalSenderId;
  final String? originalSentAt;
  
  const ReplyEmailPage({
    super.key,
    required this.originalMessageId,
    required this.originalSubject,
    required this.originalBody,
    required this.originalSenderName,
    required this.originalSenderId,
    this.originalSentAt,
  });

  @override
  State<ReplyEmailPage> createState() => _ReplyEmailPageState();
}

class _ReplyEmailPageState extends State<ReplyEmailPage> {
  final TextEditingController fromController = TextEditingController();
  final TextEditingController toController = TextEditingController();
  final TextEditingController subjectController = TextEditingController();
  final TextEditingController bodyController = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  List<XFile> _attachedImages = [];
  final MessageService _messageService = MessageService();
  
  bool _hasUnsavedChanges = false;
  String? _currentDraftId;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserName();
    _initializeReplyFields();
    _setupChangeListeners();
  }

  void _initializeReplyFields() {
    // Set recipient to original sender
    toController.text = widget.originalSenderName;
    
    // Add "Re: " prefix if not already present
    String replySubject = widget.originalSubject;
    if (!replySubject.toLowerCase().startsWith('re:')) {
      replySubject = 'Re: $replySubject';
    }
    subjectController.text = replySubject;
    
    // Initialize reply body with quoted original message
    String quotedMessage = _buildQuotedMessage();
    bodyController.text = '\n\n$quotedMessage';
    
    // Position cursor at the beginning for user to type
    bodyController.selection = TextSelection.fromPosition(
      const TextPosition(offset: 0),
    );
  }

  String _buildQuotedMessage() {
    String formattedDate = widget.originalSentAt != null 
        ? _formatDate(widget.originalSentAt!) 
        : 'Unknown date';
    
    return '''
--- Original Message ---
From: ${widget.originalSenderName}
Date: $formattedDate
Subject: ${widget.originalSubject}

${widget.originalBody}''';
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

  Future<void> _saveDraft() async {
    final auth = FirebaseAuth.instance;
    final currentUser = auth.currentUser;
    if (currentUser == null) return;

    final toName = toController.text.trim();
    final subject = subjectController.text.trim();
    final body = bodyController.text.trim();

    // Only save draft if there's content
    if (toName.isEmpty && subject.isEmpty && body.isEmpty) {
      return;
    }

    try {
      // Get recipient's phone number for draft saving
      String? recipientPhone = await _getRecipientPhone(widget.originalSenderId);
      
      if (recipientPhone == null) {
        CustomDialog.show(
          context,
          title: "Error",
          content: "Cannot find recipient information for draft",
          icon: Icons.error_outline,
        );
        return;
      }

      final draftId = await _messageService.saveDraft(
        senderId: currentUser.uid,
        recipientPhone: recipientPhone ?? '',
        subject: subject,
        body: body,
        draftId: _currentDraftId,
        attachments: [], // Thêm dòng này
      );

      if (_currentDraftId == null) {
        _currentDraftId = draftId;
      }

      setState(() {
        _hasUnsavedChanges = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reply draft saved successfully'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      CustomDialog.show(
        context,
        title: "Error",
        content: "Failed to save reply draft: $e",
        icon: Icons.error_outline,
      );
    }
  }

  Future<String?> _getRecipientPhone(String userId) async {
    try {
      final database = FirebaseDatabase.instance.ref();
      final userSnapshot = await database.child('users').child(userId).get();
      if (userSnapshot.exists) {
        final userData = userSnapshot.value as Map<dynamic, dynamic>;
        return userData['phone_number']?.toString();
      }
    } catch (e) {
      print('Error getting recipient phone: $e');
    }
    return null;
  }

  Future<void> _sendReply() async {
    final database = FirebaseDatabase.instance.ref();
    final auth = FirebaseAuth.instance;

    final fromEmail = fromController.text.trim();
    final subject = subjectController.text.trim();
    final body = bodyController.text.trim();
    final timestamp = DateTime.now().toIso8601String();

    final fromUid = auth.currentUser?.uid ?? 'anonymous';
    final recipientUid = widget.originalSenderId;

    print('=== DEBUG: Starting _sendReply ===');
    print('From: $fromEmail, To: ${widget.originalSenderName}, Subject: $subject');
    print('Sender UID: $fromUid, Recipient UID: $recipientUid');

    if (subject.isEmpty || body.trim().isEmpty) {
      CustomDialog.show(
        context,
        title: "Validation Error",
        content: "Please fill in both subject and message content before sending!",
        icon: Icons.warning_amber_outlined,
      );
      return;
    }

    // ignore: unawaited_futures
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFFCAD4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                Color.fromARGB(255, 253, 80, 138),
              ),
              strokeWidth: 3,
            ),
            const SizedBox(height: 20),
            const Text(
              'Sending Reply...',
              style: TextStyle(
                color: Color.fromARGB(255, 253, 80, 138),
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'To: ${widget.originalSenderName}',
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );

    try {
      // Create reply message
      final messageRef = database.child('internal_messages').push();
      final messageId = messageRef.key!;

      print('Creating reply message with ID: $messageId');

      await messageRef.set({
        'sender_id': fromUid,
        'subject': subject,
        'body': body,
        'sent_at': timestamp,
        'is_draft': false,
        'is_starred': false,
        'is_read': false,
        'is_trashed': false,
        'reply_to': widget.originalMessageId, // Link to original message
      });

      print('Reply message created successfully');

      // Save recipient
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

      print('Reply recipient data saved successfully');

      // Check if message is already read before creating notification
      final recipientSnapshot = await database
          .child('internal_message_recipients')
          .child(messageId)
          .child(recipientUid)
          .get();

      final isMessageRead = recipientSnapshot.child('is_read_recip').value as bool? ?? false;
      print('Is reply message read: $isMessageRead');

      // Only create notification if message hasn't been read
      if (!isMessageRead) {
        print('Creating notification for recipient: $recipientUid');
        
        final notificationRef = database.child('notifications').child(recipientUid).push();
        final notificationData = {
          'title': 'New Reply Received',
          'body': 'Reply from: $fromEmail\nSubject: $subject',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'sender_id': fromUid,
          'message_id': messageId,
          'is_read': false,
        };
        
        print('Notification data: $notificationData');
        
        await notificationRef.set(notificationData);
        print('Reply notification created successfully with key: ${notificationRef.key}');
      } else {
        print('Message already read, skipping notification creation');
      }

      // Delete draft if exists
      if (_currentDraftId != null) {
        await _messageService.deleteDraft(_currentDraftId!);
        print('Reply draft deleted: $_currentDraftId');
      }

      // Clear form after sending
      setState(() {
        _attachedImages.clear();
        _hasUnsavedChanges = false;
      });

      print('Reply form cleared successfully');

      // Close loading dialog
      Navigator.pop(context);

      // Show success dialog with enhanced message
      CustomDialog.show(
        context,
        title: "Message Sent! ✉️",
        content: "Your reply has been sent successfully to ${widget.originalSenderName}.",
        icon: Icons.check_circle_outline,
        buttonText: "Great!",
        onConfirmed: () {
          // Navigate back to previous page after user confirms
          Navigator.pop(context, true);
        },
      );

      print('Success dialog shown');

    } catch (e) {
      print('ERROR in _sendReply: $e');
      
      // Close loading dialog
      Navigator.pop(context);
      
      // Show error dialog with more helpful message
      CustomDialog.show(
        context,
        title: "Send Failed",
        content: "Unable to send your reply at this time.\n\nError: ${e.toString()}\n\nPlease check your connection and try again.",
        icon: Icons.error_outline,
        buttonText: "OK",
      );
    }
  }

  void _showSuccessSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Reply Sent Successfully!',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'Sent to ${widget.originalSenderName}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green[600],
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<bool> _onWillPop() async {
    if (_hasUnsavedChanges) {
      final result = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF2C2C2C),
          title: const Text('Save Draft?', style: TextStyle(color: Colors.white)),
          content: const Text(
            'Do you want to save this reply as draft before leaving?',
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

  String _formatDate(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      return "${dateTime.day} ${_getMonthName(dateTime.month)} ${dateTime.year} at ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}";
    } catch (e) {
      return timestamp;
    }
  }

  String _getMonthName(int month) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month];
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
          title: const Text('Reply'),
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
                  labelText: 'To',
                  labelStyle: TextStyle(color: Colors.white),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                ),
                style: const TextStyle(color: Colors.white),
                readOnly: true, // Reply recipient is fixed
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
                    labelText: 'Your Reply',
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
                        child: Stack(
                          children: [
                            Image.file(
                              File(_attachedImages[index].path),
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                            ),
                            Positioned(
                              top: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _attachedImages.removeAt(index);
                                    _hasUnsavedChanges = true;
                                  });
                                },
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ],
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
                      onPressed: _sendReply,
                      icon: const Icon(Icons.send, color: Color(0xFFF4538A)),
                      label: const Text(
                        'Send Reply',
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
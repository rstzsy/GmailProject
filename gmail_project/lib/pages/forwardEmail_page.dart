import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../components/dialog.dart';
import '../services/message_service.dart';

class ForwardEmailPage extends StatefulWidget {
  final String originalMessageId;
  final String originalSubject;
  final String originalBody;
  final String originalSenderName;
  final String originalSenderId;
  final String? originalSentAt;
  
  const ForwardEmailPage({
    super.key,
    required this.originalMessageId,
    required this.originalSubject,
    required this.originalBody,
    required this.originalSenderName,
    required this.originalSenderId,
    this.originalSentAt,
  });

  @override
  State<ForwardEmailPage> createState() => _ForwardEmailPageState();
}

class _ForwardEmailPageState extends State<ForwardEmailPage> {
  final TextEditingController fromController = TextEditingController();
  final TextEditingController subjectController = TextEditingController();
  final TextEditingController bodyController = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  List<XFile> _attachedImages = [];
  final MessageService _messageService = MessageService();
  
  bool _hasUnsavedChanges = false;
  String? _currentDraftId;
  List<Map<String, dynamic>> _userSuggestions = [];
  bool _isLoadingSuggestions = false;
  
  // Changed from single recipient to multiple recipients
  List<Map<String, dynamic>> _selectedRecipients = [];

  @override
  void initState() {
    super.initState();
    _loadCurrentUserName();
    _initializeForwardFields();
    _setupChangeListeners();
    _loadUserSuggestions();
  }

  void _initializeForwardFields() {
    // Add "Fwd: " prefix if not already present
    String forwardSubject = widget.originalSubject;
    if (!forwardSubject.toLowerCase().startsWith('fwd:')) {
      forwardSubject = 'Fwd: $forwardSubject';
    }
    subjectController.text = forwardSubject;
    
    // Initialize forward body with quoted original message
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
---------- Forwarded message ----------
From: ${widget.originalSenderName}
Date: $formattedDate
Subject: ${widget.originalSubject}

${widget.originalBody}''';
  }

  void _setupChangeListeners() {
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

  Future<void> _loadUserSuggestions() async {
    setState(() {
      _isLoadingSuggestions = true;
    });

    try {
      final database = FirebaseDatabase.instance.ref();
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final usersSnapshot = await database.child('users').get();
      if (usersSnapshot.exists) {
        final usersData = usersSnapshot.value as Map<dynamic, dynamic>;
        List<Map<String, dynamic>> suggestions = [];

        usersData.forEach((uid, userData) {
          // Exclude current user from suggestions
          if (uid != currentUser.uid) {
            final user = userData as Map<dynamic, dynamic>;
            suggestions.add({
              'uid': uid,
              'name': user['username'] ?? user['name'] ?? 'Unknown User',
              'email': user['email'] ?? '',
              'phone': user['phone_number'] ?? '',
            });
          }
        });

        // Sort by name
        suggestions.sort((a, b) => a['name'].compareTo(b['name']));

        setState(() {
          _userSuggestions = suggestions;
        });
      }
    } catch (e) {
      print('Error loading user suggestions: $e');
    } finally {
      setState(() {
        _isLoadingSuggestions = false;
      });
    }
  }

  void _showRecipientSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2C2C2C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Select Recipients',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _hasUnsavedChanges = true;
                          });
                          Navigator.pop(context);
                        },
                        child: const Text(
                          'Done',
                          style: TextStyle(
                            color: Color(0xFFffcad4),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_selectedRecipients.length} selected',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_isLoadingSuggestions)
                    const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFffcad4),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        itemCount: _userSuggestions.length,
                        itemBuilder: (context, index) {
                          final user = _userSuggestions[index];
                          final isSelected = _selectedRecipients.any(
                            (recipient) => recipient['uid'] == user['uid']
                          );
                          
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isSelected 
                                ? const Color(0xFFF4538A) 
                                : const Color(0xFFffcad4),
                              child: isSelected 
                                ? const Icon(Icons.check, color: Colors.white)
                                : Text(
                                    user['name'][0].toUpperCase(),
                                    style: const TextStyle(
                                      color: Color(0xFFF4538A),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                            ),
                            title: Text(
                              user['name'],
                              style: TextStyle(
                                color: isSelected ? const Color(0xFFffcad4) : Colors.white,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            subtitle: Text(
                              user['email'],
                              style: const TextStyle(color: Colors.grey),
                            ),
                            onTap: () {
                              setModalState(() {
                                if (isSelected) {
                                  // Remove from selection
                                  _selectedRecipients.removeWhere(
                                    (recipient) => recipient['uid'] == user['uid']
                                  );
                                } else {
                                  // Add to selection
                                  _selectedRecipients.add(user);
                                }
                              });
                              setState(() {
                                _hasUnsavedChanges = true;
                              });
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _removeRecipient(int index) {
    setState(() {
      _selectedRecipients.removeAt(index);
      _hasUnsavedChanges = true;
    });
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

    final subject = subjectController.text.trim();
    final body = bodyController.text.trim();

    // Only save draft if there's content
    if (_selectedRecipients.isEmpty && subject.isEmpty && body.isEmpty) {
      return;
    }

    try {
      // For draft, we'll save with the first recipient's phone (if any)
      String? recipientPhone;
      if (_selectedRecipients.isNotEmpty) {
        recipientPhone = _selectedRecipients.first['phone'];
      }
      
      if (recipientPhone == null && _selectedRecipients.isNotEmpty) {
        _showErrorDialog("Error", "Cannot find recipient information for draft");
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
          content: Text('Forward draft saved successfully'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      _showErrorDialog("Error", "Failed to save forward draft: $e");
    }
  }

  Future<void> _sendForward() async {
    final database = FirebaseDatabase.instance.ref();
    final auth = FirebaseAuth.instance;

    final fromEmail = fromController.text.trim();
    final subject = subjectController.text.trim();
    final body = bodyController.text.trim();
    final timestamp = DateTime.now().toIso8601String();

    final fromUid = auth.currentUser?.uid ?? 'anonymous';

    if (_selectedRecipients.isEmpty || subject.isEmpty || body.trim().isEmpty) {
      _showErrorDialog(
        "Validation Error",
        "Please select recipients and fill in subject and message content before sending!",
      );
      return;
    }

    // Show loading dialog
    _showLoadingDialog(_selectedRecipients.length);

    try {
      // Create forward message
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
        'forwarded_from': widget.originalMessageId, // Link to original message
      });

      // Save all recipients
      for (var recipient in _selectedRecipients) {
        await database
            .child('internal_message_recipients')
            .child(messageId)
            .child(recipient['uid'])
            .set({
          'recipient_type': 'TO',
          'is_draft_recip': false,
          'is_starred_recip': false,
          'is_read_recip': false,
          'is_trashed_recip': false,
        });

        // Create notification for each recipient
        final notificationRef = database.child('notifications').child(recipient['uid']).push();
        await notificationRef.set({
          'title': 'New Forwarded Message',
          'body': 'Forwarded from: $fromEmail\nSubject: $subject',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'sender_id': fromUid,
          'message_id': messageId,
          'is_read': false,
        });
      }

      // Delete draft if exists
      if (_currentDraftId != null) {
        await _messageService.deleteDraft(_currentDraftId!);
      }

      // Clear form after sending
      setState(() {
        _attachedImages.clear();
        _selectedRecipients.clear();
        _hasUnsavedChanges = false;
      });

      // Close loading dialog
      Navigator.pop(context);

      // Show success dialog
      _showSuccessDialog(_selectedRecipients.length);

    } catch (e) {
      print('ERROR in _sendForward: $e');
      
      // Close loading dialog
      Navigator.pop(context);
      
      // Show error dialog
      _showErrorDialog(
        "Forward Failed",
        "Unable to forward your message at this time.\n\nError: ${e.toString()}\n\nPlease check your connection and try again.",
      );
    }
  }

  void _showLoadingDialog(int recipientCount) {
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
              'Forwarding Message...',
              style: TextStyle(
                color: Color.fromARGB(255, 253, 80, 138),
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'To: $recipientCount recipient${recipientCount > 1 ? 's' : ''}',
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showSuccessDialog(int recipientCount) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFFCAD4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Color(0xFFF4538A)),
            SizedBox(width: 8),
            Text(
              "Message Forwarded! 📤",
              style: TextStyle(
                color: Color(0xFFF4538A),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          "Your message has been forwarded successfully to $recipientCount recipient${recipientCount > 1 ? 's' : ''}.",
          style: const TextStyle(color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context, true); // Return to previous page
            },
            child: const Text(
              "Great!",
              style: TextStyle(
                color: Color(0xFFF4538A),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFFCAD4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          content,
          style: const TextStyle(color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "OK",
              style: TextStyle(
                color: Color(0xFFF4538A),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
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
            'Do you want to save this forward as draft before leaving?',
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
    subjectController.removeListener(_onContentChanged);
    bodyController.removeListener(_onContentChanged);
    
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
          title: const Text('Forward'),
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
              const SizedBox(height: 16),
              // Recipients section
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'To: ${_selectedRecipients.length} recipient${_selectedRecipients.length == 1 ? '' : 's'}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.person_add, color: Color(0xFFffcad4)),
                            onPressed: _showRecipientSelector,
                            tooltip: 'Add Recipients',
                          ),
                        ],
                      ),
                    ),
                    if (_selectedRecipients.isNotEmpty)
                      Container(
                        height: 120,
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _selectedRecipients.length,
                          itemBuilder: (context, index) {
                            final recipient = _selectedRecipients[index];
                            return Container(
                              margin: const EdgeInsets.only(right: 8.0, bottom: 12.0),
                              child: Column(
                                children: [
                                  Stack(
                                    children: [
                                      CircleAvatar(
                                        radius: 30,
                                        backgroundColor: const Color(0xFFffcad4),
                                        child: Text(
                                          recipient['name'][0].toUpperCase(),
                                          style: const TextStyle(
                                            color: Color(0xFFF4538A),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: -5,
                                        right: -5,
                                        child: GestureDetector(
                                          onTap: () => _removeRecipient(index),
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
                                  const SizedBox(height: 4),
                                  SizedBox(
                                    width: 80,
                                    child: Text(
                                      recipient['name'],
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
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
                    labelText: 'Add your message (optional)',
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
                      onPressed: _sendForward,
                      icon: const Icon(Icons.forward, color: Color(0xFFF4538A)),
                      label: const Text(
                        'Forward',
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